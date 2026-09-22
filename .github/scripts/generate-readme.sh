#!/usr/bin/env bash
#
# Generates README.md from the recipes in Receipts/de.
#
# Recipes are grouped by the total time given in their "## Dauer" section
# into the categories Schnell (quick), Mittel (medium) and Lang (long).
# The README itself is written in German, like the recipes.
#
# Runs automatically via .github/workflows/readme.yml on every push to
# main, and can also be run locally:
#
#     .github/scripts/generate-readme.sh
#
# Requires only bash and awk (GNU awk, mawk or BSD awk).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RECIPES="$ROOT/Receipts/de"
README="$ROOT/README.md"

# Each file is preceded by a marker line so awk can tell files apart even
# when a file is empty or lacks a trailing newline.
emit_recipes() {
    local f
    for f in "$RECIPES"/*.md; do
        [ -e "$f" ] || continue
        printf '\001FILE\t%s\n' "${f##*/}"
        cat "$f"
        printf '\n'
    done
}

read -r -d '' AWK_PROGRAM <<'AWK' || true
BEGIN {
    for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i

    NUM  = "([0-9]+/[0-9]+|½|[0-9]+([.,][0-9]+)?)"
    UNIT = "(minuten|minute|min\\.?|stunden|stunde|std\\.?|h|tage|tag|nächte|nacht|wochen|woche)"
    TOKEN = NUM "([ \t]*(-|–)[ \t]*" NUM ")?[ \t]*" UNIT

    unitmin["min"] = 1; unitmin["std"] = 60; unitmin["tag"] = 1440
    unitmin["nacht"] = 600; unitmin["woche"] = 10080

    ncat = 3
    catname[1] = "Schnell"; catdesc[1] = "bis 30 Min.";  catlimit[1] = 30
    catname[2] = "Mittel";  catdesc[2] = "bis 1 Std.";   catlimit[2] = 60
    catname[3] = "Lang";    catdesc[3] = "über 1 Std.";  catlimit[3] = -1

    langname["de"] = "Deutsch"; langname["en"] = "Englisch"
    langname["fr"] = "Französisch"; langname["es"] = "Spanisch"; langname["it"] = "Italienisch"
    nlang = split(langs, lang, " ")

    n = 0
}

function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }

function urlencode(s,    i, c, out) {
    out = ""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        out = out (c ~ /[A-Za-z0-9_.~-]/ ? c : sprintf("%%%02X", ord[c]))
    }
    return out
}

function unitkey(u) {
    sub(/\.$/, "", u)
    if (u ~ /^min/) return "min"
    if (u == "h" || u == "std" || u ~ /^stunde/) return "std"
    if (u ~ /^tag/) return "tag"
    if (u ~ /^nacht/ || u ~ /^nächte/) return "nacht"
    return "woche"
}

function numval(s,    p) {
    if (s == "½") return 0.5
    if (index(s, "/")) { split(s, p, "/"); return p[1] / p[2] }
    gsub(/,/, ".", s)
    return s + 0
}

function numfmt(s) { return (s == "1/2" || s == "½") ? "½" : s }

# Splits a duration like "24–48 Std." into TA (from), TB (to) and TU (unit).
function splittoken(tok,    t, sep, i) {
    t = tolower(tok)
    match(t, UNIT "$")
    TU = substr(t, RSTART)
    t = trim(substr(t, 1, RSTART - 1))
    sep = index(t, "–") ? "–" : (index(t, "-") ? "-" : "")
    if (sep != "") {
        i = index(t, sep)
        TA = trim(substr(t, 1, i - 1)); TB = trim(substr(t, i + length(sep)))
    } else {
        TA = t; TB = ""
    }
}

function normtoken(tok,    key, val, plural, label) {
    splittoken(tok)
    key = unitkey(TU)
    val = numval(TB != "" ? TB : TA)
    plural = val > 1
    if (key == "min") label = "Min."
    else if (key == "std") label = "Std."
    else if (key == "tag") label = plural ? "Tage" : "Tag"
    else if (key == "nacht") label = plural ? "Nächte" : "Nacht"
    else label = plural ? "Wochen" : "Woche"
    return numfmt(TA) (TB != "" ? "–" numfmt(TB) : "") " " label
}

# Finds the next duration in s that does not end in the middle of a word.
# Sets TSTART and TLEN; returns 0 if there is none.
function nexttoken(s,    low, off, c) {
    low = tolower(s); off = 0
    while (match(low, TOKEN)) {
        c = substr(low, RSTART + RLENGTH, 1)
        if (c !~ /[a-z]/ && c != "\303") { TSTART = off + RSTART; TLEN = RLENGTH; return 1 }
        off += RSTART; low = substr(low, RSTART + 1)
    }
    return 0
}

# Minimum duration of a part in minutes; for ranges the lower bound counts.
function minutes(part,    s, low, total) {
    s = part
    # Store tolower() in a variable first: original-awk (macOS) returns a
    # wrong value for match(tolower(s), ...) otherwise.
    low = tolower(s)
    if (match(low, /[ \t]+(-|–|bis)[ \t]+/)) s = substr(s, 1, RSTART - 1)
    total = 0
    while (nexttoken(s)) {
        splittoken(substr(s, TSTART, TLEN))
        total += numval(TA) * unitmin[unitkey(TU)]
        s = substr(s, TSTART + TLEN)
    }
    return total
}

function display(part,    s, out) {
    s = part; out = ""
    while (nexttoken(s)) {
        out = out substr(s, 1, TSTART - 1) normtoken(substr(s, TSTART, TLEN))
        s = substr(s, TSTART + TLEN)
    }
    out = out s
    gsub(/[ \t]+/, " ", out)
    gsub(/ - /, " bis ", out)
    return out
}

