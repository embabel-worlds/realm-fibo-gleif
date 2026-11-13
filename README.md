# realm-fibo-gleif: FIBO's legal entities, bound to GLEIF and OFAC

> Which of our counterparties are ultimately controlled by a sanctioned entity, and through which
> chain?

Asked of a realm whose vocabulary is FIBO's (the ontology every bank's data office cites), whose
entities are GLEIF's (the public register of three million legal entities and who consolidates
whom), and whose sanctions list is OFAC's own files. The appliance answers it by fetching the handful
of records the question touches, concluding the rest, and showing its work: every hop of a control
chain cites the GLEIF record that asserts it.

Nothing is loaded in advance. GLEIF is read per LEI as a question reaches it and cached for a day;
OFAC's files are downloaded once a day and joined by name. The first question about an entity costs
a few GLEIF calls; the second costs none.

## What is in it

| Part | What it is |
|---|---|
| `types/legal-entities.yml` | `LegalEntity` (FIBO / OMG Commons LegalEntity, keyed on the LEI), `ConsolidationRecord` (GLEIF's relationship record: since when, accounting period, corroboration), `ReportingException` (GLEIF's reason no parent is given) |
| `types/sanctions.yml` | `SanctionedParty` and `SanctionsAlias` from OFAC's `SDN.CSV` and `ALT.CSV`, joined by exact case-insensitive name |
| `types/counterparties.yml`, `reference/counterparties.yml` | the watch list: eight real LEIs, each verified against GLEIF (below) |
| `producers/gleif.yml` | seven `remote` producers over the GLEIF JSON:API, no key; a 404 from a parent endpoint is read as "none reported", never as an outage |
| `producers/ofac.yml` | three `tabular` producers over OFAC's headerless CSV exports, their columns declared |
| `rules/` | FIBO's roles `Subsidiary` and `ControllingAffiliate` as derived labels; `SanctionsExposed`, a judgement that propagates down the chain |
| `views/control.yml` | `ControlChainOf`, `ConsolidationEvidenceOf`, `SubsidiariesOf`, `SanctionsExposureOf`, `CounterpartyExposure`, `CounterpartyControlChains` |
| `ontology/alignment.yml` | the IRI behind every name, in the form `ontology-io` writes for an imported realm |
| `apis/gleif.json` | a narrow OpenAPI description of the seven GLEIF operations used |

### The vocabulary is FIBO's; the evidence is GLEIF's

`IS_SUBSIDIARY_OF` is FIBO Business Entities' `isSubsidiaryOf`. Its evidence is GLEIF's Level 2
record, type `IS_DIRECTLY_CONSOLIDATED_BY`: accounting consolidation under IFRS 10 or US GAAP, one
hop per record, which is control in FIBO's sense. The parent's view of the same fact is
`IS_CONTROLLING_AFFILIATE_OF`, FIBO's `isControllingAffiliateOf`, under its own name on purpose: with
one relationship name for both directions the planner resolved every parent's children while walking
up, 39 GLEIF calls for Apple's one hop; with the names apart it is 4.

`Subsidiary` and `ControllingAffiliate` are FIBO roles, concluded by rules over the edges a query has
fetched and never stored. `SanctionsExposed` is concluded the same way: an entity named on the SDN
list under one of its GLEIF names, or consolidated by one that is, to the fixpoint, carrying the
listed name and the match quality down the chain.

When the host reads realm-spec's `BINDING_REALMS.md`, this realm splits along its seam: the FIBO
types and rules in an ontology realm (what `ontology-io import owl` writes from FIBO BE), the GLEIF
and OFAC producers and joins in a binding realm. Until then it is one realm that answers.

### The one weak join, declared as such

