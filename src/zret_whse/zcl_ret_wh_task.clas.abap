class zcl_ret_wh_task definition
  public
  final
  create public.

  public section.
    constants:
      begin of c_task_type,
        putaway type zret_de_wh_task_type value 'PUTAWAY',
        pick    type zret_de_wh_task_type value 'PICK',
        load    type zret_de_wh_task_type value 'LOAD',
      end of c_task_type.

    constants:
      begin of c_status,
        open      type zret_de_wh_task_stat value 'O',
        confirmed type zret_de_wh_task_stat value 'C',
        cancelled type zret_de_wh_task_stat value 'X',
      end of c_status.

    types:
      tt_wh_tasks type standard table of zret_t_wh_task with empty key.

    class-methods:
      "! Create a warehouse task in status Open
      create_task
        importing
          iv_task_type     type zret_de_wh_task_type
          iv_article_id    type zret_t_wh_task-article_id
          iv_site_id       type zret_t_wh_task-site_id
          iv_src_zone      type zret_de_whse_zone
          iv_dst_zone      type zret_de_whse_zone
          iv_quantity      type zret_t_wh_task-quantity
          iv_base_uom      type zret_t_wh_task-base_uom
          iv_ref_doc_type  type zret_t_wh_task-ref_doc_type default ''
          iv_ref_doc_num   type zret_t_wh_task-ref_doc_num default ''
          iv_ref_doc_item  type zret_t_wh_task-ref_doc_item default '0000'
        returning
          value(rv_task_num) type zret_t_wh_task-wh_task_num
        raising
          zcx_ret_core,

      "! Confirm a task: triggers stock movement + updates status
      confirm
        importing
          iv_task_num   type zret_t_wh_task-wh_task_num
        returning
          value(rs_mvt) type zcl_ret_stock=>ts_mvt_result
        raising
          zcx_ret_core,

      "! Cancel a task (only allowed if status = Open)
      cancel
        importing
          iv_task_num type zret_t_wh_task-wh_task_num
        raising
          zcx_ret_core,

      "! Read a single task
      get_task
        importing
          iv_task_num    type zret_t_wh_task-wh_task_num
        returning
          value(rs_task) type zret_t_wh_task
        raising
          zcx_ret_core,

      "! List open tasks (optionally filtered by type)
      get_open_tasks
        importing
          iv_task_type    type zret_de_wh_task_type optional
        returning
          value(rt_tasks) type tt_wh_tasks.

  private section.
    class-methods:
      get_next_task_num
        returning value(rv_num) type zret_t_wh_task-wh_task_num,

      map_task_type_to_mvt_type
        importing
          iv_task_type type zret_de_wh_task_type
        returning
          value(rv_mvt) type zret_de_mvt_type
        raising
          zcx_ret_core.

ENDCLASS.



CLASS ZCL_RET_WH_TASK IMPLEMENTATION.


  method cancel.
    " Cancel only if status = Open
    data ls_task type zret_t_wh_task.

    select single * from zret_t_wh_task
      into @ls_task
      where wh_task_num = @iv_task_num.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    if ls_task-status <> c_status-open.
      raise exception type zcx_ret_core.
    endif.

    ls_task-status       = c_status-cancelled.
    ls_task-cancelled_by = sy-uname.
    ls_task-cancelled_on = sy-datum.

    update zret_t_wh_task from ls_task.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.


