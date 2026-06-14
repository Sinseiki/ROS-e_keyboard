; =========================================
; ROS-e - AutoHotkey v1 Prototype
; Roman Orthographic Simultaneous-input for English
; by eekdland (Sinseiki)
;
; Alias: ROSE
;
; This file is based on the uploaded ros-e.ahk structure,
; but refactored for ROS-e dictionaryless chord input.
;
; Core idea:
;   1. Collect keys within CHORD_MS.
;   2. Sort by physical order.
;   3. Detect onset shift / coda shift.
;   4. Convert by ROS-e layout table.
;   5. Send generated roman text.
; =========================================

#NoEnv
#SingleInstance Force
#InstallKeybdHook
#UseHook On
SendMode Input
SetBatchLines, -1
ListLines, Off

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
global g_keys := Object()
global g_sessionId := 0

; -------------------------
; ROS-e special keys
; -------------------------
global ONSET_SHIFT_KEY := "a"
global CODA_SHIFT_KEY := ";"

; -------------------------
; Toggle
; -------------------------
; ScrollLock LED is used as the ROS-e status indicator.
; ScrollLock On  = ROS-e enabled
; ScrollLock Off = ordinary keyboard mode
;
; F9 is also bound to the same toggle for keyboards without ScrollLock.
; -------------------------
SetScrollLockState, On

$ScrollLock::
    Gosub, __ToggleRose
return

$F9::
    Gosub, __ToggleRose
return

__ToggleRose:
    g_enabled := !g_enabled

    ; Reset all pending states when disabling.
    if (!g_enabled)
        ResetSession()

    state := g_enabled ? "On" : "Off"

    ; Keep the physical ScrollLock LED in sync with ROS-e state.
    ; If the keyboard has no ScrollLock LED, this still keeps Windows state synced.
    SetScrollLockState, % state

    ; Fully enable/disable ROS-e hotkeys.
    Hotkey, $q, % state
    Hotkey, $w, % state
    Hotkey, $e, % state
    Hotkey, $r, % state
    Hotkey, $t, % state
    Hotkey, $y, % state
    Hotkey, $u, % state
    Hotkey, $i, % state
    Hotkey, $o, % state
    Hotkey, $p, % state

    Hotkey, $a, % state
    Hotkey, $s, % state
    Hotkey, $d, % state
    Hotkey, $f, % state
    Hotkey, $g, % state
    Hotkey, $h, % state
    Hotkey, $j, % state
    Hotkey, $k, % state
    Hotkey, $l, % state

    Hotkey, $z, % state
    Hotkey, $x, % state
    Hotkey, $c, % state
    Hotkey, $v, % state
    Hotkey, $b, % state
    Hotkey, $n, % state
    Hotkey, $m, % state

    Hotkey, $+`;, % state
    Hotkey, $+/, % state
    Hotkey, $`;, % state
    Hotkey, $/, % state

    ; ToolTip, % "ROS-e = " . (g_enabled ? "On" : "Off") . " / ScrollLock = " . state
    ToolTip, % "ROS-e = " . (g_enabled ? "On" : "Off")
    SetTimer, __HideTip, -800
return

; Optional debug toggle. Currently disabled because F9 is used as backup ROS-e toggle.
; F9::
;     g_show_debug := !g_show_debug
;     ToolTip, % "ROS-e Debug = " . (g_show_debug ? "On" : "Off")
;     SetTimer, __HideTip, -800
; return

__HideTip:
ToolTip
return

; -------------------------
; Hangul/English toggle passthrough
; -------------------------
$vk15::
    FlushChord()
    SendInput, {vk15}
return

; =========================================
; 1) Physical key order
; =========================================
; Onset -> Nucleus -> Coda fields,
; Left -> Right order used to generate deterministic output.
; =========================================

