import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.services

Item {
    id: root

    property var baseTheme: null
    property bool editing: false
    property bool duplicating: false
    signal closed()
    signal saved(var info)

    implicitWidth: 728
    implicitHeight: 600
    readonly property var colorKeys: ["base", "background", "surface", "border",
        "surfaceVariant", "surfaceRaised", "surfaceRaisedBorder", "overlay",
        "textMuted", "white", "primary", "secondary", "accent", "accentDeep",
        "selection", "focus", "success", "warning", "error", "info", "text"]
    readonly property var validThemes: SendaTheme.themes.filter(theme => theme.valid === true)
    property var draftColors: ({})
    property string draftName: ""
    property string draftWallpaper: ""
    property string errorMessage: ""
    property bool pendingSave: false
    property bool initialized: false
    property bool browsing: false
    readonly property bool nameValid: draftName.length <= 40
        && /^[a-z0-9]+(-[a-z0-9]+)*$/.test(draftName)
    readonly property bool colorsValid: colorKeys.every(key =>
        /^#[0-9A-Fa-f]{6}$/.test(draftColors[key] || ""))
    readonly property bool wallpaperValid: draftWallpaper.startsWith("/")
        && /\.(png|jpe?g|gif)$/i.test(draftWallpaper) && thumbnail.status === Image.Ready
    readonly property bool canSave: nameValid && colorsValid && wallpaperValid
        && !SendaTheme.busy && !pendingSave

    function copyBase(theme) {
        const colors = {};
        for (const key of colorKeys)
            colors[key] = theme && theme.colors ? (theme.colors[key] || "") : "";
        draftColors = colors;
        draftWallpaper = theme ? theme.wallpaper || "" : "";
        errorMessage = "";
    }
    function initialize() {
        copyBase(baseTheme || SendaTheme.active || validThemes[0]);
        draftName = editing && baseTheme ? baseTheme.name : "";
    }
    function updateColor(key, value) {
        const colors = Object.assign({}, draftColors);
        colors[key] = value;
        draftColors = colors;
    }
    function previewColor(key) {
        return /^#[0-9A-Fa-f]{6}$/.test(draftColors[key] || "")
            ? draftColors[key] : Theme.colors[key];
    }
    function imageUrl(path) {
        return path.startsWith("/")
            ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }
    function save() {
        if (!canSave)
            return;
        errorMessage = "";
        pendingSave = true;
        SendaTheme.save({name: draftName, colors: Object.assign({}, draftColors),
            wallpaper: draftWallpaper, original: editing && baseTheme ? baseTheme.name : ""});
    }
    onBaseThemeChanged: { if (initialized) initialize(); }
    onEditingChanged: { if (initialized) initialize(); }
    Component.onCompleted: { initialize(); initialized = true; }

    Connections {
        target: SendaTheme
        function onSaved(info) {
            if (!root.pendingSave) return;
            root.pendingSave = false;
            root.saved(info);
        }
        function onSaveFailed(error) {
            if (!root.pendingSave) return;
            root.pendingSave = false;
            root.errorMessage = error;
        }
    }
    component Field: TextField {
        font: Theme.font.body
        color: Theme.colors.text
        placeholderTextColor: Theme.colors.overlay
        selectByMouse: true
        padding: Theme.spacing.sm
        background: Rectangle {
            color: Theme.colors.background
            radius: Theme.rounding.small
            border.color: parent.activeFocus ? Theme.colors.focus : Theme.colors.surfaceVariant
        }
    }
    component Action: Button {
        property bool primary: false
        font: Theme.font.body
        padding: Theme.spacing.sm
        contentItem: Text {
            text: parent.text
            font: Theme.font.body
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: !parent.enabled ? Theme.colors.overlay
                : parent.primary ? Theme.colors.base : Theme.colors.text
        }
        background: Rectangle {
            radius: Theme.rounding.normal
            color: !parent.enabled ? Theme.colors.surface
                : parent.primary ? (parent.hovered ? Theme.colors.secondary : Theme.colors.primary)
                : parent.hovered ? Theme.colors.surfaceVariant : Theme.colors.surface
            border.color: parent.activeFocus ? Theme.colors.focus : Theme.colors.surfaceVariant
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing.md
        Text {
            text: root.editing ? "Editar tema"
                : root.duplicating ? `Duplicar «${root.baseTheme?.name ?? ""}»` : "Crear tema"
            font: Theme.font.title
            color: Theme.colors.text
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: scroll.availableWidth
                spacing: Theme.spacing.sm
                enabled: !root.pendingSave
                Text {
                    visible: !root.editing && !root.duplicating
                    text: "Tema base"
                    font: Theme.font.heading
                    color: Theme.colors.text
                }
                ComboBox {
                    id: baseSelector
                    visible: !root.editing && !root.duplicating
                    Layout.fillWidth: true
                    model: root.validThemes
                    textRole: "name"
                    currentIndex: root.validThemes.findIndex(theme =>
                        theme.name === (root.baseTheme || SendaTheme.active || {}).name)
                    onActivated: index => root.copyBase(root.validThemes[index])
                    font: Theme.font.body
                    contentItem: Text {
                        leftPadding: Theme.spacing.sm
                        rightPadding: Theme.spacing.xl
                        verticalAlignment: Text.AlignVCenter
                        text: baseSelector.displayText
                        color: Theme.colors.text
                        font: Theme.font.body
                    }
                    background: Rectangle {
                        implicitHeight: 36
                        color: Theme.colors.surface
                        radius: Theme.rounding.small
                        border.color: baseSelector.activeFocus ? Theme.colors.focus : Theme.colors.border
                    }
                    delegate: ItemDelegate {
                        required property var modelData
                        width: baseSelector.width
                        text: modelData.name
                        font: Theme.font.body
                        contentItem: Text { text: parent.text; color: Theme.colors.text; font: Theme.font.body }
                        background: Rectangle { color: parent.hovered ? Theme.colors.surfaceVariant : Theme.colors.surfaceRaised }
                    }
                    popup: Popup {
                        y: baseSelector.height
                        width: baseSelector.width
                        implicitHeight: Math.min(240, baseList.contentHeight + Theme.spacing.sm)
                        padding: Theme.spacing.xs
                        contentItem: ListView {
                            id: baseList
                            clip: true
                            model: baseSelector.popup.visible ? baseSelector.delegateModel : null
                            ScrollBar.vertical: ScrollBar {}
                        }
                        background: Rectangle {
                            color: Theme.colors.surfaceRaised
                            radius: Theme.rounding.normal
                            border.color: Theme.colors.surfaceRaisedBorder
                        }
                    }
                }
                Text { text: "Nombre"; font: Theme.font.heading; color: Theme.colors.text }
                Field {
                    Layout.fillWidth: true
                    text: root.draftName
                    placeholderText: "mi-tema"
                    onTextEdited: root.draftName = text
                }
                Text {
                    Layout.fillWidth: true
                    text: root.nameValid ? "" : "Usa minúsculas y números separados por guiones (máximo 40 caracteres)."
                    visible: !root.nameValid
                    wrapMode: Text.Wrap
                    font: Theme.font.caption
                    color: Theme.colors.error
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 116
                    radius: Theme.rounding.normal
                    color: root.previewColor("base")
                    border.color: root.previewColor("border")
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing.sm
                        spacing: Theme.spacing.sm
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: Theme.rounding.small
                            color: root.previewColor("background")
                            Text { anchors.centerIn: parent; text: "Senda · Vista previa"; font: Theme.font.body; color: root.previewColor("primary") }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.rounding.small
                            color: root.previewColor("surface")
                            border.color: root.previewColor("border")
                            Text { anchors.centerIn: parent; text: "Texto de una tarjeta"; font: Theme.font.body; color: root.previewColor("text") }
                        }
                    }
                }
                Text { text: "Colores · #RRGGBB"; font: Theme.font.heading; color: Theme.colors.text }
                Repeater {
                    model: root.colorKeys
                    delegate: ColorField {
                        required property string modelData
                        Layout.fillWidth: true
                        colorKey: modelData
                        text: root.draftColors[modelData] || ""
                        onEdited: value => root.updateColor(modelData, value)
                    }
                }
                Text {
                    visible: !root.colorsValid
                    text: "Cada color debe tener el formato #RRGGBB."
                    font: Theme.font.caption
                    color: Theme.colors.error
                }
                Text { text: "Wallpaper"; font: Theme.font.heading; color: Theme.colors.text }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.sm
                    Field {
                        Layout.fillWidth: true
                        text: root.draftWallpaper
                        placeholderText: "/ruta/a/imagen.png"
                        onTextEdited: root.draftWallpaper = text
                    }
                    Action { text: "Elegir…"; onClicked: root.browsing = !root.browsing }
                }
                WallpaperBrowser {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    visible: root.browsing
                    startPath: root.draftWallpaper
                    onVisibleChanged: if (visible) open()
                    onPicked: path => { root.draftWallpaper = path; root.browsing = false; }
                    onCancelled: root.browsing = false
                }
                Image {
                    id: thumbnail
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    source: root.imageUrl(root.draftWallpaper)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }
                Text {
                    Layout.fillWidth: true
                    visible: !root.wallpaperValid && thumbnail.status !== Image.Loading
                    text: "Indica la ruta absoluta de una imagen PNG, JPEG o GIF."
                    wrapMode: Text.Wrap
                    font: Theme.font.caption
                    color: Theme.colors.error
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: root.errorMessage !== ""
            text: root.errorMessage
            wrapMode: Text.Wrap
            font: Theme.font.body
            color: Theme.colors.error
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.sm
            Item { Layout.fillWidth: true }
            Action { text: "Cancelar"; enabled: !root.pendingSave; onClicked: root.closed() }
            Action {
                text: root.pendingSave ? "Guardando…" : "Guardar"
                primary: true
                enabled: root.canSave
                onClicked: root.save()
            }
        }
    }
}
