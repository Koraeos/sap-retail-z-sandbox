class zcl_ret_vendor_invoice definition
  public final create public.

  public section.

    " === Types ===

    types:
      begin of ty_invoice_input,
        po_item_num  type zret_t_po_item-item_num,
        invoiced_qty type zret_t_po_item-quantity,
        unit_price   type zret_t_po_item-unit_price,
      end of ty_invoice_input.

    types ty_invoice_input_tab type standard table of ty_invoice_input
                                with default key.

    types ty_item_tab type standard table of zret_t_vinv_item
                        with default key.

    types:
      begin of ty_full,
        header type zret_t_vinv,
        items  type ty_item_tab,
      end of ty_full.

    types ty_vinv_tab     type standard table of zret_t_vinv with default key.
    types ty_status_range type range of zret_t_vinv-status.
    types ty_supplier_range type range of zret_t_vinv-supplier_id.

    " === Constants ===

    constants:
      begin of c_status,
        open    type zret_t_vinv-status value 'O',
        matched type zret_t_vinv-status value 'M',
        blocked type zret_t_vinv-status value 'B',
        paid    type zret_t_vinv-status value 'P',
        voided  type zret_t_vinv-status value 'V',
      end of c_status.

    constants:
      begin of c_match,
        ok             type c length 1 value 'M',
        qty_mismatch   type c length 1 value 'Q',
        price_mismatch type c length 1 value 'P',
      end of c_match.

    " === Public methods ===

    class-methods create_from_po
      importing
        iv_po_number          type zret_t_po-po_number
        it_items              type ty_invoice_input_tab
      returning
        value(rv_vinv_number) type zret_t_vinv-vinv_number
      raising
        zcx_ret_core.

    class-methods get_by_id
      importing
        iv_vinv_number type zret_t_vinv-vinv_number
      returning
        value(rs_full) type ty_full
      raising
        zcx_ret_core.

    class-methods select_all
      importing
        it_status_range   type ty_status_range   optional
        it_supplier_range type ty_supplier_range optional
      returning
        value(rt_vinv) type ty_vinv_tab.

    class-methods unblock
      importing
        iv_vinv_number type zret_t_vinv-vinv_number
      raising
        zcx_ret_core.

  private section.

    class-methods generate_vinv_number
      returning value(rv_vinv_number) type zret_t_vinv-vinv_number.

    class-methods compute_received_qty
      importing
        iv_po_number   type zret_t_po-po_number
        iv_po_item_num type zret_t_po_item-item_num
      returning
        value(rv_qty)  type zret_t_po_item-quantity.

endclass.


