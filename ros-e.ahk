; =========================================
; ROS-e - AutoHotkey v2 Prototype
; Roman Orthographic Simultaneous-input for English
; by eekdland (Sinseiki)
;
; Alias: ROSE
;
; ROS-e orthographic chord input with optional abbreviations.
;
; Core idea:
;   1. Collect keys within CHORD_MS.
;   2. Sort by physical order.
;   3. Check for a physical-key abbreviation.
;   4. Detect onset shift / coda shift.
;   5. Convert by ROS-e layout table.
;   6. Send generated text.
; =========================================

#Requires AutoHotkey v2.0
#SingleInstance Force
InstallKeybdHook()
SendMode "Input"

; -------------------------
; Settings
; -------------------------
global CHORD_MS := 25
global PUNCT_DANCE_MS := 350
global g_enabled := true
global g_show_debug := false

; -------------------------
; Session state
; -------------------------
global g_timerOn := false
global g_keys := Map()
global g_pendingSemi := false
global g_pendingSlash := false

; -------------------------
; ROS-e special keys
; -------------------------
global ONSET_SHIFT_KEY := "a"
global CODA_SHIFT_KEY := ";"

; -------------------------
; Physical key order
; -------------------------
; Onset -> Nucleus -> Coda fields,
; Left -> Right order used to generate deterministic output.
; =========================================
global PHYSICAL_ORDER := [
    "q","a","z","w","s","x","e","d","c","r","v","f","t","g",
    "b","h","n","j","y","u","m","i","k","o","l","p",";","/"
]

; -------------------------
; Toggle
; -------------------------
; ScrollLock LED is used as the ROS-e status indicator.
; ScrollLock On  = ROS-e enabled
; ScrollLock Off = ordinary keyboard mode
;
; F9 is also bound to the same toggle for keyboards without ScrollLock.
; -------------------------

SetScrollLockState "On"

$ScrollLock::ToggleRose()
$F9::ToggleRose()

ToggleRose() {
    global g_enabled

    g_enabled := !g_enabled

    if (!g_enabled)
        ResetSession()

    ; Keep the physical ScrollLock LED in sync with ROS-e state.
    ; If the keyboard has no ScrollLock LED, this still keeps Windows state synced.

    SetScrollLockState(g_enabled ? "On" : "Off")

    ToolTip("ROS-e = " . (g_enabled ? "On" : "Off"))
    SetTimer(HideTip, -800)
}

HideTip() {
    ToolTip()
}

; -------------------------
; Hangul/English toggle passthrough
; -------------------------
$vk15::SendSpecial("{vk15}")

; =========================================
; 1) Physical key order
; =========================================
GetOrderedKeys(keyMap) {
    global PHYSICAL_ORDER
    out := []

    for k in PHYSICAL_ORDER {
        if keyMap.Has(k)
            out.Push(k)
    }

    return out
}

; =========================================
; 2) ROS-e layout tables
; =========================================
; Lower = ordinary output
; Upper = shifted output
;
; Left-side consonant field:
;   Onset shift changes lower -> upper.
;
; Right-side consonant field:
;   Coda shift changes lower -> upper.
;
; Vowels:
;   T=o, F=e, G=i, H=u, J=a, B=o, N=e
;
; Multiple O and E positions are intentional.
; =========================================


IsOnsetFieldKey(k) {
    ; Keys that can be affected by onset shift.
    return (k = "q" || k = "w" || k = "e" || k = "r"
        || k = "s" || k = "d"
        || k = "z" || k = "x" || k = "c" || k = "v")
}

IsCodaFieldKey(k) {
    ; Keys that can be affected by coda shift.
    return (k = "y" || k = "u" || k = "i" || k = "o" || k = "p"
        || k = "k" || k = "l" 
        || k = "m" || k = "/")
}

