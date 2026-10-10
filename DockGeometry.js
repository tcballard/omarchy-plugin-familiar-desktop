.pragma library

function panelLayout(edge, offset, span) {
    var vertical = edge === "left" || edge === "right";
    var anchors = {}, margins = {};
    ["top", "bottom", "left", "right"].forEach(function(side) {
        anchors[side] = side === edge || (span && (vertical ? side === "top" || side === "bottom" : side === "left" || side === "right"));
        margins[side] = side === edge ? offset : 0;
    });
    return { vertical: vertical, anchors: anchors, margins: margins };
}

function popupLayout(options) {
    var offset = options.taskbar
        ? options.taskbarSize + (options.ignoreDockExclusion ? 0 : 4)
        : (options.overlay || options.ignoreDockExclusion ? options.slotSize + 8 + 2 * options.gap : options.gap);
    var layout = panelLayout(options.edge, offset, true);
    layout.offset = offset;
    layout.overlay = options.overlay;
    layout.ignoreExclusion = options.taskbar || options.overlay || options.ignoreDockExclusion;
    return layout;
}

function surfaceSize(vertical, slotSize, totalDimension) {
    var length = Math.max(slotSize + 4, totalDimension + 8);
    return { width: vertical ? slotSize + 4 : length, height: vertical ? length : slotSize + 4 };
}

function clampCard(center, cardSize, screenSize) {
    return Math.max(6, Math.min(screenSize - cardSize - 6, center - cardSize / 2));
}

function appMenuPosition(options) {
    var along = options.vertical ? options.height : options.width;
    var center = options.taskbarAnchor !== null ? options.taskbarAnchor : (along - options.dockLength) / 2 + options.itemOffset;
    return {
        x: options.vertical ? 0 : clampCard(center, options.cardWidth, options.width),
        y: options.vertical ? clampCard(center, options.cardHeight, options.height) : 0
    };
}
