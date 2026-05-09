report zret_r_launchpad.

types:
  begin of ty_action,
    step        type n length 3,
    category    type c length 20,
    code        type c length 30,
    code_type   type c length 1,    " 'P' = program, 'T' = transaction
    description type c length 60,
    t_color     type lvc_t_scol,
  end of ty_action,
  tt_actions type standard table of ty_action with default key.

data gt_actions type tt_actions.

" --- Hotspot click handler ---
class lcl_handler definition.
  public section.
    class-methods on_link_click
      for event link_click of cl_salv_events_table
      importing row column.
endclass.

class lcl_handler implementation.
  method on_link_click.
    read table gt_actions assigning field-symbol(<fs_action>) index row.
    if sy-subrc <> 0 or column <> 'CODE'.
      return.
    endif.

    case <fs_action>-code_type.
      when 'P'.   " Program -> SUBMIT and return
        submit (<fs_action>-code) and return.
      when 'T'.   " Transaction -> CALL TRANSACTION
        call transaction <fs_action>-code.
      when others.
        message |Unknown code type: { <fs_action>-code_type }| type 'I'.
    endcase.
  endmethod.
endclass.


start-of-selection.
  perform build_actions.
  perform display_launchpad.


form build_actions.

  " === MASTER DATA SETUP ===
  append value #( step = '010' category = '01-Master Setup'  code = 'ZRET_R_ARTICLE_CREATE'   code_type = 'P' description = 'Create article master records' ) to gt_actions.
  append value #( step = '011' category = '01-Master Setup'  code = 'ZRET_R_CUSTOMER_CREATE'  code_type = 'P' description = 'Create customer master records' ) to gt_actions.
  append value #( step = '012' category = '01-Master Setup'  code = 'ZRET_R_SITE_CREATE'      code_type = 'P' description = 'Create site master records' ) to gt_actions.
  append value #( step = '013' category = '01-Master Setup'  code = 'ZRET_R_SEED_SUPPLIERS'   code_type = 'P' description = 'Seed 3 sample suppliers' ) to gt_actions.
  append value #( step = '014' category = '01-Master Setup'  code = 'ZRET_R_SEED_WHSE'        code_type = 'P' description = 'Seed warehouse zones + initial stock' ) to gt_actions.
  append value #( step = '015' category = '01-Master Setup'  code = 'ZRET_R_SEED_GENERIC'     code_type = 'P' description = 'Seed Generic Articles + link variants' ) to gt_actions.
  append value #( step = '016' category = '01-Master Setup'  code = 'ZRET_R_SEED_PARTNERS'    code_type = 'P' description = 'Seed Partner Roles B2B + B2C scenarios' ) to gt_actions.

  " === MASTER DATA - LISTS / TRANSACTIONS ===
  append value #( step = '020' category = '02-Master Lists'  code = 'ZRET_R_ARTICLE_LIST'     code_type = 'P' description = 'Article master list (ALV with row colors)' ) to gt_actions.
  append value #( step = '021' category = '02-Master Lists'  code = 'ZRET_R_GEN_ART_LIST'     code_type = 'P' description = 'Generic Articles + variant count + drill-down' ) to gt_actions.
  append value #( step = '022' category = '02-Master Lists'  code = 'ZRET_R_CUST_PART_LIST'   code_type = 'P' description = 'Customer x Partner Functions matrix' ) to gt_actions.
  append value #( step = '023' category = '02-Master Lists'  code = 'ZGENART'                 code_type = 'T' description = 'Z transaction (dynpro) Create Generic Article' ) to gt_actions.

  " === PROCUREMENT (Inbound side) ===
  append value #( step = '030' category = '03-Procurement'   code = 'ZRET_R_PO_DEMO'          code_type = 'P' description = 'Create PO + post Goods Receipt (auto-Putaway)' ) to gt_actions.
  append value #( step = '031' category = '03-Procurement'   code = 'ZRET_R_PO_LIST'          code_type = 'P' description = 'PO list (ALV with item drill-down)' ) to gt_actions.
  append value #( step = '032' category = '03-Procurement'   code = 'ZRET_R_VINV_DEMO'        code_type = 'P' description = 'Vendor Invoice 3-way match demo' ) to gt_actions.
  append value #( step = '033' category = '03-Procurement'   code = 'ZRET_R_VINV_LIST'        code_type = 'P' description = 'Vendor Invoice list (status colors)' ) to gt_actions.

  " === WAREHOUSE ===
  append value #( step = '040' category = '04-Warehouse'     code = 'ZRET_R_WH_TASK_LIST'     code_type = 'P' description = 'Warehouse tasks list (Putaway / Pick / Load)' ) to gt_actions.
  append value #( step = '041' category = '04-Warehouse'     code = 'ZRET_R_WH_TASK_CONFIRM'  code_type = 'P' description = 'Confirm a warehouse task' ) to gt_actions.
  append value #( step = '042' category = '04-Warehouse'     code = 'ZRET_R_OUTBOUND_DEMO'    code_type = 'P' description = 'Full Pick -> Load -> Goods Issue chain' ) to gt_actions.
  append value #( step = '043' category = '04-Warehouse'     code = 'ZRET_R_STOCK_DASH'       code_type = 'P' description = 'Stock by article x site x zone (subtotals)' ) to gt_actions.

  " === SALES (Outbound side) ===
  append value #( step = '050' category = '05-Sales'         code = 'ZRET_R_SO_CREATE'        code_type = 'P' description = 'Create Sales Order' ) to gt_actions.
  append value #( step = '051' category = '05-Sales'         code = 'ZRET_R_SO_LIST'          code_type = 'P' description = 'Sales Order list (status colors + items popup)' ) to gt_actions.
  append value #( step = '052' category = '05-Sales'         code = 'ZRET_R_DELIV_CREATE'     code_type = 'P' description = 'Create Delivery from SO (transitions SO to D)' ) to gt_actions.
  append value #( step = '053' category = '05-Sales'         code = 'ZRET_R_DELIV_LIST'       code_type = 'P' description = 'Delivery list' ) to gt_actions.
  append value #( step = '054' category = '05-Sales'         code = 'ZRET_R_INV_CREATE'       code_type = 'P' description = 'Create customer Invoice from Delivery' ) to gt_actions.
  append value #( step = '055' category = '05-Sales'         code = 'ZRET_R_INV_LIST'         code_type = 'P' description = 'Customer invoice list' ) to gt_actions.

  " --- Color rows by category for visual readability ---
  loop at gt_actions assigning field-symbol(<fs>).
    data ls_color type lvc_s_scol.
    clear ls_color.
    case <fs>-category(2).
      when '01'.
        ls_color-color-col = 5.   " yellow - Master setup
      when '02'.
        ls_color-color-col = 4.   " blue - Master lists
      when '03'.
        ls_color-color-col = 6.   " green - Procurement
      when '04'.
        ls_color-color-col = 3.   " grey-blue - Warehouse
      when '05'.
        ls_color-color-col = 6.   " green - Sales
        ls_color-color-int = 1.   " intensified
      when others.
        ls_color-color-col = 0.
    endcase.
    ls_color-fname = '*'.
    append ls_color to <fs>-t_color.
  endloop.

