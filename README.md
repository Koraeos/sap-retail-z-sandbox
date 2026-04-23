# SAP Retail Z Sandbox

> Hands-on ABAP Platform 1909 project simulating a minimal SAP Retail backend. Built from scratch to master SAP Retail data structures, OO-ABAP design patterns, and ABAP Unit testing.

---

## Context

Self-driven learning project by Romain Hecquet — retail professional (ex-Decathlon) transitioning to **SAP technico-functional consulting**. This repository materialises a step-by-step dive into SAP Retail through custom `Z` objects running on a local SAP ABAP Platform 1909 trial.

The goal is twofold:

- Build hands-on technical depth on ABAP, DDIC, OO, exceptions, and unit testing
- Keep each step close to real retail semantics (article types, active flag, EAN / barcode, currency, unit of measure)

---

## Tech stack

- **SAP ABAP Platform 1909** — local Developer Edition (Docker)
- **ABAP OO** — domain class, exception class, inline helpers
- **ABAP Dictionary** — custom transparent tables, data elements, domains
- **SALV** (`cl_salv_table`) — modern fullscreen ALV with header grid, row coloring, event handling
- **ABAP Unit** — local test classes with assertions
- **abapGit** — source-based version control, synced with GitHub

---

## Architecture

The project follows a clean **layered OO approach** — uncommon in the ABAP world, standard best practice everywhere else.

```
┌─────────────────────────────────────────────┐
│  Presentation layer                         │
│  ZRET_R_ARTICLE_LIST  (executable report)   │
│   - Selection screen                        │
│   - ALV rendering (header, coloring)        │
│   - Double-click event handler              │
└─────────────────────────────────────────────┘
                    │ calls
                    ▼
┌─────────────────────────────────────────────┐
│  Domain layer                               │
│  ZCL_RET_ARTICLE  (static methods)          │
│   - select_all( range, only_active )        │
│   - get_by_id( article_id )                 │
│   - enrich_article (private helper)         │
│  May raise: ZCX_RET_CORE                    │
└─────────────────────────────────────────────┘
                    │ reads
                    ▼
┌─────────────────────────────────────────────┐
│  Data layer                                 │
│  ZRET_T_ARTICLE  (DDIC transparent table)   │
│   - article_id, article_name, article_type  │
│   - ean, base_uom, price, currency          │
│   - active_flag, audit timestamps           │
└─────────────────────────────────────────────┘
```

**Error handling**: domain errors propagate through `ZCX_RET_CORE` (inheriting `CX_STATIC_CHECK`). The presentation layer catches and translates them to user-facing messages.

---

## Features

### Data layer

- Custom transparent table `ZRET_T_ARTICLE` with 13 fields (ID, name, type, EAN, UOM, price, currency, active flag, audit timestamps)
- 4 retail-realistic test articles:

| ID     | Name                           | Type | Price HT  | EAN            |
|--------|--------------------------------|------|-----------|----------------|
| ART001 | Trail running shoes men size 42 | HARD | 29.99 EUR | 3608412345678  |
| ART002 | Cotton T-shirt black size M    | SOFT | 7.99 EUR  | 3608412345685  |
| ART003 | Stainless steel water bottle   | ACCE | 4.99 EUR  | 3608412345692  |
| ART004 | Chocolate protein bar 60g      | CONS | 1.49 EUR  | 3608412345708  |

### Report `ZRET_R_ARTICLE_LIST`

- **Selection screen**: SELECT-OPTIONS on article type + active-only checkbox
- **Computed column**: TTC price = HT × VAT rate (20%)
- **ALV header**: title, date/user, per-type article counts, total HT value
- **Row coloring** by article type:
  - HARD → green
  - SOFT → blue
  - ACCE → yellow
  - CONS → orange
- **Double-click drill-down**: single click on any article row opens a popup with full details (ID, name, type, HT, TTC, EAN)

### Domain class `ZCL_RET_ARTICLE`

- Encapsulates all article-related logic — no SELECT or calculation in the report
- Public static methods:
  - `select_all( it_type_range, iv_only_active )` — returns filtered list
  - `get_by_id( iv_article_id )` — returns a single article
- Centralised VAT rate as class constant (`c_vat_rate`)
- Private helper `enrich_article` eliminates duplication between the two public methods (DRY)
- Public types exposed for reuse: `ty_article`, `ty_article_tab`, `tty_type_range`

### Exception class `ZCX_RET_CORE`

- Custom exception inheriting `CX_STATIC_CHECK`
- Carries an `article_id` attribute for error context

### Testing — ABAP Unit

**7 unit tests** on the domain class, all green:

1. `returns_all_active` — default select returns 4 active articles
2. `filter_by_hard_type` — type range filter returns only matching rows
3. `ttc_is_ht_times_1_20` — TTC correctly computed against class constant
4. `hard_row_is_green` — color is assigned per type
5. `raises_when_no_match` — `zcx_ret_core` raised on empty result
6. `get_by_id_returns_article` — single-article fetch works + TTC computed
7. `get_by_id_raises_if_not_found` — exception raised on unknown ID

---

## Repo layout

```
src/
├── zret_core.devc.xml               # Package ZRET_CORE
├── ddic/
│   └── zret_t_article.tabl.xml     # Data layer
├── classes/
│   ├── zcl_ret_article.clas.xml    # Domain class + local test class
│   └── zcx_ret_core.clas.xml       # Exception class
└── programs/
    └── zret_r_article_list.prog.abap   # Presentation layer
```

---

## Getting started

**Prerequisites**: SAP ABAP Platform 1909 Developer Edition running locally (Docker or direct install).

1. Install abapGit standalone in your system (once)
2. Clone this repo:
   ```
   https://github.com/Koraeos/sap-retail-z-sandbox.git
   ```
3. Pull the repo into a Z-package on your system
4. Activate all objects (Ctrl+F3 on each class / table / report)
5. Run `ZRET_R_ARTICLE_LIST` via SE38 or SA38

---

## Roadmap

- ✅ **Phase 1** — Sandbox setup, first DDIC table, first report
- ✅ **Phase 2** — OO refactor (domain class + exception), ABAP Unit tests
- 🚧 **Phase 2.5** — Article hierarchy (super-model → model → variant, Decathlon-style)
- ⏳ **Phase 3** — Z sales cycle (sales order → delivery → invoice)
- ⏳ **Phase 4** — Z purchase cycle (PO → goods receipt → stock)
- ⏳ **Phase 5** — Pseudo-EWM (warehouse, tasks, transport units)
- ⏳ **Phase 6** — CDS views + custom Fiori apps
- ⏳ **Phase 7** — Production-readiness polish + portfolio demo

---

## Author

**Romain Hecquet**

- GitHub: [@Koraeos](https://github.com/Koraeos)
- Email: hecquet.rom@gmail.com

Career transition from retail operations (ex-Decathlon) to SAP technico-functional consulting, with a focus on **SAP Retail / S/4HANA Retail**.
