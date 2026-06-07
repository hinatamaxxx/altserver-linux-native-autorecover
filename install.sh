#!/bin/sh
set -eu

ALTSTORE_AUTORECOVER_VERSION="0.1.0"
ALTSERVER_VERSION="${ALTSERVER_VERSION:-v0.0.5}"
ALTSERVER_REPO="${ALTSERVER_REPO:-NyaMisty/AltServer-Linux}"
NETMUXD_REPO="${NETMUXD_REPO:-jkcoxson/netmuxd}"
NETMUXD_VERSION="${NETMUXD_VERSION:-v0.1.4}"
INSTALL_DIR="${INSTALL_DIR:-/opt/altserver-native}"
ENV_FILE="${ENV_FILE:-/etc/altserver-native.env}"

say() {
  printf '\n%s\n' "$*"
}

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo sh install.sh" >&2
    exit 1
  fi
}

ask() {
  prompt="$1"
  default="$2"
  printf '%s' "$prompt" >&2
  if [ -n "$default" ]; then
    printf ' [%s]' "$default" >&2
  fi
  printf ': ' >&2
  read -r value
  if [ -z "$value" ]; then
    value="$default"
  fi
  printf '%s' "$value"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    armv7l|armv7*) echo "armv7" ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

altserver_asset_name() {
  case "$1" in
    x86_64) echo "AltServer-x86_64" ;;
    aarch64) echo "AltServer-aarch64" ;;
    armv7) echo "AltServer-armv7" ;;
  esac
}

netmuxd_asset_name() {
  case "$1" in
    x86_64) echo "x86_64-linux-netmuxd" ;;
    aarch64) echo "aarch64-linux-netmuxd" ;;
    armv7) echo "armv7-linux-netmuxd" ;;
  esac
}

download() {
  url="$1"
  out="$2"
  say "Downloading: $url"
  curl -fL --retry 3 --connect-timeout 15 "$url" -o "$out"
}

detect_host_ip() {
  ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}'
}

wait_for_usb_pairing() {
  printf '\n%s\n' "iPhoneをUSBで接続して、iPhone側で「信頼」を押してください。" >&2
  printf '%s\n' "Connect the iPhone by USB and tap Trust on the iPhone." >&2
  printf '%s\n' "検出できるまで待ちます。" >&2

  i=0
  while [ "$i" -lt 90 ]; do
    udid="$(idevice_id -l 2>/dev/null | head -n1 || true)"
    if [ -n "$udid" ]; then
      echo "$udid"
      return 0
    fi
    i=$((i+1))
    sleep 2
  done

  echo "Could not detect a trusted iPhone over USB." >&2
  echo "Reconnect USB, unlock iPhone, tap Trust, then run this installer again." >&2
  exit 1
}

validate_udid() {
  case "$1" in
    ""|*" "*|*"	"*|*":"*) return 1 ;;
    *) return 0 ;;
  esac
}

read_wifi_mac() {
  udid="$1"
  ideviceinfo -u "$udid" -k WiFiAddress 2>/dev/null | head -n1 || true
}

install_packages() {
  say "Installing Debian packages..."
  apt-get update

  packages="\
    avahi-daemon avahi-utils libavahi-compat-libdnssd-dev \
    curl ca-certificates netcat-openbsd python3 \
    usbmuxd libimobiledevice-utils iproute2 tar gzip"

  if command -v docker >/dev/null 2>&1; then
    say "Docker is already installed; leaving the existing Docker installation untouched."
  else
    packages="$packages docker.io"
  fi

  # shellcheck disable=SC2086
  DEBIAN_FRONTEND=noninteractive apt-get install -y $packages
}

