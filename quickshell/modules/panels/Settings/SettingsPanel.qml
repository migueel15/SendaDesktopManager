pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services
import "../../../common/components/lazy/lifetime.js" as Lifetime

// Settings content with a sidebar of sections. Configuration goes through the
// senda CLI; tray pins use TrayPins. SettingsWindow hosts it; it opens with
// `senda settings` or from the dashboard.
Item {
    id: root

    // Sidebar entries, shared with the launcher. Each one needs a page in the
    // StackLayout below, in the same position.
    readonly property var sections: SendaSettings.sections
    property int currentSection: SendaSettings.currentSection
    onCurrentSectionChanged: SendaSettings.currentSection = currentSection
    readonly property var pageLoaders: [page0, page1, page2, page3, page4, page5, page6, page7, page8, page9, page10, page11]
    readonly property bool retainWhenHidden: pageLoaders.some(loader => loader.retained)

    component SettingsPageLoader: Loader {
        required property int sectionIndex
        readonly property bool retained: Lifetime.hasDraft(item)
        active: (SendaSettings.windowOpen && (root.searching || root.currentSection === sectionIndex)) || retained
        Layout.fillWidth: true
        Layout.fillHeight: true
        onLoaded: root.refreshSection(sectionIndex)
    }

    Connections {
        target: page5.item
        function onOpenSystemRequested() { root.currentSection = root.sections.findIndex(section => section.label === "Sistema"); }
    }

    function refreshSection(index) {
        if (index === 5) SendaSttSettings.refresh();
        if (index === 5 || index === 9 || index === 10) SendaHyprlandSettings.refresh();
        if (index === 6) SendaDisplaySettings.refresh();
        if (index === 7) SendaInputSettings.refresh();
        if (index === 8) SendaStartupSettings.refresh();
    }

    Connections {
        target: SendaSettings
        function onWindowOpenChanged() {
            if (SendaSettings.windowOpen) root.refreshSection(root.currentSection);
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
            const page = root.pageLoaders[index]?.item;
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
        if (result.row) Qt.callLater(root.revealResult, result.row);
    }

    function revealResult(row) { if (row) row.reveal(); }

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

                    SettingsPageLoader {
                        id: page0
                        sectionIndex: 0
                        source: Qt.resolvedUrl("AppearanceSettingsPage.qml")
                    }

                    SettingsPageLoader {
                        id: page1
                        sectionIndex: 1
                        source: Qt.resolvedUrl("BarSettingsPage.qml")
                    }

                    SettingsPageLoader {
                        id: page2
                        sectionIndex: 2
                        source: Qt.resolvedUrl("widgets-settings-page.qml")
                    }

                    SettingsPageLoader {
                        id: page3
                        sectionIndex: 3
                        source: Qt.resolvedUrl("CalendarSettingsPage.qml")
                    }

                    SettingsPageLoader {
                        id: page4
                        sectionIndex: 4
                        source: Qt.resolvedUrl("WeatherSettingsPage.qml")
                    }

                    SettingsPageLoader {
                        id: page5
                        sectionIndex: 5
                        source: Qt.resolvedUrl("SttSettingsPage.qml")
                    }

                    SettingsPageLoader {
                        id: page6
                        sectionIndex: 6
                        source: Qt.resolvedUrl("display-settings-page.qml")
                    }

                    SettingsPageLoader {
                        id: page7
                        sectionIndex: 7
                        source: Qt.resolvedUrl("input-settings-page.qml")
                    }

                    SettingsPageLoader {
                        id: page8
                        sectionIndex: 8
                        source: Qt.resolvedUrl("startup-settings-page.qml")
                    }

                    SettingsPageLoader {
                        id: page9
                        sectionIndex: 9
                        source: Qt.resolvedUrl("power-settings-page.qml")
                    }

                    SettingsPageLoader {
                        id: page10
                        sectionIndex: 10
                        source: Qt.resolvedUrl("system-settings-page.qml")
                    }

                    SettingsPageLoader {
                        id: page11
                        sectionIndex: 11
                        source: Qt.resolvedUrl("UpdateSettingsPage.qml")
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
