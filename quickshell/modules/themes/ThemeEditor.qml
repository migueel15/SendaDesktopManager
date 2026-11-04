import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.common
import qs.common.components.controls
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
    readonly property var validThemes: ZendaTheme.themes.filter(theme => theme.valid === true)
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
        && !ZendaTheme.busy && !pendingSave

    function copyBase(theme) {
        const colors = {};
        for (const key of colorKeys)
            colors[key] = theme && theme.colors ? (theme.colors[key] || "") : "";
        draftColors = colors;
        draftWallpaper = theme ? theme.wallpaper || "" : "";
        errorMessage = "";
    }
    function initialize() {
        copyBase(baseTheme || ZendaTheme.active || validThemes[0]);
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
        ZendaTheme.save({name: draftName, colors: Object.assign({}, draftColors),
            wallpaper: draftWallpaper, original: editing && baseTheme ? baseTheme.name : ""});
    }
    onBaseThemeChanged: { if (initialized) initialize(); }
    onEditingChanged: { if (initialized) initialize(); }
    Component.onCompleted: { initialize(); initialized = true; }

    Connections {
        target: ZendaTheme
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
ZendaSelect {
                    visible: !root.editing && !root.duplicating
                    Layout.fillWidth: true
                    options: root.validThemes.map(theme => theme.name)
                    value: (root.baseTheme || ZendaTheme.active || {}).name ?? ""
                    onChosen: name => root.copyBase(root.validThemes.find(theme => theme.name === name))
                }
                Text { text: "Nombre"; font: Theme.font.heading; color: Theme.colors.text }
                ZendaField {
                    Layout.fillWidth: true
                    text: root.draftName
                    placeholder: "mi-tema"
                    onTextChanged: root.draftName = text
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
                    radius: Theme.card.radius
                    color: root.previewColor("base")
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing.md
                        spacing: Theme.spacing.sm
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: height / 2
                            color: root.previewColor("background")
                            Text { anchors.centerIn: parent; text: "Zenda · Vista previa"; font: Theme.font.body; color: root.previewColor("primary") }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.rounding.large
                            color: root.previewColor("surfaceRaised") || root.previewColor("surface")
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
                    ZendaField {
                        Layout.fillWidth: true
                        text: root.draftWallpaper
                        placeholder: "/ruta/a/imagen.png"
                        onTextChanged: root.draftWallpaper = text
                    }
                    ZendaButton { label: "Elegir…"; onClicked: root.browsing = !root.browsing }
                }
                Loader {
                    Layout.fillWidth: true
                    Layout.preferredHeight: item?.implicitHeight ?? 0
                    active: root.browsing
                    visible: active
                    sourceComponent: Component {
                        WallpaperBrowser {
                            startPath: root.draftWallpaper
                            onPicked: path => { root.draftWallpaper = path; root.browsing = false; }
                            onCancelled: root.browsing = false
                        }
                    }
                }
                ClippingRectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    radius: Theme.card.radius
                    color: Theme.card.fill
                Image {
                    id: thumbnail
                    anchors.fill: parent
                    sourceSize: Qt.size(320, 240)
                    cache: false
                    source: root.imageUrl(root.draftWallpaper)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
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
            ZendaButton { label: "Cancelar"; enabled: !root.pendingSave; onClicked: root.closed() }
            ZendaButton {
                label: root.pendingSave ? "Guardando…" : "Guardar"
                busy: root.pendingSave
                primary: true
                enabled: root.canSave
                onClicked: root.save()
            }
        }
    }
}
