#!/bin/sh
set -eu
ENV_FILE="${ENV_FILE:-/etc/altserver-native.env}"

install -d /usr/local/sbin
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$script_dir"
install -m 0755 scripts/runtime/altserver-anisette-migrate /usr/local/sbin/altserver-anisette-migrate
install -m 0755 scripts/runtime/altserver-native-probe /usr/local/sbin/altserver-native-probe

install -m 0755 scripts/runtime/iphone-mobdev-address-publisher /usr/local/sbin/iphone-mobdev-address-publisher
install -m 0755 scripts/runtime/iphone-mobdev-service-publisher /usr/local/sbin/iphone-mobdev-service-publisher
install -m 0755 scripts/runtime/altserver-native-healthcheck /usr/local/sbin/altserver-native-healthcheck
install -m 0755 scripts/runtime/altserver-native-boot-recover /usr/local/sbin/altserver-native-boot-recover
install -m 0755 scripts/runtime/altserver-anisette-docker-run /usr/local/sbin/altserver-anisette-docker-run

cat >/etc/systemd/system/altserver-native-healthcheck.service <<UNIT
[Unit]
Description=Repair AltServer native Wi-Fi refresh stack when discovery goes stale
After=network-online.target avahi-daemon.service docker.service
Wants=network-online.target

[Service]
Type=oneshot
Environment="ENV_FILE=${ENV_FILE}"
ExecStart=/usr/local/sbin/altserver-native-healthcheck
TimeoutStartSec=90
SuccessExitStatus=2 75
UNIT

cat >/etc/systemd/system/altserver-native-healthcheck.timer <<'UNIT'
[Unit]
Description=Periodic AltServer native Wi-Fi refresh health check

[Timer]
OnBootSec=60
OnUnitInactiveSec=1min
AccuracySec=10s
Persistent=true

[Install]
WantedBy=timers.target
UNIT

cat >/etc/systemd/system/altserver-native-boot-recover.service <<UNIT
[Unit]
Description=Run AltServer Wi-Fi refresh recovery after boot
After=network-online.target docker.service avahi-daemon.service altserver-anisette-docker.service altserver-native-netmuxd.service iphone-mobdev-address.service iphone-mobdev-service.service
Wants=network-online.target docker.service avahi-daemon.service altserver-anisette-docker.service altserver-native-netmuxd.service iphone-mobdev-address.service iphone-mobdev-service.service

[Service]
Type=oneshot
Environment="ENV_FILE=${ENV_FILE}"
ExecStart=/usr/local/sbin/altserver-native-boot-recover
TimeoutStartSec=30min

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable altserver-native-healthcheck.timer
systemctl enable altserver-native-boot-recover.service

echo "Installed helper scripts and recovery units."
