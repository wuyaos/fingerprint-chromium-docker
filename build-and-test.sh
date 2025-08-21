#!/bin/bash
# Build and test script for new fingerprint-chromium Docker image

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Configuration
IMAGE_NAME="fingerprint-chromium"
FC_VERSION="136.0.7103.113"

# Functions
cleanup() {
    log_info "Cleaning up..."
    docker-compose down --remove-orphans 2>/dev/null || true
    docker rmi "${IMAGE_NAME}:latest" 2>/dev/null || true
}

build_image() {
    log_header "Building Docker Image"
    
    log_info "Building ${IMAGE_NAME} with fingerprint-chromium ${FC_VERSION}..."
    docker build -f Dockerfile -t "${IMAGE_NAME}:latest" \
        --build-arg FC_VERSION="${FC_VERSION}" \
        --progress=plain \
        .
    
    if [ $? -eq 0 ]; then
        log_success "Image built successfully!"
    else
        log_error "Image build failed!"
        exit 1
    fi
}

analyze_image() {
    log_header "Analyzing Image"
    
    # Get image size
    local size=$(docker images --format "{{.Size}}" "${IMAGE_NAME}:latest")
    local size_bytes=$(docker inspect --format='{{.Size}}' "${IMAGE_NAME}:latest")
    local layers=$(docker history --format "{{.ID}}" "${IMAGE_NAME}:latest" | wc -l)
    
    log_info "Image analysis:"
    echo "  Name: ${IMAGE_NAME}:latest"
    echo "  Size: $size"
    echo "  Layers: $layers"
    
    # Show largest layers
    echo
    log_info "Largest layers:"
    docker history --format "table {{.Size}}\t{{.CreatedBy}}" "${IMAGE_NAME}:latest" | \
        grep -v "0B" | head -5
}

test_container() {
    log_header "Testing Container"
    
    # Set PUID/PGID
    export PUID=$(id -u)
    export PGID=$(id -g)
    
    log_info "Starting container with PUID=${PUID}, PGID=${PGID}..."
    docker-compose up -d fingerprint-chromium
    
    # Wait for container to be ready
    log_info "Waiting for container to be ready..."
    for i in {1..60}; do
        if docker-compose ps | grep -q "Up"; then
            log_success "Container is running"
            break
        fi
        if [ $i -eq 60 ]; then
            log_error "Container failed to start within 60 seconds"
            docker-compose logs
            exit 1
        fi
        sleep 1
    done
    
    # Test Chrome DevTools API
    log_info "Testing Chrome DevTools API..."
    sleep 10  # Give Chrome time to start
    
    for i in {1..30}; do
        if curl -sf http://localhost:9222/json/version >/dev/null 2>&1; then
            log_success "Chrome DevTools API is responding"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Chrome DevTools API is not responding"
            docker-compose logs
            exit 1
        fi
        sleep 2
    done
    
    # Show Chrome version info
    local version_info=$(curl -s http://localhost:9222/json/version 2>/dev/null || echo "{}")
    echo "Chrome version info:"
    echo "$version_info" | jq . 2>/dev/null || echo "$version_info"
    
    # Test noVNC web interface
    log_info "Testing noVNC web interface..."
    if curl -sf http://localhost:6081 >/dev/null 2>&1; then
        log_success "noVNC web interface is accessible"
    else
        log_warning "noVNC web interface is not accessible (may not be available)"
    fi
    
    # Show container logs
    log_info "Container logs (last 20 lines):"
    docker-compose logs --tail=20
}

show_usage() {
    log_header "Usage Information"
    
    echo "Container is running and ready to use!"
    echo
    echo "Access methods:"
    echo "  🌐 noVNC Web Interface: http://localhost:6081"
    echo "  🖥️  VNC Client: localhost:5901 (password: changeme)"
    echo "  🔧 Chrome DevTools: http://localhost:9222"
    echo
    echo "Environment variables used:"
    echo "  PUID: $(id -u)"
    echo "  PGID: $(id -g)"
    echo "  FINGERPRINT_SEED: 2025"
    echo "  BROWSER_LANG: zh-CN"
    echo
    echo "Data directories:"
    echo "  Chrome Data: ./chrome-data"
    echo "  Chrome Profiles: ./chrome-profiles"
    echo
    echo "Commands:"
    echo "  Stop: docker-compose down"
    echo "  Logs: docker-compose logs -f"
    echo "  Shell: docker-compose exec fingerprint-chromium bash"
}

# Main execution
main() {
    log_header "Fingerprint Chromium Docker Build & Test"
    
    case "${1:-build}" in
        "clean")
            cleanup
            ;;
        "build")
            build_image
            analyze_image
            ;;
        "test")
            test_container
            show_usage
            ;;
        "all")
            cleanup
            build_image
            analyze_image
            test_container
            show_usage
            ;;
        *)
            echo "Usage: $0 [clean|build|test|all]"
            echo "  clean - Clean up containers and images"
            echo "  build - Build the Docker image"
            echo "  test  - Test the container"
            echo "  all   - Clean, build, and test (default)"
            exit 1
            ;;
    esac
}

# Check dependencies
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1; then
    log_error "docker-compose is not installed or not in PATH"
    exit 1
fi

# Run main function
main "$@"
