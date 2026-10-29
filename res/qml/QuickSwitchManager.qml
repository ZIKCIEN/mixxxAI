import QtQuick 2.12
import QtQuick.Window 2.12
import Qt.labs.settings 1.1

// Geometry-based Quick Switch. Put each role window on its intended monitor,
// then use the swap/rotate controls to exchange their desktop positions.
Item {
    id: root

    required property var mainWindow
    required property var libraryWindow
    required property var toolsWindow

    property var undoLayout: null
    property bool restoring: true

    width: 0
    height: 0
    visible: false

    Settings {
        id: saved
        category: "QuickSwitchMultiScreen"

        property bool layoutSaved: false
        property int mainX: 0
        property int mainY: 0
        property int mainWidth: 1792
        property int mainHeight: 1008
        property int libraryX: 80
        property int libraryY: 80
        property int libraryWidth: 1000
        property int libraryHeight: 700
        property int toolsX: 120
        property int toolsY: 120
        property int toolsWidth: 760
        property int toolsHeight: 700
    }

    function windows() {
        return [mainWindow, libraryWindow, toolsWindow];
    }

    function snapshot() {
        var result = [];
        var list = windows();
        for (var i = 0; i < list.length; ++i) {
            result.push({
                x: list[i].x,
                y: list[i].y,
                width: list[i].width,
                height: list[i].height
            });
        }
        return result;
    }

    function applyLayout(layout) {
        if (!layout || layout.length !== 3)
            return;
        restoring = true;
        var list = windows();
        for (var i = 0; i < list.length; ++i) {
            list[i].x = layout[i].x;
            list[i].y = layout[i].y;
            list[i].width = layout[i].width;
            list[i].height = layout[i].height;
        }
        restoring = false;
        saveLayout();
    }

    function saveLayout() {
        if (restoring || !mainWindow || !libraryWindow || !toolsWindow)
            return;
        saved.mainX = mainWindow.x;
        saved.mainY = mainWindow.y;
        saved.mainWidth = mainWindow.width;
        saved.mainHeight = mainWindow.height;
        saved.libraryX = libraryWindow.x;
        saved.libraryY = libraryWindow.y;
        saved.libraryWidth = libraryWindow.width;
        saved.libraryHeight = libraryWindow.height;
        saved.toolsX = toolsWindow.x;
        saved.toolsY = toolsWindow.y;
        saved.toolsWidth = toolsWindow.width;
        saved.toolsHeight = toolsWindow.height;
        saved.layoutSaved = true;
    }

    function restoreLayout() {
        if (!saved.layoutSaved)
            return;
        applyLayout([
            { x: saved.mainX, y: saved.mainY, width: saved.mainWidth, height: saved.mainHeight },
            { x: saved.libraryX, y: saved.libraryY, width: saved.libraryWidth, height: saved.libraryHeight },
            { x: saved.toolsX, y: saved.toolsY, width: saved.toolsWidth, height: saved.toolsHeight }
        ]);
    }

    function prepareVisibleWindows() {
        // Geometry changes are ignored by some window systems while fullscreen
        // or maximized. Switch visible windows to windowed mode before swapping.
        var list = windows();
        for (var i = 0; i < list.length; ++i) {
            if (list[i].visible && list[i].visibility !== Window.Windowed)
                list[i].visibility = Window.Windowed;
        }
    }

    function swap(first, second) {
        prepareVisibleWindows();
        var current = snapshot();
        undoLayout = current;
        var next = snapshot();
        var temporary = next[first];
        next[first] = next[second];
        next[second] = temporary;
        applyLayout(next);
    }

    function rotate() {
        prepareVisibleWindows();
        var current = snapshot();
        undoLayout = current;
        applyLayout([current[1], current[2], current[0]]);
    }

    function undo() {
        if (!undoLayout)
            return;
        prepareVisibleWindows();
        var previous = undoLayout;
        undoLayout = null;
        applyLayout(previous);
    }

    // Emergency recovery if a monitor is unplugged and a window is stranded
    // outside the remaining desktop. The user can drag the windows back later.
    function resetNearMainWindow() {
        undoLayout = snapshot();
        restoring = true;
        libraryWindow.x = mainWindow.x + 36;
        libraryWindow.y = mainWindow.y + 36;
        libraryWindow.width = Math.max(680, Math.min(1000, mainWindow.width - 80));
        libraryWindow.height = Math.max(420, Math.min(700, mainWindow.height - 80));
        toolsWindow.x = mainWindow.x + 72;
        toolsWindow.y = mainWindow.y + 72;
        toolsWindow.width = Math.max(600, Math.min(760, mainWindow.width - 120));
        toolsWindow.height = Math.max(420, Math.min(700, mainWindow.height - 120));
        restoring = false;
        saveLayout();
    }

    function onGeometryChanged() {
        saveLayout();
    }

    property bool screenInfoWarned: false

    // Rectangle of a screen in desktop coordinates. Depending on the Qt
    // version the entries of Qt.application.screens expose either
    // virtualX/virtualY/width/height or a geometry rect; return null if
    // neither is available.
    function screenRect(screen) {
        if (!screen)
            return null;
        if (screen.virtualX !== undefined && screen.width !== undefined) {
            return {
                x: screen.virtualX,
                y: screen.virtualY,
                width: screen.width,
                height: screen.height
            };
        }
        if (screen.geometry !== undefined && screen.geometry !== null) {
            return {
                x: screen.geometry.x,
                y: screen.geometry.y,
                width: screen.geometry.width,
                height: screen.geometry.height
            };
        }
        return null;
    }

    // A window is reachable if enough of it overlaps at least one screen
    // for the user to grab its title bar. If no screen geometry can be read
    // at all, assume reachable rather than moving windows blindly.
    function isReachable(win) {
        var screens = Qt.application.screens;
        var margin = 100;
        var known = 0;
        if (screens) {
            for (var i = 0; i < screens.length; ++i) {
                var g = screenRect(screens[i]);
                if (!g)
                    continue;
                ++known;
                if (win.x + win.width - margin > g.x
                        && win.x + margin < g.x + g.width
                        && win.y + win.height - margin > g.y
                        && win.y + margin < g.y + g.height) {
                    return true;
                }
            }
        }
        if (known === 0) {
            if (!screenInfoWarned) {
                screenInfoWarned = true;
                console.warn("QuickSwitch: screen geometry unavailable, automatic recovery disabled");
            }
            return true;
        }
        return false;
    }

    // Automatic recovery after a monitor is unplugged (or when the saved
    // layout refers to a monitor that is no longer there). The main window
    // is the anchor: if it is not reachable itself, the window system is
    // expected to have moved it already, so nothing is done.
    function recoverIfStranded() {
        if (!mainWindow || !libraryWindow || !toolsWindow)
            return;
        if (!isReachable(mainWindow))
            return;
        if (!isReachable(libraryWindow) || !isReachable(toolsWindow))
            resetNearMainWindow();
    }

    // Screen changes arrive in bursts; wait for the layout to settle.
    Timer {
        id: recoverTimer
        interval: 750
        onTriggered: root.recoverIfStranded()
    }

    Connections {
        target: Qt.application
        // Not every Qt version/platform exposes this signal; stay silent if not.
        ignoreUnknownSignals: true
        function onScreensChanged() { recoverTimer.restart(); }
    }

    // Independent of screen signals: whenever a secondary window is about to
    // be shown, make sure it is not stranded outside the current desktop.
    Connections {
        target: root.libraryWindow
        function onVisibleChanged() {
            if (root.libraryWindow.visible)
                recoverTimer.restart();
        }
    }
    Connections {
        target: root.toolsWindow
        function onVisibleChanged() {
            if (root.toolsWindow.visible)
                recoverTimer.restart();
        }
    }

    Connections {
        target: root.mainWindow
        function onXChanged() { root.onGeometryChanged(); }
        function onYChanged() { root.onGeometryChanged(); }
        function onWidthChanged() { root.onGeometryChanged(); }
        function onHeightChanged() { root.onGeometryChanged(); }
    }
    Connections {
        target: root.libraryWindow
        function onXChanged() { root.onGeometryChanged(); }
        function onYChanged() { root.onGeometryChanged(); }
        function onWidthChanged() { root.onGeometryChanged(); }
        function onHeightChanged() { root.onGeometryChanged(); }
    }
    Connections {
        target: root.toolsWindow
        function onXChanged() { root.onGeometryChanged(); }
        function onYChanged() { root.onGeometryChanged(); }
        function onWidthChanged() { root.onGeometryChanged(); }
        function onHeightChanged() { root.onGeometryChanged(); }
    }

    Component.onCompleted: {
        if (saved.layoutSaved) {
            restoreLayout();
        } else {
            restoring = false;
            saveLayout();
        }
        recoverTimer.start();
    }
}
