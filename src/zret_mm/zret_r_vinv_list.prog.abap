report zret_r_vinv_list.

types:
  begin of ty_vinv_row,
    vinv_number   type zret_t_vinv-vinv_number,
    vinv_date     type zret_t_vinv-vinv_date,
    po_number     type zret_t_vinv-po_number,
    supplier_id   type zret_t_vinv-supplier_id,
    supplier_name type zret_t_vinv-supplier_name,
    status        type zret_t_vinv-status,
    block_reason  type zret_t_vinv-block_reason,
    total_amount  type zret_t_vinv-total_amount,
    currency      type zret_t_vinv-currency,
    created_by    type zret_t_vinv-created_by,
    created_on    type zret_t_vinv-created_on,
    t_color       type lvc_t_scol,
  end of ty_vinv_row,
  tt_vinv type standard table of ty_vinv_row with default key.

data gt_vinv type tt_vinv.
data gs_vinv type ty_vinv_row.

" --- Hotspot click handler ---
class lcl_handler definition.
  public section.
    class-methods on_link_click
      for event link_click of cl_salv_events_table
      importing row column.
endclass.

class lcl_handler implementation.
  method on_link_click.
    read table gt_vinv assigning field-symbol(<fs_clicked>) index row.
    if sy-subrc <> 0 or column <> 'VINV_NUMBER'.
      return.
    endif.

    select * from zret_t_vinv_item
      into table @data(lt_items)
      where vinv_number = @<fs_clicked>-vinv_number
      order by item_num ascending.

    if lt_items is initial.
      message |No items found for vendor invoice { <fs_clicked>-vinv_number }| type 'I'.
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
          |Vendor invoice items - { <fs_clicked>-vinv_number }| ).

        lo_popup->set_screen_popup(
          start_column = 5
          end_column   = 180
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
  select-options s_vinv   for gs_vinv-vinv_number.
  select-options s_status for gs_vinv-status.
  select-options s_supp   for gs_vinv-supplier_id.
selection-screen end of block b1.


start-of-selection.
  perform load_invoices.
  perform display_invoices.


form load_invoices.

  select vinv_number, vinv_date, po_number,
         supplier_id, supplier_name, status, block_reason,
         total_amount, currency, created_by, created_on
    from zret_t_vinv
    into corresponding fields of table @gt_vinv
    where vinv_number in @s_vinv
      and status      in @s_status
      and supplier_id in @s_supp
    order by vinv_number ascending.

  " Color rows by status
  loop at gt_vinv assigning field-symbol(<fs_vinv>).
    data ls_color type lvc_s_scol.
    clear ls_color.
    case <fs_vinv>-status.
      when 'O'.   " Open (unblocked, awaiting payment)
        ls_color-color-col = 5.   " yellow
      when 'M'.   " Matched
        ls_color-color-col = 6.   " green
      when 'B'.   " Blocked
        ls_color-color-col = 7.   " red
      when 'P'.   " Paid
        ls_color-color-col = 6.   " green
        ls_color-color-int = 1.   " intensified
      when 'V'.   " Voided
        ls_color-color-col = 0.   " grey
      when others.
        ls_color-color-col = 0.
    endcase.
    ls_color-fname = '*'.
    append ls_color to <fs_vinv>-t_color.
  endloop.

endform.


form display_invoices.

  data lo_alv type ref to cl_salv_table.

  try.
      cl_salv_table=>factory(
        importing
          r_salv_table = lo_alv
        changing
          t_table      = gt_vinv
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
          data(lo_col_vinv) = lo_columns->get_column( 'VINV_NUMBER' ).
          data(lo_col_table) = cast cl_salv_column_table( lo_col_vinv ).
          lo_col_table->set_cell_type( if_salv_c_cell_type=>hotspot ).
        catch cx_salv_not_found.
      endtry.

      lo_alv->get_display_settings( )->set_list_header( 'Vendor Invoice List (3-way match)' ).

      lo_alv->get_functions( )->set_all( ).

      data(lo_events) = lo_alv->get_event( ).
      set handler lcl_handler=>on_link_click for lo_events.

      lo_alv->display( ).

    catch cx_salv_msg into data(lx_msg).
      message lx_msg type 'E'.
  endtry.

endform.
