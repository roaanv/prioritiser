# Releasing Prioritiser

Distribution is a signed + notarized, universal (arm64 + x86_64) macOS app,
published as both a `.dmg` and a `.zip` to this repo's GitHub Releases **and** to
the shared [`roaanv/releases`](https://github.com/roaanv/releases) repo.

The pipeline is driven by [`.github/workflows/release.yml`](.github/workflows/release.yml),
which calls the `make` release targets in order:

```
release → sign → notarize-app → dmg → notarize-dmg → archive → publish
```

## One-time setup

### 1. Prerequisites (from your Apple Developer account)

- A **Developer ID Application** certificate exported as a `.p12` (with a password).
- An **App Store Connect API key** (`.p8`) used for notarization, plus its **Key ID**
  and **Issuer ID** (App Store Connect → Users and Access → Integrations → Keys).
- A **GitHub personal access token** with `contents: write` on `roaanv/releases`
  (fine-grained or classic), for cross-repo publishing.

### 2. Repository secrets

The workflow reads six secrets. Add them to the GitHub repo (Settings → Secrets and
variables → Actions), or use the helper below.

| Secret | Value |
|--------|-------|
| `DEVELOPER_ID_CERTIFICATE_P12` | base64 of the `.p12` (`base64 -i cert.p12`) |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | the `.p12` password |
| `APPSTORE_API_KEY_P8_BASE64` | base64 of the `.p8` (`base64 -i AuthKey_XXX.p8`) |
| `APPSTORE_API_KEY_ID` | the App Store Connect Key ID |
| `APPSTORE_API_ISSUER_ID` | the App Store Connect Issuer ID |
| `RELEASE_REPO_TOKEN` | PAT with `contents: write` on `roaanv/releases` |

#### Helper: push secrets from your Keychain

Store each value once in the macOS Keychain under the service name `GH-<SECRET_NAME>`,
then push them all to the repo with `make gh-secrets`:

```sh
# Example: certificate + its password
security add-generic-password -s GH-DEVELOPER_ID_CERTIFICATE_P12 -a "$USER" -w "$(base64 -i cert.p12)"
security add-generic-password -s GH-DEVELOPER_ID_CERTIFICATE_PASSWORD -a "$USER" -w 'the-p12-password'
# …repeat for APPSTORE_API_KEY_P8_BASE64, APPSTORE_API_KEY_ID,
#    APPSTORE_API_ISSUER_ID, RELEASE_REPO_TOKEN…

make gh-secrets          # reads GH-* from Keychain, sets them on the GitHub repo
```

`make gh-secrets` requires the `gh` CLI, authenticated (`gh auth login`), and the
repo to already exist on GitHub.

## Cutting a release

1. Bump `MARKETING_VERSION` in [`project.yml`](project.yml) (e.g. `0.1.0` → `0.2.0`).
2. Commit on `main`.
3. Tag and push:

   ```sh
   git tag v0.2.0
   git push origin main --tags
   ```

The `v*` tag triggers the workflow: it runs the test suite, then builds, signs,
notarizes, packages, and publishes:

- `Prioritiser-v0.2.0-universal.dmg`
- `Prioritiser-v0.2.0-universal.zip`

to this repo's Releases and to `roaanv/releases` (tagged `prioritiser-v0.2.0`).

## Verifying / running locally

The same targets run locally if you have a Developer ID identity and API key on hand:

```sh
make release
make sign SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
make notarize-app API_KEY_PATH=AuthKey_XXX.p8 API_KEY_ID=XXXX API_ISSUER_ID=yyyy
make dmg TAG=v0.2.0
make archive TAG=v0.2.0
```

To confirm a downloaded build is correctly signed and notarized:

```sh
spctl --assess --type execute -vv /Applications/Prioritiser.app   # → accepted, source=Notarized Developer ID
codesign --verify --deep --strict --verbose=2 /Applications/Prioritiser.app
```
