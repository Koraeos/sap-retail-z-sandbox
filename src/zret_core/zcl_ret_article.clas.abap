CLASS zcl_ret_article DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_article.
             INCLUDE TYPE zret_t_article.
    TYPES:   price_ttc TYPE zret_t_article-price,
             t_color   TYPE lvc_t_scol,
           END OF ty_article.

    TYPES: ty_article_tab TYPE STANDARD TABLE OF ty_article WITH DEFAULT KEY.

    TYPES: tty_type_range TYPE RANGE OF zret_t_article-article_type.

    CONSTANTS: c_vat_rate TYPE p LENGTH 4 DECIMALS 2 VALUE '1.20'.

    CLASS-METHODS select_all
      IMPORTING it_type_range      TYPE tty_type_range OPTIONAL
                iv_only_active     TYPE abap_bool      DEFAULT abap_true
      RETURNING VALUE(rt_articles) TYPE ty_article_tab
      RAISING   zcx_ret_core.

    CLASS-METHODS get_by_id
      IMPORTING iv_article_id     TYPE zret_t_article-article_id
      RETURNING VALUE(rs_article) TYPE ty_article
      RAISING   zcx_ret_core.

    CLASS-METHODS create
      IMPORTING is_article TYPE zret_t_article
      RAISING   zcx_ret_core.

    CLASS-METHODS update
      IMPORTING is_article TYPE zret_t_article
      RAISING   zcx_ret_core.

    CLASS-METHODS delete
      IMPORTING iv_article_id TYPE zret_t_article-article_id
      RAISING   zcx_ret_core.

  PROTECTED SECTION.

  PRIVATE SECTION.

    CLASS-METHODS enrich_article
      CHANGING cs_article TYPE ty_article.

ENDCLASS.


CLASS zcl_ret_article IMPLEMENTATION.

  METHOD select_all.
    DATA: lt_db TYPE STANDARD TABLE OF zret_t_article.

    SELECT *
      FROM zret_t_article
      WHERE article_type IN @it_type_range
        AND ( @iv_only_active = @abap_true  AND active_flag = @abap_true
           OR @iv_only_active = @abap_false )
      ORDER BY article_id
      INTO TABLE @lt_db.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    rt_articles = CORRESPONDING #( lt_db ).

    LOOP AT rt_articles ASSIGNING FIELD-SYMBOL(<fs_article>).
      enrich_article( CHANGING cs_article = <fs_article> ).
    ENDLOOP.
  ENDMETHOD.


  METHOD get_by_id.
    DATA ls_db TYPE zret_t_article.

    SELECT SINGLE *
      FROM zret_t_article
      WHERE article_id = @iv_article_id
      INTO @ls_db.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core
        EXPORTING
          article_id = iv_article_id.
    ENDIF.

    rs_article = CORRESPONDING #( ls_db ).
    enrich_article( CHANGING cs_article = rs_article ).
  ENDMETHOD.


  METHOD create.
    " --- Input validation (fail fast) ---
    IF is_article-article_id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    IF is_article-article_name IS INITIAL
    OR is_article-price        <= 0.
      RAISE EXCEPTION TYPE zcx_ret_core
        EXPORTING
          article_id = is_article-article_id.
    ENDIF.

    " --- Unicity check ---
    SELECT SINGLE article_id
      FROM zret_t_article
      WHERE article_id = @is_article-article_id
      INTO @DATA(lv_found).

    IF sy-subrc = 0.
      RAISE EXCEPTION TYPE zcx_ret_core
        EXPORTING
          article_id = is_article-article_id.
    ENDIF.

    " --- Prepare record with audit defaults ---
    DATA ls_db TYPE zret_t_article.
    ls_db             = is_article.
    ls_db-mandt       = sy-mandt.
    ls_db-created_by  = sy-uname.
    ls_db-created_on  = sy-datum.
    ls_db-changed_by  = sy-uname.
    ls_db-changed_on  = sy-datum.
    IF ls_db-active_flag IS INITIAL.
      ls_db-active_flag = abap_true.
    ENDIF.

    " --- Persist ---
    INSERT zret_t_article FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core
        EXPORTING
          article_id = is_article-article_id.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.


  METHOD update.
    " --- Input validation ---
    IF is_article-article_id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    IF is_article-article_name IS INITIAL
    OR is_article-price        <= 0.
      RAISE EXCEPTION TYPE zcx_ret_core
        EXPORTING
          article_id = is_article-article_id.
    ENDIF.

    " --- Existence check + load current audit fields ---
    DATA ls_existing TYPE zret_t_article.
    SELECT SINGLE *
      FROM zret_t_article
      WHERE article_id = @is_article-article_id
      INTO @ls_existing.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core
        EXPORTING
          article_id = is_article-article_id.
    ENDIF.

    " --- Prepare record preserving created_* + refreshing changed_* ---
    DATA ls_db TYPE zret_t_article.
    ls_db            = is_article.
    ls_db-mandt      = sy-mandt.
    ls_db-created_by = ls_existing-created_by.
    ls_db-created_on = ls_existing-created_on.
    ls_db-changed_by = sy-uname.
    ls_db-changed_on = sy-datum.

    " --- Persist ---
    UPDATE zret_t_article FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core
        EXPORTING
          article_id = is_article-article_id.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.


  METHOD delete.
    " --- Input validation ---
    IF iv_article_id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    " --- Existence check ---
    SELECT SINGLE article_id
      FROM zret_t_article
      WHERE article_id = @iv_article_id
      INTO @DATA(lv_found).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core
        EXPORTING
          article_id = iv_article_id.
    ENDIF.

    " --- Soft delete: flip active_flag to false ---
    UPDATE zret_t_article
      SET active_flag = @abap_false,
          changed_by  = @sy-uname,
          changed_on  = @sy-datum
      WHERE article_id = @iv_article_id.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ret_core
        EXPORTING
          article_id = iv_article_id.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.


  METHOD enrich_article.
    DATA ls_color TYPE lvc_s_scol.

    cs_article-price_ttc = cs_article-price * c_vat_rate.

    CASE cs_article-article_type.
      WHEN 'HARD'. ls_color-color-col = 5.
      WHEN 'SOFT'. ls_color-color-col = 1.
      WHEN 'ACCE'. ls_color-color-col = 3.
      WHEN 'CONS'. ls_color-color-col = 7.
    ENDCASE.
    ls_color-color-int = 1.
    APPEND ls_color TO cs_article-t_color.
  ENDMETHOD.

ENDCLASS.
