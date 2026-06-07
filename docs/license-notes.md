# ライセンス方針 / License Notes

## 日本語

このリポジトリは、Debian上でAltServer-Linuxを常駐させるための補助インストーラです。AltServer-Linux本体、`netmuxd`、anisette serverのバイナリは同梱しません。

このリポジトリに含まれる自作スクリプトと文書はMIT Licenseで公開する想定です。upstreamのバイナリやDocker imageは、それぞれのupstreamのライセンスと配布条件に従います。

`install.sh` は、ユーザーのDebian端末上で公開upstreamリリースから必要なファイルを取得します。

### 含めるもの

- インストーラ
- systemd unit生成スクリプト
- healthcheck script
- boot recovery script
- mDNS helper script
- ドキュメント

### 含めないもの

- AltServer-Linuxのバイナリ
- `netmuxd` のバイナリ
- anisette serverのバイナリ
- Apple ID、パスワード
- pairing file
- SSH秘密鍵
- 実端末のUDID、MACアドレス、IPアドレス
- ログファイル

### upstream 依存

- AltServer-Linux: [NyaMisty/AltServer-Linux](https://github.com/NyaMisty/AltServer-Linux)
- netmuxd: [jkcoxson/netmuxd](https://github.com/jkcoxson/netmuxd)
- anisette Docker image: `dadoum/anisette-v3-server`

このセットアップでは `netmuxd v0.1.4` を固定して取得します。これは実機検証でUSB/Wi-Fiの両方が動作したためです。バイナリは同梱せず、GitHub Releasesからユーザー環境へダウンロードします。

## English

This repository is a helper installer for running AltServer-Linux continuously on Debian. It does not vendor AltServer-Linux, `netmuxd`, or anisette server binaries.

The scripts and documentation in this repository are intended to be published under the MIT License. Upstream binaries and Docker images remain governed by their own upstream licenses and distribution terms.

`install.sh` downloads required files from public upstream releases on the user's Debian machine.

### Included

- Installer
- scripts that generate systemd units
- healthcheck script
- boot recovery script
- mDNS helper scripts
- documentation

### Not Included

- AltServer-Linux binaries
- `netmuxd` binaries
- anisette server binaries
- Apple ID or passwords
- pairing files
- SSH private keys
- real device UDIDs, MAC addresses, or IP addresses
- log files

### Upstream Dependencies

- AltServer-Linux: [NyaMisty/AltServer-Linux](https://github.com/NyaMisty/AltServer-Linux)
- netmuxd: [jkcoxson/netmuxd](https://github.com/jkcoxson/netmuxd)
- anisette Docker image: `dadoum/anisette-v3-server`

This setup pins `netmuxd v0.1.4` because it was verified to work with both USB and Wi-Fi refresh. The binary is not bundled; it is downloaded from GitHub Releases on the user's machine.
