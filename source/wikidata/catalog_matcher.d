/**
 * Exact catalogue-to-Wikidata Lexeme candidate matching.
 * Query results do not alter the catalogue and do not assign A1 to Senses.
 */
module wikidata.catalog_matcher;

import std.algorithm.searching : canFind, startsWith;
import std.exception : enforce;
import std.json : JSONValue, JSONType, parseJSON;
import wikidata.catalog : VocabularyCatalog;
import wikidata.lexical_categories : CategoryCompatibility;
import wikidata.query : buildLexemeQuery, isEntityId;
import wikidata.relations : isSenseId;

/**
 * One bounded group of distinct lemma spellings and its SPARQL query.
 *
 * Execute $(D sparql) once, then pass the complete response for this batch
 * to $(D matchCatalog). The source catalogue is not changed.
 * See_Also: buildCatalogLookupBatches, matchCatalog
 */
struct CatalogLookupBatch
{
    string[] lemmas; /// Unique lookup spellings in this batch, in source order.
    string sparql; /// Ready-to-execute query text; no request has been sent.
}

/**
 * One matching Wikidata Lexeme candidate, not a verified translation.
 *
 * The candidate retains its Lexeme and Sense IDs separately. Multiple
 * Senses do not create multiple Lexeme candidates.
 * See_Also: CatalogMatch, matchCatalogWithCategories
 */
struct LexemeCandidate
{
    string lexemeId; /// Lexeme entity identifier, such as L5577.
    string lexicalCategoryId; /// Wikidata part-of-speech Q-ID.
    string[] senseIds; /// Sense IDs returned for this Lexeme, possibly empty.
    string matchMethod; /// "exact" or "subclass"; may be empty for legacy data.
}

/**
 * Number-of-candidates outcome for one original catalogue entry.
 *
 * A $(D noMatch) value describes the supplied complete query results, not
 * proof that a word or Sense is absent from all of Wikidata.
 */
enum CatalogMatchStatus
{
    noMatch, /// No acceptable candidate in the supplied complete results.
    matched, /// Exactly one acceptable Lexeme candidate.
    multipleCandidates /// More than one acceptable Lexeme candidate.
}

/**
 * Lookup outcome for one unchanged source-catalogue entry.
 *
 * Results preserve the source order and retain entries with no match.
 * See_Also: matchCatalog, CatalogMatchStatus
 */
struct CatalogMatch
{
    string catalogEntryId; /// Original source entry ID.
    CatalogMatchStatus status; /// Outcome based on candidate count.
    LexemeCandidate[] candidates; /// All acceptable Lexeme candidates.
}

/**
 * Prepare bounded SPARQL lookup queries for a complete vocabulary catalogue.
 *
 * Identical lookup spellings are queried only once even when several source
 * entries use them. The catalogue itself is neither filtered nor modified.
 * An empty set of lookup targets produces an empty batch array.
 *
 * Params:
 *   catalog = Independent catalogue containing lookup targets.
 *   batchSize = Maximum distinct spellings per query, from 1 to 100;
 *               defaults to 20.
 * Returns: Ordered query batches for execution by a separate Wikidata client.
 * Throws: $(D Exception) for an invalid batch size or invalid query input.
 * Notes: No network request occurs here. Preserve one complete successful
 *        response per returned batch when calling $(D matchCatalog).
 * See_Also: matchCatalog, CatalogLookupBatch
 */
CatalogLookupBatch[] buildCatalogLookupBatches(
    ref const VocabularyCatalog catalog, size_t batchSize = 20)
{
    enforce(batchSize >= 1 && batchSize <= 100, "Batch size must be 1..100");
    bool[string] seen;
    string[] lemmas;
    foreach (entry; catalog.entries)
        foreach (target; entry.lookupTargets)
            if ((target.lemma in seen) is null)
            {
                seen[target.lemma] = true;
                lemmas ~= target.lemma;
            }
    CatalogLookupBatch[] batches;
    for (size_t begin = 0; begin < lemmas.length; begin += batchSize)
    {
        size_t end = begin + batchSize;
        if (end > lemmas.length)
            end = lemmas.length;
        auto part = lemmas[begin .. end].dup;
        batches ~= CatalogLookupBatch(part,
            buildLexemeQuery(catalog.languageCode,
                catalog.languageEntityId, part));
    }
    return batches;
}

