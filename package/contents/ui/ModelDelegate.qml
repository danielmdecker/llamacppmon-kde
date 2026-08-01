import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: delegate

    property var backend

    // Roles provided by the ListModel in main.qml.
    required property string name
    required property string modelState
    required property int port
    required property double vramKb
    required property double ramKb
    required property bool memKnown

    implicitHeight: Kirigami.Units.gridUnit * 2.5

    readonly property bool ready: modelState === "ready"
    readonly property bool starting: modelState === "starting"
    readonly property bool stopping: modelState === "stopping"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // status indicator dot
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Kirigami.Units.gridUnit * 0.6
            implicitHeight: Kirigami.Units.gridUnit * 0.6
            radius: width / 2
            color: delegate.ready ? Kirigami.Theme.positiveTextColor
                 : delegate.starting ? Kirigami.Theme.neutralTextColor
                 : Kirigami.Theme.disabledTextColor
        }

        // name + memory footprint
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: delegate.name
                elide: Text.ElideRight
                font.weight: Font.Bold
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                text: delegate.starting ? i18n("Loading…")
                    : delegate.stopping ? i18n("Unloading…")
                    : delegate.memKnown ? i18n("VRAM %1 · RAM %2",
                                               delegate.backend.formatKb(delegate.vramKb),
                                               delegate.backend.formatKb(delegate.ramKb))
                    : delegate.modelState
            }
        }

        // unload action (icon rendered as a recolorable mask, so the semantic
        // tint applies consistently regardless of the icon theme)
        PlasmaComponents.ToolButton {
            id: unloadButton
            display: QQC2.AbstractButton.IconOnly
            enabled: !delegate.stopping
            onClicked: delegate.backend.unloadModel(delegate.name)
            QQC2.ToolTip.text: i18n("Unload from VRAM/RAM")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

            contentItem: Kirigami.Icon {
                source: Qt.resolvedUrl("../icons/action-unload.svg")
                isMask: true
                color: unloadButton.enabled ? Kirigami.Theme.negativeTextColor
                                            : Kirigami.Theme.disabledTextColor
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
            }
        }
    }
}
