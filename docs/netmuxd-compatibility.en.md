# netmuxd version compatibility: cause, recovery and verification

[日本語](netmuxd-compatibility.md)

Investigation date: 2026-09-16. Scope: unmodified AltServer-Linux v0.0.5 on Debian amd64.

## Current status

An opt-in compatibility profile uses **unmodified official netmuxd v0.4.3**, an external address-format adapter, and the official device registration API. It is installed persistently on the tested existing host. The original binary and a restoration script are retained.

The ordinary installer still defaults to v0.1.4. This profile has not been verified as a fresh installation or on other architectures.

## Address-format mismatch

AltServer's bundled older libimobiledevice expects BSD `sockaddr` layout: byte 0 is the structure length and byte 1 is the address family. Newer Linux netmuxd builds put the address family in the first two bytes instead. IPv4 bytes `02 00` are interpreted by the old client as length 2 and family 0, reaching its unsupported-family error path.

| Compared binary | First four NetworkAddress bytes | Data length | Legacy client interpretation |
|---|---|---|---|
| Existing v0.1.4-equivalent binary | `0a 02 00 00` | 152 | Recognizable IPv4 layout |
| Official v0.3.2 Linux amd64 | `02 00 00 00` | 152 | Family 0; incompatible |
| Official v0.4.3 Linux amd64 | `02 00 00 00` | 128 | Family 0; incompatible |

The legacy length 10 differs from the conventional BSD IPv4 structure length of 16. Successful operation of that binary is not proof that all its memory handling is correct. The v0.4.3 asset prints v0.4.2 with `--about`; identify it using its release URL and checksum, not that string alone.

### Evidence

