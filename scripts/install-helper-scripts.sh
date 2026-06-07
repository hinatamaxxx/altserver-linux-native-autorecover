#!/bin/sh
set -eu

install -d /usr/local/sbin

install -m 0755 scripts/runtime/iphone-mobdev-address-publisher /usr/local/sbin/iphone-mobdev-address-publisher
install -m 0755 scripts/runtime/iphone-mobdev-service-publisher /usr/local/sbin/iphone-mobdev-service-publisher
install -m 0755 scripts/runtime/altserver-native-healthcheck /usr/local/sbin/altserver-native-healthcheck
install -m 0755 scripts/runtime/altserver-native-boot-recover /usr/local/sbin/altserver-native-boot-recover
install -m 0755 scripts/runtime/altserver-anisette-docker-run /usr/local/sbin/altserver-anisette-docker-run

cat >/etc/systemd/system/altserver-native-healthcheck.service <<'UNIT'
[Unit]
Description=Repair AltServer native Wi-Fi refresh stack when discovery goes stale
After=network-online.target avahi-daemon.service docker.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/altserver-native-healthcheck
UNIT

cat >/etc/systemd/system/altserver-native-healthcheck.timer <<'UNIT'
[Unit]
Description=Periodic AltServer native Wi-Fi refresh health check

[Timer]
OnBootSec=60
OnUnitActiveSec=1min
AccuracySec=10s
Persistent=true

[Install]
WantedBy=timers.target
UNIT

cat >/etc/systemd/system/altserver-native-boot-recover.service <<'UNIT'
[Unit]
Description=Run AltServer Wi-Fi refresh recovery after boot
After=multi-user.target network-online.target docker.service avahi-daemon.service altserver-anisette-docker.service altserver-native-netmuxd.service iphone-mobdev-address.service iphone-mobdev-service.service
Wants=network-online.target docker.service avahi-daemon.service altserver-anisette-docker.service altserver-native-netmuxd.service iphone-mobdev-address.service iphone-mobdev-service.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/altserver-native-boot-recover

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable altserver-native-healthcheck.timer
systemctl enable altserver-native-boot-recover.service

echo "Installed helper scripts and recovery units."
