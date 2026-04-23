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

  PROTECTED SECTION.

  PRIVATE SECTION.

    "! Enriches an article with computed TTC price and row color (by type).
    CLASS-METHODS enrich_article
      CHANGING cs_article TYPE ty_article.

ENDCLASS.



CLASS ZCL_RET_ARTICLE IMPLEMENTATION.


  METHOD enrich_article.
    DATA ls_color TYPE lvc_s_scol.

    " Compute TTC price
    cs_article-price_ttc = cs_article-price * c_vat_rate.

    " Assign row color by article type
    CASE cs_article-article_type.
      WHEN 'HARD'. ls_color-color-col = 5.  " green
      WHEN 'SOFT'. ls_color-color-col = 1.  " blue
      WHEN 'ACCE'. ls_color-color-col = 3.  " yellow
      WHEN 'CONS'. ls_color-color-col = 7.  " orange
    ENDCASE.
    ls_color-color-int = 1.
    APPEND ls_color TO cs_article-t_color.
  ENDMETHOD.


  METHOD get_by_id.
    DATA ls_db TYPE zret_t_article.

    SELECT SINGLE *
      FROM zret_t_article
      WHERE article_id = @iv_article_id
      INTO @ls_db.

    IF sy-subrc <> 0.
RAISE EXCEPTION TYPE zcx_ret_core.
    ENDIF.

    rs_article = CORRESPONDING #( ls_db ).
    enrich_article( CHANGING cs_article = rs_article ).
  ENDMETHOD.


  METHOD select_all.
    DATA lt_db TYPE STANDARD TABLE OF zret_t_article.

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
ENDCLASS.
