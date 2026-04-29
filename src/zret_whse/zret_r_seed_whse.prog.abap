*&---------------------------------------------------------------------*
*& Report ZRET_R_SEED_WHSE
*&---------------------------------------------------------------------*
*& Seeds warehouse master data:
*&   - 4 standard zones (RECV, STORAGE, STAGING, LOAD_DOCK)
*&   - Initial stock for existing articles in existing sites (mvt 561)
*&---------------------------------------------------------------------*
report zret_r_seed_whse.

class lcl_seeder definition.
  public section.
    class-methods:
      seed_zones,
      seed_initial_stock.
endclass.

class lcl_seeder implementation.

  method seed_zones.
    " Insert/update the 4 standard warehouse zones
    data lt_zones type table of zret_t_whse_zone.

    append value #(
      client        = sy-mandt
      zone_code     = 'RECV'
      zone_name     = 'Receiving Zone'
      zone_category = 'INBOUND'
      description   = 'Goods receipt area'
      created_by    = sy-uname
      created_on    = sy-datum
    ) to lt_zones.

    append value #(
      client        = sy-mandt
      zone_code     = 'STORAGE'
      zone_name     = 'Storage Area'
      zone_category = 'STORAGE'
      description   = 'Long-term storage'
      created_by    = sy-uname
      created_on    = sy-datum
    ) to lt_zones.

    append value #(
      client        = sy-mandt
      zone_code     = 'STAGING'
      zone_name     = 'Staging Zone'
      zone_category = 'OUTBOUND'
      description   = 'Pre-loading staging area'
      created_by    = sy-uname
      created_on    = sy-datum
    ) to lt_zones.

    append value #(
      client        = sy-mandt
      zone_code     = 'LOAD_DOCK'
      zone_name     = 'Loading Dock'
      zone_category = 'OUTBOUND'
      description   = 'Truck loading dock'
      created_by    = sy-uname
      created_on    = sy-datum
    ) to lt_zones.

    " UPSERT: insert if missing, update if existing
    modify zret_t_whse_zone from table @lt_zones.

    if sy-subrc = 0.
      commit work and wait.
      write: / |Warehouse zones seeded: { lines( lt_zones ) } rows|.
    else.
      write: / 'ERROR while inserting zones'.
    endif.
  endmethod.


method seed_initial_stock.
    " Load 100 PC of each existing article in each existing site (zone STORAGE)
    data lt_articles type table of zret_t_article.
    data lt_sites    type table of zret_t_site.
    data lv_count    type i.
    data lv_article_id type zret_t_stock-article_id.
    data lv_site_id    type zret_t_stock-site_id.

    select * from zret_t_article into table @lt_articles up to 4 rows.
    select * from zret_t_site    into table @lt_sites    up to 3 rows.

    if lt_articles is initial.
      write: / 'No articles found in ZRET_T_ARTICLE - skipping initial stock'.
      return.
    endif.

    if lt_sites is initial.
      write: / 'No sites found in ZRET_T_SITE - skipping initial stock'.
      return.
    endif.

    loop at lt_articles into data(ls_article).
      loop at lt_sites into data(ls_site).
        lv_article_id = ls_article-article_id.
        lv_site_id    = ls_site-site_id.

        try.
            data(ls_mvt) = zcl_ret_stock=>load_initial_stock(
              iv_article_id = lv_article_id
              iv_site_id    = lv_site_id
              iv_zone_code  = zcl_ret_stock=>c_zone-storage
              iv_quantity   = '100'
              iv_base_uom   = 'PC'
            ).
            write: / |Stock 100 PC loaded - article: { lv_article_id }, site: { lv_site_id }, mvt_doc: { ls_mvt-mvt_doc }|.
            lv_count = lv_count + 1.

          catch zcx_ret_core.
            write: / |ERROR loading stock for article { lv_article_id } in site { lv_site_id }|.
        endtry.
      endloop.
    endloop.

    write: /.
    write: / |Total stock loads: { lv_count }|.
  endmethod.

endclass.


start-of-selection.

  write: / '========================================='.
  write: / '  Warehouse Seeding'.
  write: / '========================================='.
  write: /.

  write: / '--- Phase 1: Zones ---'.
  lcl_seeder=>seed_zones( ).
  write: /.

  write: / '--- Phase 2: Initial Stock ---'.
  lcl_seeder=>seed_initial_stock( ).
  write: /.

  write: / '========================================='.
  write: / '  Done'.
  write: / '========================================='.
