# SAP Retail Z Sandbox

> Hands-on ABAP Platform 1909 project simulating a minimal SAP Retail backend with the complete Order-to-Cash cycle. Built from scratch to master SAP Retail data structures, OO-ABAP design patterns, transactional integrity, and ABAP Unit testing.

---

## Context

Self-driven learning project by Romain Hecquet — retail professional (ex-Decathlon) transitioning to **SAP technico-functional consulting**. This repository materialises a step-by-step dive into SAP Retail through custom `Z` objects running on a local SAP ABAP Platform 1909 trial.

The goal is twofold:

- Build hands-on technical depth on ABAP, DDIC, OO, exceptions, transactions, and unit testing
- Keep each step close to real retail semantics (article types, customer segments, sites, the Order-to-Cash cycle, multi-currency)

---

## Highlights

- ✅ **Complete Order-to-Cash cycle in custom Z**: Sales Order → Delivery → Invoice with status transitions (`Open` → `Delivered` → `Billed`)
- ✅ **6 domain classes** that compose each other (Sales Order calls Customer + Article ; Delivery calls Sales Order + Site + Customer ; Invoice calls Delivery + Sales Order)
- ✅ **31 ABAP Unit tests green** — uncommon in the ABAP world, signals production-grade rigor
- ✅ **Atomic transactions** with `COMMIT WORK` / `ROLLBACK WORK` — multi-table updates respect business invariants
- ✅ **Snapshot pattern** on transactional documents — customer/article/price values are frozen at transaction time for audit traceability
- ✅ **Document flow** — every invoice line traces back to its delivery item and original sales order item
- ✅ **Layered architecture** — presentation (programs) → domain (classes) → data (DDIC tables), tested in isolation
- ✅ **Multi-currency / multi-segment** — 4 customer segments (Store / Web / B2B / Export) with default currency per customer

---

## Tech stack

- **SAP ABAP Platform 1909** — local Developer Edition (Docker)
- **ABAP OO** — domain classes, exception class with context attribute, private helpers
- **ABAP Dictionary** — transparent tables, domains with fixed values, data elements, F4 search helps
- **SALV** (`cl_salv_table`) — modern fullscreen ALV with header grid, row coloring, double-click events, popup ALV (drill-down)
- **ABAP Unit** — local test classes with class_setup, teardown, fixtures, helpers
- **abapGit** — source-based version control, synced with GitHub
- **Eclipse / ABAP Development Tools (ADT)** — primary IDE for source-based DDIC and class editing

---

## Architecture

The project follows a clean **layered OO approach** — uncommon in the ABAP world, standard best practice everywhere else. Three layers, strict separation of responsibilities.

```
╔═══════════════════════════════════════════════════════════════════╗
║  PRESENTATION LAYER — programs / reports                          ║
║                                                                   ║
║  Master:    ZRET_R_ARTICLE_LIST / CREATE                          ║
║             ZRET_R_CUSTOMER_CREATE                                ║
║             ZRET_R_SITE_CREATE                                    ║
║  Sales:     ZRET_R_SO_CREATE / LIST                               ║
║             ZRET_R_DELIV_CREATE / LIST                            ║
║             ZRET_R_INV_CREATE                                     ║
╚═══════════════════════════════════════════════════════════════════╝
                              │ delegates to
                              ▼
╔═══════════════════════════════════════════════════════════════════╗
║  DOMAIN LAYER — classes that own business logic                   ║
║                                                                   ║
║  ZCL_RET_ARTICLE        select_all, get_by_id, create,            ║
║                          update, delete (soft), enrich_article    ║
║  ZCL_RET_CUSTOMER       select_all, get_by_id, create             ║
║  ZCL_RET_SITE           select_all, get_by_id, create             ║
║  ZCL_RET_SALES_ORDER    select_all, get_by_id, create             ║
║                          (composes Article + Customer)            ║
║  ZCL_RET_DELIVERY       select_all, get_by_id, create_from_so     ║
║                          (composes Sales Order + Site + Customer) ║
║  ZCL_RET_INVOICE        select_all, get_by_id, create_from_deliv  ║
║                          (composes Delivery + Sales Order)        ║
║                                                                   ║
║  ZCX_RET_CORE — custom exception with article_id context          ║
╚═══════════════════════════════════════════════════════════════════╝
                              │ reads / writes via SQL + COMMIT
                              ▼
╔═══════════════════════════════════════════════════════════════════╗
║  DATA LAYER — DDIC transparent tables                             ║
║                                                                   ║
║  Master:    ZRET_T_ARTICLE   (5 articles, 4 types)                ║
║             ZRET_T_CUSTOMER  (5 customers, 4 segments)            ║
║             ZRET_T_SITE      (4 sites, stores + warehouses)       ║
║  Sales:     ZRET_T_SO + ZRET_T_SO_ITEM                            ║
║             ZRET_T_DELIV + ZRET_T_DELIV_ITE                       ║
║             ZRET_T_INV + ZRET_T_INV_ITEM                          ║
║                                                                   ║
║  Domains with fixed values:                                       ║
║  ZDO_RET_SO_STATUS    (O / D / B / C)                             ║
║  ZDO_RET_DELIV_STATUS (C / S / R)                                 ║
║  ZDO_RET_INV_STATUS   (O / P / V)                                 ║
╚═══════════════════════════════════════════════════════════════════╝
```

