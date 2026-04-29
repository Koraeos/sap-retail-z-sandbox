class zcl_ret_stock definition
  public
  final
  create public.

  public section.
    constants:
      begin of c_mvt_type,
        gr       type zret_de_mvt_type value '101',
        transfer type zret_de_mvt_type value '311',
        pick     type zret_de_mvt_type value '411',
        loading  type zret_de_mvt_type value '412',
        init     type zret_de_mvt_type value '561',
        gi       type zret_de_mvt_type value '601',
      end of c_mvt_type.

    constants:
      begin of c_zone,
        recv      type zret_de_whse_zone value 'RECV',
        storage   type zret_de_whse_zone value 'STORAGE',
        staging   type zret_de_whse_zone value 'STAGING',
        load_dock type zret_de_whse_zone value 'LOAD_DOCK',
      end of c_zone.

    constants:
      begin of c_ref_doc,
        po        type c length 10 value 'PO',
        inb_deliv type c length 10 value 'INB_DELIV',
        out_deliv type c length 10 value 'OUT_DELIV',
        inventory type c length 10 value 'INVENTORY',
      end of c_ref_doc.

    types:
      begin of ts_mvt_result,
        mvt_doc  type zret_t_stk_mvt-mvt_doc,
        mvt_item type zret_t_stk_mvt-mvt_item,
      end of ts_mvt_result.

    class-methods:
      post_movement
        importing
          iv_mvt_type     type zret_de_mvt_type
          iv_article_id   type zret_t_stk_mvt-article_id
          iv_site_id      type zret_t_stk_mvt-site_id
          iv_src_zone     type zret_de_whse_zone optional
          iv_dst_zone     type zret_de_whse_zone optional
          iv_quantity     type zret_t_stk_mvt-quantity
          iv_base_uom     type zret_t_stk_mvt-base_uom
          iv_ref_doc_type type zret_t_stk_mvt-ref_doc_type default ''
          iv_ref_doc_num  type zret_t_stk_mvt-ref_doc_num default ''
          iv_ref_doc_item type zret_t_stk_mvt-ref_doc_item default '0000'
        returning
          value(rs_mvt)   type ts_mvt_result
        raising
          zcx_ret_core,

      get_available
        importing
          iv_article_id type zret_t_stock-article_id
          iv_site_id    type zret_t_stock-site_id
          iv_zone_code  type zret_de_whse_zone
        returning
          value(rv_qty) type zret_t_stock-quantity,

      validate_availability
        importing
          iv_article_id   type zret_t_stock-article_id
          iv_site_id      type zret_t_stock-site_id
          iv_zone_code    type zret_de_whse_zone
          iv_required_qty type zret_t_stock-quantity
        raising
          zcx_ret_core,

      load_initial_stock
        importing
          iv_article_id type zret_t_stock-article_id
          iv_site_id    type zret_t_stock-site_id
          iv_zone_code  type zret_de_whse_zone default c_zone-storage
          iv_quantity   type zret_t_stock-quantity
          iv_base_uom   type zret_t_stock-base_uom default 'PC'
        returning
          value(rs_mvt) type ts_mvt_result
        raising
          zcx_ret_core.

  private section.
    class-methods:
      get_next_mvt_doc
        returning value(rv_doc) type zret_t_stk_mvt-mvt_doc,

      apply_to_stock
        importing
          iv_article_id type zret_t_stock-article_id
          iv_site_id    type zret_t_stock-site_id
          iv_zone_code  type zret_de_whse_zone
          iv_qty_change type zret_t_stock-quantity
          iv_base_uom   type zret_t_stock-base_uom
          iv_mvt_doc    type zret_t_stk_mvt-mvt_doc
        raising
          zcx_ret_core.

endclass.


