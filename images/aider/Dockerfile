FROM debian:bookworm

# Development tools + gosu for privilege dropping in entrypoint
RUN apt-get update && apt-get install -y \
    curl wget git vim nano less \
    procps jq unzip zip \
    build-essential python3 python3-pip python3-venv \
    openssh-client ca-certificates gnupg \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# aider via pip — uses DeepSeek by default (set DEEPSEEK_API_KEY at runtime)
RUN pip install --break-system-packages aider-chat

# Home directory — initialized here so the named volume gets this directory on first mount
RUN mkdir -p /home/user && chmod 755 /home/user
ENV HOME=/home/user

# Entrypoint creates the host user inside the container and drops privileges
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
