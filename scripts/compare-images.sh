#!/bin/bash
# Docker镜像对比脚本 - 对比Ubuntu和Alpine版本

set -euo pipefail

# 配置
UBUNTU_IMAGE=${1:-"wuyaos/fingerprint-chromium-docker:latest"}
ALPINE_IMAGE=${2:-"wuyaos/fingerprint-chromium-docker:latest-alpine"}

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

# 获取镜像信息
get_image_info() {
    local image=$1
    local name=$2
    
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$image$"; then
        log_error "镜像 $image 不存在"
        return 1
    fi
    
    local size=$(docker inspect --format='{{.Size}}' "$image")
    local virtual_size=$(docker inspect --format='{{.VirtualSize}}' "$image")
    local created=$(docker inspect --format='{{.Created}}' "$image")
    local layer_count=$(docker history --format "{{.ID}}" "$image" | wc -l)
    
    echo "$name:"
    echo "  镜像: $image"
    echo "  大小: $(format_bytes $size)"
    echo "  虚拟大小: $(format_bytes $virtual_size)"
    echo "  层数: $layer_count"
    echo "  创建时间: $created"
    echo "  大小(字节): $size"
}

# 对比镜像
compare_images() {
    log_header "镜像基本信息对比"
    
    # 获取Ubuntu镜像信息
    local ubuntu_info=$(get_image_info "$UBUNTU_IMAGE" "Ubuntu版本")
    local ubuntu_size=$(docker inspect --format='{{.Size}}' "$UBUNTU_IMAGE" 2>/dev/null || echo "0")
    local ubuntu_layers=$(docker history --format "{{.ID}}" "$UBUNTU_IMAGE" 2>/dev/null | wc -l || echo "0")
    
    echo "$ubuntu_info"
    echo
    
    # 获取Alpine镜像信息
    local alpine_info=$(get_image_info "$ALPINE_IMAGE" "Alpine版本")
    local alpine_size=$(docker inspect --format='{{.Size}}' "$ALPINE_IMAGE" 2>/dev/null || echo "0")
    local alpine_layers=$(docker history --format "{{.ID}}" "$ALPINE_IMAGE" 2>/dev/null | wc -l || echo "0")
    
    echo "$alpine_info"
    echo
    
    # 计算差异
    if [ "$ubuntu_size" -gt 0 ] && [ "$alpine_size" -gt 0 ]; then
        local size_diff=$((ubuntu_size - alpine_size))
        local size_ratio=$(echo "scale=2; $alpine_size*100/$ubuntu_size" | bc)
        local layer_diff=$((ubuntu_layers - alpine_layers))
        
        log_header "对比结果"
        echo "大小对比:"
        echo "  Ubuntu: $(format_bytes $ubuntu_size)"
        echo "  Alpine: $(format_bytes $alpine_size)"
        echo "  差异: $(format_bytes $size_diff)"
        echo "  Alpine是Ubuntu的: ${size_ratio}%"
        
        echo
        echo "层数对比:"
        echo "  Ubuntu: $ubuntu_layers 层"
        echo "  Alpine: $alpine_layers 层"
        echo "  差异: $layer_diff 层"
        
        echo
        if [ "$alpine_size" -lt "$ubuntu_size" ]; then
            local savings=$(echo "scale=2; (1-$alpine_size/$ubuntu_size)*100" | bc)
            log_success "Alpine版本节省了 ${savings}% 的空间"
        else
            log_warning "Alpine版本反而更大"
        fi
    fi
}

# 对比镜像层
compare_layers() {
    log_header "镜像层详细对比"
    
    echo "Ubuntu版本镜像层:"
    docker history --format "table {{.ID}}\t{{.CreatedBy}}\t{{.Size}}" "$UBUNTU_IMAGE" | head -10
    
    echo
    echo "Alpine版本镜像层:"
    docker history --format "table {{.ID}}\t{{.CreatedBy}}\t{{.Size}}" "$ALPINE_IMAGE" | head -10
}

