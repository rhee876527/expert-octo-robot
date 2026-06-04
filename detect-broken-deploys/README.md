#### Get Telegram notifications when deployment state does not match desired replica state.

When we have `fewer ready pods than total desired replicas` this script will send a Telegram alert with the deployments that require remediation.

Enable this `systemd service` to run this check every `1` hour:

```
[Unit]
Description=Deployment Monitor - Alerts on mismatched replicas

[Service]
Type=simple
User=ubuntu
Environment="KUBECONFIG=/home/ubuntu/.kube/config"
Environment="PATH=/usr/bin:/home/ubuntu/.local/bin"
Environment=TELEGRAM_BOT_TOKEN="564xxxxx:AAGxxx0ZOy1Pw9__ExxxxxxJPfeI8"
Environment=TELEGRAM_CHAT_ID="-100xxxxxx"

ExecStart=/bin/bash -c '\
set -o pipefail; \
LAST_ALERT=""; \
while true; do \
    MISMATCH=$(kubectl get deployments -o json | jq -r "[.items[] | select(.status.readyReplicas != .spec.replicas) | {name: .metadata.name, ready: (.status.readyReplicas // 0), desired: .spec.replicas}]") || exit 1; \
    CURRENT=$(echo "$MISMATCH" | jq -c .); \
    \
    if [ "$(echo "$MISMATCH" | jq length)" -gt 0 ]; then \
        sleep 300; \
        MISMATCH=$(kubectl get deployments -o json | jq -r "[.items[] | select(.status.readyReplicas != .spec.replicas) | {name: .metadata.name, ready: (.status.readyReplicas // 0), desired: .spec.replicas}]") || exit 1; \
        CURRENT=$(echo "$MISMATCH" | jq -c .); \
    fi; \
    \
    if [ "$CURRENT" != "$LAST_ALERT" ]; then \
        LAST_ALERT="$CURRENT"; \
        COUNT=$(echo "$MISMATCH" | jq "length"); \
        if [ "$COUNT" -gt 0 ]; then \
            MESSAGE="⚠️ Deployment Mismatches ($COUNT)%%0A%%0A"; \
            for i in $(seq 0 $((COUNT - 1))); do \
                NAME=$(echo "$MISMATCH" | jq -r ".[$i].name"); \
                READY=$(echo "$MISMATCH" | jq -r ".[$i].ready"); \
                DESIRED=$(echo "$MISMATCH" | jq -r ".[$i].desired"); \
                MESSAGE+="$NAME: $READY/$DESIRED%%0A"; \
            done; \
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$MESSAGE" \
                -d parse_mode="Markdown"; \
        fi; \
    fi; \
    sleep 3600; \
done'

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```
