# Shipping a Mac release

## Local preview

`bash scripts/release.sh` builds a universal `.app`, runs its self-tests and creates a DMG, ZIP and SHA-256 checksums. The DMG includes a link to Applications. This preview uses an ad-hoc signature, which verifies file integrity but does **not** establish an Apple Developer identity or notarization. A downloaded preview can be blocked by Gatekeeper; do not describe it as a notarized public release.

## Public downloads

Before a broad public release, choose your final bundle identifier, use an Apple Developer ID Application certificate, notarize the application and staple the ticket. Apple's [Developer ID guide](https://developer.apple.com/developer-id/) and [notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) describe the prerequisites.

The build supports `SIGN_IDENTITY`; the release script supports `NOTARY_PROFILE`, referring to credentials already stored with `xcrun notarytool store-credentials`. It never creates or uploads credentials. Example, after the developer has configured their own certificate and Keychain profile:

```sh
SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='pawlet-release' bash scripts/release.sh
```

Notarization submits the built app ZIP to Apple and requires network access. The script waits for acceptance, staples the app, then rebuilds the final ZIP and DMG from the stapled app. Failed notarization stops the release. No signing credentials are included in this repository.

## GitHub

Create an empty repository and push the source. The included workflow builds/tests pull requests on Apple silicon and Intel runners. A manual release workflow uploads preview artifacts for review; it does not create a public GitHub Release. After signing/notarization, create a versioned Release with the DMG, ZIP, checksums and release notes. Users should download binaries from Releases, not build output committed to the source tree.

Keep personal pet packs outside source commits. The bundled Mochi and Paris atlases are small enough for normal Git; generation sources and QA belong in separate creation workspaces. Community gallery submissions should name their artwork license and attribution. Add automatic updates only after the signed release channel and update verification are established.
