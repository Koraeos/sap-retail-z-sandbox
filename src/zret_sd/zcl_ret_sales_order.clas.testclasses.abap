*"* use this source file for your ABAP unit test classes

CLASS ltcl_so_tests DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    METHODS:
      teardown,

      " Helpers (private to keep tests DRY)
      build_basic_header
        RETURNING VALUE(rs_header) TYPE zret_t_so,
      build_basic_items
        RETURNING VALUE(rt_items) TYPE zcl_ret_sales_order=>ty_item_input_tab,

      " Tests
      create_returns_so_number       FOR TESTING,
      create_calculates_total        FOR TESTING,
      create_snapshots_article_data  FOR TESTING,
      create_raises_on_unknown_art   FOR TESTING,
      create_raises_on_empty_cust    FOR TESTING,
      create_raises_on_empty_items   FOR TESTING,
      get_by_id_returns_full         FOR TESTING,
      get_by_id_raises_if_not_found  FOR TESTING.

ENDCLASS.


CLASS ltcl_so_tests IMPLEMENTATION.

  METHOD teardown.
    " Cleanup test SOs (identified by customer_id starting with 'TC')
    SELECT so_number FROM zret_t_so
      WHERE customer_id LIKE 'TC%'
      INTO TABLE @DATA(lt_test_so).

    IF lt_test_so IS NOT INITIAL.
      LOOP AT lt_test_so INTO DATA(ls_so).
        DELETE FROM zret_t_so_item WHERE so_number = @ls_so-so_number.
      ENDLOOP.
      DELETE FROM zret_t_so WHERE customer_id LIKE 'TC%'.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.


  METHOD build_basic_header.
    rs_header-customer_id   = 'TC0001'.
    rs_header-customer_name = 'Test Customer'.
    rs_header-currency      = 'EUR'.
  ENDMETHOD.


  METHOD build_basic_items.
    rt_items = VALUE #(
      ( article_id = 'ART001' quantity = 5 )
      ( article_id = 'ART002' quantity = 3 )
    ).
  ENDMETHOD.


  METHOD create_returns_so_number.
    TRY.
        DATA(lv_so) = zcl_ret_sales_order=>create(
          is_header = build_basic_header( )
          it_items  = build_basic_items( ) ).
        cl_abap_unit_assert=>assert_not_initial(
          act = lv_so
          msg = 'SO number should be returned' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core during create' ).
    ENDTRY.
  ENDMETHOD.


  METHOD create_calculates_total.
    " Expected: 5 * 29.99 + 3 * 7.99 = 149.95 + 23.97 = 173.92
    TRY.
        DATA(lv_so) = zcl_ret_sales_order=>create(
          is_header = build_basic_header( )
          it_items  = build_basic_items( ) ).
        DATA(ls_full) = zcl_ret_sales_order=>get_by_id( lv_so ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_full-header-total_amount
          exp = '173.92'
          msg = 'Total should equal sum of line amounts' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.


  METHOD create_snapshots_article_data.
    TRY.
        DATA(lv_so) = zcl_ret_sales_order=>create(
          is_header = build_basic_header( )
          it_items  = build_basic_items( ) ).
        DATA(ls_full) = zcl_ret_sales_order=>get_by_id( lv_so ).

        READ TABLE ls_full-items
          INTO DATA(ls_item)
          WITH KEY article_id = 'ART001'.
        cl_abap_unit_assert=>assert_subrc(
          exp = 0
          msg = 'ART001 line should be present' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_item-unit_price
          exp = '29.99'
          msg = 'Unit price should be snapshot from article master (29.99)' ).
        cl_abap_unit_assert=>assert_not_initial(
          act = ls_item-article_name
          msg = 'Article name should be snapshot from article master' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.


  METHOD create_raises_on_unknown_art.
    DATA lt_items TYPE zcl_ret_sales_order=>ty_item_input_tab.
    lt_items = VALUE #( ( article_id = 'ZZ999' quantity = 1 ) ).

    TRY.
        zcl_ret_sales_order=>create(
          is_header = build_basic_header( )
          it_items  = lt_items ).
        cl_abap_unit_assert=>fail( 'Should have raised for unknown article' ).
      CATCH zcx_ret_core.
        " Expected — bubbled up from zcl_ret_article=>get_by_id
    ENDTRY.
  ENDMETHOD.


  METHOD create_raises_on_empty_cust.
    DATA ls_header TYPE zret_t_so.
    ls_header-currency = 'EUR'. " customer_id intentionally empty

    TRY.
        zcl_ret_sales_order=>create(
          is_header = ls_header
          it_items  = build_basic_items( ) ).
        cl_abap_unit_assert=>fail( 'Should have raised for empty customer_id' ).
      CATCH zcx_ret_core.
        " Expected
    ENDTRY.
  ENDMETHOD.


  METHOD create_raises_on_empty_items.
    DATA lt_items TYPE zcl_ret_sales_order=>ty_item_input_tab.
    " lt_items intentionally empty

    TRY.
        zcl_ret_sales_order=>create(
          is_header = build_basic_header( )
          it_items  = lt_items ).
        cl_abap_unit_assert=>fail( 'Should have raised for empty items' ).
      CATCH zcx_ret_core.
        " Expected
    ENDTRY.
  ENDMETHOD.


  METHOD get_by_id_returns_full.
    TRY.
        DATA(lv_so) = zcl_ret_sales_order=>create(
          is_header = build_basic_header( )
          it_items  = build_basic_items( ) ).
        DATA(ls_full) = zcl_ret_sales_order=>get_by_id( lv_so ).

        cl_abap_unit_assert=>assert_equals(
          act = ls_full-header-so_number
          exp = lv_so
          msg = 'Returned header should match created SO number' ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( ls_full-items )
          exp = 2
          msg = 'Should have exactly 2 items' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.


  METHOD get_by_id_raises_if_not_found.
    TRY.
        zcl_ret_sales_order=>get_by_id( '9999999999' ).
        cl_abap_unit_assert=>fail( 'Should have raised for unknown SO' ).
      CATCH zcx_ret_core.
        " Expected
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
