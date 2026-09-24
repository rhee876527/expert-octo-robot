# Some more notes on setup

Most of the operations in this setup are hand rolled. This gives us the advantage of customizing the solutions we want specifically at the cost of adding some maintenance burden for these bespoke solutions.

This doc goes through some of the pitfalls.

The general stumbling block goes something like this:
Since k3s runs as a docker container, kubernetes has a fatal tie to the docker runtime. As such any container restarts, breaking docker package updates etc. directly affect k8s api availability.

I cover below steps how to reduce downtime because of this architectural flaw
 as well as some bonus suggestions for handling all the operational work that
 k3s/k8s/docker does not automatically handle on our behalf.


###### Tips for reducing maintainer toil


##### Docker

Enable `live-restore` feature
```
~ cat /etc/docker/daemon.json

{
"live-restore": true
}
```
This configuration will keep containers running
 after dockerd disconnects and try to repair connections
 to the running containers.
More here: https://docs.docker.com/engine/daemon/live-restore/


##### Unattended-upgrades
I have this wonderful utility enabled so an attacker cannot take advantage of outdated
 and insecure programs/services to surprise me. Very important for services that
 are available and reachable from an untrusted/public network.

After unattended-upgrades setup, to add `docker-ce` to the list of packages marked for auto updates:
- edit file `/etc/apt/apt.conf.d/50unattended-upgrades`

Inside block `Unattended-Upgrade::Allowed-Origins` add entry `"Docker:${distro_codename}";`


Con:
- The docker socket's inode may become stale (https://github.com/traefik/traefik/issues/5833) after an unattended upgrade.

If for whatever reason caddy-docker-proxy fails to reach the docker socket path,
 the load balancer will crash taking down availability
 for every other app that caddy web server hosts.

Solution to this con:
- 2 prong approach (1. restart container 2. if restart does not bring back k8s api recreate k3s container)

- 1st systemd service restarts k3s-server container
 for it to pick up the bind mount for the new inode.
- 2nd systemd service will recreate the docker container
 if kubectl can't reach the k8s api after sometime.
- Usually this is enough to bring back the k8s api,
 however, sometimes a docker-ce upgrade has broken more stuff than
 a simple container restart/recreate
 could fix.


Attempt 1: Restart

A docker-ce upgrade may sometimes restart the docker service.
So we restart the container afterwards to keep it in sync with
 the new inode for the docker socket.

```
~ cat /etc/systemd/system/caddy_reboot.service
[Unit]
Description=Restart caddy when docker restarts
After=docker.service
PartOf=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/usr/bin/sleep 6
ExecStart=/usr/bin/docker restart k3s-server

[Install]
WantedBy=docker.service
```

Attempt 2: Recreate container

```
~ cat /etc/systemd/system/broken-k3s.service
[Unit]
Description=Attempt to recover broken k3s container after Docker-ce unattended upgrades
After=docker.service
PartOf=docker.service

[Service]
Type=oneshot
User=ubuntu
Environment="KUBECONFIG=/home/ubuntu/.kube/config"
Environment="PATH=/usr/bin:/home/ubuntu/.local/bin"
Environment=TELEGRAM_BOT_TOKEN="564xxxx7:AAGxxxxxx0ZOy1Pw9__ELxxxxxxxxxI8"
Environment=TELEGRAM_CHAT_ID="-100xxxxx6"

ExecStart=/bin/bash -c '\
set -uo pipefail; \
sleep 80; \
if kubectl get --raw=/readyz >/dev/null 2>&1; then \
    exit 0; \
fi; \
cd /home/ubuntu/docker/k3s || exit 1; \
docker compose down; \
sleep 5; \
docker compose up -d; \
sleep 40; \
if ! kubectl get --raw=/readyz >/dev/null 2>&1; then \
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="⚠️ Kubernetes API is still unavailable after restarting the k3s compose stack on $(hostname)"; \
fi'

RemainAfterExit=yes

[Install]
WantedBy=docker.service
```

Review:

***If the two don't bring the api back, it's time to put on the sysadmin hat and
 put out the fire!***

***Nice part is we get a Telegram notification if a docker-ce upgrade royally screwed the setup.***


##### Remove image churn

Renovate updates new container images on an hourly basis day in day out. That's its job.
The downside of this is a lot of images will be left dangling over time
 as kubelet threshold for automatically pruning dangling images may be too low: https://github.com/k3s-io/k3s/issues/1900#issuecomment-644453072

For this we add the following config:
```
~ cat /etc/rancher/k3s/config.yaml
kubelet-arg:
  - "image-gc-high-threshold=85"
  - "image-gc-low-threshold=70"
```
This tells k3s to check if system storage is above `85% used` and `prune` any `unused images`.

If you want the pruning to be done sooner rather than later,
 you can trigger this action with a systemd timer below.

```
~ cat /etc/systemd/system/gc-containerd.timer
[Unit]
Description=Run gc-containerd.service two days a week

[Timer]
# 2 a.m. and 5 a.m. on Sundays and Wednesdays
OnCalendar=Wed,Sun *-*-* 02,05:00:00
Persistent=true
AccuracySec=1h

[Install]
WantedBy=timers.target

~ cat /etc/systemd/system/gc-containerd.service
[Unit]
Description=Create huge empty file in /tmp and delete after 2 minutes
Wants=gc-containerd.timer

[Service]
Type=oneshot
ExecStart=/bin/sh -c 't=$(df -B1 / | awk '\''NR==2{print $2}'\''); u=$(df -B1 / | awk '\''NR==2{print $3}'\''); n=$(( (86 * t / 100) - u )); [ $n -gt 0 ] && fallocate -l $n /tmp/empty_file.bin && sleep 120 && rm -f /tmp/empty_file.bin'
```

Note. `gc-containerd.service` will fill up disk capacity (to 86%) and wait for 2 mins
 before completing its job. You should not have this operation
 coincide with another job that expectedly writes huge files at the same time.

##### Finally

This self-hosted infra mostly takes care of itself. I only need to remember
 to update the container (k3s-server) when k3s releases a new stable version.
 And the good part is for some of the services we have an uptime monitor running on
 Cloudflare workers (https://github.com/rhee876527/IOkdjashAQkl) and the
 monitor service is hooked up to a Make.com webhook for downtime alert notifications
 with Pushbullet.