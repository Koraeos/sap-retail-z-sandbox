# SAP Retail Z Sandbox

> Hands-on ABAP Platform 1909 project simulating a minimal SAP Retail backend with a complete **Order-to-Cash cycle** AND a **pseudo-EWM warehouse module** (Inbound + Putaway + Outbound). Built from scratch to master SAP Retail data structures, OO-ABAP design patterns, transactional integrity, asynchronous task workflows, ABAP Unit testing, and the RAP / Fiori Elements pipeline.

---

## Context

Self-driven learning project by Romain Hecquet — retail professional (ex-Decathlon) transitioning to **SAP technico-functional consulting**. This repository materialises a step-by-step dive into SAP Retail through custom `Z` objects running on a local SAP ABAP Platform 1909 trial.

The goal is twofold:

- Build hands-on technical depth on ABAP, DDIC, OO, exceptions, transactions, asynchronous workflows, unit testing, and the modern RAP / Fiori Elements stack
- Keep each step close to real retail semantics (article types, customer segments, sites, the Order-to-Cash cycle, multi-currency, warehouse zones, inbound goods receipt, putaway, picking, loading, goods issue)

---

## Highlights

- ✅ **Complete Order-to-Cash cycle in custom Z**: Sales Order → Delivery → Invoice with status transitions (`Open` → `Delivered` → `Billed`)
- ✅ **Pseudo-EWM warehouse module**: PO → Goods Receipt → auto-Putaway task → Pick → auto-Load task → Goods Issue, with zone-aware stock (RECV / STORAGE / STAGING / LOAD_DOCK)
- ✅ **Partner Roles SAP-style (KNVP pattern)**: Sold-to / Ship-to / Bill-to / Payer with `partner_counter` for multi-Ship-to scenarios, smart fallback to sold-to, scenarios B2C + B2B Decathlon-style with HQ + 3 regional depots
- ✅ **10 domain classes** that compose each other across modules (Sales, Procurement, Stock, Warehouse Tasks, Partner Functions)
- ✅ **52 ABAP Unit tests green** — uncommon in the ABAP world, signals production-grade rigor
- ✅ **Atomic transactions** with `COMMIT WORK` / `ROLLBACK WORK` — multi-table updates respect business invariants
- ✅ **Snapshot pattern** on every transactional document — customer/article/supplier/price values are frozen at transaction time for audit traceability
- ✅ **Append-only stock movement journal** with typed movements (101 Goods Receipt, 311 Transfer, 411 Pick, 412 Load, 561 Initial, 601 Goods Issue) mirroring SAP MM-IM standard codes
- ✅ **Event-driven task chaining**: a confirmed Goods Receipt automatically creates a Putaway task; a confirmed Pick automatically creates a Load task — same pattern as real EWM
- ✅ **End-to-end document flow** — every stock movement traces back through warehouse task → purchase order item, every invoice line traces to delivery item to original sales order
- ✅ **Layered architecture** — presentation (programs) → domain (classes) → data (DDIC tables), tested in isolation
- ✅ **Fiori Elements List Report** functional via the full RAP pipeline (CDS view → Service Definition → Service Binding → OData V2 - UI)
- ✅ **Type refactor episode** — aligned new warehouse tables on existing master data elements (`zde_ret_article_id`, `werks_d`, `meins`, `waers`) for native CDS JOINs without implicit conversions

---

## Tech stack

- **SAP ABAP Platform 1909** — local Developer Edition (Docker)
- **ABAP OO** — domain classes, exception class with context attribute, private helpers, class-methods
- **ABAP Dictionary** — transparent tables, domains with fixed values, data elements typed on standard SAP elements (`werks_d`, `meins`, `waers`), F4 search helps
- **CDS Views** — consumption view `ZC_RET_SO_HEADER` with `@UI` annotations
- **RAP pipeline** — Service Definition + Service Binding (OData V2 - UI)
- **Fiori Elements** — List Report functional, Object Page limitation on 1909 trial Docker documented
- **SALV** (`cl_salv_table`) — modern fullscreen ALV with header grid, row coloring, double-click events, popup ALV (drill-down), aggregations + subtotals
- **ABAP Unit** — local test classes with class_setup, teardown, fixtures, helpers, test isolation
- **abapGit** — source-based version control, synced with GitHub
- **Eclipse / ABAP Development Tools (ADT)** — primary IDE for source-based DDIC and class editing

