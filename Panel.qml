import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Four daily injection checks on the bar.
//
// Saved flags belong to a local calendar day. The bar treats any other day
// as not done, so yesterday's checks never look finished this morning.
// The saved flags themselves clear the first time the panel opens that day.
Panel {
  id: root
  moduleName: "peterm.injections"
  ipcTarget: "peterm.injections"

  readonly property string homeDir: Quickshell.env("HOME") || ""
  readonly property string stateDir: {
    var base = Quickshell.env("XDG_STATE_HOME")
    if (!base) base = homeDir + "/.local/state"
    return base + "/omarchy/injections"
  }
  readonly property string statePath: stateDir + "/doses.json"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string storedDate: ""
  property var doses: Model.emptyDoses()
  property bool stateReady: false
  property bool mkdirDone: false
  property double dayTick: 0
  property int selectedIndex: 0
  property bool cursorActive: false

  // dayTick and the minute clock are what wake this up after midnight.
  // The value is always the real local day at evaluation time.
  readonly property string todayKey: {
    var refresh = dayTick + (clock.date ? 1 : 0)
    return Model.localDay(refresh >= 0 ? new Date() : new Date())
  }
  readonly property var enabledIndices: Model.enabledIndices(settings)
  readonly property int enabledCount: enabledIndices.length
  readonly property int shownCount: Model.shownCount(storedDate, doses, todayKey, settings)
  readonly property string barTooltip: Model.tooltip(storedDate, doses, todayKey, settings)
  readonly property string statusLine: {
    var when = clock.date ? Qt.formatDate(clock.date, "dddd d MMMM") : todayKey
    var total = enabledCount
    if (total <= 0) return when + " · none configured"
    if (shownCount <= 0) return when + " · none yet"
    if (shownCount >= total) return when + (total === 4 ? " · all four done" : " · all done")
    return when + " · " + shownCount + " of " + total
  }

  // "doses" is the checklist. "settings" is the rename / enable panel.
  property string page: "doses"
  // "dose" walks the checklist. "settings" is the link under it.
  property string cursorRow: "dose"
  property int settingsIndex: 0
  property bool editingName: false
  property bool returnPressed: false

  function applyLoaded(raw) {
    var parsed = Model.parseState(raw)
    storedDate = parsed.date
    doses = parsed.doses
    stateReady = true
    // A panel left open across midnight clears when this instance reloads
    // the file. A check saved by the widget on another monitor just updates
    // the switches; same-day state is kept.
    if (opened) rollDay()
  }

  function rollDay() {
    if (!stateReady) return
    var today = Model.localDay(new Date())
    dayTick = Date.now()
    var next = Model.stateOnOpen(storedDate, doses, today)
    if (!next.cleared) return
    storedDate = next.date
    doses = next.doses
    save()
  }

  function toggleDose(index) {
    if (!stateReady) return
    var today = Model.localDay(new Date())
    dayTick = Date.now()
    var next = Model.toggleDose(storedDate, doses, today, index)
    storedDate = next.date
    doses = next.doses
    selectedIndex = index
    cursorActive = true
    save()
  }

  function moveCursor(dy) {
    if (dy === 0) return
    var list = enabledIndices
    cursorActive = true
    if (cursorRow === "settings") {
      if (dy < 0 && list.length > 0) {
        cursorRow = "dose"
        selectedIndex = list[list.length - 1]
      }
      return
    }
    var pos = list.indexOf(selectedIndex)
    if (pos < 0) pos = 0
    var next = pos + dy
    if (next < 0) next = 0
    if (list.length === 0 || next >= list.length) {
      cursorRow = "settings"
      return
    }
    selectedIndex = list[next]
  }

  function activateCursor() {
    if (cursorRow === "settings") {
      showSettings()
      return
    }
    toggleDose(selectedIndex)
  }

  function showSettings() {
    editingName = false
    returnPressed = false
    settingsIndex = 0
    page = "settings"
    Qt.callLater(function() {
      root.reloadSettingNames()
      keyCatcher.forceActiveFocus()
    })
  }

  function showDoses() {
    editingName = false
    returnPressed = false
    page = "doses"
    cursorRow = enabledCount > 0 ? "dose" : "settings"
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function moveSettings(dy) {
    if (dy === 0) return
    var next = settingsIndex + dy
    if (next < -1) next = -1
    if (next > 3) next = 3
    settingsIndex = next
  }

  function noteReturn() {
    returnPressed = page === "settings"
  }

  function activateFocused() {
    if (page === "settings") {
      if (returnPressed) {
        returnPressed = false
        editSettingsName()
        return
      }
      if (settingsIndex < 0) showDoses()
      else setSlotEnabled(settingsIndex, !Model.enabledFor(settingsIndex, settings))
      return
    }
    returnPressed = false
    activateCursor()
  }

  function editSettingsName() {
    if (settingsIndex < 0) {
      showDoses()
      return
    }
    var slot = settingsNames.itemAt(settingsIndex)
    if (slot && slot.focusName) slot.focusName()
  }

  function reloadSettingNames() {
    for (var i = 0; i < 4; i++) {
      var slot = settingsNames.itemAt(i)
      if (slot && slot.setName) slot.setName(Model.labelFor(i, settings))
    }
  }

  function persistSettings(values) {
    var entry = { id: moduleName }
    var current = settings || {}
    for (var existing in current) if (existing !== "id") entry[existing] = current[existing]
    for (var key in values) entry[key] = values[key]
    settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
  }

  function commitName(index, raw) {
    var text = String(raw || "").trim()
    if (text === "") text = Model.labelFor(index, null)
    if (text !== Model.labelFor(index, settings)) {
      var values = {}
      values["label" + (index + 1)] = text
      persistSettings(values)
    }
    return text
  }

  // The last enabled point stays on. Turning them all off would leave the
  // bar with nothing to check.
  function setSlotEnabled(index, on) {
    var currently = Model.enabledFor(index, settings)
    if (currently === on) return
    if (!on && enabledCount <= 1) return
    var values = {}
    values["enabled" + (index + 1)] = on
    persistSettings(values)
    if (!on && selectedIndex === index) {
      var list = Model.enabledIndices(settings)
      if (list.length > 0) selectedIndex = list[0]
    }
  }

  function save() {
    if (!stateReady || !mkdirDone) return
    stateFile.setText(Model.serializeState(storedDate, doses))
  }

  onOpenedChanged: {
    if (!opened) {
      editingName = false
      returnPressed = false
      return
    }
    page = "doses"
    rollDay()
    cursorActive = true
    var list = enabledIndices
    cursorRow = list.length > 0 ? "dose" : "settings"
    if (list.length > 0) selectedIndex = list[0]
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.dayTick = Date.now()
      if (root.opened) root.rollDay()
    }
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.stateDir]
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        console.warn("injections: could not create", root.stateDir)
        return
      }
      root.mkdirDone = true
      stateFile.reload()
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    // Each monitor has its own widget. They share this file, so a check on
    // one screen shows up on the others.
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyLoaded(stateFile.text())
    onLoadFailed: {
      if (!root.mkdirDone || root.stateReady) return
      root.applyLoaded("")
    }
    onFileChanged: reload()
  }

  Component.onCompleted: mkdirProc.running = true

  // The portrait HDMI bar is a few hundred pixels wide and already full.
  // A text pill there collides with the clock, so this widget only takes
  // a slot on bars that have room for it.
  readonly property int barSpan: {
    var win = button.QsWindow.window
    if (!win) return 0
    var span = (bar && bar.vertical) ? win.height : win.width
    return span
  }
  readonly property bool cramped: barSpan > 0 && barSpan < 720

  visible: !cramped
  implicitWidth: cramped ? 0 : button.implicitWidth
  implicitHeight: cramped ? 0 : button.implicitHeight
  readonly property real openPanelIndicatorWidth: doseMark.implicitWidth

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    tooltipText: root.barTooltip
    horizontalMargin: 7
    verticalPadding: 6
    fixedWidth: button.vertical ? -1 : doseMark.implicitWidth + button.scaledHorizontalMargin * 2
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
    }

    Row {
      id: doseMark
      anchors.centerIn: parent
      spacing: Style.space(5)

      SyringeIcon {
        id: syringe
        iconSize: Math.max(14, Style.bar.iconFont + 2)
        color: button.foreground
        anchors.verticalCenter: parent.verticalCenter
      }

      // Top dot is the first injection, bottom dot the last.
      // Grey is switched off, blue is still due, green is done.
      Column {
        id: doseDots
        readonly property real dot: Math.max(3, syringe.iconSize * 0.20)
        anchors.verticalCenter: parent.verticalCenter
        spacing: dot * 0.55

        Repeater {
          model: 4

          Rectangle {
            required property int index
            width: doseDots.dot
            height: doseDots.dot
            radius: width / 2
            antialiasing: true
            color: !Model.enabledFor(index, root.settings) ? "#8C8C8C"
              : Model.doseOn(root.storedDate, root.doses, root.todayKey, index) ? "#3DDC84"
              : "#2A5C9E"
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.page === "settings" ? Style.space(400) : Style.space(320))
    contentHeight: panel.fittedContentHeight(root.page === "settings" ? settingsColumn.implicitHeight : column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingName
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (root.page === "settings") root.moveSettings(dy)
        else if (dy !== 0) root.moveCursor(dy)
      }
      onReturnRequested: root.noteReturn()
      onActivateRequested: root.activateFocused()
      onCloseRequested: {
        if (root.page === "settings") root.showDoses()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (root.page === "settings") {
          if (t === "e" || t === "E") root.editSettingsName()
          return
        }
        if (t === "s" || t === "S") root.showSettings()
        else if (t === "1" || t === "2" || t === "3" || t === "4") {
          var list = root.enabledIndices
          var n = Number(t) - 1
          if (n >= 0 && n < list.length) root.toggleDose(list[n])
        }
      }

      Column {
        id: column
        visible: root.page === "doses"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        Column {
          width: parent.width
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: "Injections"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: root.statusLine
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.6
            elide: Text.ElideRight
            width: parent.width
          }
        }

        PanelSeparator { foreground: root.foreground }

        Repeater {
          model: root.enabledIndices

          Toggle {
            required property int modelData
            width: column.width
            label: Model.labelFor(modelData, root.settings)
            checked: Model.doseOn(root.storedDate, root.doses, root.todayKey, modelData)
            hasCursor: root.cursorActive && root.cursorRow === "dose" && root.selectedIndex === modelData
            foreground: root.foreground
            fontFamily: root.fontFamily
            onHovered: function(isHovered) {
              if (!isHovered) return
              root.cursorActive = true
              root.cursorRow = "dose"
              root.selectedIndex = modelData
            }
            onClicked: root.toggleDose(modelData)
          }
        }

        Text {
          visible: root.enabledCount === 0
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: "No injections are switched on."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: "The first open each day clears these."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Button {
          text: "Settings"
          fontFamily: root.fontFamily
          fontSize: Style.font.body
          foreground: root.foreground
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(4)
          hasCursor: root.cursorActive && root.cursorRow === "settings"
          onClicked: root.showSettings()
          onHovered: function(isHovered) {
            if (!isHovered) return
            root.cursorActive = true
            root.cursorRow = "settings"
          }
        }
      }

      Column {
        id: settingsColumn
        visible: root.page === "settings"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(8)

        Button {
          text: "Back"
          fontFamily: root.fontFamily
          fontSize: Style.font.body
          foreground: root.foreground
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(4)
          hasCursor: root.settingsIndex < 0
          onClicked: root.showDoses()
          onHovered: function(isHovered) {
            if (isHovered) root.settingsIndex = -1
          }
        }

        Text {
          textFormat: Text.PlainText
          text: "Injection settings"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Rename a point, or switch off the ones you don't take. Space toggles, Enter renames. At least one stays on."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Repeater {
          id: settingsNames
          model: 4

          Item {
            id: slot
            required property int index
            width: settingsColumn.width
            height: Math.max(nameField.implicitHeight, slotSwitch.implicitHeight)

            function focusName() {
              nameField.forceActiveFocus()
              nameField.selectAll()
            }
            function setName(value) {
              if (!nameField.activeFocus) nameField.text = value
            }

            Text {
              id: slotOrdinal
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(18)
              textFormat: Text.PlainText
              text: String(slot.index + 1)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignRight
            }

            TextField {
              id: nameField
              anchors.left: slotOrdinal.right
              anchors.leftMargin: Style.space(8)
              anchors.right: slotSwitch.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              placeholderText: Model.labelFor(slot.index, null)
              font.family: root.fontFamily
              foreground: root.foreground
              verticalPadding: Style.space(6)
              selectByMouse: true
              hasCursor: root.page === "settings" && root.settingsIndex === slot.index && !activeFocus
              Component.onCompleted: text = Model.labelFor(slot.index, root.settings)
              onActiveFocusChanged: root.editingName = activeFocus
              onAccepted: {
                text = root.commitName(slot.index, text)
                root.editingName = false
                keyCatcher.forceActiveFocus()
              }
              Keys.onEscapePressed: function(event) {
                event.accepted = true
                text = Model.labelFor(slot.index, root.settings)
                root.editingName = false
                keyCatcher.forceActiveFocus()
              }
              HoverHandler {
                onHoveredChanged: if (hovered) root.settingsIndex = slot.index
              }
            }

            ToggleSwitch {
              id: slotSwitch
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: Model.enabledFor(slot.index, root.settings)
              enabled: !(checked && root.enabledCount <= 1)
              opacity: enabled ? 1 : 0.45
              hasCursor: root.page === "settings" && root.settingsIndex === slot.index
              onToggled: root.setSlotEnabled(slot.index, !checked)
              onHovered: function(isHovered) {
                if (isHovered) root.settingsIndex = slot.index
              }
            }
          }
        }
      }
    }
  }
}
