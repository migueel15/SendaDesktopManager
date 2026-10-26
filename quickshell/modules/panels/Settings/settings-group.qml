import QtQuick
import QtQuick.Layouts
import qs.common

Rectangle {
    id: root
    default property alias rows: column.data
    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 2 * Theme.spacing.md
    color: Theme.colors.surface
    border { width: 1; color: Theme.colors.border }
    radius: Theme.rounding.normal
    ColumnLayout {
        id: column
        x: Theme.spacing.md
        y: Theme.spacing.md
        width: parent.width - 2 * Theme.spacing.md
        spacing: Theme.spacing.md
    }
}
