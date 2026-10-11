/** Offline importer: given source HTML -> local, unredistributed JSON. */
import std.file : readText, write;
import std.stdio : stderr, writeln;
import wikidata.catalog : parseCatalog;
import wikidata.perugia_import : parsePerugiaHtml, buildPerugiaCatalog;

int main(string[] args)
{
    if (args.length != 3)
    {
        stderr.writeln("Usage: import_perugia SOURCE.html OUTPUT.json");
        return 2;
    }
    try
    {
        auto rows = parsePerugiaHtml(readText(args[1]));
        auto output = buildPerugiaCatalog(rows); // validates 1..486
        auto catalog = parseCatalog(output);    // schema compatibility
        write(args[2], output.toPrettyString() ~ "\n");
        size_t reviewCount;
        foreach (entry; output["entries"].array)
            if (entry["reviewReasons"].array.length != 0)
                ++reviewCount;
        writeln("SOURCE ROWS: ", rows.length);
        writeln("CATALOG ENTRIES: ", catalog.entries.length);
        writeln("REVIEW REQUIRED: ", reviewCount);
        writeln("LOCAL OUTPUT: ", args[2]);
        return 0;
    }
    catch (Exception error)
    {
        stderr.writeln("IMPORT FAILED: ", error.msg);
        return 1;
    }
}
