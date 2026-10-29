import QtQuick
import "../LateNightTheme"

// Drag handle placed along the bottom edge of a rack section (FX, samplers,
// mic/aux). Dragging it up or down asks the section for another content
// height; the section keeps the rack at its natural height and clips it.
// Double-click asks for the natural height again.
//
// The pointer position is tracked in scene coordinates, so the handle moving
// together with the section while dragging does not feed back into the delta.
Rectangle {
    id: root

    // Height of the visible content above the handle (without the handle).
    property real contentHeight: 0
    // Natural height of the content; dragging beyond it means "natural".
    property real maximumContentHeight: 0
    property real minimumContentHeight: 0
    readonly property bool resizing: dragArea.pressed

    // A request of -1 means "use the natural height".
    signal contentHeightRequested(real requestedHeight)
    signal resetRequested

    clip: true
    color: LateNightTheme.libraryPanelSplitterBackground
    implicitHeight: 14

    Image {
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
        source: root.resizing
                ? LateNightTheme.assetWaveformSplitterHandlePressed
                : LateNightTheme.assetWaveformSplitterHandle
    }
    MouseArea {
        id: dragArea

        property real pressContentHeight: 0
        property real pressSceneY: 0

        function sceneY(mouse) {
            return mapToItem(null, mouse.x, mouse.y).y;
        }

        anchors.fill: parent
        cursorShape: Qt.SplitVCursor
        preventStealing: true

        onDoubleClicked: root.resetRequested()
        onPositionChanged: function (mouse) {
            if (!pressed)
                return;
            const wanted = pressContentHeight + (sceneY(mouse) - pressSceneY);
            if (wanted >= root.maximumContentHeight) {
                root.contentHeightRequested(-1);
                return;
            }
            root.contentHeightRequested(Math.max(root.minimumContentHeight, wanted));
        }
        onPressed: function (mouse) {
            pressSceneY = sceneY(mouse);
            pressContentHeight = root.contentHeight;
        }
    }
}