**Error handling**: domain errors propagate through `ZCX_RET_CORE` (inheriting `CX_STATIC_CHECK`), with an `article_id` attribute for context. The presentation layer catches and translates exceptions to user-facing messages.

---

## Order-to-Cash cycle (Phase 3)

The complete sales cycle in custom Z, mirror of standard SAP SD (VA01 → VL01N → VF01):

```
1. SO created via ZRET_R_SO_CREATE
   ↓ ZCL_RET_SALES_ORDER.create:
     - validates customer exists in ZRET_T_CUSTOMER (via ZCL_RET_CUSTOMER)
     - snapshots customer_name from master
     - validates each article via ZCL_RET_ARTICLE (snapshots prices)
     - generates SO number, computes total
     - INSERT header + items, COMMIT
   ↓
   SO status: 'O' (Open)

2. Delivery created via ZRET_R_DELIV_CREATE
   ↓ ZCL_RET_DELIVERY.create_from_so:
     - loads SO via ZCL_RET_SALES_ORDER.get_by_id
     - validates SO is in 'O' status
     - validates source site is a Warehouse (via ZCL_RET_SITE)
     - snapshots destination from customer master
     - copies items from SO to delivery
     - INSERT header + items
     - UPDATE SO status from 'O' to 'D' (atomic)
     - COMMIT (or ROLLBACK if any step fails)
   ↓
   SO status: 'D' (Delivered) ; Delivery status: 'C' (Created)

3. Invoice created via ZRET_R_INV_CREATE
   ↓ ZCL_RET_INVOICE.create_from_delivery:
     - loads delivery + SO via their classes
     - validates SO is in 'D' status (not yet billed)
     - copies items, retrieves prices from SO items
     - INSERT header + items
     - UPDATE SO status 'D' → 'B' (Billed)
     - UPDATE Delivery status 'C' → 'S' (Shipped)
     - COMMIT (atomic)
   ↓
   SO status: 'B' (Billed) ; Delivery status: 'S' (Shipped) ; Invoice status: 'O' (Open)
```

**Key technical points showcased:**

- **Class composition**: 4 domain classes orchestrated within a single method
- **Transactional atomicity**: ALL status transitions and INSERTs in one LUW (Logical Unit of Work)
- **Document traceability**: every invoice item references its delivery item AND its original SO item
- **Triple snapshot**: customer/article data is frozen at every step

---

## Features by phase

### Phase 1 — Sandbox & first table

- ABAP Platform 1909 setup via Docker
- Eclipse / ADT configured
- First DDIC table `ZRET_T_ARTICLE`, first report

### Phase 2 — OO foundations

- Domain class `ZCL_RET_ARTICLE` with full CRUD (`select_all`, `get_by_id`, `create`, `update`, `delete` with soft-delete via `active_flag`)
- Custom exception `ZCX_RET_CORE` with constructor parameter `article_id`
- 12 unit tests with `class_setup` + `teardown` cleanup pattern
- Programs: `ZRET_R_ARTICLE_LIST` (ALV with row coloring + drill-down popup), `ZRET_R_ARTICLE_CREATE`

### Phase 2.6 — Customer master

- Table `ZRET_T_CUSTOMER` with 4 segments: M (Store), W (Web), B (B2B), E (Export)
- 5 fictitious customers including multi-currency (1 customer in MAD)
- Class `ZCL_RET_CUSTOMER` (lighter, no enrichment)
- Refactor `ZCL_RET_SALES_ORDER` to validate customer + snapshot name from master

