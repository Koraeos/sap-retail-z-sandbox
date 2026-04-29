*&---------------------------------------------------------------------*
*& Report ZRET_R_STOCK_DASH
*&---------------------------------------------------------------------*
*& Stock dashboard - all article x site x zone with quantity totals
*&---------------------------------------------------------------------*
report zret_r_stock_dash.

class lcl_app definition.
  public section.
    class-methods: run.
endclass.

class lcl_app implementation.

  method run.
    data lt_stock type table of zret_t_stock.
    data lo_alv   type ref to cl_salv_table.

    select * from zret_t_stock
      into table @lt_stock
      order by article_id, site_id, zone_code.

    if lt_stock is initial.
      message 'No stock records found in ZRET_T_STOCK' type 'I'.
      return.
    endif.

    try.
        cl_salv_table=>factory(
          importing r_salv_table = lo_alv
          changing  t_table      = lt_stock
        ).

        lo_alv->get_columns( )->set_optimize( abap_true ).

        try.
            lo_alv->get_columns( )->get_column( 'CLIENT' )->set_visible( abap_false ).
          catch cx_salv_not_found.
        endtry.

        lo_alv->get_display_settings( )->set_list_header( 'Stock Dashboard - article x site x zone' ).
        lo_alv->get_functions( )->set_all( abap_true ).

        " Aggregation: sum on QUANTITY
        try.
            lo_alv->get_aggregations( )->add_aggregation(
              columnname  = 'QUANTITY'
              aggregation = if_salv_c_aggregation=>total
            ).
          catch cx_salv_not_found cx_salv_data_error cx_salv_existing.
        endtry.

        " Sort with subtotals by article and site
        try.
            lo_alv->get_sorts( )->add_sort(
              columnname = 'ARTICLE_ID'
              subtotal   = abap_true
            ).
            lo_alv->get_sorts( )->add_sort(
              columnname = 'SITE_ID'
              subtotal   = abap_true
            ).
          catch cx_salv_not_found cx_salv_data_error cx_salv_existing.
        endtry.

        lo_alv->display( ).

      catch cx_salv_msg into data(lo_ex).
        message lo_ex->get_text( ) type 'E'.
    endtry.
  endmethod.

endclass.

start-of-selection.
  lcl_app=>run( ).
