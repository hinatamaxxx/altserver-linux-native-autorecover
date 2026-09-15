# AltServer Linux Native Autorecover

Debianで [NyaMisty/AltServer-Linux](https://github.com/NyaMisty/AltServer-Linux) を常駐させ、USB接続とWi-Fiリフレッシュを使えるようにするための簡単セットアップです。

このリポジトリは **AltServer-Linux本体のフォークではありません**。AltServer-Linuxと関連ツールを公開リリースから取得し、Debian上で24時間動くようにsystemdサービス、自動復旧、ヘルスチェックを入れる補助インストーラです。

## 日本語

### 既存環境で公式netmuxd v0.4.3を使う

旧AltServerとのアドレス形式の不一致を、**netmuxd本体を変更しない外部変換**で解消する互換性プロファイルを追加しました。Wi-Fi再接続後は公式APIで端末を再登録します。
amd64の既存実機でWi-Fi更新を確認しています。[原因・試験・永続化・元に戻す手順](docs/netmuxd-compatibility.md)を参照してください。通常インストーラの既存デフォルトとは別の、明示的に導入するプロファイルです。

### これは何？

「Debian端末をAltServer専用機として置いておきたい」「Windows PCを常時起動できない」「USBでは動くのにWi-Fi refreshが不安定」という人向けのセットアップです。

目標はこの流れです。

1. Debian端末にこのリポジトリを入れる
2. iPhoneをUSBでつなぐ
3. iPhone側で「信頼」を押す
4. `sudo sh install.sh` を実行する
5. AltStore/AltServerに求められたときだけApple IDと二段階認証コードを入力する
6. 以後、Debian上でAltServerが自動起動する

### 重要な注意

Apple IDやパスワードを、このリポジトリのファイルや `install.sh` に入力しないでください。

Apple IDは、AltStore/AltServerの画面で求められたときだけ入力します。このリポジトリはApple IDやパスワードを保存しません。

### 検証済み環境

実機検証済み:

```text
Debian GNU/Linux 13.1 (trixie)
kernel: 6.12.48+deb13-amd64
systemd
amd64 / x86_64
```

Debian以外は未検証です。UbuntuやRaspberry Pi OSでは動く可能性がありますが、そのまま動く保証はありません。

### 事前に必要なもの

- Debianが入った端末
- Debian端末がインターネットに接続できること
- iPhoneとDebian端末をつなぐUSBケーブル
- Debianで `sudo` できるユーザー
- AltStore Classicが入ったiPhone

### いちばん簡単な導入

Debian上でこのリポジトリをcloneします。

```sh
git clone https://github.com/hinatamaxxx/altserver-linux-native-autorecover.git
cd altserver-linux-native-autorecover
sudo sh install.sh
```

インストール中にiPhoneをUSBで接続し、iPhone側で「信頼」が出たら押してください。

インストーラが行うこと:

- 必要なDebianパッケージを入れる
- 必要に応じて新しい `usbmuxd` をビルドする
- AltServer-Linux `v0.0.5` の公開リリースからAltServerを取得する
- `jkcoxson/netmuxd v0.1.4` の公開リリースから `netmuxd` を取得する
- USB接続されたiPhoneからUDIDとWi-Fi MACを読み取る
- `/etc/altserver-native.env` を作成する
- systemdサービスを作成する
- anisette互換サーバーをDockerで起動する
- Debian起動時の自動起動と1分ごとの自動復旧を有効にする

### インストール後に確認する

```sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

正常なら最後に `healthy` と表示されます。

サービス状態を見る場合:

```sh
systemctl status altserver-native.service
systemctl status altserver-native-netmuxd.service
systemctl status altserver-anisette-docker.service
```

### Debianを再起動した後

Debian再起動後、iPhone側で再度「信頼」が表示される場合があります。その場合は押してください。

信頼後、healthcheckとboot recoveryがAltServerを復旧します。

```sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

### なぜ netmuxd v0.1.4 固定？

AltServer-LinuxのWi-Fiリフレッシュには、通常の `usbmuxd` だけではなく `netmuxd` が必要です。

検証中、`netmuxd v0.3.2` の現在のLinux向け配布アセットでは、AltServerはmDNSで見えているのにiPhone接続で失敗し、AltStore側では `AltServer could not be found` と表示されました。

一方、`netmuxd v0.1.4` の `x86_64-linux-netmuxd` ではUSB/Wi-Fiの両方で動作しました。そのため、このセットアップでは再現性を優先して `v0.1.4` を固定しています。

### 根本問題について

v0.2.0では、Anisetteの端末ID・認証データの保存漏れ、別端末のIPを拾う探索、毎分のAvahi再読み込み、通信の分割受信の誤判定を修正しました。短時間の障害では再起動せず、iPhoneの再登録とサービス障害を分けて処理します。上流netmuxd自体のheartbeat制約は残っています。

既存環境は、旧Anisetteコンテナが存在する間に次を実行してください。現在の認証用データを保存してから更新します。

```sh
sudo sh scripts/upgrade-runtime.sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

二段階認証の保存漏れと移行・確認方法は [docs/runtime-fixes.md](docs/runtime-fixes.md) を参照してください。

根本的な問題と今後の改善案は [docs/known-issues.md](docs/known-issues.md) にまとめています。

### 個人情報を入れないでください

GitHubに上げてはいけないもの:

- Apple ID
- パスワード、アプリ用パスワード
- iPhoneのUDID
- iPhoneのWi-Fi MACアドレス
- 自宅LANの実IPアドレス
- Debianのユーザー名
- SSH秘密鍵
- pairing file
- ログファイル

実際の値はDebian上の `/etc/altserver-native.env` にだけ保存します。このファイルはGitHubに含めません。

### 困ったとき

詳しくは [docs/troubleshooting.md](docs/troubleshooting.md) を見てください。

まず見るコマンド:

```sh
sudo /usr/local/sbin/altserver-native-healthcheck
journalctl -u altserver-native.service -n 80 --no-pager
journalctl -u altserver-native-netmuxd.service -n 80 --no-pager
```

## English

This repository provides an easy Debian setup for running [NyaMisty/AltServer-Linux](https://github.com/NyaMisty/AltServer-Linux) continuously with USB and Wi-Fi refresh support.

This is **not a fork of AltServer-Linux itself**. It downloads upstream AltServer-Linux and related tools from public releases, then installs systemd services, healthchecks, and recovery scripts so AltServer can run 24/7 on Debian.

### Quick Start

```sh
git clone https://github.com/hinatamaxxx/altserver-linux-native-autorecover.git
cd altserver-linux-native-autorecover
sudo sh install.sh
```

Connect the iPhone by USB and tap Trust when prompted on the iPhone.

Do not enter your Apple ID or password into `install.sh`. Enter Apple ID credentials only when AltStore/AltServer asks for them.

### Verified Environment

```text
Debian GNU/Linux 13.1 (trixie)
kernel: 6.12.48+deb13-amd64
systemd
amd64 / x86_64
```

Other distributions are not verified.

### What The Installer Does

- Installs required Debian packages.
- Builds a newer `usbmuxd` when enabled.
- Downloads AltServer from AltServer-Linux `v0.0.5`.
- Downloads `netmuxd v0.1.4`.
- Reads the iPhone UDID and Wi-Fi MAC from a trusted USB connection.
- Writes `/etc/altserver-native.env`.
- Installs systemd services.
- Runs an anisette compatibility server through Docker.
- Enables boot-time startup and a 1-minute recovery healthcheck.

### Verify

```sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

The expected result is `healthy`.

### Privacy

Never commit Apple ID credentials, passwords, iPhone UDID, Wi-Fi MAC addresses, real home LAN IP addresses, SSH keys, pairing files, or logs.

Real local values should exist only on the Debian host in `/etc/altserver-native.env`.

### More Docs

- [Setup guide](docs/setup.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Known issues](docs/known-issues.md)
- [License notes](docs/license-notes.md)
- [Verification notes](docs/verification.md)
- [Privacy checklist](PRIVACY_CHECKLIST.md)
