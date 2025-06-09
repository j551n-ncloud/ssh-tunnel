#!/bin/bash
# ssh-tunnel-manager.sh - Unified SSH tunnel creation and management script

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly CONFIG_FILE="$HOME/.ssh-tunnel-config"
readonly LOG_FILE="$HOME/.ssh-tunnel.log"
readonly TUNNEL_STATE_FILE="$HOME/.ssh-tunnels-state"

# Default values
DEFAULT_BASE_PORT=8443
DEFAULT_JUMP_HOST="jumphost"
DEFAULT_USER="username"
DEFAULT_TARGET_PORT=443

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Global variables
declare -A TUNNEL_INFO
START_PORT=$DEFAULT_BASE_PORT
END_PORT=8500

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Colored output functions
error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
    log "ERROR: $*"
}

success() {
    echo -e "${GREEN}SUCCESS: $*${NC}"
    log "SUCCESS: $*"
}

warning() {
    echo -e "${YELLOW}WARNING: $*${NC}"
    log "WARNING: $*"
}

info() {
    echo -e "${BLUE}INFO: $*${NC}"
    log "INFO: $*"
}

header() {
    echo -e "${CYAN}$*${NC}"
}

prompt() {
    echo -e "${MAGENTA}$*${NC}"
}

# Usage function
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [COMMAND] [OPTIONS]

Unified SSH tunnel creation and management script.

COMMANDS:
    create [FQDN...]           Create new SSH tunnel(s) (default)
    list, ls, status           List all active tunnels
    close PORT                 Close tunnel on specific port
    close-all, kill-all        Close all active tunnels
    clean                      Clean up stale tunnel records
    config                     Create/edit configuration file
    interactive, menu          Interactive menu mode

CREATE OPTIONS:
    -s, --silent              Silent mode (no interactive prompts)
    -p, --port PORT           Specify base local port (default: $DEFAULT_BASE_PORT)
    -j, --jumphost HOST       Jump host hostname
    -u, --user USER           SSH username
    -t, --target-port PORT    Target port on servers (default: $DEFAULT_TARGET_PORT)
    -d, --daemon              Run as daemon (background process)
    --dry-run                 Show what would be executed without running
    --batch FILE              Create tunnels from batch file

MANAGEMENT OPTIONS:
    -v, --verbose             Verbose output
    -q, --quiet               Quiet mode (minimal output)
    --no-confirm              Skip confirmation prompts
    --port-range START-END    Specify port range to check (default: $START_PORT-$END_PORT)

GLOBAL OPTIONS:
    -h, --help               Show this help message

EXAMPLES:
    $SCRIPT_NAME                                    # Interactive single tunnel
    $SCRIPT_NAME create idrac1.com idrac2.com      # Create multiple tunnels
    $SCRIPT_NAME -s -j myhost -u user idrac.com    # Silent mode
    $SCRIPT_NAME list                               # Show active tunnels
    $SCRIPT_NAME close 8443                         # Close specific tunnel
    $SCRIPT_NAME interactive                        # Interactive menu
    $SCRIPT_NAME --batch tunnels.txt               # Batch creation

BATCH FILE FORMAT:
    # Lines starting with # are comments
    idrac1.example.com
    idrac2.example.com:8444  # Custom target port
    idrac3.example.com --port 9000  # Custom local port base

EOF
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        if [[ "${VERBOSE_MODE:-false}" == "true" ]]; then
            info "Configuration loaded from $CONFIG_FILE"
        fi
    fi
}

# Create configuration file
create_config() {
    info "Setting up configuration file at $CONFIG_FILE"
    echo
    
    read -p "Jump host hostname [$DEFAULT_JUMP_HOST]: " jump_host
    jump_host=${jump_host:-$DEFAULT_JUMP_HOST}
    
    read -p "SSH username [$DEFAULT_USER]: " user
    user=${user:-$DEFAULT_USER}
    
    read -p "Base local port [$DEFAULT_BASE_PORT]: " base_port
    base_port=${base_port:-$DEFAULT_BASE_PORT}
    
    read -p "Target port [$DEFAULT_TARGET_PORT]: " target_port
    target_port=${target_port:-$DEFAULT_TARGET_PORT}
    
    cat > "$CONFIG_FILE" << EOF
# SSH Tunnel Configuration
JUMP_HOST="$jump_host"
USER="$user"
BASE_PORT=$base_port
TARGET_PORT=$target_port
EOF
    
    success "Configuration saved to $CONFIG_FILE"
    
    read -p "Would you like to create a tunnel now? (y/N): " create_now
    if [[ "$create_now" =~ ^[Yy]$ ]]; then
        echo
        create_tunnel_interactive
    fi
}

