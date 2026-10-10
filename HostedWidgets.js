// Attach eager/lazy widget panels to the clicked dock slot.
.pragma library

function attach(host, item, widgetId, anchorItem) {
    if (!item) return
    if (host.loadedWidgetItems.indexOf(item) === -1) host.loadedWidgetItems.push(item)
    if ("bar" in item) item.bar = host.barContext
    if ("shell" in item) item.shell = host.shell
    if ("widgetId" in item) item.widgetId = widgetId
    if ("moduleName" in item) item.moduleName = widgetId

    function applyToPanel(p) {
        if (!p) return
        if ("centerOnBar" in p) {
            p.centerOnBar = false
        }
        if ("bar" in p) {
            p.bar = host.barContext
        }
        if ("anchorItem" in p) {
            p.anchorItem = anchorItem || (host.dockWindow ? host.dockWindow.contentItem : null)
        }
        if ("opened" in p && p.openedChanged) {
            p.openedChanged.connect(function() {
                host.evaluateHoverState()
            })
        }
        if ("open" in p && p.openChanged) {
            p.openChanged.connect(function() {
                host.evaluateHoverState()
            })
        }
    }

    function scan(obj) {
        if (!obj) return
        applyToPanel(obj)
        if (obj.panel) {
            applyToPanel(obj.panel)
        }
        if (obj.data) {
            for (var i = 0; i < obj.data.length; i++) {
                var d = obj.data[i]
                if (d) {
                    applyToPanel(d)
                    if (d.panel) applyToPanel(d.panel)
                }
            }
        }
        if (obj.children) {
            for (var j = 0; j < obj.children.length; j++) {
                var c = obj.children[j]
                if (c) {
                    applyToPanel(c)
                    if (c.panel) applyToPanel(c.panel)
                }
            }
        }
    }

    scan(item)

    if (item) {
        if ("iconChanged" in item && item.iconChanged && typeof item.iconChanged.connect === "function") {
            item.iconChanged.connect(function() { host.widgetIconRevision++ })
        }
        if ("displayTextChanged" in item && item.displayTextChanged && typeof item.displayTextChanged.connect === "function") {
            item.displayTextChanged.connect(function() { host.widgetIconRevision++ })
        }
        if ("playIconChanged" in item && item.playIconChanged && typeof item.playIconChanged.connect === "function") {
            item.playIconChanged.connect(function() { host.widgetIconRevision++ })
        }
        if ("updateAvailableChanged" in item && item.updateAvailableChanged && typeof item.updateAvailableChanged.connect === "function") {
            item.updateAvailableChanged.connect(function() { host.widgetIconRevision++ })
        }
        if ("activeChanged" in item && item.activeChanged && typeof item.activeChanged.connect === "function") {
            item.activeChanged.connect(function() { host.widgetIconRevision++ })
        }
        if ("mutedChanged" in item && item.mutedChanged && typeof item.mutedChanged.connect === "function") {
            item.mutedChanged.connect(function() { host.widgetIconRevision++ })
        }
    }

    if (item.panelLoader) {
        var handlePanelLoader = function() {
            if (item.panelLoader && item.panelLoader.item) {
                scan(item.panelLoader.item)
            }
        }
        handlePanelLoader()
        item.panelLoader.loaded.connect(handlePanelLoader)
    }
}
