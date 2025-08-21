#!/bin/bash
# Docker镜像分析脚本 - 分析镜像层和大小

set -euo pipefail

# 配置
IMAGE_NAME=${1:-"wuyaos/fingerprint-chromium-docker:latest"}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_header() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# 格式化字节大小
format_bytes() {
    local bytes=$1
    if [ "$bytes" -gt 1073741824 ]; then
        printf "%.2fGB" "$(echo "scale=2; $bytes/1073741824" | bc)"
    elif [ "$bytes" -gt 1048576 ]; then
        printf "%.2fMB" "$(echo "scale=2; $bytes/1048576" | bc)"
    elif [ "$bytes" -gt 1024 ]; then
        printf "%.2fKB" "$(echo "scale=2; $bytes/1024" | bc)"
    else
        printf "%dB" "$bytes"
    fi
}

# 分析镜像基本信息
analyze_basic_info() {
    log_header "镜像基本信息"
    
    # 检查镜像是否存在
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$IMAGE_NAME$"; then
        log_error "镜像 $IMAGE_NAME 不存在"
        exit 1
    fi
    
    # 获取镜像信息
    local info=$(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" | head -1)
    echo "$info"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" | grep "$IMAGE_NAME"
    
    echo
    
    # 获取详细信息
    local image_id=$(docker images --format "{{.ID}}" "$IMAGE_NAME")
    local created=$(docker inspect --format='{{.Created}}' "$IMAGE_NAME")
    local size=$(docker inspect --format='{{.Size}}' "$IMAGE_NAME")
    local virtual_size=$(docker inspect --format='{{.VirtualSize}}' "$IMAGE_NAME")
    
    echo "镜像ID: $image_id"
    echo "创建时间: $created"
    echo "镜像大小: $(format_bytes $size)"
    echo "虚拟大小: $(format_bytes $virtual_size)"
}

# 分析镜像层
analyze_layers() {
    log_header "镜像层分析"
    
    # 使用docker history分析层
    echo "镜像层历史 (从最新到最旧):"
    docker history --format "table {{.ID}}\t{{.CreatedBy}}\t{{.Size}}" "$IMAGE_NAME"
    
    echo
    
    # 统计层数和总大小
    local layer_count=$(docker history --format "{{.ID}}" "$IMAGE_NAME" | wc -l)
    local total_size=$(docker inspect --format='{{.Size}}' "$IMAGE_NAME")
    
    echo "总层数: $layer_count"
    echo "总大小: $(format_bytes $total_size)"
    
    # 找出最大的层
    echo
    echo "最大的5个层:"
    docker history --format "{{.Size}}\t{{.CreatedBy}}" "$IMAGE_NAME" | \
        grep -v "0B" | \
        sort -hr | \
        head -5 | \
        while read size command; do
            echo "  $size - ${command:0:80}..."
        done
}

# 分析镜像内容
analyze_content() {
    log_header "镜像内容分析"
    
    # 创建临时容器来分析内容
    local container_id=$(docker create "$IMAGE_NAME")
    
    echo "正在分析镜像内容..."
    
    # 分析根目录大小
    echo
    echo "根目录大小分布:"
    docker exec "$container_id" du -sh /* 2>/dev/null | sort -hr | head -10 || {
        # 如果exec失败，尝试使用export
        docker export "$container_id" | tar -tv | head -20
    }
    
    # 清理临时容器
    docker rm "$container_id" >/dev/null
}

# 提供优化建议
provide_suggestions() {
    log_header "优化建议"
    
    local size=$(docker inspect --format='{{.Size}}' "$IMAGE_NAME")
    local layer_count=$(docker history --format "{{.ID}}" "$IMAGE_NAME" | wc -l)
    
    echo "基于分析结果的优化建议:"
    echo
    
    # 基于大小的建议
    if [ "$size" -gt 1073741824 ]; then  # > 1GB
        log_warning "镜像大小超过1GB，建议："
        echo "  1. 使用多阶段构建分离构建环境和运行环境"
        echo "  2. 选择更轻量的基础镜像（如Alpine）"
        echo "  3. 清理不必要的文件和缓存"
    elif [ "$size" -gt 536870912 ]; then  # > 512MB
        log_info "镜像大小适中，可进一步优化："
        echo "  1. 检查是否有不必要的依赖包"
        echo "  2. 合并RUN指令减少层数"
    else
        log_success "镜像大小良好（< 512MB）"
    fi
    
    echo
    
    # 基于层数的建议
    if [ "$layer_count" -gt 20 ]; then
        log_warning "镜像层数较多（$layer_count层），建议："
        echo "  1. 合并多个RUN指令"
        echo "  2. 使用&&连接命令"
        echo "  3. 在同一层中安装和清理"
    elif [ "$layer_count" -gt 10 ]; then
        log_info "镜像层数适中（$layer_count层），可适当优化"
    else
        log_success "镜像层数良好（$layer_count层）"
    fi
    
    echo
    echo "通用优化技巧："
    echo "  1. 使用.dockerignore忽略不必要的文件"
    echo "  2. 在RUN指令末尾清理缓存和临时文件"
    echo "  3. 使用--no-install-recommends减少依赖"
    echo "  4. 考虑使用镜像压缩工具进一步减小传输大小"
}

# 主函数
main() {
    log_info "Docker镜像分析工具"
    log_info "分析镜像: $IMAGE_NAME"
    echo
    
    analyze_basic_info
    echo
    analyze_layers
    echo
    analyze_content
    echo
    provide_suggestions
    
    echo
    log_success "分析完成！"
}

# 显示帮助
show_help() {
    echo "Docker镜像分析工具"
    echo
    echo "用法: $0 [镜像名称]"
    echo
    echo "参数:"
    echo "  镜像名称    要分析的Docker镜像名称 (默认: wuyaos/fingerprint-chromium-docker:latest)"
    echo
    echo "示例:"
    echo "  $0"
    echo "  $0 myimage:latest"
    echo
    echo "选项:"
    echo "  -h, --help    显示此帮助信息"
}

# 检查依赖
check_dependencies() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker未安装或不在PATH中"
        exit 1
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        log_warning "bc未安装，某些计算功能可能不可用"
    fi
}

# 处理命令行参数
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

# 检查依赖并运行主函数
check_dependencies
main "$@"
