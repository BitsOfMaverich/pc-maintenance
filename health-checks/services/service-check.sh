#!/bin/bash

# in development

# query for failed services


# aws config should be in /root/.aws/

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin/usr/local/bin

profile=maintenance
SNS_TOPIC_ARN="arn:aws:sns:us-east-2:465723427096:pc-health"
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


# systemctl list-unit-files --type=service --state=enabled --no-legend |
# while read -r service _; do
#     mapfile -t state < <(systemctl show -P ActiveState -P SubState "$service")
#     printf "%-60s %-12s %-12s\n" "$service" "${state[0]}" "${state[1]}"
# done



result=$(systemctl list-units --type=service --state=failed --no-legend)

# send message if there's any result.
if [[ -n "$result" ]]; then
  send_sns_message \
    subject="HEALTH ALERT - failed services" \
    message=$result
else
  send_sns_message \
    subject="HEALTH ALERT - failed services - all good" \
    message="no problemo
comment this out of the script after you know its working"
fi