---

## Architecture

The project follows a clean **layered OO approach** — uncommon in the ABAP world, standard best practice everywhere else. Three layers, strict separation of responsibilities, organised in **bounded contexts** via packages.

```
╔══════════════════════════════════════════════════════════════════════════╗
║  PACKAGE STRUCTURE — bounded contexts                                    ║
║                                                                          ║
║  ZRET_ROOT          showcase root (master package)                       ║
║  ├── ZRET_CORE      types, exceptions, status domains, data elements     ║
║  ├── ZRET_MD        master data (article, customer, site, supplier)      ║
║  ├── ZRET_SD        sales (SO, delivery, invoice) + CDS Fiori            ║
║  ├── ZRET_MM        materials management (purchase orders)               ║
║  └── ZRET_WHSE      warehouse (stock, movements, tasks, zones)           ║
╚══════════════════════════════════════════════════════════════════════════╝
                              │ delegates to
                              ▼
╔══════════════════════════════════════════════════════════════════════════╗
║  PRESENTATION LAYER — programs / reports                                 ║
║                                                                          ║
║  Master:    ZRET_R_ARTICLE_LIST / CREATE                                 ║
║             ZRET_R_CUSTOMER_CREATE                                       ║
║             ZRET_R_SITE_CREATE                                           ║
║  Sales:     ZRET_R_SO_CREATE / LIST                                      ║
║             ZRET_R_DELIV_CREATE / LIST                                   ║
║             ZRET_R_INV_CREATE                                            ║
║  Purchase:  ZRET_R_PO_DEMO (creates PO + posts GR)                       ║
║             ZRET_R_PO_LIST (ALV with optional item drill-down)           ║
║  Warehouse: ZRET_R_SEED_WHSE      (zones + initial stock)                ║
║             ZRET_R_SEED_SUPPLIERS (3 sample suppliers)                   ║
║             ZRET_R_OUTBOUND_DEMO  (full Pick → Load → GI flow)           ║
║             ZRET_R_STOCK_DASH     (SALV stock by article × site × zone)  ║
║             ZRET_R_WH_TASK_LIST    (ALV with status filter)              ║
║             ZRET_R_WH_TASK_CONFIRM (confirms a task, posts the mvt)      ║
║             ZRET_R_WIPE_WHSE       (utility: clear transactional tables) ║
╚══════════════════════════════════════════════════════════════════════════╝
                              │ delegates to
                              ▼
╔══════════════════════════════════════════════════════════════════════════╗
║  DOMAIN LAYER — classes that own business logic                          ║
║                                                                          ║
║  Master:                                                                 ║
║    ZCL_RET_ARTICLE        select_all, get_by_id, create, update,         ║
║                            delete (soft), enrich_article                 ║
║    ZCL_RET_CUSTOMER       select_all, get_by_id, create                  ║
║    ZCL_RET_SITE           select_all, get_by_id, create                  ║
║                                                                          ║
║  Sales:                                                                  ║
║    ZCL_RET_SALES_ORDER    select_all, get_by_id, create                  ║
║                            (composes Article + Customer)                 ║
║    ZCL_RET_DELIVERY       select_all, get_by_id, create_from_so          ║
║                            (composes Sales Order + Site + Customer)      ║
║    ZCL_RET_INVOICE        select_all, get_by_id, create_from_deliv      ║
║                            (composes Delivery + Sales Order)             ║
║    ZCL_RET_CUST_PARTNER   seed_partner_functions, assign_partner,        ║
║                            get_partners, get_partner_for_function        ║
║                            (with smart fallback), deactivate_partner     ║
║                            (KNVP pattern with auto-incremented counter)  ║
║                                                                          ║
║  Procurement & Warehouse:                                                ║
║    ZCL_RET_PURCH_ORDER    create_po, post_goods_receipt, get_header,     ║
║                            cancel_po, update_status                      ║
║                            (auto-creates Putaway task on GR)             ║
║    ZCL_RET_STOCK          post_movement, get_available,                  ║
║                            validate_availability, load_initial_stock     ║
║                            (zone-aware, atomic LUW with rollback)        ║
║    ZCL_RET_WH_TASK        create_task, confirm, cancel, get_open_tasks   ║
║                            (auto-chains Pick → Load on confirm)          ║
║                                                                          ║
║  ZCX_RET_CORE — custom exception inheriting CX_STATIC_CHECK              ║
╚══════════════════════════════════════════════════════════════════════════╝
                              │ reads / writes via SQL + COMMIT
                              ▼
╔══════════════════════════════════════════════════════════════════════════╗
║  DATA LAYER — DDIC transparent tables                                    ║
║                                                                          ║
║  Master (5):                                                             ║
║    ZRET_T_ARTICLE   ZRET_T_CUSTOMER   ZRET_T_SITE                        ║
║    ZRET_T_SUPPLIER  (created for the EWM phase)                          ║
║                                                                          ║
║  Sales (8):                                                              ║
║    ZRET_T_SO + ZRET_T_SO_ITEM                                            ║
║    ZRET_T_DELIV + ZRET_T_DELIV_ITE                                       ║
║    ZRET_T_INV + ZRET_T_INV_ITEM                                          ║
║    ZRET_T_PART_FCT       partner functions reference (AG/WE/RE/RG)       ║
║    ZRET_T_CUST_PRT       customer × partner_function × counter           ║
║                                                                          ║
║  Procurement (2):                                                        ║
║    ZRET_T_PO + ZRET_T_PO_ITEM                                            ║
║                                                                          ║
║  Warehouse (3):                                                          ║
║    ZRET_T_WHSE_ZONE   master data of 4 zones                             ║
║    ZRET_T_STOCK       stock by article × site × zone (composite key)     ║
║    ZRET_T_STK_MVT     append-only movement journal                       ║
║    ZRET_T_WH_TASK     warehouse tasks (Putaway / Pick / Load)            ║
║                                                                          ║
║  Domains with fixed values (13 total):                                   ║
║    ZDO_RET_SO_STATUS    (O / D / B / C)                                  ║
║    ZDO_RET_DELIV_STATUS (C / S / R)                                      ║
║    ZDO_RET_INV_STATUS   (O / P / V)                                      ║
║    ZRET_D_MVT_TYPE      (101 / 311 / 411 / 412 / 561 / 601)              ║
║    ZRET_D_WHSE_ZONE     (RECV / STORAGE / STAGING / LOAD_DOCK)           ║
║    ZRET_D_PO_STATUS     (O / I / D / C / X)                              ║
║    ZRET_D_WH_TASK_TYPE  (PUTAWAY / PICK / LOAD)                          ║
║    ZRET_D_WH_TASK_STAT  (O / C / X)                                      ║
║    ZDOM_RET_PART_FCT    (AG / WE / RE / RG)  Partner functions           ║
║    ZDOM_RET_CUST_TYPE   (B2B / B2C)                                      ║
╚══════════════════════════════════════════════════════════════════════════╝
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

## Pseudo-EWM warehouse cycle (Phase 5)

The complete warehouse cycle in custom Z, mirroring real SAP EWM patterns. The system models **zone-aware stock**, **typed stock movements** (mirroring MM-IM movement types 101 / 311 / 411 / 412 / 561 / 601), and **asynchronous warehouse tasks** that must be confirmed by an operator to physically move the goods.

### Inbound side (PO → Goods Receipt → auto-Putaway)

```
1. PO created via ZCL_RET_PURCH_ORDER.create_po
   - validates supplier and articles
   - snapshots supplier_name + article_name
   - generates PO number, computes total
   - INSERT header + N items, COMMIT
   PO status: 'O' (Open)

