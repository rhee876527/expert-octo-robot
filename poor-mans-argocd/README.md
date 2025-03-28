#### (HUaS) Helm upgrade as a service

#### Required:

`git` and `helm`.

In this guide, `helm` binary is saved in `/home/ubuntu/.local/bin`.

#### Objective

To sync changes in helm charts from repo as soon as they are made, `helm-updater.sh` script exists. As long it is in `tracking` state, every time it is run it will upgrade the helm charts that are different from last commit state.

#### Initialize remote repo

On first run it will initialize the remote repo

```
./helm-updater.sh

Cloning into '/home/ubuntu/.helm-tracker/repo'...
remote: Enumerating objects: 137, done.
remote: Counting objects: 100% (37/37), done.
remote: Compressing objects: 100% (36/36), done.
remote: Total 137 (delta 12), reused 1 (delta 1), pack-reused 100 (from 2)
Receiving objects: 100% (137/137), 22.87 KiB | 238.00 KiB/s, done.
Resolving deltas: 100% (55/55), done.
🚨 First-time setup detected!
Run: helm-updater.sh --start-tracking


```

#### Set tracking point

Pass `--start-tracking` flag to begin tracking changes.

```
./helm-updater.sh --start-tracking

HEAD is now at a949ac4 Update quay.io/invidious/invidious:master-arm64 Docker digest to 298f3d4
Tracking started from commit: a949ac44352c9baf98eadb88b68468a440d274af

```

#### Helm upgrade on diff changes

With tracking commit established, when changes are detected from remote repo the `upgrade_charts` action kicks in.

```
./helm-updater.sh
Detected changes in Helm charts:
app-charts/invidious-chart/templates/deployment.yaml
app-charts/invidious-chart/values.yaml
Upgrading chart: invidious-chart (from app-charts/invidious-chart)
Release "invidious-chart" has been upgraded. Happy Helming!
NAME: invidious-chart
LAST DEPLOYED: Thu Mar 27 20:39:17 2025
NAMESPACE: default
STATUS: deployed
REVISION: 12
TEST SUITE: None
Upgrade complete. Tracking updated.

```

#### Run helm-tracker daemon

Run helm tracker script as a systemd service every 5 mins

```
[Unit]
Description=Helm Tracker Service
After=network.target
Wants=network-online.target

[Service]
ExecStart=/bin/bash -c 'while :; do /home/ubuntu/docker/poor-mans-argocd/helm-updater.sh; sleep 300; done'
Restart=always
User=ubuntu
WorkingDirectory=/home/ubuntu/docker/poor-mans-argocd
Environment="HOME=/home/ubuntu"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/home/ubuntu/.local/bin"

[Install]
WantedBy=multi-user.target

```
