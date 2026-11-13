# Sources and licences

| What | Source | Licence |
|---|---|---|
| Vocabulary: `LegalEntity`, `Subsidiary`, `ControllingAffiliate`, `IS_SUBSIDIARY_OF` | FIBO Business Entities, EDM Council, `spec.edmcouncil.org/fibo/ontology/BE/`; OMG Commons Ontology Library | MIT |
| Legal entities and consolidation relationships | GLEIF Golden Copy via `api.gleif.org/api/v1` | CC0 1.0 under the LEI Data Terms of Use: reached through the Access Service, no rights claimed in the data, no GLEIF endorsement implied |
| Sanctions list and aliases | OFAC Sanctions List Service exports `SDN.CSV`, `ALT.CSV` (US Department of the Treasury) | US Government work, public domain |
| `apis/gleif.json` | Written here from GLEIF's API documentation and the live service, 12 and 13 November 2026 | this repository's |

Nothing from these sources is copied into the realm. GLEIF is read per LEI as a question reaches it
and cached for a day; OFAC's files are downloaded once a day and joined by name.
