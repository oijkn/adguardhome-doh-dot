FROM alpine AS builder_stubby

RUN apk add --update alpine-sdk libidn2-dev unbound-dev cmake openssl-dev libev-dev libuv-dev check-dev yaml-dev \
        && git clone https://github.com/getdnsapi/getdns.git \
        && cd getdns && git checkout master && git submodule update --init \
        && mkdir build && cd build \
        && cmake -DBUILD_STUBBY=ON .. \
        && make && make install


FROM adguard/adguardhome as base

MAINTAINER "Oijkn <https://github.com/oijkn>"
LABEL name="oijkn/adguardhome-doh-dot"


# Raspberry Pi 32 bit = armhf
# Raspberry Pi 64 bit = arm64
# PC 64 bit = amd64
# PC 32 bit = i386

# Install dependencies for building
RUN apk update && apk add --no-cache \
    dpkg \
    libidn2 \
    libcrypto1.1 \
    libssl1.1 \
    openssl \
    yaml \
    unbound

# Get root.hints file for Unbound
RUN wget -O root.hints https://www.internic.net/domain/named.root \
    && mkdir -p /var/lib/unbound/ \
    && mv root.hints /var/lib/unbound/

# Set up the Unbound conf file
COPY unbound/unbound.conf /etc/unbound/unbound.conf

# Download and install Cloudflare depend on the architecture
RUN set -eux; \
    ARCH="$(dpkg --print-architecture | awk -F'-' '{print $NF}')"; \
    case "$ARCH" in \
        aarch64|arm64) \
            CLOUDFLARE_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"; \
            ;; \
        armhf|arm) \
            CLOUDFLARE_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"; \
            ;; \
        amd64|x86_64) \
            CLOUDFLARE_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"; \
            ;; \
        *) \
            echo "Unsupported architecture: $ARCH"; \
            exit 1; \
            ;; \
    esac; \
    wget -qO /usr/local/bin/cloudflared "${CLOUDFLARE_URL}"; \
    chmod +x /usr/local/bin/cloudflared; \
    cloudflared --version;

# Add user cloudflared and set ownership
RUN addgroup -S cloudflared \
    && adduser -S cloudflared -G cloudflared -s /usr/sbin/nologin -D -H \
    && chown cloudflared:cloudflared /usr/local/bin/cloudflared

# Install Stubby from previous build
RUN mkdir -p /usr/local/var/run
COPY --from=builder_stubby /usr/local/lib/libgetdns.so.10.2.0 /usr/local/lib/libgetdns.so
COPY --from=builder_stubby /usr/local/bin/stubby /usr/local/bin/stubby
COPY --from=builder_stubby /usr/local/share/man/man1/stubby.1 /usr/local/share/man/man1/stubby.1
COPY --from=builder_stubby /usr/local/share/doc/stubby/AUTHORS /usr/local/share/doc/stubby/AUTHORS
COPY --from=builder_stubby /usr/local/share/doc/stubby/COPYING /usr/local/share/doc/stubby/COPYING
COPY --from=builder_stubby /usr/local/share/doc/stubby/ChangeLog /usr/local/share/doc/stubby/ChangeLog
COPY --from=builder_stubby /usr/local/share/doc/stubby/NEWS /usr/local/share/doc/stubby/NEWS
COPY --from=builder_stubby /usr/local/share/doc/stubby/README.md /usr/local/share/doc/stubby/README.md

# Copy the config file for Stubby
COPY stubby/stubby.yml /usr/local/etc/stubby/stubby.yml

# Set up the cron jobs
COPY crontab/root /tmp/crontab_root
RUN cat /tmp/crontab_root >> /var/spool/cron/crontabs/root \
    && rm -f /tmp/crontab_root

# Copy custom entrypoint script
COPY distribution/entrypoint.sh /opt

# Upgrade Alpine to 3.16 and install the latest version of packages
RUN sed -i 's#3.13#3.16#g' /etc/apk/repositories \
    && apk update \
    && apk upgrade --available --no-cache \
    && sync

# Set script permissions executable
RUN chmod +x /opt/entrypoint.sh

# Run the entrypoint script
ENTRYPOINT ["/opt/entrypoint.sh"]

# For debugging only
#CMD ["/bin/sh", "-c", "while true; do cat /dev/null; done"]
