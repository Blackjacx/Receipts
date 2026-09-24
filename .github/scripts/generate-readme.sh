#!/usr/bin/env bash
#
# Generates the recipe indexes from the recipes in Recipes/<language>.
#
# Recipes are grouped by the total time given in their duration section
# ("## Dauer" in German, "## Duration" in English, "## Durée" in French)
# into three categories: quick, medium and long. Each language gets its own
# index, written in that language, next to its recipes:
#
#   Recipes/de  ->  Recipes/de/README.md (German)
#   Recipes/en  ->  Recipes/en/README.md (English)
#   Recipes/fr  ->  Recipes/fr/README.md (French)
#
# The main README.md is a short German landing page that links to the index
# of every language.
#
# Runs automatically via .github/workflows/readme.yml on every push to
# main, and can also be run locally:
#
#     .github/scripts/generate-readme.sh
#
# Requires only bash and awk (GNU awk, mawk or BSD awk).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Languages that have index labels in the awk program below.
SUPPORTED="de en fr"

# Every subfolder of Recipes/ is one language, e.g. "de", "en" and "fr".
languages() {
    local d
    for d in "$ROOT/Recipes"/*/; do
        [ -d "$d" ] || continue
        d="${d%/}"
        printf '%s ' "${d##*/}"
    done
}

# Languages that get an index: present as a folder and supported.
indexed_languages() {
    local lang
    for lang in $(languages); do
        case " $SUPPORTED " in *" $lang "*) printf '%s ' "$lang" ;; esac
    done
}

# Each recipe is preceded by a marker line so awk can tell files apart even
# when a file is empty or lacks a trailing newline. README.md files are the
# generated indexes, not recipes.
emit_recipes() {
    local f
    for f in "$1"/*.md; do
        [ -e "$f" ] || continue
        [ "${f##*/}" = "README.md" ] && continue
        printf '\001FILE\t%s\n' "${f##*/}"
        cat "$f"
        printf '\n'
    done
}