/// Read a required or optional SPARQL result binding value.
private string bindingValue(JSONValue row, string key, bool optional = false)
{
    enforce(row.type == JSONType.object, "Invalid result binding row");
    auto term = key in row.object;
    if (term is null && optional)
        return "";
    enforce(term !is null && (*term).type == JSONType.object,
        "Missing binding: " ~ key);
    auto value = "value" in (*term).object;
    enforce(value !is null && (*value).type == JSONType.string,
        "Invalid binding: " ~ key);
    return (*value).str;
}

/// Extract an identifier from an HTTP or HTTPS Wikidata entity URI.
private string entityId(string uri)
{
    enum http = "http://www.wikidata.org/entity/";
    enum https = "https://www.wikidata.org/entity/";
    if (uri.startsWith(http))
        return uri[http.length .. $];
    if (uri.startsWith(https))
        return uri[https.length .. $];
    throw new Exception("Invalid Wikidata entity URI: " ~ uri);
}

/// Internal pairing of a returned lemma and its Lexeme candidate.
private struct SearchHit
{
    string lemma;
    LexemeCandidate candidate;
}

/**
 * Match every original catalogue entry against complete Lexeme-query results.
 *
 * Use this after executing every batch from $(D buildCatalogLookupBatches).
 * A query failure must be handled by the caller, never replaced with an
 * invented empty result. Only matching lexical-category IDs are accepted;
 * known subclass relationships require $(D matchCatalogWithCategories).
 *
 * Params:
 *   catalog = Complete original catalogue; entries are not removed.
 *   batches = Query batches generated for that catalogue.
 *   responses = Parsed successful SPARQL JSON, one response per batch.
 * Returns: One match outcome per original entry, in catalogue order.
 * Throws: $(D Exception) for missing batches, malformed responses, invalid
 *         IDs or SPARQL bindings not requested by the relevant batch.
 * Notes: Candidates are Lexemes, not validated translations or assigned
 *        Senses. A $(D noMatch) result is relative to the supplied responses.
 * See_Also: buildCatalogLookupBatches, matchCatalogWithCategories
 */
CatalogMatch[] matchCatalog(
    ref const VocabularyCatalog catalog,
    const(CatalogLookupBatch)[] batches,
    JSONValue[] responses)
{
    CategoryCompatibility empty;
    return matchCatalogWithCategories(catalog, batches, responses, empty);
}

/**
 * Match catalogue entries using exact categories or supplied subclass evidence.
 *
 * Use this when a previously acquired $(D CategoryCompatibility) table can
 * accept a Wikidata lexical category below the catalogue's expected one.
 * For a given candidate, an exact match takes precedence over subclass
 * evidence. No new grammatical facts or Wikidata records are generated.
 *
 * Params:
 *   catalog = Unchanged source vocabulary catalogue.
 *   batches = Query batches for its exact lookup spellings.
 *   responses = One complete, valid SPARQL JSON response per batch.
 *   categories = Previously recorded category compatibility evidence.
 * Returns: A source-ordered result for every catalogue entry, including
 *          entries without accepted Lexeme candidates.
 * Throws: $(D Exception) for incomplete or invalid SPARQL results, invalid
 *         IDs or unexpected returned lemmas.
 * Notes: A missing relation is not proof of incompatibility in Wikidata.
 *        Duplicate Lexeme IDs are combined per catalogue entry and Sense
 *        IDs are retained; candidates remain unverified translations.
 * See_Also: matchCatalog, CategoryCompatibility, LexemeCandidate
 */