GetOrderedKeys(ByRef keyMap) {
    order := ["q","a","z","w","s","x","e","d","c","r","v","f","t","g","b","y","h","j","n","u","m","i","k","o","l","p",";","/"]
    
    out := []

    for idx, k in order {
        if (keyMap.HasKey(k))
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
;   F=e, G=o, H=a, B=i, N=u
;
; Special:
;   T=rev, Y=x2
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

MapKeyToToken(k, onsetShift, codaShift, ByRef kind) {
    kind := "cons"

    ; ----- onset shift key -----
    ; A is onset-shift when chorded with an onset-side key,
    ; but outputs "d" when it is not functioning as onset shift.
    if (k = "a") {
        kind := "cons"
        return "d"
    }

    ; ----- coda shift key -----
    ; Semicolon is coda-shift when chorded with a coda-side key,
    ; but outputs "m" when it is not functioning as coda shift.
    if (k = ";") {
        kind := "cons"
        return "m"
    }

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

    ; Q key: q / w
    if (k = "q")
        return onsetShift ? "q" : "w"

    ; W key: j / c
    if (k = "w")
        return onsetShift ? "j" : "c"

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

    ; Z key: p
    if (k = "z")
        ; return onsetShift ? "q" : "p"
        return "p"

    ; X key: z / n
    if (k = "x")
        return onsetShift ? "z" : "n"

    ; C key: v / l
    if (k = "c")
        return onsetShift ? "v" : "l"

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
        ; return codaShift ? "x" : "h"
        return "g"

    kind := "unknown"
    return ""
}

; =========================================
; 3) Output helpers
; =========================================

JoinTokens(ByRef tokens) {
    out := ""

    for idx, token in tokens
        out .= token

    return out
}

; =========================================
; 4) Chord builder
; =========================================

