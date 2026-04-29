*&---------------------------------------------------------------------*
*& Report ZRET_R_OUTBOUND_DEMO
*&---------------------------------------------------------------------*
*& End-to-end demo of the outbound warehouse flow:
*&   STORAGE -> Pick -> STAGING -> Load -> LOAD_DOCK -> Goods Issue -> out
*&---------------------------------------------------------------------*
report zret_r_outbound_demo.

class lcl_demo definition.
  public section.
    class-methods:
      run_demo.

  private section.
    class-methods:
      show_stock_zones
        importing
          iv_article type zret_t_stock-article_id
          iv_site    type zret_t_stock-site_id.
endclass.

class lcl_demo implementation.

  method run_demo.
    constants:
      lc_article type zret_t_stock-article_id value 'ART001',
      lc_site    type zret_t_stock-site_id    value 'WH01',
      lc_qty     type zret_t_wh_task-quantity value '30',
      lc_uom     type zret_t_wh_task-base_uom value 'PC'.

    write: / '========================================='.
    write: / '  Outbound Demo: Pick -> Load -> GI'.
    write: / '========================================='.

    write: /.
    write: / '--- Initial state ---'.
    show_stock_zones( iv_article = lc_article iv_site = lc_site ).

    try.
        write: /.
        write: / '--- Step 1: Create Pick task (STORAGE -> STAGING) ---'.
        data(lv_pick_num) = zcl_ret_wh_task=>create_task(
          iv_task_type  = zcl_ret_wh_task=>c_task_type-pick
          iv_article_id = lc_article
          iv_site_id    = lc_site
          iv_src_zone   = zcl_ret_stock=>c_zone-storage
          iv_dst_zone   = zcl_ret_stock=>c_zone-staging
          iv_quantity   = lc_qty
          iv_base_uom   = lc_uom
        ).
        write: / |Pick task created: { lv_pick_num } (status Open)|.

        write: /.
        write: / '--- Step 2: Confirm Pick (auto-creates Load task) ---'.
        data(ls_mvt_pick) = zcl_ret_wh_task=>confirm( lv_pick_num ).
        write: / |Pick confirmed: mvt_doc { ls_mvt_pick-mvt_doc } (type 411)|.
        show_stock_zones( iv_article = lc_article iv_site = lc_site ).

        " Get the auto-created Load task
        data lt_open_loads type zcl_ret_wh_task=>tt_wh_tasks.
        lt_open_loads = zcl_ret_wh_task=>get_open_tasks( zcl_ret_wh_task=>c_task_type-load ).
        if lt_open_loads is initial.
          write: / 'ERROR: No Load task auto-created!'.
          return.
        endif.
        data(ls_load) = lt_open_loads[ lines( lt_open_loads ) ].
        write: / |Auto-created Load task: { ls_load-wh_task_num } (status Open)|.

        write: /.
        write: / '--- Step 3: Confirm Load (STAGING -> LOAD_DOCK) ---'.
        data(ls_mvt_load) = zcl_ret_wh_task=>confirm( ls_load-wh_task_num ).
        write: / |Load confirmed: mvt_doc { ls_mvt_load-mvt_doc } (type 412)|.
        show_stock_zones( iv_article = lc_article iv_site = lc_site ).

        write: /.
        write: / '--- Step 4: Goods Issue (LOAD_DOCK -> out of system) ---'.
        data(ls_mvt_gi) = zcl_ret_stock=>post_movement(
          iv_mvt_type     = zcl_ret_stock=>c_mvt_type-gi
          iv_article_id   = lc_article
          iv_site_id      = lc_site
          iv_src_zone     = zcl_ret_stock=>c_zone-load_dock
          iv_quantity     = lc_qty
          iv_base_uom     = lc_uom
          iv_ref_doc_type = zcl_ret_stock=>c_ref_doc-out_deliv
          iv_ref_doc_num  = '0000000099'
          iv_ref_doc_item = '0001'
        ).
        write: / |Goods Issue posted: mvt_doc { ls_mvt_gi-mvt_doc } (type 601)|.

        write: /.
        write: / '--- Final state ---'.
        show_stock_zones( iv_article = lc_article iv_site = lc_site ).

      catch zcx_ret_core into data(lo_ex).
        write: / |ERROR: { lo_ex->get_text( ) }|.
    endtry.

    write: /.
    write: / '========================================='.
    write: / '  Done'.
    write: / '========================================='.
  endmethod.

  method show_stock_zones.
    data(lv_recv)      = zcl_ret_stock=>get_available(
      iv_article_id = iv_article
      iv_site_id    = iv_site
      iv_zone_code  = zcl_ret_stock=>c_zone-recv
    ).
    data(lv_storage)   = zcl_ret_stock=>get_available(
      iv_article_id = iv_article
      iv_site_id    = iv_site
      iv_zone_code  = zcl_ret_stock=>c_zone-storage
    ).
    data(lv_staging)   = zcl_ret_stock=>get_available(
      iv_article_id = iv_article
      iv_site_id    = iv_site
      iv_zone_code  = zcl_ret_stock=>c_zone-staging
    ).
    data(lv_load_dock) = zcl_ret_stock=>get_available(
      iv_article_id = iv_article
      iv_site_id    = iv_site
      iv_zone_code  = zcl_ret_stock=>c_zone-load_dock
    ).

    write: / |  Article { iv_article } @ site { iv_site }:|.
    write: / |    RECV:      { lv_recv } PC|.
    write: / |    STORAGE:   { lv_storage } PC|.
    write: / |    STAGING:   { lv_staging } PC|.
    write: / |    LOAD_DOCK: { lv_load_dock } PC|.
  endmethod.

endclass.

start-of-selection.
  lcl_demo=>run_demo( ).
