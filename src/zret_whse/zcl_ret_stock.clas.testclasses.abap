"! Test class for ZCL_RET_STOCK
class ltcl_stock_test definition for testing
  duration short
  risk level harmless
  final.

  private section.
    constants:
      c_test_article type zret_t_stock-article_id value 'TST001',
      c_test_site    type zret_t_stock-site_id    value 'TS01',
      c_test_uom     type zret_t_stock-base_uom   value 'PC'.

    methods:
      teardown,
      test_load_initial_ok       for testing,
      test_post_invalid_qty      for testing,
      test_post_both_zones_empty for testing,
      test_get_available_zero    for testing,
      test_validate_insufficient for testing,
      test_transfer_zones        for testing.
endclass.


class ltcl_stock_test implementation.

  method teardown.
    " Cleanup after each test: remove test article rows from stock + journal
    delete from zret_t_stock
      where article_id = @c_test_article
        and site_id    = @c_test_site.

    delete from zret_t_stk_mvt
      where article_id = @c_test_article
        and site_id    = @c_test_site.

    commit work and wait.
  endmethod.


  method test_load_initial_ok.
    " GIVEN no stock for the test article
    " WHEN  load_initial_stock is called with 100 PC
    " THEN  zone STORAGE should hold exactly 100 PC

    try.
        data(ls_mvt) = zcl_ret_stock=>load_initial_stock(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_quantity   = '100'
          iv_base_uom   = c_test_uom
        ).

        cl_abap_unit_assert=>assert_not_initial(
          act = ls_mvt-mvt_doc
          msg = 'Movement document should be created'
        ).

        data(lv_qty) = zcl_ret_stock=>get_available(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-storage
        ).

        cl_abap_unit_assert=>assert_equals(
          exp = '100'
          act = lv_qty
          msg = 'STORAGE should hold 100 PC after initial load'
        ).

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.


  method test_post_invalid_qty.
    " WHEN  post_movement is called with quantity = 0
    " THEN  should raise zcx_ret_core

    try.
        zcl_ret_stock=>post_movement(
          iv_mvt_type   = zcl_ret_stock=>c_mvt_type-init
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_dst_zone   = zcl_ret_stock=>c_zone-storage
          iv_quantity   = '0'
          iv_base_uom   = c_test_uom
        ).

        cl_abap_unit_assert=>fail( msg = 'Should have raised exception for zero quantity' ).

      catch zcx_ret_core.
        " expected
    endtry.
  endmethod.


  method test_post_both_zones_empty.
    " WHEN  post_movement called with no source AND no destination zone
    " THEN  should raise zcx_ret_core

    try.
        zcl_ret_stock=>post_movement(
          iv_mvt_type   = zcl_ret_stock=>c_mvt_type-init
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_quantity   = '50'
          iv_base_uom   = c_test_uom
        ).

        cl_abap_unit_assert=>fail( msg = 'Should have raised exception when both zones empty' ).

      catch zcx_ret_core.
        " expected
    endtry.
  endmethod.


  method test_get_available_zero.
    " GIVEN no stock record for test article
    " WHEN  get_available is called
    " THEN  returns 0 (not error)

    data(lv_qty) = zcl_ret_stock=>get_available(
      iv_article_id = c_test_article
      iv_site_id    = c_test_site
      iv_zone_code  = zcl_ret_stock=>c_zone-storage
    ).

    cl_abap_unit_assert=>assert_equals(
      exp = 0
      act = lv_qty
      msg = 'Should return 0 if no stock record exists'
    ).
  endmethod.


  method test_validate_insufficient.
    " GIVEN 100 PC in STORAGE
    " WHEN  validate_availability for 200 PC
    " THEN  should raise zcx_ret_core

    try.
        zcl_ret_stock=>load_initial_stock(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_quantity   = '100'
          iv_base_uom   = c_test_uom
        ).

        zcl_ret_stock=>validate_availability(
          iv_article_id   = c_test_article
          iv_site_id      = c_test_site
          iv_zone_code    = zcl_ret_stock=>c_zone-storage
          iv_required_qty = '200'
        ).

        cl_abap_unit_assert=>fail( msg = 'Should have raised exception for insufficient stock' ).

      catch zcx_ret_core.
        " expected
    endtry.
  endmethod.


  method test_transfer_zones.
    " GIVEN 100 PC in STORAGE
    " WHEN  transfer 60 PC to STAGING (mvt 411 - pick)
    " THEN  STORAGE = 40 PC, STAGING = 60 PC

    try.
        zcl_ret_stock=>load_initial_stock(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_quantity   = '100'
          iv_base_uom   = c_test_uom
        ).

        zcl_ret_stock=>post_movement(
          iv_mvt_type   = zcl_ret_stock=>c_mvt_type-pick
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = zcl_ret_stock=>c_zone-storage
          iv_dst_zone   = zcl_ret_stock=>c_zone-staging
          iv_quantity   = '60'
          iv_base_uom   = c_test_uom
        ).

        data(lv_storage) = zcl_ret_stock=>get_available(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-storage
        ).
        cl_abap_unit_assert=>assert_equals(
          exp = '40'
          act = lv_storage
          msg = 'STORAGE should hold 40 PC after transfer'
        ).

        data(lv_staging) = zcl_ret_stock=>get_available(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-staging
        ).
        cl_abap_unit_assert=>assert_equals(
          exp = '60'
          act = lv_staging
          msg = 'STAGING should hold 60 PC after transfer'
        ).

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.

endclass.