OFAC names entities by name and alias, not by LEI. A `LegalEntity` reaches a `SanctionedParty` when
one of its GLEIF names (the legal name or an alternative-language or trading name) equals an SDN
primary name (`NAMED_ON_SDN`) or an SDN alias (`ALIAS_ON_SDN`), compared case-insensitively and
trimmed, nothing fuzzier. The views say which of the two matched. A match is a lead to confirm
against OFAC's own search, never a finding; a non-match says nothing. Rosneft is the worked case:
GLEIF records PAO NK Rosneft's alternative-language legal names as `Rosneft` and `Rosneft Oil
Company`; OFAC's entry 17022 is `OPEN JOINT-STOCK COMPANY ROSNEFT OIL COMPANY`, with `ROSNEFT OIL
COMPANY` and `ROSNEFT` among its aliases. The alias join finds it; the primary-name join does not.

## Running it

```
embabel realm validate ./realm-fibo-gleif          # PASSED: 0 errors (13 November 2026)
```

Install it from a mounted checkout (`install_realm_from_path`, or a `path:` entry in
`config/realms.yml`), then:

```cypher
MATCH (e:LegalEntity {lei: '549300G81RQKP7XW2N18'}) RETURN e.legalName, e.country, e.names
```

```
POST /api/v1/views/ControlChainOf/invoke          {"args": {"lei": "549300G81RQKP7XW2N18"}}
POST /api/v1/views/ConsolidationEvidenceOf/invoke {"args": {"lei": "549300G81RQKP7XW2N18"}}
POST /api/v1/views/SubsidiariesOf/invoke          {"args": {"lei": "HWUPKR0MPOU8FGXBT394"}}
POST /api/v1/views/CounterpartyControlChains/invoke
POST /api/v1/views/SanctionsExposureOf/invoke     {"args": {"lei": "391200PKEUF3Y2NUMW25"}}
POST /api/v1/views/CounterpartyExposure/invoke
```

**Host requirement for the OFAC half.** OFAC's CSV exports have no header row. The `tabular`
producer's `columns:` field (realm-spec `VIRTUAL_CYPHER.md` §5.8; host change embabel/me#3857) names
them. On a host without it the sanctions producers fail loudly, naming the file and the columns they
found, and `SanctionsExposureOf` and `CounterpartyExposure` return `SOURCE_UNAVAILABLE` rather than an
empty answer; everything over GLEIF alone still runs. `producers/ofac.yml` is its own file so that is
all that is lost.

## Verification, 13 November 2026

Every figure below was read from the GLEIF API directly with `curl`, then from the realm installed on
an appliance (image `sha-063c0fa`), and the two agree.

| Counterparty | GLEIF says | The realm says (`CounterpartyControlChains`) |
|---|---|---|
| Apple Operations International Limited (IE) | direct and ultimate parent Apple Inc. (US); relationship since 2017-12-13, `ENTITY_SUPPLIED_ONLY`; Apple Inc. reports `NATURAL_PERSONS` | chain `APPLE OPERATIONS INTERNATIONAL LIMITED -> Apple Inc.`, 1 hop, record `HWUPKR0MPOU8FGXBT394`, ends `NATURAL_PERSONS`; `ConsolidationEvidenceOf` gives since 2017-12-13, accounting period 2022, `ENTITY_SUPPLIED_ONLY` |
| Rosneft Deutschland GmbH (DE) | direct parent PAO NK Rosneft (RU, `253400JT3MQWNDKMJE44`), which reports `NO_KNOWN_PERSON` | the same chain, 1 hop; the sanctions match needs the OFAC half (above) |
| OOO RN-Kapital (RU) | a direct child of PAO NK Rosneft | chain to Rosneft, 1 hop |
| SEFE Marketing & Trading Switzerland AG (CH) | parent SEFE Marketing & Trading Limited (GB), which reports no parent (`NO_LEI`) | the same, 1 hop |
| SEFE Energy Limited (GB) | parent SEFE Energy GmbH (DE), `NO_LEI` above it | the same, 1 hop |
| Gazprom Austria GmbH (AT) | no parent; exception `NON_CONSOLIDATING` | no chain, `whyTheChainEnds: NON_CONSOLIDATING` |
| Siemens Energy Greece (GR) | parent Siemens Energy AG (DE), `NO_KNOWN_PERSON` | the same, 1 hop |
| Nestlé (South Africa) (ZA) | parent Nestlé S.A. (CH), `NON_CONSOLIDATING` | the same, 1 hop |

`SubsidiariesOf` for Apple Inc. returns the 8 entities GLEIF lists as its direct children, the same
8 the API returns. The whole watch list walks in one view with 6 external calls once the entity
records are warm.

Measured costs: an unseen LEI's record takes one GLEIF call; its chain takes one `direct-parent`
call per hop plus one `reporting-exception` call at the top; the first view over an entity ran in
2 to 12 seconds, the second from cache in under a second.

## Licences

See `NOTICE.md`. FIBO is MIT; GLEIF data is CC0 1.0 under the LEI Data Terms of Use (reached
through the Access Service, no rights claimed, no endorsement implied); OFAC's lists are US
Government works in the public domain. This realm is Apache-2.0.
