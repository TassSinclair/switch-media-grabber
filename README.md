# Switch Media Grabber

A bash script that downloads screenshots and videos from a nearby Nintendo Switch via its "Send to Smart Device" wifi transfer feature.

## Requirements

- macOS (uses CoreWLAN for wifi management)
- [jq](https://jqlang.github.io/jq/) (`brew install jq`)
- Xcode Command Line Tools (for `swift`)

## Usage

1. On your Switch's home menu, navigate to `Album`. 
2. Select a screenshot or video, select `Posting and Editing`, and then `Send to Smart Device`.
   - If sharing a screenshots, `Send Individually` or `Send Multiple`.
3. On the "Send to Smart Device" screen, select `Trouble connecting?` and note down the password. Stay on this screen for now.

4. With the password from the previous step, run the following:
   ```bash
   ./grab.sh <wifi-password>
   ```
   The screenshots or video will be downloaded to the current directory.

## What it does

1. Scans for a wifi network matching `switch_*` (retries up to 10 times)
2. Connects using CoreWLAN
3. Fetches the file list from the Switch's HTTP server
4. Downloads all listed media files
5. Removes the Switch network and toggles wifi to auto-rejoin your previous network
