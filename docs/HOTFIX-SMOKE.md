# Combined hotfix smoke test

Use the exact-SHA development bundle identified in PR #77. Verify `SHA256SUMS`, read `DEV-BUILD.json`, and run its `bash install-dev.sh`. Keep the printed rollback snapshot path. The installed source and both binaries must match that receipt; do not delete it or use the public setup/repair path before release.

For a fresh-install test, use the matching CI release artifact's `install-candidate.sh` after backed-up removal. Check that Familiar appears immediately to the right of Agents in the native bar before enabling Windows. If Agents is not in the right section, Familiar should appear at that section's start. An update or repair must retain an existing custom placement. Windows moves the combined app strip into its taskbar layout; General/Mac must restore the fresh-install placement.

Tom’s acceptance of this exact build is pending. Record the source SHA, CI run/attempt and your result on PR #77 before authorizing merge or publication.

1. Open Familiar settings from its labelled taskbar button. In General/Mac, check access through your original Plugin Drawer placement.
2. Select Windows. Expect one full-width bottom bar, 48px at the default font scale, 32px app icons and no separate floating dock. Existing native widgets and pins remain.
3. Launch a disposable app, focus it from the taskbar and open its right-click menu. Select the window row before Minimise; restore it by clicking its taskbar icon. Check overflow arrows if needed.
4. Restart the Omarchy shell. Windows mode, settings access and pins must persist.
5. Select General, then repeat Windows → Mac. Both must restore the original bar arrangement and height. In Mac, hover over a running app to see its preview, click an app to focus it, and right-click for its menu. Repeat after a shell restart. Return to your preferred profile.
6. Optional rollback: run the same bundle’s `bash install-dev.sh --rollback <printed-snapshot-path>`. It restores the prior exact build and placement while retaining subsequent personal changes. Reinstall the candidate if you wish to accept it after rollback testing.

Installer failure diagnostics and publication ordering are covered by isolated automated tests. Do not disrupt a working development installation to manufacture an initial-install 404. After authorized publication, run the release URL verifier and test fresh setup/retry in a disposable account before announcing that #79 is resolved for users.
