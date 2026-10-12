/**
 * R1.11-B: conservative, offline Wikidata Q-item dimension candidates.
 *
 * The source graph is the original R1.3 Q-item audit, not a lexicon.
 * Interpretation anchors are explicitly reviewed external metadata; a match
 * is a *candidate*, never a universal grammar fact or an attested Form.
 * No global P279 transitivity, P1889 disjointness or lexical generation.
 */
module wikidata.grammar_dimension;

import std.exception : enforce;
import std.json : JSONType, JSONValue;

/// These are metadata facets, not a closed list of grammatical dimensions.
enum FeatureFacet : ubyte { inflection, lexical, representation, usage }
enum ClassificationKind : ubyte { unclassified, candidate, multipleCandidates }

string facetName(FeatureFacet facet)
{
    final switch (facet)
    {
        case FeatureFacet.inflection: return "inflection";
        case FeatureFacet.lexical: return "lexical";
        case FeatureFacet.representation: return "representation";
        case FeatureFacet.usage: return "usage";
    }
}

private FeatureFacet parseFacet(string name)
{
    switch (name)
    {
        case "inflection": return FeatureFacet.inflection;
        case "lexical": return FeatureFacet.lexical;
        case "representation": return FeatureFacet.representation;
        case "usage": return FeatureFacet.usage;
        default: enforce(false, "Unrecognized feature facet: " ~ name);
    }
    assert(0);
}

string classificationName(ClassificationKind kind)
{
    final switch (kind)
    {
        case ClassificationKind.unclassified: return "unclassified";
        case ClassificationKind.candidate: return "candidate";
        case ClassificationKind.multipleCandidates: return "multiple_candidates";
    }
}

private string requireString(JSONValue value, string key)
{
    enforce(value.type == JSONType.object, "Expected JSON object");
    auto entries = value.object;
    auto p = key in entries;
    enforce(p !is null && (*p).type == JSONType.string && (*p).str.length,
        "Missing or empty string: " ~ key);
    return (*p).str;
}

private JSONValue requireMember(JSONValue value, string key)
{
    enforce(value.type == JSONType.object, "Expected JSON object");
    auto entries = value.object;
    auto p = key in entries;
    enforce(p !is null, "Missing member: " ~ key);
    return *p;
}

private bool optionalBool(JSONValue value, string key)
{
    enforce(value.type == JSONType.object, "Expected JSON object");
    auto entries = value.object;
    auto p = key in entries;
    if (p is null) return false;
    enforce((*p).type == JSONType.true_ || (*p).type == JSONType.false_,
        "Not a boolean: " ~ key);
    return (*p).type == JSONType.true_;
}

private bool isQId(string id)
{
    if (id.length < 2 || id[0] != 'Q') return false;
    foreach (c; id[1 .. $]) if (c < '0' || c > '9') return false;
    return true;
}

/** Evidence for one exact edge in the original R1.3 item graph. */
struct ItemGraphEdge
{
    string sourceQId;
    string propertyId;
    string targetQId;
    string statementId;
    string rank;
    bool hasQualifiers;
    bool hasReferences;
}

/** A bounded, potentially incomplete Wikidata Q-item graph snapshot. */
struct ItemGraph
{
    string snapshotStatus;
    bool graphTruncated;
    string[] unresolvedQIds;
    private ItemGraphEdge[][string] bySourceAndProperty;

    private static string key(string src, string prop)
    {
        return src ~ "\x1f" ~ prop;
    }

    ItemGraphEdge[] find(string sourceQId, string propertyId)
    {
        auto p = key(sourceQId, propertyId) in bySourceAndProperty;
        return p is null ? null : *p;
    }
}