install_latest_usbmuxd() {
  if [ "${BUILD_LATEST_USBMUXD:-auto}" = "0" ] || [ "${BUILD_LATEST_USBMUXD:-auto}" = "false" ]; then
    say "Skipping latest usbmuxd build because BUILD_LATEST_USBMUXD=${BUILD_LATEST_USBMUXD}."
    return 0
  fi

  say "Building latest usbmuxd from libimobiledevice/usbmuxd..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential pkg-config git autoconf automake libtool-bin \
    libplist-dev libusbmuxd-dev libimobiledevice-dev libimobiledevice-glue-dev \
    libusb-1.0-0-dev udev

  src=/opt/libimobiledevice-src/usbmuxd
  mkdir -p /opt/libimobiledevice-src
  if [ -d "$src/.git" ]; then
    git -C "$src" fetch --all --prune
    git -C "$src" reset --hard origin/master
  else
    git clone https://github.com/libimobiledevice/usbmuxd.git "$src"
  fi

  (
    cd "$src"
    ./autogen.sh --prefix=/usr/local --without-systemd
    make -j"$(nproc)"
    make install
  )
  ldconfig

  systemctl stop usbmuxd.service usbmuxd.socket 2>/dev/null || true
  systemctl disable usbmuxd.service usbmuxd.socket 2>/dev/null || true
  pkill -x usbmuxd 2>/dev/null || true

  cat >/etc/systemd/system/usbmuxd-local.service <<'UNIT'
[Unit]
Description=Latest local usbmuxd for AltServer
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/usbmuxd -f -v -U root
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable --now usbmuxd-local.service
}

install_binaries() {
  arch="$1"
  mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/logs"

  alt_asset="$(altserver_asset_name "$arch")"
  alt_url="https://github.com/${ALTSERVER_REPO}/releases/download/${ALTSERVER_VERSION}/${alt_asset}"
  tmpdir="$(mktemp -d)"
  download "$alt_url" "$tmpdir/AltServer"
  chmod 755 "$tmpdir/AltServer"
  mv -f "$tmpdir/AltServer" "$INSTALL_DIR/bin/AltServer"
  rm -rf "$tmpdir"

  netmux_asset="$(netmuxd_asset_name "$arch")"
  netmux_url="https://github.com/${NETMUXD_REPO}/releases/download/${NETMUXD_VERSION}/${netmux_asset}"
  tmpdir="$(mktemp -d)"
  download "$netmux_url" "$tmpdir/netmuxd"
  chmod 755 "$tmpdir/netmuxd"
  mv -f "$tmpdir/netmuxd" "$INSTALL_DIR/bin/netmuxd"
  rm -rf "$tmpdir"
}

write_env() {
  host_ip="$1"
  udid="$2"
  wifi_mac="$3"
  iphone_ip="$4"

  cat >"$ENV_FILE" <<EOF
ALTSERVER_HOST_IP=$host_ip
IPHONE_UDID=$udid
IPHONE_WIFI_MAC=$wifi_mac
IPHONE_FALLBACK_IP=$iphone_ip
ALTSERVER_HOME=$INSTALL_DIR
ALTSERVER_BIN=$INSTALL_DIR/bin/AltServer
NETMUXD_BIN=$INSTALL_DIR/bin/netmuxd
USBMUXD_SOCKET_ADDRESS=127.0.0.1:27015
ALTSERVER_NO_SUBSCRIBE=1
ALTSERVER_ANISETTE_SERVER=http://127.0.0.1:6969
ANISETTE_URL=http://127.0.0.1:6969/
ANISETTE_DOCKER_IMAGE=${ANISETTE_DOCKER_IMAGE:-dadoum/anisette-v3-server:latest}
ANISETTE_DOCKER_VOLUME=${ANISETTE_DOCKER_VOLUME:-altserver-anisette-data}
EOF

  chmod 600 "$ENV_FILE"
}

install_anisette_hint_tree() {
  mkdir -p "$INSTALL_DIR/anisette"
  cat >"$INSTALL_DIR/anisette/README.txt" <<'EOF'
This directory is reserved for optional anisette compatibility files.

The default setup uses dadoum/anisette-v3-server and stores its state in a Docker volume.

No Apple ID, password, or pairing files should be stored here.
EOF
}

