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
 function none() { return ({widths: {top: 0, bottom: 0, left: 0, right: 0}}) }
 function hyprlandActiveSpec(color, width) { return ({color: color, widths: {top: width, bottom: width, left: width, right: width}}) }
}
