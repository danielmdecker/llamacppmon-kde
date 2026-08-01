import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configPage

    // The plasmoid config system loads/saves these `cfg_<key>` properties automatically.
    property alias cfg_serverUrl: serverField.text
    property alias cfg_refreshInterval: refreshSpin.value
    property alias cfg_idleRefreshInterval: idleSpin.value

    Kirigami.FormLayout {
        QQC2.TextField {
            id: serverField
            Kirigami.FormData.label: i18n("Server URL:")
            placeholderText: "http://127.0.0.1:8090"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: refreshSpin
            Kirigami.FormData.label: i18n("Refresh interval (popup open):")
            from: 1
            to: 3600
            editable: true
            textFromValue: function (value) {
                return i18np("%1 second", "%1 seconds", value)
            }
            valueFromText: function (text) {
                return parseInt(text, 10)
            }
        }

        QQC2.SpinBox {
            id: idleSpin
            Kirigami.FormData.label: i18n("Refresh interval (popup closed):")
            from: 5
            to: 3600
            editable: true
            textFromValue: function (value) {
                return i18np("%1 second", "%1 seconds", value)
            }
            valueFromText: function (text) {
                return parseInt(text, 10)
            }
        }
    }
}
