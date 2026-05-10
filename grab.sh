#!/usr/bin/env bash
set -euo pipefail

SSID_PREFIX="switch_"
SERVER_BASE="http://192.168.0.1"
DATA_URL="${SERVER_BASE}/data.json"
WIFI_IFACE="en0"

cleanup() {
    echo "Disconnecting from Switch network..."
    networksetup -removepreferredwirelessnetwork "$WIFI_IFACE" "$TARGET_SSID" 2>/dev/null || true
    networksetup -setairportpower "$WIFI_IFACE" off 2>/dev/null
    networksetup -setairportpower "$WIFI_IFACE" on 2>/dev/null
    echo "Wifi toggled — macOS will auto-rejoin your preferred network."
}
trap cleanup EXIT

if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: this script only works on macOS." >&2
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <wifi-password>" >&2
    exit 1
fi

WIFI_PASSWORD="$1"

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required. Install with: brew install jq" >&2
    exit 1
fi

SCAN_ATTEMPTS=10
echo "Scanning for networks matching '${SSID_PREFIX}*' (up to $SCAN_ATTEMPTS attempts)..."
TARGET_SSID=$(SCAN_PREFIX="$SSID_PREFIX" SCAN_MAX="$SCAN_ATTEMPTS" SCAN_PASS="$WIFI_PASSWORD" swift -e '
import CoreWLAN
import Foundation
let prefix = ProcessInfo.processInfo.environment["SCAN_PREFIX"] ?? ""
let password = ProcessInfo.processInfo.environment["SCAN_PASS"] ?? ""
let maxAttempts = Int(ProcessInfo.processInfo.environment["SCAN_MAX"] ?? "10") ?? 10
let client = CWWiFiClient.shared()
guard let iface = client.interface() else {
    fputs("Error: no wifi interface found\n", stderr); exit(1)
}
for attempt in 1...maxAttempts {
    fputs("  Scan \(attempt)/\(maxAttempts)...\n", stderr)
    if let networks = try? iface.scanForNetworks(withName: nil) {
        for n in networks {
            if let ssid = n.ssid, ssid.hasPrefix(prefix) {
                fputs("  Found: \(ssid)\n", stderr)
                fputs("  Connecting...\n", stderr)
                do {
                    try iface.associate(to: n, password: password)
                    print(ssid)
                    exit(0)
                } catch {
                    fputs("  Failed to connect: \(error.localizedDescription)\n", stderr)
                    exit(1)
                }
            }
        }
    }
    if attempt < maxAttempts { Thread.sleep(forTimeInterval: 10) }
}
exit(1)
')
if [[ -z "$TARGET_SSID" ]]; then
    echo "Error: no network found matching '${SSID_PREFIX}*' after $SCAN_ATTEMPTS scans." >&2
    exit 1
fi
echo "Connected to $TARGET_SSID"

echo "Waiting for server..."
TRIES=0
until curl --silent --head --max-time 3 "$DATA_URL" >/dev/null 2>&1; do
    TRIES=$((TRIES + 1))
    if [[ $TRIES -ge 10 ]]; then
        echo "Error: could not reach $DATA_URL after 30s." >&2
        exit 1
    fi
    sleep 3
done

echo "Fetching file list..."
DATA_JSON=$(curl -sf "$DATA_URL")

FILES=$(echo "$DATA_JSON" | jq -r '.FileNames[]')
TOTAL=$(echo "$DATA_JSON" | jq '.FileNames | length')

COUNT=0
echo "Found $TOTAL file(s) to download."

for file in $FILES; do
    echo "Downloading $file..."
    curl -sf -O "${SERVER_BASE}/img/$file" && COUNT=$((COUNT + 1)) || echo "  Failed: $file"
done

echo "Done. Downloaded $COUNT/$TOTAL file(s) to $(pwd)."