MapKeyToToken(k, onsetShift, codaShift, &kind) {
    kind := "cons"

    ; ----- onset shift key -----
    ; A is onset-shift when chorded with an onset-side key,
    ; but outputs "d" when it is not functioning as onset shift.
    if (k = "a")
        return "d"

    ; ----- coda shift key -----
    ; Semicolon is coda-shift when chorded with a coda-side key,
    ; but outputs "m" when it is not functioning as coda shift.
    if (k = ";")
        return "m"

    ; ----- vowels -----
    ; Multiple e/o keys are intentional. They allow direct vowel sequences
    if (k = "t") {
        kind := "vowel"
        return "o"
    }

    if (k = "f") {
        kind := "vowel"
        return "e"
    }

    if (k = "g") {
        kind := "vowel"
        return "i"
    }

    if (k = "h") {
        kind := "vowel"
        return "u"
    }

    if (k = "j") {
        kind := "vowel"
        return "a"
    }

    if (k = "b") {
        kind := "vowel"
        return "o"
    }

    if (k = "n") {
        kind := "vowel"
        return "e"
    }

    ; ----- left field: onset-side consonants -----
    ; Upper value = onset shift, lower value = ordinary output.

    ; Q key: w
    if (k = "q")
        return "w"

    ; W key: v / c
    if (k = "w")
        return onsetShift ? "v" : "c"

    ; E key: g / t
    if (k = "e")
        return onsetShift ? "g" : "t"

    ; R key: k / h
    if (k = "r")
        return onsetShift ? "k" : "h"

    ; S key: b / s
    if (k = "s")
        return onsetShift ? "b" : "s"

    ; D key: f / r
    if (k = "d")
        return onsetShift ? "f" : "r"

    ; Z key: j / p
    if (k = "z")
        return onsetShift ? "j" : "p"

    ; X key: q / n
    if (k = "x")
        return onsetShift ? "q" : "n"

    ; C key: z / l
    if (k = "c")
        return onsetShift ? "z" : "l"

    ; V key: y / m
    if (k = "v")
        return onsetShift ? "y" : "m"

    ; ----- right field: coda-side consonants -----
    ; Upper value = coda shift, lower value = ordinary output.

    ; Y key: w / c
    if (k = "y")
        return codaShift ? "w" : "c"

    ; U key: x / l
    if (k = "u")
        return codaShift ? "x" : "l"

    ; I key: p / s
    if (k = "i")
        return codaShift ? "p" : "s"

    ; O key: b / d
    if (k = "o")
        return codaShift ? "b" : "d"

    ; P key: k / h
    if (k = "p")
        return codaShift ? "k" : "h"

    ; K key: f / n
    if (k = "k")
        return codaShift ? "f" : "n"

    ; L key: y / t
    if (k = "l")
        return codaShift ? "y" : "t"

    ; M key: v / r
    if (k = "m")
        return codaShift ? "v" : "r"

    ; / key: g
    if (k = "/")
        return "g"

    kind := "unknown"
    return ""
}

JoinTokens(tokens) {
    out := ""
    for token in tokens
        out .= token
    return out
}

; =========================================
; 3) Optional developer abbreviations
; =========================================
; Abbreviations are matched by physical-key chord before normal
; ROS-e letter conversion. Any physical-key chord may be assigned.
; Chord IDs are canonicalized, so key order in the map does not matter.
; =========================================

GetAbbreviationMap() {
    static abbrevMap := 0

    if !IsObject(abbrevMap) {
        abbrevMap := Map()

        ; Starter developer abbreviations.
        ; These defaults use the A+X(Q) family, but this is only a convention.
        ; Users may change, remove, or add ANY physical-key chord here.
        ; Key order does not matter; chord IDs are canonicalized automatically.

        abbrevMap["a+x+k"] := "return"
        abbrevMap["a+x+l"] := "function"
        abbrevMap["a+x+;"] := "public"
        abbrevMap["a+x+y"] := "import"
        abbrevMap["a+x+u"] := "void"
        abbrevMap["a+x+i"] := "array"
        abbrevMap["a+x+o"] := "static"
        abbrevMap["a+x+p"] := "true"
        abbrevMap["a+x+/"] := "false"

        abbrevMap["a+x+k+;"] := "private"
        abbrevMap["a+x+l+;"] := "break"
        abbrevMap["a+x+y+;"] := "double"
        abbrevMap["a+x+u+;"] := "class"
        abbrevMap["a+x+i+;"] := "final"
        abbrevMap["a+x+o+;"] := "protect"
        abbrevMap["a+x+p+;"] := "boolean"
        abbrevMap["a+x+m+;"] := "struct"
        abbrevMap["a+x+/+;"] := "extend"

        ; Examples:
        ; abbrevMap["q+w"] := "example"
        ; abbrevMap["j+f"] := "custom"
        ; abbrevMap["o+u+i"] := "another"

        normalized := Map()
        for chordId, expansion in abbrevMap {
            canonicalId := CanonicalizePhysicalChordId(chordId)
            normalized[canonicalId] := expansion
        }
        abbrevMap := normalized
    }

    return abbrevMap
}

