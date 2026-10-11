/**
 * Source-specific, offline importer for the Perugia Italian A1 HTML page.
 *
 * The output is a full reference catalogue, NOT a list of Wikidata matches.
 * It must remain a local artifact until the source's redistribution terms
 * have been clarified. No network requests are performed by this module.
 */
module wikidata.perugia_import;

import std.algorithm.searching : canFind;
import std.conv : to;
import std.exception : enforce;
import std.format : format;
import std.json : JSONValue;
import std.string : indexOf, replace, splitLines, strip;

struct PerugiaRow
{
    size_t number;
    string lemma;           /// Exact visible source text, except HTML entities.
    string annotation;      /// Text between </a> and <br>, including parentheses.
    string rawLine;         /// Original HTML row for local auditing.
}

private string decodeBasicEntities(string value)
{
    // This page is UTF-8. Do not attempt an unsafe generic HTML rewrite.
    // Unknown entities are retained verbatim and flagged for review.
    return value.replace("&nbsp;", " ")
        .replace("&#160;", " ")
        .replace("&amp;", "&")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&#39;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">");
}

/** Extract the numbered source rows. This deliberately does not infer lemmas
 * from other page elements, and does not drop rows with unusual annotations.
 */
PerugiaRow[] parsePerugiaHtml(string html)
{
    PerugiaRow[] rows;
    foreach (line; html.splitLines())
    {
        const anchorIndex = line.indexOf("<a ");
        if (anchorIndex < 0)
            continue;

        const before = line[0 .. cast(size_t) anchorIndex].strip;
        if (before.length < 2 || before[$ - 1] != '.')
            continue;

        // Require a decimal source position immediately before the anchor.
        size_t firstDigit = before.length - 1;
        while (firstDigit > 0 &&
               before[firstDigit - 1] >= '0' &&
               before[firstDigit - 1] <= '9')
            --firstDigit;
        if (firstDigit == before.length - 1)
            continue;

        const number = to!size_t(before[firstDigit .. $ - 1]);
        const rest = line[cast(size_t) anchorIndex .. $];
        const openEnd = rest.indexOf(">");
        const closeStart = rest.indexOf("</a>");
        if (openEnd < 0 || closeStart < 0 || closeStart <= openEnd)
            continue;

        const after = rest[cast(size_t) closeStart + 4 .. $];
        const endOfRow = after.indexOf("<br");
        if (endOfRow < 0)
            continue;

        PerugiaRow row;
        row.number = number;
        row.lemma = decodeBasicEntities(
            rest[cast(size_t) openEnd + 1 .. cast(size_t) closeStart].strip);
        row.annotation = decodeBasicEntities(
            after[0 .. cast(size_t) endOfRow].strip);
        row.rawLine = line;
        enforce(row.lemma.length != 0,
            "Empty Perugia lemma at position " ~ to!string(number));
        rows ~= row;
    }
    return rows;
}

/** Fail closed on incomplete, duplicated, reordered or changed source lists. */
void validatePerugiaRows(const(PerugiaRow)[] rows, size_t expectedCount = 486)
{
    enforce(rows.length == expectedCount,
        format("Expected %s Perugia rows, found %s", expectedCount,
            rows.length));
    foreach (index, row; rows)
        enforce(row.number == index + 1,
            format("Unexpected source number at row %s: %s", index + 1,
                row.number));
}

/**
 * Source-specific POS hints. The source annotation remains authoritative and
 * unchanged; these IDs merely constrain Wikidata Lexeme lookup candidates.
 * Wikidata sometimes uses finer lexical categories (notably pronouns). The
 * eventual coverage report must distinguish a POS-limited miss from a true
 * missing Lexeme.
 */
