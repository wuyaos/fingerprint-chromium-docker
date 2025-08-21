#!/bin/bash
# Browser cache cleanup script
# Runs periodically to clean browser cache and temporary files

set -euo pipefail

# Configuration
USER_DIR=${USER_DIR:-/data}
TEMP_DIR="/tmp"
LOG_FILE="/var/log/cache-cleanup.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to get directory size in MB
get_size_mb() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sm "$dir" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

# Function to clean Chrome cache
clean_chrome_cache() {
    local cache_dirs=(
        "$USER_DIR/Default/Cache"
        "$USER_DIR/Default/Code Cache"
        "$USER_DIR/Default/GPUCache"
        "$USER_DIR/Default/Service Worker/CacheStorage"
        "$USER_DIR/Default/Application Cache"
        "$USER_DIR/Default/IndexedDB"
        "$USER_DIR/Default/Local Storage"
        "$USER_DIR/Default/Session Storage"
        "$USER_DIR/ShaderCache"
        "$USER_DIR/GrShaderCache"
    )
    
    local total_cleaned=0
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [ -d "$cache_dir" ]; then
            local size_before=$(get_size_mb "$cache_dir")
            sudo find "$cache_dir" -type f -mtime +1 -delete 2>/dev/null || true
            sudo find "$cache_dir" -type d -empty -delete 2>/dev/null || true
            local size_after=$(get_size_mb "$cache_dir")
            local cleaned=$((size_before - size_after))
            total_cleaned=$((total_cleaned + cleaned))
            if [ $cleaned -gt 0 ]; then
                log_message "Cleaned $cleaned MB from $(basename "$cache_dir")"
            fi
        fi
    done
    
    echo $total_cleaned
}

# Function to clean temporary files
clean_temp_files() {
    local temp_dirs=(
        "$TEMP_DIR"
        "/var/tmp"
        "$USER_DIR/Default/Downloads"
    )
    
    local total_cleaned=0
    
    for temp_dir in "${temp_dirs[@]}"; do
        if [ -d "$temp_dir" ]; then
            local size_before=$(get_size_mb "$temp_dir")
            # Clean files older than 24 hours
            sudo find "$temp_dir" -type f -mtime +1 -name "*.tmp" -delete 2>/dev/null || true
            sudo find "$temp_dir" -type f -mtime +1 -name "*.log" -delete 2>/dev/null || true
            sudo find "$temp_dir" -type f -mtime +7 -delete 2>/dev/null || true
            local size_after=$(get_size_mb "$temp_dir")
            local cleaned=$((size_before - size_after))
            total_cleaned=$((total_cleaned + cleaned))
            if [ $cleaned -gt 0 ]; then
                log_message "Cleaned $cleaned MB from $(basename "$temp_dir")"
            fi
        fi
    done
    
    echo $total_cleaned
}

# Function to clean system logs
clean_system_logs() {
    local log_dirs=(
        "/var/log"
        "/tmp"
    )
    
    local total_cleaned=0
    
    for log_dir in "${log_dirs[@]}"; do
        if [ -d "$log_dir" ]; then
            local size_before=$(get_size_mb "$log_dir")
            # Clean log files older than 7 days
            sudo find "$log_dir" -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
            sudo find "$log_dir" -name "*.log.*" -type f -mtime +3 -delete 2>/dev/null || true
            local size_after=$(get_size_mb "$log_dir")
            local cleaned=$((size_before - size_after))
            total_cleaned=$((total_cleaned + cleaned))
            if [ $cleaned -gt 0 ]; then
                log_message "Cleaned $cleaned MB from $(basename "$log_dir") logs"
            fi
        fi
    done
    
    echo $total_cleaned
}

# Main cleanup function
main() {
    log_message "Starting cache cleanup..."
    
    # Get initial disk usage
    local disk_before=$(df / | tail -1 | awk '{print $3}')
    
    # Clean different types of cache
    local chrome_cleaned=$(clean_chrome_cache)
    local temp_cleaned=$(clean_temp_files)
    local logs_cleaned=$(clean_system_logs)
    
    # Calculate total cleaned
    local total_cleaned=$((chrome_cleaned + temp_cleaned + logs_cleaned))
    
    # Get final disk usage
    local disk_after=$(df / | tail -1 | awk '{print $3}')
    local disk_freed=$((disk_before - disk_after))
    
    log_message "Cleanup completed:"
    log_message "  Chrome cache: ${chrome_cleaned} MB"
    log_message "  Temp files: ${temp_cleaned} MB"
    log_message "  System logs: ${logs_cleaned} MB"
    log_message "  Total freed: ${disk_freed} KB"
    
    # Restart Chrome if it's running and significant cache was cleaned
    if [ $chrome_cleaned -gt 100 ] && pgrep -f "chrome" > /dev/null; then
        log_message "Significant cache cleaned, Chrome restart recommended"
    fi
}

# Run main function
main "$@"
