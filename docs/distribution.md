# Shipping a Mac release

## Downloads without an Apple Developer membership

Pawlet can be distributed as a built Mac app before joining the Apple Developer Program. Users download a DMG or ZIP from [GitHub Releases](https://github.com/ruzwid/pawlet/releases/latest), move Pawlet.app to Applications and open it. They do not need the source repository, Git, Xcode, npm, Python or Codex.

Current downloads use an ad-hoc signature, which verifies file integrity but does **not** establish an Apple Developer identity or notarization. Gatekeeper may block the first launch. Users who trust the download can try opening it once, then approve Pawlet in **System Settings → Privacy & Security → Open Anyway**. See [Apple's instructions](https://support.apple.com/en-us/102445). Managed Macs may prevent this exception. Do not describe these downloads as Apple-signed or notarized.

## Publish with GitHub Actions

The **Publish Mac download** workflow runs when a `v*` tag is pushed. It checks that the tag matches `CFBundleShortVersionString` in `Resources/Info.plist`, builds a universal app for Apple silicon and Intel, runs the app and pack tests, verifies the signature and architectures, and creates a GitHub Release. The release is published only after its DMG, ZIP and `SHA256SUMS.txt` have been uploaded. It becomes the latest download, with an explicit notice that it is not notarized. No Apple credentials or extra GitHub secrets are needed; the workflow uses GitHub's temporary repository token.

For each new version:

1. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Resources/Info.plist`.
2. Update `docs/release-notes.md` with the version's changes, keeping the installation and notarization notice accurate.
3. Commit and push the source and workflow changes to `main`.
4. Tag that commit and push the tag, using the matching version. For example, for app version `0.7.1`:

   ```sh
   git tag v0.7.1
   git push origin v0.7.1
   ```

You can also run **Publish Mac download** manually from the Actions tab with an existing version tag. It checks out that tag, not the selected branch. A failed upload can be retried while the release is still a draft; published versions are never overwritten. Fix a published release by making a new version and tag.

The **Build downloadable preview** workflow remains a manual way to build unpublished review artifacts. Workflow artifacts are intended for developers; the public installation link points to Releases.

## Package locally

Set up the build-only DMG tooling in an isolated Python 3.10+ environment, then package:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-release.txt
RELEASE_PYTHON=.venv/bin/python bash scripts/release.sh
```

The release script always builds both Mac architectures, runs the app's self-tests and creates a DMG, ZIP and SHA-256 checksums in `dist/`. Both downloads include installation instructions. The DMG opens a compact, text-free dotted canvas with Pawlet on the left, Applications on the right, five fading chevrons between them, and small Mochi and Paris details in the bottom corners. Only the two normal Finder icon labels are visible. The Read Me and artwork support files are hidden and placed beyond the canvas, including for users who show hidden files in Finder. The background includes 1x and 2x TIFF representations for Retina displays and reuses the MIT-licensed bundled minis.

`scripts/package-dmg.sh APP_PATH OUTPUT_DMG` packages an already-built Pawlet.app for quick installer-only iteration. It mounts the completed DMG read-only and verifies the stored app's signature and executable before reporting success. Mac CI also runs this packaging check. `Tools/make-dmg-background.swift` draws the original artwork; `Tools/dmg-settings.py` sets the native Finder layout. [dmgbuild](https://dmgbuild.readthedocs.io/) writes the background alias and `.DS_Store` without launching Finder, so the same layout is built in GitHub Actions. It is a build-time dependency only; the downloaded app and installer do not need Python or network access. Release products stay out of source commits.

To publish a locally tested build instead of using Actions, create a draft GitHub Release at its matching source tag, upload all three files from `dist/`, use `docs/release-notes.md` as the release notes, and publish once the assets are complete. Do not publish the same version through both paths.

## Add signing and notarization later

Joining the Apple Developer Program enables Developer ID signing and notarization, reducing first-launch friction. Apple's [Developer ID guide](https://developer.apple.com/developer-id/) and [notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) describe the prerequisites.

The build supports `SIGN_IDENTITY`; the release script supports `NOTARY_PROFILE`, referring to credentials already stored with `xcrun notarytool store-credentials`. It never creates or uploads credentials. Example, after the developer has configured their own certificate and Keychain profile:

```sh
SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='pawlet-release' \
RELEASE_PYTHON=.venv/bin/python bash scripts/release.sh
```

Notarization submits the built app ZIP to Apple and requires network access. The script waits for acceptance, staples the app, then builds the final ZIP and DMG from the stapled app. Failed notarization stops the release. No signing credentials are included in this repository. The GitHub workflow currently ships ad-hoc builds; signing credentials and the installation notices must be updated when adopting notarized releases.

Keep personal pet packs outside source commits. The bundled Mochi and Paris atlases use the repository's MIT license; generation sources and QA belong in separate creation workspaces. Community gallery submissions should name their artwork license and attribution. Add automatic updates only after the signed release channel and update verification are established.
