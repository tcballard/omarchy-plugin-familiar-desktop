.pragma library

function validWidgetId(value) {
    return typeof value === "string"
        && /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/.test(value)
        && value !== "io.github.tcballard.familiar-desktop";
}

function normalizeDockWidgets(values) {
    if (!Array.isArray(values)) return ["omarchy.apps"];
    var result = [];
    for (var i = 0; i < values.length; i++) {
        if (validWidgetId(values[i])) result = addWidgetToDockList(result, values[i]);
    }
    return result;
}

function addWidgetToDockList(dockWidgetsList, widgetId) {
    var arr = Array.isArray(dockWidgetsList) ? dockWidgetsList.slice() : [];
    if (!validWidgetId(widgetId)) return arr;

    // Remove duplicates of the same widgetId
    for (var i = arr.length - 1; i >= 0; i--) {
        if (arr[i] === widgetId) arr.splice(i, 1);
    }

    if (widgetId === "omarchy.apps") {
        // Add omarchy.apps at the front, keep other non-apps widgets (max 1)
        var others = arr.filter(function(id) { return id && id !== "omarchy.apps"; });
        return ["omarchy.apps"].concat(others.slice(0, 1));
    } else {
        // Add non-apps widget; preserve omarchy.apps if present, cap others at 1
        var hasApps = arr.indexOf("omarchy.apps") !== -1;
        var result = hasApps ? ["omarchy.apps", widgetId] : [widgetId];
        return result;
    }
}

function removeWidgetFromDockList(dockWidgetsList, widgetId) {
    var arr = Array.isArray(dockWidgetsList) ? dockWidgetsList.slice() : [];
    var res = [];
    for (var i = 0; i < arr.length; i++) {
        if (arr[i] !== widgetId) {
            res.push(arr[i]);
        }
    }
    return res;
}

function getDockWidgetLayout(showAppMenu, appMenuPosition, widgetsEnabled, dockWidgetsList, widgetPosition) {
    var leftWidgets = [];
    var rightWidgets = [];
    var appPos = (appMenuPosition === "right") ? "right" : "left";
    var otherPos = (widgetPosition === "left") ? "left" : "right";

    if (!widgetsEnabled) {
        return {
            leftWidgets: [],
            rightWidgets: []
        };
    }

    var hasApps = (showAppMenu === true) && Array.isArray(dockWidgetsList) && (dockWidgetsList.indexOf("omarchy.apps") !== -1);

    // Left side:
    if (hasApps && appPos === "left") {
        leftWidgets.push("omarchy.apps");
    }
    if (otherPos === "left") {
        var listL = Array.isArray(dockWidgetsList) ? dockWidgetsList : [];
        for (var i = 0; i < listL.length; i++) {
            if (listL[i] && listL[i] !== "omarchy.apps") {
                leftWidgets.push(listL[i]);
            }
        }
    }

    // Right side:
    if (otherPos === "right") {
        var listR = Array.isArray(dockWidgetsList) ? dockWidgetsList : [];
        for (var j = 0; j < listR.length; j++) {
            if (listR[j] && listR[j] !== "omarchy.apps") {
                rightWidgets.push(listR[j]);
            }
        }
    }
    if (hasApps && appPos === "right") {
        rightWidgets.push("omarchy.apps");
    }

    return {
        leftWidgets: leftWidgets,
        rightWidgets: rightWidgets
    };
}