# 性能测试
performance_test() {
    log_header "启动性能测试"
    
    echo "测试Ubuntu版本启动时间..."
    local ubuntu_start_time=$(date +%s.%N)
    local ubuntu_container=$(docker run -d --rm "$UBUNTU_IMAGE" sleep 10)
    docker wait "$ubuntu_container" >/dev/null 2>&1 || true
    local ubuntu_end_time=$(date +%s.%N)
    local ubuntu_duration=$(echo "$ubuntu_end_time - $ubuntu_start_time" | bc)
    
    echo "测试Alpine版本启动时间..."
    local alpine_start_time=$(date +%s.%N)
    local alpine_container=$(docker run -d --rm "$ALPINE_IMAGE" sleep 10)
    docker wait "$alpine_container" >/dev/null 2>&1 || true
    local alpine_end_time=$(date +%s.%N)
    local alpine_duration=$(echo "$alpine_end_time - $alpine_start_time" | bc)
    
    echo
    echo "启动时间对比:"
    printf "  Ubuntu: %.2f秒\n" "$ubuntu_duration"
    printf "  Alpine: %.2f秒\n" "$alpine_duration"
    
    if (( $(echo "$alpine_duration < $ubuntu_duration" | bc -l) )); then
        local improvement=$(echo "scale=2; ($ubuntu_duration - $alpine_duration) * 100 / $ubuntu_duration" | bc)
        log_success "Alpine版本启动快了 ${improvement}%"
    else
        log_warning "Ubuntu版本启动更快"
    fi
}

# 提供建议
provide_recommendations() {
    log_header "使用建议"
    
    local ubuntu_size=$(docker inspect --format='{{.Size}}' "$UBUNTU_IMAGE" 2>/dev/null || echo "0")
    local alpine_size=$(docker inspect --format='{{.Size}}' "$ALPINE_IMAGE" 2>/dev/null || echo "0")
    
    echo "选择建议:"
    echo
    
    if [ "$alpine_size" -lt "$ubuntu_size" ]; then
        local savings=$(echo "scale=2; (1-$alpine_size/$ubuntu_size)*100" | bc)
        echo "🏔️  Alpine版本优势:"
        echo "   - 镜像体积小 ${savings}%"
        echo "   - 下载传输更快"
        echo "   - 适合CI/CD环境"
        echo "   - 安全攻击面更小"
        echo
        echo "🐧 Ubuntu版本优势:"
        echo "   - 更好的软件兼容性"
        echo "   - 更多的调试工具"
        echo "   - 更稳定的glibc支持"
        echo "   - 适合生产环境"
    fi
    
    echo
    echo "推荐使用场景:"
    echo "  开发/测试环境: Alpine版本"
    echo "  生产环境: Ubuntu版本"
    echo "  CI/CD流水线: Alpine版本"
    echo "  需要调试: Ubuntu版本"
}

# 主函数
main() {
    log_info "Docker镜像对比工具"
    log_info "对比镜像: $UBUNTU_IMAGE vs $ALPINE_IMAGE"
    echo
    
    compare_images
    echo
    compare_layers
    echo
    performance_test
    echo
    provide_recommendations
    
    echo
    log_success "对比完成！"
}

# 显示帮助
show_help() {
    echo "Docker镜像对比工具"
    echo
    echo "用法: $0 [Ubuntu镜像] [Alpine镜像]"
    echo
    echo "参数:"
    echo "  Ubuntu镜像    Ubuntu版本镜像名称 (默认: wuyaos/fingerprint-chromium-docker:latest)"
    echo "  Alpine镜像    Alpine版本镜像名称 (默认: wuyaos/fingerprint-chromium-docker:latest-alpine)"
    echo
    echo "示例:"
    echo "  $0"
    echo "  $0 myimage:ubuntu myimage:alpine"
    echo
    echo "选项:"
    echo "  -h, --help    显示此帮助信息"
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
        exit 1
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
