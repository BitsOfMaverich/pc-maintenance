#!/bin/bash

# aws config should be in /root/.aws/

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin/usr/local/bin

profile=maintenance
SNS_TOPIC_ARN="arn:aws:sns:us-east-2:465723427096:pc-health"
drives=("/dev/sda" "/dev/sdb" "/dev/nvme0" "/dev/nvme1")
host=$(hostname)

send_sns_message() {
    local message=""
    local subject=""

    for arg in "$@"; do
        case "$arg" in
            message=*)
                message="${arg#message=}"
                ;;
            subject=*)
                subject="${arg#subject=}"
                ;;
            *)
                echo "ERROR: unknown argument '$arg'"
                return 1
                ;;
        esac
    done

    if [[ -z "$message" ]]; then
        echo "ERROR: message is required"
        return 1
    fi

    aws sns publish \
        --topic-arn "$SNS_TOPIC_ARN" \
        --message "$message" \
        --profile $profile \
        ${subject:+--subject "$subject"}
}

failed=false

for drive in ${drives[@]}; do
    result=$(smartctl -H $drive | grep result | awk -F": " '{print $2}')
    echo "${drive} : ${result}"

    echo "$(date) loop for $drive"

    if [ $result != "PASSED" ]; then
        failed=true
        send_sns_message \
            subject="HEALTH ALERT" \
            message="Unhealthy drive ${drive} detected on $host"
    fi
done

# periodic ping to verify script is still running      
if [[ $(date +%a) == "Mon" && $failed == false ]]; then
    send_sns_message \
        subject="Health Check PASS: $host" \
        message="Health checks PASSED on $host"
fi
