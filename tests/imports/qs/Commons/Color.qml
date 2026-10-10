pragma Singleton
import QtQuick
QtObject {
 property QtObject popups: QtObject {
  property color background: "#f6f7f9"
  property color text: "#202833"
  property color border: "#cbd0d7"
 }
 property QtObject bar: QtObject {
  property color background: "#f6f7f9"
  property color text: "#202833"
 }
 property color accent: "#006abe"
 property color background: "#ffffff"
 property color text: "#202833"
 property color foreground: "#202833"
 property color muted: "#687281"
 property color border: "#cbd0d7"
 function composed(a,b,c,d) { return "#e5e7eb" }
}
