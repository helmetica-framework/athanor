# Athanor

An alchemist's furnace.

Athanor is a devcontainer-based development environment for Helmetica.
It provides a local [kind](https://kind.sigs.k8s.io/) cluster with all modules needed to develop and test service charts (reagents).

## Getting started with the devcontainer

### Prerequisites

* [Docker](https://docs.docker.com/get-docker/) (or a compatible engine like OrbStack)
* [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Starting it

1. Clone this repository and open it in VS Code.
2. When prompted, choose **Reopen in Container**. Alternatively open the command palette (`F1`) and run **Dev Containers: Reopen in Container**.
3. Wait for the container to build and provision. The `postCreateCommand` automatically runs `just ignite`, so once provisioning finishes you already have a running cluster.

Another good way to run the devcontainer is [Devsy](https://github.com/devsy-org/devsy).
It works with any IDE and can run the devcontainer on your local Docker daemon or on remote providers:

```bash
devsy up .
```

If you prefer the plain CLI, the [devcontainer CLI](https://github.com/devcontainers/cli) works too:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . zsh
```

### What's inside

The devcontainer ships all tooling needed for development:

* Go, `just`, `git`, `vim`
* `docker` (docker-in-docker)
* `kubectl` (with completions and [kubecolor](https://github.com/kubecolor/kubecolor)), `helm`, `krew`
* `jq` and `yq`
* Nix

The devcontainer forwards the following ports to your host:

| Port  | Purpose                              |
| ----- | ------------------------------------ |
| 8088  | Ingress HTTP (traefik)               |
| 8443  | Ingress HTTPS (traefik)              |
| 5000  | Internal container registry (TLS)    |
| 36377 | Kubernetes API server                |

## Igniting the furnace

If you need to (re-)create the cluster manually, simply ignite the furnace to get a kind cluster with all necessary modules:

```bash
just quench
just ignite
```

This creates the kind cluster and installs the modules from the `hearth/` folder:

* [traefik](https://traefik.io/) as ingress controller, reachable on `localhost:8088`/`localhost:8443`
* [metallb](https://metallb.io/) so `LoadBalancer` services get IPs
* [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) for monitoring
* [k8up](https://k8up.io/) for backups
* [cert-manager](https://cert-manager.io/) for certificates
* [COSI](https://container-object-storage-interface.sigs.k8s.io/) (the `objectstorage.k8s.io`
  CRDs and its central controller) so a `BucketClaim` provisions a real bucket
* The [garage operator](https://github.com/rajsinghtech/garage-operator) with its COSI
  driver enabled, plus a single-node [Garage](https://garagehq.deuxfleurs.fr/) cluster
* An internal container registry on `localhost:5000` (TLS, self-signed)
* And of course the helmetica framework

To talk to the cluster from outside the devcontainer, point `kubectl` at the generated kubeconfig:

```bash
export KUBECONFIG=$(pwd)/.kind/kind-config
```

### Asking for a bucket

The `garage` `BucketClass` and `BucketAccessClass` are installed and pointed at the local
Garage cluster, so a claim is all it takes:

```yaml
apiVersion: objectstorage.k8s.io/v1alpha2
kind: BucketClaim
metadata:
  name: scratch
  namespace: default
spec:
  bucketClassName: garage
  protocols:
  - S3
```

```console
kubectl get bucketclaims,buckets
kubectl -n garage-system logs deployment/garage-operator -f
```

Some handy URLs once the furnace is lit:

* <http://prometheus.127.0.0.1.nip.io:8088>
* <http://alertmanager.127.0.0.1.nip.io:8088>

Editing a module's values file (e.g. `hearth/traefik/values.yaml`) and re-running `just ignite` reconciles every module, or run the single recipe (e.g. `just traefik-setup`) to upgrade only that one.

Then put the service charts (reagents) into the `reagents/` folder and develop away.

## Quenching it

To stop and delete the cluster:

```bash
just quench
```

`just` (or `just --list`) lists all available recipes.

## Structure

```
.
├── hearth            # Modules for athanor (one folder per module)
├── reagents          # Charts to be developed go here
├── Justfile             # Contains logic to start/stop the devenv
├── Justfile.vars.just   # Pinned versions of all modules (managed by Renovate)
├── README.md
└── renovate.json
```
