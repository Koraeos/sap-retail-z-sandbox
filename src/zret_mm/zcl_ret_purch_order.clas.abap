class zcl_ret_purch_order definition
  public
  final
  create public.

  public section.
    constants:
      begin of c_status,
        open      type zret_de_po_status value 'O',
        in_deliv  type zret_de_po_status value 'I',
        delivered type zret_de_po_status value 'D',
        closed    type zret_de_po_status value 'C',
        cancelled type zret_de_po_status value 'X',
      end of c_status.

    types:
      begin of ts_po_item_in,
        article_id type zret_t_po_item-article_id,
        quantity   type zret_t_po_item-quantity,
        base_uom   type zret_t_po_item-base_uom,
        unit_price type zret_t_po_item-unit_price,
      end of ts_po_item_in,

      tt_po_items_in type standard table of ts_po_item_in with empty key,

      tt_po_items    type standard table of zret_t_po_item with empty key.

    class-methods:
      "! Create a PO header + items in one atomic LUW
      create_po
        importing
          iv_supplier_id   type zret_t_po-supplier_id
          iv_supplier_name type zret_t_po-supplier_name
          iv_site_id       type zret_t_po-site_id
          iv_currency      type zret_t_po-currency default 'EUR'
          it_items         type tt_po_items_in
        returning
          value(rv_po_num) type zret_t_po-po_number
        raising
          zcx_ret_core,

      "! Post goods receipt: triggers stock mvt 101 + updates PO
      post_goods_receipt
        importing
          iv_po_number    type zret_t_po-po_number
          iv_item_num     type zret_t_po_item-item_num
          iv_qty_received type zret_t_po_item-quantity
        returning
          value(rs_mvt)   type zcl_ret_stock=>ts_mvt_result
        raising
          zcx_ret_core,

      "! Get PO header
      get_header
        importing
          iv_po_number     type zret_t_po-po_number
        returning
          value(rs_header) type zret_t_po
        raising
          zcx_ret_core,

      "! Get PO items
      get_items
        importing
          iv_po_number    type zret_t_po-po_number
        returning
          value(rt_items) type tt_po_items,

      "! Update PO status
      update_status
        importing
          iv_po_number  type zret_t_po-po_number
          iv_new_status type zret_de_po_status
        raising
          zcx_ret_core,

      "! Cancel a PO (only if status = O)
      cancel_po
        importing
          iv_po_number type zret_t_po-po_number
        raising
          zcx_ret_core.

  private section.
    class-methods:
      get_next_po_number
        returning value(rv_po_num) type zret_t_po-po_number,

      lookup_article_name
        importing iv_article_id  type zret_t_po_item-article_id
        returning value(rv_name) type zret_t_po_item-article_name,

      check_full_delivery
        importing iv_po_number     type zret_t_po-po_number
        returning value(rv_full)   type abap_bool.

ENDCLASS.



CLASS ZCL_RET_PURCH_ORDER IMPLEMENTATION.


  method cancel_po.
    " Cancellation only allowed if status = open (no GR yet)
    data ls_po type zret_t_po.

    select single * from zret_t_po
      into @ls_po
      where po_number = @iv_po_number.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    if ls_po-status <> c_status-open.
      raise exception type zcx_ret_core.
    endif.

    ls_po-status     = c_status-cancelled.
    ls_po-changed_by = sy-uname.
    ls_po-changed_on = sy-datum.

    update zret_t_po from ls_po.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.


method check_full_delivery.
    " Returns abap_true if all items have delivered_qty >= quantity
    data lv_pending type i.

    select count(*)
      from zret_t_po_item as itm
      into @lv_pending
      where itm~po_number     = @iv_po_number
        and itm~delivered_qty < itm~quantity.

    if lv_pending = 0.
      rv_full = abap_true.
    else.
      rv_full = abap_false.
    endif.
  endmethod.


  method create_po.
    " Create PO header + items in one atomic LUW
    data ls_po       type zret_t_po.
    data ls_po_item  type zret_t_po_item.
    data lv_item_num type zret_t_po_item-item_num.
    data lv_total    type zret_t_po-total_amount.

    if it_items is initial.
      raise exception type zcx_ret_core.
    endif.

    try.
        rv_po_num = get_next_po_number( ).

        ls_po-client        = sy-mandt.
        ls_po-po_number     = rv_po_num.
        ls_po-po_date       = sy-datum.
        ls_po-supplier_id   = iv_supplier_id.
        ls_po-supplier_name = iv_supplier_name.
        ls_po-site_id       = iv_site_id.
        ls_po-status        = c_status-open.
        ls_po-currency      = iv_currency.
        ls_po-created_by    = sy-uname.
        ls_po-created_on    = sy-datum.
        ls_po-changed_by    = sy-uname.
        ls_po-changed_on    = sy-datum.

        lv_item_num = '0000'.
        loop at it_items into data(ls_in).
          lv_item_num = lv_item_num + 1.

          if ls_in-quantity <= 0 or ls_in-unit_price < 0.
            raise exception type zcx_ret_core.
          endif.

          ls_po_item-client        = sy-mandt.
          ls_po_item-po_number     = rv_po_num.
          ls_po_item-item_num      = lv_item_num.
          ls_po_item-article_id    = ls_in-article_id.
          ls_po_item-article_name  = lookup_article_name( ls_in-article_id ).
          ls_po_item-quantity      = ls_in-quantity.
          ls_po_item-base_uom      = ls_in-base_uom.
          ls_po_item-unit_price    = ls_in-unit_price.
          ls_po_item-line_amount   = ls_in-quantity * ls_in-unit_price.
          ls_po_item-currency      = iv_currency.
          ls_po_item-delivered_qty = 0.

          insert zret_t_po_item from ls_po_item.
          if sy-subrc <> 0.
            raise exception type zcx_ret_core.
          endif.

          lv_total = lv_total + ls_po_item-line_amount.
        endloop.

        ls_po-total_amount = lv_total.
        insert zret_t_po from ls_po.
        if sy-subrc <> 0.
          raise exception type zcx_ret_core.
        endif.

        commit work and wait.

      catch zcx_ret_core into data(lo_ex).
        rollback work.
        raise exception lo_ex.
    endtry.
  endmethod.


  method get_header.
    select single * from zret_t_po
      into @rs_header
      where po_number = @iv_po_number.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.
  endmethod.


  method get_items.
    select * from zret_t_po_item
      into table @rt_items
      where po_number = @iv_po_number
      order by item_num.
  endmethod.


  method get_next_po_number.
    select max( po_number )
      from zret_t_po
      into @data(lv_max).

    if lv_max is initial.
      rv_po_num = '0000000001'.
    else.
      rv_po_num = lv_max + 1.
    endif.
  endmethod.


  method lookup_article_name.
    " Snapshot article name at PO creation time
    select single article_name
      from zret_t_article
      into @rv_name
      where article_id = @iv_article_id.

    if sy-subrc <> 0.
      rv_name = ''.
    endif.
  endmethod.