/** R1.3 provides direct edges only. Missing nodes never imply negation. */
ItemGraph parseItemGraph(JSONValue original)
{
    enforce(requireString(original, "schemaVersion") == "r1.3-graph-audit-v1",
        "Expected the original R1.3 feature-graph.json");
    ItemGraph graph;
    graph.snapshotStatus = requireString(original, "status");
    graph.graphTruncated = optionalBool(original, "graphTruncated");
    auto missing = requireMember(original, "missingQIds");
    enforce(missing.type == JSONType.array, "missingQIds must be an array");
    foreach (v; missing.array)
    {
        enforce(v.type == JSONType.string && isQId(v.str), "Invalid missing Q-ID");
        graph.unresolvedQIds ~= v.str;
    }
    auto nodes = requireMember(original, "nodes");
    enforce(nodes.type == JSONType.object, "R1.3 nodes must be an object");
    string[string] seenStatement;
    foreach (qid, node; nodes.object)
    {
        enforce(isQId(qid), "Invalid Q-item key: " ~ qid);
        auto edges = requireMember(node, "edges");
        enforce(edges.type == JSONType.array, "Node edges must be an array");
        foreach (raw; edges.array)
        {
            ItemGraphEdge edge;
            edge.sourceQId = requireString(raw, "source");
            edge.propertyId = requireString(raw, "property");
            edge.targetQId = requireString(raw, "target");
            edge.statementId = requireString(raw, "statementId");
            edge.rank = requireString(raw, "rank");
            edge.hasQualifiers = optionalBool(raw, "hasQualifiers");
            edge.hasReferences = optionalBool(raw, "hasReferences");
            enforce(edge.sourceQId == qid && isQId(edge.targetQId),
                "Item graph edge crosses its source node or has a non-Q target");
            auto existing = edge.statementId in seenStatement;
            enforce(existing is null, "Repeated Q-item statement ID: " ~ edge.statementId);
            seenStatement[edge.statementId] = qid;
            // Retain only structural links used by explicit allowed paths.
            // P1889 is deliberately NOT used as grammatical exclusion.
            if (edge.propertyId == "P31" || edge.propertyId == "P279")
                graph.bySourceAndProperty[ItemGraph.key(qid, edge.propertyId)] ~= edge;
        }
    }
    return graph;
}

/** Metadata anchor, NOT a fact about a lexical Wikidata Form. */
struct DimensionAnchor
{
    string id;
    string dimensionId;
    FeatureFacet facet;
    string rootQId;
    string source; // reviewed external/ontology mapping provenance
    string[][] allowedPaths; // literal P31/P279 paths, no implicit traversal
}

struct DimensionProfile
{
    string profileId;
    DimensionAnchor[] anchors;
}

DimensionProfile parseDimensionProfile(JSONValue data)
{
    enforce(requireString(data, "schemaVersion") ==
        "wikidata-r1.11b-dimension-profile-v1", "Unsupported dimension profile");
    DimensionProfile profile;
    profile.profileId = requireString(data, "profileId");
    auto anchors = requireMember(data, "anchors");
    enforce(anchors.type == JSONType.array, "anchors must be an array");
    enforce(anchors.array.length <= 256, "Too many profile anchors");
    bool[string] ids;
    foreach (raw; anchors.array)
    {
        DimensionAnchor anchor;
        anchor.id = requireString(raw, "id");
        enforce((anchor.id in ids) is null, "Duplicate dimension anchor: " ~ anchor.id);
        ids[anchor.id] = true;
        anchor.dimensionId = requireString(raw, "dimensionId");
        anchor.facet = parseFacet(requireString(raw, "facet"));
        anchor.rootQId = requireString(raw, "rootQId");
        enforce(isQId(anchor.rootQId), "Invalid anchor root Q-ID");
        anchor.source = requireString(raw, "source");
        auto paths = requireMember(raw, "allowedPaths");
        enforce(paths.type == JSONType.array && paths.array.length > 0 &&
            paths.array.length <= 16, "Invalid allowedPaths");
        foreach (path; paths.array)
        {
            enforce(path.type == JSONType.array && path.array.length <= 3,
                "Only explicitly typed paths of up to three hops are allowed");
            string[] relations;
            foreach (i, property; path.array)
            {
                enforce(property.type == JSONType.string, "Non-string path relation");
                auto pid = property.str;
                enforce((i == 0 && (pid == "P31" || pid == "P279")) ||
                    (i > 0 && pid == "P279"),
                    "Only initial P31/P279 followed by explicit P279 is supported");
                relations ~= pid;
            }
            anchor.allowedPaths ~= relations;
        }
        profile.anchors ~= anchor;
    }
    return profile;
}

/** Every witness retains the exact statement IDs of its traversed edges. */
struct ClassificationWitness
{
    string anchorId;
    string rootQId;
    string source;
    string[] nodes;
    string[] properties;
    string[] statementIds;
}

