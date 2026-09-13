.pragma library
var background = "#111619"
var sidebar = "#0d1215"
var surface = "#171d20"
var raised = "#222a2e"
var border = "#2b3337"
var text = "#f3f0e8"
var secondary = "#b9bec0"
var muted = "#7d868b"
var amber = "#e6b64e"
var gold = "#f0c96b"
var blue = "#6e9fd1"
var green = "#55b878"
var orange = "#d97a4b"
var family = "Inter"
var radius = 8
var gap = 12
function speed(value) {
    if (value === null || value === undefined || !isFinite(value)) return "Not reported"
    return value >= 1000 ? (value / 1000) + " Gbps" : value + " Mbps"
}
function reported(value) { return value ? String(value) : "Not reported" }
function date(value) {
    if (!value) return "Not saved yet"
    var d = new Date(value)
    return isNaN(d.getTime()) ? "Not reported" : Qt.formatDateTime(d, "MMM d, h:mm AP")
}
