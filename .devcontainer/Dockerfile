FROM mcr.microsoft.com/devcontainers/go:dev-1.26-bookworm

ARG TARGETOS
ARG TARGETARCH

ENV KUBECOLORVERSION="0.4.0"
# renovate: datasource=github-releases depName=casey/just
ENV JUSTVERSION="1.51.0"
# renovate: datasource=github-releases depName=kubernetes-sigs/krew
ENV KREWVERSION="0.5.0"

# Install kubecolor
RUN curl -L -o kubecolor.tar.gz https://github.com/kubecolor/kubecolor/releases/download/v${KUBECOLORVERSION}/kubecolor_${KUBECOLORVERSION}_linux_${TARGETARCH}.tar.gz && tar -xvzf kubecolor.tar.gz && install -c -m 0755 kubecolor /usr/local/bin

# Install just
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --tag ${JUSTVERSION} --to /usr/local/bin

# Install bash-complete to make kubectl autocomplete work
RUN apt-get update && apt-get install bash-completion vim -y && rm -rf /var/lib/apt/lists/*

# Install krew as the user that runs the container, it installs into $HOME/.krew
USER vscode
RUN curl -L -o krew.tar.gz https://github.com/kubernetes-sigs/krew/releases/download/v${KREWVERSION}/krew-linux_${TARGETARCH}.tar.gz && tar -xzf krew.tar.gz && ./krew-linux_${TARGETARCH} install krew && rm -rf krew.tar.gz krew-linux_${TARGETARCH} LICENSE
ENV PATH="/home/vscode/.krew/bin:${PATH}"
USER root