2. Goods Receipt posted via ZCL_RET_PURCH_ORDER.post_goods_receipt
   ↓ Refuses over-delivery (delivered_qty + qty > order_qty raises exception)
   ↓ ZCL_RET_STOCK.post_movement (mvt_type 101, ref_doc = PO)
     - INSERT mvt journal line (RECV zone)
     - UPSERT into stock table (+qty in RECV)
     - COMMIT (atomic LUW)
   ↓ UPDATE PO item delivered_qty
   ↓ UPDATE PO header status (Open → In Delivery, or → Delivered if all items full)
   ↓ Auto-creates a PUTAWAY warehouse task in status Open
     (RECV → STORAGE, preserves PO ref_doc for end-to-end traceability)
   ↓
   Stock now in zone RECV ; Putaway task waiting for confirmation
```

### Putaway (warehouse worker confirms the task)

```
3. Putaway task confirmed via ZCL_RET_WH_TASK.confirm
   ↓ ZCL_RET_STOCK.post_movement (mvt_type 311, RECV → STORAGE)
   ↓ UPDATE task: status Open → Confirmed, mvt_doc filled,
     confirmed_by + confirmed_on stamped
   ↓
   Stock now in zone STORAGE — available for sale
```

### Outbound side (Pick → auto-Load → Goods Issue)

```
4. Pick task created via ZCL_RET_WH_TASK.create_task
   (STORAGE → STAGING)