function finish(    text, parts, np, i, p, c, total, shown) {
    if (file == "") return
    text = dauer
    gsub(/<br[ \t]*\/?>/, "\n", text)
    gsub(/[ \t]+und[ \t]+/, "\n", text)
    np = split(text, parts, "\n")
    total = 0; shown = ""
    for (i = 1; i <= np; i++) {
        p = trim(parts[i]); sub(/^-+/, "", p); p = trim(p)
        c = index(p, ","); if (c) p = trim(substr(p, 1, c - 1))
        if (p == "") continue
        total += minutes(p)
        shown = shown (shown == "" ? "" : " + ") display(p)
    }
    if (title == "") { title = file; sub(/\.md$/, "", title); sub(/^#+/, "", title) }
    n++
    rfile[n] = file; rtitle[n] = title; rmin[n] = total; rshown[n] = shown
    titlecount[title]++
    file = ""
}

substr($0, 1, 6) == "\001FILE\t" { finish(); file = substr($0, 7); title = ""; insec = 0; seen = 0; dauer = ""; next }
insec && (/^# / || /^## /) { insec = 0 }
title == "" && /^# / { title = trim(substr($0, 3)) }
!seen && /^## Dauer[ \t]*$/ { insec = 1; seen = 1; next }
insec { dauer = dauer $0 "\n" }

function before(a, b) {
    if (rmin[a] != rmin[b]) return rmin[a] < rmin[b]
    return (tolower(rtitle[a]) "") < (tolower(rtitle[b]) "")
}

function row(i, withtime,    link) {
    link = "[" rtitle[i] "](Receipts/de/" urlencode(rfile[i]) ")"
    return withtime ? "| " link " | " rshown[i] " |" : "| " link " |"
}

function table(c, withtime,    out, k) {
    out = withtime ? "| Rezept | Dauer |\n|---|---|" : "| Rezept |\n|---|"
    for (k = 1; k <= cnt[c]; k++) out = out "\n" row(member[c, k], withtime)
    return out
}

END {
    finish()

    for (i = 1; i <= n; i++) {
        if (titlecount[rtitle[i]] > 1) {
            stem = rfile[i]; sub(/\.md$/, "", stem)
            rtitle[i] = rtitle[i] " (" stem ")"
        }
    }

    # Category 4 = recipes without a duration ("Ohne Zeitangabe")
    for (c = 1; c <= 4; c++) cnt[c] = 0
    for (i = 1; i <= n; i++) {
        if (rmin[i] <= 0) c = 4
        else for (c = 1; c <= ncat; c++) if (catlimit[c] < 0 || rmin[i] <= catlimit[c]) break
        k = ++cnt[c]
        # insertion sort: by minutes, then by title
        while (k > 1 && before(i, member[c, k - 1])) { member[c, k] = member[c, k - 1]; k-- }
        member[c, k] = i
    }

    print "<!-- Diese Datei wird automatisch von .github/scripts/generate-readme.sh erzeugt. Änderungen von Hand werden beim nächsten Push überschrieben. -->"
    print ""
    print "# Receipts"
    print ""
    if (nlang > 1) {
        print "Unsere Rezeptsammlung. Die Rezepte gibt es in mehreren Sprachen:"
        print ""
        for (i = 1; i <= nlang; i++)
            print "- " (lang[i] in langname ? langname[lang[i]] : lang[i]) ": [`Receipts/" lang[i] "`](Receipts/" lang[i] ")"
        print ""
        print "Die Übersicht unten verlinkt die deutschen Rezepte."
    } else {
        print "Unsere Rezeptsammlung. Alle Rezepte liegen unter [`Receipts/de`](Receipts/de)."
    }
    print ""
    print "## Rezepte nach Zubereitungsdauer"
    print ""
    print "Eingeteilt wird nach der **Gesamtzeit** – also inklusive Back-, Koch-, Ruhe-, Einweich- und Ziehzeiten. Ein Salat, der über Nacht durchziehen muss, landet deshalb bei „Lang\", auch wenn die eigentliche Arbeit nur 15 Minuten dauert."
    print ""
    print "| Kategorie | Gesamtzeit | Anzahl |"
    print "|---|---|---|"
    for (c = 1; c <= ncat; c++)
        print "| [" catname[c] "](#" tolower(catname[c]) ") | " catdesc[c] " | " cnt[c] " |"
    if (cnt[4]) print "| [Ohne Zeitangabe](#ohne-zeitangabe) | – | " cnt[4] " |"
    print ""
    for (c = 1; c <= ncat; c++) {
        if (c > 1) print ""
        print "### " catname[c]
        print ""
        print table(c, 1)
    }
    if (cnt[4]) {
        print ""
        print "### Ohne Zeitangabe"
        print ""
        print "Diese Rezepte haben noch keinen Abschnitt `## Dauer`."
        print ""
        print table(4, 0)
    }
    print ""
    print "---"
    print ""
    print "Die Liste wird bei jedem Push auf `main` automatisch aktualisiert. Die Zeiten stammen aus dem Abschnitt `## Dauer` des jeweiligen Rezepts."

    print "README.md written: " cnt[1] " quick, " cnt[2] " medium, " cnt[3] " long, " cnt[4] " without duration" | "cat 1>&2"
}
AWK

# Every subfolder of Receipts/ is one language, e.g. "de" and "en".
languages() {
    local d
    for d in "$ROOT/Receipts"/*/; do
        [ -d "$d" ] || continue
        d="${d%/}"
        printf '%s ' "${d##*/}"
    done
}

emit_recipes | LC_ALL=C awk -v langs="$(languages)" "$AWK_PROGRAM" > "$README.tmp"
mv "$README.tmp" "$README"
