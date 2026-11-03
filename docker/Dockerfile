FROM ubuntu:latest

ARG TAILSCALE_VERSION=1.104.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg apt-transport-https bash openssh-server openssh-client sshpass \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.gpg | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu noble main" > /etc/apt/sources.list.d/tailscale.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends "tailscale=${TAILSCALE_VERSION}" \
 && rm -rf /var/lib/apt/lists/* \
 && tailscale version

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
 && useradd -m -u 1001 -s /bin/bash runner

ENV TAILSCALE_STATE_DIR=/var/lib/tailscale \
    TAILSCALE_SOCKET=/var/run/tailscale/tailscaled.sock \
    TS_HOSTNAME=gh-test \
    TS_EXTRA_ARGS=

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
