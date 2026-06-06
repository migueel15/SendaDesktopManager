pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property string currentTheme: "mocha"

    readonly property Colors colors: Colors {}
    readonly property Rounding rounding: Rounding {}
    readonly property FontSize fontSize: FontSize {}
    readonly property Fonts font: Fonts {}
    readonly property Workspaces workspaces: Workspaces {}
    readonly property Notifications notifications: Notifications {}

    component Colors: QtObject {
        readonly property color background: "#11111B"
        readonly property color surface: "#1e1e2e"
        readonly property color surfaceVariant: "#313244"
        readonly property color overlay: "#7f849c"
        readonly property color white: "#ffffff"
        readonly property color primary: "#89b4fa"
        readonly property color secondary: "#cba6f7"
        readonly property color accent: "#fab387"
        readonly property color success: "#a6e3a1"
        readonly property color warning: "#f9e2af"
        readonly property color error: "#f38ba8"
        readonly property color info: "#89b4fa"
        readonly property color text: "#cdd6f4"
    }

    component Rounding: QtObject {
        readonly property int small: 6
        readonly property int normal: 10
        readonly property int large: 20
        readonly property int full: 1000
    }

    component FontSize: QtObject {
        readonly property int small: 12
        readonly property int normal: 14
        readonly property int large: 16
        readonly property int xLarge: 18
        readonly property int giant: 19
    }

    component Fonts: QtObject {
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
    property int barBorderRadius: Theme.rounding.normal

    component Workspaces: QtObject {
        property string icon: ""
        property font font: Theme.font.icon
        property int spacing: 8
        property color activeWorkspaceColor: root.colors.white
        property color notFocusedWorkspaceColor: root.colors.primary
        property color emptyWorkspaceColor: root.colors.overlay
    }

    component Notifications: QtObject {
        property QtObject icon: QtObject {
            property string notification: "󱅫"
            property string none: "󰂚"
            property string dnd_none: "󰂛"
            property string dnd_notification: ""
        }
    }
}
