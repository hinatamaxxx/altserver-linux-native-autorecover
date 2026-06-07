# 公開手順 / Publishing Guide

## 日本語

このプロジェクトは、AltServer-Linux本体のフォークではなく、Debian上でAltServer-Linuxを常駐させるための補助インストーラです。

そのため、GitHubでは `NyaMisty/AltServer-Linux` のフォークとしてではなく、新規リポジトリとして公開するのがおすすめです。

### 推奨リポジトリ名

例:

```text
altserver-linux-native-autorecover
altserver-linux-debian-autorecover
altserver-linux-debian-helper
```

### 公開前チェック

公開前に必ず確認してください。

```sh
node tools/privacy-scan.js .
python3 tools/check-upstream-assets.py
sh install.sh --check-downloads
```

Windows上で通常の `node` が動かない場合は、利用できるNode実行環境で `tools/privacy-scan.js` を実行してください。

### GitHubへ上げる対象

このディレクトリの中身だけを新規リポジトリに入れてください。

上げてよいもの:

- `README.md`
- `install.sh`
- `LICENSE`
- `.gitignore`
- `PRIVACY_CHECKLIST.md`
- `config/`
- `docs/`
- `scripts/`
- `tools/`

上げてはいけないもの:

- SSH秘密鍵
- 実機の `/etc/altserver-native.env`
- pairing file
- 実行ログ
- 作業用の一時スクリプト
- iPhone UDIDやMACアドレスが入ったファイル

### 公開後にREADMEで置き換える場所

README内のGitHub URLが、実際の公開先と一致していることを確認してください。

## English

This project is not a fork of AltServer-Linux itself. It is a helper installer for running AltServer-Linux continuously on Debian.

Publishing it as a new GitHub repository is recommended.

### Suggested Repository Names

```text
altserver-linux-native-autorecover
altserver-linux-debian-autorecover
altserver-linux-debian-helper
```

### Before Publishing

Run:

```sh
node tools/privacy-scan.js .
python3 tools/check-upstream-assets.py
sh install.sh --check-downloads
```

### Publish Only This Directory

Commit only the files inside this directory.

Do not publish SSH private keys, real `/etc/altserver-native.env`, pairing files, logs, temporary repair scripts, or files containing real iPhone UDIDs or MAC addresses.

### Repository URL

Verify that the GitHub URL in README matches the final repository URL.
