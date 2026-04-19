#!/bin/bash
# =============================================================================
# Script: initial-server-setup.sh
# Description: Initial server setup script for Debian/Ubuntu
# Configures: APT repositories, DNS servers, NTP synchronization
# =============================================================================

set -euo pipefail  # Strict mode: exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging setup
LOG_FILE="/var/log/initial-server-setup.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

# =============================================================================
# Configuration Variables (EDIT THESE AS NEEDED)
# =============================================================================

# DNS Servers (Cloudflare and Google as defaults - fastest and most reliable)
# Format: "nameserver IP" lines
DNS_SERVERS="nameserver 77.88.8.8 
nameserver 77.88.8.1"

# NTP Servers (pool.ntp.org with specific country pool if needed)
# Using Debian's default NTP pool with specific zones
NTP_SERVERS="0.ru.pool.ntp.org
1.ru.pool.ntp.org
ntp2.vniiftri.ru
2.debian.pool.ntp.org
3.debian.pool.ntp.org"

# APT Repository (for Debian Bookworm - adjust as needed)
# Using Yandex mirror for Russia/CIS, fallback to official Debian
APT_SOURCES="deb http://mirror.yandex.ru/debian bookworm main contrib non-free non-free-firmware
deb http://mirror.yandex.ru/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware"

# =============================================================================
# Utility Functions
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}

# =============================================================================
# 1. APT Repository Configuration
# =============================================================================

configure_apt_repositories() {
    log_step "Configuring APT repositories"
    
    # Backup existing sources.list
    backup_file "/etc/apt/sources.list"
    
    # Write new sources
    log_info "Writing APT sources to /etc/apt/sources.list"
    printf "%s\n" "$APT_SOURCES" > /etc/apt/sources.list
    
    # Install required HTTPS transport for APT
    log_info "Installing apt-transport-https and ca-certificates"
    apt-get update -qq
    apt-get install -y -qq apt-transport-https ca-certificates curl gnupg
    
    # Update package lists
    log_info "Updating package lists"
    apt-get update -qq || {
        log_warn "APT update failed, but continuing..."
    }
    
    log_info "APT repositories configured successfully"
}

# =============================================================================
# 2. DNS Configuration
# =============================================================================

configure_dns() {
    log_step "Configuring DNS servers"
    
    local resolv_conf="/etc/resolv.conf"
    local resolv_conf_head="/etc/resolv.conf.head"
    
    # Modern systems use systemd-resolved or resolvconf
    if systemctl is-active --quiet systemd-resolved; then
        log_info "systemd-resolved is active, configuring DNS via systemd-resolved"
        
        # Configure systemd-resolved
        mkdir -p /etc/systemd/resolved.conf.d/
        cat > /etc/systemd/resolved.conf.d/dns-servers.conf << EOF
[Resolve]
DNS=77.88.8.8, 77.88.8.1
FallbackDNS=77.88.8.8, 77.88.8.1
DNSSEC=allow-downgrade
Cache=yes
DNSStubListener=yes
EOF
        
        # Restart systemd-resolved
        systemctl restart systemd-resolved
        log_info "systemd-resolved configured and restarted"
        
    else
        # Traditional /etc/resolv.conf management
        log_info "Using traditional /etc/resolv.conf configuration"
        
        # Backup existing resolv.conf
        backup_file "$resolv_conf"
        
        # For systems with resolvconf package
        if command -v resolvconf >/dev/null 2>&1; then
            log_info "resolvconf detected, configuring via /etc/resolvconf/resolv.conf.d/head"
            echo "$DNS_SERVERS" > /etc/resolvconf/resolv.conf.d/head
            resolvconf -u
        else
            # Direct modification (make immutable to prevent overwrite)
            log_info "Writing DNS servers directly to $resolv_conf"
            echo "$DNS_SERVERS" > "$resolv_conf"
            
            # Make resolv.conf immutable to prevent DHCP/NetworkManager from overwriting
            chattr +i "$resolv_conf" 2>/dev/null || log_warn "Could not set immutable flag on resolv.conf"
        fi
    fi
    
    # Test DNS resolution
    log_info "Testing DNS resolution..."
    if host -W 2 google.com >/dev/null 2>&1; then
        log_info "DNS resolution working correctly"
    else
        log_warn "DNS resolution test failed. Check configuration."
    fi
}

# =============================================================================
# 3. NTP Configuration
# =============================================================================