method confirm.
    " Confirmation: post stock movement + flip status to Confirmed.
    " Pick confirm auto-chains a Load task (own LUW).
    data ls_task         type zret_t_wh_task.
    data lv_mvt_type     type zret_de_mvt_type.
    data lv_ref_doc_type type zret_t_stk_mvt-ref_doc_type.
    data lv_ref_doc_num  type zret_t_stk_mvt-ref_doc_num.
    data lv_ref_doc_item type zret_t_stk_mvt-ref_doc_item.
    data lv_task_as_char type zret_t_stk_mvt-ref_doc_num.

    select single * from zret_t_wh_task
      into @ls_task
      where wh_task_num = @iv_task_num.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    if ls_task-status <> c_status-open.
      raise exception type zcx_ret_core.
    endif.

    lv_mvt_type = map_task_type_to_mvt_type( ls_task-task_type ).

    " Build movement reference: prefer the task's original doc, fallback to task itself
    if ls_task-ref_doc_type is not initial.
      lv_ref_doc_type = ls_task-ref_doc_type.
      lv_ref_doc_num  = ls_task-ref_doc_num.
      lv_ref_doc_item = ls_task-ref_doc_item.
    else.
      lv_task_as_char = iv_task_num.
      lv_ref_doc_type = 'WH_TASK'.
      lv_ref_doc_num  = lv_task_as_char.
      lv_ref_doc_item = '0001'.
    endif.

    " 1. Post stock movement (own LUW, autonomous)
    rs_mvt = zcl_ret_stock=>post_movement(
      iv_mvt_type     = lv_mvt_type
      iv_article_id   = ls_task-article_id
      iv_site_id      = ls_task-site_id
      iv_src_zone     = ls_task-src_zone
      iv_dst_zone     = ls_task-dst_zone
      iv_quantity     = ls_task-quantity
      iv_base_uom     = ls_task-base_uom
      iv_ref_doc_type = lv_ref_doc_type
      iv_ref_doc_num  = lv_ref_doc_num
      iv_ref_doc_item = lv_ref_doc_item
    ).

    " 2. Flip task status (own LUW)
    ls_task-status       = c_status-confirmed.
    ls_task-mvt_doc      = rs_mvt-mvt_doc.
    ls_task-confirmed_by = sy-uname.
    ls_task-confirmed_on = sy-datum.

    update zret_t_wh_task from ls_task.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.

    " 3. Auto-chain: if Pick confirmed, create the next Load task
    "    Preserves the original ref_doc for end-to-end traceability.
    if ls_task-task_type = c_task_type-pick.
      create_task(
        iv_task_type    = c_task_type-load
        iv_article_id   = ls_task-article_id
        iv_site_id      = ls_task-site_id
        iv_src_zone     = zcl_ret_stock=>c_zone-staging
        iv_dst_zone     = zcl_ret_stock=>c_zone-load_dock
        iv_quantity     = ls_task-quantity
        iv_base_uom     = ls_task-base_uom
        iv_ref_doc_type = ls_task-ref_doc_type
        iv_ref_doc_num  = ls_task-ref_doc_num
        iv_ref_doc_item = ls_task-ref_doc_item
      ).
    endif.
  endmethod.


  method create_task.
    " Create a new warehouse task in status Open (atomic LUW)
    data ls_task type zret_t_wh_task.

    if iv_quantity <= 0.
      raise exception type zcx_ret_core.
    endif.

    if iv_src_zone is initial or iv_dst_zone is initial.
      raise exception type zcx_ret_core.
    endif.

    rv_task_num = get_next_task_num( ).

    ls_task-client       = sy-mandt.
    ls_task-wh_task_num  = rv_task_num.
    ls_task-task_type    = iv_task_type.
    ls_task-status       = c_status-open.
    ls_task-article_id   = iv_article_id.
    ls_task-site_id      = iv_site_id.
    ls_task-src_zone     = iv_src_zone.
    ls_task-dst_zone     = iv_dst_zone.
    ls_task-quantity     = iv_quantity.
    ls_task-base_uom     = iv_base_uom.
    ls_task-ref_doc_type = iv_ref_doc_type.
    ls_task-ref_doc_num  = iv_ref_doc_num.
    ls_task-ref_doc_item = iv_ref_doc_item.
    ls_task-created_by   = sy-uname.
    ls_task-created_on   = sy-datum.

    insert zret_t_wh_task from ls_task.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.


  method get_next_task_num.
    select max( wh_task_num )
      from zret_t_wh_task
      into @data(lv_max).

    if lv_max is initial.
      rv_num = '0000000001'.
    else.
      rv_num = lv_max + 1.
    endif.
  endmethod.


  method get_open_tasks.
    if iv_task_type is initial.
      select * from zret_t_wh_task
        into table @rt_tasks
        where status = @c_status-open
        order by wh_task_num.
    else.
      select * from zret_t_wh_task
        into table @rt_tasks
        where status    = @c_status-open
          and task_type = @iv_task_type
        order by wh_task_num.
    endif.
  endmethod.


  method get_task.
    select single * from zret_t_wh_task
      into @rs_task
      where wh_task_num = @iv_task_num.

    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.
  endmethod.


  method map_task_type_to_mvt_type.
    " PUTAWAY → 311 (transfer between zones)
    " PICK    → 411
    " LOAD    → 412
    case iv_task_type.
      when c_task_type-putaway.
        rv_mvt = zcl_ret_stock=>c_mvt_type-transfer.
      when c_task_type-pick.
        rv_mvt = zcl_ret_stock=>c_mvt_type-pick.
      when c_task_type-load.
        rv_mvt = zcl_ret_stock=>c_mvt_type-loading.
      when others.
        raise exception type zcx_ret_core.
    endcase.
  endmethod.
ENDCLASS.