CanonicalizePhysicalChordId(chordId) {
    keyMap := Map()

    parts := StrSplit(chordId, "+")
    for k in parts {
        k := Trim(k)
        if (k != "")
            keyMap[k] := true
    }

    return BuildPhysicalChordId(GetOrderedKeys(keyMap))
}

BuildPhysicalChordId(orderedKeys) {
    id := ""

    for k in orderedKeys {
        if (id != "")
            id .= "+"
        id .= k
    }

    return id
}

TryGetAbbreviation(orderedKeys, &output) {
    output := ""
    chordId := BuildPhysicalChordId(orderedKeys)
    map := GetAbbreviationMap()

    if !map.Has(chordId)
        return false

    output := map[chordId]
    return true
}

; =========================================
; 4) Chord builder
; =========================================

BuildOutput(orderedKeys) {
    global ONSET_SHIFT_KEY, CODA_SHIFT_KEY

    abbreviation := ""
    if TryGetAbbreviation(orderedKeys, &abbreviation)
        return abbreviation

    hasOnsetShiftKey := false
    hasCodaShiftKey := false
    hasOnsetTarget := false
    hasCodaTarget := false

    ; For a single-key chord, A and ; should output their ordinary letters.
    singleKey := (orderedKeys.Length = 1)

    ; First pass: detect scoped modifiers and their target fields.
    ;
    ; Important:
    ;   A is NOT a global onset modifier.
    ;   ; is NOT a global coda modifier.
    ;
    ;   A becomes onset-shift only when an onset-side key exists in the same chord.
    ;   ; becomes coda-shift only when a coda-side key exists in the same chord.
    for k in orderedKeys {
        if (k = ONSET_SHIFT_KEY) {
            hasOnsetShiftKey := true
            continue
        }

        if (k = CODA_SHIFT_KEY) {
            hasCodaShiftKey := true
            continue
        }

        if IsOnsetFieldKey(k)
            hasOnsetTarget := true

        if IsCodaFieldKey(k)
            hasCodaTarget := true
    }

    onsetShift := (!singleKey && hasOnsetShiftKey && hasOnsetTarget)
    codaShift := (!singleKey && hasCodaShiftKey && hasCodaTarget)

    tokens := []

    ; Second pass: build tokens.
        ; Skip A only when it is actually functioning as onset shift.
    for k in orderedKeys {
        if (k = ONSET_SHIFT_KEY && onsetShift)
            continue

        ; Skip ; only when it is actually functioning as coda shift.
        if (k = CODA_SHIFT_KEY && codaShift)
            continue

        kind := ""
        token := MapKeyToToken(k, onsetShift, codaShift, &kind)

        if (token != "")
            tokens.Push(token)
    }

    return JoinTokens(tokens)
}

; =========================================
; 5) Shift punctuation tap-dance
; =========================================
; Shift + ; once  => ;
; Shift + ; twice => :
; Shift + / once  => /
; Shift + / twice => ?
;
; The first character is emitted immediately.
; If the same shifted punctuation is pressed again within
; PUNCT_DANCE_MS, the previous character is replaced.
; =========================================

ClearPunctPending() {
    global g_pendingSemi, g_pendingSlash

    g_pendingSemi := false
    g_pendingSlash := false
    SetTimer(ClearSemiPending, 0)
    SetTimer(ClearSlashPending, 0)
}

HandleShiftSemicolon() {
    global g_pendingSemi, g_pendingSlash, PUNCT_DANCE_MS

    FlushChord()

    ; Do not allow semicolon state to be upgraded accidentally.
    g_pendingSlash := false
    SetTimer(ClearSlashPending, 0)

    if g_pendingSemi {
        g_pendingSemi := false
        SetTimer(ClearSemiPending, 0)
        Send("{Backspace}")
        SendText(":")
        return
    }

    SendText(";")
    g_pendingSemi := true
    SetTimer(ClearSemiPending, -PUNCT_DANCE_MS)
}

