FROM debian:bookworm

# Base development tools
RUN apt-get update && apt-get install -y \
    curl wget git vim nano less \
    procps jq unzip zip \
    build-essential python3 python3-pip python3-venv \
    openssh-client ca-certificates gnupg \
    gosu \
    tree htop tmux lsof rsync patch diffutils \
    iproute2 dnsutils netcat-openbsd \
    sqlite3 file xxd bat \
    ripgrep fd-find \
    iputils-ping nmap traceroute mtr tcpdump whois iperf3 socat \
    cmake autoconf automake pkg-config ninja-build meson \
    podman buildah skopeo \
    gdb strace ltrace \
    && ln -s /usr/bin/batcat /usr/local/bin/bat \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
      https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# GitLab CLI
RUN ARCH=$(dpkg --print-architecture) \
    && GLAB_VERSION=$(curl -fsSL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases?per_page=1" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['tag_name'][1:])") \
    && curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${ARCH}.tar.gz" \
        | tar -xz -C /tmp \
    && install -m755 /tmp/bin/glab /usr/local/bin/glab \
    && rm -rf /tmp/bin /tmp/lib /tmp/share

# yq — YAML processor
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(dpkg --print-architecture)" \
      -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# kubectl
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/$(dpkg --print-architecture)/kubectl" \
      -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg \
      | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
      > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# aider via pip — uses DeepSeek by default (set DEEPSEEK_API_KEY at runtime)
RUN pip install --break-system-packages aider-chat

# Home directory — initialized here so the named volume gets this directory on first mount
RUN mkdir -p /home/user && chmod 755 /home/user
ENV HOME=/home/user

# Entrypoint creates the host user inside the container and drops privileges
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