configure_ntp() {
    log_step "Configuring NTP time synchronization"
    
    # Detect available NTP implementation
    if systemctl is-active --quiet systemd-timesyncd; then
        log_info "systemd-timesyncd is active, configuring..."
        
        # Configure systemd-timesyncd
        local timesync_conf="/etc/systemd/timesyncd.conf"
        backup_file "$timesync_conf"
        
        # Create NTP servers list for systemd-timesyncd
        NTP_LIST=$(echo "$NTP_SERVERS" | tr '\n' ' ')
        
        # Update configuration
        sed -i "s/^#NTP=/NTP=$NTP_LIST/" "$timesync_conf"
        sed -i "s/^#FallbackNTP=/FallbackNTP=0.pool.ntp.org 1.pool.ntp.org/" "$timesync_conf"
        
        # Enable and restart service
        systemctl enable systemd-timesyncd
        systemctl restart systemd-timesyncd
        
        # Check status
        sleep 2
        if timedatectl status | grep -q "synchronized: yes"; then
            log_info "Time synchronization is active"
        else
            log_warn "Time synchronization may not be working properly"
            timedatectl status
        fi
        
    elif command -v ntpd >/dev/null 2>&1; then
        log_info "NTPd detected, configuring..."
        
        # Configure NTPd
        local ntp_conf="/etc/ntp.conf"
        backup_file "$ntp_conf"
        
        # Create backup of original config
        cp "$ntp_conf" "${ntp_conf}.backup"
        
        # Write new configuration
        cat > "$ntp_conf" << EOF
# /etc/ntp.conf, configured by initial-server-setup.sh

# Use Debian pool servers
$(echo "$NTP_SERVERS" | sed 's/^/server /')

# Fallback servers
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

# Restrict access
restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1

# Drift file
driftfile /var/lib/ntp/ntp.drift
EOF
        
        # Restart NTP service
        systemctl restart ntp || service ntp restart
        
    elif command -v chronyd >/dev/null 2>&1; then
        log_info "chrony detected, configuring..."
        
        # Configure chrony
        local chrony_conf="/etc/chrony/chrony.conf"
        backup_file "$chrony_conf"
        
        # Add NTP servers
        {
            echo ""
            echo "# Added by initial-server-setup.sh"
            echo "$NTP_SERVERS" | sed 's/^/server /' | sed 's/$/ iburst/'
        } >> "$chrony_conf"
        
        # Restart chrony
        systemctl restart chrony
    else
        log_warn "No NTP implementation found. Installing systemd-timesyncd..."
        apt-get install -y -qq systemd-timesyncd
        systemctl enable systemd-timesyncd
        systemctl start systemd-timesyncd
    fi
    
    # Verify time synchronization
    log_info "Current system time: $(date)"
    log_info "Time synchronization status:"
    timedatectl status | grep -E "(NTP service|synchronized|System clock)" || true
}

# =============================================================================
# 4. System Validation
# =============================================================================

validate_system() {
    log_step "Validating system configuration"
    
    local errors=0
    
    # Check DNS
    log_info "Checking DNS resolution..."
    if nslookup google.com >/dev/null 2>&1; then
        log_info "✓ DNS is working"
    else
        log_error "✗ DNS resolution failed"
        ((errors++))
    fi
    
    # Check time synchronization
    log_info "Checking time synchronization..."
    if timedatectl status | grep -q "synchronized: yes"; then
        log_info "✓ Time is synchronized"
    else
        log_warn "Time is not synchronized (might take a few minutes)"
        # Not counting as error because it might take time to sync
    fi
    
    # Check APT repositories
    log_info "Checking APT repositories..."
    if apt-get update -qq 2>/dev/null; then
        log_info "✓ APT repositories are accessible"
    else
        log_error "✗ APT repositories have issues"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_info "All systems validated successfully!"
    else
        log_warn "Found $errors issue(s). Check the log for details."
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo "================================================================================"
    echo "Initial Server Setup Script"
    echo "================================================================================"
    
    # Check if running as root
    check_root
    
    # Detect OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Detected OS: $PRETTY_NAME"
    fi
    
    # Update system first
    log_step "Updating package lists"
    apt-get update -qq
    
    # Install required packages
    log_step "Installing required packages"
    apt-get install -y -qq dnsutils systemd-timesyncd ntpdate curl wget
    
    # Configure components
    configure_apt_repositories
    configure_dns
    configure_ntp
    
    # Final validation
    validate_system
    
    echo "================================================================================"
    log_info "Setup complete! Log file: $LOG_FILE"
    echo "================================================================================"
    
    # Show summary
    echo ""
    echo "Summary:"
    echo "  DNS Servers:"
    echo "$DNS_SERVERS" | sed 's/^/    /'
    echo "  NTP Servers:"
    echo "$NTP_SERVERS" | sed 's/^/    /'
    echo "  APT Sources:"
    echo "$APT_SOURCES" | sed 's/^/    /'
    echo ""
    log_info "You may need to reboot for all changes to take effect"
}

# Run main function
main "$@"
