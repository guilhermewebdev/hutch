FROM debian:bookworm

# Development tools
RUN apt-get update && apt-get install -y \
    curl wget git vim nano less \
    procps jq unzip zip \
    build-essential python3 \
    openssh-client ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/*

# Node.js via official NodeSource script
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI (access to the host daemon)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
      https://download.docker.com/linux/debian bookworm stable" \
      > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Gemini CLI via npm
RUN npm install -g @google/gemini-cli

# Home directory accessible to any UID (initializes the volume on first run)
RUN mkdir -p /home/user && chmod 777 /home/user
ENV HOME=/home/user
