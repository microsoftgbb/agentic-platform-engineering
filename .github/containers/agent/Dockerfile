FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    python3 \
    apt-transport-https \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' > /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update && apt-get install -y kubectl \
    && rm -rf /var/lib/apt/lists/*

# Install kubelogin
RUN curl -fsSL https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-amd64.zip -o /tmp/kubelogin.zip \
    && apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/* \
    && unzip /tmp/kubelogin.zip -d /tmp/kubelogin \
    && mv /tmp/kubelogin/bin/linux_amd64/kubelogin /usr/local/bin/ \
    && rm -rf /tmp/kubelogin /tmp/kubelogin.zip

# Install Copilot CLI
RUN curl -fsSL https://gh.io/copilot-install | bash

# Non-root user
RUN useradd -m -s /bin/bash agent
USER agent
WORKDIR /workspace

ENTRYPOINT ["/bin/bash"]
