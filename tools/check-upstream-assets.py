#!/usr/bin/env python3
import json
import sys
import urllib.request


def release(repo, tag):
    url = f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else "jkcoxson/netmuxd"
    tag = sys.argv[2] if len(sys.argv) > 2 else "v0.1.4"
    asset_name = sys.argv[3] if len(sys.argv) > 3 else "x86_64-linux-netmuxd"

    data = release(repo, tag)
    assets = data.get("assets", [])
    print(f"repo={repo}")
    print(f"tag={data.get('tag_name')}")
    print(f"required_asset={asset_name}")
    print("assets:")
    found = False
    for asset in assets:
        name = asset.get("name")
        print(f"- {name}")
        if name == asset_name:
            found = True
            print(f"  url={asset.get('browser_download_url')}")
            print(f"  size={asset.get('size')}")

    return 0 if found else 1


if __name__ == "__main__":
    raise SystemExit(main())