BuildOutput(ByRef orderedKeys) {
    global ONSET_SHIFT_KEY, CODA_SHIFT_KEY

    hasOnsetShiftKey := false
    hasCodaShiftKey := false
    hasOnsetTarget := false
    hasCodaTarget := false

    ; For single-key chord, V and N should output letters.
    singleKey := (orderedKeys.Length() = 1)

    ; First pass: detect scoped modifiers and their target fields.
    ;
    ; Important:
    ;   V is NOT a global onset modifier.
    ;   N is NOT a global coda modifier.
    ;
    ;   V becomes onset-shift only when an onset-side key exists in the same chord.
    ;   N becomes coda-shift only when a coda-side key exists in the same chord.
    for idx, k in orderedKeys {
        if (k = ONSET_SHIFT_KEY) {
            hasOnsetShiftKey := true
            continue
        }

        if (k = CODA_SHIFT_KEY) {
            hasCodaShiftKey := true
            continue
        }

        if (IsOnsetFieldKey(k))
            hasOnsetTarget := true

        if (IsCodaFieldKey(k))
            hasCodaTarget := true
    }

    onsetShift := (!singleKey && hasOnsetShiftKey && hasOnsetTarget)
    codaShift := (!singleKey && hasCodaShiftKey && hasCodaTarget)

    tokens := []
    kinds := []

    ; Second pass: build tokens.
    for idx, k in orderedKeys {
        ; Skip V only when it is actually functioning as onset shift.
        if (k = ONSET_SHIFT_KEY && onsetShift)
            continue

        ; Skip N only when it is actually functioning as coda shift.
        if (k = CODA_SHIFT_KEY && codaShift)
            continue

        kind := ""
        token := MapKeyToToken(k, onsetShift, codaShift, kind)

        if (token != "") {
            tokens.Push(token)
            kinds.Push(kind)
        }
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
    SetTimer, __ClearSemiPending, Off
    SetTimer, __ClearSlashPending, Off
}

HandleShiftSemicolon() {
    global g_pendingSemi, g_pendingSlash, PUNCT_DANCE_MS

    FlushChord()

    ; Do not allow slash state to be upgraded accidentally.
    g_pendingSlash := false
    SetTimer, __ClearSlashPending, Off

    if (g_pendingSemi) {
        g_pendingSemi := false
        SetTimer, __ClearSemiPending, Off
        SendInput, {Backspace}{Text}:
        return
    }

    SendInput, {Text}`;
    g_pendingSemi := true
    SetTimer, __ClearSemiPending, -%PUNCT_DANCE_MS%
}

HandleShiftSlash() {
    global g_pendingSemi, g_pendingSlash, PUNCT_DANCE_MS

    FlushChord()

    ; Do not allow semicolon state to be upgraded accidentally.
    g_pendingSemi := false
    SetTimer, __ClearSemiPending, Off

    if (g_pendingSlash) {
        g_pendingSlash := false
        SetTimer, __ClearSlashPending, Off
        SendInput, {Backspace}{Text}?
        return
    }

    SendInput, {Text}/
    g_pendingSlash := true
    SetTimer, __ClearSlashPending, -%PUNCT_DANCE_MS%
}

__ClearSemiPending:
    g_pendingSemi := false
return

__ClearSlashPending:
    g_pendingSlash := false
return


; =========================================
; 6) Session helpers
; =========================================

ResetSession() {
    global g_timerOn, g_keys
    g_timerOn := false
    g_keys := Object()
    SetTimer, __ChordTimeout, Off
}

StartOrContinueSession(k) {
    global g_timerOn, g_keys, CHORD_MS, g_sessionId

    ClearPunctPending()

    g_keys[k] := 1
    g_timerOn := true
    g_sessionId += 1

    SetTimer, __ChordTimeout, Off
    SetTimer, __ChordTimeout, -%CHORD_MS%
}

FlushChord() {
    global g_timerOn, g_keys, g_show_debug

    if (!g_timerOn)
        return

    ordered := GetOrderedKeys(g_keys)
    output := BuildOutput(ordered)

    if (g_show_debug) {
        debug := ""
        for i, k in ordered
            debug .= k
        ToolTip, % debug . " => " . output
        SetTimer, __HideTip, -700
    }

    ResetSession()

    if (output != "")
        SendInput, {Text}%output%
}

; =========================================
; 7) Main input handler
; =========================================

IsModifierPressed() {
    modifiers := ["Ctrl", "Alt", "LWin", "RWin"]
    for _, mod in modifiers {
        if (GetKeyState(mod, "P"))
            return true
    }
    return false
}

OnKey(k) {
    ; Shift is used to make OS keyboard layout capital letters.
    ; However, Shift+; and Shift+/ are handled by ROS-e punctuation logic.
    if (GetKeyState("Shift", "P")) {
        if (k != ";" && k != "/") {
            SendSpecial("{Text}" . k)
            return
        }
    }

    ; Ctrl/Alt/Win are usually shortcuts. Do not chord them.
    if (IsModifierPressed()) {
        SendSpecial("{Text}" . k)
        return
    }

    StartOrContinueSession(k)
}

SendSpecial(text) {
    FlushChord()
    ClearPunctPending()
    SendInput, %text%
}

__ChordTimeout:
    FlushChord()
return

; =========================================
; 8) Hooks: alphabet keys
; =========================================
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

; =========================================
; 9) Hooks: punctuation keys used by ROS-e
; =========================================
; Shift tap-dance punctuation:
;   Shift+; once  => ;
;   Shift+; twice => :
;   Shift+/ once  => /
;   Shift+/ twice => ?
$+`;::HandleShiftSemicolon()
$+/::HandleShiftSlash()

$`;::OnKey(";")
$/::OnKey("/")

; =========================================
; 10) Flush-before-special keys
; =========================================
$Space::SendSpecial("{Space}")
$Enter::SendSpecial("{Enter}")
$Backspace::SendSpecial("{Backspace}")
$Tab::SendSpecial("{Tab}")
$Esc::SendSpecial("{Esc}")
