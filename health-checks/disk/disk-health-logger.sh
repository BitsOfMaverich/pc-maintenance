#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin/usr/local/bin
NVME_DRIVES=("/dev/nvme0" "/dev/nvme1")
SATA_DRIVES=("/dev/sda" "/dev/sdb")
HOST=$(hostname)
LOG="/home/rich/OneDrive/pc-maintenance/health-checks/disk/ssd_health_log.csv"
TIMESTAMP=$(date --iso-8601=minutes)

# Key Metrics to Watch

# Media and Data Integrity Errors: 
#     This should strictly be 0. 
#     Any number above zero indicates the drive is actively failing to read/write data and blocks are corrupting.

# Percentage Used:
#     This represents how much of the manufacturer's rated write endurance (TBW - Terabytes Written) has been consumed.

# Available Spare:
#     SSDs hide a pool of extra blocks to replace worn-out ones seamlessly. 
#     If this drops near the threshold, your drive is running out of replacement blocks.


# Note for SATA SSDs: 
#     Look for Reallocated Sector Count or G-Sense Error Rate. [1] (https://www.silicon-power.com/knowledge-detail/ssd-smart/)


if [ ! -f "$LOG" ]; then
    echo "Timestamp,Host,Drive,Model,Percentage_Used,Media_Errors,Available_Spare,Reallocated_Sectors" > "$LOG"
fi

# nvme
for DRIVE in ${NVME_DRIVES[@]}; do
    result=$(smartctl --all $DRIVE)

    # Extract raw values from smartctl
    # Trims leading spaces by using a regular expression sub-string replace
    MODEL=$(echo "$result" | awk -F':' '/Model Number/ {sub(/^[ \t]+/, "", $2); print $2}')
    PERCENT_USED=$(echo "$result" | grep "Percentage Used:" | awk '{print $3}' | sed 's/%//')
    MEDIA_ERRORS=$(echo "$result" | grep "Media and Data Integrity Errors:" | awk '{print $6}')
    SPARE=$(echo "$result" | grep "Available Spare:" | awk '{print $3}' | sed 's/%//')

    echo "$TIMESTAMP,$HOST,$DRIVE,$MODEL,$PERCENT_USED,$MEDIA_ERRORS,$SPARE" >> "$LOG"
done

# sata
for DRIVE in ${SATA_DRIVES[@]}; do
    result=$(smartctl --all $DRIVE)

    # Extract raw values from smartctl
    # Trims leading spaces by using a regular expression sub-string replace
    MODEL=$(echo "$result" | awk -F':' '/Device Model/ {sub(/^[ \t]+/, "", $2); print $2}')
    REALLOCATED_SECTORS=$(echo "$result" | grep "Reallocated_Sector_Ct" | awk '{print $10}')

    echo "$TIMESTAMP,$HOST,$DRIVE,$MODEL,,,,$REALLOCATED_SECTORS" >> "$LOG"
done