private string[] categoriesForAnnotation(string original)
{
    const pos = original.replace("–", "-").replace("—", "-")
                        .replace(" ", "").replace("(", "")
                        .replace(")", "");

    // Italian locative pronominal particles are not reliably equivalent to
    // one of the broad Wikidata lexical classes. Keep this case under review.
    if (pos.canFind("part.pron.luogo"))
        return null;

    string[] result;
    if (pos.canFind("s.m") || pos.canFind("s.f"))
        result ~= "Q1084";   // noun
    if (pos.canFind("agg."))
        result ~= "Q34698";  // adjective
    if (pos.indexOf("v.") == 0 || pos.canFind("-v."))
        result ~= "Q24905";  // verb
    if (pos.canFind("avv."))
        result ~= "Q380057"; // adverb
    // `v.int. pron.` denotes a pronominal verb, not a second POS "pronoun".
    if (pos.canFind("pron.") && !pos.canFind("v.int.pron.") &&
        !pos.canFind("v.t.pron."))
        result ~= "Q36224";  // pronoun (generic; Wikidata has subtypes)
    if (pos.canFind("inter."))
        result ~= "Q83034";  // interjection
    if (pos.canFind("art."))
        result ~= "Q103184"; // article
    if (pos.canFind("prep."))
        result ~= "Q4833830"; // preposition
    if (pos.canFind("cong."))
        result ~= "Q36484";  // conjunction
    return result;
}

/**
 * Reviewed orthographic search variants for the *source positions* identified
 * in Perugia A1. These are not new catalogue rows and do not change Wikidata.
 * Source spelling is checked before applying any entry-specific expansion.
 * Unknown/changed spellings are kept as-is and marked for review.
 */
private string[] explicitSourceVariants(const ref PerugiaRow row)
{
    switch (row.number)
    {
    case 6:
        if (row.lemma == "aereo(aeroplano)") return ["aereo", "aeroplano"];
        break;
    case 18:
        if (row.lemma == "amico/a") return ["amico", "amica"];
        break;
    case 43:
        if (row.lemma == "bambino/a") return ["bambino", "bambina"];
        break;
    case 51:
        if (row.lemma == "bici(cletta)") return ["bici", "bicicletta"];
        break;
    case 69:
        if (row.lemma == "cameriere/a") return ["cameriere", "cameriera"];
        break;
    case 95:
        if (row.lemma == "chiamare/si") return ["chiamare", "chiamarsi"];
        break;
    case 112:
        if (row.lemma == "compagno/a") return ["compagno", "compagna"];
        break;
    case 146:
        if (row.lemma == "dottore/ssa") return ["dottore", "dottoressa"];
        break;
    case 171:
        if (row.lemma == "figlio/a") return ["figlio", "figlia"];
        break;
    case 286:
        if (row.lemma == "moto(cicletta)") return ["moto", "motocicletta"];
        break;
    case 301:
        if (row.lemma == "nonno/a") return ["nonno", "nonna"];
        break;
    case 344:
        if (row.lemma == "poco (po’)") return ["poco", "po'", "po’"];
        break;
    case 361:
        if (row.lemma == "professore/ssa")
            return ["professore", "professoressa"];
        break;
    case 375:
        if (row.lemma == "ragazzo/a") return ["ragazzo", "ragazza"];
        break;
    case 406:
        if (row.lemma == "signore/a") return ["signore", "signora"];
        break;
    case 432:
        if (row.lemma == "studente/ssa") return ["studente", "studentessa"];
        break;
    case 460:
        if (row.lemma == "un/o/a") return ["un", "uno", "una"];
        break;
    default:
        break;
    }
    return null;
}

private bool complexSourceLemma(string lemma)
{
    return lemma.canFind("/") || lemma.canFind("(") ||
           lemma.canFind(")") || lemma.canFind("<") ||
           lemma.canFind("&");
}

/** Build an M5.1-compatible catalogue without touching or filtering source
 * rows. More complex orthographies are marked for subsequent normalization.
 */
