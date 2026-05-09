report zret_r_inv_list.

" --- Type for ALV row with color column ---
types:
  begin of ty_inv_row,
    invoice_number type zret_t_inv-invoice_number,
    invoice_date   type zret_t_inv-invoice_date,
    so_number      type zret_t_inv-so_number,
    deliv_number   type zret_t_inv-deliv_number,
    customer_id    type zret_t_inv-customer_id,
    customer_name  type zret_t_inv-customer_name,
    status         type zret_t_inv-status,
    total_amount   type zret_t_inv-total_amount,
    currency       type zret_t_inv-currency,
    created_by     type zret_t_inv-created_by,
    created_on     type zret_t_inv-created_on,
    t_color        type lvc_t_scol,
  end of ty_inv_row,
  tt_inv type standard table of ty_inv_row with default key.

data gt_inv type tt_inv.
data gs_inv type ty_inv_row.

" --- Hotspot click handler ---
class lcl_handler definition.
  public section.
    class-methods on_link_click
      for event link_click of cl_salv_events_table
      importing row column.
endclass.

class lcl_handler implementation.
  method on_link_click.
    read table gt_inv assigning field-symbol(<fs_clicked>) index row.
    if sy-subrc <> 0 or column <> 'INVOICE_NUMBER'.
      return.
    endif.

    select * from zret_t_inv_item
      into table @data(lt_items)
      where invoice_number = @<fs_clicked>-invoice_number
      order by item_number ascending.

    if lt_items is initial.
      message |No items found for invoice { <fs_clicked>-invoice_number }| type 'I'.
      return.
    endif.

    try.
        cl_salv_table=>factory(
          importing
            r_salv_table = data(lo_popup)
          changing
            t_table      = lt_items
        ).

        lo_popup->get_columns( )->set_optimize( abap_true ).
        lo_popup->get_display_settings( )->set_list_header(
          |Invoice items - { <fs_clicked>-invoice_number }| ).

        lo_popup->set_screen_popup(
          start_column = 5
          end_column   = 150
          start_line   = 3
          end_line     = 25 ).

        lo_popup->display( ).
        catch cx_salv_msg.
      catch cx_salv_data_error.
    endtry.
  endmethod.
endclass.

" --- Selection screen ---
selection-screen begin of block b1 with frame title text-001.
  select-options s_invnum for gs_inv-invoice_number.
  select-options s_custid for gs_inv-customer_id.
  select-options s_status for gs_inv-status.
selection-screen end of block b1.

start-of-selection.
  perform load_invoices.
  perform display_invoices.


form load_invoices.

  select invoice_number, invoice_date, so_number, deliv_number,
         customer_id, customer_name, status,
         total_amount, currency, created_by, created_on
    from zret_t_inv
    into corresponding fields of table @gt_inv
    where invoice_number in @s_invnum
      and customer_id    in @s_custid
      and status         in @s_status
    order by invoice_number ascending.

  " Color rows by status
  loop at gt_inv assigning field-symbol(<fs_inv>).
    data ls_color type lvc_s_scol.
    clear ls_color.
    case <fs_inv>-status.
      when 'O'.   " Open
        ls_color-color-col = 5.   " yellow
      when 'P'.   " Paid
        ls_color-color-col = 6.   " green
      when 'V'.   " Void / Cancelled
        ls_color-color-col = 7.   " red
      when others.
        ls_color-color-col = 0.
    endcase.
    ls_color-fname = '*'.
    append ls_color to <fs_inv>-t_color.
  endloop.

endform.


form display_invoices.

  data lo_alv type ref to cl_salv_table.

  try.
      cl_salv_table=>factory(
        importing
          r_salv_table = lo_alv
        changing
          t_table      = gt_inv
      ).

      data(lo_columns) = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).
      lo_columns->set_color_column( 't_color' ).

      try.
          data(lo_col_color) = lo_columns->get_column( 'T_COLOR' ).
          lo_col_color->set_technical( abap_true ).
        catch cx_salv_not_found.
      endtry.

      try.
          data(lo_col_inv) = lo_columns->get_column( 'INVOICE_NUMBER' ).
          data(lo_col_table) = cast cl_salv_column_table( lo_col_inv ).
          lo_col_table->set_cell_type( if_salv_c_cell_type=>hotspot ).
        catch cx_salv_not_found.
      endtry.

      lo_alv->get_display_settings( )->set_list_header( 'Invoice List' ).

      lo_alv->get_functions( )->set_all( ).

      data(lo_events) = lo_alv->get_event( ).
      set handler lcl_handler=>on_link_click for lo_events.

      lo_alv->display( ).

    catch cx_salv_msg into data(lx_msg).
      message lx_msg type 'E'.
  endtry.

endform.
