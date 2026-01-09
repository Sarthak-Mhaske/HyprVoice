import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: root
    property bool active: false

    Process {
        id: checker
        command: ["test", "-f", "/tmp/voice_active"]
        onExited: (code, status) => root.active = (code === 0)
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: checker.running = true
    }

    PanelWindow {
        visible: root.active
        color: "transparent"
        implicitWidth: 400
        implicitHeight: 200

        anchors {
            bottom: true
            left: true
            right: true
        }
        margins.bottom: 60

        WlrLayershell.namespace: "quickshell:voiceOverlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        Item {
            id: container
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            width: 600
            height: 180

            // Voice sync timer for coordinated animation
            property int voiceBeat: 0
            Timer {
                interval: 80
                running: root.active
                repeat: true
                onTriggered: container.voiceBeat = (container.voiceBeat + 1) % 20
            }

            // Left wave bars
            Row {
                anchors.right: centerSymbol.left
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                layoutDirection: Qt.RightToLeft

                Repeater {
                    model: 6
                    
                    Rectangle {
                        // Voice-like height pattern (center is tallest)
                        property real baseHeight: [50, 75, 100, 90, 65, 40][index]
                        property real currentMultiplier: 1.0
                        
                        width: 8
                        height: baseHeight * currentMultiplier
                        radius: 2.5
                        anchors.verticalCenter: parent.verticalCenter
                        
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: ["#f38ba8", "#cba6f7", "#89b4fa", "#94e2d5", "#b4befe", "#f5c2e7"][index] }
                            GradientStop { position: 1.0; color: ["#f9a8d4", "#d8b4fe", "#93c5fd", "#99f6e4", "#c4b5fd", "#fbcfe8"][index] }
                        }
                        
                        opacity: 0.95

                        // Coordinated voice-like animation
                        SequentialAnimation on currentMultiplier {
                            running: root.active
                            loops: Animation.Infinite
                            
                            // Rise (voice starts)
                            NumberAnimation { 
                                to: 1.5 + (Math.abs(3 - index) * 0.15)  // Center bars rise more
                                duration: 400 + (index * 30)
                                easing.type: Easing.OutQuad 
                            }
                            // Peak hold
                            PauseAnimation { duration: 100 + (index * 20) }
                            // Drop (voice pauses)
                            NumberAnimation { 
                                to: 0.6 + (Math.random() * 0.2)
                                duration: 300 + (index * 40)
                                easing.type: Easing.InOutSine 
                            }
                            // Quick rise (next syllable)
                            NumberAnimation { 
                                to: 1.2 + (Math.abs(3 - index) * 0.1)
                                duration: 350 + (index * 25)
                                easing.type: Easing.OutCubic 
                            }
                            // Settle
                            NumberAnimation { 
                                to: 1.0
                                duration: 400 + (index * 35)
                                easing.type: Easing.InOutQuad 
                            }
                        }
                    }
                }
            }

            // Center "><" symbol
            Text {
                id: centerSymbol
                anchors.centerIn: parent
                text: "><"
                font.pixelSize: 48
                font.bold: true
                font.family: "monospace"
                color: "#cba6f7"
                style: Text.Outline
                styleColor: "#89b4fa"
                
                SequentialAnimation on opacity {
                    running: root.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.7; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                }
            }

            // Right wave bars
            Row {
                anchors.left: centerSymbol.right
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Repeater {
                    model: 6
                    
                    Rectangle {
                        // Voice-like height pattern (mirrored)
                        property real baseHeight: [40, 65, 90, 100, 75, 50][index]
                        property real currentMultiplier: 1.0
                        
                        width: 8
                        height: baseHeight * currentMultiplier
                        radius: 2.5
                        anchors.verticalCenter: parent.verticalCenter
                        
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: ["#f5c2e7", "#b4befe", "#94e2d5", "#89b4fa", "#cba6f7", "#f38ba8"][index] }
                            GradientStop { position: 1.0; color: ["#fbcfe8", "#c4b5fd", "#99f6e4", "#93c5fd", "#d8b4fe", "#f9a8d4"][index] }
                        }
                        
                        opacity: 0.95

                        // Coordinated voice-like animation (slightly offset from left)
                        SequentialAnimation on currentMultiplier {
                            running: root.active
                            loops: Animation.Infinite
                            
                            // Small delay to create flow effect
                            PauseAnimation { duration: index * 15 }
                            
                            // Rise
                            NumberAnimation { 
                                to: 1.5 + (Math.abs(2 - index) * 0.15)
                                duration: 400 + (index * 30)
                                easing.type: Easing.OutQuad 
                            }
                            // Hold
                            PauseAnimation { duration: 100 + (index * 20) }
                            // Drop
                            NumberAnimation { 
                                to: 0.6 + (Math.random() * 0.2)
                                duration: 300 + (index * 40)
                                easing.type: Easing.InOutSine 
                            }
                            // Quick rise
                            NumberAnimation { 
                                to: 1.2 + (Math.abs(2 - index) * 0.1)
                                duration: 350 + (index * 25)
                                easing.type: Easing.OutCubic 
                            }
                            // Settle
                            NumberAnimation { 
                                to: 1.0
                                duration: 400 + (index * 35)
                                easing.type: Easing.InOutQuad 
                            }
                        }
                    }
                }
            }

            // Instant snap-in animation
            scale: root.active ? 1.0 : 0.5
            opacity: root.active ? 1.0 : 0
            
            Behavior on scale {
                NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
            }
            Behavior on opacity {
                NumberAnimation { duration: 60 }
            }
        }
    }
}
