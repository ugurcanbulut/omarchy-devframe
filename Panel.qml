import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Bar button + popup that sizes the browser on the active workspace to a
// device window size. The sibling `devframe` script does the window work;
// this file only picks the preset and passes the switches along.
Panel {
  id: root
  moduleName: "ugurcanbulut.devframe"
  ipcTarget: "ugurcanbulut.devframe"

  property bool incognito: false
  property bool devtools: false
  // Keyboard cursor over presets, the workspace grid, the incognito and
  // DevTools switches, then reset. -1 until the first arrow/j/k press.
  property int cursorIndex: -1

  readonly property string script: decodeURIComponent(Qt.resolvedUrl("devframe").toString().replace(/^file:\/\//, ""))

  // Logical (CSS pixel) sizes; the whole browser window gets this size.
  readonly property var presets: [
    { group: "DESKTOP", icon: 0xF0379, label: "Full HD", width: 1920, height: 1080 },
    { group: "DESKTOP", icon: 0xF0322, label: "MacBook Pro 16\"", width: 1728, height: 1117 },
    { group: "DESKTOP", icon: 0xF0322, label: "MacBook Pro 14\"", width: 1512, height: 982 },
    { group: "TABLET", icon: 0xF04F6, label: "iPad landscape", width: 1180, height: 820 },
    { group: "TABLET", icon: 0xF04F6, label: "iPad portrait", width: 820, height: 1180 },
    { group: "TABLET", icon: 0xF04F6, label: "iPad Pro 13\" landscape", width: 1376, height: 1032 },
    { group: "TABLET", icon: 0xF04F6, label: "iPad Pro 13\" portrait", width: 1032, height: 1376 },
    { group: "PHONE", icon: 0xF011C, label: "iPhone 16 Pro", width: 402, height: 874 },
    { group: "PHONE", icon: 0xF011C, label: "iPhone 16 Pro Max", width: 440, height: 956 }
  ]
  readonly property int workspaceCount: 10
  readonly property int workspaceColumns: 5
  readonly property int workspaceStart: presets.length
  readonly property int incognitoIndex: workspaceStart + workspaceCount
  readonly property int devtoolsIndex: incognitoIndex + 1
  readonly property int resetIndex: incognitoIndex + 2

  function glyph(codePoint) { return String.fromCodePoint(codePoint) }

  function run(args) {
    root.close()
    Quickshell.execDetached([root.script].concat(args))
  }

  function applyPreset(preset) {
    var args = [String(preset.width), String(preset.height)]
    if (root.incognito) args.push("--incognito")
    if (root.devtools) args.push("--devtools")
    run(args)
  }

  function activate(index) {
    if (index >= 0 && index < presets.length) applyPreset(presets[index])
    else if (index >= workspaceStart && index < incognitoIndex) run(["move", String(index - workspaceStart + 1)])
    else if (index === incognitoIndex) root.incognito = !root.incognito
    else if (index === devtoolsIndex) root.devtools = !root.devtools
    else if (index === resetIndex) run(["reset"])
  }

  // Everything is one vertical list except the workspace grid, where h/l move
  // along a row and j/k between its two rows.
  function moveCursor(dx, dy) {
    if (cursorIndex < 0) { cursorIndex = 0; return }
    var cell = cursorIndex - workspaceStart
    var inGrid = cell >= 0 && cell < workspaceCount
    var next
    if (inGrid && dx !== 0) next = workspaceStart + Math.max(0, Math.min(workspaceCount - 1, cell + dx))
    else if (inGrid && dy > 0 && cell < workspaceColumns) next = cursorIndex + workspaceColumns
    else if (inGrid && dy < 0 && cell >= workspaceColumns) next = cursorIndex - workspaceColumns
    else if (inGrid) next = dy > 0 ? incognitoIndex : workspaceStart - 1
    else next = cursorIndex + (dy !== 0 ? dy : dx)
    cursorIndex = Math.max(0, Math.min(resetIndex, next))
  }

  onOpenedChanged: if (opened) cursorIndex = -1

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // md-incognito while the switch is on, md-monitor-cellphone otherwise.
    text: root.glyph(root.incognito ? 0xF05F9 : 0xF0989)
    tooltipText: "Devframe" + (root.incognito ? " · incognito" : "") + (root.devtools ? " · DevTools" : "")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.incognito = !root.incognito
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activate(root.cursorIndex)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      // 1-9 pick a preset directly, i flips incognito, d flips DevTools,
      // r resets.
      onTextKey: function(t) {
        var n = parseInt(t)
        if (n >= 1 && n <= root.presets.length) root.applyPreset(root.presets[n - 1])
        else if (t === "i") root.incognito = !root.incognito
        else if (t === "d") root.devtools = !root.devtools
        else if (t === "r") root.activate(root.resetIndex)
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(2)

        Repeater {
          model: root.presets

          Column {
            id: presetRow
            required property var modelData
            required property int index
            readonly property bool firstInGroup: index === 0 || root.presets[index - 1].group !== modelData.group

            width: column.width
            spacing: Style.space(4)
            topPadding: firstInGroup && index > 0 ? Style.space(8) : 0

            PanelSectionHeader {
              visible: presetRow.firstInGroup
              text: presetRow.modelData.group
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            Button {
              width: parent.width
              leftAlign: true
              iconText: root.glyph(presetRow.modelData.icon)
              text: presetRow.modelData.label
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              hasCursor: root.cursorIndex === presetRow.index
              onClicked: root.applyPreset(presetRow.modelData)
              onHovered: function(h) { if (h) root.cursorIndex = presetRow.index }

              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.controlPaddingX
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: presetRow.modelData.width + " × " + presetRow.modelData.height
                color: root.bar.foreground
                opacity: 0.6
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }

        Item { width: 1; height: Style.space(10) }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Item { width: 1; height: Style.space(10) }

        PanelSectionHeader {
          text: "WORKSPACE"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Item { width: 1; height: Style.space(4) }

        // Moves the browser and its DevTools there, and follows them.
        Grid {
          id: workspaceGrid
          width: parent.width
          columns: root.workspaceColumns
          spacing: Style.space(6)

          readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

          Repeater {
            model: root.workspaceCount

            Button {
              required property int index
              readonly property int workspace: index + 1

              width: workspaceGrid.cellWidth
              text: String(workspace)
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              bordered: true
              active: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspace
              hasCursor: root.cursorIndex === root.workspaceStart + index
              onClicked: root.activate(root.workspaceStart + index)
              onHovered: function(h) { if (h) root.cursorIndex = root.workspaceStart + index }
            }
          }
        }

        Item { width: 1; height: Style.space(12) }

        Toggle {
          width: parent.width
          label: "Incognito"
          description: "Open the current page in a new private window"
          checked: root.incognito
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          hasCursor: root.cursorIndex === root.incognitoIndex
          onClicked: root.incognito = !root.incognito
          onHovered: function(h) { if (h) root.cursorIndex = root.incognitoIndex }
        }

        Item { width: 1; height: Style.space(4) }

        Toggle {
          width: parent.width
          label: "DevTools"
          description: "Open DevTools in its own window beside the browser"
          checked: root.devtools
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          hasCursor: root.cursorIndex === root.devtoolsIndex
          onClicked: root.devtools = !root.devtools
          onHovered: function(h) { if (h) root.cursorIndex = root.devtoolsIndex }
        }

        Item { width: 1; height: Style.space(4) }

        Button {
          width: parent.width
          leftAlign: true
          iconText: root.glyph(0xF05B2) // md-window-restore
          text: "Reset window"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          hasCursor: root.cursorIndex === root.resetIndex
          onClicked: root.activate(root.resetIndex)
          onHovered: function(h) { if (h) root.cursorIndex = root.resetIndex }
        }
      }
    }
  }
}
