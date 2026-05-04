class zcl_ret_cust_partner definition
  public final create public.

  public section.

    types:
      ty_partner_assignment  type zret_t_cust_prt,
      tt_partner_assignments type standard table of ty_partner_assignment
                                with default key.

    constants:
      begin of c_active,
        yes type c length 1 value 'X',
        no  type c length 1 value ' ',
      end of c_active.

    constants:
      begin of c_partner_function,
        sold_to type zde_ret_part_fct value 'AG',
        ship_to type zde_ret_part_fct value 'WE',
        bill_to type zde_ret_part_fct value 'RE',
        payer   type zde_ret_part_fct value 'RG',
      end of c_partner_function.

    class-methods seed_partner_functions
      raising zcx_ret_core.

    class-methods assign_partner
      importing
        iv_customer_id         type kunnr
        iv_partner_function    type zde_ret_part_fct
        iv_partner_customer_id type kunnr
      returning
        value(rv_counter)      type zret_t_cust_prt-partner_counter
      raising
        zcx_ret_core.

    class-methods get_partners
      importing
        iv_customer_id     type kunnr
      returning
        value(rt_partners) type tt_partner_assignments.

    class-methods get_partner_for_function
      importing
        iv_customer_id                type kunnr
        iv_partner_function           type zde_ret_part_fct
      returning
        value(rv_partner_customer_id) type kunnr.

    class-methods deactivate_partner
      importing
        iv_customer_id      type kunnr
        iv_partner_function type zde_ret_part_fct
        iv_partner_counter  type zret_t_cust_prt-partner_counter
      raising
        zcx_ret_core.

  private section.

    class-methods customer_exists_and_active
      importing
        iv_customer_id   type kunnr
      returning
        value(rv_exists) type abap_bool.

    class-methods get_next_counter
      importing
        iv_customer_id      type kunnr
        iv_partner_function type zde_ret_part_fct
      returning
        value(rv_counter)   type zret_t_cust_prt-partner_counter.

endclass.


class zcl_ret_cust_partner implementation.

  method seed_partner_functions.

    data lt_functions type standard table of zret_t_part_fct.

    delete from zret_t_part_fct.

    lt_functions = value #(
      ( client = sy-mandt
        partner_function = c_partner_function-sold_to
        description      = 'Sold-to Party'
        is_mandatory     = c_active-yes
        created_by       = sy-uname
        created_on       = sy-datum )

      ( client = sy-mandt
        partner_function = c_partner_function-ship_to
        description      = 'Ship-to Party'
        is_mandatory     = c_active-yes
        created_by       = sy-uname
        created_on       = sy-datum )

      ( client = sy-mandt
        partner_function = c_partner_function-bill_to
        description      = 'Bill-to Party'
        is_mandatory     = c_active-no
        created_by       = sy-uname
        created_on       = sy-datum )

      ( client = sy-mandt
        partner_function = c_partner_function-payer
        description      = 'Payer'
        is_mandatory     = c_active-no
        created_by       = sy-uname
        created_on       = sy-datum )
    ).

    insert zret_t_part_fct from table @lt_functions.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.


  method assign_partner.

    if customer_exists_and_active( iv_customer_id ) = abap_false.
      raise exception type zcx_ret_core.
    endif.

    if customer_exists_and_active( iv_partner_customer_id ) = abap_false.
      raise exception type zcx_ret_core.
    endif.

    select single @abap_true from zret_t_part_fct
      into @data(lv_fct_exists)
      where partner_function = @iv_partner_function.
    if lv_fct_exists <> abap_true.
      raise exception type zcx_ret_core.
    endif.

    rv_counter = get_next_counter(
      iv_customer_id      = iv_customer_id
      iv_partner_function = iv_partner_function ).

    data ls_assignment type zret_t_cust_prt.
    ls_assignment-client              = sy-mandt.
    ls_assignment-customer_id         = iv_customer_id.
    ls_assignment-partner_function    = iv_partner_function.
    ls_assignment-partner_counter     = rv_counter.
    ls_assignment-partner_customer_id = iv_partner_customer_id.
    ls_assignment-active_flag         = c_active-yes.
    ls_assignment-created_by          = sy-uname.
    ls_assignment-created_on          = sy-datum.
    ls_assignment-changed_by          = sy-uname.
    ls_assignment-changed_on          = sy-datum.

    insert zret_t_cust_prt from @ls_assignment.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.


  method get_partners.
    select * from zret_t_cust_prt
      into table @rt_partners
      where customer_id = @iv_customer_id
        and active_flag = @c_active-yes
      order by partner_function ascending,
               partner_counter  ascending.
  endmethod.


method get_partner_for_function.

    select partner_customer_id from zret_t_cust_prt
      into @rv_partner_customer_id
      up to 1 rows
      where customer_id      = @iv_customer_id
        and partner_function = @iv_partner_function
        and active_flag      = @c_active-yes
      order by partner_counter ascending.
    endselect.

    if rv_partner_customer_id is initial.
      rv_partner_customer_id = iv_customer_id.
    endif.
  endmethod.


  method deactivate_partner.

    update zret_t_cust_prt
      set active_flag = @c_active-no,
          changed_by  = @sy-uname,
          changed_on  = @sy-datum
      where customer_id      = @iv_customer_id
        and partner_function = @iv_partner_function
        and partner_counter  = @iv_partner_counter.

    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.


  method customer_exists_and_active.
    select single @abap_true from zret_t_customer
      into @data(lv_exists)
      where customer_id = @iv_customer_id
        and active_flag = 'X'.

    rv_exists = lv_exists.
  endmethod.


  method get_next_counter.

    select max( partner_counter ) from zret_t_cust_prt
      into @data(lv_max)
      where customer_id      = @iv_customer_id
        and partner_function = @iv_partner_function.

    rv_counter = lv_max + 1.
  endmethod.

endclass.