JSONValue buildPerugiaCatalog(const(PerugiaRow)[] rows)
{
    validatePerugiaRows(rows);

    JSONValue document = JSONValue.emptyObject;
    document["schemaVersion"] = 1;
    document["id"] = "it-A1-perugia";
    document["languageCode"] = "it";
    document["languageEntityId"] = "Q652";
    document["level"] = "A1";

    JSONValue origin = JSONValue.emptyObject;
    origin["name"] = "Università per Stranieri di Perugia — Profilo della lingua italiana";
    origin["url"] = "https://www.unistrapg.it/profilo_lingua_italiana/site/liste_lessicali_a1.html";
    origin["redistribution"] = "rights-review-required";
    document["source"] = origin;

    JSONValue allEntries = JSONValue.emptyArray;
    foreach (row; rows)
    {
        JSONValue entry = JSONValue.emptyObject;
        entry["id"] = format("perugia-it-A1-%04d", cast(int) row.number);
        entry["lemma"] = row.lemma;
        entry["sourcePosition"] = cast(long) row.number;
        entry["sourceAnnotation"] = row.annotation;
        entry["sourcePartOfSpeech"] = row.annotation;
        entry["sourceHtml"] = row.rawLine;

        const categories = categoriesForAnnotation(row.annotation);
        const variants = explicitSourceVariants(row);
        const searchLemmas = variants.length ? variants : [row.lemma];
        JSONValue targets = JSONValue.emptyArray;
        foreach (searchLemma; searchLemmas)
        {
            if (categories.length == 0)
            {
                JSONValue target = JSONValue.emptyObject;
                target["lemma"] = searchLemma;
                targets.array ~= target;
            }
            else
            {
                foreach (category; categories)
                {
                    JSONValue target = JSONValue.emptyObject;
                    target["lemma"] = searchLemma;
                    target["lexicalCategoryId"] = category;
                    targets.array ~= target;
                }
            }
        }
        entry["lookupTargets"] = targets;

        JSONValue reasons = JSONValue.emptyArray;
        if (complexSourceLemma(row.lemma) && variants.length == 0)
            reasons.array ~= JSONValue("complex-source-lemma");
        if (categories.length == 0)
            reasons.array ~= JSONValue("pos-mapping-unresolved");
        if (row.annotation.length == 0 || row.annotation.canFind("&"))
            reasons.array ~= JSONValue("source-annotation-review");
        entry["reviewReasons"] = reasons;
        allEntries.array ~= entry;
    }
    document["entries"] = allEntries;
    return document;
}

