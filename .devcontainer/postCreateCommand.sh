#!/bin/bash

# Fixing rebasing on macos
# https://stackoverflow.com/questions/79217455/unable-to-rebase-git-repository-when-running-inside-a-devcontainer
sudo git config set --system core.checkStat minimal

mkdir -p "$HOME/.kube"
kubectl completion bash >/home/vscode/.kube/completion.bash.inc
printf "
source /usr/share/bash-completion/bash_completion
source "$HOME/.kube/completion.bash.inc"
complete -F __start_kubectl k
" >>"$HOME/.bashrc"

printf "
source <(kubectl completion zsh)
complete -F __start_kubectl k
" >>"$HOME/.zshrc"

just quench
just ignite
ln -fs /workspaces/athanor/.kind/kind-config ~/.kube/config