struct DimensionCandidate
{
    string dimensionId;
    FeatureFacet facet;
    ClassificationWitness[] witnesses;
}

struct FeatureClassification
{
    string featureQId;
    ClassificationKind kind;
    DimensionCandidate[] candidates;
    string graphStatus;
    bool graphTruncated;
    size_t unresolvedQItemCount;
}

private void traverse(ref ItemGraph graph, ref DimensionAnchor anchor,
    string current, string[] path, size_t step, string[] nodes,
    string[] statements, ref ClassificationWitness[] matches)
{
    if (step == path.length)
    {
        if (current != anchor.rootQId) return;
        ClassificationWitness hit;
        hit.anchorId = anchor.id;
        hit.rootQId = anchor.rootQId;
        hit.source = anchor.source;
        hit.nodes = nodes.dup;
        hit.properties = path.dup;
        hit.statementIds = statements.dup;
        matches ~= hit;
        enforce(matches.length <= 4096, "Too many classification paths");
        return;
    }
    foreach (edge; graph.find(current, path[step]))
    {
        // Qualified statements from R1.3 have only a qualifier-presence flag:
        // we cannot safely read their semantic restrictions. Skip them.
        if ((edge.rank != "normal" && edge.rank != "preferred") ||
            edge.hasQualifiers) continue;
        bool cycle;
        foreach (seen; nodes) if (seen == edge.targetQId) { cycle = true; break; }
        if (cycle) continue;
        auto nextNodes = nodes.dup;
        nextNodes ~= edge.targetQId;
        auto nextStatements = statements.dup;
        nextStatements ~= edge.statementId;
        traverse(graph, anchor, edge.targetQId, path, step + 1,
            nextNodes, nextStatements, matches);
    }
}

/**
 * Return zero, one or multiple *candidate* dimensions.
 * No result certifies a grammatical rule, nor the completeness of the graph.
 */
FeatureClassification classifyFeature(ref ItemGraph graph,
    ref DimensionProfile profile, string featureQId)
{
    enforce(isQId(featureQId), "Invalid feature Q-ID");
    FeatureClassification result;
    result.featureQId = featureQId;
    result.kind = ClassificationKind.unclassified;
    result.graphStatus = graph.snapshotStatus;
    result.graphTruncated = graph.graphTruncated;
    result.unresolvedQItemCount = graph.unresolvedQIds.length;
    foreach (ref anchor; profile.anchors)
    {
        ClassificationWitness[] witnesses;
        foreach (path; anchor.allowedPaths)
        {
            string[] origin = [featureQId];
            traverse(graph, anchor, featureQId, path, 0, origin, null, witnesses);
        }
        if (!witnesses.length) continue;
        bool merged;
        foreach (ref candidate; result.candidates)
        {
            if (candidate.dimensionId == anchor.dimensionId &&
                candidate.facet == anchor.facet)
            {
                candidate.witnesses ~= witnesses;
                merged = true;
                break;
            }
        }
        if (!merged)
            result.candidates ~= DimensionCandidate(
                anchor.dimensionId, anchor.facet, witnesses);
    }
    if (result.candidates.length == 1)
        result.kind = ClassificationKind.candidate;
    else if (result.candidates.length > 1)
        result.kind = ClassificationKind.multipleCandidates;
    return result;
}

private JSONValue toJson(string[] strings)
{
    JSONValue arr = JSONValue.emptyArray;
    foreach (s; strings) arr.array ~= JSONValue(s);
    return arr;
}

JSONValue asJson(FeatureClassification result)
{
    JSONValue row = JSONValue.emptyObject;
    row["featureQId"] = result.featureQId;
    row["status"] = classificationName(result.kind);
    row["snapshotStatus"] = result.graphStatus;
    row["graphTruncated"] = result.graphTruncated;
    row["unresolvedQItemCount"] = cast(long) result.unresolvedQItemCount;
    row["candidates"] = JSONValue.emptyArray;
    foreach (candidate; result.candidates)
    {
        JSONValue c = JSONValue.emptyObject;
        c["dimensionId"] = candidate.dimensionId;
        c["facet"] = facetName(candidate.facet);
        c["witnesses"] = JSONValue.emptyArray;
        foreach (witness; candidate.witnesses)
        {
            JSONValue w = JSONValue.emptyObject;
            w["anchorId"] = witness.anchorId;
            w["rootQId"] = witness.rootQId;
            w["profileSource"] = witness.source;
            w["nodes"] = toJson(witness.nodes);
            w["properties"] = toJson(witness.properties);
            w["statementIds"] = toJson(witness.statementIds);
            c["witnesses"].array ~= w;
        }
        row["candidates"].array ~= c;
    }
    row["generatesLexicalData"] = false;
    row["claimIsVerifiedGrammar"] = false;
    return row;
}