unittest
{
    import std.exception : assertThrown;
    import wikidata.catalog : parseCatalog;

    assert(categoriesForAnnotation("(avv.)")[0] == "Q380057");
    assert(categoriesForAnnotation("(pron.)")[0] == "Q36224");
    assert(categoriesForAnnotation("(inter.)")[0] == "Q83034");
    assert(categoriesForAnnotation("(art.)")[0] == "Q103184");
    assert(categoriesForAnnotation("(prep.)")[0] == "Q4833830");
    assert(categoriesForAnnotation("(cong.)")[0] == "Q36484");
    assert(categoriesForAnnotation("(agg.)")[0] == "Q34698");
    assert(categoriesForAnnotation("(v.int. - s.m.)").length == 2);
    assert(categoriesForAnnotation("(v.t. – v.int. pron.)").length == 1);
    assert(categoriesForAnnotation("(v.t. – v.int. pron.)")[0] == "Q24905");
    assert(categoriesForAnnotation("(pron. - avv.)").length == 2);
    assert(categoriesForAnnotation("(avv. - cong.)").length == 2);
    assert(categoriesForAnnotation("(prep.- avv.)").length == 2);
    assert(categoriesForAnnotation("(part. pron. luogo)").length == 0);

    // Three representative HTML source rows, using real source formatting.
    enum fixture =
        ` 18. <a href="#" onClick="x()">amico/a</a> (s.m. – s.f.)<br>` ~ "\n" ~
        ` 19. <a href="#" onClick="x()">amore</a> (s.m)<br>` ~ "\n" ~
        ` 20. <a href="#" onClick="x()">anche</a> (cong.)<br>`;
    auto rows = parsePerugiaHtml(fixture);
    assert(rows.length == 3);
    assert(rows[0].number == 18);
    assert(rows[0].lemma == "amico/a");
    assert(rows[0].annotation == "(s.m. – s.f.)");
    assert(rows[1].lemma == "amore");
    assertThrown!Exception(validatePerugiaRows(rows));

    // Number integrity is checked without filtering or correcting the input.
    rows[0].number = 1;
    rows[1].number = 2;
    rows[2].number = 3;
    validatePerugiaRows(rows, 3);
    rows[2].number = 2;
    assertThrown!Exception(validatePerugiaRows(rows, 3));

    // Existing catalogue parser receives a normal M5.1 schema document.
    // Full catalog generation enforces 486 rows, so test the producer in its
    // own integration exercise with the downloaded reference HTML.
    auto basic = parseCatalog(`{"schemaVersion":1,"id":"it-A1-demo",
        "languageCode":"it","languageEntityId":"Q652","level":"A1",
        "source":{},"entries":[{"id":"01","lemma":"gatto",
        "lookupTargets":[{"lemma":"gatto","lexicalCategoryId":"Q1084"}]}]}`);
    assert(basic.entries.length == 1);

    PerugiaRow[] complete;
    foreach (n; 1 .. 487)
    {
        PerugiaRow row;
        row.number = cast(size_t) n;
        row.lemma = "word" ~ to!string(n);
        row.annotation = "(s.m.)";
        row.rawLine = "fixture";
        complete ~= row;
    }
    complete[17].lemma = "amico/a";
    complete[17].annotation = "(s.m. – s.f.)";
    complete[183].lemma = "gatto";
    complete[293].lemma = "nero";
    complete[293].annotation = "(agg.)";
    complete[333].lemma = "piacere";
    complete[333].annotation = "(v.int. - s.m.)";

    auto output = buildPerugiaCatalog(complete);
    auto parsed = parseCatalog(output);
    assert(parsed.entries.length == 486);
    assert(parsed.entries[17].lemma == "amico/a");
    assert(output["entries"][17]["reviewReasons"].array.length == 0);
    assert(parsed.entries[17].lookupTargets.length == 2);
    assert(parsed.entries[17].lookupTargets[1].lemma == "amica");
    assert(parsed.entries[293].lookupTargets[0].lexicalCategoryId ==
        "Q34698");
    assert(parsed.entries[333].lookupTargets.length == 2);

    // Every reviewed complex source form expands into explicit search targets.
    struct Example { size_t number; string source; string[] expected; }
    Example[] cases = [
        Example(6, "aereo(aeroplano)", ["aereo", "aeroplano"]),
        Example(18, "amico/a", ["amico", "amica"]),
        Example(43, "bambino/a", ["bambino", "bambina"]),
        Example(51, "bici(cletta)", ["bici", "bicicletta"]),
        Example(69, "cameriere/a", ["cameriere", "cameriera"]),
        Example(95, "chiamare/si", ["chiamare", "chiamarsi"]),
        Example(112, "compagno/a", ["compagno", "compagna"]),
        Example(146, "dottore/ssa", ["dottore", "dottoressa"]),
        Example(171, "figlio/a", ["figlio", "figlia"]),
        Example(286, "moto(cicletta)", ["moto", "motocicletta"]),
        Example(301, "nonno/a", ["nonno", "nonna"]),
        Example(344, "poco (po’)", ["poco", "po'", "po’"]),
        Example(361, "professore/ssa", ["professore", "professoressa"]),
        Example(375, "ragazzo/a", ["ragazzo", "ragazza"]),
        Example(406, "signore/a", ["signore", "signora"]),
        Example(432, "studente/ssa", ["studente", "studentessa"]),
        Example(460, "un/o/a", ["un", "uno", "una"])
    ];
    assert(cases.length == 17);
    foreach (c; cases)
    {
        PerugiaRow variantRow;
        variantRow.number = c.number;
        variantRow.lemma = c.source;
        auto got = explicitSourceVariants(variantRow);
        assert(got == c.expected);
        // No accidental expansion if the university changes source spelling.
        variantRow.lemma = "source changed";
        assert(explicitSourceVariants(variantRow).length == 0);
    }
    PerugiaRow special;
    special.number = 460;
    special.lemma = "un/o/a";
    special.annotation = "(art.)";
    complete[459] = special;
    auto refreshed = buildPerugiaCatalog(complete);
    assert(refreshed["entries"][459]["lookupTargets"].array.length == 3);
    assert(refreshed["entries"][459]["lookupTargets"].array[0]
        ["lexicalCategoryId"].str == "Q103184");
    assert(refreshed["entries"][459]["reviewReasons"].array.length == 0);
}
