CLASS zcl_ret_site DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: ty_site_tab    TYPE STANDARD TABLE OF zret_t_site WITH DEFAULT KEY.
    TYPES: tty_type_range TYPE RANGE OF zret_t_site-site_type.

    " Site type constants
    CONSTANTS: BEGIN OF c_type,
                 store     TYPE zret_t_site-site_type VALUE 'S',
                 warehouse TYPE zret_t_site-site_type VALUE 'W',
               END OF c_type.

    CLASS-METHODS select_all
      IMPORTING it_type_range  TYPE tty_type_range OPTIONAL
                iv_only_active TYPE abap_bool      DEFAULT abap_true
      RETURNING VALUE(rt_sites) TYPE ty_site_tab.

    CLASS-METHODS get_by_id
      IMPORTING iv_site_id     TYPE zret_t_site-site_id
      RETURNING VALUE(rs_site) TYPE zret_t_site
      RAISING   zcx_ret_core.

    CLASS-METHODS create
      IMPORTING is_site TYPE zret_t_site
      RAISING   zcx_ret_core.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.


CLASS zcl_ret_site IMPLEMENTATION.

  METHOD select_all.
    SELECT *
      FROM zret_t_site
      WHERE site_type IN @it_type_range
        AND ( @iv_only_active = @abap_true  AND active_flag = @abap_true
           OR @iv_only_active = @abap_false )
      ORDER BY site_id
      INTO TABLE @rt_sites.
  ENDMETHOD.


  METHOD get_by_id.
    SELECT SINGLE *
      FROM zret_t_site
      WHERE site_id = @iv_site_id
      INTO @rs_site.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.
  ENDMETHOD.


  METHOD create.
    " Validation
    IF is_site-site_id IS INITIAL
    OR is_site-site_name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    IF is_site-site_type NA 'SW'.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " Unicity
    SELECT SINGLE site_id FROM zret_t_site
      WHERE site_id = @is_site-site_id
      INTO @DATA(lv_found).

    IF sy-subrc = 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " Build with defaults
    DATA ls_db TYPE zret_t_site.
    ls_db             = is_site.
    ls_db-mandt       = sy-mandt.
    ls_db-created_by  = sy-uname.
    ls_db-created_on  = sy-datum.
    ls_db-changed_by  = sy-uname.
    ls_db-changed_on  = sy-datum.

    IF ls_db-active_flag IS INITIAL.
      ls_db-active_flag = abap_true.
    ENDIF.

    IF ls_db-country IS INITIAL.
      ls_db-country = 'FR'.
    ENDIF.

    " Persist
    INSERT zret_t_site FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
