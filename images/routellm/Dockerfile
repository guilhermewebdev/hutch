FROM python:slim

RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# RouteLLM with the OpenAI-compatible server extra
RUN pip install "routellm[serve]"

# Startup script — reads model config from env vars at runtime
COPY routellm/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6060

CMD ["/start.sh"]
