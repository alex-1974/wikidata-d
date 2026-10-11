# M1 acceptance criteria

- [x] Independent source package and DUB manifest drafted.
- [x] Arbitrary SPARQL GET query method included.
- [x] Lexeme lookup builder accepts language, lemma(s), and optional POS.
- [x] Entity retrieval for Q/L/P IDs included.
- [x] User-agent, HTTPS, connection and operation timeouts included.
- [x] Query escaping and entity-ID validation included.
- [x] Offline source-level `unittest` coverage drafted.
- [ ] Compile with DMD 2.111 and LDC 1.41 (environment has no D compiler).
- [ ] Execute `dub test` and live smoke on the XPS.
- [ ] Validate real WDQS and API payload structures against the parser.
- [ ] Review with workspace design/quality/repository standards before integration.

M1 does not include graph expansion, persistence or the vocabulary trainer UI.
