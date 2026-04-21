REPORT zret_r_article_list.

*-----------------------------------------------------------------------
* Retail - Active article list
*
* Displays all active articles from ZRET_T_ARTICLE in a standard ALV grid
* using modern OO approach (CL_SALV_TABLE factory pattern).
*-----------------------------------------------------------------------

DATA: lt_articles TYPE TABLE OF zret_t_article,
      lo_alv      TYPE REF TO cl_salv_table.

" 1) Fetch all active articles
SELECT *
  FROM zret_t_article
  INTO TABLE @lt_articles
  WHERE active_flag = @abap_true
  ORDER BY article_id.

IF sy-subrc <> 0 OR lt_articles IS INITIAL.
  WRITE: / 'No active articles found.'.
  RETURN.
ENDIF.

" 2) Build the ALV via factory
TRY.
    cl_salv_table=>factory(
      IMPORTING r_salv_table = lo_alv
      CHANGING  t_table      = lt_articles
    ).
  CATCH cx_salv_msg INTO DATA(lx_salv).
    WRITE: / 'ALV creation failed:', lx_salv->get_text( ).
    RETURN.
ENDTRY.

" 3) Enable all standard ALV functions + auto column width
lo_alv->get_functions( )->set_all( abap_true ).
lo_alv->get_columns( )->set_optimize( abap_true ).

" 4) Display
lo_alv->display( ).
