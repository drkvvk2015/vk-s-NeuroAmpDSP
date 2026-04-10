# NeuroAmp DSP Release & Play Store Deployment Guide

This guide explains how to set up and execute the production release pipeline for NeuroAmp DSP on Google Play Store.

## Prerequisites

- Google Play Developer account (USD $25 registration fee)
- GitHub repository (this one assumed)
- Java keytool (included in JDK)
- Android SDK

## Step 1: Generate Release Keystore

```bash
keytool -genkey -v -keystore ~/keystore/neuroamp-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias neuroamp -storepass yourStorePassword -keypass yourKeyPassword
```

**Important:** Keep `~/keystore/neuroamp-release.jks` secure and backed up. Store passwords must match the GitHub secrets.

## Step 2: Set GitHub Secrets

Go to **Settings > Secrets and variables > Actions** in your GitHub repository and add:

1. **NEUROAMP_KEYSTORE_BASE64**: Base64-encoded keystore file
   ```bash
   cat ~/keystore/neuroamp-release.jks | base64 > keystore.b64
   # Copy contents of keystore.b64 to the secret
   ```

2. **NEUROAMP_KEY_ALIAS**: `neuroamp` (or your chosen alias)

3. **NEUROAMP_KEY_PASSWORD**: The key password from step 1

4. **NEUROAMP_KEYSTORE_PASSWORD**: The keystore password from step 1

5. **PLAYSTORE_SERVICE_ACCOUNT_JSON**: Google Play service account JSON (see Step 3)

6. **TELEMETRY_KEY**: Your telemetry provider key (Crashlytics/App Insights ID)

## Step 3: Create Google Play Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable **Google Play Developer API**
4. Create Service Account:
   - **Service accounts** > **Create Service Account**
   - Name: `neuroamp-ci`
   - Grant role: `Editor` (or use role with Play Developer API access)
5. Create JSON key:
   - Click the service account
   - **Keys** > **Add Key** > **Create new key** > JSON
   - Save the JSON file
6. In Google Play Console:
   - **Settings** > **API access**
   - Grant the service account access with appropriate roles
7. Copy entire JSON content to `PLAYSTORE_SERVICE_ACCOUNT_JSON` secret

## Step 4: Test Local Build

```bash
cd app

# Create local key.properties
cat > android/key.properties << EOF
storeFile=../keystore/neuroamp-release.jks
storePassword=yourStorePassword
keyAlias=neuroamp
keyPassword=yourKeyPassword
EOF

# Build AAB
flutter build appbundle --release --dart-define=APP_FLAVOR=prod

# Produced file: build/app/outputs/bundle/release/app-release.aab
```

## Step 5: Trigger Release

Push a tag matching the pattern `release/v*`:

```bash
git tag release/v1.0.0
git push origin release/v1.0.0
```

The GitHub Actions workflow will automatically:
1. Build the AAB with signing
2. Upload to Google Play internal testing track (draft)
3. Create a GitHub release note

## Step 6: Review and Release in Play Store

1. Go to [Google Play Console](https://play.google.com/console/) > Your App > **Internal Testing**
2. Review the uploaded AAB
3. Create release notes
4. Move to **Production** track when ready
5. Submit for review

## Troubleshooting

### Keystore Password Mismatch
Ensure `storePassword` and `keyPassword` in GitHub secrets match exactly.

### Play Store API Errors
- Verify service account has **Play Developer API** access
- Check app bundle version code is higher than previous release
- Ensure bundle is signed correctly: `jarsigner -verify -verbose build/app/outputs/bundle/release/app-release.aab`

### Base64 Encoding Issues
On Windows:
```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$env:USERPROFILE\keystore\neuroamp-release.jks")) | Set-Clipboard
```

On macOS/Linux:
```bash
base64 < ~/keystore/neuroamp-release.jks | tr -d '\n' | pbcopy
```

## Version Management

Update version in `app/pubspec.yaml`:
- `version: X.Y.Z+BUILD_NUMBER`

The `BUILD_NUMBER` should increment with each release.

### Version Bump + Tag Commands

PowerShell example (manual):

```powershell
Set-Location "e:/NeuAMP/vk-s-NeuroAmpDSP"

# Example: bump to 1.0.1+2
(Get-Content "app/pubspec.yaml") -replace '^version:\s*.*$', 'version: 1.0.1+2' | Set-Content "app/pubspec.yaml"

git add app/pubspec.yaml
git commit -m "chore(release): bump version to 1.0.1+2"
git tag release/v1.0.1
git push origin main
git push origin release/v1.0.1
```

Scripted option:

```powershell
Set-Location "e:/NeuAMP/vk-s-NeuroAmpDSP"
./app/tool/bump_and_tag.ps1 -Version 1.0.1 -BuildNumber 2 -Push
```

## Monitoring

After release:
- Monitor Play Store console for crash reports
- Check telemetry provider (Crashlytics/App Insights) for error trends
- Monitor ANR (Application Not Responding) rates

## Security Best Practices

1. **Rotate keystore passwords** periodically
2. **Regenerate service account keys** every 6-12 months
3. **Keep GitHub secrets secure** — never commit them
4. **Use GitHub branch protection** for release tags
5. **Enable two-factor authentication** on both GitHub and Google Play accounts
6. **Audit GitHub Actions runs** regularly