endform.


form display_launchpad.

  data lo_alv type ref to cl_salv_table.

  try.
      cl_salv_table=>factory(
        importing
          r_salv_table = lo_alv
        changing
          t_table      = gt_actions
      ).

      data(lo_columns) = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).
      lo_columns->set_color_column( 't_color' ).

      " Hide technical color column
      try.
          data(lo_col_color) = lo_columns->get_column( 'T_COLOR' ).
          lo_col_color->set_technical( abap_true ).
        catch cx_salv_not_found.
      endtry.

      " Hide code_type column (technical only)
      try.
          data(lo_col_type) = lo_columns->get_column( 'CODE_TYPE' ).
          lo_col_type->set_technical( abap_true ).
        catch cx_salv_not_found.
      endtry.

      " Hotspot on CODE column
      try.
          data(lo_col_code) = lo_columns->get_column( 'CODE' ).
          data(lo_col_table) = cast cl_salv_column_table( lo_col_code ).
          lo_col_table->set_cell_type( if_salv_c_cell_type=>hotspot ).
        catch cx_salv_not_found.
      endtry.

      " Customize column labels
      try.
          lo_columns->get_column( 'STEP' )->set_short_text( 'Step' ).
          lo_columns->get_column( 'CATEGORY' )->set_short_text( 'Category' ).
          lo_columns->get_column( 'CODE' )->set_short_text( 'Code' ).
lo_columns->get_column( 'CODE' )->set_long_text( 'Code (click to launch)' ).
          lo_columns->get_column( 'DESCRIPTION' )->set_short_text( 'Action' ).
          lo_columns->get_column( 'DESCRIPTION' )->set_long_text( 'Description' ).
        catch cx_salv_not_found.
      endtry.

      " Sort by step ascending
      data(lo_sorts) = lo_alv->get_sorts( ).
      try.
          lo_sorts->add_sort(
            columnname = 'STEP'
            position   = 1
            sequence   = if_salv_c_sort=>sort_up ).
        catch cx_salv_data_error
              cx_salv_existing
              cx_salv_not_found.
      endtry.

      " Title
      lo_alv->get_display_settings( )->set_list_header(
        'Retail Z Sandbox - Launchpad (click on Code to run)' ).

      " Standard ALV functions
      lo_alv->get_functions( )->set_all( ).

      " Register hotspot handler
      data(lo_events) = lo_alv->get_event( ).
      set handler lcl_handler=>on_link_click for lo_events.

      lo_alv->display( ).

    catch cx_salv_msg into data(lx_msg).
      message lx_msg type 'E'.
  endtry.

endform.
