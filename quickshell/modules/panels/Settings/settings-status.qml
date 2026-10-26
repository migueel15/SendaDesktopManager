import QtQuick
import qs.common

Text {
    id: root
    property string message: ""
    property bool error: false
    function show(message, error) {
        root.error = error;
        root.message = message;
        expiry.stop();
        if (!error && message !== "") expiry.start();
    }
    // A reserved footer keeps feedback from moving the page.
    text: message
    color: error ? Theme.colors.error : Theme.colors.success
    font: Theme.font.caption
    wrapMode: Text.WordWrap
    maximumLineCount: 2
    elide: Text.ElideRight
    Timer { id: expiry; interval: 3500; onTriggered: root.message = "" }
}