CatalogMatch[] matchCatalogWithCategories(
    ref const VocabularyCatalog catalog,
    const(CatalogLookupBatch)[] batches,
    JSONValue[] responses,
    ref const CategoryCompatibility categories)
{
    enforce(batches.length == responses.length,
        "One complete response is required per query batch");
    // Fail closed before computing matches. No result can be returned after a
    // malformed later batch, and no synthetic missing-lemma state is produced.
    // This pass retains only the already parsed JSONValue response graph.
    foreach (n, response; responses)
    {
        enforce(response.type == JSONType.object, "Invalid SPARQL response");
        auto results = "results" in response.object;
        enforce(results !is null && (*results).type == JSONType.object,
            "Missing SPARQL results");
        auto bindings = "bindings" in (*results).object;
        enforce(bindings !is null && (*bindings).type == JSONType.array,
            "Missing SPARQL bindings");
        foreach (row; (*bindings).array)
        {
            auto lemma = bindingValue(row, "lemma");
            enforce(batches[n].lemmas.canFind(lemma),
                "Result lemma not requested by this batch");
            auto lexemeId = entityId(bindingValue(row, "lexeme"));
            auto lexicalCategoryId = entityId(bindingValue(row, "category"));
            auto sense = bindingValue(row, "sense", true);
            string senseId;
            if (sense.length)
                senseId = entityId(sense);
            enforce(isEntityId(lexemeId) && lexemeId[0] == 'L',
                "Invalid Lexeme ID");
            enforce(isEntityId(lexicalCategoryId) && lexicalCategoryId[0] == 'Q',
                "Invalid POS ID");
            if (senseId.length)
                enforce(isSenseId(senseId), "Invalid Sense ID");
        }
    }

    // Preserve the full validation-first contract above. Each lemma owns
    // an insertion-ordered chain of catalogue entries, stored as links in
    // one contiguous array instead of an allocated array per lemma.
    struct EntryLink
    {
        size_t entryIndex;
        size_t next;
    }
    struct LemmaChain
    {
        size_t first;
        size_t last;
    }
    size_t maxLinks;
    foreach (entry; catalog.entries)
        maxLinks += entry.lookupTargets.length;
    EntryLink[] links;
    links.length = maxLinks;
    size_t linkCount;
    LemmaChain[string] entriesByLemma;
    foreach (entryIndex, entry; catalog.entries)
        foreach (target; entry.lookupTargets)
        {
            auto chain = target.lemma in entriesByLemma;
            if (chain is null)
            {
                links[linkCount] = EntryLink(entryIndex, size_t.max);
                entriesByLemma[target.lemma] = LemmaChain(linkCount, linkCount);
                ++linkCount;
            }
            else if (links[(*chain).last].entryIndex != entryIndex)
            {
                links[linkCount] = EntryLink(entryIndex, size_t.max);
                links[(*chain).last].next = linkCount;
                (*chain).last = linkCount;
                ++linkCount;
            }
        }

    // Preallocate the complete result array. Missing lemmas never remove or
    // reorder source entries, and SPARQL bindings are visited in source order.
    CatalogMatch[] matches;
    matches.length = catalog.entries.length;
    foreach (entryIndex, entry; catalog.entries)
        matches[entryIndex].catalogEntryId = entry.id;

    foreach (response; responses)
        foreach (row; response["results"]["bindings"].array)
        {
            SearchHit hit;
            hit.lemma = bindingValue(row, "lemma");
            hit.candidate.lexemeId = entityId(bindingValue(row, "lexeme"));
            hit.candidate.lexicalCategoryId = entityId(bindingValue(row, "category"));
            // Separate name from the later foreach(sense; candidate.senseIds).
            // DMD 2.111 rejects same-function lexical shadowing.
            auto senseBinding = bindingValue(row, "sense", true);
            if (senseBinding.length)
                hit.candidate.senseIds = [entityId(senseBinding)];
        auto chain = hit.lemma in entriesByLemma;
        if (chain is null)
            continue;
        for (size_t link = (*chain).first; link != size_t.max;
            link = links[link].next)
        {
            const entryIndex = links[link].entryIndex;
            auto match = &matches[entryIndex];
            // Preserve per-variant POS and exact-over-subclass precedence.
            bool targetMatches = false;
            string matchMethod;
            foreach (target; catalog.entries[entryIndex].lookupTargets)
            {
                if (target.lemma != hit.lemma)
                    continue;
                bool exact = target.lexicalCategoryId.length == 0 ||
                    target.lexicalCategoryId == hit.candidate.lexicalCategoryId;
                if (exact)
                {
                    targetMatches = true;
                    matchMethod = "exact";
                    break;
                }
                if (categories.compatible(hit.candidate.lexicalCategoryId,
                    target.lexicalCategoryId))
                {
                    targetMatches = true;
                    matchMethod = "subclass";
                }
            }
            if (!targetMatches)
                continue;
            size_t index = match.candidates.length;
            foreach (i, candidate; match.candidates)
                if (candidate.lexemeId == hit.candidate.lexemeId)
                {
                    index = i;
                    break;
                }
            if (index == match.candidates.length)
            {
                auto added = hit.candidate;
                added.matchMethod = matchMethod;
                match.candidates ~= added;
            }
            else
            {
                if (matchMethod == "exact")
                    match.candidates[index].matchMethod = "exact";
                foreach (sense; hit.candidate.senseIds)
                    if (!match.candidates[index].senseIds.canFind(sense))
                        match.candidates[index].senseIds ~= sense;
            }
        }
    }
    foreach (ref match; matches)
    {
        if (match.candidates.length == 1)
            match.status = CatalogMatchStatus.matched;
        else if (match.candidates.length > 1)
            match.status = CatalogMatchStatus.multipleCandidates;
        else
            match.status = CatalogMatchStatus.noMatch;
    }
    return matches;
}

