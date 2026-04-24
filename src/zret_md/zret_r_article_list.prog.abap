REPORT zret_r_article_list.

TABLES zret_t_article.

" Selection screen
SELECT-OPTIONS so_type FOR zret_t_article-article_type.
PARAMETERS p_actv AS CHECKBOX DEFAULT 'X'.

" Local event handler class
CLASS lcl_handler DEFINITION.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING it_articles TYPE zcl_ret_article=>ty_article_tab.
    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
  PRIVATE SECTION.
    DATA mt_articles TYPE zcl_ret_article=>ty_article_tab.
ENDCLASS.

CLASS lcl_handler IMPLEMENTATION.
  METHOD constructor.
    mt_articles = it_articles.
  ENDMETHOD.

  METHOD on_double_click.
    DATA(ls_article) = mt_articles[ row ].

    CALL FUNCTION 'POPUP_TO_INFORM'
      EXPORTING
        titel = 'Article details'
        txt1  = |Article: { ls_article-article_id } - { ls_article-article_name }|
        txt2  = |Type: { ls_article-article_type }  -  EAN: { ls_article-ean }|
        txt3  = |Price HT:  { ls_article-price } { ls_article-currency }|
        txt4  = |Price TTC: { ls_article-price_ttc } { ls_article-currency }|.
  ENDMETHOD.
ENDCLASS.

" Data
DATA: lt_articles TYPE zcl_ret_article=>ty_article_tab,
      lo_alv      TYPE REF TO cl_salv_table,
      lo_handler  TYPE REF TO lcl_handler.

" Main
START-OF-SELECTION.

  " Delegate data retrieval + enrichment to the domain class
  TRY.
      lt_articles = zcl_ret_article=>select_all(
        it_type_range  = so_type[]
        iv_only_active = p_actv ).
    CATCH zcx_ret_core.
      MESSAGE 'Aucun article trouvé' TYPE 'I'.
      RETURN.
  ENDTRY.

  " Compute stats for header
  DATA: lv_total     TYPE i,
        lv_hard      TYPE i,
        lv_soft      TYPE i,
        lv_acce      TYPE i,
        lv_cons      TYPE i,
        lv_sum_price TYPE zret_t_article-price.

  lv_total = lines( lt_articles ).

  LOOP AT lt_articles ASSIGNING FIELD-SYMBOL(<fs_stat>).
    lv_sum_price = lv_sum_price + <fs_stat>-price.
    CASE <fs_stat>-article_type.
      WHEN 'HARD'. lv_hard = lv_hard + 1.
      WHEN 'SOFT'. lv_soft = lv_soft + 1.
      WHEN 'ACCE'. lv_acce = lv_acce + 1.
      WHEN 'CONS'. lv_cons = lv_cons + 1.
    ENDCASE.
  ENDLOOP.

  " Build ALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = lt_articles ).

      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_columns( )->set_optimize( abap_true ).
      lo_alv->get_columns( )->set_color_column( 'T_COLOR' ).

      DATA(lo_header) = NEW cl_salv_form_layout_grid( ).

      lo_header->create_label(
        row    = 1
        column = 1
        text   = 'Article List - ZRET_R_ARTICLE_LIST'
      ).

      lo_header->create_label(
        row    = 2
        column = 1
        text   = |Date: { sy-datum DATE = USER }  -  User: { sy-uname }|
      ).

      lo_header->create_label(
        row    = 3
        column = 1
        text   = |Total: { lv_total } articles  -  HARD: { lv_hard }  SOFT: { lv_soft }  ACCE: { lv_acce }  CONS: { lv_cons }|
      ).

      lo_header->create_label(
        row    = 4
        column = 1
        text   = |Total value (HT): { lv_sum_price } EUR|
      ).

      lo_alv->set_top_of_list( lo_header ).

      lo_handler = NEW lcl_handler( lt_articles ).
      SET HANDLER lo_handler->on_double_click FOR lo_alv->get_event( ).

      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv TYPE 'E'.
  ENDTRY.
