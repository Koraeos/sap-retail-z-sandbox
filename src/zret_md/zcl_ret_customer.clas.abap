CLASS zcl_ret_customer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: ty_customer_tab TYPE STANDARD TABLE OF zret_t_customer WITH DEFAULT KEY.
    TYPES: tty_type_range  TYPE RANGE OF zret_t_customer-customer_type.

    " Customer type constants — avoid magic strings
    CONSTANTS: BEGIN OF c_type,
                 magasin TYPE zret_t_customer-customer_type VALUE 'M',
                 web     TYPE zret_t_customer-customer_type VALUE 'W',
                 b2b     TYPE zret_t_customer-customer_type VALUE 'B',
                 export  TYPE zret_t_customer-customer_type VALUE 'E',
               END OF c_type.

    CLASS-METHODS select_all
      IMPORTING it_type_range       TYPE tty_type_range OPTIONAL
                iv_only_active      TYPE abap_bool      DEFAULT abap_true
      RETURNING VALUE(rt_customers) TYPE ty_customer_tab.

    CLASS-METHODS get_by_id
      IMPORTING iv_customer_id     TYPE zret_t_customer-customer_id
      RETURNING VALUE(rs_customer) TYPE zret_t_customer
      RAISING   zcx_ret_core.

    CLASS-METHODS create
      IMPORTING is_customer TYPE zret_t_customer
      RAISING   zcx_ret_core.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.


CLASS zcl_ret_customer IMPLEMENTATION.

  METHOD select_all.
    SELECT *
      FROM zret_t_customer
      WHERE customer_type IN @it_type_range
        AND ( @iv_only_active = @abap_true  AND active_flag = @abap_true
           OR @iv_only_active = @abap_false )
      ORDER BY customer_id
      INTO TABLE @rt_customers.
  ENDMETHOD.


  METHOD get_by_id.
    SELECT SINGLE *
      FROM zret_t_customer
      WHERE customer_id = @iv_customer_id
      INTO @rs_customer.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.
  ENDMETHOD.


  METHOD create.
    " --- Validation ---
    IF is_customer-customer_id IS INITIAL
    OR is_customer-customer_name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " Customer type must be one of M/W/B/E
    IF is_customer-customer_type NA 'MWBE'.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " --- Unicity check ---
    SELECT SINGLE customer_id
      FROM zret_t_customer
      WHERE customer_id = @is_customer-customer_id
      INTO @DATA(lv_found).

    IF sy-subrc = 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " --- Prepare record with defaults ---
    DATA ls_db TYPE zret_t_customer.
    ls_db             = is_customer.
    ls_db-mandt       = sy-mandt.
    ls_db-created_by  = sy-uname.
    ls_db-created_on  = sy-datum.
    ls_db-changed_by  = sy-uname.
    ls_db-changed_on  = sy-datum.

    IF ls_db-active_flag IS INITIAL.
      ls_db-active_flag = abap_true.
    ENDIF.

    " Sensible defaults if not provided
    IF ls_db-default_currency IS INITIAL.
      ls_db-default_currency = 'EUR'.
    ENDIF.

    IF ls_db-country IS INITIAL.
      ls_db-country = 'FR'.
    ENDIF.

    " --- Persist ---
    INSERT zret_t_customer FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
