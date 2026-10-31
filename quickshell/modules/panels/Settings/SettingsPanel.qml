pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Settings content with a sidebar of sections. Configuration goes through the
// senda CLI; tray pins use TrayPins. SettingsWindow hosts it; it opens with
// `senda settings` or from the dashboard.
Item {
    id: root

    // Sidebar entries, shared with the launcher. Each one needs a page in the
    // StackLayout below, in the same position.
    readonly property var sections: SendaSettings.sections
    property int currentSection: 0

    // The panel lives in SettingsWindow, so its own visible flag never changes:
    // reload the CLI state each time the window opens.
    Connections {
        target: SendaSettings
        function onWindowOpenChanged() {
            if (!SendaSettings.windowOpen) return;
            SendaSettings.refresh();
            SendaSttSettings.refresh();
            SendaHyprlandSettings.refresh();
            SendaDisplaySettings.refresh();
            SendaInputSettings.refresh();
            SendaStartupSettings.refresh();
        }
    }

    // The launcher asks for a section through SendaSettings.openSection.
    function applyRequestedSection() {
        const index = root.sections.findIndex(section => section.label === SendaSettings.requestedSection);
        if (index !== -1) root.currentSection = index;
        SendaSettings.requestedSection = "";
    }
    Component.onCompleted: applyRequestedSection()

    // The update notice in the bar opens this panel on the update section.
    Connections {
        target: SendaUpdate

        function onOpenRequested() {
            root.currentSection = root.sections.findIndex(section => section.label === "Actualización");
        }
    }

    Connections {
        target: SendaSettings
        function onRequestedSectionChanged() { if (SendaSettings.requestedSection) root.applyRequestedSection(); }
        function onNoticeChanged() { feedback.show(SendaSettings.notice, SendaSettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(SendaSettings.notice, SendaSettings.noticeIsError); }
    }
    Connections {
        target: SendaSttSettings
        function onNoticeChanged() { feedback.show(SendaSttSettings.notice, SendaSttSettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(SendaSttSettings.notice, SendaSttSettings.noticeIsError); }
    }

    Connections {
        target: SendaHyprlandSettings
        function onNoticeChanged() { feedback.show(SendaHyprlandSettings.notice, SendaHyprlandSettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(SendaHyprlandSettings.notice, SendaHyprlandSettings.noticeIsError); }
    }

    Connections {
        target: SendaDisplaySettings
        function onNoticeChanged() { feedback.show(SendaDisplaySettings.notice, SendaDisplaySettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(SendaDisplaySettings.notice, SendaDisplaySettings.noticeIsError); }
    }

    Connections {
        target: SendaStartupSettings
        function onNoticeChanged() { feedback.show(SendaStartupSettings.notice, SendaStartupSettings.noticeIsError); }
    }

    // Same card style as the dashboard and the control center.
    component SettingsCard: Rectangle {
        radius: Theme.rounding.normal
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.border
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: searchField.focusInput()
    }

    // Search works on the rows the pages really have, so no list needs upkeep.
    property string query: ""
    // Result chosen with the arrow keys; Enter opens it.
    property int resultIndex: 0
    readonly property bool searching: query.trim() !== ""
    function normalized(text) {
        return String(text).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
    }
    function collectRows(item, found) {
        for (const child of Array.from(item.children ?? []).concat(Array.from(item.contentItem?.children ?? []))) {
            if (child.searchable === true && child.label) found.push(child);
            root.collectRows(child, found);
        }
        return found;
    }
    readonly property var results: {
        const words = root.normalized(root.query).trim();
        if (!words) return [];
        const found = [];
        root.sections.forEach((section, index) => {
            if (root.normalized(section.label).includes(words))
                found.push({ title: section.label, section: section.label, index: index, row: null });
            const page = pages.children[index];
            if (!page) return;
            const seen = new Set();
            for (const row of root.collectRows(page, [])) {
                if (seen.has(row.label)) continue;
                if (root.normalized(row.label + " " + row.description).includes(words)) {
                    seen.add(row.label);
                    found.push({ title: row.label, section: section.label, index: index, row: row });
                }
            }
        });
        return found;
    }
    function openResult(result) {
        if (!result) return;
        root.currentSection = result.index;
        searchField.text = "";
        if (result.row) Qt.callLater(result.row.reveal);
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacing.md

        SettingsCard {
            // Reserve room for the longest label at the active text scale.
            Layout.preferredWidth: Math.max(root.width * 0.24, Theme.scaled(145))
            Layout.minimumWidth: Math.max(root.width * 0.24, Theme.scaled(145))
            Layout.maximumWidth: Math.max(root.width * 0.24, Theme.scaled(145))
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing.md
                spacing: 4

                Text {
                    Layout.bottomMargin: 10
                    text: "Ajustes"
                    color: Theme.colors.text
                    font.family: Theme.font.title.family
                    font.pixelSize: Theme.scaled(18)
                    font.weight: Font.Bold
                }

                SettingsField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.spacing.sm
                    placeholder: "Buscar ajustes"
                    onTextChanged: {
                        root.query = text;
                        root.resultIndex = 0;
                    }
                    onAccepted: root.openResult(root.results[root.resultIndex])
                    onArrowPressed: step => {
                        if (root.results.length > 0)
                            root.resultIndex = Math.max(0, Math.min(root.resultIndex + step, root.results.length - 1));
                    }
                }

                // While searching, results take the place of the sections.
                Text {
                    Layout.fillWidth: true
                    visible: root.searching && root.results.length === 0
                    text: "Sin resultados"
                    color: Theme.colors.overlay
                    font: Theme.font.body
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.searching
                    currentIndex: root.resultIndex
                    highlightMoveDuration: 0
                    clip: true
                    spacing: Theme.spacing.xs
                    model: root.results
                    delegate: Rectangle {
                        id: resultEntry
                        required property var modelData
                        required property int index
                        readonly property bool current: root.resultIndex === index
                        width: ListView.view.width
                        height: resultColumn.implicitHeight + 2 * Theme.spacing.sm
                        radius: Theme.rounding.small
                        color: current ? Theme.colors.selection : resultArea.containsMouse ? Theme.colors.surfaceVariant : "transparent"
                        ColumnLayout {
                            id: resultColumn
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.spacing.sm }
                            spacing: Theme.spacing.xxs
                            Text {
                                Layout.fillWidth: true
                                text: resultEntry.modelData.title
                                color: Theme.colors.text
                                font: Theme.font.body
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                text: resultEntry.modelData.section
                                color: Theme.colors.overlay
                                font: Theme.font.caption
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: resultArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openResult(resultEntry.modelData)
                        }
                    }
                }

                Repeater {
                    model: root.sections

                    delegate: Rectangle {
                        id: sectionEntry
                        required property var modelData
                        required property int index

                        readonly property bool selected: root.currentSection === index
                        visible: !root.searching

                        Layout.fillWidth: true
                        implicitHeight: Theme.scaled(24) + Theme.spacing.md
                        radius: Theme.rounding.small
                        color: selected ? Theme.colors.selection
                            : sectionMouse.containsMouse ? Theme.colors.surfaceVariant : Theme.colors.surface

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            text: sectionEntry.modelData.icon
                            font: Theme.font.icon
                            color: parent.selected ? Theme.colors.primary : Theme.colors.overlay
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacing.xl + Theme.spacing.md
                            text: sectionEntry.modelData.label
                            color: parent.selected ? Theme.colors.white : Theme.colors.text
                            font.family: Theme.font.base.family
                            font.pixelSize: Theme.scaled(13)
                            font.weight: parent.selected ? Font.Bold : Font.Normal
                        }

                        MouseArea {
                            id: sectionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentSection = sectionEntry.index
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    visible: !root.searching
                }

                SettingsButton {
                    Layout.fillWidth: true
                    label: "Cerrar"
                    onClicked: SendaSettings.closeWindow()
                }
            }
        }

        SettingsCard {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing.lg
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    text: root.sections[root.currentSection]?.label ?? ""
                    color: Theme.colors.primary
                    font.family: Theme.font.title.family
                    font.pixelSize: Theme.scaled(16)
                    font.weight: Font.Bold
                }

                StackLayout {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentSection

                    AppearanceSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    BarSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    WidgetsSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    CalendarSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    WeatherSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    SttSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onOpenSystemRequested: root.currentSection = root.sections.findIndex(section => section.label === "Sistema")
                    }

                    DisplaySettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    InputSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    StartupSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    PowerSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    SystemSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    UpdateSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
                SettingsStatus {
                    id: feedback
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.scaled(30)
                }
            }
        }
    }
}
