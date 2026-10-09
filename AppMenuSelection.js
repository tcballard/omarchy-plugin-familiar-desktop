.pragma library

// Keep a user's selection by identity across refreshes and reordering. A new
// app, closed window, or late Hyprland mapping needs a usable default instead.
function selectedIndex(addresses, preferredAddress, activeIndex) {
    if (preferredAddress) {
        for (var i = 0; i < addresses.length; i++) {
            if (addresses[i] === preferredAddress) return i;
        }
    }
    if (!addresses.length) return -1;
    return typeof activeIndex === "number" && activeIndex >= 0 && activeIndex < addresses.length
        ? activeIndex : 0;
}
