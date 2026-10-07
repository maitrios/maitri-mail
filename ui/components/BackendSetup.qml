import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  required property var runtime
  required property color textColor
  required property color dimColor
  required property color accentColor
  required property string panelFontFamily
  property string backendError: ""
  property bool diagnosisAvailable: false
  property bool diagnosing: false
  signal diagnosisRequested()
  spacing: Style.space(12)
  onVisibleChanged: {
    if (visible && runtime && !runtime.busy && typeof runtime.refresh === "function") runtime.refresh()
  }
  MaitriMailLogo {
    foreground: root.dimColor
    accent: root.accentColor
  }
  Text {
    text: "Mail backend"
    color: root.textColor
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.heading
  }
  Row {
    width: parent.width
    height: Math.max(versionLabel.height, checkButton.height)
    spacing: Style.space(8)
    Text {
      id: versionLabel
      objectName: "backend-version-label"
      width: Math.min(implicitWidth, Math.max(0, parent.width - checkButton.width - parent.spacing))
      y: (parent.height - height) / 2
      wrapMode: Text.WordWrap
      text: !root.runtime ? "Checking the mail backend"
        : root.runtime.busy ? "Working"
        : root.runtime.state === "ready" ? (root.runtime.bundled
          ? "Bundled backend " + root.runtime.installedVersion + " is ready."
          : "Backend " + root.runtime.installedVersion + " is installed.")
        : root.runtime.bundled ? "The bundled mail backend could not start."
        : "Mail needs backend " + (root.runtime.requiredVersion || "matching this plugin")
          + (root.runtime.installedVersion ? ". Installed: " + root.runtime.installedVersion : ". It is not installed yet.")
      color: root.dimColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.body
    }
    Button {
      id: checkButton
      objectName: "backend-refresh"
      y: (parent.height - height) / 2
      bordered: false
      accent: root.accentColor
      fontFamily: root.panelFontFamily
      text: root.runtime && root.runtime.bundled ? "Retry" : "Check"
      enabled: !!root.runtime && !root.runtime.busy
      foreground: root.textColor
      onClicked: root.runtime.refresh()
    }
  }
  Text {
    width: parent.width
    wrapMode: Text.WordWrap
    text: root.runtime && root.runtime.bundled
      ? "Included with this app. Reinstall this version if the bundled backend is missing or damaged."
      : root.runtime && root.runtime.development
      ? "Development executable: " + root.runtime.developmentExecutable + ". Build the required version, then check again."
      : "Required for the app’s mail features. maitri installs it with the maitri-mail package."
    color: root.dimColor
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.body
  }
  Text {
    width: parent.width
    visible: text !== ""
    wrapMode: Text.WordWrap
    text: root.runtime && root.runtime.error ? root.runtime.error : root.backendError
    color: root.textColor
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.body
  }
  Flow {
    width: parent.width
    spacing: Style.space(8)
    IconButton {
      objectName: "backend-diagnose"
      visible: root.diagnosisAvailable
      enabled: !root.diagnosing
      iconName: "agent"
      iconSize: Style.font.iconSmall
      size: Style.space(24)
      tooltipText: "Diagnose with AI..."
      Accessible.role: Accessible.Button
      Accessible.name: "Diagnose with AI..."
      foreground: root.textColor
      accent: root.accentColor
      fontFamily: root.panelFontFamily
      onClicked: root.diagnosisRequested()
    }
  }
}
