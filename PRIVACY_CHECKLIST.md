# 公開前の個人情報チェック / Privacy Checklist

## 日本語

GitHub に push する前に、必ずこのファイルを確認してください。

### 絶対に入れてはいけないもの

- 実際の iPhone UDID
- 実際の iPhone Wi-Fi MAC アドレス
- 自宅LANの実IPアドレス
- Apple ID
- パスワード、アプリ用パスワード
- pairing file
- SSH秘密鍵
- Debian の実ユーザー名
- Debian の実ホスト名
- 実行ログ

### 入っていてよいもの

テンプレートや説明文としてのプレースホルダはOKです。

例:

```text
<DEBIAN_LAN_IP>
<IPHONE_UDID>
<IPHONE_WIFI_MAC>
<IPHONE_LAN_IP>
```

### ローカルで確認するコマンド

Git Bash、WSL、Linux、Debian 上などで実行できます。

```sh
grep -RInE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' .
grep -RInE '192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+' .
grep -RInE 'password|passwd|apple.?id|mobiledevicepairing|BEGIN .*PRIVATE KEY' .
```

PowerShell の場合:

```powershell
Get-ChildItem -Recurse -File | Select-String -Pattern '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}'
Get-ChildItem -Recurse -File | Select-String -Pattern '192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+'
Get-ChildItem -Recurse -File | Select-String -Pattern 'password|passwd|apple.?id|mobiledevicepairing|BEGIN .*PRIVATE KEY'
```

ヒットがあった場合は、プレースホルダか説明文だけかを確認してください。実際の値があれば削除してください。

## English

Before pushing to GitHub, verify that no personal or device-specific data is included.

Never commit:

- Real iPhone UDID
- Real iPhone Wi-Fi MAC address
- Real home LAN IP address
- Apple ID
- Passwords or app-specific passwords
- Pairing files
- SSH private keys
- Real Debian username
- Real Debian hostname
- Execution logs

Placeholders such as `<IPHONE_UDID>` are allowed.

Never write your Apple ID or password into any GitHub-tracked file in this repository. Apple ID credentials should be entered only in the appropriate AltStore/AltServer flow, not stored in this setup.