method post_goods_receipt.
    " Goods receipt = stock mvt 101 (zone RECV) + update PO + auto-create Putaway WHT
    data ls_item type zret_t_po_item.
    data ls_po   type zret_t_po.

    if iv_qty_received <= 0.
      raise exception type zcx_ret_core.
    endif.

    " Read header
    select single * from zret_t_po
      into @ls_po
      where po_number = @iv_po_number.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    if ls_po-status <> c_status-open and
       ls_po-status <> c_status-in_deliv.
      raise exception type zcx_ret_core.
    endif.

    " Read item
    select single * from zret_t_po_item
      into @ls_item
      where po_number = @iv_po_number
        and item_num  = @iv_item_num.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    " Refuse over-delivery
    data(lv_remaining) = ls_item-quantity - ls_item-delivered_qty.
    if iv_qty_received > lv_remaining.
      raise exception type zcx_ret_core.
    endif.

    " ============================================================
    " 1. Stock movement 101 → RECV zone (own LUW, autonomous)
    " ============================================================
    data lv_ref_num type zret_t_stk_mvt-ref_doc_num.
    lv_ref_num = iv_po_number.

    rs_mvt = zcl_ret_stock=>post_movement(
      iv_mvt_type     = zcl_ret_stock=>c_mvt_type-gr
      iv_article_id   = ls_item-article_id
      iv_site_id      = ls_po-site_id
      iv_dst_zone     = zcl_ret_stock=>c_zone-recv
      iv_quantity     = iv_qty_received
      iv_base_uom     = ls_item-base_uom
      iv_ref_doc_type = zcl_ret_stock=>c_ref_doc-po
      iv_ref_doc_num  = lv_ref_num
      iv_ref_doc_item = iv_item_num
    ).

    " ============================================================
    " 2. Update PO item + header (own LUW)
    " ============================================================
    try.
        ls_item-delivered_qty = ls_item-delivered_qty + iv_qty_received.
        update zret_t_po_item from ls_item.
        if sy-subrc <> 0.
          raise exception type zcx_ret_core.
        endif.

        if check_full_delivery( iv_po_number ) = abap_true.
          ls_po-status = c_status-delivered.
        else.
          ls_po-status = c_status-in_deliv.
        endif.
        ls_po-changed_by = sy-uname.
        ls_po-changed_on = sy-datum.

        update zret_t_po from ls_po.
        if sy-subrc <> 0.
          raise exception type zcx_ret_core.
        endif.

        commit work and wait.

      catch zcx_ret_core into data(lo_ex).
        rollback work.
        raise exception lo_ex.
    endtry.

    " ============================================================
    " 3. Auto-create Putaway warehouse task (RECV → STORAGE)
    "    Own LUW. The task remains Open until a worker confirms it.
    " ============================================================
    data lv_ref_num_task type zret_t_wh_task-ref_doc_num.
    lv_ref_num_task = iv_po_number.

    zcl_ret_wh_task=>create_task(
      iv_task_type    = zcl_ret_wh_task=>c_task_type-putaway
      iv_article_id   = ls_item-article_id
      iv_site_id      = ls_po-site_id
      iv_src_zone     = zcl_ret_stock=>c_zone-recv
      iv_dst_zone     = zcl_ret_stock=>c_zone-storage
      iv_quantity     = iv_qty_received
      iv_base_uom     = ls_item-base_uom
      iv_ref_doc_type = zcl_ret_stock=>c_ref_doc-po
      iv_ref_doc_num  = lv_ref_num_task
      iv_ref_doc_item = iv_item_num
    ).
  endmethod.


  method update_status.
    " Manual status update (e.g. close PO)
    data ls_po type zret_t_po.

    select single * from zret_t_po
      into @ls_po
      where po_number = @iv_po_number.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    ls_po-status     = iv_new_status.
    ls_po-changed_by = sy-uname.
    ls_po-changed_on = sy-datum.

    update zret_t_po from ls_po.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.
ENDCLASS.
