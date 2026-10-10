pragma Singleton
import QtQuick
QtObject {
    property var commands: []
    function alpha(color, value) { return Qt.rgba(color.r, color.g, color.b, value) }
    function execArgv(argv) { commands = commands.concat([argv]) }
    function execDetached(command) { commands = commands.concat([command]) }
}
