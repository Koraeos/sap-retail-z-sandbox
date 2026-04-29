"! Test class for ZCL_RET_WH_TASK
class ltcl_wh_task_test definition for testing
  duration short
  risk level harmless
  final.

  private section.
    constants:
      c_test_article type zret_t_wh_task-article_id value 'TST_WHT_01',
      c_test_site    type zret_t_wh_task-site_id    value 'TS01',
      c_test_uom     type zret_t_wh_task-base_uom   value 'PC'.

    methods:
      teardown,

      test_create_task_ok       for testing,
      test_create_invalid_qty   for testing,
      test_create_missing_zone  for testing,
      test_confirm_ok           for testing,
      test_confirm_already_done for testing,
      test_cancel_ok            for testing,
test_pick_confirm_creates_load for testing,
test_load_confirm_no_chain     for testing,
      test_cancel_after_confirm for testing.
endclass.


class ltcl_wh_task_test implementation.

  method teardown.
    " Clean test data after each test
    delete from zret_t_wh_task
      where article_id = @c_test_article
        and site_id    = @c_test_site.

    delete from zret_t_stock
      where article_id = @c_test_article
        and site_id    = @c_test_site.

    delete from zret_t_stk_mvt
      where article_id = @c_test_article
        and site_id    = @c_test_site.

    commit work and wait.
  endmethod.


  method test_create_task_ok.
    " GIVEN nothing
    " WHEN  create_task is called with valid input
    " THEN  task is created with status Open
    try.
        data(lv_task_num) = zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-putaway
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = zcl_ret_stock=>c_zone-recv
          iv_dst_zone   = zcl_ret_stock=>c_zone-storage
          iv_quantity   = '50'
          iv_base_uom   = c_test_uom
        ).

        cl_abap_unit_assert=>assert_not_initial(
          act = lv_task_num
          msg = 'Task number should be returned'
        ).

        data(ls_task) = zcl_ret_wh_task=>get_task( lv_task_num ).
        cl_abap_unit_assert=>assert_equals(
          exp = zcl_ret_wh_task=>c_status-open
          act = ls_task-status
          msg = 'New task should be in status Open'
        ).

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.


  method test_create_invalid_qty.
    " WHEN  create_task with quantity = 0
    " THEN  raises zcx_ret_core
    try.
        zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-putaway
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = zcl_ret_stock=>c_zone-recv
          iv_dst_zone   = zcl_ret_stock=>c_zone-storage
          iv_quantity   = '0'
          iv_base_uom   = c_test_uom
        ).

        cl_abap_unit_assert=>fail( msg = 'Should have raised exception for zero quantity' ).

      catch zcx_ret_core.
        " expected
    endtry.
  endmethod.


  method test_create_missing_zone.
    " WHEN  create_task with src_zone empty
    " THEN  raises zcx_ret_core
    try.
        zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-putaway
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = ''
          iv_dst_zone   = zcl_ret_stock=>c_zone-storage
          iv_quantity   = '50'
          iv_base_uom   = c_test_uom
        ).

        cl_abap_unit_assert=>fail( msg = 'Should have raised exception when src_zone is empty' ).

      catch zcx_ret_core.
        " expected
    endtry.
  endmethod.


  method test_confirm_ok.
    " GIVEN 100 PC in RECV + a putaway task for 60 PC
    " WHEN  confirm
    " THEN  status = Confirmed, RECV = 40, STORAGE = 60, mvt_doc filled
    try.
        zcl_ret_stock=>load_initial_stock(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-recv
          iv_quantity   = '100'
          iv_base_uom   = c_test_uom
        ).

        data(lv_task_num) = zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-putaway
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = zcl_ret_stock=>c_zone-recv
          iv_dst_zone   = zcl_ret_stock=>c_zone-storage
          iv_quantity   = '60'
          iv_base_uom   = c_test_uom
        ).

        data(ls_mvt) = zcl_ret_wh_task=>confirm( lv_task_num ).

        cl_abap_unit_assert=>assert_not_initial(
          act = ls_mvt-mvt_doc
          msg = 'Movement document should be created on confirm'
        ).

        data(ls_task) = zcl_ret_wh_task=>get_task( lv_task_num ).
        cl_abap_unit_assert=>assert_equals(
          exp = zcl_ret_wh_task=>c_status-confirmed
          act = ls_task-status
          msg = 'Task status should be Confirmed after confirm'
        ).

        data(lv_recv) = zcl_ret_stock=>get_available(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-recv
        ).
        cl_abap_unit_assert=>assert_equals(
          exp = '40'
          act = lv_recv
          msg = 'RECV should have 40 PC after putaway of 60'
        ).

        data(lv_storage) = zcl_ret_stock=>get_available(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-storage
        ).
        cl_abap_unit_assert=>assert_equals(
          exp = '60'
          act = lv_storage
          msg = 'STORAGE should have 60 PC after putaway'
        ).

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.


  method test_confirm_already_done.
    " GIVEN a confirmed task
    " WHEN  confirm again
    " THEN  raises zcx_ret_core (idempotency check)
    try.
        zcl_ret_stock=>load_initial_stock(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-recv
          iv_quantity   = '100'
          iv_base_uom   = c_test_uom
        ).

        data(lv_task_num) = zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-putaway
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = zcl_ret_stock=>c_zone-recv
          iv_dst_zone   = zcl_ret_stock=>c_zone-storage
          iv_quantity   = '30'
          iv_base_uom   = c_test_uom
        ).

        zcl_ret_wh_task=>confirm( lv_task_num ).

        try.
            zcl_ret_wh_task=>confirm( lv_task_num ).
            cl_abap_unit_assert=>fail( msg = 'Should have raised exception when confirming twice' ).
          catch zcx_ret_core.
            " expected
        endtry.

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception during setup: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.


  method test_cancel_ok.
    " GIVEN an open task
    " WHEN  cancel
    " THEN  status = Cancelled
    try.
        data(lv_task_num) = zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-putaway
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = zcl_ret_stock=>c_zone-recv
          iv_dst_zone   = zcl_ret_stock=>c_zone-storage
          iv_quantity   = '50'
          iv_base_uom   = c_test_uom
        ).

        zcl_ret_wh_task=>cancel( lv_task_num ).

        data(ls_task) = zcl_ret_wh_task=>get_task( lv_task_num ).
        cl_abap_unit_assert=>assert_equals(
          exp = zcl_ret_wh_task=>c_status-cancelled
          act = ls_task-status
          msg = 'Task should be Cancelled after cancel call'
        ).

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.


  method test_cancel_after_confirm.
    " GIVEN a confirmed task
    " WHEN  cancel
    " THEN  raises zcx_ret_core (cannot cancel what is already done)
    try.
        zcl_ret_stock=>load_initial_stock(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-recv
          iv_quantity   = '100'
          iv_base_uom   = c_test_uom
        ).

        data(lv_task_num) = zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-putaway
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = zcl_ret_stock=>c_zone-recv
          iv_dst_zone   = zcl_ret_stock=>c_zone-storage
          iv_quantity   = '20'
          iv_base_uom   = c_test_uom
        ).

        zcl_ret_wh_task=>confirm( lv_task_num ).

        try.
            zcl_ret_wh_task=>cancel( lv_task_num ).
            cl_abap_unit_assert=>fail( msg = 'Should have raised exception when cancelling a Confirmed task' ).
          catch zcx_ret_core.
            " expected
        endtry.

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception during setup: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.
method test_pick_confirm_creates_load.
    " GIVEN: 100 PC in STORAGE + a Pick task
    " WHEN:  confirm Pick
    " THEN:  a Load task is auto-created (Open, STAGING -> LOAD_DOCK, same qty)
    try.
        zcl_ret_stock=>load_initial_stock(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-storage
          iv_quantity   = '100'
          iv_base_uom   = c_test_uom
        ).

        data(lv_pick_num) = zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-pick
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = zcl_ret_stock=>c_zone-storage
          iv_dst_zone   = zcl_ret_stock=>c_zone-staging
          iv_quantity   = '40'
          iv_base_uom   = c_test_uom
        ).

        zcl_ret_wh_task=>confirm( lv_pick_num ).

        " Verify: exactly one Load task in Open status for our test article
        data lt_loads type table of zret_t_wh_task.
        select * from zret_t_wh_task
          into table @lt_loads
          where article_id = @c_test_article
            and site_id    = @c_test_site
            and task_type  = @zcl_ret_wh_task=>c_task_type-load
            and status     = @zcl_ret_wh_task=>c_status-open.

        cl_abap_unit_assert=>assert_equals(
          exp = 1
          act = lines( lt_loads )
          msg = 'Pick confirm should auto-create exactly one Load task'
        ).

        data(ls_load) = lt_loads[ 1 ].

        cl_abap_unit_assert=>assert_equals(
          exp = zcl_ret_stock=>c_zone-staging
          act = ls_load-src_zone
          msg = 'Auto-created Load src_zone must be STAGING'
        ).

        cl_abap_unit_assert=>assert_equals(
          exp = zcl_ret_stock=>c_zone-load_dock
          act = ls_load-dst_zone
          msg = 'Auto-created Load dst_zone must be LOAD_DOCK'
        ).

        cl_abap_unit_assert=>assert_equals(
          exp = '40'
          act = ls_load-quantity
          msg = 'Auto-created Load quantity should match Pick quantity'
        ).

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.

  method test_load_confirm_no_chain.
    " GIVEN: 100 PC in STAGING + a Load task
    " WHEN:  confirm Load
    " THEN:  NO new task is created (chain stops at Load)
    try.
        zcl_ret_stock=>load_initial_stock(
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_zone_code  = zcl_ret_stock=>c_zone-staging
          iv_quantity   = '100'
          iv_base_uom   = c_test_uom
        ).

        data(lv_load_num) = zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-load
          iv_article_id = c_test_article
          iv_site_id    = c_test_site
          iv_src_zone   = zcl_ret_stock=>c_zone-staging
          iv_dst_zone   = zcl_ret_stock=>c_zone-load_dock
          iv_quantity   = '40'
          iv_base_uom   = c_test_uom
        ).

        zcl_ret_wh_task=>confirm( lv_load_num ).

        " Verify: zero Open tasks remain for our test article
        data lv_open_count type i.
        select count(*) from zret_t_wh_task
          into @lv_open_count
          where article_id = @c_test_article
            and site_id    = @c_test_site
            and status     = @zcl_ret_wh_task=>c_status-open.

        cl_abap_unit_assert=>assert_equals(
          exp = 0
          act = lv_open_count
          msg = 'Load confirm must NOT create any new task - chain ends at Load'
        ).

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.
endclass.
