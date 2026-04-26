CLASS zcl_ret_invoice DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: ty_item_tab TYPE STANDARD TABLE OF zret_t_inv_item WITH DEFAULT KEY.
    TYPES: ty_inv_tab  TYPE STANDARD TABLE OF zret_t_inv      WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_full,
             header TYPE zret_t_inv,
             items  TYPE ty_item_tab,
           END OF ty_full.

    TYPES: ty_customer_range TYPE RANGE OF zret_t_inv-customer_id.
    TYPES: ty_status_range   TYPE RANGE OF zret_t_inv-status.

    CONSTANTS: BEGIN OF c_status,
                 open   TYPE zret_t_inv-status VALUE 'O',
                 paid   TYPE zret_t_inv-status VALUE 'P',
                 voided TYPE zret_t_inv-status VALUE 'V',
               END OF c_status.

    "! Creates an invoice from a delivery.
    "! Loads delivery + SO via their classes, validates SO is Delivered,
    "! snapshots line prices from SO items, persists invoice and transitions
    "! SO to Billed + Delivery to Shipped — all in one transaction.
    CLASS-METHODS create_from_delivery
      IMPORTING iv_deliv_number          TYPE zret_t_deliv-deliv_number
      RETURNING VALUE(rv_invoice_number) TYPE zret_t_inv-invoice_number
      RAISING   zcx_ret_core.

    CLASS-METHODS get_by_id
      IMPORTING iv_invoice_number TYPE zret_t_inv-invoice_number
      RETURNING VALUE(rs_full)    TYPE ty_full
      RAISING   zcx_ret_core.

    CLASS-METHODS select_all
      IMPORTING it_customer_range TYPE ty_customer_range OPTIONAL
                it_status_range   TYPE ty_status_range OPTIONAL
      RETURNING VALUE(rt_inv)     TYPE ty_inv_tab.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-METHODS generate_invoice_number
      RETURNING VALUE(rv_invoice_number) TYPE zret_t_inv-invoice_number.

ENDCLASS.


CLASS zcl_ret_invoice IMPLEMENTATION.

  METHOD create_from_delivery.
    " --- 1. Load delivery (raises if not found) ---
    DATA(ls_deliv_full) = zcl_ret_delivery=>get_by_id( iv_deliv_number ).

    " --- 2. Load SO (raises if not found) ---
    DATA(ls_so_full) = zcl_ret_sales_order=>get_by_id( ls_deliv_full-header-so_number ).

    " --- 3. Validate SO is in Delivered status (not yet billed) ---
    IF ls_so_full-header-status <> zcl_ret_sales_order=>c_status-delivered.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " --- 4. Generate new invoice number ---
    rv_invoice_number = generate_invoice_number( ).

    " --- 5. Build invoice header (snapshots from delivery + SO) ---
    DATA ls_header TYPE zret_t_inv.
    ls_header-mandt          = sy-mandt.
    ls_header-invoice_number = rv_invoice_number.
    ls_header-invoice_date   = sy-datum.
    ls_header-deliv_number   = ls_deliv_full-header-deliv_number.
    ls_header-so_number      = ls_deliv_full-header-so_number.
    ls_header-customer_id    = ls_deliv_full-header-customer_id.
    ls_header-customer_name  = ls_deliv_full-header-customer_name.
    ls_header-currency       = ls_so_full-header-currency.
    ls_header-status         = c_status-open.
    ls_header-created_by     = sy-uname.
    ls_header-created_on     = sy-datum.
    ls_header-changed_by     = sy-uname.
    ls_header-changed_on     = sy-datum.

    " --- 6. Build invoice items: match delivery items with SO items for prices ---
    DATA: lt_inv_items TYPE ty_item_tab,
          ls_inv_item  TYPE zret_t_inv_item,
          lv_total     TYPE p LENGTH 8 DECIMALS 2.

    LOOP AT ls_deliv_full-items INTO DATA(ls_deliv_item).
      " Find matching SO item to retrieve unit_price (delivery doesn't store price)
      READ TABLE ls_so_full-items INTO DATA(ls_so_item)
        WITH KEY item_number = ls_deliv_item-so_item_number.

      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_ret_core.
      ENDIF.

      CLEAR ls_inv_item.
      ls_inv_item-mandt             = sy-mandt.
      ls_inv_item-invoice_number    = rv_invoice_number.
      ls_inv_item-item_number       = ls_deliv_item-item_number.
      ls_inv_item-deliv_number      = ls_deliv_item-deliv_number.
      ls_inv_item-deliv_item_number = ls_deliv_item-item_number.
      ls_inv_item-so_number         = ls_deliv_item-so_number.
      ls_inv_item-so_item_number    = ls_deliv_item-so_item_number.
      ls_inv_item-article_id        = ls_deliv_item-article_id.
      ls_inv_item-article_name      = ls_deliv_item-article_name.
      ls_inv_item-quantity          = ls_deliv_item-quantity.
      ls_inv_item-uom               = ls_deliv_item-uom.
      ls_inv_item-unit_price        = ls_so_item-unit_price.
      ls_inv_item-line_amount       = ls_deliv_item-quantity * ls_so_item-unit_price.
      ls_inv_item-currency          = ls_so_full-header-currency.

      APPEND ls_inv_item TO lt_inv_items.
      lv_total = lv_total + ls_inv_item-line_amount.
    ENDLOOP.

    ls_header-total_amount = lv_total.

    " --- 7. Persist atomically: invoice + status transitions ---
    INSERT zret_t_inv FROM @ls_header.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    INSERT zret_t_inv_item FROM TABLE @lt_inv_items.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " *** LIFECYCLE TRANSITION 1: SO Delivered -> Billed ***
    UPDATE zret_t_so
      SET status     = @zcl_ret_sales_order=>c_status-billed,
          changed_by = @sy-uname,
          changed_on = @sy-datum
      WHERE so_number = @ls_so_full-header-so_number.

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " *** LIFECYCLE TRANSITION 2: Delivery Created -> Shipped ***
    UPDATE zret_t_deliv
      SET status     = @zcl_ret_delivery=>c_status-shipped,
          changed_by = @sy-uname,
          changed_on = @sy-datum
      WHERE deliv_number = @iv_deliv_number.

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.


  METHOD get_by_id.
    SELECT SINGLE *
      FROM zret_t_inv
      WHERE invoice_number = @iv_invoice_number
      INTO @rs_full-header.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    SELECT *
      FROM zret_t_inv_item
      WHERE invoice_number = @iv_invoice_number
      ORDER BY item_number
      INTO TABLE @rs_full-items.
  ENDMETHOD.


  METHOD select_all.
    SELECT *
      FROM zret_t_inv
      WHERE customer_id IN @it_customer_range
        AND status      IN @it_status_range
      ORDER BY invoice_number
      INTO TABLE @rt_inv.
  ENDMETHOD.


  METHOD generate_invoice_number.
    DATA: lv_max     TYPE zret_t_inv-invoice_number,
          lv_new_num TYPE i.

    SELECT MAX( invoice_number )
      FROM zret_t_inv
      INTO @lv_max.

    IF lv_max IS INITIAL.
      lv_new_num = 1.
    ELSE.
      lv_new_num = lv_max + 1.
    ENDIF.

    rv_invoice_number = |{ lv_new_num WIDTH = 10 PAD = '0' ALIGN = RIGHT }|.
  ENDMETHOD.

ENDCLASS.
