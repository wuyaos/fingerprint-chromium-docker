#!/bin/bash
# Docker镜像压缩脚本 - 基于腾讯云文章的终极压缩术

set -euo pipefail

# 配置
IMAGE_NAME=${1:-"wuyaos/fingerprint-chromium-docker:latest"}
OUTPUT_DIR=${2:-"./compressed"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取镜像大小
get_image_size() {
    local image=$1
    docker images --format "table {{.Size}}" "$image" | tail -n 1
}

# 获取镜像大小（字节）
get_image_size_bytes() {
    local image=$1
    docker inspect "$image" --format='{{.Size}}' 2>/dev/null || echo "0"
}

# 格式化字节大小
format_bytes() {
    local bytes=$1
    if [ "$bytes" -gt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [ "$bytes" -gt 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    elif [ "$bytes" -gt 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# 主函数
main() {
    log_info "Docker镜像压缩工具启动"
    log_info "目标镜像: $IMAGE_NAME"
    
    # 检查镜像是否存在
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$IMAGE_NAME$"; then
        log_error "镜像 $IMAGE_NAME 不存在，请先构建镜像"
        exit 1
    fi
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
    
    # 获取原始镜像大小
    original_size=$(get_image_size "$IMAGE_NAME")
    original_bytes=$(get_image_size_bytes "$IMAGE_NAME")
    log_info "原始镜像大小: $original_size"
    
    # 1. 导出为tar文件
    log_info "正在导出镜像为tar文件..."
    tar_file="$OUTPUT_DIR/image_${TIMESTAMP}.tar"
    docker save "$IMAGE_NAME" -o "$tar_file"
    tar_size=$(stat -f%z "$tar_file" 2>/dev/null || stat -c%s "$tar_file")
    log_success "tar文件已创建: $tar_file ($(format_bytes $tar_size))"
    
    # 2. 使用gzip压缩
    log_info "正在使用gzip压缩..."
    gzip_file="${tar_file}.gz"
    gzip -c "$tar_file" > "$gzip_file"
    gzip_size=$(stat -f%z "$gzip_file" 2>/dev/null || stat -c%s "$gzip_file")
    gzip_ratio=$(echo "scale=2; (1-$gzip_size/$tar_size)*100" | bc)
    log_success "gzip压缩完成: $gzip_file ($(format_bytes $gzip_size), 压缩率: ${gzip_ratio}%)"
    
    # 3. 使用xz压缩（更高压缩率）
    log_info "正在使用xz压缩（更高压缩率）..."
    xz_file="${tar_file}.xz"
    xz -c "$tar_file" > "$xz_file"
    xz_size=$(stat -f%z "$xz_file" 2>/dev/null || stat -c%s "$xz_file")
    xz_ratio=$(echo "scale=2; (1-$xz_size/$tar_size)*100" | bc)
    log_success "xz压缩完成: $xz_file ($(format_bytes $xz_size), 压缩率: ${xz_ratio}%)"
    
    # 4. 使用zstd压缩（平衡压缩率和速度）
    if command -v zstd >/dev/null 2>&1; then
        log_info "正在使用zstd压缩（平衡压缩率和速度）..."
        zstd_file="${tar_file}.zst"
        zstd -c "$tar_file" > "$zstd_file"
        zstd_size=$(stat -f%z "$zstd_file" 2>/dev/null || stat -c%s "$zstd_file")
        zstd_ratio=$(echo "scale=2; (1-$zstd_size/$tar_size)*100" | bc)
        log_success "zstd压缩完成: $zstd_file ($(format_bytes $zstd_size), 压缩率: ${zstd_ratio}%)"
    else
        log_warning "zstd未安装，跳过zstd压缩"
    fi
    
    # 清理原始tar文件
    rm "$tar_file"
    log_info "已清理原始tar文件"
    
    # 总结报告
    echo
    log_success "压缩完成！压缩文件保存在: $OUTPUT_DIR"
    echo "压缩结果对比:"
    echo "  原始镜像: $original_size"
    echo "  gzip压缩: $(format_bytes $gzip_size) (压缩率: ${gzip_ratio}%)"
    echo "  xz压缩:   $(format_bytes $xz_size) (压缩率: ${xz_ratio}%)"
    if command -v zstd >/dev/null 2>&1; then
        echo "  zstd压缩: $(format_bytes $zstd_size) (压缩率: ${zstd_ratio}%)"
    fi
    
    echo
    log_info "使用方法:"
    echo "  加载gzip压缩镜像: gunzip -c $gzip_file | docker load"
    echo "  加载xz压缩镜像:   xz -dc $xz_file | docker load"
    if command -v zstd >/dev/null 2>&1; then
        echo "  加载zstd压缩镜像: zstd -dc $zstd_file | docker load"
    fi
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    if ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("docker")
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        missing_deps+=("bc")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖后重试"
        exit 1
    fi
}

# 显示帮助
show_help() {
    echo "Docker镜像压缩工具"
    echo
    echo "用法: $0 [镜像名称] [输出目录]"
    echo
    echo "参数:"
    echo "  镜像名称    要压缩的Docker镜像名称 (默认: wuyaos/fingerprint-chromium-docker:latest)"
    echo "  输出目录    压缩文件保存目录 (默认: ./compressed)"
    echo
    echo "示例:"
    echo "  $0"
    echo "  $0 myimage:latest"
    echo "  $0 myimage:latest /tmp/compressed"
    echo
    echo "选项:"
    echo "  -h, --help    显示此帮助信息"
}

# 处理命令行参数
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# 检查依赖并运行主函数
check_dependencies
main "$@"
