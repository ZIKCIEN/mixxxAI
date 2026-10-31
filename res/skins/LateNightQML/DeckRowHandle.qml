import "LateNightTheme"
import QtQuick

// Thin grab handle drawn on the gutter under a deck row. Dragging it picks the
// Mini / Compact / Full size nearest to the pointer for the row above it.
Item {
    id: root

    // Y of the bottom edge of the row this handle resizes, in `reference` coordinates.
    required property real boundaryY
    // Size state (0 = Mini, 1 = Compact, 2 = Full) currently applied to that row.
    required property int currentState
    // Item whose coordinate system boundaryY and rowTop are expressed in.
    required property Item reference
    // Y of the top edge of the row this handle resizes, in `reference` coordinates.
    required property real rowTop
    readonly property bool dragging: dragArea.pressed
    readonly property bool highlighted: dragArea.pressed || dragArea.containsMouse

    signal resetRequested
    signal stateRequested(int deckState)

    function nearestState(rowHeight) {
        const heights = [LateNightTheme.miniDeckHeight, LateNightTheme.compactDeckHeight, LateNightTheme.fullDeckHeight];
        let best = 0;
        let bestDistance = Math.abs(rowHeight - heights[0]);
        for (let i = 1; i < heights.length; ++i) {
            const distance = Math.abs(rowHeight - heights[i]);
            if (distance < bestDistance) {
                best = i;
                bestDistance = distance;
            }
        }
        return best;
    }

    // Centered on the gutter below the row, a few pixels taller for easier grabbing.
    height: LateNightTheme.deckRowGutter + 4
    y: boundaryY + LateNightTheme.deckRowGutter / 2 - height / 2
    z: 20

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: root.dragging ? LateNightTheme.libraryPanelSplitterHandleActive : LateNightTheme.libraryPanelSplitterHandle
        height: LateNightTheme.deckRowGutter
        opacity: root.highlighted ? 0.9 : 0
        visible: opacity > 0

        Behavior on opacity {
            enabled: LateNightTheme.layoutAnimationsEnabled

            NumberAnimation {
                duration: 100
            }
        }
    }
    MouseArea {
        id: dragArea

        // Offset between the pointer and the bottom edge of the row when the press started.
        property real grabOffset: 0

        anchors.fill: parent
        cursorShape: Qt.SizeVerCursor
        hoverEnabled: true
        preventStealing: true

        onDoubleClicked: root.resetRequested()
        onPositionChanged: mouse => {
            if (!pressed)
                return;

            const pointerY = mapToItem(root.reference, mouse.x, mouse.y).y;
            const requestedState = root.nearestState(pointerY - grabOffset - root.rowTop);
            if (requestedState !== root.currentState)
                root.stateRequested(requestedState);
        }
        onPressed: mouse => {
            grabOffset = mapToItem(root.reference, mouse.x, mouse.y).y - root.boundaryY;
        }
    }
}