- [netmuxd commit 1d0e437](https://github.com/jkcoxson/netmuxd/commit/1d0e4374f8baf065a69ebf186a12eb3a8d509e7a) changes the IPv4 prefix from `0a 02` to `02 00`.
- [AltServer v0.0.5's bundled libimobiledevice](https://github.com/NyaMisty/AltServer-Linux/tree/v0.0.5/libraries/libimobiledevice): `idevice_from_mux_device` and `idevice_connect` in `src/idevice.c` assume the old layout.
- [netmuxd v0.4.3 devices.rs](https://github.com/jkcoxson/netmuxd/blob/v0.4.3/src/devices.rs) chooses layout by build target; it has no CLI switch to emit BSD layout on Linux.
- Related upstream reports: [libimobiledevice #1248](https://github.com/libimobiledevice/libimobiledevice/issues/1248) and [libusbmuxd #134](https://github.com/libimobiledevice/libusbmuxd/issues/134). These reports are separate from this host's measurements.

This is a concrete incompatibility, but detailed logs from the original v0.3.2 failure are unavailable. It does not prove that every historical failure had this single cause.

## Comparison procedure

Production remained on port 27015 while official assets were temporarily started on 27016/27017 with Unix sockets, mDNS and heartbeat disabled; v0.4.3 also had USB disabled. The same phone entry was registered only in the test processes through AddDevice, and actual ListDevices responses were compared. Pairing data was read without deletion or re-pairing. Test processes were stopped afterward. This initial comparison measured wire format, not app refresh success.

Archive SHA-256 values matched the GitHub Releases API digests:

```text
v0.3.2 netmuxd-x86_64-unknown-linux-gnu.tar.gz
1a85e69a258349d2e130aa8475f9d18f212331db3ab46843c0b8b05020f556bb
v0.4.3 netmuxd-x86_64-unknown-linux-gnu.tar.gz
85b6598284fc639f2a282584461d05e2090b79bdf3ec949d2a5e5d3dc655dde4
```

Read-only diagnostic:

```sh
python3 tools/check-netmux-compatibility.py
python3 tools/check-netmux-compatibility.py --port 27016
```

Exit codes: 0 = recognizable legacy layout; 1 = incompatible layout or protocol error; 2 = no network devices, so inconclusive. This check alone does not verify signing, authentication, heartbeat or app installation.

## Alternatives evaluated

| Option | Finding |
|---|---|
| Upgrade official netmuxd only | v0.4.3 still emits incompatible layout for the old client |
| Use `--upstream-usbmuxd` | Forwards requests to the existing muxer; does not translate network addresses |
| Upgrade Debian libraries | AltServer is statically linked, so its embedded implementation is unchanged |
| Replace with usbmuxd2 | [Its Linux implementation](https://github.com/tihmstar/usbmuxd2/blob/744c46f/usbmuxd2/Muxer.cpp) also emits native layout; no published releases were available; not installed |
| New official AltServer-Linux binary | v0.0.5 was the latest published release, with no available Actions artifacts at investigation time |
| External adapter | Adopted and verified; neither upstream binary is modified |
| Windows/macOS AltServer | Requires changing the operating environment; not installed or validated here |

## Trial, persistence and restoration

The adapter uses only Python's standard library and listens on localhost. It translates NetworkAddress in ListDevices and Attached announcements. Pairing replies retain their original frames; after a successful Connect, service bytes pass through unchanged in both directions.

From an updated checkout on an existing amd64 installation:

```sh
sudo sh scripts/trial-netmux-compat.sh
```

The script verifies the official archive checksum, preserves the old binary, installs temporary `/run` units, and schedules automatic restoration after 20 minutes. Routing is AltServer → adapter on 27015 → official netmuxd on 27016. Temporary overrides disappear on reboot.

```sh
# Restore before the trial timer expires
sudo sh /var/lib/altserver-native/netmux-compat-trial/rollback.sh

# After successful testing, while the trial remains active
sudo sh scripts/keep-netmux-compat.sh

# Restore the original profile after persistence
sudo sh /var/lib/altserver-native/netmux-compat-trial/restore-original.sh
```

Persistence adds a separately named official binary and dedicated systemd drop-ins. It retains the original binary and base units, creates the restoration script before disabling the trial timer, and runs the adapter under DynamicUser with filesystem and address-family restrictions.

## Recovery after toggling Wi-Fi

The first toggle reproduced `AltServer could not be found`. Both the raw and translated DeviceList were empty, although the configured phone was reachable. Repeated mDNS reannouncement did not restore registration. Calling official v0.4.3's AddDevice API for the verified address returned success and restored the device list.

Upstream registers on ServiceResolved events and removes devices after heartbeat failure. Missing renewed resolution for a cached service is a plausible explanation; a complete failing mDNS packet trace was not captured, so cache internals were not directly proven.

The new profile sets `NETMUXD_REGISTER_MODE=api` for healthcheck and boot recovery. It registers only the verified configured phone when missing, avoids duplicate registration, and rejects unverified destinations. The old v0.1.4 profile retains mDNS reannouncement because its AddDevice path starts duplicate heartbeat workers.

The user initially still saw an error before recovery. Automatic registration succeeded at 01:37:06 JST, and the subsequent app refresh succeeded. The recovery interval was then reduced from about a minute to **15 seconds after each check finishes**. Recovery immediately after a Wi-Fi change is not guaranteed.

Checks cover Anisette responses, AltServer's real response and advertisement, netmuxd responses, and phone reachability/registration. Healthy checks change nothing. A missing phone is re-registered, not re-paired or logged back into Apple. Service failures trigger a targeted restart only after three consecutive failures, with a five-minute restart cooldown.

## Verification and boot behavior

- 27 regression tests passed on Debian, covering fragmented/invalid frames, identity-aware discovery, identity migration, UTC validation, address translation, unchanged pairing replies, tunnels, half-close, rejected connections and API registration.
- USB-disconnected AltStore refresh succeeded with official v0.4.3 and the adapter, initially without another two-factor prompt.
- Service restart recovered registration; refresh after Wi-Fi loss and automatic re-registration succeeded.
- The installed official binary hash is `d42e0d1ed1a29c38693083db919e4cb2e1ce9e08799fa19a2ee388882d9bcc23`, matching the downloaded asset's extracted binary.
- Persistence, preservation of the original binary, DynamicUser operation, healthy checks, the 15-second timer and cancellation of trial rollback were verified.
- Required services, boot recovery and the periodic timer are enabled. Persistent units/drop-ins reside under `/etc/systemd/system`; dependencies start the adapter. systemd unit verification passed.

The configuration is intended to start automatically after Debian boots and re-register the phone when it returns to the same network. **A full host power-cycle/reboot test, clean installation and long-duration operation have not been performed for this profile.**
