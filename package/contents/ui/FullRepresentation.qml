import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: fullRep

    property var backend

    // Size hints read by the Plasma popup.
    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 18
    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: Kirigami.Units.gridUnit * 18

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // ---- header: title, refresh ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: i18n("Llama.cpp")
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                text: i18n("Refresh")
                onClicked: fullRep.backend.refresh()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        // ---- error banner ----
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            text: fullRep.backend.errorText
            visible: fullRep.backend.errorText.length > 0
        }

        // ---- memory overview: available / total VRAM and RAM ----
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Kirigami.Units.smallSpacing * 2
            rowSpacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18n("VRAM")
                font.weight: Font.Bold
            }
            PlasmaComponents.ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, fullRep.backend.vramTotalKb)
                value: fullRep.backend.vramUsedKb
            }
            PlasmaComponents.Label {
                text: fullRep.backend.vramTotalKb > 0
                    ? i18n("%1 free of %2",
                           fullRep.backend.formatKb(fullRep.backend.vramAvailKb),
                           fullRep.backend.formatKb(fullRep.backend.vramTotalKb))
                    : i18n("unavailable")
                opacity: 0.7
            }

            PlasmaComponents.Label {
                text: i18n("RAM")
                font.weight: Font.Bold
            }
            PlasmaComponents.ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, fullRep.backend.ramTotalKb)
                value: fullRep.backend.ramTotalKb - fullRep.backend.ramAvailKb
            }
            PlasmaComponents.Label {
                text: fullRep.backend.ramTotalKb > 0
                    ? i18n("%1 free of %2",
                           fullRep.backend.formatKb(fullRep.backend.ramAvailKb),
                           fullRep.backend.formatKb(fullRep.backend.ramTotalKb))
                    : i18n("unavailable")
                opacity: 0.7
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ---- loaded model list ----
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: listView
                clip: true
                model: fullRep.backend.listModel
                boundsBehavior: Flickable.StopAtBounds

                delegate: ModelDelegate {
                    width: listView.width
                    backend: fullRep.backend
                }

                // Empty state. Built from primitives rather than
                // Kirigami.PlaceholderMessage, which can fail to load inside a
                // running Plasma session (IconPropertiesGroup type conflict).
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Kirigami.Units.gridUnit * 2,
                                    Kirigami.Units.gridUnit * 16)
                    spacing: Kirigami.Units.smallSpacing
                    visible: listView.count === 0 && fullRep.backend.errorText.length === 0

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Kirigami.Units.iconSizes.large
                        implicitHeight: Kirigami.Units.iconSizes.large
                        source: fullRep.backend.llamaIcon
                        opacity: 0.5
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                        text: i18n("No models loaded")
                    }
                }
            }
        }
    }

    Component.onCompleted: backend.refresh()
}
