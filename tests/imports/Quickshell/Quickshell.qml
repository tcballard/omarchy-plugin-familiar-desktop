pragma Singleton
import QtQml
QtObject {
    property var detachedCommands: []
    function iconPath(name, fallback) { return "" }
    function env(name) { return name === "HOME" ? "/fictional-home" : "" }
    function execDetached(argv) { detachedCommands = detachedCommands.concat([argv]) }
}