JSONValue evaluateDimensionFixture(JSONValue graphData, JSONValue profileData,
    JSONValue checksData)
{
    enforce(requireString(checksData, "schemaVersion") ==
        "wikidata-r1.11b-checks-v1", "Unsupported R1.11-B checks");
    auto graph = parseItemGraph(graphData);
    auto profile = parseDimensionProfile(profileData);
    auto checks = requireMember(checksData, "checks");
    enforce(checks.type == JSONType.array, "checks must be an array");
    JSONValue report = JSONValue.emptyObject;
    report["schemaVersion"] = "wikidata-r1.11b-evaluation-v1";
    report["profileId"] = profile.profileId;
    report["results"] = JSONValue.emptyArray;
    foreach (raw; checks.array)
    {
        auto qid = requireString(raw, "featureQId");
        auto expected = requireString(raw, "expectedStatus");
        auto result = classifyFeature(graph, profile, qid);
        enforce(classificationName(result.kind) == expected,
            "R1.11-B classification mismatch for " ~ qid);
        auto entry = asJson(result);
        entry["id"] = requireString(raw, "id");
        auto entries = raw.object;
        if (auto ec = "expectedCandidates" in entries)
        {
            enforce((*ec).type == JSONType.integer && (*ec).integer >= 0,
                "Invalid expectedCandidates");
            enforce(result.candidates.length == cast(size_t) (*ec).integer,
                "Wrong dimension candidate count: " ~ qid);
        }
        if (auto ew = "expectedWitnesses" in entries)
        {
            enforce((*ew).type == JSONType.integer && (*ew).integer >= 0,
                "Invalid expectedWitnesses");
            size_t count;
            foreach (candidate; result.candidates) count += candidate.witnesses.length;
            enforce(count == cast(size_t) (*ew).integer,
                "Wrong provenance path count: " ~ qid);
        }
        report["results"].array ~= entry;
    }
    return report;
}

unittest
{
    import std.json : parseJSON;
    auto graph = parseJSON(q{
      {"schemaVersion":"r1.3-graph-audit-v1","status":"offline-cache-only",
       "graphTruncated":true,"missingQIds":["Q999"],"nodes":{
         "Q10":{"edges":[{"source":"Q10","target":"Q20","property":"P31",
                "statementId":"Q10$one","rank":"normal","hasQualifiers":false,
                "hasReferences":true}]},
         "Q20":{"edges":[]},"Q11":{"edges":[]}
       }}
    });
    auto profile = parseJSON(q{
      {"schemaVersion":"wikidata-r1.11b-dimension-profile-v1",
       "profileId":"unit","anchors":[
        {"id":"a","rootQId":"Q20","dimensionId":"number",
         "facet":"inflection","source":"explicit synthetic mapping",
         "allowedPaths":[["P31"]]}
       ]}
    });
    auto index = parseItemGraph(graph);
    auto rules = parseDimensionProfile(profile);
    auto yes = classifyFeature(index, rules, "Q10");
    assert(yes.kind == ClassificationKind.candidate);
    assert(yes.candidates[0].witnesses[0].statementIds[0] == "Q10$one");
    assert(yes.unresolvedQItemCount == 1 && yes.graphTruncated);
    auto no = classifyFeature(index, rules, "Q11");
    assert(no.kind == ClassificationKind.unclassified);
    bool threw;
    try
    {
        auto bad = parseJSON(q{
          {"schemaVersion":"wikidata-r1.11b-dimension-profile-v1",
           "profileId":"bad","anchors":[
            {"id":"bad","rootQId":"Q20","dimensionId":"number",
             "facet":"inflection","source":"synthetic",
             "allowedPaths":[["P279","P31"]]}
           ]}
        });
        auto ignored = parseDimensionProfile(bad);
    }
    catch (Exception) threw = true;
    assert(threw);
}