5. Pick confirmed via ZCL_RET_WH_TASK.confirm
   ↓ ZCL_RET_STOCK.post_movement (mvt_type 411, STORAGE → STAGING)
   ↓ Status flip: Open → Confirmed
   ↓ Auto-creates a LOAD task in status Open (STAGING → LOAD_DOCK)
     — this is the Pick → Load chaining; preserves ref_doc

6. Load confirmed via ZCL_RET_WH_TASK.confirm
   ↓ ZCL_RET_STOCK.post_movement (mvt_type 412, STAGING → LOAD_DOCK)
   ↓ Status flip: Open → Confirmed
   ↓ Chain stops at Load (no further auto-creation — verified by negative test)

7. Goods Issue posted via direct ZCL_RET_STOCK.post_movement
   (mvt_type 601, LOAD_DOCK → consumed)
   ↓
   Stock leaves the system → physically delivered to customer
```

**Key technical points showcased:**

- **Zone-aware stock** with composite key (article × site × zone) — same model as EWM bin/zone
- **Typed stock movements** with src/dst zones — one ledger entry per movement, append-only
- **Asynchronous task pattern** — task creation and physical movement are separate; tasks wait in `Open` until confirmed
- **Event-driven chaining** — confirming a task can auto-create the next one (GR → Putaway, Pick → Load)
- **Status workflow locked by code** — cannot confirm twice, cannot cancel a Confirmed task
- **Document flow preserved** — a stock movement points to its task; a task points to its originating PO ; from any movement you can trace back to the PO

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
- Class `ZCL_RET_CUSTOMER`
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

- Tables `ZRET_T_DELIV` + `ZRET_T_DELIV_ITE` (16-char limit on table names)
- Class `ZCL_RET_DELIVERY` with `create_from_so` orchestrating SO + Site + Customer
- 9 unit tests including critical lifecycle test `so_becomes_delivered` and `cannot_redeliver_so`
- Programs: `ZRET_R_DELIV_CREATE`, `ZRET_R_DELIV_LIST`

### Phase 3.3 — Invoice

- Tables `ZRET_T_INV` + `ZRET_T_INV_ITEM`
- Class `ZCL_RET_INVOICE` with `create_from_delivery` — 4 classes orchestrated atomically
- Status transitions on 2 upstream documents (SO → Billed, Delivery → Shipped)
- Program `ZRET_R_INV_CREATE`

### Phase 3.5 — Partner Roles SD (KNVP pattern)

- 2 domains with fixed values: `ZDOM_RET_PART_FCT` (AG / WE / RE / RG) and `ZDOM_RET_CUST_TYPE` (B2B / B2C)
- 2 data elements: `ZDE_RET_PART_FCT`, `ZDE_RET_CUST_TYPE`
- 2 new tables in `ZRET_SD`:
  - `ZRET_T_PART_FCT` — reference table for partner functions (delivery class C — Customizing)
  - `ZRET_T_CUST_PRT` — assignments (customer × partner_function × counter × partner_customer)
- Class `ZCL_RET_CUST_PARTNER` with 5 public methods:
  - `seed_partner_functions` (idempotent setup of AG/WE/RE/RG)
  - `assign_partner` (auto-increments `partner_counter` when multiple partners share a function)
  - `get_partners` (full list for a sold-to)
  - `get_partner_for_function` with **smart fallback**: returns the sold-to itself if no explicit partner is assigned (B2C pattern)
  - `deactivate_partner` (soft delete via `active_flag`)
- Triple validation in `assign_partner`: sold-to exists + partner customer exists + partner function valid (otherwise `zcx_ret_core` raised)
- Program `ZRET_R_SEED_PARTNERS` with two scenarios:
  - **B2C** (DUPONT01): no explicit assignment, all functions resolve to DUPONT01 itself via fallback
  - **B2B Decathlon-style** (HQPARIS): 1 sold-to, 3 ship-to (DEP_LYON / DEP_MAR / DEP_LIL with auto counters 001/002/003), bill-to = HQPARIS, payer = BNPBANK
- 6 ABAP Unit tests covering: seed idempotency, assignment happy path, validation refusal of unknown customer, smart fallback to sold-to, multi-Ship-to counter increment, deactivate-then-fallback end-to-end
- Pattern faithful to **SAP standard table KNVP** (simplified: skipped Sales Org / Distribution Channel / Division dimensions for portfolio scope)

### Polish — F4 search helps (matchcodes)

- Domains with fixed values for all status fields
- Data elements + table modifications applied → F4 search help available on every status filter

### Phase 5 Session 1 — Inbound EWM (PO + Goods Receipt + zone-aware stock)

- 2 new bounded-context packages: `ZRET_MM`, `ZRET_WHSE`
- 3 domains + 3 data elements (movement type, warehouse zone, PO status)
- 6 tables: `ZRET_T_WHSE_ZONE`, `ZRET_T_STOCK`, `ZRET_T_STK_MVT`, `ZRET_T_PO`, `ZRET_T_PO_ITEM`, `ZRET_T_SUPPLIER`
- 2 classes: `ZCL_RET_STOCK` (zone-aware), `ZCL_RET_PURCH_ORDER`
- 4 programs: seeders for zones / suppliers / initial stock, PO demo, ALV PO list with parameter-based drill-down
- 6 ABAP Unit tests (validation, UPSERT, transfer between zones, atomic LUW)
- End-to-end inbound flow demonstrated: PO 1 → GR 50 PC → stock in RECV

### Phase 5 Session 2 — Warehouse Tasks (Putaway)

- 2 domains + 2 data elements (task type, task status)
- 1 table: `ZRET_T_WH_TASK` with triple timestamping (created / confirmed / cancelled)
- 1 class: `ZCL_RET_WH_TASK` (create / confirm / cancel)
- Integration: `post_goods_receipt` now auto-creates a PUTAWAY task on GR
- 2 programs: `ZRET_R_WH_TASK_LIST` (ALV), `ZRET_R_WH_TASK_CONFIRM` (confirm + show before/after)
- 7 ABAP Unit tests (lifecycle, idempotency, status transitions locked)

### Phase 5 Session 3 — Outbound (Pick + Load + Goods Issue)

- Auto-chaining: a confirmed Pick task automatically creates a Load task (`ZCL_RET_WH_TASK.confirm` extended)
- Chain stops at Load (verified by `test_load_confirm_no_chain` negative test)
- 2 programs: `ZRET_R_OUTBOUND_DEMO` (full chain demonstration), `ZRET_R_STOCK_DASH` (SALV with subtotals by article and site)
- 2 additional unit tests added to `ZCL_RET_WH_TASK` test class (total 9)
- End-to-end outbound flow demonstrated: STORAGE 100 → Pick 30 → STAGING 30 → Load → LOAD_DOCK 30 → GI → out

### Refactor — Type alignment with master data

- Detected mismatch: warehouse tables used generic `abap.char(10)` for article_id / site_id, while masters use proper data elements (`zde_ret_article_id` CHAR 20, `werks_d` CHAR 4)
- Created one-shot wipe program `ZRET_R_WIPE_WHSE` to clear the 5 transactional warehouse tables
- Refactored 5 tables to use `zde_ret_article_id`, `werks_d`, `meins`, `waers` — aligned with SAP convention of always using typed data elements in business tables
- Re-seeded via existing programs ; all 15 EWM unit tests still green after refactor (zero regression, classes auto-adapted thanks to typed references)
- Unlocks future native CDS JOINs between warehouse and masters with no implicit type conversion

### Phase 6 — CDS + Fiori Elements (List Report functional, Object Page limitation documented)

- CDS consumption view `ZC_RET_SO_HEADER` with `@UI` annotations (lineItem, headerInfo, fieldGroup, facet)
- Service Definition `ZSD_RET_SO`, Service Binding `ZSB_RET_SO` (OData V2 - UI), both active and published
- **List Report** ✅: filters, columns with custom labels, navigation, real data — full RAP pipeline operational
- **Object Page** ❌: facets and identification annotations silently ignored on this 1909 trial Docker build, despite 5 different annotation approaches tested (`#IDENTIFICATION_REFERENCE` with/without `purpose: #STANDARD`, `#FIELDGROUP_REFERENCE` with explicit qualifier, default rendering without facet, etc.)
- Limitation documented as a runtime constraint of the embedded Fiori Preview on 1909 trial Docker — the same code would render correctly on S/4HANA recent or with a separate Gateway. The List Report alone proves mastery of the full pipeline (CDS → Service Definition → Service Binding → OData V2 → Fiori Elements)

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

