import QtQuick
import QtQuick.Layouts
import qs.common

Rectangle {
    id: root
    default property alias rows: column.data
    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 2 * Theme.spacing.lg
    color: Theme.card.fill
    radius: Theme.card.radius
    ColumnLayout {
        id: column
        x: Theme.spacing.lg
        y: Theme.spacing.lg
        width: parent.width - 2 * Theme.spacing.lg
        spacing: Theme.spacing.md
    }
}
