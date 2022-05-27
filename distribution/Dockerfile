FROM debian:11-slim as base

MAINTAINER "Oijkn <https://github.com/oijkn>"
LABEL name="oijkn/adguardhome-doh-dot"

# Set up the environment
ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive


# Raspberry Pi 32 bit = armhf
# Raspberry Pi 64 bit = arm64
# PC 64 bit = amd64
# PC 32 bit = i386


RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
               apt-file \
               ca-certificates \
               cron \
               curl \
               libcap2-bin \
               procps \
               stubby \
               systemd \
               systemd-sysv \
               unbound \
               wget \
    && apt-file update \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Prepare the container for the ystemd-sysv service
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp*

# Download and install AdguardHome
RUN wget -qO install.sh https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh \
    && chmod +x install.sh \
    && ./install.sh \
    && rm -f install.sh

# Update AdGuardHome with the latest version depends on the architecture
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
        aarch64|arm64) \
            ADGH_URL="https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz"; \
            ;; \
        armhf|arm) \
            ADGH_URL="https://static.adguard.com/adguardhome/release/AdGuardHome_linux_armv7.tar.gz"; \
            ;; \
        amd64|x86_64) \
            ADGH_URL="https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz"; \
            ;; \
        *) \
            echo "Unsupported architecture: $ARCH"; \
            exit 1; \
            ;; \
    esac; \
    wget -qO update.tar.gz "${ADGH_URL}"; \
    tar -xzf update.tar.gz; \
    cp -f AdGuardHome/AdGuardHome /opt/AdGuardHome; \
    rm -rf update.tar.gz AdGuardHome/;

# Create needed directories
RUN mkdir -p /opt/AdGuardHome/conf \
    && mkdir -p /opt/AdGuardHome/work

# Replace default configuration
RUN sed -i 's#cmd="/opt/AdGuardHome/AdGuardHome "-s" "run""#cmd="/opt/AdGuardHome/AdGuardHome "-s" "run" "-c" "/opt/AdGuardHome/conf/AdGuarHome.yaml" "-w" "/opt/AdGuardHome/work""#' \
    /etc/init.d/AdGuardHome

# Configure setcap for AdGuardHome
RUN setcap 'cap_net_bind_service=+eip' /opt/AdGuardHome/AdGuardHome

# Get root.hints file for unbound
RUN wget -O root.hints https://www.internic.net/domain/named.root \
    && mv root.hints /var/lib/unbound/

# Set up the unbound configuration
COPY unbound/unbound.conf /etc/unbound/unbound.conf.d/unbound.conf

# Download and install cloudflare depend on the architecture
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
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

# Configure cloudflared options
RUN echo "CLOUDFLARED_OPTS=--port 5053 --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query --upstream https://2606:4700:4700::1111/dns-query --upstream https://2606:4700:4700::1001/dns-query" >> /etc/default/cloudflared

# Add user cloudflared and set ownership
RUN useradd -s /usr/sbin/nologin -r -M cloudflared \
    && chown cloudflared:cloudflared /etc/default/cloudflared /usr/local/bin/cloudflared

# Copy systemd service file for cloudflared
COPY cloudflare/cloudflared.service /lib/systemd/system/cloudflared.service

# Configure stubby
RUN rm -f /etc/stubby/stubby.yml
COPY stubby/stubby.yml /etc/stubby/stubby.yml
RUN sed -i 's,DynamicUser=true,#DynamicUser=true,g' /lib/systemd/system/stubby.service

# Configure crontab
COPY crontab/root /var/spool/cron/crontabs/root
RUN chmod 600 /var/spool/cron/crontabs/root \
    && chown root:crontab /var/spool/cron/crontabs/root

# Enable and start services
RUN systemctl enable AdGuardHome \
    && systemctl enable unbound \
    && systemctl enable cloudflared \
    && systemctl enable cron \
    && systemctl enable stubby

# Mount volume for systemd-sysv
VOLUME [ "/sys/fs/cgroup" ]

# Run systemd-sysv service
CMD ["/lib/systemd/systemd"]

# For debugging only
#CMD ["/bin/sh", "-c", "while true; do cat /dev/null; done"]
