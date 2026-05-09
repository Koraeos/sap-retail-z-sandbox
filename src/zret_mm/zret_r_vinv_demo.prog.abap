report zret_r_vinv_demo.

start-of-selection.

  perform demo_vinv.


form demo_vinv.

  write: / '=================================================='.
  write: / 'Vendor Invoice 3-way match demo'.
  write: / '=================================================='.
  write: /.

  " --- Find the most recent PO that has at least one GR posted ---
  select po_number from zret_t_po
    into @data(lv_po_number)
    up to 1 rows
    where status in ('I', 'D', 'C')   " Open with delivery, fully delivered, or closed
    order by po_number descending.
  endselect.

  if lv_po_number is initial.
    write: / 'No PO found with goods receipt. Run ZRET_R_PO_DEMO first.'.
    return.
  endif.

  write: / |Using PO: { lv_po_number }|.
  write: /.

  " --- Load PO items to know what we can invoice ---
  select * from zret_t_po_item
    into table @data(lt_po_items)
    where po_number = @lv_po_number
    order by item_num ascending.

  if lt_po_items is initial.
    write: / 'PO has no items. Aborting.'.
    return.
  endif.

  data(ls_first_item) = lt_po_items[ 1 ].

  write: / |PO line item used: { ls_first_item-item_num }|.
  write: / |  Article    : { ls_first_item-article_id } - { ls_first_item-article_name }|.
  write: / |  Ordered qty: { ls_first_item-quantity }|.
  write: / |  Delivered  : { ls_first_item-delivered_qty }|.
  write: / |  Unit price : { ls_first_item-unit_price } { ls_first_item-currency }|.
  write: /.

  if ls_first_item-delivered_qty <= 0.
    write: / 'No delivered quantity yet. Run ZRET_R_PO_DEMO first to post a GR.'.
    return.
  endif.

  " --- Scenario 1 : Matching invoice (qty = delivered, price = PO) ---
  write: / '--- Scenario 1: Matching invoice ---'.

  data lt_input1 type zcl_ret_vendor_invoice=>ty_invoice_input_tab.
  append value #(
    po_item_num  = ls_first_item-item_num
    invoiced_qty = ls_first_item-delivered_qty
    " unit_price intentionally left empty -> defaults to PO price -> no mismatch
  ) to lt_input1.

  try.
      data(lv_vinv1) = zcl_ret_vendor_invoice=>create_from_po(
        iv_po_number = lv_po_number
        it_items     = lt_input1 ).

      write: / |  Created vendor invoice { lv_vinv1 }|.

      data(ls_full1) = zcl_ret_vendor_invoice=>get_by_id( lv_vinv1 ).
      write: / |  Header status: { ls_full1-header-status } (M = matched, B = blocked)|.

    catch zcx_ret_core.
      write: / '  ERROR creating matching invoice'.
  endtry.

  write: /.

  " --- Scenario 2 : Mismatching invoice (price diverges from PO) ---
  write: / '--- Scenario 2: Mismatching invoice (price diverges) ---'.

  data lt_input2 type zcl_ret_vendor_invoice=>ty_invoice_input_tab.
  append value #(
    po_item_num  = ls_first_item-item_num
    invoiced_qty = ls_first_item-delivered_qty
    unit_price   = ls_first_item-unit_price + '5.00'   " Supplier overcharges by 5
  ) to lt_input2.

  try.
      data(lv_vinv2) = zcl_ret_vendor_invoice=>create_from_po(
        iv_po_number = lv_po_number
        it_items     = lt_input2 ).

      write: / |  Created vendor invoice { lv_vinv2 }|.

      data(ls_full2) = zcl_ret_vendor_invoice=>get_by_id( lv_vinv2 ).
      write: / |  Header status: { ls_full2-header-status } (should be B = blocked)|.
      write: / |  Block reason : { ls_full2-header-block_reason }|.

    catch zcx_ret_core.
      write: / '  ERROR creating mismatching invoice'.
  endtry.

  write: /.
  write: / '=================================================='.
  write: / 'Demo done.'.
  write: / 'Run ZRET_R_VINV_LIST to see all vendor invoices.'.
  write: / '=================================================='.

endform.
