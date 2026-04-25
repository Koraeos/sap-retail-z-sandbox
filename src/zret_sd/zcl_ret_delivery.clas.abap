CLASS zcl_ret_delivery DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Table types
    TYPES: ty_item_tab  TYPE STANDARD TABLE OF zret_t_deliv_ite WITH DEFAULT KEY.
    TYPES: ty_deliv_tab TYPE STANDARD TABLE OF zret_t_deliv     WITH DEFAULT KEY.

    " Composite return type for get_by_id
    TYPES: BEGIN OF ty_full,
             header TYPE zret_t_deliv,
             items  TYPE ty_item_tab,
           END OF ty_full.

    " Range types for select_all filters
    TYPES: ty_site_range   TYPE RANGE OF zret_t_deliv-source_site_id.
    TYPES: ty_status_range TYPE RANGE OF zret_t_deliv-status.

    " Status constants
    CONSTANTS: BEGIN OF c_status,
                 created  TYPE zret_t_deliv-status VALUE 'C',
                 shipped  TYPE zret_t_deliv-status VALUE 'S',
                 received TYPE zret_t_deliv-status VALUE 'R',
               END OF c_status.

    "! Creates a delivery from an existing Sales Order.
    "! Loads the SO, validates Open status, validates the source site is a warehouse,
    "! copies items, persists header + items, and updates the SO status to Delivered.
    CLASS-METHODS create_from_so
      IMPORTING iv_so_number           TYPE zret_t_so-so_number
                iv_source_site_id      TYPE zret_t_site-site_id
      RETURNING VALUE(rv_deliv_number) TYPE zret_t_deliv-deliv_number
      RAISING   zcx_ret_core.

    CLASS-METHODS get_by_id
      IMPORTING iv_deliv_number TYPE zret_t_deliv-deliv_number
      RETURNING VALUE(rs_full)  TYPE ty_full
      RAISING   zcx_ret_core.

    CLASS-METHODS select_all
      IMPORTING it_site_range   TYPE ty_site_range OPTIONAL
                it_status_range TYPE ty_status_range OPTIONAL
      RETURNING VALUE(rt_deliv) TYPE ty_deliv_tab.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-METHODS generate_deliv_number
      RETURNING VALUE(rv_deliv_number) TYPE zret_t_deliv-deliv_number.

ENDCLASS.


CLASS zcl_ret_delivery IMPLEMENTATION.

  METHOD create_from_so.
    " --- 1. Load SO via the SO class (raises if not found) ---
    DATA(ls_so_full) = zcl_ret_sales_order=>get_by_id( iv_so_number ).

    " --- 2. Validate SO is in Open status ---
    IF ls_so_full-header-status <> zcl_ret_sales_order=>c_status-open.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " --- 3. Validate source site exists AND is a warehouse ---
    DATA(ls_site) = zcl_ret_site=>get_by_id( iv_source_site_id ).

    IF ls_site-site_type <> zcl_ret_site=>c_type-warehouse.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " --- 4. Generate new delivery number ---
    rv_deliv_number = generate_deliv_number( ).

    " --- 5. Build delivery header (snapshots from SO + customer master) ---
    DATA ls_header TYPE zret_t_deliv.
    ls_header-mandt              = sy-mandt.
    ls_header-deliv_number       = rv_deliv_number.
    ls_header-deliv_date         = sy-datum.
    ls_header-so_number          = iv_so_number.
    ls_header-source_site_id     = iv_source_site_id.
    ls_header-customer_id        = ls_so_full-header-customer_id.
    ls_header-customer_name      = ls_so_full-header-customer_name.
    ls_header-status             = c_status-created.
    ls_header-created_by         = sy-uname.
    ls_header-created_on         = sy-datum.
    ls_header-changed_by         = sy-uname.
    ls_header-changed_on         = sy-datum.

    " Snapshot destination from customer master (best effort)
    TRY.
        DATA(ls_customer) = zcl_ret_customer=>get_by_id( ls_so_full-header-customer_id ).
        ls_header-destination_city    = ls_customer-city.
        ls_header-destination_country = ls_customer-country.
      CATCH zcx_ret_core.
        ls_header-destination_country = 'FR'.
    ENDTRY.

    " --- 6. Build delivery items by copying from SO items ---
    DATA: lt_deliv_items TYPE ty_item_tab,
          ls_deliv_item  TYPE zret_t_deliv_ite.

    LOOP AT ls_so_full-items INTO DATA(ls_so_item).
      CLEAR ls_deliv_item.
      ls_deliv_item-mandt          = sy-mandt.
      ls_deliv_item-deliv_number   = rv_deliv_number.
      ls_deliv_item-item_number    = ls_so_item-item_number.
      ls_deliv_item-so_number      = ls_so_item-so_number.
      ls_deliv_item-so_item_number = ls_so_item-item_number.
      ls_deliv_item-article_id     = ls_so_item-article_id.
      ls_deliv_item-article_name   = ls_so_item-article_name.
      ls_deliv_item-quantity       = ls_so_item-quantity.
      ls_deliv_item-uom            = ls_so_item-uom.
      APPEND ls_deliv_item TO lt_deliv_items.
    ENDLOOP.

    " --- 7. Persist atomically (header + items + SO status update) ---
    INSERT zret_t_deliv FROM @ls_header.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    INSERT zret_t_deliv_ite FROM TABLE @lt_deliv_items.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " *** THE LIFECYCLE TRANSITION: SO Open -> Delivered ***
    UPDATE zret_t_so
      SET status     = @zcl_ret_sales_order=>c_status-delivered,
          changed_by = @sy-uname,
          changed_on = @sy-datum
      WHERE so_number = @iv_so_number.

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.


  METHOD get_by_id.
    SELECT SINGLE *
      FROM zret_t_deliv
      WHERE deliv_number = @iv_deliv_number
      INTO @rs_full-header.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    SELECT *
      FROM zret_t_deliv_ite
      WHERE deliv_number = @iv_deliv_number
      ORDER BY item_number
      INTO TABLE @rs_full-items.
  ENDMETHOD.


  METHOD select_all.
    SELECT *
      FROM zret_t_deliv
      WHERE source_site_id IN @it_site_range
        AND status         IN @it_status_range
      ORDER BY deliv_number
      INTO TABLE @rt_deliv.
  ENDMETHOD.


  METHOD generate_deliv_number.
    DATA: lv_max     TYPE zret_t_deliv-deliv_number,
          lv_new_num TYPE i.

    SELECT MAX( deliv_number )
      FROM zret_t_deliv
      INTO @lv_max.

    IF lv_max IS INITIAL.
      lv_new_num = 1.
    ELSE.
      lv_new_num = lv_max + 1.
    ENDIF.

    rv_deliv_number = |{ lv_new_num WIDTH = 10 PAD = '0' ALIGN = RIGHT }|.
  ENDMETHOD.

ENDCLASS.
