import QtQml

QtObject {
    enum DeckSize {
        Mini = 0,
        Compact = 1,
        Full = 2
    }

    required property bool maximizeLibrary
    required property bool mixerVisible
    required property int savedDeckSize
    required property int savedSecondRowDeckSize
    required property bool show4decks
    required property bool showCompactVuMetersSetting
    required property bool showMaximizedDecks

    readonly property int effectiveDeckSize: maximizeLibrary ? LayoutState.Mini : (mixerVisible ? LayoutState.Full : normalizedSavedDeckSize)
    readonly property int effectiveSecondRowDeckSize: maximizeLibrary ? LayoutState.Mini : (mixerVisible ? LayoutState.Full : normalizedSavedSecondRowDeckSize)
    readonly property bool showCompactVuMeters: !maximizeLibrary && !mixerVisible && normalizedSavedDeckSize === LayoutState.Compact
            && (!show4decks || normalizedSavedSecondRowDeckSize === LayoutState.Compact) && showCompactVuMetersSetting
    readonly property bool showDeckArea: !maximizeLibrary || showMaximizedDecks
    readonly property int normalizedSavedDeckSize: Math.max(LayoutState.Mini, Math.min(LayoutState.Full, Math.round(savedDeckSize)))
    readonly property int normalizedSavedSecondRowDeckSize: Math.max(LayoutState.Mini, Math.min(LayoutState.Full, Math.round(savedSecondRowDeckSize)))
}
