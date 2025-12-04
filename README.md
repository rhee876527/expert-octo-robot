###### my k3s misadventures

### Preface
Run self-hosted services in docker containers with `k3s`. Uses a `caddy` wrapper [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) to reverse proxy and issue TLS certificates automatically. It also listens on the docker socket to auto-discover services: convenient dual use for docker services on same system. Check `app-charts/caddy-chart` for more information.

Renovate automatically updates container image tags and a helm-updater script automatically applies those updates.

#### Service charts (app-charts)
- bazarr
- changedetection
- cloudtube
- godns
- jackett
- miniflux
- prowlarr
- radarr
- searxng
- wikiless
- caddy-docker-proxy
- flaresolverr
- invidious
- jellyfin
- nextcloud
- redlib
- sonarr
- dozzle
- neuters

#### Install K3S

Customize `k3s/.env.sample` and `docker compose up -d`. Confirm k3s server is setup correctly with `docker logs k3s-server`.

#### Move kubeconfig to $HOME

Without this you have to `docker exec -it k3s-server ash` into the k3s server everytime you want to use `kubectl` which is less than ideal.

```
docker cp k3s-server:/etc/rancher/k3s/k3s.yaml $HOME/.kube/config
```

Add this to your bashrc.
```
export KUBECONFIG=~/.kube/config
```

After a few minutes, confirm installation with

```
kubectl get nodes

NAME           STATUS   ROLES                  AGE   VERSION
589c5514ef19   Ready    control-plane,master   1d   v1.32.2+k3s1

```

#### Create my-secret

Install [kubeseal](https://github.com/bitnami-labs/sealed-secrets?tab=readme-ov-file#linux).

Populate `secrets/.env.sample` with your variables.
```
kubectl create secret generic my-secrets \
  $(grep -v '^#' .env | xargs -I {} echo --from-literal={}) \
  --dry-run=client -o yaml > sealed-secret.yaml
```

```
kubeseal --format=yaml < sealed-secret.yaml > sealed-secret-temp.yaml && mv sealed-secret-temp.yaml sealed-secret.yaml
```

```
kubectl apply -f sealed-secret.yaml
```

Your secrets will be `base64` encoded and you can check them with `kubectl get secret my-secrets -o yaml`.

These secrets are what helm's `template helper` decodes to pass sensitive information when deploying. e.g to get apps-dir
```
{{- define "get.appsDir" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.APPS_DIR | b64dec -}}
{{- end -}}
```

#### Helm-charts

Install [helm](https://github.com/helm/helm).

##### Install
`helm install searxng-chart app-charts/searxng-chart`
##### Upgrade
`helm upgrade searxng-chart app-charts/searxng-chart`
##### Rollback
`helm rollback searxng-chart 5`

`5` is the revision number which you can check with
`helm history searxng-chart`

#### Automated unattended-upgrades

[Renovate bot](https://github.com/apps/renovate) tracks `values.yaml` in all the `charts` in this `repo` and updates the `digest/version`. Minor/patch updates `bypass` PR creation and get merged to the branch directly. Major updates will require a PR approval for `merge`.

#### Effecting upgrades

Run `poor-mans-argocd/helm-updater.sh` on a regular interval (check the systemd service) to do `helm upgrade foo` on the charts tracked by this repo.

#### Upgrading k3s server

##### Easy 2 steps:


###### 1. Get deprecated node id
```
k get no
NAME           STATUS   ROLES                  AGE   VERSION
5b3e00f37c95   Ready    control-plane,master   14m   v1.33.2+k3s1
```


###### 2. Update .env, recreate k3s container and delete old node
```
docker compose up -d --remove-orphans && sleep 8 && kubectl delete node $nodeid
```
