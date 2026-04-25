CLASS zcl_ret_sales_order DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Input type: what the caller fills in to declare an item
    TYPES: BEGIN OF ty_item_input,
             article_id TYPE zde_ret_article_id,
             quantity   TYPE p LENGTH 7 DECIMALS 3,
             unit_price TYPE p LENGTH 7 DECIMALS 2,
           END OF ty_item_input.

    TYPES: ty_item_input_tab TYPE STANDARD TABLE OF ty_item_input WITH DEFAULT KEY.

    " Output type: full sales order (header + persisted items)
    TYPES: ty_item_tab TYPE STANDARD TABLE OF zret_t_so_item WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_full,
             header TYPE zret_t_so,
             items  TYPE ty_item_tab,
           END OF ty_full.

    " Status constants: avoids magic strings 'O'/'D'/'B'/'C' scattered everywhere
    CONSTANTS: BEGIN OF c_status,
                 open      TYPE zret_t_so-status VALUE 'O',
                 delivered TYPE zret_t_so-status VALUE 'D',
                 billed    TYPE zret_t_so-status VALUE 'B',
                 cancelled TYPE zret_t_so-status VALUE 'C',
               END OF c_status.

    CLASS-METHODS create
      IMPORTING is_header           TYPE zret_t_so
                it_items            TYPE ty_item_input_tab
      RETURNING VALUE(rv_so_number) TYPE zret_t_so-so_number
      RAISING   zcx_ret_core.

    CLASS-METHODS get_by_id
      IMPORTING iv_so_number   TYPE zret_t_so-so_number
      RETURNING VALUE(rs_full) TYPE ty_full
      RAISING   zcx_ret_core.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-METHODS generate_so_number
      RETURNING VALUE(rv_so_number) TYPE zret_t_so-so_number.

ENDCLASS.


CLASS zcl_ret_sales_order IMPLEMENTATION.

  METHOD create.
    " --- 1. Header validation (fail fast) ---
    IF is_header-customer_id IS INITIAL
    OR is_header-currency    IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    IF lines( it_items ) = 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " --- 2. Generate new SO number ---
    rv_so_number = generate_so_number( ).

    " --- 3. Build header with audit + status defaults ---
    DATA ls_header TYPE zret_t_so.
    ls_header            = is_header.
    ls_header-mandt      = sy-mandt.
    ls_header-so_number  = rv_so_number.
    ls_header-so_date    = sy-datum.
    ls_header-status     = c_status-open.
    ls_header-created_by = sy-uname.
    ls_header-created_on = sy-datum.
    ls_header-changed_by = sy-uname.
    ls_header-changed_on = sy-datum.

    " --- 4. Process each item: validate via Article class + snapshot + accumulate ---
    DATA: lt_items_db TYPE ty_item_tab,
          ls_item_db  TYPE zret_t_so_item,
          lv_total    TYPE p LENGTH 8 DECIMALS 2,
          lv_item_no  TYPE n LENGTH 6 VALUE '000010'.

    LOOP AT it_items INTO DATA(ls_input).
      " *** THIS IS THE "CLICK MENTAL" LINE ***
      " Delegate article validation to the Article class.
      " If article doesn't exist, get_by_id raises zcx_ret_core which bubbles up.
      DATA(ls_article) = zcl_ret_article=>get_by_id( ls_input-article_id ).

      " Build the persisted item (snapshot of master data at order time)
      CLEAR ls_item_db.
      ls_item_db-mandt        = sy-mandt.
      ls_item_db-so_number    = rv_so_number.
      ls_item_db-item_number  = lv_item_no.
      ls_item_db-article_id   = ls_input-article_id.
      ls_item_db-article_name = ls_article-article_name.
      ls_item_db-quantity     = ls_input-quantity.
      ls_item_db-uom          = ls_article-base_uom.

      IF ls_input-unit_price IS NOT INITIAL.
        ls_item_db-unit_price = ls_input-unit_price.
      ELSE.
        ls_item_db-unit_price = ls_article-price.
      ENDIF.

      ls_item_db-line_amount = ls_input-quantity * ls_item_db-unit_price.
      ls_item_db-currency    = is_header-currency.

      APPEND ls_item_db TO lt_items_db.
      lv_total = lv_total + ls_item_db-line_amount.

      lv_item_no = lv_item_no + 10.
    ENDLOOP.

    ls_header-total_amount = lv_total.

    " --- 5. Persist header + items in one atomic transaction ---
    INSERT zret_t_so FROM @ls_header.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    INSERT zret_t_so_item FROM TABLE @lt_items_db.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.


  METHOD get_by_id.
    SELECT SINGLE *
      FROM zret_t_so
      WHERE so_number = @iv_so_number
      INTO @rs_full-header.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    SELECT *
      FROM zret_t_so_item
      WHERE so_number = @iv_so_number
      ORDER BY item_number
      INTO TABLE @rs_full-items.
  ENDMETHOD.


  METHOD generate_so_number.
    DATA: lv_max_so  TYPE zret_t_so-so_number,
          lv_new_num TYPE i.

    SELECT MAX( so_number )
      FROM zret_t_so
      INTO @lv_max_so.

    IF lv_max_so IS INITIAL.
      lv_new_num = 1.
    ELSE.
      lv_new_num = lv_max_so + 1.
    ENDIF.

    rv_so_number = |{ lv_new_num WIDTH = 10 PAD = '0' ALIGN = RIGHT }|.
  ENDMETHOD.

ENDCLASS.
