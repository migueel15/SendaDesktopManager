import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// "EL TIEMPO": the weather for the location chosen in the settings panel.
Rectangle {
    id: root

    readonly property var current: SendaWeather.current
    readonly property string placeName: SendaWeather.location.split(",")[0]

    function conditionIcon(condition) {
        switch (condition) {
        case "clear": return "󰖙";
        case "mostly-clear":
        case "partly-cloudy": return "󰖕";
        case "cloudy": return "󰖐";
        case "fog": return "󰖑";
        case "drizzle": return "󰖗";
        case "rain": return "󰖖";
        case "snow": return "󰖘";
        case "storm": return "󰖓";
        default: return "󰖐";
        }
    }

    radius: Theme.rounding.normal
    color: Theme.colors.surface
    border.width: 1
    border.color: Theme.colors.surfaceVariant

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "EL TIEMPO"
                color: Theme.colors.overlay
                font.family: Theme.font.overlay.family
                font.pixelSize: Theme.scaled(11)
                font.weight: Font.Bold
            }
            Text {
                text: "󰒓"
                color: Theme.colors.overlay
                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(16)

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: OverlayService.setCurrentPanel("settings")
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            visible: SendaWeather.status === "ready" && root.current !== null

            Text {
                text: root.conditionIcon(root.current?.condition)
                color: Theme.colors.secondary
                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(40)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: `${Math.round(root.current?.temperature ?? 0)}°`
                    color: Theme.colors.text
                    font.family: Theme.font.title.family
                    font.pixelSize: Theme.scaled(30)
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: root.current?.label ?? ""
                    color: Theme.colors.text
                    font.family: Theme.font.base.family
                    font.pixelSize: Theme.scaled(12)
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: SendaWeather.status === "ready" && root.current !== null
            text: `Máx ${Math.round(root.current?.max ?? 0)}°  ·  Mín ${Math.round(root.current?.min ?? 0)}°  ·  ${root.placeName}`
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: SendaWeather.status !== "ready"
            verticalAlignment: Text.AlignVCenter
            text: {
                if (SendaWeather.status === "loading") return "Cargando el tiempo…";
                if (SendaWeather.status === "unconfigured") return "Elige tu localidad en la configuración para ver el tiempo.";
                return SendaWeather.message;
            }
            color: SendaWeather.status === "error" ? Theme.colors.warning : Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            wrapMode: Text.WordWrap

            MouseArea {
                anchors.fill: parent
                enabled: SendaWeather.status === "unconfigured"
                cursorShape: Qt.PointingHandCursor
                onClicked: OverlayService.setCurrentPanel("settings")
            }
        }
    }
}
