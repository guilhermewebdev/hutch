FROM python:3.12-slim

RUN apt-get update && apt-get install -y \
    curl gosu \
    && rm -rf /var/lib/apt/lists/*

# RouteLLM with the OpenAI-compatible server extra
RUN pip install "routellm[serve]"

# Home directory — shared with the main container via the profile volume
RUN mkdir -p /home/user && chmod 755 /home/user
ENV HOME=/home/user

# Entrypoint maps host UID/GID and drops privileges (shared with other images)
COPY entrypoint.sh /entrypoint.sh

# Startup script — sources ~/.api_keys from the profile home, then starts the server
COPY routellm/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6060

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/start.sh"]
