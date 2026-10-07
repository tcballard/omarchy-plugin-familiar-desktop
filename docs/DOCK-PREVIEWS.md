# Window previews and dock widget placement

Hover over a running app for 350 ms to see its windows. Move into the popup to select a window; leaving both the icon and popup dismisses it after 220 ms. Apps with more than three windows have Previous/Next controls. Clicking a preview activates that exact window through Familiar's existing activation helper when a Hyprland address is available.

Window previews start enabled. Turn them off in **Dock → Extras → Window previews on hover**. The preference survives changing layouts and restarting the shell.

Previews use Quickshell's `ScreencopyView` and Hyprland's toplevel export protocol. Only the currently displayed page captures, with at most three streams. Dismissal, drag/edit mode, disabling the dock or closing its last window tears the preview down. No thumbnails are saved. Unsupported capture, stopped streams and minimised windows show an icon and title instead. A live compositor may not supply frames for every inactive-workspace window.

Hosted widgets now anchor their panels to the clicked dock slot rather than the centre of the bar. The transparent dock window spans its screen along the dock edge to match Omarchy's panel coordinate system; its input region remains confined to the visible dock card. Panels open above bottom docks, below top docks, or inward from side docks, with the host's screen-edge clamping.

## XPS acceptance

Portable tests cover hover timing, popup handoff, capture teardown, pagination, exact window selection, and eager/lazy widget anchors. They use Quickshell test doubles; live screen capture and layer-shell placement are not claimed as tested.

- Hover one-window and multi-window apps; click each preview, including a window on another workspace.
- Minimise a window, open its preview and restore it; close windows while the popup is open.
- Cross icons quickly, move into the popup, drag icons, open a context menu and turn previews off. Check that no popup remains and autohide still works.
- Open Agents and other hosted widgets at both ends of bottom, left and right docks; confirm alignment with the clicked icon and screen-edge clamping.
- On each monitor, verify popup placement at normal scaling and that the transparent area beside the dock passes clicks through. Repeat after unplugging a monitor and changing dock position.

This is development work for a later release; no release version or binary pins change.
