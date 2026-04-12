# Grab gosu from Debian (not available in Wolfi's apk repos)
FROM debian:bookworm-slim AS gosu
RUN apt-get update && apt-get install -y --no-install-recommends gosu && rm -rf /var/lib/apt/lists/*

FROM ghcr.io/berriai/litellm:main-latest

USER root

COPY --from=gosu /usr/sbin/gosu /usr/local/bin/gosu
RUN gosu nobody true

RUN mkdir -p /home/user && chmod 755 /home/user
ENV HOME=/home/user

COPY entrypoint.sh /entrypoint.sh
COPY litellm/start.sh /start.sh
RUN chmod +x /entrypoint.sh /start.sh

RUN chown -R 1000:1000 /home/user

EXPOSE 4000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/start.sh"]