///
unittest
{
    import wikidata.catalog : parseCatalog;
    import std.json : parseJSON;

    // All source entries survive; identical lemma targets share one query.
    auto catalog = parseCatalog(`{"schemaVersion":1,"id":"sample",
      "languageCode":"it","languageEntityId":"Q652","level":"A1",
      "source":{},"entries":[{"id":"1","lemma":"gatto"},
                             {"id":"2","lemma":"gatto"}]}`);
    auto batches = buildCatalogLookupBatches(catalog);
    assert(batches.length == 1 && batches[0].lemmas == ["gatto"]);

    // A valid empty response means no candidates in these specific results.
    JSONValue[] responses = [parseJSON(`{"results":{"bindings":[]}}`)];
    auto matches = matchCatalog(catalog, batches, responses);
    assert(matches.length == 2);
    assert(matches[0].status == CatalogMatchStatus.noMatch);
    assert(matches[1].status == CatalogMatchStatus.noMatch);
}

unittest
{
    import wikidata.catalog : parseCatalog;
    import std.exception : assertThrown;
    auto catalog = parseCatalog(`{
      "schemaVersion":1,"id":"it-A1-test","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},
      "entries":[
        {"id":"1","lemma":"nero","lexicalCategoryId":"Q34698"},
        {"id":"2","lemma":"nero","lexicalCategoryId":"Q1084"},
        {"id":"3","lemma":"gatto","lexicalCategoryId":"Q1084"},
        {"id":"4","lemma":"absent","lexicalCategoryId":"Q1084"}
      ]}`);
    auto batches = buildCatalogLookupBatches(catalog, 2);
    assert(batches.length == 2);
    assert(batches[0].lemmas.length == 2);
    assert(batches[0].lemmas[0] == "nero");
    assert(batches[0].lemmas[1] == "gatto");
    enum first = `{"results":{"bindings":[
      {"lemma":{"value":"nero"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L711417"},
       "category":{"value":"http://www.wikidata.org/entity/Q34698"},
       "sense":{"value":"http://www.wikidata.org/entity/L711417-S1"}},
      {"lemma":{"value":"nero"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L1219303"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"},
       "sense":{"value":"http://www.wikidata.org/entity/L1219303-S1"}},
      {"lemma":{"value":"nero"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L1219303"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"},
       "sense":{"value":"http://www.wikidata.org/entity/L1219303-S2"}},
      {"lemma":{"value":"gatto"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L5577"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"},
       "sense":{"value":"http://www.wikidata.org/entity/L5577-S1"}},
      {"lemma":{"value":"gatto"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L5577"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"},
       "sense":{"value":"http://www.wikidata.org/entity/L5577-S2"}}
    ]}}`;
    JSONValue[] answers = [parseJSON(first),
        parseJSON(`{"results":{"bindings":[]}}`)];
    auto mappings = matchCatalog(catalog, batches, answers);
    assert(mappings.length == 4); // The reference catalogue was not filtered.
    assert(mappings[0].status == CatalogMatchStatus.matched);
    assert(mappings[0].candidates[0].lexemeId == "L711417");
    assert(mappings[1].candidates[0].lexemeId == "L1219303");
    assert(mappings[1].candidates[0].senseIds.length == 2);
    assert(mappings[2].candidates[0].senseIds.length == 2);
    assert(mappings[3].status == CatalogMatchStatus.noMatch);
    assertThrown!Exception(matchCatalog(catalog, batches, answers[0 .. 1]));

    // A single source row may legitimately select two lexical categories.
    auto extended = parseCatalog(`{
      "schemaVersion":1,"id":"it-A1-extended","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},
      "entries":[
        {"id":"334","lemma":"piacere","lookupTargets":[
           {"lemma":"piacere","lexicalCategoryId":"Q24905"},
           {"lemma":"piacere","lexicalCategoryId":"Q1084"}]},
        {"id":"18","lemma":"amico/a","lookupTargets":[
           {"lemma":"amico","lexicalCategoryId":"Q1084"},
           {"lemma":"amica","lexicalCategoryId":"Q1084"}]}
      ]}`);
    auto expandedBatches = buildCatalogLookupBatches(extended, 20);
    assert(expandedBatches.length == 1);
    assert(expandedBatches[0].lemmas.length == 3);
    JSONValue[] expandedResponses = [parseJSON(`{"results":{"bindings":[
      {"lemma":{"value":"piacere"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L10"},
       "category":{"value":"http://www.wikidata.org/entity/Q24905"}},
      {"lemma":{"value":"piacere"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L11"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"}},
      {"lemma":{"value":"amico"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L12"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"}},
      {"lemma":{"value":"amica"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L13"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"}}
    ]}}`)];
    auto expanded = matchCatalog(extended, expandedBatches, expandedResponses);
    assert(expanded.length == 2);
    assert(expanded[0].candidates.length == 2);
    assert(expanded[1].candidates.length == 2);
}