### Phase 2.7 — Site master

- Table `ZRET_T_SITE` (stores + warehouses)
- 4 fictitious sites: 1 central warehouse + 1 regional + 2 stores
- Class `ZCL_RET_SITE` with type constants (`store`, `warehouse`)
- Used in Phase 3.2 for delivery source validation

### Phase 3.1 — Sales Order

- Tables `ZRET_T_SO` (header) + `ZRET_T_SO_ITEM` (items)
- Class `ZCL_RET_SALES_ORDER` with full life-cycle methods + 10 unit tests
- Programs: `ZRET_R_SO_CREATE`, `ZRET_R_SO_LIST` (ALV with status colors + popup ALV drill-down on items)

### Phase 3.2 — Delivery

- Tables `ZRET_T_DELIV` + `ZRET_T_DELIV_ITE` (16-char limit)
- Class `ZCL_RET_DELIVERY` with `create_from_so` orchestrating SO + Site + Customer
- 9 unit tests including critical lifecycle test `so_becomes_delivered` and `cannot_redeliver_so`
- Programs: `ZRET_R_DELIV_CREATE`, `ZRET_R_DELIV_LIST`

### Phase 3.3 — Invoice

- Tables `ZRET_T_INV` + `ZRET_T_INV_ITEM`
- Class `ZCL_RET_INVOICE` with `create_from_delivery` — 4 classes orchestrated atomically
- Status transitions on 2 upstream documents (SO → Billed, Delivery → Shipped)
- Program `ZRET_R_INV_CREATE`

### Polish — F4 search helps (matchcodes)

- Domains with fixed values for all status fields:
  - `ZDO_RET_SO_STATUS` (O=Open, D=Delivered, B=Billed, C=Cancelled)
  - `ZDO_RET_DELIV_STATUS` (C=Created, S=Shipped, R=Received)
  - `ZDO_RET_INV_STATUS` (O=Open, P=Paid, V=Voided)
- Data elements + table modifications applied → F4 search help available on every status filter

---

## Test data shipped (seed)

### 5 articles

| ID     | Name                            | Type | Price HT  | EAN            |
|--------|---------------------------------|------|-----------|----------------|
| ART001 | Trail running shoes men size 42 | HARD | 29.99 EUR | 3608412345678  |
| ART002 | Cotton T-shirt black size M     | SOFT | 7.99 EUR  | 3608412345685  |
| ART003 | Stainless steel water bottle    | ACCE | 4.99 EUR  | 3608412345692  |
| ART004 | Chocolate protein bar 60g       | CONS | 1.49 EUR  | 3608412345708  |
| ART005 | Wool beanie grey                | SOFT | 12.50 EUR | 3608412345715  |

### 5 customers

| ID       | Name                  | Segment   | City       | Currency |
|----------|-----------------------|-----------|------------|----------|
| STORE001 | Store Lille Center    | Store (M) | Lille      | EUR      |
| STORE002 | Store Bordeaux Lac    | Store (M) | Bordeaux   | EUR      |
| WEB001   | E-commerce France     | Web (W)   | Paris      | EUR      |
| B2B001   | Centrale Achat B2B    | B2B (B)   | Paris      | EUR      |
| EXP001   | Export Casablanca     | Export (E)| Casablanca | MAD      |

### 4 sites

| ID    | Name                         | Type      | City     |
|-------|------------------------------|-----------|----------|
| WH01  | Central Warehouse Paris      | Warehouse | Paris    |
| WH02  | Regional Warehouse Bordeaux  | Warehouse | Bordeaux |
| ST01  | Store Lille                  | Store     | Lille    |
| ST02  | Store Bordeaux Lac           | Store     | Bordeaux |

---

## Testing — ABAP Unit (31 tests green)

| Class                  | Tests | Notable patterns |
|------------------------|-------|------------------|
| `ZCL_RET_ARTICLE`      | 12    | TTC computation, color assignment, CRUD with cascade teardown via `customer_id` filter |
| `ZCL_RET_SALES_ORDER`  | 10    | Customer master validation, lifecycle helper `build_basic_*`, exception context assertion |
| `ZCL_RET_DELIVERY`     | 9     | `class_setup` for shared test customer, double-delivery prevention, lifecycle transition test |

Total runtime: ~500 ms across all 31 tests.

---

## Repo layout

