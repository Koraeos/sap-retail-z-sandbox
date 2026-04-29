*&---------------------------------------------------------------------*
*& Report ZRET_R_WH_TASK_CONFIRM
*&---------------------------------------------------------------------*
*& Confirms a warehouse task: triggers the stock movement
*& and flips the status from Open to Confirmed.
*&---------------------------------------------------------------------*
report zret_r_wh_task_confirm.

parameters p_task type zret_t_wh_task-wh_task_num obligatory.

class lcl_app definition.
  public section.
    class-methods:
      run
        importing iv_task_num type zret_t_wh_task-wh_task_num.
endclass.

class lcl_app implementation.

  method run.
    write: / '========================================='.
    write: / |  Confirming WH task { iv_task_num }|.
    write: / '========================================='.
    write: /.

    " Read task before confirm
    try.
        data(ls_task_before) = zcl_ret_wh_task=>get_task( iv_task_num ).
      catch zcx_ret_core.
        write: / |ERROR: Task { iv_task_num } not found|.
        return.
    endtry.

    write: / '--- Task before confirm ---'.
    write: / |  Type:     { ls_task_before-task_type }|.
    write: / |  Status:   { ls_task_before-status }|.
    write: / |  Article:  { ls_task_before-article_id }|.
    write: / |  Site:     { ls_task_before-site_id }|.
    write: / |  Move:     { ls_task_before-src_zone } -> { ls_task_before-dst_zone }|.
    write: / |  Quantity: { ls_task_before-quantity } { ls_task_before-base_uom }|.
    write: /.

    " Confirm
    try.
        data(ls_mvt) = zcl_ret_wh_task=>confirm( iv_task_num ).
        write: / |--- Confirm successful ---|.
        write: / |  Stock movement created: mvt_doc { ls_mvt-mvt_doc }|.
      catch zcx_ret_core into data(lo_ex).
        write: / |ERROR during confirm: { lo_ex->get_text( ) }|.
        return.
    endtry.

" Read task after confirm
    data ls_task_after type zret_t_wh_task.
    try.
        ls_task_after = zcl_ret_wh_task=>get_task( iv_task_num ).
      catch zcx_ret_core.
        write: / 'ERROR: task not found after confirm (should not happen)'.
        return.
    endtry.
    write: /.
    write: / '--- Task after confirm ---'.
    write: / |  Status:        { ls_task_after-status } (C = Confirmed)|.
    write: / |  Confirmed by:  { ls_task_after-confirmed_by }|.
    write: / |  Confirmed on:  { ls_task_after-confirmed_on }|.
    write: / |  Linked mvt:    { ls_task_after-mvt_doc }|.
    write: /.

    " Show stock state in DST_ZONE
    write: / |--- Stock now in zone { ls_task_after-dst_zone } ---|.
    data(lv_qty) = zcl_ret_stock=>get_available(
      iv_article_id = ls_task_after-article_id
      iv_site_id    = ls_task_after-site_id
      iv_zone_code  = ls_task_after-dst_zone
    ).
    write: / |  Article { ls_task_after-article_id } @ site { ls_task_after-site_id }: { lv_qty } { ls_task_after-base_uom }|.

    write: /.
    write: / '========================================='.
    write: / '  Done'.
    write: / '========================================='.
  endmethod.

endclass.

start-of-selection.
  lcl_app=>run( p_task ).