### 3 suppliers (for the EWM phase)

| ID     | Name                  | City       | Country |
|--------|-----------------------|------------|---------|
| SUP001 | Acme Distribution     | Lille      | FR      |
| SUP002 | Global Sportswear Ltd | Manchester | GB      |
| SUP003 | EcoTextiles GmbH      | Munich     | DE      |

### 4 warehouse zones (master data)

| Code      | Name            | Category | Description              |
|-----------|-----------------|----------|--------------------------|
| RECV      | Receiving Zone  | INBOUND  | Goods receipt area       |
| STORAGE   | Storage Area    | STORAGE  | Long-term storage        |
| STAGING   | Staging Zone    | OUTBOUND | Pre-loading staging area |
| LOAD_DOCK | Loading Dock    | OUTBOUND | Truck loading dock       |

### Initial stock (seeded by `ZRET_R_SEED_WHSE`)

100 PC of every article in every site (4 × 3 = 12 stock lines), all in zone STORAGE, posted as movement type 561 (initial stock load) — provides a representative starting state for any demo.

### Partner Roles scenarios (seeded by `ZRET_R_SEED_PARTNERS`)

**6 additional customers to demonstrate B2B Decathlon-style and B2C patterns:**

| ID       | Name                  | Type | City      | Role in scenarios |
|----------|-----------------------|------|-----------|-------------------|
| HQPARIS  | Decathlon HQ Paris    | B2B  | Paris     | Sold-to + Bill-to of B2B chain |
| DEP_LYON | Depot Lyon            | B2B  | Lyon      | Ship-to #1 (counter 001)       |
| DEP_MAR  | Depot Marseille       | B2B  | Marseille | Ship-to #2 (counter 002)       |
| DEP_LIL  | Depot Lille           | B2B  | Lille     | Ship-to #3 (counter 003)       |
| BNPBANK  | BNP Paribas Finance   | B2B  | Paris     | Payer (RG)                     |
| DUPONT01 | Mr Dupont             | B2C  | Lyon      | All 4 roles via fallback       |

