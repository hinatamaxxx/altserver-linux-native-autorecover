# セットアップ手順 / Setup Guide

## 日本語

この手順は、Debian上でAltServer-Linuxを自動起動し、Wi-Fiリフレッシュが不安定になったときも自動復旧できるようにするためのものです。

実際の端末ID、MACアドレス、IPアドレス、Apple ID、パスワードはこのリポジトリに書かないでください。実機の値はDebian上の `/etc/altserver-native.env` にだけ保存します。

### 検証済み環境

```text
Debian GNU/Linux 13.1 (trixie)
kernel: 6.12.48+deb13-amd64
systemd
amd64 / x86_64
```

Debian以外では未検証です。

### 簡単インストール

通常はこちらだけで導入できます。

```sh
sudo sh install.sh
```

途中で行うこと:

1. iPhoneをDebian端末にUSB接続する
2. iPhone側で「信頼」を押す
3. インストーラの質問に答える
4. AltStore/AltServer側で求められた場合だけApple IDと二段階認証コードを入力する

Apple IDとパスワードは `install.sh` に入力しません。リポジトリ内のファイルにも絶対に書かないでください。

Debian再起動後、iPhone側で再度「信頼」が表示される場合があります。その場合は押してください。信頼後、healthcheckとboot recoveryがAltServerを復旧します。

### インストーラの中身

`install.sh` は次を行います。

- `apt` で必要なパッケージを入れる
- 必要なら最新の `usbmuxd` をソースからビルドして `usbmuxd-local.service` として起動する
- AltServer-Linux `v0.0.5` から `AltServer` を取得する
- `jkcoxson/netmuxd v0.1.4` から対象アーキテクチャ用の `netmuxd` を取得する
- USB接続済みiPhoneからUDIDとWi-Fi MACを読む
- `/etc/altserver-native.env` を作る
- systemdサービスと自動復旧タイマーを入れる
- anisette互換サーバーをDockerで起動する
- 復旧用healthcheckを1分ごとに実行する

### なぜ netmuxd v0.1.4 固定なのか

検証では、`netmuxd v0.3.2` の現在のLinux向け配布アセットを使うと、AltServerのmDNS広告は出ているのに、AltServerがiPhoneへ接続できず、AltStore側では `AltServer could not be found` と表示される状態になりました。

一方、`netmuxd v0.1.4` の `x86_64-linux-netmuxd` では、USB接続とWi-Fiリフレッシュの両方が成功しました。そのため、このセットアップでは再現性を優先して `v0.1.4` を固定しています。

根本的な問題と将来の改善案は [known-issues.md](known-issues.md) にまとめています。

### 手動で状態確認する

```sh
sudo systemctl status altserver-native.service
sudo systemctl status altserver-native-netmuxd.service
sudo systemctl status altserver-anisette-docker.service
sudo /usr/local/sbin/altserver-native-healthcheck
```

mDNS確認:

```sh
avahi-browse -rt _altserver._tcp
avahi-browse -rt _apple-mobdev2._tcp
```

anisette確認:

```sh
curl -i http://127.0.0.1:6969/
```

正常なら `Content-Type: application/json` の応答が返ります。

### 再起動テスト

```sh
sudo reboot
```

Debianが戻ってきたら2-3分待って、次を確認します。

```sh
systemctl status altserver-native-boot-recover.service
journalctl -t altserver-health -b -n 30 --no-pager
```

`healthy` が出ていれば、自動起動と自動復旧が動いています。

## English

This guide sets up AltServer-Linux on Debian with automatic startup and recovery for Wi-Fi refresh.

Do not write real device IDs, MAC addresses, IP addresses, Apple ID, or passwords into this repository. Store real local values only in `/etc/altserver-native.env` on the Debian host.

### Verified Environment

```text
Debian GNU/Linux 13.1 (trixie)
kernel: 6.12.48+deb13-amd64
systemd
amd64 / x86_64
```

Other distributions are unverified.

### Easy Install

Most users should run:

```sh
sudo sh install.sh
```

During installation:

1. Connect the iPhone to the Debian machine by USB.
2. Tap Trust on the iPhone.
3. Answer the installer prompts.
4. Enter the Apple ID and two-factor code only when AltStore/AltServer asks for them.

Do not enter your Apple ID or password into `install.sh`. Never write them into repository files.

After a Debian reboot, the iPhone may show Trust again. Tap Trust if it appears. After Trust is accepted, healthcheck and boot recovery will bring AltServer back.

### What The Installer Does

`install.sh` will:

- Install required packages with `apt`.
- Build a recent `usbmuxd` from source when enabled.
- Download `AltServer` from AltServer-Linux `v0.0.5`.
- Download architecture-specific `netmuxd` from `jkcoxson/netmuxd v0.1.4`.
- Read the iPhone UDID and Wi-Fi MAC from a trusted USB connection.
- Write `/etc/altserver-native.env`.
- Install systemd services and recovery timers.
- Run an anisette compatibility service through Docker.
- Run the recovery healthcheck every 1 minute.

### Why netmuxd v0.1.4 Is Pinned

During verification, the current Linux release asset from `netmuxd v0.3.2` made AltServer discoverable through mDNS, but AltServer could not connect to the device. AltStore displayed `AltServer could not be found`.

`netmuxd v0.1.4` with `x86_64-linux-netmuxd` was verified to work with both USB and Wi-Fi refresh. This setup pins `v0.1.4` for reproducibility.

See [known-issues.md](known-issues.md) for the root issue and future work.

### Manual Checks

```sh
sudo systemctl status altserver-native.service
sudo systemctl status altserver-native-netmuxd.service
sudo systemctl status altserver-anisette-docker.service
sudo /usr/local/sbin/altserver-native-healthcheck
```

mDNS:

```sh
avahi-browse -rt _altserver._tcp
avahi-browse -rt _apple-mobdev2._tcp
```

anisette:

```sh
curl -i http://127.0.0.1:6969/
```

The anisette response should be JSON.

### Reboot Test

```sh
sudo reboot
```

After Debian returns, wait two to three minutes and check:

```sh
systemctl status altserver-native-boot-recover.service
journalctl -t altserver-health -b -n 30 --no-pager
```