read -r -d '' AWK_PROGRAM <<'AWK' || true
BEGIN {
    for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i

    NUM  = "([0-9]+/[0-9]+|½|[0-9]+([.,][0-9]+)?)"
    UNIT = "(minuten|minute|minutes|mins|min\\.?|stunden|stunde|std\\.?|hours|hour|hrs|hr|heures|heure|h|tage|tag|days|day|jours|jour|nächte|nacht|nights|night|nuits|nuit|wochen|woche|weeks|week|semaines|semaine)"
    TOKEN = NUM "([ \t]*(-|–)[ \t]*" NUM ")?[ \t]*" UNIT

    unitmin["min"] = 1; unitmin["std"] = 60; unitmin["tag"] = 1440
    unitmin["nacht"] = 600; unitmin["woche"] = 10080

    flag["de"] = "🇩🇪"; flag["en"] = "🇬🇧"; flag["fr"] = "🇫🇷"; flag["es"] = "🇪🇸"; flag["it"] = "🇮🇹"

    ncat = 3
    catlimit[1] = 30; catlimit[2] = 60; catlimit[3] = -1

    if (ui == "en") {
        HEADING = "## Duration"; AND = "and"; RANGE = "to"
        catname[1] = "Quick";  catdesc[1] = "up to 30 min"
        catname[2] = "Medium"; catdesc[2] = "up to 1 h"
        catname[3] = "Long";   catdesc[3] = "over 1 h"
        nodur = "Without duration"; nodur_anchor = "without-duration"
        unitlabel["min"] = "min"; unitlabel["std"] = "h"
        unitlabel["tag"] = "day"; unitplural["tag"] = "days"
        unitlabel["nacht"] = "night"; unitplural["nacht"] = "nights"
        unitlabel["woche"] = "week"; unitplural["woche"] = "weeks"
        langname["de"] = "German"; langname["en"] = "English"
        langname["fr"] = "French"; langname["es"] = "Spanish"; langname["it"] = "Italian"
        GENERATED = "<!-- This file is generated automatically by .github/scripts/generate-readme.sh. Manual changes will be overwritten on the next push. -->"
        TITLE = "# Recipes"
        INTRO = "All English recipes, grouped by preparation time."
        ALSO = " Also available in: "
        BACK = " Back to the [home page](../../README.md)."
        SECTION = "## Recipes by preparation time"
        EXPLAIN = "Recipes are grouped by their **total time** – including baking, cooking, resting, soaking and infusing. A salad that has to sit overnight therefore counts as \"Long\", even if the actual work only takes 15 minutes."
        OVERVIEW = "| Category | Total time | Count |"
        COLRECIPE = "Recipe"; COLDURATION = "Duration"
        NODURTEXT = "These recipes don't have a `" HEADING "` section yet."
        FOOTER = "This list is updated automatically on every push to `main`. The times come from the `" HEADING "` section of each recipe."
    } else if (ui == "fr") {
        HEADING = "## Durée"; AND = "et"; RANGE = "à"
        catname[1] = "Rapide"; catdesc[1] = "jusqu'à 30 min"
        catname[2] = "Moyen";  catdesc[2] = "jusqu'à 1 h"
        catname[3] = "Long";   catdesc[3] = "plus d'1 h"
        nodur = "Sans durée"; nodur_anchor = "sans-durée"
        unitlabel["min"] = "min"; unitlabel["std"] = "h"
        unitlabel["tag"] = "jour"; unitplural["tag"] = "jours"
        unitlabel["nacht"] = "nuit"; unitplural["nacht"] = "nuits"
        unitlabel["woche"] = "semaine"; unitplural["woche"] = "semaines"
        langname["de"] = "allemand"; langname["en"] = "anglais"
        langname["fr"] = "français"; langname["es"] = "espagnol"; langname["it"] = "italien"
        GENERATED = "<!-- Ce fichier est généré automatiquement par .github/scripts/generate-readme.sh. Les modifications manuelles seront écrasées au prochain push. -->"
        TITLE = "# Recettes"
        INTRO = "Toutes les recettes en français, classées par durée de préparation."
        ALSO = " Aussi disponible en : "
        BACK = " Retour à la [page d'accueil](../../README.md)."
        SECTION = "## Recettes par durée de préparation"
        EXPLAIN = "Le classement se fait selon la **durée totale**, cuisson, repos, trempage et infusion compris. Une salade qui doit reposer toute une nuit est donc classée « Long », même si la préparation proprement dite ne prend que 15 minutes."
        OVERVIEW = "| Catégorie | Durée totale | Nombre |"
        COLRECIPE = "Recette"; COLDURATION = "Durée"
        NODURTEXT = "Ces recettes n'ont pas encore de section `" HEADING "`."
        FOOTER = "Cette liste est mise à jour automatiquement à chaque push sur `main`. Les durées proviennent de la section `" HEADING "` de chaque recette."
    } else {
        HEADING = "## Dauer"; AND = "und"; RANGE = "bis"
        catname[1] = "Schnell"; catdesc[1] = "bis 30 Min."
        catname[2] = "Mittel";  catdesc[2] = "bis 1 Std."
        catname[3] = "Lang";    catdesc[3] = "über 1 Std."
        nodur = "Ohne Zeitangabe"; nodur_anchor = "ohne-zeitangabe"
        unitlabel["min"] = "Min."; unitlabel["std"] = "Std."
        unitlabel["tag"] = "Tag"; unitplural["tag"] = "Tage"
        unitlabel["nacht"] = "Nacht"; unitplural["nacht"] = "Nächte"
        unitlabel["woche"] = "Woche"; unitplural["woche"] = "Wochen"
        langname["de"] = "Deutsch"; langname["en"] = "Englisch"
        langname["fr"] = "Französisch"; langname["es"] = "Spanisch"; langname["it"] = "Italienisch"
        GENERATED = "<!-- Diese Datei wird automatisch von .github/scripts/generate-readme.sh erzeugt. Änderungen von Hand werden beim nächsten Push überschrieben. -->"
        TITLE = "# Rezepte"
        INTRO = "Alle deutschen Rezepte, eingeteilt nach Zubereitungsdauer."
        ALSO = " Auch verfügbar auf: "
        BACK = " Zurück zur [Startseite](../../README.md)."
        SECTION = "## Rezepte nach Zubereitungsdauer"
        EXPLAIN = "Eingeteilt wird nach der **Gesamtzeit** – also inklusive Back-, Koch-, Ruhe-, Einweich- und Ziehzeiten. Ein Salat, der über Nacht durchziehen muss, landet deshalb bei „Lang\", auch wenn die eigentliche Arbeit nur 15 Minuten dauert."
        OVERVIEW = "| Kategorie | Gesamtzeit | Anzahl |"
        COLRECIPE = "Rezept"; COLDURATION = "Dauer"
        NODURTEXT = "Diese Rezepte haben noch keinen Abschnitt `" HEADING "`."
        FOOTER = "Die Liste wird bei jedem Push auf `main` automatisch aktualisiert. Die Zeiten stammen aus dem Abschnitt `" HEADING "` des jeweiligen Rezepts."
    }
    unitplural["min"] = unitlabel["min"]; unitplural["std"] = unitlabel["std"]

    nlang = split(langs, lang, " ")
    nindexed = split(indexed, idx, " ")
    for (i = 1; i <= nindexed; i++) isindexed[idx[i]] = 1

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
    if (u == "h" || u ~ /^(std|stunde|hour|hr|heure)/) return "std"
    if (u ~ /^(tag|day|jour)/) return "tag"
    if (u ~ /^(nacht|nächte|night|nuit)/) return "nacht"
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

function normtoken(tok,    key, val) {
    splittoken(tok)
    key = unitkey(TU)
    val = numval(TB != "" ? TB : TA)
    return numfmt(TA) (TB != "" ? "–" numfmt(TB) : "") " " (val > 1 ? unitplural[key] : unitlabel[key])
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
    if (match(low, "[ \t]+(-|–|" RANGE ")[ \t]+")) s = substr(s, 1, RSTART - 1)
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
    gsub(/ - /, " " RANGE " ", out)
    return out
}

function finish(    text, parts, np, i, p, c, total, shown) {
    if (file == "") return
    text = dauer
    gsub(/<br[ \t]*\/?>/, "\n", text)
    gsub("[ \t]+" AND "[ \t]+", "\n", text)
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
!seen && $0 ~ ("^" HEADING "[ \t]*$") { insec = 1; seen = 1; next }
insec { dauer = dauer $0 "\n" }

function before(a, b) {
    if (rmin[a] != rmin[b]) return rmin[a] < rmin[b]
    return (tolower(rtitle[a]) "") < (tolower(rtitle[b]) "")
}

function row(i, withtime,    link) {
    link = "[" rtitle[i] "](" urlencode(rfile[i]) ")"
    return withtime ? "| " link " | " rshown[i] " |" : "| " link " |"
}

function table(c, withtime,    out, k) {
    out = withtime ? "| " COLRECIPE " | " COLDURATION " |\n|---|---|" : "| " COLRECIPE " |\n|---|"
    for (k = 1; k <= cnt[c]; k++) out = out "\n" row(member[c, k], withtime)
    return out
}

# Link from this index to the index (or, without one, the folder) of language l.
function indexlink(l) {
    return "../" l (l in isindexed ? "/README.md" : "")
}

END {
    finish()

    for (i = 1; i <= n; i++) {
        if (titlecount[rtitle[i]] > 1) {
            stem = rfile[i]; sub(/\.md$/, "", stem)
            rtitle[i] = rtitle[i] " (" stem ")"
        }
    }

    # Category 4 = recipes without a duration
    for (c = 1; c <= 4; c++) cnt[c] = 0
    for (i = 1; i <= n; i++) {
        if (rmin[i] <= 0) c = 4
        else for (c = 1; c <= ncat; c++) if (catlimit[c] < 0 || rmin[i] <= catlimit[c]) break
        k = ++cnt[c]
        # insertion sort: by minutes, then by title
        while (k > 1 && before(i, member[c, k - 1])) { member[c, k] = member[c, k - 1]; k-- }
        member[c, k] = i
    }

    # Flag bar with a link to every language index, shown top right
    flags = ""
    for (i = 1; i <= nlang; i++)
        flags = flags (flags == "" ? "" : "&emsp;") "<a href=\"" indexlink(lang[i]) "\" title=\"" \
                (lang[i] in langname ? langname[lang[i]] : lang[i]) "\">" \
                (lang[i] in flag ? flag[lang[i]] : lang[i]) "</a>"

    # Links to the other languages and back to the landing page
    others = ""
    for (i = 1; i <= nlang; i++) if (lang[i] != ui)
        others = others (others == "" ? "" : " · ") "[" (lang[i] in langname ? langname[lang[i]] : lang[i]) "](" indexlink(lang[i]) ")"

    print GENERATED
    print ""
    print "<h3 align=\"right\">" flags "</h3>"
    print ""
    print TITLE
    print ""
    print INTRO (others != "" ? ALSO others "." : "") BACK
    print ""
    print SECTION
    print ""
    print EXPLAIN
    print ""
    print OVERVIEW
    print "|---|---|---|"
    for (c = 1; c <= ncat; c++)
        print "| [" catname[c] "](#" tolower(catname[c]) ") | " catdesc[c] " | " cnt[c] " |"
    if (cnt[4]) print "| [" nodur "](#" nodur_anchor ") | – | " cnt[4] " |"
    print ""
    for (c = 1; c <= ncat; c++) {
        if (c > 1) print ""
        print "### " catname[c]
        print ""
        print table(c, 1)
    }
    if (cnt[4]) {
        print ""
        print "### " nodur
        print ""
        print NODURTEXT
        print ""
        print table(4, 0)
    }
    print ""
    print "---"
    print ""
    print FOOTER

    print outname " written: " cnt[1] " quick, " cnt[2] " medium, " cnt[3] " long, " cnt[4] " without duration" | "cat 1>&2"
}
AWK

# generate_index <language>: writes Recipes/<language>/README.md
generate_index() {
    local out="$ROOT/Recipes/$1/README.md"
    emit_recipes "$ROOT/Recipes/$1" | LC_ALL=C awk \
        -v ui="$1" -v langs="$(languages)" -v indexed="$(indexed_languages)" \
        -v outname="${out#"$ROOT"/}" \
        "$AWK_PROGRAM" > "$out.tmp"
    mv "$out.tmp" "$out"
}

# Flag emoji of a language code, for the flag bar on the landing page.
language_flag() {
    case "$1" in
        de) echo "🇩🇪" ;; en) echo "🇬🇧" ;; fr) echo "🇫🇷" ;;
        es) echo "🇪🇸" ;; it) echo "🇮🇹" ;; *) echo "$1" ;;
    esac
}

