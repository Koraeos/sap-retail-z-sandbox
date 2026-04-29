*&---------------------------------------------------------------------*
*& Report ZRET_R_PO_DEMO
*&---------------------------------------------------------------------*
*& End-to-end demo:
*&   - Creates a PO with 2 items
*&   - Posts a goods receipt on item 1
*&   - Shows stock in zone RECV after GR
*&---------------------------------------------------------------------*
report zret_r_po_demo.

class lcl_demo definition.
  public section.
    class-methods:
      run_demo,
      show_stock_in_zone
        importing iv_zone type zret_de_whse_zone.
endclass.

class lcl_demo implementation.

  method run_demo.
    data lt_suppliers type table of zret_t_supplier.
    data lt_articles  type table of zret_t_article.
    data lt_sites     type table of zret_t_site.
    data lt_items     type zcl_ret_purch_order=>tt_po_items_in.

    " --- 1. Read prerequisites ---
    select * from zret_t_supplier into table @lt_suppliers up to 1 rows.
    if lt_suppliers is initial.
      write: / 'ERROR: No supplier in ZRET_T_SUPPLIER. Add one via SE16 first.'.
      return.
    endif.

    select * from zret_t_article into table @lt_articles up to 2 rows.
    if lines( lt_articles ) < 2.
      write: / 'ERROR: Need at least 2 articles in ZRET_T_ARTICLE.'.
      return.
    endif.

    select single * from zret_t_site
      into @data(ls_site)
      where site_id = 'WH01'.
    if sy-subrc <> 0.
      write: / 'ERROR: Site WH01 not found in ZRET_T_SITE.'.
      return.
    endif.

    data(ls_supplier) = lt_suppliers[ 1 ].

    " --- 2. Build PO items ---
    loop at lt_articles into data(ls_article).
      append value #(
        article_id = ls_article-article_id
        quantity   = '50'
        base_uom   = 'PC'
        unit_price = '12.50'
      ) to lt_items.
    endloop.

    " --- 3. Type conversions for cross-table compat ---
    data lv_supplier_id type zret_t_po-supplier_id.
    data lv_site_id     type zret_t_po-site_id.
    lv_supplier_id = ls_supplier-supplier_id.
    lv_site_id     = ls_site-site_id.

    write: / '========================================='.
    write: / '  PO Demo: Create + Goods Receipt'.
    write: / '========================================='.
    write: /.

    try.
        " --- 4. Create the PO ---
        write: / '--- Step 1: Create PO ---'.
        data(lv_po_num) = zcl_ret_purch_order=>create_po(
          iv_supplier_id   = lv_supplier_id
          iv_supplier_name = ls_supplier-supplier_name
          iv_site_id       = lv_site_id
          iv_currency      = 'EUR'
          it_items         = lt_items
        ).
        write: / |PO created: { lv_po_num }|.
        write: / |  Supplier:  { lv_supplier_id } - { ls_supplier-supplier_name }|.
        write: / |  Site:      { lv_site_id }|.
        write: / |  Items:     { lines( lt_items ) }|.
        write: / |  Total qty: { lines( lt_items ) * 50 } PC|.
        write: /.

        " --- 5. Post Goods Receipt on item 1 ---
        write: / '--- Step 2: Post Goods Receipt (item 1) ---'.
        data(ls_mvt) = zcl_ret_purch_order=>post_goods_receipt(
          iv_po_number    = lv_po_num
          iv_item_num     = '0001'
          iv_qty_received = '50'
        ).
        write: / |GR posted: mvt_doc { ls_mvt-mvt_doc }, type 101 (Goods Receipt)|.
        write: / |  Stock added: 50 PC of { lt_articles[ 1 ]-article_id } in zone RECV (site { lv_site_id })|.
        write: /.

        " --- 6. Read updated PO header ---
        write: / '--- Step 3: PO status after GR ---'.
        data(ls_header) = zcl_ret_purch_order=>get_header( lv_po_num ).
        write: / |PO { lv_po_num } status: { ls_header-status } (I = In Delivery)|.
        write: /.

        " --- 7. Show RECV zone state ---
        write: / '--- Step 4: Stock currently in zone RECV ---'.
        show_stock_in_zone( zcl_ret_stock=>c_zone-recv ).

      catch zcx_ret_core into data(lo_ex).
        write: / |ERROR: { lo_ex->get_text( ) }|.
    endtry.
  endmethod.

  method show_stock_in_zone.
    data lt_stock type table of zret_t_stock.

    select * from zret_t_stock
      into table @lt_stock
      where zone_code = @iv_zone
      order by article_id, site_id.

    if lt_stock is initial.
      write: / |No stock in zone { iv_zone }|.
      return.
    endif.

    loop at lt_stock into data(ls).
      write: / |  Article: { ls-article_id }, Site: { ls-site_id }, Qty: { ls-quantity } { ls-base_uom }, Last mvt: { ls-last_mvt_doc }|.
    endloop.
  endmethod.

endclass.

start-of-selection.
  lcl_demo=>run_demo( ).
  write: /.
  write: / '========================================='.
  write: / '  Done'.
  write: / '========================================='.
