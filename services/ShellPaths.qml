pragma Singleton

import Quickshell
import QtQml

QtObject {
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")
    readonly property string appName: "lume-shell"
    readonly property string configDirectory: configHome + "/" + appName
    readonly property string cacheDirectory: cacheHome + "/" + appName
    readonly property string stateDirectory: stateHome + "/" + appName
    readonly property string dataDirectory: dataHome + "/" + appName
    readonly property string currentWallpaper: cacheHome + "/current_wallpaper"

    function configFile(relativePath) {
        return configDirectory + "/" + relativePath
    }

    function cacheFile(relativePath) {
        return cacheDirectory + "/" + relativePath
    }

    function stateFile(relativePath) {
        return stateDirectory + "/" + relativePath
    }

    function dataFile(relativePath) {
        return dataDirectory + "/" + relativePath
    }
}