**Resolved partner matrix after seed:**

```
Customer HQPARIS:                  Customer DUPONT01:
  AG -> HQPARIS                      AG -> DUPONT01     ← fallback
  WE -> DEP_LYON (counter 001)       WE -> DUPONT01     ← fallback
  RE -> HQPARIS                      RE -> DUPONT01     ← fallback
  RG -> BNPBANK                      RG -> DUPONT01     ← fallback
```

The fallback pattern means consuming code (e.g. delivery / invoice) can call `get_partner_for_function` blindly without checking for null — there's always a meaningful partner returned.

---

## Testing — ABAP Unit (52 tests green)

| Class                  | Tests | Notable patterns |
|------------------------|-------|------------------|
| `ZCL_RET_ARTICLE`      | 12    | TTC computation, color assignment, CRUD with cascade teardown via `customer_id` filter |
| `ZCL_RET_SALES_ORDER`  | 10    | Customer master validation, lifecycle helper `build_basic_*`, exception context assertion |
| `ZCL_RET_DELIVERY`     | 9     | `class_setup` for shared test customer, double-delivery prevention, lifecycle transition test |
| `ZCL_RET_STOCK`        | 6     | Zone-aware UPSERT, atomic LUW with rollback, transfer between zones, validation cases |
| `ZCL_RET_WH_TASK`      | 9     | Lifecycle, idempotency (cannot confirm twice), Pick → Load auto-chaining, chain stops at Load |
| `ZCL_RET_CUST_PARTNER` | 6     | Seed idempotency, validation refusal on unknown customer, smart fallback to sold-to, multi-Ship-to counter increment, deactivate-then-fallback end-to-end |

