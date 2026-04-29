*&---------------------------------------------------------------------*
*& Report ZRET_R_PO_LIST
*&---------------------------------------------------------------------*
*& ALV display of Purchase Orders.
*&  - empty PO number  -> shows all PO headers
*&  - given PO number  -> shows items of that PO
*&---------------------------------------------------------------------*
report zret_r_po_list.

parameters p_pon type zret_t_po-po_number default ''.

class lcl_app definition.
  public section.
    class-methods:
      show_headers,
      show_items
        importing iv_po_number type zret_t_po-po_number.
endclass.

class lcl_app implementation.

  method show_headers.
    data lt_pos type table of zret_t_po.
    data lo_alv type ref to cl_salv_table.

    select * from zret_t_po
      into table @lt_pos
      order by po_number descending.

    if lt_pos is initial.
      message 'No purchase orders found in ZRET_T_PO' type 'I'.
      return.
    endif.

    try.
        cl_salv_table=>factory(
          importing r_salv_table = lo_alv
          changing  t_table      = lt_pos
        ).

        lo_alv->get_columns( )->set_optimize( abap_true ).

        try.
            lo_alv->get_columns( )->get_column( 'CLIENT' )->set_visible( abap_false ).
          catch cx_salv_not_found.
        endtry.

        lo_alv->get_display_settings( )->set_list_header( 'Purchase Orders Overview' ).
        lo_alv->get_functions( )->set_all( abap_true ).

        lo_alv->display( ).

      catch cx_salv_msg into data(lo_ex).
        message lo_ex->get_text( ) type 'E'.
    endtry.
  endmethod.

  method show_items.
    data lt_items type zcl_ret_purch_order=>tt_po_items.
    data lo_alv   type ref to cl_salv_table.

    lt_items = zcl_ret_purch_order=>get_items( iv_po_number ).

    if lt_items is initial.
      message |No items found for PO { iv_po_number }| type 'I'.
      return.
    endif.

    try.
        cl_salv_table=>factory(
          importing r_salv_table = lo_alv
          changing  t_table      = lt_items
        ).

        lo_alv->get_columns( )->set_optimize( abap_true ).

        try.
            lo_alv->get_columns( )->get_column( 'CLIENT' )->set_visible( abap_false ).
          catch cx_salv_not_found.
        endtry.

        lo_alv->get_display_settings( )->set_list_header( |Items of PO { iv_po_number }| ).
        lo_alv->get_functions( )->set_all( abap_true ).

        lo_alv->display( ).

      catch cx_salv_msg into data(lo_ex).
        message lo_ex->get_text( ) type 'E'.
    endtry.
  endmethod.

endclass.

start-of-selection.
  if p_pon is initial.
    lcl_app=>show_headers( ).
  else.
    lcl_app=>show_items( p_pon ).
  endif.
