report zret_r_cust_part_list.

types:
  begin of ty_matrix_row,
    customer_id          type kunnr,
    customer_name        type zret_t_customer-customer_name,
    customer_type        type zret_t_customer-customer_type,
    partner_function     type zde_ret_part_fct,
    function_description type zret_t_part_fct-description,
    resolution_mode      type c length 10,
    partner_counter      type zret_t_cust_prt-partner_counter,
    partner_customer_id  type kunnr,
    partner_name         type zret_t_customer-customer_name,
  end of ty_matrix_row,
  tt_matrix type standard table of ty_matrix_row with default key.

data gt_matrix type tt_matrix.

start-of-selection.
  perform build_matrix.
  perform display_matrix.


form build_matrix.

  " 1. All active customers
  select * from zret_t_customer
    into table @data(lt_customers)
    where active_flag = 'X'
    order by customer_id ascending.

  " 2. All partner functions reference (AG/WE/RE/RG)
  select * from zret_t_part_fct
    into table @data(lt_functions)
    order by partner_function ascending.

  " 3. For each customer × each function, emit matrix row(s)
  loop at lt_customers into data(ls_customer).
    loop at lt_functions into data(ls_function).

      " Look for explicit assignments
      select * from zret_t_cust_prt
        into table @data(lt_assignments)
        where customer_id      = @ls_customer-customer_id
          and partner_function = @ls_function-partner_function
          and active_flag      = 'X'
        order by partner_counter ascending.

      data ls_row type ty_matrix_row.
      ls_row-customer_id          = ls_customer-customer_id.
      ls_row-customer_name        = ls_customer-customer_name.
      ls_row-customer_type        = ls_customer-customer_type.
      ls_row-partner_function     = ls_function-partner_function.
      ls_row-function_description = ls_function-description.

      if lt_assignments is initial.
        " No explicit assignment → fallback to sold-to itself
        ls_row-resolution_mode     = 'Fallback'.
        ls_row-partner_counter     = '000'.
        ls_row-partner_customer_id = ls_customer-customer_id.
        ls_row-partner_name        = ls_customer-customer_name.
        append ls_row to gt_matrix.
      else.
        " Explicit assignment(s) — one row per counter
        loop at lt_assignments into data(ls_assignment).
          ls_row-resolution_mode     = 'Explicit'.
          ls_row-partner_counter     = ls_assignment-partner_counter.
          ls_row-partner_customer_id = ls_assignment-partner_customer_id.

          " Lookup partner customer name
          select single customer_name from zret_t_customer
            into @ls_row-partner_name
            where customer_id = @ls_assignment-partner_customer_id.

          append ls_row to gt_matrix.
        endloop.
      endif.

    endloop.
  endloop.

endform.


form display_matrix.

  data lo_alv type ref to cl_salv_table.

  try.
      cl_salv_table=>factory(
        importing
          r_salv_table = lo_alv
        changing
          t_table      = gt_matrix
      ).

      " Auto-optimize column widths
      data(lo_columns) = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " Customize column labels
   perform set_column_text using lo_columns 'CUSTOMER_ID'          'Sold-to'    'Sold-to ID'   'Sold-to Customer'.
      perform set_column_text using lo_columns 'CUSTOMER_NAME'        'Sold Name'  'Sold-to Name' 'Sold-to Customer Name'.
      perform set_column_text using lo_columns 'CUSTOMER_TYPE'        'Type'       'Cust Type'    'Customer Type'.
      perform set_column_text using lo_columns 'PARTNER_FUNCTION'     'PartFct'    'PartFct'      'Partner Function'.
      perform set_column_text using lo_columns 'FUNCTION_DESCRIPTION' 'Desc'       'PartFct Desc' 'Partner Function Description'.
      perform set_column_text using lo_columns 'RESOLUTION_MODE'      'Mode'       'Resolution'   'Resolution Mode'.
      perform set_column_text using lo_columns 'PARTNER_COUNTER'      'Ctr'        'Counter'      'Partner Counter'.
      perform set_column_text using lo_columns 'PARTNER_CUSTOMER_ID'  'Partner'    'Partner ID'   'Resolved Partner'.
      perform set_column_text using lo_columns 'PARTNER_NAME'         'Part Name'  'Partner Name' 'Resolved Partner Name'.

      " Title
      data(lo_display) = lo_alv->get_display_settings( ).
      lo_display->set_list_header( 'Customer x Partner Functions Matrix (with fallback resolution)' ).

      " Standard ALV functions (sort, filter, export, etc.)
      lo_alv->get_functions( )->set_all( ).

      lo_alv->display( ).

    catch cx_salv_msg into data(lx_msg).
      message lx_msg type 'E'.
  endtry.

endform.


form set_column_text using
  io_columns type ref to cl_salv_columns_table
  iv_col_id  type lvc_fname
  iv_short   type scrtext_s
  iv_medium  type scrtext_m
  iv_long    type scrtext_l.

  try.
      data(lo_col) = io_columns->get_column( iv_col_id ).
      lo_col->set_short_text( iv_short ).
      lo_col->set_medium_text( iv_medium ).
      lo_col->set_long_text( iv_long ).
    catch cx_salv_not_found.
      " Column not found — silently ignore
  endtry.
endform.