Total runtime: ~1.2 s across all 52 tests.

**Patterns used across all tests:**
- Test isolation via `teardown` (clean DB state after each test)
- Given/When/Then style commenting
- Negative tests on validation paths (insufficient stock, invalid quantity, missing zone, illegal status transition)
- Composite flow tests (e.g. `test_transfer_zones`: load stock + post movement + verify in 2 zones)

---

## Repo layout

```
src/
├── zret_root.devc.xml               # Root showcase package
├── zret_core.devc.xml               # Core types, exceptions, status domains
│   ├── doma/                        # ZDO_RET_*_STATUS, ZRET_D_*
│   ├── dtel/                        # ZDE_RET_*_STATUS, ZRET_DE_*
│   └── classes/                     # ZCX_RET_CORE
├── zret_md.devc.xml                 # Master Data
│   ├── tabl/                        # ARTICLE, CUSTOMER, SITE, SUPPLIER
│   ├── classes/                     # ZCL_RET_ARTICLE, _CUSTOMER, _SITE
│   └── prog/                        # CREATE / LIST programs + seeders
├── zret_sd.devc.xml                 # Sales & Distribution
│   ├── tabl/                        # SO, DELIV, INV (+items)
│   ├── classes/                     # ZCL_RET_SALES_ORDER, _DELIVERY, _INVOICE
│   ├── ddls/                        # CDS view ZC_RET_SO_HEADER
│   ├── srvd/srvb/                   # Service Definition + Binding
│   └── prog/                        # SO/DELIV/INV CREATE + LIST
├── zret_mm.devc.xml                 # Materials Management (purchasing)
│   ├── tabl/                        # ZRET_T_PO, ZRET_T_PO_ITEM
│   ├── classes/                     # ZCL_RET_PURCH_ORDER
│   └── prog/                        # PO_DEMO, PO_LIST
└── zret_whse.devc.xml               # Warehouse (pseudo-EWM)
    ├── tabl/                        # WHSE_ZONE, STOCK, STK_MVT, WH_TASK
    ├── classes/                     # ZCL_RET_STOCK, ZCL_RET_WH_TASK
    └── prog/                        # SEED_WHSE, OUTBOUND_DEMO,
                                     # STOCK_DASH, WH_TASK_LIST/CONFIRM,
                                     # WIPE_WHSE (utility)
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
   - Suppliers: run `ZRET_R_SEED_SUPPLIERS` once
   - Warehouse zones + initial stock: run `ZRET_R_SEED_WHSE` once
   - Partner Roles scenarios (B2B + B2C): run `ZRET_R_SEED_PARTNERS` once
6. Run the **Order-to-Cash** cycle:
   - `ZRET_R_SO_CREATE` to create a sales order
   - `ZRET_R_DELIV_CREATE` to ship it (transitions SO to Delivered)
   - `ZRET_R_INV_CREATE` to bill it (transitions SO to Billed)
   - `ZRET_R_SO_LIST` / `ZRET_R_DELIV_LIST` to visualize the cycle in ALV with status colors
7. Run the **pseudo-EWM** cycle:
   - `ZRET_R_PO_DEMO` to create a PO and post a Goods Receipt (auto-creates a Putaway task)
   - `ZRET_R_WH_TASK_LIST` to see open tasks
   - `ZRET_R_WH_TASK_CONFIRM` (with task number) to confirm the Putaway → stock moves to STORAGE
   - `ZRET_R_OUTBOUND_DEMO` to run the full Pick → Load → Goods Issue chain
   - `ZRET_R_STOCK_DASH` to see consolidated stock by article × site × zone

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
- ✅ **Phase 5.1** — Inbound EWM (PO + Goods Receipt + zone-aware stock)
- ✅ **Phase 5.2** — Warehouse Tasks (Putaway with auto-creation on GR)
- ✅ **Phase 5.3** — Outbound EWM (Pick + Load + Goods Issue, auto-chaining Pick → Load)
- ✅ **Refactor types** — alignment of warehouse tables on master data elements
- ✅ **Phase 6** — RAP / Fiori Elements pipeline (List Report functional, Object Page limitation on 1909 trial documented)
- ✅ **Phase 3.5** — SD Partner Roles (Sold-to / Ship-to / Bill-to / Payer with KNVP pattern + smart fallback)
- ⏳ **Phase 4** — Z purchase cycle extension (vendor invoice + 3-way match)
- ⏳ **Phase 2.5** — Article hierarchy (super-model → model → variant, Decathlon-style)
- ⏳ **Phase 7** — Production-readiness polish (additional tests, missing list programs, complete update methods)

---

## Known limitations / future improvements

- Some `customer_id` cities were left empty in seed data (forgot during entry, no functional impact)
- Update method on `ZCL_RET_CUSTOMER` not yet implemented (planned for Phase 7 polish)
- Invoice has no list program yet (`ZRET_R_INV_LIST`) — same pattern as delivery list, planned
- Partner Roles (Phase 3.5) is currently a **standalone module** — not yet plugged into Sales Order creation. The `ZCL_RET_SALES_ORDER.create` doesn't yet resolve Ship-to / Bill-to / Payer through `ZCL_RET_CUST_PARTNER.get_partner_for_function`. Designed and ready, integration planned for Phase 7
- Partner Roles model simplified vs SAP standard KNVP: skipped Sales Org / Distribution Channel / Division dimensions (mono-organisation portfolio scope)
- VAT computation is a hardcoded 20% rate as a class constant — in production, would be derived from tax code via `T007A` / pricing conditions
- **Fiori Object Page** silently ignored on 1909 trial Docker — 5 annotation approaches tested ; List Report works perfectly. Same code would render correctly on S/4HANA recent or with a separate Gateway
- The auto-chaining `post_goods_receipt → create_task` and `confirm_pick → create_load` runs as **3 separate LUWs** (stock movement, document update, task creation) — in production a saga pattern or compensating-transaction approach would be more robust against failures between steps. Documented and assumed for portfolio scope.
- `supplier_id` left as `abap.char(10)` (not aligned with a custom data element yet) — minor cosmetic gap, planned for Phase 7
- ABAP Unit tests rely on real DB writes + teardown rather than mocking — fine at this scale, would need test doubles in larger projects

---

## Author

**Romain Hecquet**

- GitHub: [@Koraeos](https://github.com/Koraeos)
- Email: hecquet.rom@gmail.com

Career transition from retail operations (ex-Decathlon) to SAP technico-functional consulting, with a focus on **SAP Retail / S/4HANA Retail**.
