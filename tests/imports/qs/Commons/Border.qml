pragma Singleton
import QtQuick
QtObject {
 function localOrSurfaceSpec() { return ({}) }
 function controlSpec() { return ({}) }
 function left() { return 1 }
 function right() { return 1 }
 function top() { return 1 }
 function bottom() { return 1 }
 function canUseNative() { return false }
 function needsOverlay() { return false }
 function uniformWidth() { return 1 }
 function color() { return "#cbd0d7" }
}
