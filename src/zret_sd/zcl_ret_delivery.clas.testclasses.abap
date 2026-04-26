*"* use this source file for your ABAP unit test classes

CLASS ltcl_deliv_tests DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-METHODS class_setup.

    METHODS:
      teardown,

      " Helper: creates a fresh SO in Open status, returns its number
      create_test_so
        RETURNING VALUE(rv_so_number) TYPE zret_t_so-so_number,

      " Happy path tests
      create_from_so_returns_number      FOR TESTING,
      so_becomes_delivered               FOR TESTING,
      create_from_so_copies_items        FOR TESTING,
      get_by_id_returns_full             FOR TESTING,

      " Error path tests
      create_raises_on_unknown_so        FOR TESTING,
      cannot_redeliver_so                FOR TESTING,
      create_raises_on_unknown_site      FOR TESTING,
      create_raises_on_non_warehouse     FOR TESTING,
      get_by_id_raises_if_not_found     FOR TESTING.

ENDCLASS.


CLASS ltcl_deliv_tests IMPLEMENTATION.

  METHOD class_setup.
    " Create dedicated test customer once (idempotent: ignored if already exists)
    TRY.
        DATA ls_cust TYPE zret_t_customer.
        ls_cust-customer_id      = 'TESTDELIV'.
        ls_cust-customer_name    = 'Test Customer for Delivery Tests'.
        ls_cust-customer_type    = 'B'.
        ls_cust-default_currency = 'EUR'.
        zcl_ret_customer=>create( ls_cust ).
      CATCH zcx_ret_core.
        " Already exists from a previous run - fine
    ENDTRY.
  ENDMETHOD.


  METHOD teardown.
    " Find all SOs from our test customer
    SELECT so_number FROM zret_t_so
      WHERE customer_id = 'TESTDELIV'
      INTO TABLE @DATA(lt_test_so).

    IF lt_test_so IS INITIAL.
      RETURN.
    ENDIF.

    " Cascade-delete: delivery items, deliveries, SO items, SOs
    LOOP AT lt_test_so INTO DATA(ls_so).
      SELECT deliv_number FROM zret_t_deliv
        WHERE so_number = @ls_so-so_number
        INTO TABLE @DATA(lt_deliv).

      LOOP AT lt_deliv INTO DATA(ls_deliv).
        DELETE FROM zret_t_deliv_ite WHERE deliv_number = @ls_deliv-deliv_number.
      ENDLOOP.

      DELETE FROM zret_t_deliv     WHERE so_number = @ls_so-so_number.
      DELETE FROM zret_t_so_item   WHERE so_number = @ls_so-so_number.
    ENDLOOP.

    DELETE FROM zret_t_so WHERE customer_id = 'TESTDELIV'.

    COMMIT WORK.
  ENDMETHOD.


  METHOD create_test_so.
    DATA ls_header TYPE zret_t_so.
    ls_header-customer_id = 'TESTDELIV'.
    ls_header-currency    = 'EUR'.

    DATA lt_items TYPE zcl_ret_sales_order=>ty_item_input_tab.
    lt_items = VALUE #( ( article_id = 'ART001' quantity = 2 ) ).

    rv_so_number = zcl_ret_sales_order=>create(
      is_header = ls_header
      it_items  = lt_items ).
  ENDMETHOD.


  METHOD create_from_so_returns_number.
    TRY.
        DATA(lv_so)    = create_test_so( ).
        DATA(lv_deliv) = zcl_ret_delivery=>create_from_so(
          iv_so_number      = lv_so
          iv_source_site_id = 'WH01' ).

        cl_abap_unit_assert=>assert_not_initial(
          act = lv_deliv
          msg = 'Delivery number should be returned' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.


  METHOD so_becomes_delivered.
    " *** THE CRITICAL TEST: lifecycle transition O -> D ***
    TRY.
        DATA(lv_so) = create_test_so( ).
        zcl_ret_delivery=>create_from_so(
          iv_so_number      = lv_so
          iv_source_site_id = 'WH01' ).

        " Reload the SO and check status
        DATA(ls_so_full) = zcl_ret_sales_order=>get_by_id( lv_so ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_so_full-header-status
          exp = zcl_ret_sales_order=>c_status-delivered
          msg = 'SO status should be Delivered after delivery creation' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.


  METHOD create_from_so_copies_items.
    TRY.
        DATA(lv_so) = create_test_so( ).
        DATA(lv_deliv) = zcl_ret_delivery=>create_from_so(
          iv_so_number      = lv_so
          iv_source_site_id = 'WH01' ).

        DATA(ls_full) = zcl_ret_delivery=>get_by_id( lv_deliv ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( ls_full-items )
          exp = 1
          msg = 'Delivery should have same number of items as SO' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.


  METHOD get_by_id_returns_full.
    TRY.
        DATA(lv_so) = create_test_so( ).
        DATA(lv_deliv) = zcl_ret_delivery=>create_from_so(
          iv_so_number      = lv_so
          iv_source_site_id = 'WH01' ).

        DATA(ls_full) = zcl_ret_delivery=>get_by_id( lv_deliv ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_full-header-deliv_number
          exp = lv_deliv
          msg = 'Returned header should match' ).
        cl_abap_unit_assert=>assert_not_initial(
          act = lines( ls_full-items )
          msg = 'Items should be returned' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.


  METHOD create_raises_on_unknown_so.
    TRY.
        zcl_ret_delivery=>create_from_so(
          iv_so_number      = '9999999999'
          iv_source_site_id = 'WH01' ).
        cl_abap_unit_assert=>fail( 'Should have raised for unknown SO' ).
      CATCH zcx_ret_core.
        " Expected — bubbled up from zcl_ret_sales_order=>get_by_id
    ENDTRY.
  ENDMETHOD.


  METHOD cannot_redeliver_so.
    TRY.
        DATA(lv_so) = create_test_so( ).
        " First delivery: succeeds (SO transitions O -> D)
        zcl_ret_delivery=>create_from_so(
          iv_so_number      = lv_so
          iv_source_site_id = 'WH01' ).
        " Second delivery on same SO: should fail (status is now D, not O)
        zcl_ret_delivery=>create_from_so(
          iv_so_number      = lv_so
          iv_source_site_id = 'WH01' ).
        cl_abap_unit_assert=>fail( 'Should have raised on second delivery' ).
      CATCH zcx_ret_core.
        " Expected on second call
    ENDTRY.
  ENDMETHOD.


  METHOD create_raises_on_unknown_site.
    TRY.
        DATA(lv_so) = create_test_so( ).
        zcl_ret_delivery=>create_from_so(
          iv_so_number      = lv_so
          iv_source_site_id = 'XX99' ).
        cl_abap_unit_assert=>fail( 'Should have raised for unknown site' ).
      CATCH zcx_ret_core.
        " Expected
    ENDTRY.
  ENDMETHOD.


  METHOD create_raises_on_non_warehouse.
    TRY.
        DATA(lv_so) = create_test_so( ).
        " ST01 is a store (S), not a warehouse (W)
        zcl_ret_delivery=>create_from_so(
          iv_so_number      = lv_so
          iv_source_site_id = 'ST01' ).
        cl_abap_unit_assert=>fail( 'Should have raised for non-warehouse site' ).
      CATCH zcx_ret_core.
        " Expected
    ENDTRY.
  ENDMETHOD.


  METHOD get_by_id_raises_if_not_found.
    TRY.
        zcl_ret_delivery=>get_by_id( '9999999999' ).
        cl_abap_unit_assert=>fail( 'Should have raised for unknown delivery' ).
      CATCH zcx_ret_core.
        " Expected
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
