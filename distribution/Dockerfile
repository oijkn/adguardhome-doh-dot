FROM arm32v7/debian:11-slim as base

ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
               apt-file \
               ca-certificates \
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

# Update AdGuardHome with the latest version
RUN wget -qO update.tar.gz https://static.adguard.com/adguardhome/release/AdGuardHome_linux_armv7.tar.gz \
    && tar -xzf update.tar.gz \
    && cp AdGuardHome/AdGuardHome /opt/AdGuardHome \
    && rm -rf update.tar.gz AdGuardHome/

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

# Download and install cloudflare
RUN wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/download/2022.3.1/cloudflared-linux-arm \
    && chmod +x /usr/local/bin/cloudflared \
    && cloudflared -v

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

# Enable and start services
RUN systemctl enable AdGuardHome \
    && systemctl enable unbound \
    && systemctl enable cloudflared \
    && systemctl enable stubby

# Mount volume for systemd-sysv
VOLUME [ "/sys/fs/cgroup" ]

# Run systemd-sysv service
CMD ["/lib/systemd/systemd"]

#CMD ["/bin/sh", "-c", "while true; do cat /dev/null; done"]
