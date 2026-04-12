FROM python:3.12-slim

RUN apt-get update && apt-get install -y curl gosu libatomic1 && rm -rf /var/lib/apt/lists/*

RUN pip install "litellm[proxy]" prisma

# Generate Prisma binaries so they are baked into the image
RUN prisma generate --schema /usr/local/lib/python3.12/site-packages/litellm/proxy/schema.prisma

RUN mkdir -p /home/user && chmod 755 /home/user
ENV HOME=/home/user

COPY entrypoint.sh /entrypoint.sh
COPY litellm/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 4000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/start.sh"]
