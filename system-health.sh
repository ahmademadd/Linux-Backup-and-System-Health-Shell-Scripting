#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Start of health report
echo -e "${GREEN}System Health Report $(date)${NC}"

# Check disk space
print_header "Disk Space"
df -h | awk '$NF=="/" {print $5, $2, $4}' | sed 's/%//' | {
    read used total available
    echo "Total storage: $total"
    echo "Available storage: $available"
    if [ $used -gt 90 ]; then
        echo -e "${RED}WARNING: Disk space usage is high (${used}%)${NC}"
        echo "Recommendation: Consider freeing up disk space or expanding storage."
    else
        echo -e "${GREEN}Disk space usage is normal (${used}%)${NC}"
    fi
}

# Check memory usage
print_header "Memory Usage"
free -m | awk '/Mem:/ {total=$2; used=$3/$2*100.0; free=$4; available=$7} /Swap:/ {free_swap=$4} END {print total, used, free, available, free_swap}' | {
    read total used free available free_swap
    used=${used%.*}
    echo "Total memory: ${total}MB"
    echo "Free memory: ${free}MB"
    echo "Available memory: ${available}MB"
    echo "Free swap: ${free_swap}MB"
    if [ $used -gt 90 ]; then
        echo -e "${RED}WARNING: Memory usage is high (${used}%)${NC}"
        echo "Recommendation: Consider closing unnecessary applications or adding more RAM."
    else
        echo -e "${GREEN}Memory usage is normal (${used}%)${NC}"
    fi
}

# Check running services
print_header "Running Services"
if command_exists systemctl; then
    systemctl list-units --type=service --state=running
elif command_exists service; then
    service --status-all | grep +
else
    echo "Unable to check services: neither systemctl nor service command found."
fi

# Check for recent system updates
print_header "System Updates"
if command_exists apt-get; then
    last_update=$(stat -c %Y /var/cache/apt/pkgcache.bin 2>/dev/null)
    now=$(date +%s)
    days_since_update=$(( (now - last_update) / 86400 ))
    if [ $days_since_update -gt 7 ]; then
        echo -e "${YELLOW}WARNING: System hasn't been updated in ${days_since_update} days${NC}"
        echo "Recommendation: Run 'sudo apt-get update && sudo apt-get upgrade' to update the system."
        echo "Recent installations and updates:"
        sudo apt-get update > /dev/null
        apt-get --just-print upgrade | grep -E "Inst|Conf"
    else
        echo -e "${GREEN}System was updated within the last 7 days${NC}"
        echo "Recent installations and updates:"
        sudo apt-get update > /dev/null
        apt-get --just-print upgrade | grep -E "Inst|Conf"
    fi
elif command_exists yum; then
    yum check-update --quiet
    if [ $? -eq 100 ]; then
        echo -e "${YELLOW}WARNING: System updates are available${NC}"
        echo "Recommendation: Run 'sudo yum update' to update the system."
        echo "Recent installations and updates:"
        yum list updates
    else
        echo -e "${GREEN}System is up to date${NC}"
    fi
else
    echo "Unable to check for updates: neither apt-get nor yum found."
fi

# End of health report
echo -e "\n${GREEN}End of System Health Report${NC}"
