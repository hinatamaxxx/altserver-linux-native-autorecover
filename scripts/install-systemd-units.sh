#!/bin/sh
set -eu

ENV_FILE="${ENV_FILE:-/etc/altserver-native.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE. Copy config/altserver-native.env.example and fill local values first." >&2
  exit 1
fi

. "$ENV_FILE"

install -d /usr/local/sbin
install -d /etc/systemd/system
install -d /etc/systemd/system/altserver-native.service.d
install -d /etc/systemd/system/altserver-native-netmuxd.service.d

cat >/etc/systemd/system/altserver-native-netmuxd.service <<UNIT
[Unit]
Description=AltServer native netmuxd
After=network-online.target avahi-daemon.service
Wants=network-online.target avahi-daemon.service

[Service]
Type=simple
WorkingDirectory=${ALTSERVER_HOME}
ExecStart=${NETMUXD_BIN} --disable-unix --host 127.0.0.1 --plist-storage /var/lib/lockdown
Restart=always
RestartSec=5
StandardOutput=append:${ALTSERVER_HOME}/logs/netmuxd.out.log
StandardError=append:${ALTSERVER_HOME}/logs/netmuxd.err.log

[Install]
WantedBy=multi-user.target
UNIT

cat >/etc/systemd/system/altserver-native.service <<UNIT
[Unit]
Description=AltServer native
After=network-online.target avahi-daemon.service altserver-anisette-docker.service altserver-native-netmuxd.service iphone-mobdev-address.service iphone-mobdev-service.service
Wants=network-online.target avahi-daemon.service altserver-anisette-docker.service altserver-native-netmuxd.service iphone-mobdev-address.service iphone-mobdev-service.service

[Service]
Type=simple
WorkingDirectory=${ALTSERVER_HOME}
EnvironmentFile=${ENV_FILE}
Environment=TZ=UTC
ExecStart=${ALTSERVER_BIN}
Restart=always
RestartSec=5
StandardOutput=append:${ALTSERVER_HOME}/logs/altserver.out.log
StandardError=append:${ALTSERVER_HOME}/logs/altserver.err.log

[Install]
WantedBy=multi-user.target
UNIT

cat >/etc/systemd/system/altserver-anisette-docker.service <<UNIT
[Unit]
Description=AltServer anisette compatibility container
After=docker.service docker.socket containerd.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=simple
Environment="ENV_FILE=${ENV_FILE}"
Restart=always
RestartSec=5
TimeoutStartSec=60
ExecStartPre=/bin/sh -c 'i=0; while [ "\$i" -lt 30 ]; do /usr/bin/docker info >/dev/null 2>&1 && exit 0; i=\$((i+1)); sleep 2; done; exit 1'
ExecStart=/usr/local/sbin/altserver-anisette-docker-run
ExecStop=/usr/bin/docker stop altserver-anisette

[Install]
WantedBy=multi-user.target
UNIT

cat >/etc/systemd/system/iphone-mobdev-address.service <<UNIT
[Unit]
Description=Publish iPhone Wi-Fi address for netmuxd
After=network-online.target avahi-daemon.service
Wants=network-online.target avahi-daemon.service

[Service]
Type=simple
EnvironmentFile=${ENV_FILE}
Environment="ENV_FILE=${ENV_FILE}"
ExecStart=/usr/local/sbin/iphone-mobdev-address-publisher
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

cat >/etc/systemd/system/iphone-mobdev-service.service <<UNIT
[Unit]
Description=Publish iPhone mobdev service for netmuxd
After=network-online.target avahi-daemon.service iphone-mobdev-address.service
Wants=network-online.target avahi-daemon.service iphone-mobdev-address.service

[Service]
Type=simple
EnvironmentFile=${ENV_FILE}
Environment="ENV_FILE=${ENV_FILE}"
ExecStart=/usr/local/sbin/iphone-mobdev-service-publisher
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable docker.service avahi-daemon.service
systemctl enable altserver-anisette-docker.service
systemctl enable altserver-native-netmuxd.service
systemctl enable iphone-mobdev-address.service iphone-mobdev-service.service
systemctl enable altserver-native.service

echo "Installed and enabled systemd units."