class zcl_ret_stock implementation.

  method post_movement.
    " Atomic LUW: insert movement journal + apply stock to zones
    data ls_mvt     type zret_t_stk_mvt.
    data lv_mvt_doc type zret_t_stk_mvt-mvt_doc.

    " 1. Validate inputs
    if iv_quantity <= 0.
      raise exception type zcx_ret_core.
    endif.

    if iv_src_zone is initial and iv_dst_zone is initial.
      raise exception type zcx_ret_core.
    endif.

    " 2. Check availability if source zone provided
    if iv_src_zone is not initial.
      validate_availability(
        iv_article_id   = iv_article_id
        iv_site_id      = iv_site_id
        iv_zone_code    = iv_src_zone
        iv_required_qty = iv_quantity
      ).
    endif.

    " 3. Atomic LUW: insert mvt + apply stock
    try.
        lv_mvt_doc = get_next_mvt_doc( ).

        ls_mvt-client       = sy-mandt.
        ls_mvt-mvt_doc      = lv_mvt_doc.
        ls_mvt-mvt_item     = '0001'.
        ls_mvt-mvt_type     = iv_mvt_type.
        ls_mvt-mvt_date     = sy-datum.
        ls_mvt-article_id   = iv_article_id.
        ls_mvt-site_id      = iv_site_id.
        ls_mvt-src_zone     = iv_src_zone.
        ls_mvt-dst_zone     = iv_dst_zone.
        ls_mvt-quantity     = iv_quantity.
        ls_mvt-base_uom     = iv_base_uom.
        ls_mvt-ref_doc_type = iv_ref_doc_type.
        ls_mvt-ref_doc_num  = iv_ref_doc_num.
        ls_mvt-ref_doc_item = iv_ref_doc_item.
        ls_mvt-created_by   = sy-uname.
        ls_mvt-created_on   = sy-datum.

        insert zret_t_stk_mvt from ls_mvt.
        if sy-subrc <> 0.
          raise exception type zcx_ret_core.
        endif.

        if iv_src_zone is not initial.
          apply_to_stock(
            iv_article_id = iv_article_id
            iv_site_id    = iv_site_id
            iv_zone_code  = iv_src_zone
            iv_qty_change = iv_quantity * -1
            iv_base_uom   = iv_base_uom
            iv_mvt_doc    = lv_mvt_doc
          ).
        endif.

        if iv_dst_zone is not initial.
          apply_to_stock(
            iv_article_id = iv_article_id
            iv_site_id    = iv_site_id
            iv_zone_code  = iv_dst_zone
            iv_qty_change = iv_quantity
            iv_base_uom   = iv_base_uom
            iv_mvt_doc    = lv_mvt_doc
          ).
        endif.

        commit work and wait.

      catch zcx_ret_core into data(lo_ex).
        rollback work.
        raise exception lo_ex.
    endtry.

    rs_mvt-mvt_doc  = lv_mvt_doc.
    rs_mvt-mvt_item = '0001'.
  endmethod.

  method get_available.
    " Returns the available quantity in a specific zone (0 if no record)
    select single quantity
      from zret_t_stock
      into @rv_qty
      where article_id = @iv_article_id
        and site_id    = @iv_site_id
        and zone_code  = @iv_zone_code.

    if sy-subrc <> 0.
      rv_qty = 0.
    endif.
  endmethod.

  method validate_availability.
    " Raises exception if available stock < required quantity
    data(lv_available) = get_available(
      iv_article_id = iv_article_id
      iv_site_id    = iv_site_id
      iv_zone_code  = iv_zone_code
    ).

    if lv_available < iv_required_qty.
      raise exception type zcx_ret_core.
    endif.
  endmethod.

  method load_initial_stock.
    " Initial stock seeding (movement type 561)
    rs_mvt = post_movement(
      iv_mvt_type     = c_mvt_type-init
      iv_article_id   = iv_article_id
      iv_site_id      = iv_site_id
      iv_dst_zone     = iv_zone_code
      iv_quantity     = iv_quantity
      iv_base_uom     = iv_base_uom
      iv_ref_doc_type = c_ref_doc-inventory
    ).
  endmethod.

  method get_next_mvt_doc.
    " Returns next movement document number (max + 1)
    select max( mvt_doc )
      from zret_t_stk_mvt
      into @data(lv_max).

    if lv_max is initial.
      rv_doc = '0000000001'.
    else.
      rv_doc = lv_max + 1.
    endif.
  endmethod.

  method apply_to_stock.
    " UPSERT pattern on stock table
    data ls_stock type zret_t_stock.

    select single * from zret_t_stock
      into @ls_stock
      where article_id = @iv_article_id
        and site_id    = @iv_site_id
        and zone_code  = @iv_zone_code.

    if sy-subrc = 0.
      ls_stock-quantity     = ls_stock-quantity + iv_qty_change.
      ls_stock-last_mvt_doc = iv_mvt_doc.
      ls_stock-changed_by   = sy-uname.
      ls_stock-changed_on   = sy-datum.

      if ls_stock-quantity < 0.
        raise exception type zcx_ret_core.
      endif.

      update zret_t_stock from ls_stock.
      if sy-subrc <> 0.
        raise exception type zcx_ret_core.
      endif.

    else.
      if iv_qty_change < 0.
        raise exception type zcx_ret_core.
      endif.

      ls_stock-client       = sy-mandt.
      ls_stock-article_id   = iv_article_id.
      ls_stock-site_id      = iv_site_id.
      ls_stock-zone_code    = iv_zone_code.
      ls_stock-quantity     = iv_qty_change.
      ls_stock-base_uom     = iv_base_uom.
      ls_stock-last_mvt_doc = iv_mvt_doc.
      ls_stock-changed_by   = sy-uname.
      ls_stock-changed_on   = sy-datum.

      insert zret_t_stock from ls_stock.
      if sy-subrc <> 0.
        raise exception type zcx_ret_core.
      endif.
    endif.
  endmethod.

endclass.
