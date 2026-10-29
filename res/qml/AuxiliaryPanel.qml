import "." as Skin
import "Effects" as Effects
import "Theme"
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Label {
            Layout.fillWidth: true
            color: Theme.white
            font.pixelSize: 24
            text: qsTr("Effets, auxiliaires et entrées")
            wrapMode: Text.Wrap
        }

        ScrollView {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: 16

                Label {
                    color: Theme.white
                    font.pixelSize: 20
                    text: qsTr("Unités d'effets")
                }

                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: effectUnit.implicitHeight + 12
                        color: Theme.darkGray2
                        radius: 6

                        Effects.EffectUnit {
                            id: effectUnit
                            anchors.fill: parent
                            anchors.margins: 6
                            unitNumber: index + 1
                        }
                    }
                }

                Label {
                    color: Theme.white
                    font.pixelSize: 20
                    text: qsTr("Entrées auxiliaires")
                }

                Repeater {
                    model: 2
                    delegate: Rectangle {
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 72
                        color: Theme.darkGray2
                        radius: 6

                        Skin.AuxiliaryUnit {
                            anchors.centerIn: parent
                            height: 60
                            unitNumber: index + 1
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    color: Theme.lightGray3
                    text: qsTr("Les commandes agissent sur le moteur Mixxx partagé. Cette fenêtre ne démarre pas une seconde instance audio.")
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