unittest
{
    import std.json : parseJSON;
    import wikidata.catalog : parseCatalog;
    auto catalog = parseCatalog(`{"schemaVersion":1,"id":"test","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},"entries":[
      {"id":"one","lemma":"io","lexicalCategoryId":"Q36224"},
      {"id":"two","lemma":"i","lexicalCategoryId":"Q103184"}
    ]}`);
    auto batches = buildCatalogLookupBatches(catalog, 20);
    JSONValue[] responses = [parseJSON(`{"results":{"bindings":[
      {"lemma":{"value":"io"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L101"},
       "category":{"value":"http://www.wikidata.org/entity/Q468801"},
       "sense":{"value":"http://www.wikidata.org/entity/L101-S1"}},
      {"lemma":{"value":"i"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L102"},
       "category":{"value":"http://www.wikidata.org/entity/Q9788"}}
    ]}}`)];
    auto baseline = matchCatalog(catalog, batches, responses);
    assert(baseline[0].status == CatalogMatchStatus.noMatch);
    CategoryCompatibility compatibility;
    compatibility.add("Q468801", "Q36224");
    auto extended = matchCatalogWithCategories(catalog, batches,
        responses, compatibility);
    assert(extended[0].status == CatalogMatchStatus.matched);
    assert(extended[0].candidates[0].matchMethod == "subclass");
    assert(extended[0].candidates[0].senseIds == ["L101-S1"]);
    assert(extended[1].status == CatalogMatchStatus.noMatch);
}

