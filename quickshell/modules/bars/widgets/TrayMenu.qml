pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common

// Context menu of a tray item, drawn with the Senda theme instead of the
// native Qt menu. Submenus open in place, with a back entry on top.
PopupWindow {
    id: root

    required property var rootMenu
    property bool showUnpin: false
    property bool showPin: false

    signal unpinRequested()
    signal pinRequested()

    // Stack of opened submenu handles; the last one is shown.
    property var menuStack: []
    readonly property var currentMenu: menuStack.length > 0 ? menuStack[menuStack.length - 1] : rootMenu

    function open(window, x, y) {
        menuStack = [];
        anchor.window = window;
        anchor.rect.x = x;
        anchor.rect.y = y;
        visible = true;
    }

    // Time of the last close, so the press that dismissed the menu on its own
    // tray icon does not reopen it right away.
    property real closedAt: 0

    function close() {
        if (visible)
            closedAt = Date.now();
        grab.active = false;
        visible = false;
        menuStack = [];
    }

    function toggle(window, x, y) {
        if (visible || Date.now() - closedAt < 300) {
            close();
            return;
        }
        open(window, x, y);
    }

    color: "transparent"
    implicitWidth: Math.max(200, column.implicitWidth + 12)
    implicitHeight: column.implicitHeight + 12
    visible: false

    // The grab only takes once the surface is mapped, so it is activated a
    // moment after the popup shows. A click outside or Escape clears it.
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: root.close()
    }

    onVisibleChanged: {
        if (visible)
            grabTimer.restart();
    }

    Timer {
        id: grabTimer
        interval: 50
        onTriggered: grab.active = root.visible
    }

    QsMenuOpener {
        id: opener
        menu: root.currentMenu
    }

    Rectangle {
        id: menuBackground
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (root.menuStack.length > 0)
                root.menuStack = root.menuStack.slice(0, -1);
            else
                root.close();
        }
        radius: Theme.rounding.normal
        color: Theme.colors.background
        border.width: 1
        border.color: Theme.colors.border

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            // Back to the parent menu.
            MenuRow {
                visible: root.menuStack.length > 0
                label: "Atrás"
                leadingIcon: "󰁍"
                onActivated: root.menuStack = root.menuStack.slice(0, -1)
            }

            Repeater {
                id: appEntries
                model: opener.children

                delegate: Loader {
                    id: entryLoader
                    required property var modelData
                    Layout.fillWidth: true
                    sourceComponent: modelData.isSeparator ? separator : row

                    Component {
                        id: separator
                        Rectangle {
                            implicitHeight: 9
                            color: "transparent"
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                height: 1
                                color: Theme.colors.border
                            }
                        }
                    }

                    Component {
                        id: row
                        MenuRow {
                            entry: entryLoader.modelData
                            label: entryLoader.modelData.text
                            onActivated: {
                                const entry = entryLoader.modelData;
                                if (entry.hasChildren) {
                                    root.menuStack = root.menuStack.concat([entry]);
                                } else {
                                    entry.triggered();
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: (root.showUnpin || root.showPin) && root.menuStack.length === 0 && appEntries.count > 0
                Layout.fillWidth: true
                implicitHeight: 9
                color: "transparent"

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    height: 1
                    color: menuBackground.border.color
                }
            }

            MenuRow {
                visible: root.showPin && root.menuStack.length === 0
                label: "Anclar a la barra"
                leadingIcon: "󰐃"
                onActivated: {
                    root.close();
                    root.pinRequested();
                }
            }

            MenuRow {
                visible: root.showUnpin && root.menuStack.length === 0
                label: "Desanclar de la barra"
                leadingIcon: "󰐃"
                onActivated: {
                    root.close();
                    root.unpinRequested();
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: menuRow

        property var entry: null
        property string label: ""
        property string leadingIcon: ""
        readonly property bool enabledEntry: entry ? entry.enabled : true
        readonly property bool checkable: entry && entry.buttonType !== QsMenuButtonType.None
        readonly property bool checked: entry && entry.checkState === Qt.Checked

        signal activated

        Layout.fillWidth: true
        implicitWidth: rowLayout.implicitWidth + 20
        implicitHeight: 30
        radius: Theme.rounding.small
        color: mouse.containsMouse && enabledEntry ? Theme.colors.surfaceVariant : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            id: rowLayout
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
                visible: menuRow.checkable
                text: menuRow.entry && menuRow.entry.buttonType === QsMenuButtonType.RadioButton
                        ? (menuRow.checked ? "󰐾" : "󰄯")
                        : (menuRow.checked ? "󰄵" : "󰄱")
                color: menuRow.checked ? Theme.colors.primary : Theme.colors.overlay
                font: Theme.font.overlay
            }

            Text {
                visible: menuRow.leadingIcon !== ""
                text: menuRow.leadingIcon
                color: Theme.colors.overlay
                font: Theme.font.overlay
            }

            IconImage {
                asynchronous: true
                visible: !!menuRow.entry && menuRow.entry.icon !== ""
                source: menuRow.entry ? menuRow.entry.icon : ""
                implicitSize: 16
            }

            Text {
                Layout.fillWidth: true
                text: menuRow.label.replace(/_(?!_)/g, "")
                color: menuRow.enabledEntry ? Theme.colors.text : Theme.colors.overlay
                font: Theme.font.overlay
                elide: Text.ElideRight
            }

            Text {
                visible: !!menuRow.entry && menuRow.entry.hasChildren
                text: "󰅂"
                color: Theme.colors.overlay
                font: Theme.font.overlay
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: menuRow.enabledEntry
            cursorShape: Qt.PointingHandCursor
            onClicked: menuRow.activated()
        }
    }
}
