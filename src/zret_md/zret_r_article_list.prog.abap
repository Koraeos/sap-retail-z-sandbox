REPORT zret_r_article_list.

*-----------------------------------------------------------------------
* Retail - Active article list (v3: computed TTC price)
*-----------------------------------------------------------------------

TABLES zret_t_article.

*-- Selection screen ----------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS s_type FOR zret_t_article-article_type.
  PARAMETERS     p_active AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b1.

*-- Types & data --------------------------------------------------------
" Local structure: all fields of zret_t_article + one extra computed field
TYPES: BEGIN OF ty_article_line.
         INCLUDE TYPE zret_t_article.
TYPES:   price_ttc TYPE zret_t_article-price,
       END OF ty_article_line.

TYPES ty_article_tab TYPE STANDARD TABLE OF ty_article_line WITH DEFAULT KEY.

DATA: lt_articles TYPE ty_article_tab,
      lo_alv      TYPE REF TO cl_salv_table.

*-- Main ----------------------------------------------------------------
START-OF-SELECTION.

SELECT *
    FROM zret_t_article
    WHERE article_type IN @s_type
      AND ( @p_active = @abap_false OR active_flag = @abap_true )
    ORDER BY article_id
    INTO TABLE @lt_articles.

  IF sy-subrc <> 0 OR lt_articles IS INITIAL.
    MESSAGE 'No articles match the selection.' TYPE 'S'.
    RETURN.
  ENDIF.

LOOP AT lt_articles ASSIGNING FIELD-SYMBOL(<fs_article>).
<fs_article>-price_ttc = <fs_article>-price * '1.20'.
ENDLOOP.

  " Build the ALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = lt_articles
      ).
    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv->get_text( ) TYPE 'E'.
  ENDTRY.

  lo_alv->get_functions( )->set_all( abap_true ).
  lo_alv->get_columns( )->set_optimize( abap_true ).
  lo_alv->display( ).
