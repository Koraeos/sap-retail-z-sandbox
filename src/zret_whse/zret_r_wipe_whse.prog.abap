*&---------------------------------------------------------------------*
*& Report ZRET_R_WIPE_WHSE
*&---------------------------------------------------------------------*
*& One-shot wipe of warehouse transactional tables before type refactor
*&---------------------------------------------------------------------*
report zret_r_wipe_whse.

start-of-selection.
  data lv_count type i.

  write: / '========================================='.
  write: / '  Wipe warehouse transactional tables'.
  write: / '========================================='.
  write: /.

  select count(*) from zret_t_wh_task into @lv_count.
  delete from zret_t_wh_task.
  write: / |ZRET_T_WH_TASK   : { lv_count } rows deleted|.

  select count(*) from zret_t_stk_mvt into @lv_count.
  delete from zret_t_stk_mvt.
  write: / |ZRET_T_STK_MVT   : { lv_count } rows deleted|.

  select count(*) from zret_t_stock into @lv_count.
  delete from zret_t_stock.
  write: / |ZRET_T_STOCK     : { lv_count } rows deleted|.

  select count(*) from zret_t_po_item into @lv_count.
  delete from zret_t_po_item.
  write: / |ZRET_T_PO_ITEM   : { lv_count } rows deleted|.

  select count(*) from zret_t_po into @lv_count.
  delete from zret_t_po.
  write: / |ZRET_T_PO        : { lv_count } rows deleted|.

  commit work and wait.

  write: /.
  write: / 'Done. Tables ready for type refactor.'.
