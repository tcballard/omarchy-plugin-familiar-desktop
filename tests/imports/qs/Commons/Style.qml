pragma Singleton
import QtQuick
QtObject {
 property var font: ({family: "DejaVu Sans", caption: 11, body: 12})
 property var spacing: ({controlHeight: 36, popupRowHeight: 36, dropdownWidth: 180, huge: 24, labelGap: 4, controlPaddingX: 10, md: 8, controlGap: 8, hairline: 1})
 property int normalBorderWidth: 1
 function controlFill(f,h,a,b) { return "#f6f7f9" }
 function hoverStateColor(a,b) { return a }
 property int cornerRadius: 12
 function space(v) { return v }
 function hoverFillFor(a,b) { return "#e5e7eb" }
}
