pragma Singleton

import QtQuick

QtObject {
    id: theme

    property string currentTheme: "mocha"

    property QtObject colors: QtObject {
        // property color background: "#1e1e2e"        // base
        // property color surface: "#181825"           // mantle
        //
        property color background: "#11111B"           // mantle
        property color surface: "#1e1e2e"        // base
        property color surfaceVariant: "#313244"    // surface0
        property color overlay: "#7f849c"    // surface0
        property color white: "#ffffff"           // yellow
        property color primary: "#89b4fa"           // blue
        property color secondary: "#cba6f7"         // mauve
        property color accent: "#fab387"            // peach
        property color success: "#a6e3a1"           // green
        property color warning: "#f9e2af"           // yellow
        property color error: "#f38ba8"             // red
        property color info: "#89b4fa"              // blue
        property color text: "#cdd6f4"
    }

    property QtObject font: QtObject {
        property font base: Qt.font({
            family: "CaskaydiaMono Nerd Font Propo",
            pixelSize: 19,
            weight: Font.Normal
        })
        property font title: Qt.font({
            family: "CaskaydiaMono Nerd Font Propo",
            pixelSize: 17,
            weight: Font.Bold
        })
        property font overlay: Qt.font({
            family: "CaskaydiaMono Nerd Font Propo",
            pixelSize: 13,
            weight: Font.Normal
        })
        property font icon: Qt.font({
            family: "CaskaydiaMono Nerd Font Propo",
            pixelSize: 13,
            weight: Font.Normal
        })
    }

    property int barSize: 40
    property int barBorderRadius: 10

    property QtObject workspaces: QtObject {
        property string icon: ""
        property font font: Theme.font.icon
        property int spacing: 8
        property string activeWorkspaceColor: Theme.colors.white
        property string notFocusedWorkspaceColor: Theme.colors.primary
        property string emptyWorkspaceColor: Theme.colors.overlay
    }

    property QtObject notifications: QtObject {
        property QtObject icon: QtObject {
            property string notification: "󱅫"
            property string none: "󰂚"
            property string dnd_none: "󰂛"
            property string dnd_notification: ""
        }
        property font font: Theme.font.icon
        property int spacing: 8
        property string activeWorkspaceColor: Theme.colors.white
        property string notFocusedWorkspaceColor: Theme.colors.primary
        property string emptyWorkspaceColor: Theme.colors.overlay
    }
}
