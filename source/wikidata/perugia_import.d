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

private string[] categoriesForAnnotation(string original)
{
    // Only mappings already established from Wikidata in M1-M4.
    // Other parts of speech remain unrestricted search candidates.
    const pos = original.replace("–", "-").replace("—", "-")
                        .replace(" ", "").replace("(", "")
                        .replace(")", "");
    string[] result;
    if (pos.canFind("s.m") || pos.canFind("s.f"))
        result ~= "Q1084"; // noun
    if (pos.canFind("agg."))
        result ~= "Q34698"; // adjective
    if (pos.indexOf("v.") == 0 || pos.canFind("-v."))
        result ~= "Q24905"; // verb (v.t., v.int., ...)
    return result;
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
        JSONValue targets = JSONValue.emptyArray;
        if (categories.length == 0)
        {
            JSONValue target = JSONValue.emptyObject;
            target["lemma"] = row.lemma;
            targets.array ~= target;
        }
        else
        {
            foreach (category; categories)
            {
                JSONValue target = JSONValue.emptyObject;
                target["lemma"] = row.lemma;
                target["lexicalCategoryId"] = category;
                targets.array ~= target;
            }
        }
        entry["lookupTargets"] = targets;

        JSONValue reasons = JSONValue.emptyArray;
        if (row.lemma.canFind("/") || row.lemma.canFind("(") ||
            row.lemma.canFind(")") || row.lemma.canFind("<") ||
            row.lemma.canFind("&"))
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

    assert(categoriesForAnnotation("(avv.)").length == 0);
    assert(categoriesForAnnotation("(agg.)")[0] == "Q34698");
    assert(categoriesForAnnotation("(v.int. - s.m.)").length == 2);

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
    assert(output["entries"][17]["reviewReasons"].array.length > 0);
    assert(parsed.entries[293].lookupTargets[0].lexicalCategoryId ==
        "Q34698");
    assert(parsed.entries[333].lookupTargets.length == 2);
}
