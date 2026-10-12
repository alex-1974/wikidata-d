/**
 * Offline grammar contract evaluation over an M5.10 report.
 * Usage: catalog_grammar_contract <contract.json> <M5.10-report.json>
 *          <Lexeme-ID> [Lexeme-ID ...]
 */
import std.file : readText;
import std.json : parseJSON;
import std.stdio : writeln, stderr;
import wikidata.grammar_contract : evaluateGrammarContract;

int main(string[] args)
{
    if (args.length < 4)
    {
        writeln("Usage: catalog_grammar_contract <contract.json> "
            ~ "<M5.10-report.json> <Lexeme-ID> [Lexeme-ID ...]");
        return 2;
    }
    try
    {
        auto contract = parseJSON(readText(args[1]));
        auto report = parseJSON(readText(args[2]));
        foreach (lexemeId; args[3 .. $])
        {
            auto result = evaluateGrammarContract(contract, report, lexemeId);
            auto stats = result["summary"];
            writeln("=== ", lexemeId, " | ", result["contractId"].str,
                " ===");
            writeln("Confirmed: ", stats["confirmedSlots"].integer, "/",
                stats["slots"].integer, ", review: ",
                stats["reviewSlots"].integer, ", missing: ",
                stats["missingSlots"].integer);
            foreach (slot; result["slots"].array)
            {
                writeln("  ", slot["slotId"].str, " [",
                    slot["status"].str, "]");
                foreach (candidate; slot["matches"].array)
                {
                    foreach (rep; candidate["representations"].array)
                        if (rep["languageCode"].str == result["languageCode"].str)
                            writeln("    ", candidate["formId"].str, ": ",
                                rep["text"].str, " [",
                                candidate["method"].str, "]");
                }
                if (slot["status"].str == "missing" ||
                    slot["status"].str == "review")
                {
                    auto excluded = slot["excludedCandidates"].array.length;
                    if (excluded > 0)
                        writeln("    Excluded incompatible Forms: ", excluded);
                    foreach (candidate; slot["incompleteCandidates"].array)
                    {
                        foreach (rep; candidate["representations"].array)
                            if (rep["languageCode"].str ==
                                result["languageCode"].str)
                                writeln("    UNVERIFIED: ",
                                    candidate["formId"].str, " ",
                                    rep["text"].str, " | missing ",
                                    candidate["missingRequiredFeatureIds"]
                                        .toString());
                    }
                }
            }
        }
        return 0;
    }
    catch (Exception e)
    {
        stderr.writeln("Grammar contract evaluation failed: ", e.msg);
        return 1;
    }
}
