# macOS Signing and Notarization Setup

This project signs and notarizes macOS release binaries in GitHub Actions.

## 1) Get Apple prerequisites

1. Join the Apple Developer Program (paid).
2. Create a `Developer ID Application` certificate.
3. Create an app-specific password for notarization.
4. Note your Apple Team ID.

## 2) Create Developer ID Application certificate

1. Open Keychain Access on macOS.
2. Go to `Keychain Access -> Certificate Assistant -> Request a Certificate From a Certificate Authority...`.
3. Save the CSR file to disk.
4. In Apple Developer portal, create a `Developer ID Application` certificate using that CSR.
5. Download the certificate (`.cer`) and open it to install in Keychain.

## 3) Export certificate as `.p12`

1. In Keychain Access, open `My Certificates`.
2. Find `Developer ID Application: ...`.
3. Right-click -> `Export`.
4. Save as `.p12` and set an export password.

## 4) Create app-specific password

1. Go to https://appleid.apple.com/
2. Sign in and create an app-specific password.
3. Save it for GitHub Actions.

## 5) Add GitHub Actions secrets

Open: `https://github.com/bbondy/guardrails/settings/secrets/actions`

Add these repository secrets:

- `APPLE_CERT_P12`: base64-encoded `.p12` content
- `APPLE_CERT_PASSWORD`: password used when exporting `.p12`
- `APPLE_ID`: Apple ID email
- `APPLE_TEAM_ID`: Apple Developer Team ID
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password from appleid.apple.com

## 6) Base64 the `.p12` for `APPLE_CERT_P12`

On macOS:

```bash
base64 -i /path/to/developer_id_app.p12 | pbcopy
```

Paste clipboard contents into the `APPLE_CERT_P12` secret.

## Notes

- Do not commit certificate files, passwords, or tokens to git.
- If any secret is missing, tag-release signing/notarization will fail intentionally.
