pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.common

// Reusable dropdown for lists too long for SettingsSegments. Give it options
// (strings) and value, and handle chosen(value). It works in any settings page.
Rectangle {
    id: root
    property var options: []
    property string value: ""
    property string placeholder: "Sin definir"
    property bool searchable: false
    property string searchPlaceholder: "Buscar…"
    readonly property var filteredOptions: root.searchable ? root.options.filter(option => option.toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase())) : root.options
    onFilteredOptionsChanged: if (list) list.currentIndex = root.filteredOptions.length > 0 ? 0 : -1
    // Longer lists scroll inside this height.
    property real maxListHeight: Theme.scaled(260)
    signal chosen(string value)

    function chooseCurrent() {
        if (list.currentIndex < 0 || list.currentIndex >= root.filteredOptions.length) return;
        const value = root.filteredOptions[list.currentIndex];
        popup.close();
        root.chosen(value);
    }

    function moveSelection(step) {
        if (list.count === 0) return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + step));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    implicitWidth: Theme.scaled(220)
    implicitHeight: label.implicitHeight + 2 * Theme.spacing.sm
    color: area.containsMouse && root.enabled ? Theme.colors.surfaceVariant : Theme.colors.base
    border { width: 1; color: popup.visible ? Theme.colors.primary : Theme.colors.border }
    radius: Theme.rounding.normal
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: root.value || root.placeholder
    Keys.onSpacePressed: popup.open()
    Keys.onReturnPressed: popup.open()

    Text {
        id: label
        anchors { left: parent.left; right: chevron.left; verticalCenter: parent.verticalCenter; leftMargin: Theme.spacing.sm; rightMargin: Theme.spacing.xs }
        text: root.value || root.placeholder
        color: root.value ? Theme.colors.text : Theme.colors.overlay
        font: Theme.font.body
        elide: Text.ElideRight
    }
    Text {
        id: chevron
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Theme.spacing.sm }
        text: ""
        color: Theme.colors.overlay
        font.family: Theme.iconFamily
        font.pixelSize: Theme.scaled(10)
        rotation: popup.visible ? 180 : 0
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible ? popup.close() : popup.open()
    }

    // A real window, so the list can extend past the settings window.
    PopupWindow {
        id: popup
        function open() { popup.visible = true; }
        function close() { popup.visible = false; }
        anchor.item: root
        anchor.rect.y: root.height + Theme.spacing.xs
        anchor.rect.width: root.width
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        grabFocus: true
        color: "transparent"
        implicitWidth: root.width
        implicitHeight: Math.min(Math.max(list.contentHeight, list.count === 0 && root.searchable ? emptyLabel.implicitHeight + 2 * Theme.spacing.xs : 0), root.maxListHeight) + 2 * Theme.spacing.xs + 2 + (root.searchable ? search.height + Theme.spacing.xs : 0)
        onVisibleChanged: if (visible) {
            search.text = "";
            list.currentIndex = root.filteredOptions.length > 0 ? Math.max(0, root.filteredOptions.indexOf(root.value)) : -1;
            if (root.searchable) search.focusInput();
            else list.forceActiveFocus();
            if (list.currentIndex >= 0) list.positionViewAtIndex(list.currentIndex, ListView.Center);
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.colors.surface
            border { width: 1; color: Theme.colors.border }
            radius: Theme.rounding.normal
            SettingsField {
                id: search
                visible: root.searchable
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacing.xs + 1 }
                placeholder: root.searchPlaceholder
                onArrowPressed: step => root.moveSelection(step)
                onAccepted: {
                    root.chooseCurrent();
                    if (popup.visible) search.focusInput();
                }
                Keys.onEscapePressed: popup.close()
            }
            ListView {
                id: list
                anchors { fill: parent; margins: Theme.spacing.xs + 1 }
                anchors.topMargin: root.searchable ? search.height + 2 * Theme.spacing.xs + 1 : Theme.spacing.xs + 1
                clip: true
                model: root.filteredOptions
                boundsBehavior: Flickable.StopAtBounds
                Keys.onEscapePressed: popup.close()
                Keys.onReturnPressed: root.chooseCurrent()
                Keys.onEnterPressed: root.chooseCurrent()
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onDownPressed: root.moveSelection(1)
                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    id: scrollBar
                    policy: list.contentHeight > list.height ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
                    contentItem: Rectangle {
                        implicitWidth: Theme.spacing.xs
                        radius: Theme.rounding.full
                        color: Theme.colors.overlay
                    }
                }
                delegate: Rectangle {
                    id: option
                    required property string modelData
                    required property int index
                    readonly property bool current: modelData === root.value
                    width: ListView.view.width - (scrollBar.policy === Controls.ScrollBar.AlwaysOn ? scrollBar.width + Theme.spacing.xs : 0)
                    height: optionText.implicitHeight + 2 * Theme.spacing.xs
                    radius: Theme.rounding.small
                    color: current ? Theme.colors.primary : optionArea.containsMouse || (root.searchable && list.currentIndex === index) ? Theme.colors.surfaceVariant : "transparent"
                    Text {
                        id: optionText
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.spacing.sm }
                        text: option.modelData
                        color: option.current ? Theme.colors.base : Theme.colors.text
                        font: Theme.font.body
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.close();
                            root.chosen(option.modelData);
                        }
                    }
                }
            }
            Text {
                id: emptyLabel
                anchors.centerIn: list
                visible: root.searchable && list.count === 0
                text: "Sin coincidencias"
                color: Theme.colors.overlay
                font: Theme.font.caption
            }
        }
    }
}
