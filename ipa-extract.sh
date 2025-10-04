#!/usr/bin/env bash
set -euo pipefail

readonly SSH_USER="root"
readonly SSH_PASS="alpine"
readonly SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' 

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
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Display usage information
show_usage() {
    cat << EOF
Usage: $0 <IP_ADDRESS> <APP_NAME_FRAGMENT> <OUTPUT_FILENAME.ipa>

Description:
    Extract iOS application bundle from jailbroken device and create IPA file

Arguments:
    IP_ADDRESS         Target device IP address
    APP_NAME_FRAGMENT  Partial application name to search for
    OUTPUT_FILENAME    Desired output IPA filename

Examples:
    $0 10.0.0.38 "Runner" teste.ipa
    $0 192.168.1.100 "WhatsApp" whatsapp.ipa

Requirements:
    - sshpass utility must be installed
    - SSH access to target device with root privileges
    - Target device must be jailbroken

EOF
}


validate_arguments() {
    if [ "$#" -ne 3 ]; then
        log_error "Invalid number of arguments"
        show_usage
        exit 1
    fi


    if ! [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "Invalid IP address format: $1"
        exit 1
    fi

    # Validate output filename
    if [[ ! "$3" =~ \.ipa$ ]]; then
        log_error "Output filename must have .ipa extension"
        exit 1
    fi
}


check_dependencies() {
    if ! command -v sshpass >/dev/null 2>&1; then
        log_error "sshpass utility not found"
        log_info "Install with: sudo apt install sshpass (Ubuntu/Debian) or brew install hudochenkov/sshpass/sshpass (macOS)"
        log_info "Alternatively, configure SSH key authentication"
        exit 2
    fi
}


execute_ssh() {
    local cmd="$1"
    if ! sshpass -p "$SSH_PASS" ssh $SSH_OPTS "$SSH_USER@$IP" "$cmd" 2>/dev/null; then
        log_error "SSH command failed: $cmd"
        exit 3
    fi
}


copy_from_remote() {
    local remote_path="$1"
    local local_path="$2"
    if ! sshpass -p "$SSH_PASS" scp $SSH_OPTS "$SSH_USER@$IP:$remote_path" "$local_path" 2>/dev/null; then
        log_error "Failed to copy file from remote device"
        exit 4
    fi
}


test_connectivity() {
    log_info "Testing SSH connectivity to $IP..."
    if ! execute_ssh "echo 'Connection successful'" >/dev/null 2>&1; then
        log_error "Cannot establish SSH connection to $IP"
        log_info "Verify device IP, SSH service, and credentials"
        exit 5
    fi
    log_success "SSH connection established"
}


locate_application() {
    log_info "Searching for application containing: '$APP_QUERY'"
    
    local raw_apps
    raw_apps=$(execute_ssh "find /var/containers/Bundle/Application -type d -name '*.app' -print 2>/dev/null || true")

    if [ -z "$raw_apps" ]; then
        log_error "No application bundles found in /var/containers/Bundle/Application"
        log_info "Verify device is jailbroken and applications are installed"
        exit 6
    fi

    local matched_app
    matched_app=$(printf "%s\n" "$raw_apps" | grep -i -- "$APP_QUERY" | head -n1 || true)

    if [ -z "$matched_app" ]; then
        log_error "No application found matching fragment: '$APP_QUERY'"
        log_info "Available applications:"
        printf "%s\n" "$raw_apps" | nl -ba -v1 -w2 -s': '
        exit 7
    fi

    APP_PATH="$matched_app"
    APP_BASENAME=$(basename "$APP_PATH")
    log_success "Found application: $APP_PATH"
    log_info "Application basename: $APP_BASENAME"
}


prepare_extraction() {
    log_info "Preparing extraction environment on remote device"

    execute_ssh "rm -rf '$REMOTE_TMP_DIR'" >/dev/null 2>&1 || true
    
    execute_ssh "mkdir -p '$REMOTE_TMP_DIR/Payload' && chmod 700 '$REMOTE_TMP_DIR'"
    
    log_success "Extraction environment prepared"
}

copy_application() {
    log_info "Copying application bundle to extraction directory"
    
    if ! execute_ssh "cp -a '$APP_PATH' '$REMOTE_TMP_DIR/Payload/'"; then
        log_error "Failed to copy application bundle"
        exit 8
    fi
    
    log_success "Application bundle copied successfully"
}

create_ipa() {
    log_info "Creating IPA archive: $OUTPUT_IPA"
    
    local zip_cmd="cd '$REMOTE_TMP_DIR' && ("
    zip_cmd+="command -v zip >/dev/null 2>&1 && zip -qr '$OUTPUT_IPA' Payload || "
    zip_cmd+="(command -v busybox >/dev/null 2>&1 && busybox zip -qr '$OUTPUT_IPA' Payload) "
    zip_cmd+=") || { echo 'zip-failed' >&2; exit 9; }"
    
    if ! execute_ssh "$zip_cmd"; then
        log_error "Failed to create IPA archive"
        log_info "Ensure zip utility is available on target device"
        exit 9
    fi
    
    log_success "IPA archive created successfully"
}

verify_ipa() {
    log_info "Verifying IPA archive creation"
    
    local file_info
    file_info=$(sshpass -p "$SSH_PASS" ssh $SSH_OPTS "$SSH_USER@$IP" "ls -l '$REMOTE_TMP_DIR'" 2>/dev/null)
    echo "$file_info"
    
    if ! execute_ssh "test -f '$REMOTE_TMP_DIR/$OUTPUT_IPA'"; then
        log_error "IPA file not found after creation"
        exit 10
    fi
    
    log_success "IPA archive verified"
}

download_ipa() {
    log_info "Downloading IPA file to local system"
    
    if ! copy_from_remote "$REMOTE_TMP_DIR/$OUTPUT_IPA" "./$OUTPUT_IPA"; then
        log_error "Failed to download IPA file"
        exit 11
    fi
    
    log_success "IPA file downloaded: $(pwd)/$OUTPUT_IPA"
}

cleanup_remote() {
    log_info "Cleaning up remote temporary files"
    
    execute_ssh "rm -rf '$REMOTE_TMP_DIR'" >/dev/null 2>&1 || true
    
    log_success "Remote cleanup completed"
}

show_summary() {
    local file_size
    file_size=$(ls -lh "$OUTPUT_IPA" 2>/dev/null | awk '{print $5}' || echo "Unknown")
    
    echo
    log_success "Extraction completed successfully"
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│                    EXTRACTION SUMMARY                       │"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│ Target Device: $IP"
    echo "│ Application:   $APP_BASENAME"
    echo "│ Output File:   $(pwd)/$OUTPUT_IPA"
    echo "│ File Size:     $file_size"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo
}

main() {

    IP="$1"
    APP_QUERY="$2"
    OUTPUT_IPA="$3"
    REMOTE_TMP_DIR="/var/root/extract_ipa_tmp_$(date +%s)"
    
    APP_PATH=""
    APP_BASENAME=""
    
    validate_arguments "$@"
    
    check_dependencies
    
    test_connectivity
    
    locate_application
    
    prepare_extraction
    
    copy_application
    
    create_ipa
    
    verify_ipa
    
    download_ipa
    
    cleanup_remote
    
    show_summary
}

main "$@"