// R1.14 production regression: reverse dispatch preserves complete results,
// per-entry deduplication, source order, exact POS and Sense order.
unittest
{
    import wikidata.catalog : parseCatalog;
    import std.exception : assertThrown;
    auto catalog = parseCatalog(`{
      "schemaVersion":1,"id":"index-edge","languageCode":"it",
      "languageEntityId":"Q652","level":"test","source":{},
      "entries":[
        {"id":"both","lemma":"uno","lookupTargets":[
          {"lemma":"uno","lexicalCategoryId":"Q1084"},
          {"lemma":"uno","lexicalCategoryId":"Q34698"},
          {"lemma":"uno","lexicalCategoryId":"Q1084"},
          {"lemma":"due","lexicalCategoryId":"Q1084"}]},
        {"id":"noun","lemma":"uno","lexicalCategoryId":"Q1084"},
        {"id":"absent","lemma":"assente","lexicalCategoryId":"Q1084"}
      ]}`);
    auto batches = buildCatalogLookupBatches(catalog, 1);
    assert(batches.length == 3);
    JSONValue[] answers = [
      parseJSON(`{"results":{"bindings":[
        {"lemma":{"value":"uno"},"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
         "category":{"value":"http://www.wikidata.org/entity/Q34698"},
         "sense":{"value":"http://www.wikidata.org/entity/L1-S2"}},
        {"lemma":{"value":"uno"},"lexeme":{"value":"http://www.wikidata.org/entity/L2"},
         "category":{"value":"http://www.wikidata.org/entity/Q1084"},
         "sense":{"value":"http://www.wikidata.org/entity/L2-S1"}},
        {"lemma":{"value":"uno"},"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
         "category":{"value":"http://www.wikidata.org/entity/Q34698"},
         "sense":{"value":"http://www.wikidata.org/entity/L1-S1"}}
      ]}}`),
      parseJSON(`{"results":{"bindings":[
        {"lemma":{"value":"due"},"lexeme":{"value":"http://www.wikidata.org/entity/L3"},
         "category":{"value":"http://www.wikidata.org/entity/Q1084"}}
      ]}}`),
      parseJSON(`{"results":{"bindings":[]}}`)
    ];
    auto result = matchCatalog(catalog, batches, answers);
    assert(result.length == 3);
    assert(result[0].catalogEntryId == "both");
    assert(result[0].status == CatalogMatchStatus.multipleCandidates);
    assert(result[0].candidates.length == 3);
    assert(result[0].candidates[0].lexemeId == "L1");
    assert(result[0].candidates[0].senseIds == ["L1-S2", "L1-S1"]);
    assert(result[0].candidates[1].lexemeId == "L2");
    assert(result[0].candidates[2].lexemeId == "L3");
    assert(result[1].catalogEntryId == "noun");
    assert(result[1].status == CatalogMatchStatus.matched);
    assert(result[1].candidates.length == 1);
    assert(result[1].candidates[0].lexemeId == "L2");
    assert(result[2].catalogEntryId == "absent");
    assert(result[2].status == CatalogMatchStatus.noMatch);
    assert(result[2].candidates.length == 0);
    // A broken later batch is not interpreted as a no-hit batch.
    answers[2] = parseJSON(`{"results":{}}`);
    assertThrown!Exception(matchCatalog(catalog, batches, answers));
}
