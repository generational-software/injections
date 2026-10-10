// Day and dose math for the injections bar widget.
// Qt-free so the reset rules can be checked under node.

var DOSE_COUNT = 4
var DEFAULT_LABELS = ["Morning", "Lunch", "Dinner", "Bedtime"]

function pad2(n) {
  var value = Number(n)
  if (!isFinite(value) || value < 0) value = 0
  return (value < 10 ? "0" : "") + value
}

// Local calendar day. UTC ISO dates roll over at the wrong hour.
function localDay(date) {
  var d = date instanceof Date && !isNaN(date.getTime()) ? date : new Date()
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function emptyDoses() {
  return [false, false, false, false]
}

function normalizeDoses(raw) {
  var out = emptyDoses()
  if (!raw || typeof raw.length !== "number") return out
  var count = raw.length < DOSE_COUNT ? raw.length : DOSE_COUNT
  for (var i = 0; i < count; i++) out[i] = raw[i] === true
  return out
}

function parseState(raw) {
  var parsed = null
  if (raw && typeof raw === "object") parsed = raw
  else {
    try { parsed = JSON.parse(String(raw || "")) } catch (e) { parsed = null }
  }
  if (!parsed || typeof parsed !== "object") return { date: "", doses: emptyDoses() }
  return {
    date: typeof parsed.date === "string" ? parsed.date : "",
    doses: normalizeDoses(parsed.done)
  }
}

function serializeState(date, doses) {
  return JSON.stringify({
    date: String(date || ""),
    done: normalizeDoses(doses)
  }, null, 2) + "\n"
}

// The first open of a local day clears yesterday's checks. A later open
// the same day keeps whatever was checked off.
function stateOnOpen(date, doses, today) {
  var flags = normalizeDoses(doses)
  if (date === today) return { date: date, doses: flags, cleared: false }
  return { date: today, doses: emptyDoses(), cleared: true }
}

function toggleDose(date, doses, today, index) {
  var base = stateOnOpen(date, doses, today)
  var next = emptyDoses()
  for (var i = 0; i < DOSE_COUNT; i++) next[i] = base.doses[i] === true
  if (index >= 0 && index < DOSE_COUNT) next[index] = !next[index]
  return { date: today, doses: next, cleared: base.cleared }
}

// Yesterday's checks must not read as done today, even before the panel
// has been opened and the saved flags wiped.
function shownCount(date, doses, today, settings) {
  if (date !== today) return 0
  var flags = normalizeDoses(doses)
  var n = 0
  for (var i = 0; i < DOSE_COUNT; i++) {
    if (!enabledFor(i, settings)) continue
    if (flags[i]) n++
  }
  return n
}

function doseOn(date, doses, today, index) {
  if (date !== today) return false
  if (index < 0 || index >= DOSE_COUNT) return false
  var flags = normalizeDoses(doses)
  return flags[index] === true
}

function labelFor(index, settings) {
  var fallback = DEFAULT_LABELS[index] || ("Dose " + (index + 1))
  if (!settings) return fallback
  var value = settings["label" + (index + 1)]
  if (value === undefined || value === null) return fallback
  var text = String(value).trim()
  return text !== "" ? text : fallback
}

// Missing keys stay on, so a config that only renames labels still tracks
// all four. An explicit false (or the string "false") turns that point off.
function enabledFor(index, settings) {
  if (index < 0 || index >= DOSE_COUNT) return false
  if (!settings) return true
  var value = settings["enabled" + (index + 1)]
  if (value === undefined || value === null || value === "") return true
  if (value === false || value === 0 || value === "false" || value === "0") return false
  return true
}

function enabledIndices(settings) {
  var out = []
  for (var i = 0; i < DOSE_COUNT; i++) if (enabledFor(i, settings)) out.push(i)
  return out
}

function tooltip(date, doses, today, settings) {
  if (date !== today) return "Injections — new day"
  var doneNames = []
  var left = 0
  var any = 0
  for (var i = 0; i < DOSE_COUNT; i++) {
    if (!enabledFor(i, settings)) continue
    any++
    if (doseOn(date, doses, today, i)) doneNames.push(labelFor(i, settings))
    else left++
  }
  if (any === 0) return "Injections"
  if (doneNames.length === 0) return "Injections — none yet today"
  if (left === 0) return any === DOSE_COUNT ? "Injections — all four done" : "Injections — all done"
  return "Injections — " + doneNames.join(", ") + " done"
}
