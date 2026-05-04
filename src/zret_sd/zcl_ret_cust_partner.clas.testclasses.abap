class ltc_cust_partner definition deferred.
class zcl_ret_cust_partner definition local friends ltc_cust_partner.

class ltc_cust_partner definition for testing
  duration short
  risk level harmless.

  private section.

    constants:
      c_cust_a type kunnr value 'TST_CUS_A',
      c_cust_b type kunnr value 'TST_CUS_B',
      c_cust_c type kunnr value 'TST_CUS_C'.

    methods:
      setup,
      teardown,
      cleanup_test_data,
      create_test_customers,

      test_seed_functions          for testing,
      test_assign_creates_record   for testing,
      test_assign_invalid_customer for testing,
      test_fallback_to_sold_to     for testing,
      test_multi_ship_to_counter   for testing,
      test_deactivate_then_fallback for testing.

endclass.


class ltc_cust_partner implementation.

  method setup.
    cleanup_test_data( ).
    create_test_customers( ).
  endmethod.

  method teardown.
    cleanup_test_data( ).
  endmethod.

  method cleanup_test_data.
    delete from zret_t_cust_prt
      where customer_id like 'TST_CUS%'
         or partner_customer_id like 'TST_CUS%'.
    commit work and wait.

    delete from zret_t_customer
      where customer_id like 'TST_CUS%'.
    commit work and wait.
  endmethod.

  method create_test_customers.
    data lt_customers type standard table of zret_t_customer.

    lt_customers = value #(
      ( mandt = sy-mandt
        customer_id   = c_cust_a
        customer_name = 'Test Customer A'
        customer_type = 'B'
        country       = 'FR'
        active_flag   = 'X' )
      ( mandt = sy-mandt
        customer_id   = c_cust_b
        customer_name = 'Test Customer B'
        customer_type = 'B'
        country       = 'FR'
        active_flag   = 'X' )
      ( mandt = sy-mandt
        customer_id   = c_cust_c
        customer_name = 'Test Customer C'
        customer_type = 'B'
        country       = 'FR'
        active_flag   = 'X' )
    ).

    insert zret_t_customer from table @lt_customers.
    commit work and wait.
  endmethod.


  method test_seed_functions.
    " When seed is called
    try.
        zcl_ret_cust_partner=>seed_partner_functions( ).
      catch zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Seed should not raise' ).
    endtry.

    " Then 4 functions should exist (AG/WE/RE/RG)
    select count(*) from zret_t_part_fct into @data(lv_count).
    cl_abap_unit_assert=>assert_equals(
      exp = 4
      act = lv_count
      msg = 'Should have 4 partner functions seeded' ).
  endmethod.


  method test_assign_creates_record.
    " Given functions seeded
    try.
        zcl_ret_cust_partner=>seed_partner_functions( ).
      catch zcx_ret_core.
    endtry.

    " When assign B as Ship-to of A
    data lv_counter type zret_t_cust_prt-partner_counter.
    try.
        lv_counter = zcl_ret_cust_partner=>assign_partner(
          iv_customer_id         = c_cust_a
          iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-ship_to
          iv_partner_customer_id = c_cust_b ).
      catch zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Assign should not raise' ).
    endtry.

    " Then counter is 001 (first assignment)
    cl_abap_unit_assert=>assert_equals(
      exp = '001'
      act = lv_counter
      msg = 'First assignment should have counter 001' ).
  endmethod.


method test_assign_invalid_customer.
    try.
        zcl_ret_cust_partner=>seed_partner_functions( ).
      catch zcx_ret_core.
    endtry.

    " When assign with non-existent customer, should raise
    try.
        zcl_ret_cust_partner=>assign_partner(
          iv_customer_id         = 'TST_NONE'
          iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-ship_to
          iv_partner_customer_id = c_cust_b ).
        cl_abap_unit_assert=>fail( 'Should have raised exception' ).
      catch zcx_ret_core.
        " Expected — test passes
    endtry.
  endmethod.


  method test_fallback_to_sold_to.
    " Given customer A with NO explicit partner

    " When resolve Ship-to of A
    data(lv_partner) = zcl_ret_cust_partner=>get_partner_for_function(
      iv_customer_id      = c_cust_a
      iv_partner_function = zcl_ret_cust_partner=>c_partner_function-ship_to ).

    " Then fallback returns A itself
    cl_abap_unit_assert=>assert_equals(
      exp = c_cust_a
      act = lv_partner
      msg = 'Fallback should return sold-to itself' ).
  endmethod.


  method test_multi_ship_to_counter.
    try.
        zcl_ret_cust_partner=>seed_partner_functions( ).
      catch zcx_ret_core.
    endtry.

    " When assign B then C as Ship-to of A
    data: lv_counter_b type zret_t_cust_prt-partner_counter,
          lv_counter_c type zret_t_cust_prt-partner_counter.

    try.
        lv_counter_b = zcl_ret_cust_partner=>assign_partner(
          iv_customer_id         = c_cust_a
          iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-ship_to
          iv_partner_customer_id = c_cust_b ).

        lv_counter_c = zcl_ret_cust_partner=>assign_partner(
          iv_customer_id         = c_cust_a
          iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-ship_to
          iv_partner_customer_id = c_cust_c ).
      catch zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Assign should not raise' ).
    endtry.

    " Then counters are 001 and 002
    cl_abap_unit_assert=>assert_equals(
      exp = '001'
      act = lv_counter_b
      msg = 'First Ship-to should be counter 001' ).

    cl_abap_unit_assert=>assert_equals(
      exp = '002'
      act = lv_counter_c
      msg = 'Second Ship-to should be counter 002' ).
  endmethod.


  method test_deactivate_then_fallback.
    try.
        zcl_ret_cust_partner=>seed_partner_functions( ).
      catch zcx_ret_core.
    endtry.

    data lv_counter type zret_t_cust_prt-partner_counter.

    try.
        lv_counter = zcl_ret_cust_partner=>assign_partner(
          iv_customer_id         = c_cust_a
          iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-ship_to
          iv_partner_customer_id = c_cust_b ).

        zcl_ret_cust_partner=>deactivate_partner(
          iv_customer_id      = c_cust_a
          iv_partner_function = zcl_ret_cust_partner=>c_partner_function-ship_to
          iv_partner_counter  = lv_counter ).
      catch zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Setup should not raise' ).
    endtry.

    " When resolve Ship-to of A after deactivation
    data(lv_partner) = zcl_ret_cust_partner=>get_partner_for_function(
      iv_customer_id      = c_cust_a
      iv_partner_function = zcl_ret_cust_partner=>c_partner_function-ship_to ).

    " Then deactivated partner is ignored, fallback to A
    cl_abap_unit_assert=>assert_equals(
      exp = c_cust_a
      act = lv_partner
      msg = 'Deactivated partner should be ignored, fallback to sold-to' ).
  endmethod.

endclass.
