#!/bin/sh

# This script is executed by the Docker container.
#set -eux # For debugging
set -e

# Run crontab service.
/usr/sbin/crond -L /var/log/cron.log

# Run Ubound
/usr/sbin/unbound -p -v -d &
/usr/sbin/unbound-anchor -4 -r /var/lib/unbound/root.hints -a /var/lib/unbound/root.key

#Run Cloudflare DNS
/usr/local/bin/cloudflared proxy-dns --port 5053 --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query --upstream https://2606:4700:4700::1111/dns-query --upstream https://2606:4700:4700::1001/dns-query &

# Run Stubby
/usr/local/bin/stubby -l &

# Run AdGuardHome
/opt/adguardhome/AdGuardHome --no-check-update -c /opt/adguardhome/conf/AdGuardHome.yaml -h 0.0.0.0 -w /opt/adguardhome/work

# Will redirect input variables -> https://wiki.bash-hackers.org/commands/builtin/exec
exec "$@"
