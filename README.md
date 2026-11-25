# Athanor

An alchemist's furnace.

Athanor is a devcontainer-based development environment for Helmetica.
It provides a local [kind](https://kind.sigs.k8s.io/) cluster with all modules needed to develop and test service charts (reagents).

Documentation: https://docs.helmetica.io/athanor/

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
devsy workspace up .
```

If you prefer the plain CLI, the [devcontainer CLI](https://github.com/devcontainers/cli) works too:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . zsh
```
