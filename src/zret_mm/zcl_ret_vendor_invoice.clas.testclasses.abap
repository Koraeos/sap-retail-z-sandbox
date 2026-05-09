class ltc_vendor_invoice definition deferred.
class zcl_ret_vendor_invoice definition local friends ltc_vendor_invoice.

class ltc_vendor_invoice definition for testing
  duration short
  risk level harmless.

  private section.

    constants:
      c_test_po type zret_t_po-po_number value '9999999999'.

    methods:
      setup,
      teardown,
      cleanup_test_data,
      create_test_po,

      test_match_ok          for testing,
      test_qty_mismatch      for testing,
      test_price_mismatch    for testing,
      test_invalid_po        for testing,
      test_unblock_then_open for testing.

endclass.


class ltc_vendor_invoice implementation.

  method setup.
    cleanup_test_data( ).
    create_test_po( ).
  endmethod.

  method teardown.
    cleanup_test_data( ).
  endmethod.

method cleanup_test_data.
    " Delete vendor invoices items + headers linked to test PO
    delete from zret_t_vinv_item where po_number = @c_test_po.
    delete from zret_t_vinv      where po_number = @c_test_po.

    " Delete test PO
    delete from zret_t_po_item where po_number = @c_test_po.
    delete from zret_t_po      where po_number = @c_test_po.

    commit work and wait.
  endmethod.

  method create_test_po.
    " Create a test PO with 1 line item already partially delivered (80 / 100)
    insert zret_t_po from @( value zret_t_po(
      client        = sy-mandt
      po_number     = c_test_po
      po_date       = sy-datum
      supplier_id   = 'SUP001'
      supplier_name = 'Test Supplier'
      site_id       = 'WH01'
      status        = 'I'
      total_amount  = '1000.00'
      currency      = 'EUR'
      created_by    = sy-uname
      created_on    = sy-datum
      changed_by    = sy-uname
      changed_on    = sy-datum
    ) ).

    insert zret_t_po_item from @( value zret_t_po_item(
      client        = sy-mandt
      po_number     = c_test_po
      item_num      = '0001'
      article_id    = 'ART001'
      article_name  = 'Test Article'
      quantity      = '100.000'
      base_uom      = 'PC'
      unit_price    = '10.00'
      line_amount   = '1000.00'
      currency      = 'EUR'
      delivered_qty = '80.000'
    ) ).

    commit work and wait.
  endmethod.


  method test_match_ok.
    " Given : test PO with 80 delivered, price 10
    " When : invoice 80 without overriding price
    data lt_input type zcl_ret_vendor_invoice=>ty_invoice_input_tab.
    append value #(
      po_item_num  = '0001'
      invoiced_qty = '80.000'
    ) to lt_input.

    data lv_vinv type zret_t_vinv-vinv_number.
    try.
        lv_vinv = zcl_ret_vendor_invoice=>create_from_po(
          iv_po_number = c_test_po
          it_items     = lt_input ).
      catch zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Should not raise on matching invoice' ).
    endtry.

    " Then : header status = M
    select single status from zret_t_vinv
      into @data(lv_status)
      where vinv_number = @lv_vinv.

    cl_abap_unit_assert=>assert_equals(
      exp = 'M'
      act = lv_status
      msg = 'Matching invoice should have status M' ).
  endmethod.


  method test_qty_mismatch.
    " Given : test PO with 80 delivered
    " When : invoice 90 (more than delivered)
    data lt_input type zcl_ret_vendor_invoice=>ty_invoice_input_tab.
    append value #(
      po_item_num  = '0001'
      invoiced_qty = '90.000'
    ) to lt_input.

    data lv_vinv type zret_t_vinv-vinv_number.
    try.
        lv_vinv = zcl_ret_vendor_invoice=>create_from_po(
          iv_po_number = c_test_po
          it_items     = lt_input ).
      catch zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Should not raise — should create with status B' ).
    endtry.

    " Then : header status = B (blocked)
    select single status from zret_t_vinv
      into @data(lv_status)
      where vinv_number = @lv_vinv.

    cl_abap_unit_assert=>assert_equals(
      exp = 'B'
      act = lv_status
      msg = 'Qty mismatch should result in status B' ).
  endmethod.


  method test_price_mismatch.
    " Given : test PO with price 10.00
    " When : invoice with overcharge price 15.00
    data lt_input type zcl_ret_vendor_invoice=>ty_invoice_input_tab.
    append value #(
      po_item_num  = '0001'
      invoiced_qty = '80.000'
      unit_price   = '15.00'
    ) to lt_input.

    data lv_vinv type zret_t_vinv-vinv_number.
    try.
        lv_vinv = zcl_ret_vendor_invoice=>create_from_po(
          iv_po_number = c_test_po
          it_items     = lt_input ).
      catch zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Should not raise' ).
    endtry.

    " Then : header status = B
    select single status from zret_t_vinv
      into @data(lv_status)
      where vinv_number = @lv_vinv.

    cl_abap_unit_assert=>assert_equals(
      exp = 'B'
      act = lv_status
      msg = 'Price mismatch should result in status B' ).
  endmethod.


  method test_invalid_po.
    " When : invoice referencing a non-existent PO
    data lt_input type zcl_ret_vendor_invoice=>ty_invoice_input_tab.
    append value #(
      po_item_num  = '0001'
      invoiced_qty = '50.000'
    ) to lt_input.

    try.
        zcl_ret_vendor_invoice=>create_from_po(
          iv_po_number = '8888888888'
          it_items     = lt_input ).
        cl_abap_unit_assert=>fail( 'Should have raised exception on invalid PO' ).
      catch zcx_ret_core.
        " Expected — test passes
    endtry.
  endmethod.


  method test_unblock_then_open.
    " Given : a blocked invoice (price mismatch)
    data lt_input type zcl_ret_vendor_invoice=>ty_invoice_input_tab.
    append value #(
      po_item_num  = '0001'
      invoiced_qty = '80.000'
      unit_price   = '99.00'
    ) to lt_input.

    data lv_vinv type zret_t_vinv-vinv_number.
    try.
        lv_vinv = zcl_ret_vendor_invoice=>create_from_po(
          iv_po_number = c_test_po
          it_items     = lt_input ).
      catch zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Setup should not raise' ).
    endtry.

    " When : unblock
    try.
        zcl_ret_vendor_invoice=>unblock( lv_vinv ).
      catch zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unblock should not raise on blocked invoice' ).
    endtry.

    " Then : status flipped to O (open for payment)
    select single status from zret_t_vinv
      into @data(lv_status)
      where vinv_number = @lv_vinv.

    cl_abap_unit_assert=>assert_equals(
      exp = 'O'
      act = lv_status
      msg = 'Unblocked invoice should have status O' ).
  endmethod.

endclass.