main() {
  need_root

  say "AltServer Linux Native Autorecover installer ${ALTSTORE_AUTORECOVER_VERSION}"
  say "このインストーラはApple IDやパスワードを保存しません。"
  say "This installer never stores your Apple ID or password."

  arch="$(detect_arch)"
  host_ip_default="$(detect_host_ip || true)"
  host_ip="${ALTSERVER_HOST_IP:-}"
  if [ -z "$host_ip" ]; then
    host_ip="$(ask "DebianのLAN IP / Debian LAN IP" "$host_ip_default")"
  fi

  install_packages
  install_latest_usbmuxd

  udid="${IPHONE_UDID:-}"
  wifi_mac="${IPHONE_WIFI_MAC:-}"
  used_env_device=0
  if [ -n "$udid" ] && [ -n "$wifi_mac" ]; then
    used_env_device=1
  fi
  if [ -z "$udid" ] || [ -z "$wifi_mac" ]; then
    systemctl restart usbmuxd-local.service 2>/dev/null || systemctl start usbmuxd.service 2>/dev/null || systemctl start usbmuxd 2>/dev/null || true
    sleep 3
    udid="$(wait_for_usb_pairing)"
    if ! validate_udid "$udid"; then
      echo "Invalid iPhone UDID detected. Please reconnect USB and try again." >&2
      exit 1
    fi
    wifi_mac="$(read_wifi_mac "$udid")"
  fi
  if [ -z "$wifi_mac" ]; then
    wifi_mac="$(ask "iPhoneのWi-Fi MAC / iPhone Wi-Fi MAC" "")"
  elif [ "$used_env_device" -eq 1 ]; then
    say "Using iPhone UDID and Wi-Fi MAC from environment variables."
  else
    say "Detected iPhone UDID and Wi-Fi MAC over USB."
  fi

  iphone_ip_default="$(ip neigh show | awk -v mac="$(printf '%s' "$wifi_mac" | tr 'A-F' 'a-f')" 'tolower($0) ~ mac {print $1; exit}')"
  iphone_ip="${IPHONE_FALLBACK_IP:-}"
  if [ -z "$iphone_ip" ]; then
    iphone_ip="$(ask "iPhoneのLAN IP / iPhone LAN IP" "$iphone_ip_default")"
  fi

  install_binaries "$arch"
  install_anisette_hint_tree
  write_env "$host_ip" "$udid" "$wifi_mac" "$iphone_ip"

  script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  ENV_FILE="$ENV_FILE" sh "$script_dir/scripts/install-helper-scripts.sh"
  ENV_FILE="$ENV_FILE" sh "$script_dir/scripts/install-systemd-units.sh"

  systemctl enable altserver-native-healthcheck.timer altserver-native-boot-recover.service
  systemctl restart docker.service avahi-daemon.service || true
  systemctl restart altserver-anisette-docker.service || true
  systemctl restart altserver-native-netmuxd.service
  sleep 3
  systemctl restart iphone-mobdev-address.service iphone-mobdev-service.service
  sleep 8
  systemctl restart altserver-native.service
  systemctl restart altserver-native-healthcheck.timer

  say "Running healthcheck..."
  /usr/local/sbin/altserver-native-healthcheck || true

  say "Done."
  say "次にやること:"
  say "1. iPhoneでAltStoreを開く"
  say "2. 必要な場合だけApple IDと二段階認証コードをAltStore/AltServerに入力する"
  say "3. USB接続とWi-Fi接続の両方でrefreshを試す"
  say "4. Debianを再起動し、数分後に自動復旧を確認する"
}

check_downloads() {
  arch="$(detect_arch)"
  tmpdir="$(mktemp -d)"
  INSTALL_DIR="$tmpdir/install"
  say "Testing upstream downloads into $INSTALL_DIR"
  install_binaries "$arch"
  "$INSTALL_DIR/bin/AltServer" --help >/dev/null 2>&1 || true
  "$INSTALL_DIR/bin/netmuxd" --help >/dev/null 2>&1 || true
  file "$INSTALL_DIR/bin/AltServer" "$INSTALL_DIR/bin/netmuxd"
  rm -rf "$tmpdir"
  say "Download check completed."
}

case "${1:-}" in
  --check-downloads)
    check_downloads
    ;;
  *)
    main "$@"
    ;;
esac