class zcl_ret_vendor_invoice implementation.

  method create_from_po.

    " --- 1. Load PO header ---
    select single * from zret_t_po
      into @data(ls_po)
      where po_number = @iv_po_number.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    " Validate PO status (must not be Voided)
    if ls_po-status = 'V'.
      raise exception type zcx_ret_core.
    endif.

    " --- 2. Generate VINV number ---
    rv_vinv_number = generate_vinv_number( ).

    " --- 3. Process input items + perform 3-way match per line ---
    data: lt_items_db   type ty_item_tab,
          ls_item_db    type zret_t_vinv_item,
          lv_total      type p length 8 decimals 2,
          lv_item_num   type n length 4 value '0010',
          lv_all_match  type abap_bool value abap_true,
          lv_block_msg  type string.

    loop at it_items into data(ls_input).

      " Find corresponding PO item
      select single * from zret_t_po_item
        into @data(ls_po_item)
        where po_number = @iv_po_number
          and item_num  = @ls_input-po_item_num.
      if sy-subrc <> 0.
        raise exception type zcx_ret_core.
      endif.

      " Get GR cumulative quantity for this PO line
      data(lv_gr_qty) = compute_received_qty(
        iv_po_number   = iv_po_number
        iv_po_item_num = ls_input-po_item_num ).

      " Determine effective unit price (input or default to PO price)
      data(lv_unit_price_used) = ls_input-unit_price.
      if lv_unit_price_used is initial.
        lv_unit_price_used = ls_po_item-unit_price.
      endif.

      " --- 3-way match logic ---
      data(lv_match_status) = c_match-ok.

      " Check 1: invoiced qty must not exceed received qty
      if ls_input-invoiced_qty > lv_gr_qty.
        lv_match_status = c_match-qty_mismatch.
        lv_all_match    = abap_false.
        if lv_block_msg is initial.
          lv_block_msg = |Item { ls_input-po_item_num }: invoiced { ls_input-invoiced_qty } > received { lv_gr_qty }|.
        endif.
      endif.

      " Check 2: invoiced unit price must match PO price (only if explicitly provided)
      if ls_input-unit_price is not initial
         and ls_input-unit_price <> ls_po_item-unit_price.
        if lv_match_status = c_match-ok.
          lv_match_status = c_match-price_mismatch.
        endif.
        lv_all_match = abap_false.
        if lv_block_msg is initial.
          lv_block_msg = |Item { ls_input-po_item_num }: price { ls_input-unit_price } <> PO price { ls_po_item-unit_price }|.
        endif.
      endif.

      " Build invoice line with full snapshot
      clear ls_item_db.
      ls_item_db-client       = sy-mandt.
      ls_item_db-vinv_number  = rv_vinv_number.
      ls_item_db-item_num     = lv_item_num.
      ls_item_db-po_number    = iv_po_number.
      ls_item_db-po_item_num  = ls_input-po_item_num.
      ls_item_db-article_id   = ls_po_item-article_id.
      ls_item_db-article_name = ls_po_item-article_name.
      ls_item_db-invoiced_qty = ls_input-invoiced_qty.
      ls_item_db-base_uom     = ls_po_item-base_uom.
      ls_item_db-unit_price   = lv_unit_price_used.
      ls_item_db-line_amount  = ls_input-invoiced_qty * lv_unit_price_used.
      ls_item_db-currency     = ls_po_item-currency.
      " Audit snapshot of values used in the 3-way match
      ls_item_db-po_qty       = ls_po_item-quantity.
      ls_item_db-gr_qty       = lv_gr_qty.
      ls_item_db-po_price     = ls_po_item-unit_price.
      ls_item_db-match_status = lv_match_status.

      append ls_item_db to lt_items_db.
      lv_total    = lv_total + ls_item_db-line_amount.
      lv_item_num = lv_item_num + 10.

    endloop.

    " --- 4. Build header ---
    data ls_header type zret_t_vinv.
    ls_header-client        = sy-mandt.
    ls_header-vinv_number   = rv_vinv_number.
    ls_header-vinv_date     = sy-datum.
    ls_header-po_number     = iv_po_number.
    ls_header-supplier_id   = ls_po-supplier_id.
    ls_header-supplier_name = ls_po-supplier_name.
    ls_header-total_amount  = lv_total.
    ls_header-currency      = ls_po-currency.

    if lv_all_match = abap_true.
      ls_header-status = c_status-matched.
    else.
      ls_header-status       = c_status-blocked.
      ls_header-block_reason = lv_block_msg.
    endif.

    ls_header-created_by = sy-uname.
    ls_header-created_on = sy-datum.
    ls_header-changed_by = sy-uname.
    ls_header-changed_on = sy-datum.

    " --- 5. Persist atomically ---
    insert zret_t_vinv from @ls_header.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    insert zret_t_vinv_item from table @lt_items_db.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work.
  endmethod.


  method get_by_id.
    select single * from zret_t_vinv
      into @rs_full-header
      where vinv_number = @iv_vinv_number.

    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    select * from zret_t_vinv_item
      into table @rs_full-items
      where vinv_number = @iv_vinv_number
      order by item_num ascending.
  endmethod.


  method select_all.
    select * from zret_t_vinv
      into table @rt_vinv
      where status      in @it_status_range
        and supplier_id in @it_supplier_range
      order by vinv_number ascending.
  endmethod.


  method unblock.
    " Validate the invoice exists and is currently blocked
    select single status from zret_t_vinv
      into @data(lv_status)
      where vinv_number = @iv_vinv_number.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    if lv_status <> c_status-blocked.
      raise exception type zcx_ret_core.
    endif.

    " Transition B -> O (open for payment)
    update zret_t_vinv
      set status     = @c_status-open,
          changed_by = @sy-uname,
          changed_on = @sy-datum
      where vinv_number = @iv_vinv_number.

    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    commit work.
  endmethod.


  method generate_vinv_number.
    data: lv_max_vinv type zret_t_vinv-vinv_number,
          lv_new_num  type i.

    select max( vinv_number )
      from zret_t_vinv
      into @lv_max_vinv.

    if lv_max_vinv is initial.
      lv_new_num = 1.
    else.
      lv_new_num = lv_max_vinv + 1.
    endif.

    rv_vinv_number = |{ lv_new_num width = 10 pad = '0' align = right }|.
  endmethod.


  method compute_received_qty.
    " Read the cumulative delivered quantity directly from the PO item.
    " ZRET_T_PO_ITEM.delivered_qty is maintained by post_goods_receipt
    " every time a GR is posted, so it always reflects the up-to-date received qty.
    " Alternative would be to SUM zret_t_stk_mvt entries with mvt_type=101 and
    " ref_doc=PO — equivalent result, but reading the pre-aggregated value is simpler.
    select single delivered_qty
      from zret_t_po_item
      into @rv_qty
      where po_number = @iv_po_number
        and item_num  = @iv_po_item_num.
  endmethod.

endclass.
