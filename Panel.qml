import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar button + popup that sizes the browser on the active workspace to a
// device window size. The sibling `devframe` script does the window work;
// this file only picks the preset and passes the switches along.
Panel {
  id: root
  moduleName: "ugurcanbulut.devframe"
  ipcTarget: "ugurcanbulut.devframe"

  // The switches live on this widget's shell.json entry, so they survive bar
  // restarts; loadSwitches() keeps them in step with that entry.
  property bool incognito: false
  // When on, presets open the page alone in a toolbar-less window, like phones.
  property bool hideToolbar: false
  property bool devtools: false
  property string devtoolsSide: "right"
  readonly property var devtoolsSides: [
    { value: "left", label: "Left" },
    { value: "right", label: "Right" },
    { value: "below", label: "Below" }
  ]

  // Size of the floating browser the script would act on, from
  // `devframe status`; null when there is none.
  property var activeWindow: null

  // Keyboard cursor over presets, the workspace grid, the incognito and
  // DevTools switches (and DevTools side while it is on), then rotate,
  // screenshot and reset. -1 until the first arrow/j/k press.
  property int cursorIndex: -1

  readonly property string script: decodeURIComponent(Qt.resolvedUrl("devframe").toString().replace(/^file:\/\//, ""))

  // Logical (CSS pixel) sizes; the whole browser window gets this size.
  readonly property var builtInPresets: [
    { group: "DESKTOP", icon: 0xF0379, label: "Full HD", width: 1920, height: 1080 },
    { group: "DESKTOP", icon: 0xF0322, label: "MacBook Pro 16\"", width: 1728, height: 1117 },
    { group: "DESKTOP", icon: 0xF0322, label: "MacBook Pro 14\"", width: 1512, height: 982 },
    { group: "DESKTOP", icon: 0xF0322, label: "HD laptop", width: 1366, height: 768 },
    { group: "TABLET", icon: 0xF04F6, label: "iPad landscape", width: 1180, height: 820 },
    { group: "TABLET", icon: 0xF04F6, label: "iPad portrait", width: 820, height: 1180 },
    { group: "TABLET", icon: 0xF04F6, label: "iPad Pro 13\" landscape", width: 1376, height: 1032 },
    { group: "TABLET", icon: 0xF04F6, label: "iPad Pro 13\" portrait", width: 1032, height: 1376 },
    { group: "TABLET", icon: 0xF04F6, label: "iPad mini portrait", width: 744, height: 1133 },
    { group: "PHONE", icon: 0xF011C, label: "iPhone 16 Pro", width: 402, height: 874 },
    { group: "PHONE", icon: 0xF011C, label: "iPhone 16 Pro Max", width: 440, height: 956 },
    { group: "PHONE", icon: 0xF011C, label: "iPhone 16e", width: 390, height: 844 },
    { group: "PHONE", icon: 0xF011C, label: "iPhone SE", width: 375, height: 667 },
    { group: "PHONE", icon: 0xF011C, label: "Pixel 9", width: 412, height: 923 },
    { group: "PHONE", icon: 0xF011C, label: "Galaxy S25", width: 360, height: 780 }
  ]

  function loadSwitches() {
    incognito = setting("incognito", false) === true
    hideToolbar = setting("hideToolbar", false) === true
    devtools = setting("devtools", false) === true
    var side = setting("devtoolsSide", "right")
    devtoolsSide = ["left", "right", "below"].indexOf(side) >= 0 ? side : "right"
  }

  // Set one switch and write it to this widget's shell.json entry, keeping
  // the entry's other settings (custom presets and so on).
  function saveSwitch(name, value) {
    root[name] = value
    var next = Object.assign({}, root.settings || {})
    next[name] = value
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, next)
  }

  function cycleDevtoolsSide(delta) {
    var values = devtoolsSides.map(function(side) { return side.value })
    var index = (values.indexOf(devtoolsSide) + delta + values.length) % values.length
    saveSwitch("devtoolsSide", values[index])
  }

  function refreshStatus() {
    if (!statusProc.running) statusProc.running = true
  }

  function isActive(preset) {
    return !!activeWindow && activeWindow.width === preset.width && activeWindow.height === preset.height
  }

  Component.onCompleted: loadSwitches()
  onSettingsChanged: loadSwitches()

  Process {
    id: statusProc
    command: [root.script, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = null
        try { parsed = JSON.parse(text || "{}") } catch (e) {}
        root.activeWindow = parsed && parsed.width ? parsed : null
      }
    }
  }

  // Built-ins plus the `presets` list on this widget's shell.json entry, e.g.
  // { "label": "Pixel 9", "width": 412, "height": 915, "group": "PHONE" }.
  // A custom preset joins its group's section, or starts a new one at the
  // end; `builtInPresets: false` shows only the custom ones.
  readonly property var presets: {
    var custom = setting("presets", [])
    var all = (setting("builtInPresets", true) === false ? [] : builtInPresets)
      .concat((Array.isArray(custom) ? custom : []).map(customPreset).filter(Boolean))
    var groups = []
    all.forEach(function(preset) { if (groups.indexOf(preset.group) < 0) groups.push(preset.group) })
    return groups.reduce(function(sorted, group) {
      return sorted.concat(all.filter(function(preset) { return preset.group === group }))
    }, [])
  }

  readonly property var groupIcons: ({ DESKTOP: 0xF0379, LAPTOP: 0xF0322, TABLET: 0xF04F6, PHONE: 0xF011C })

  // Skips entries without a sensible size rather than failing on them.
  function customPreset(entry) {
    if (!entry || typeof entry !== "object") return null
    var width = Math.round(Number(entry.width))
    var height = Math.round(Number(entry.height))
    if (!(width >= 100 && width <= 10000 && height >= 100 && height <= 10000)) return null
    var group = String(entry.group || "CUSTOM").toUpperCase()
    return {
      group: group,
      icon: groupIcons[group] || groupIcons.DESKTOP,
      label: entry.label ? String(entry.label) : width + " × " + height,
      width: width,
      height: height
    }
  }

  readonly property int workspaceCount: 10
  readonly property int workspaceColumns: 5
  readonly property int workspaceStart: presets.length
  readonly property int incognitoIndex: workspaceStart + workspaceCount
  readonly property int toolbarIndex: incognitoIndex + 1
  readonly property int devtoolsIndex: incognitoIndex + 2
  // The side row only exists while DevTools is on.
  readonly property int sideIndex: devtools ? devtoolsIndex + 1 : -1
  readonly property int rotateIndex: devtoolsIndex + (devtools ? 2 : 1)
  readonly property int screenshotIndex: rotateIndex + 1
  readonly property int resetIndex: rotateIndex + 2

  // Free area of the focused monitor in logical pixels, minus the bar. The
  // script works on the same monitor.
  readonly property var freeArea: {
    var monitor = Hyprland.focusedMonitor
    if (!monitor || !monitor.scale) return null
    var reserved = (monitor.lastIpcObject && monitor.lastIpcObject.reserved) || [0, 0, 0, 0]
    return {
      width: Math.floor(monitor.width / monitor.scale) - reserved[0] - reserved[2],
      height: Math.floor(monitor.height / monitor.scale) - reserved[1] - reserved[3]
    }
  }

  // With DevTools on, the preset also needs room for the smallest DevTools
  // beside it (the script's GAP + MIN_DEVTOOLS_WIDTH) or below it
  // (GAP + MIN_DEVTOOLS_HEIGHT).
  function fits(preset) {
    if (!freeArea) return true
    var below = root.devtools && root.devtoolsSide === "below"
    var width = preset.width + (root.devtools && !below ? 410 : 0)
    var height = preset.height + (below ? 260 : 0)
    return width <= freeArea.width && height <= freeArea.height
  }

  function glyph(codePoint) { return String.fromCodePoint(codePoint) }

  function ensureVisible(item) {
    var top = item.mapToItem(column, 0, 0).y
    var bottom = top + item.height
    var margin = Style.space(8)
    if (top < scroller.contentY + margin) scroller.contentY = Math.max(0, top - margin)
    else if (bottom > scroller.contentY + scroller.height - margin)
      scroller.contentY = Math.min(scroller.contentHeight - scroller.height, bottom + margin - scroller.height)
  }

  function run(args) {
    root.close()
    Quickshell.execDetached([root.script].concat(args))
  }

  function applyPreset(preset) {
    var args = [String(preset.width), String(preset.height)]
    if (root.incognito) args.push("--incognito")
    if (root.hideToolbar) args.push("--no-toolbar")
    if (root.devtools) args.push("--devtools=" + root.devtoolsSide)
    run(args)
  }

  function activate(index) {
    if (index >= 0 && index < presets.length) applyPreset(presets[index])
    else if (index >= workspaceStart && index < incognitoIndex) run(["move", String(index - workspaceStart + 1)])
    else if (index === incognitoIndex) saveSwitch("incognito", !root.incognito)
    else if (index === toolbarIndex) saveSwitch("hideToolbar", !root.hideToolbar)
    else if (index === devtoolsIndex) saveSwitch("devtools", !root.devtools)
    else if (index === sideIndex) cycleDevtoolsSide(1)
    else if (index === rotateIndex) run(["rotate"])
    else if (index === screenshotIndex) run(["screenshot"])
    else if (index === resetIndex) run(["reset"])
  }

  // Everything is one vertical list except the workspace grid, where h/l move
  // along a row and j/k between its two rows, and the DevTools side row,
  // where h/l pick the side.
  function moveCursor(dx, dy) {
    if (cursorIndex < 0) { cursorIndex = 0; return }
    if (cursorIndex === sideIndex && dx !== 0) { cycleDevtoolsSide(dx); return }
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

  onOpenedChanged: {
    if (!opened) return
    cursorIndex = -1
    scroller.contentY = 0
    Hyprland.refreshMonitors()
    refreshStatus()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // md-incognito while the switch is on, md-monitor-cellphone otherwise.
    text: root.glyph(root.incognito ? 0xF05F9 : 0xF0989)
    tooltipText: "Devframe"
      + (root.activeWindow ? " · " + root.activeWindow.width + "×" + root.activeWindow.height : "")
      + (root.incognito ? " · incognito" : "")
      + (root.hideToolbar ? " · no toolbar" : "")
      + (root.devtools ? " · DevTools " + root.devtoolsSide : "")
    // Refresh the size shown in the tooltip each time the pointer arrives.
    onTooltipHoveredChanged: if (tooltipHovered) root.refreshStatus()
    onPressed: function(b) {
      if (b === Qt.RightButton) root.saveSwitch("incognito", !root.incognito)
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
      // 1-9 pick a preset directly, i flips incognito, t the toolbar,
      // d DevTools, o rotates, s takes a screenshot, r resets.
      onTextKey: function(t) {
        var n = parseInt(t)
        if (n >= 1 && n <= root.presets.length) root.applyPreset(root.presets[n - 1])
        else if (t === "i") root.activate(root.incognitoIndex)
        else if (t === "t") root.activate(root.toolbarIndex)
        else if (t === "d") root.activate(root.devtoolsIndex)
        else if (t === "o") root.activate(root.rotateIndex)
        else if (t === "s") root.activate(root.screenshotIndex)
        else if (t === "r") root.activate(root.resetIndex)
      }

      // Scrolls when the popup is taller than the screen allows.
      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: scroller.width
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
                readonly property bool fits: root.fits(presetRow.modelData)

                width: parent.width
                leftAlign: true
                iconText: root.glyph(presetRow.modelData.icon)
                text: presetRow.modelData.label
                // Still usable, but dimmed when it won't fit on this screen.
                opacity: fits ? 1 : 0.45
                tooltipText: fits ? "" : "Bigger than this screen"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                // Marks the size the browser is at right now.
                active: root.isActive(presetRow.modelData)
                hasCursor: root.cursorIndex === presetRow.index
                onClicked: root.applyPreset(presetRow.modelData)
                onHovered: function(h) { if (h) root.cursorIndex = presetRow.index }
                onHasCursorChanged: if (hasCursor) root.ensureVisible(this)

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
                onHasCursorChanged: if (hasCursor) root.ensureVisible(this)
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
            onClicked: root.activate(root.incognitoIndex)
            onHovered: function(h) { if (h) root.cursorIndex = root.incognitoIndex }
            onHasCursorChanged: if (hasCursor) root.ensureVisible(this)
          }

          Item { width: 1; height: Style.space(4) }

          Toggle {
            width: parent.width
            label: "Hide toolbar"
            description: "Show only the page, without tabs and address bar"
            checked: root.hideToolbar
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            hasCursor: root.cursorIndex === root.toolbarIndex
            onClicked: root.activate(root.toolbarIndex)
            onHovered: function(h) { if (h) root.cursorIndex = root.toolbarIndex }
            onHasCursorChanged: if (hasCursor) root.ensureVisible(this)
          }

          Item { width: 1; height: Style.space(4) }

          Toggle {
            width: parent.width
            label: "DevTools"
            description: "Open DevTools in its own window next to the browser"
            checked: root.devtools
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            hasCursor: root.cursorIndex === root.devtoolsIndex
            onClicked: root.activate(root.devtoolsIndex)
            onHovered: function(h) { if (h) root.cursorIndex = root.devtoolsIndex }
            onHasCursorChanged: if (hasCursor) root.ensureVisible(this)
          }

          // Where DevTools goes; one keyboard stop, h/l pick the side.
          Row {
            id: sideRow
            visible: root.devtools
            width: parent.width
            topPadding: Style.space(4)
            spacing: Style.space(6)

            readonly property real cellWidth: (width - spacing * (root.devtoolsSides.length - 1)) / root.devtoolsSides.length

            Repeater {
              model: root.devtoolsSides

              Button {
                required property var modelData

                width: sideRow.cellWidth
                text: modelData.label
                tooltipText: "DevTools " + (modelData.value === "below" ? "below" : "to the " + modelData.value + " of") + " the browser"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                bordered: true
                selected: root.devtoolsSide === modelData.value
                hasCursor: root.cursorIndex === root.sideIndex && selected
                onClicked: root.saveSwitch("devtoolsSide", modelData.value)
                onHovered: function(h) { if (h) root.cursorIndex = root.sideIndex }
                onHasCursorChanged: if (hasCursor) root.ensureVisible(this)
              }
            }
          }

          Item { width: 1; height: Style.space(4) }

          Row {
            id: actionRow
            width: parent.width
            spacing: Style.space(6)

            readonly property real cellWidth: (width - spacing * 2) / 3

            Button {
              width: actionRow.cellWidth
              iconText: root.glyph(0xF0475) // md-screen-rotation
              text: "Rotate"
              tooltipText: "Swap portrait and landscape"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              hasCursor: root.cursorIndex === root.rotateIndex
              onClicked: root.activate(root.rotateIndex)
              onHovered: function(h) { if (h) root.cursorIndex = root.rotateIndex }
              onHasCursorChanged: if (hasCursor) root.ensureVisible(this)
            }

            Button {
              width: actionRow.cellWidth
              iconText: root.glyph(0xF0100) // md-camera
              text: "Capture"
              tooltipText: "Screenshot the browser window"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              hasCursor: root.cursorIndex === root.screenshotIndex
              onClicked: root.activate(root.screenshotIndex)
              onHovered: function(h) { if (h) root.cursorIndex = root.screenshotIndex }
              onHasCursorChanged: if (hasCursor) root.ensureVisible(this)
            }

            Button {
              width: actionRow.cellWidth
              iconText: root.glyph(0xF05B2) // md-window-restore
              text: "Reset"
              tooltipText: "Tile the window back and close its DevTools"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              hasCursor: root.cursorIndex === root.resetIndex
              onClicked: root.activate(root.resetIndex)
              onHovered: function(h) { if (h) root.cursorIndex = root.resetIndex }
              onHasCursorChanged: if (hasCursor) root.ensureVisible(this)
            }
          }
        }
      }
    }
  }
}