# Validate inputs
validate_inputs() {
    local fqdn="$1"
    
    if [[ -z "$fqdn" ]]; then
        error "FQDN is required"
        return 1
    fi
    
    # Validate FQDN format
    if ! [[ "$fqdn" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        error "Invalid FQDN format: $fqdn"
        return 1
    fi
    
    # Validate port numbers
    if ! [[ "$BASE_PORT" =~ ^[0-9]+$ ]] || (( BASE_PORT < 1024 || BASE_PORT > 65535 )); then
        error "Invalid base port: $BASE_PORT (must be between 1024-65535)"
        return 1
    fi
    
    if ! [[ "$TARGET_PORT" =~ ^[0-9]+$ ]] || (( TARGET_PORT < 1 || TARGET_PORT > 65535 )); then
        error "Invalid target port: $TARGET_PORT (must be between 1-65535)"
        return 1
    fi
    
    return 0
}

# Check if port is available
is_port_available() {
    local port=$1
    ! lsof -i ":$port" >/dev/null 2>&1
}

# Find available port
find_available_port() {
    local start_port=${1:-$BASE_PORT}
    local port=$start_port
    local max_attempts=100
    local attempts=0
    
    while ! is_port_available "$port" && (( attempts < max_attempts )); do
        ((port++))
        ((attempts++))
    done
    
    if (( attempts >= max_attempts )); then
        error "Could not find available port after $max_attempts attempts starting from $start_port"
        return 1
    fi
    
    echo "$port"
}

# Test SSH connectivity
test_ssh_connection() {
    if [[ "${SILENT_MODE:-false}" == "true" ]]; then
        return 0
    fi
    
    info "Testing SSH connection to $USER@$JUMP_HOST..."
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$USER@$JUMP_HOST" exit 2>/dev/null; then
        success "SSH connection test successful"
        return 0
    else
        warning "SSH connection test failed - you may need to enter password/key passphrase"
        return 1
    fi
}

# Save tunnel state
save_tunnel_state() {
    local local_port=$1
    local target_host=$2
    local target_port=$3
    local pid=$4
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$local_port|$target_host|$target_port|$pid|$timestamp|$USER@$JUMP_HOST" >> "$TUNNEL_STATE_FILE"
}

# Create single SSH tunnel
create_single_tunnel() {
    local target_host="$1"
    local custom_target_port="${2:-$TARGET_PORT}"
    local custom_local_port="${3:-}"
    
    if ! validate_inputs "$target_host"; then
        return 1
    fi
    
    local local_port
    if [[ -n "$custom_local_port" ]]; then
        if is_port_available "$custom_local_port"; then
            local_port="$custom_local_port"
        else
            warning "Port $custom_local_port is not available, finding alternative..."
            local_port=$(find_available_port "$custom_local_port") || return 1
        fi
    else
        local_port=$(find_available_port) || return 1
    fi
    
    info "Creating SSH tunnel: localhost:$local_port -> $JUMP_HOST -> $target_host:$custom_target_port"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        info "DRY RUN: Would execute: ssh -f -N -L $local_port:$target_host:$custom_target_port $USER@$JUMP_HOST"
        return 0
    fi
    
    # Create the SSH tunnel
    if ssh -f -N -L "$local_port:$target_host:$custom_target_port" "$USER@$JUMP_HOST"; then
        sleep 1  # Give SSH time to establish
        
        # Get the PID of the SSH process
        local pid
        pid=$(pgrep -f "ssh.*-L $local_port:$target_host:$custom_target_port" | head -1)
        
        if [[ -n "$pid" ]]; then
            save_tunnel_state "$local_port" "$target_host" "$custom_target_port" "$pid"
            success "Tunnel established: https://localhost:$local_port -> $target_host:$custom_target_port (PID: $pid)"
            return 0
        else
            error "Tunnel created but couldn't find PID for $target_host"
            return 1
        fi
    else
        error "Failed to create SSH tunnel for $target_host"
        return 1
    fi
}

# Parse target specification (host:port format)
parse_target() {
    local target="$1"
    local host port
    
    if [[ "$target" =~ ^(.+):([0-9]+)$ ]]; then
        host="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"
    else
        host="$target"
        port="$TARGET_PORT"
    fi
    
    echo "$host $port"
}

# Create multiple tunnels
create_multiple_tunnels() {
    local targets=("$@")
    local created=0
    local failed=0
    local total=${#targets[@]}
    
    if [[ $total -eq 1 ]] && [[ "${SILENT_MODE:-false}" != "true" ]]; then
        # Single tunnel - run connectivity test
        test_ssh_connection || true
    elif [[ $total -gt 1 ]]; then
        info "Creating $total SSH tunnels..."
        if [[ "${SILENT_MODE:-false}" != "true" ]]; then
            test_ssh_connection || true
        fi
    fi
    
    for target in "${targets[@]}"; do
        read -r host port <<< "$(parse_target "$target")"
        
        if create_single_tunnel "$host" "$port"; then
            ((created++))
        else
            ((failed++))
        fi
        
        # Small delay between tunnel creations
        if [[ $total -gt 1 ]] && [[ $created -lt $total ]]; then
            sleep 0.5
        fi
    done
    
    if [[ $total -gt 1 ]]; then
        echo
        if [[ $created -gt 0 ]]; then
            success "Successfully created $created tunnel(s)"
        fi
        if [[ $failed -gt 0 ]]; then
            error "Failed to create $failed tunnel(s)"
            return 1
        fi
    fi
    
    return 0
}

# Create tunnels from batch file
create_from_batch_file() {
    local batch_file="$1"
    
    if [[ ! -f "$batch_file" ]]; then
        error "Batch file not found: $batch_file"
        return 1
    fi
    
    local targets=()
    local line_num=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove inline comments
        line=$(echo "$line" | sed 's/[[:space:]]*#.*$//')
        
        # Parse line for additional options
        if [[ "$line" =~ --port[[:space:]]+([0-9]+) ]]; then
            local custom_port="${BASH_REMATCH[1]}"
            line=$(echo "$line" | sed 's/--port[[:space:]]*[0-9]*//g')
            line="$line:$custom_port"
        fi
        
        targets+=("$line")
    done < "$batch_file"
    
    if [[ ${#targets[@]} -eq 0 ]]; then
        warning "No valid targets found in batch file"
        return 1
    fi
    
    info "Found ${#targets[@]} target(s) in batch file"
    create_multiple_tunnels "${targets[@]}"
}

# Interactive tunnel creation
create_tunnel_interactive() {
    local targets=()
    
    while true; do
        echo
        prompt "Enter target server FQDN (or press Enter if done): "
        read -r target
        
        if [[ -z "$target" ]]; then
            break
        fi
        
        # Ask for custom target port
        read -p "Target port [$TARGET_PORT]: " custom_target_port
        custom_target_port=${custom_target_port:-$TARGET_PORT}
        
        if [[ "$custom_target_port" != "$TARGET_PORT" ]]; then
            target="$target:$custom_target_port"
        fi
        
        targets+=("$target")
        
        success "Added: $target"
        
        read -p "Add another tunnel? (Y/n): " add_more
        if [[ "$add_more" =~ ^[Nn]$ ]]; then
            break
        fi
    done
    
    if [[ ${#targets[@]} -eq 0 ]]; then
        warning "No targets specified"
        return 1
    fi
    
    create_multiple_tunnels "${targets[@]}"
}

# Get tunnel info from state file
get_tunnel_info() {
    local port="$1"
    if [[ -f "$TUNNEL_STATE_FILE" ]]; then
        grep "^$port|" "$TUNNEL_STATE_FILE" | tail -1
    fi
}

# Check if process is running
is_process_running() {
    local pid="$1"
    kill -0 "$pid" 2>/dev/null
}

# Get active tunnels
get_active_tunnels() {
    local -A tunnel_info
    local active_ports=()
    
    for port in $(seq "$START_PORT" "$END_PORT"); do
        local pid
        pid=$(lsof -ti ":$port" 2>/dev/null || true)
        
        if [[ -n "$pid" ]]; then
            local cmd
            cmd=$(ps -p "$pid" -o comm= 2>/dev/null || true)
            
            if [[ "$cmd" == "ssh" ]]; then
                active_ports+=("$port")
                
                local state_info
                state_info=$(get_tunnel_info "$port")
                
                if [[ -n "$state_info" ]]; then
                    IFS='|' read -r _ target_host target_port _ timestamp jump_host <<< "$state_info"
                    tunnel_info["$port"]="$pid|$target_host|$target_port|$timestamp|$jump_host"
                else
                    tunnel_info["$port"]="$pid|unknown|unknown|unknown|unknown"
                fi
            fi
        fi
    done
    
    printf '%s\n' "${active_ports[@]}" | sort -n
    
    # Store in global array
    TUNNEL_INFO=()
    for port in "${active_ports[@]}"; do
        TUNNEL_INFO["$port"]="${tunnel_info["$port"]}"
    done
}

# Display tunnel status
show_tunnel_status() {
    header "=== SSH Tunnel Status ==="
    echo
    
    local active_ports
    mapfile -t active_ports < <(get_active_tunnels)
    
    if [[ ${#active_ports[@]} -eq 0 ]]; then
        info "No active SSH tunnels found"
        return 0
    fi
    
    printf "%-6s %-6s %-25s %-6s %-15s %-20s %s\n" "PORT" "PID" "TARGET" "T-PORT" "CREATED" "JUMP HOST" "URL"
    printf "%s\n" "$(printf '=%.0s' {1..110})"
    
    for port in "${active_ports[@]}"; do
        IFS='|' read -r pid target_host target_port timestamp jump_host <<< "${TUNNEL_INFO["$port"]}"
        
        # Format timestamp
        if [[ "$timestamp" != "unknown" ]]; then
            formatted_time=$(date -d "$timestamp" "+%m/%d %H:%M" 2>/dev/null || echo "$timestamp")
        else
            formatted_time="unknown"
        fi
        
        # Truncate long hostnames
        if [[ ${#target_host} -gt 24 ]]; then
            target_host="${target_host:0:21}..."
        fi
        
        printf "%-6s %-6s %-25s %-6s %-15s %-20s %s\n" \
            "$port" "$pid" "$target_host" "$target_port" "$formatted_time" "$jump_host" "https://localhost:$port"
    done
    
    echo
    success "${#active_ports[@]} active tunnel(s) found"
}

# Close specific tunnel
close_tunnel() {
    local target_port="$1"
    
    if ! [[ "$target_port" =~ ^[0-9]+$ ]]; then
        error "Invalid port number: $target_port"
        return 1
    fi
    
    local pid
    pid=$(lsof -ti ":$target_port" 2>/dev/null || true)
    
    if [[ -z "$pid" ]]; then
        warning "No active tunnel found on port $target_port"
        return 1
    fi
    
    local cmd
    cmd=$(ps -p "$pid" -o comm= 2>/dev/null || true)
    
    if [[ "$cmd" != "ssh" ]]; then
        error "Process on port $target_port (PID: $pid) is not an SSH tunnel"
        return 1
    fi
    
    info "Closing tunnel on port $target_port (PID: $pid)..."
    
    if kill "$pid" 2>/dev/null; then
        sleep 1
        
        if is_process_running "$pid"; then
            warning "Process still running, sending SIGKILL..."
            kill -9 "$pid" 2>/dev/null || true
        fi
        
        success "Tunnel on port $target_port closed"
        
        # Remove from state file
        if [[ -f "$TUNNEL_STATE_FILE" ]]; then
            sed -i "/^$target_port|/d" "$TUNNEL_STATE_FILE"
        fi
    else
        error "Failed to close tunnel on port $target_port"
        return 1
    fi
}

# Close all tunnels
close_all_tunnels() {
    local active_ports
    mapfile -t active_ports < <(get_active_tunnels)
    
    if [[ ${#active_ports[@]} -eq 0 ]]; then
        info "No active SSH tunnels to close"
        return 0
    fi
    
    if [[ "${NO_CONFIRM:-false}" != "true" ]]; then
        echo -e "${YELLOW}Found ${#active_ports[@]} active tunnel(s):${NC}"
        for port in "${active_ports[@]}"; do
            IFS='|' read -r pid target_host _ _ _ <<< "${TUNNEL_INFO["$port"]}"
            echo "  - Port $port -> $target_host (PID: $pid)"
        done
        echo
        
        read -p "Close all tunnels? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "Cancelled"
            return 0
        fi
    fi
    
    local closed=0
    local failed=0
    
    for port in "${active_ports[@]}"; do
        if close_tunnel "$port"; then
            ((closed++))
        else
            ((failed++))
        fi
    done
    
    if [[ $closed -gt 0 ]]; then
        success "Closed $closed tunnel(s)"
    fi
    
    if [[ $failed -gt 0 ]]; then
        error "Failed to close $failed tunnel(s)"
        return 1
    fi
}

# Clean stale records
clean_stale_records() {
    if [[ ! -f "$TUNNEL_STATE_FILE" ]]; then
        info "No state file found"
        return 0
    fi
    
    local temp_file
    temp_file=$(mktemp)
    local cleaned=0
    
    while IFS='|' read -r port target_host target_port pid timestamp jump_host; do
        if [[ -n "$pid" ]] && is_process_running "$pid"; then
            echo "$port|$target_host|$target_port|$pid|$timestamp|$jump_host" >> "$temp_file"
        else
            ((cleaned++))
        fi
    done < "$TUNNEL_STATE_FILE"
    
    if [[ $cleaned -gt 0 ]]; then
        mv "$temp_file" "$TUNNEL_STATE_FILE"
        success "Cleaned $cleaned stale record(s)"
    else
        rm -f "$temp_file"
        info "No stale records found"
    fi
}

# Interactive menu
interactive_menu() {
    while true; do
        clear
        header "=== SSH Tunnel Manager ==="
        echo
        echo "1) Create new tunnel(s)"
        echo "2) Show tunnel status"
        echo "3) Close specific tunnel"
        echo "4) Close all tunnels"
        echo "5) Clean stale records"
        echo "6) Configuration"
        echo "7) Exit"
        echo
        
        read -p "Select option [1-7]: " choice
        
        case $choice in
            1)
                echo
                create_tunnel_interactive
                read -p "Press Enter to continue..."
                ;;
            2)
                echo
                show_tunnel_status
                read -p "Press Enter to continue..."
                ;;
            3)
                echo
                show_tunnel_status
                echo
                read -p "Enter port number to close: " port
                if [[ -n "$port" ]]; then
                    close_tunnel "$port"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                echo
                close_all_tunnels
                read -p "Press Enter to continue..."
                ;;
            5)
                echo
                clean_stale_records
                read -p "Press Enter to continue..."
                ;;
            6)
                echo
                create_config
                read -p "Press Enter to continue..."
                ;;
            7)
                info "Goodbye!"
                exit 0
                ;;
            *)
                error "Invalid choice: $choice"
                sleep 1
                ;;
        esac
    done
}

# Main function
main() {
    # Initialize defaults
    BASE_PORT=$DEFAULT_BASE_PORT
    JUMP_HOST=$DEFAULT_JUMP_HOST
    USER=$DEFAULT_USER
    TARGET_PORT=$DEFAULT_TARGET_PORT
    COMMAND="create"
    SILENT_MODE=false
    DAEMON_MODE=false
    DRY_RUN=false
    VERBOSE_MODE=false
    QUIET_MODE=false
    NO_CONFIRM=false
    BATCH_FILE=""
    
    # Load configuration
    load_config
    
    # Parse arguments
    local targets=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            create)
                COMMAND="create"
                shift
                ;;
            list|ls|status)
                COMMAND="list"
                shift
                ;;
            close)
                COMMAND="close"
                if [[ $# -lt 2 ]]; then
                    error "Port number required for close command"
                    exit 1
                fi
                TARGET_PORT_TO_CLOSE="$2"
                shift 2
                ;;
            close-all|kill-all)
                COMMAND="close-all"
                shift
                ;;
            clean)
                COMMAND="clean"
                shift
                ;;
            config)
                COMMAND="config"
                shift
                ;;
            interactive|menu)
                COMMAND="interactive"
                shift
                ;;
            -s|--silent)
                SILENT_MODE=true
                shift
                ;;
            -p|--port)
                BASE_PORT="$2"
                shift 2
                ;;
            -j|--jumphost)
                JUMP_HOST="$2"
                shift 2
                ;;
            -u|--user)
                USER="$2"
                shift 2
                ;;
            -t|--target-port)
                TARGET_PORT="$2"
                shift 2
                ;;
            -d|--daemon)
                DAEMON_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            --no-confirm)
                NO_CONFIRM=true
                shift
                ;;
            --batch)
                BATCH_FILE="$2"
                shift 2
                ;;
            --port-range)
                if [[ "$2" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    START_PORT="${BASH_REMATCH[1]}"
                    END_PORT="${BASH_REMATCH[2]}"
                else
                    error "Invalid port range format: $2"
                    exit 1
                fi
                shift 2
                ;;
            -*)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                targets+=("$1")
                shift
                ;;
        esac
    done
    
    # Execute command
    case $COMMAND in
        create)
            if [[ -n "$BATCH_FILE" ]]; then
                create_from_batch_file "$BATCH_FILE"
            elif [[ ${#targets[@]} -gt 0 ]]; then
                create_multiple_tunnels "${targets[@]}"
            elif [[ "$SILENT_MODE" == "true" ]]; then
                error "No targets specified in silent mode"
                exit 1
            else
                create_tunnel_interactive
            fi
            ;;
        list)
            show_tunnel_status
            ;;
        close)
            close_tunnel "$TARGET_PORT_TO_CLOSE"
            ;;
        close-all)
            close_all_tunnels
            ;;
        clean)
            clean_stale_records
            ;;
        config)
            create_config
            ;;
        interactive)
            interactive_menu
            ;;
        *)
            error "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
}

# Cleanup on exit
cleanup() {
    info "Script interrupted"
    exit 130
}

trap cleanup SIGINT SIGTERM

# Run main
main "$@"