# German display name of a language code, for the landing page.
language_name() {
    case "$1" in
        de) echo "Deutsch" ;; en) echo "Englisch" ;; fr) echo "Französisch" ;;
        es) echo "Spanisch" ;; it) echo "Italienisch" ;; *) echo "$1" ;;
    esac
}

# Link target of a language on the landing page: its index, or its folder
# if it has none.
landing_target() {
    case " $(indexed_languages) " in
        *" $1 "*) echo "Recipes/$1/README.md" ;;
        *) echo "Recipes/$1" ;;
    esac
}

# generate_landing_page: writes the German main README.md that links to the
# index of every language (or to the folder of a language without index).
generate_landing_page() {
    local lang flags="" out="$ROOT/README.md"
    for lang in $(languages); do
        [ -n "$flags" ] && flags="$flags&emsp;"
        flags="$flags<a href=\"$(landing_target "$lang")\" title=\"$(language_name "$lang")\">$(language_flag "$lang")</a>"
    done
    {
        echo "<!-- Diese Datei wird automatisch von .github/scripts/generate-readme.sh erzeugt. Änderungen von Hand werden beim nächsten Push überschrieben. -->"
        echo ""
        echo "<h3 align=\"right\">$flags</h3>"
        echo ""
        echo "# Recipes"
        echo ""
        echo "Unsere Rezeptsammlung. Jede Sprache hat eine eigene Übersicht, in der die Rezepte nach Zubereitungsdauer eingeteilt sind:"
        echo ""
        for lang in $(languages); do
            echo "- $(language_name "$lang"): [\`Recipes/$lang\`]($(landing_target "$lang"))"
        done
    } > "$out.tmp"
    mv "$out.tmp" "$out"
    echo "README.md written: landing page for $(languages | wc -w | tr -d ' ') language(s)" >&2
}

for lang in $(indexed_languages); do
    generate_index "$lang"
done
generate_landing_page