HandleShiftSlash() {
    global g_pendingSemi, g_pendingSlash, PUNCT_DANCE_MS

    FlushChord()

    ; Do not allow slash state to be upgraded accidentally.
    g_pendingSemi := false
    SetTimer(ClearSemiPending, 0)

    if g_pendingSlash {
        g_pendingSlash := false
        SetTimer(ClearSlashPending, 0)
        Send("{Backspace}")
        SendText("?")
        return
    }

    SendText("/")
    g_pendingSlash := true
    SetTimer(ClearSlashPending, -PUNCT_DANCE_MS)
}

ClearSemiPending() {
    global g_pendingSemi
    g_pendingSemi := false
}

ClearSlashPending() {
    global g_pendingSlash
    g_pendingSlash := false
}

; =========================================
; 6) Session helpers
; =========================================

ResetSession() {
    global g_timerOn, g_keys
    g_timerOn := false
    g_keys := Map()
    SetTimer(ChordTimeout, 0)
}

StartOrContinueSession(k) {
    global g_timerOn, g_keys, CHORD_MS

    ClearPunctPending()

    g_keys[k] := true
    g_timerOn := true

    SetTimer(ChordTimeout, 0)
    SetTimer(ChordTimeout, -CHORD_MS)
}

FlushChord() {
    global g_timerOn, g_keys, g_show_debug

    if !g_timerOn
        return

    ordered := GetOrderedKeys(g_keys)
    output := BuildOutput(ordered)

    if g_show_debug {
        debug := ""
        for k in ordered
            debug .= k
        ToolTip(debug . " => " . output)
        SetTimer(HideTip, -700)
    }

    ResetSession()

    if (output != "")
        SendText(output)
}

; =========================================
; 7) Main input handler
; =========================================

IsModifierPressed() {
    for mod in ["Ctrl", "Alt", "LWin", "RWin"] {
        if GetKeyState(mod, "P")
            return true
    }
    return false
}

OnKey(k) {
    ; Shift/Ctrl/Alt/Win input should pass through as the physical key,
    ; rather than being converted into a ROS-e chord.
    if GetKeyState("Shift", "P") {
        if (k != ";" && k != "/") {
            SendPhysicalKey(k)
            return
        }
    }

    if IsModifierPressed() {
        SendPhysicalKey(k)
        return
    }

    StartOrContinueSession(k)
}

SendPhysicalKey(k) {
    FlushChord()
    ClearPunctPending()

    ; SendLevel prevents the synthetic key from re-triggering the $ hotkeys.
    oldLevel := A_SendLevel
    SendLevel 0
    Send("{" . k . "}")
    SendLevel oldLevel
}

SendSpecial(keys) {
    FlushChord()
    ClearPunctPending()
    Send(keys)
}

ChordTimeout() {
    FlushChord()
}

; =========================================
; 8) Hotkeys
; =========================================
; #HotIf makes ROS-e's ordinary key hooks conditional. When ROS-e is
; disabled, these hotkeys cease to intercept the underlying keyboard.
; =========================================

#HotIf g_enabled

$q::OnKey("q")
$w::OnKey("w")
$e::OnKey("e")
$r::OnKey("r")
$t::OnKey("t")
$y::OnKey("y")
$u::OnKey("u")
$i::OnKey("i")
$o::OnKey("o")
$p::OnKey("p")

$a::OnKey("a")
$s::OnKey("s")
$d::OnKey("d")
$f::OnKey("f")
$g::OnKey("g")
$h::OnKey("h")
$j::OnKey("j")
$k::OnKey("k")
$l::OnKey("l")

$z::OnKey("z")
$x::OnKey("x")
$c::OnKey("c")
$v::OnKey("v")
$b::OnKey("b")
$n::OnKey("n")
$m::OnKey("m")

$+`;::HandleShiftSemicolon()
$+/::HandleShiftSlash()

$`;::OnKey(";")
$/::OnKey("/")

$Space::SendSpecial("{Space}")
$Enter::SendSpecial("{Enter}")
$Backspace::SendSpecial("{Backspace}")
$Tab::SendSpecial("{Tab}")
$Esc::SendSpecial("{Esc}")

#HotIf