```
src/
├── zret_root.devc.xml               # Root showcase package
├── zret_core.devc.xml               # Core types, exceptions, status domains
│   ├── doma/                        # ZDO_RET_*_STATUS
│   ├── dtel/                        # ZDE_RET_*_STATUS
│   └── classes/                     # ZCX_RET_CORE
├── zret_md.devc.xml                 # Master Data
│   ├── tabl/                        # ZRET_T_ARTICLE, ZRET_T_CUSTOMER, ZRET_T_SITE
│   ├── classes/                     # ZCL_RET_ARTICLE, ZCL_RET_CUSTOMER, ZCL_RET_SITE
│   └── prog/                        # CREATE / LIST programs
└── zret_sd.devc.xml                 # Sales & Distribution
    ├── tabl/                        # ZRET_T_SO, ZRET_T_DELIV, ZRET_T_INV (+items)
    ├── classes/                     # ZCL_RET_SALES_ORDER, _DELIVERY, _INVOICE
    └── prog/                        # SO/DELIV/INV CREATE + LIST
```

---

## Getting started

**Prerequisites**: SAP ABAP Platform 1909 Developer Edition running locally (Docker recommended).

1. Install **abapGit standalone** in your system (one-time)
2. Clone this repo via abapGit:
   ```
   https://github.com/Koraeos/sap-retail-z-sandbox.git
   ```
3. Pull into the `ZRET_ROOT` package on your system
4. Activate all objects (Ctrl+F3 on each class / table / report)
5. Seed initial data:
   - Articles: pre-loaded in test data, or use `ZRET_R_ARTICLE_CREATE`
   - Customers: run `ZRET_R_CUSTOMER_CREATE` 5 times
   - Sites: run `ZRET_R_SITE_CREATE` 4 times
6. Run the cycle:
   - `ZRET_R_SO_CREATE` to create a sales order
   - `ZRET_R_DELIV_CREATE` to ship it (transitions SO to Delivered)
   - `ZRET_R_INV_CREATE` to bill it (transitions SO to Billed)
   - `ZRET_R_SO_LIST` / `ZRET_R_DELIV_LIST` to visualize the cycle in ALV with status colors

---

## Roadmap

- ✅ **Phase 1** — Sandbox setup, first DDIC table, first report
- ✅ **Phase 2** — OO refactor (domain class + exception), ABAP Unit tests
- ✅ **Phase 2.6** — Customer master with 4 segments, multi-currency
- ✅ **Phase 2.7** — Site master (stores + warehouses)
- ✅ **Phase 3.1** — Sales Order (creation, list, drill-down)
- ✅ **Phase 3.2** — Delivery (create_from_so, lifecycle transition)
- ✅ **Phase 3.3** — Invoice (create_from_delivery, double lifecycle transition)
- ✅ **Polish** — Status matchcodes (F4 search helps) on all transactional tables
- 🚧 **Phase 6** — CDS views + Fiori Elements (List Report + Object Page) — for portfolio video
- ⏳ **Phase 4** — Z purchase cycle (PO → goods receipt → stock)
- ⏳ **Phase 2.5** — Article hierarchy (super-model → model → variant, Decathlon-style)
- ⏳ **Phase 3.5** — SD Partner Roles (Sold-to / Ship-to / Bill-to / Payer)
- ⏳ **Phase 5** — Pseudo-EWM (warehouse, tasks, transport units)
- ⏳ **Phase 7** — Production-readiness polish (rename mis-named DDIC objects, complete update programs, additional tests)

---

## Known limitations / future improvements

- Some `customer_id` cities were left empty in seed data (forgot during entry, no functional impact)
- One data element (`ZDO_RET_DELIV_STATUS`) was originally created with the domain prefix by mistake, then cleaned up — naming is now consistent
- Update method on `ZCL_RET_CUSTOMER` not yet implemented (planned for Phase 7 polish)
- Invoice has no list program yet (`ZRET_R_INV_LIST`) — same pattern as delivery list, planned
- No partner role concept on SO yet — planned for Phase 3.5
- VAT computation is a hardcoded 20% rate as a class constant — in production, would be derived from tax code via `T007A` / pricing conditions

---

## Author

**Romain Hecquet**

- GitHub: [@Koraeos](https://github.com/Koraeos)
- Email: hecquet.rom@gmail.com

Career transition from retail operations (ex-Decathlon) to SAP technico-functional consulting, with a focus on **SAP Retail / S/4HANA Retail**.
