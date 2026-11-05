pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.components.controls
import qs.services
import "../../../common/components/lazy/lifetime.js" as Lifetime

// Settings content with a sidebar of sections. Configuration goes through the
// zenda CLI; tray pins use TrayPins. SettingsWindow hosts it; it opens with
// `zenda settings` or from the dashboard.
Item {
    id: root

    // Sidebar entries, shared with the launcher. Each one needs a page in the
    // StackLayout below, in the same position.
    readonly property var sections: ZendaSettings.sections
    property int currentSection: ZendaSettings.currentSection
    onCurrentSectionChanged: ZendaSettings.currentSection = currentSection
    readonly property var pageLoaders: [page0, page1, page2, page3, page4, page5, page6, page7, page8, page9, page10, page11]
    readonly property bool retainWhenHidden: pageLoaders.some(loader => loader.retained)

    component SettingsPageLoader: Loader {
        required property int sectionIndex
        readonly property bool retained: Lifetime.hasDraft(item)
        active: (ZendaSettings.windowOpen && (root.searching || root.currentSection === sectionIndex)) || retained
        Layout.fillWidth: true
        Layout.fillHeight: true
        onLoaded: root.refreshSection(sectionIndex)
    }

    Connections {
        target: page5.item
        function onOpenSystemRequested() { root.currentSection = root.sections.findIndex(section => section.label === "Sistema"); }
    }

    function refreshSection(index) {
        if (index === 5) ZendaSttSettings.refresh();
        if (index === 5 || index === 9 || index === 10) ZendaHyprlandSettings.refresh();
        if (index === 6) ZendaDisplaySettings.refresh();
        if (index === 7) ZendaInputSettings.refresh();
        if (index === 8) ZendaStartupSettings.refresh();
    }

    Connections {
        target: ZendaSettings
        function onWindowOpenChanged() {
            if (ZendaSettings.windowOpen) root.refreshSection(root.currentSection);
        }
    }

    // The launcher asks for a section through ZendaSettings.openSection.
    function applyRequestedSection() {
        const index = root.sections.findIndex(section => section.label === ZendaSettings.requestedSection);
        if (index !== -1) root.currentSection = index;
        ZendaSettings.requestedSection = "";
    }
    Component.onCompleted: applyRequestedSection()

    // The update notice in the bar opens this panel on the update section.
    Connections {
        target: ZendaUpdate

        function onOpenRequested() {
            root.currentSection = root.sections.findIndex(section => section.label === "Actualización");
        }
    }

    Connections {
        target: ZendaSettings
        function onRequestedSectionChanged() { if (ZendaSettings.requestedSection) root.applyRequestedSection(); }
        function onNoticeChanged() { feedback.show(ZendaSettings.notice, ZendaSettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(ZendaSettings.notice, ZendaSettings.noticeIsError); }
    }
    Connections {
        target: ZendaSttSettings
        function onNoticeChanged() { feedback.show(ZendaSttSettings.notice, ZendaSttSettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(ZendaSttSettings.notice, ZendaSttSettings.noticeIsError); }
    }

    Connections {
        target: ZendaHyprlandSettings
        function onNoticeChanged() { feedback.show(ZendaHyprlandSettings.notice, ZendaHyprlandSettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(ZendaHyprlandSettings.notice, ZendaHyprlandSettings.noticeIsError); }
    }

    Connections {
        target: ZendaDisplaySettings
        function onNoticeChanged() { feedback.show(ZendaDisplaySettings.notice, ZendaDisplaySettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(ZendaDisplaySettings.notice, ZendaDisplaySettings.noticeIsError); }
    }

    Connections {
        target: ZendaStartupSettings
        function onNoticeChanged() { feedback.show(ZendaStartupSettings.notice, ZendaStartupSettings.noticeIsError); }
    }

    // Material 3 content container: one large tonal card, no border, holding
    // the option groups, which sit a tone lighter.
    component SettingsCard: Rectangle {
        radius: Theme.rounding.card + Theme.spacing.xs
        color: Theme.colors.surface
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

        // Material 3 standard navigation drawer: no container of its own, it
        // sits on the window background next to the content card.
        Item {
            // Reserve room for the longest label at the active text scale.
            Layout.preferredWidth: Math.max(root.width * 0.24, Theme.scaled(170))
            Layout.minimumWidth: Math.max(root.width * 0.24, Theme.scaled(170))
            Layout.maximumWidth: Math.max(root.width * 0.24, Theme.scaled(170))
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: Theme.spacing.md
                anchors.bottomMargin: Theme.spacing.md
                spacing: Theme.spacing.xs

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.spacing.sm
                    spacing: Theme.spacing.sm

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.spacing.sm
                        text: "Ajustes"
                        color: Theme.colors.text
                        elide: Text.ElideRight
                        font.family: Theme.font.title.family
                        font.pixelSize: Theme.scaled(18)
                        font.weight: Font.Bold
                    }

                    ZendaIconButton {
                        icon: "󰅖"
                        accessibleLabel: "Cerrar"
                        onClicked: ZendaSettings.closeWindow()
                    }
                }

                ZendaField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.spacing.sm
                    radius: Theme.rounding.full
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
                    Layout.leftMargin: Theme.spacing.sm
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
                    delegate: ZendaListItem {
                        id: resultEntry
                        required property var modelData
                        required property int index
                        implicitHeight: Theme.scaled(56)
                        text: modelData.title
                        supportingText: modelData.section
                        trailingIcon: ""
                        selected: root.resultIndex === index
                        onClicked: root.openResult(modelData)
                    }
                }

                Repeater {
                    model: root.sections

                    delegate: ZendaListItem {
                        id: sectionEntry
                        required property var modelData
                        required property int index

                        visible: !root.searching
                        Layout.fillWidth: true
                        implicitHeight: Theme.scaled(48)
                        leadingIcon: modelData.icon
                        text: modelData.label
                        trailingIcon: ""
                        selected: root.currentSection === index
                        onClicked: root.currentSection = index
                    }
                }

                Item {
                    Layout.fillHeight: true
                    visible: !root.searching
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
                ZendaStatus {
                    id: feedback
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.scaled(30)
                }
            }
        }
    }
}
