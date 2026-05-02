*&---------------------------------------------------------------------*
*& Report ZRET_R_SEED_GENERIC
*&---------------------------------------------------------------------*
*& Seeds 3 Generic Articles + links existing articles as variants.
*& Demonstrates the article hierarchy pattern (super-model -> variants).
*& ART004 and ART005 are intentionally left orphan to show
*& backwards compatibility with legacy articles.
*&---------------------------------------------------------------------*
report zret_r_seed_generic.

class lcl_seeder definition.
  public section.
    class-methods:
      seed_generics,
      link_articles.
endclass.

class lcl_seeder implementation.

  method seed_generics.
    write: / '--- Phase 1: Create Generic Articles ---'.

    try.
        zcl_ret_generic_art=>create(
          iv_id          = 'GEN001'
          iv_name        = 'Trail running shoes Quechua men'
          iv_type        = 'HARD'
          iv_base_uom    = 'PC'
          iv_description = 'Lightweight trail running footwear for men'
        ).
        write: / |  GEN001 created (Trail running shoes Quechua men)|.

      catch zcx_ret_core.
        write: / |  GEN001 already exists or error - skipped|.
    endtry.

    try.
        zcl_ret_generic_art=>create(
          iv_id          = 'GEN002'
          iv_name        = 'Cotton T-shirt round neck'
          iv_type        = 'SOFT'
          iv_base_uom    = 'PC'
          iv_description = 'Basic cotton t-shirt, multiple colors and sizes'
        ).
        write: / |  GEN002 created (Cotton T-shirt round neck)|.

      catch zcx_ret_core.
        write: / |  GEN002 already exists or error - skipped|.
    endtry.

    try.
        zcl_ret_generic_art=>create(
          iv_id          = 'GEN003'
          iv_name        = 'Hydration accessory'
          iv_type        = 'ACCE'
          iv_base_uom    = 'PC'
          iv_description = 'Reusable bottles, gourdes, hydration packs'
        ).
        write: / |  GEN003 created (Hydration accessory)|.

      catch zcx_ret_core.
        write: / |  GEN003 already exists or error - skipped|.
    endtry.

    write: /.
  endmethod.

  method link_articles.
    " Update existing articles: assign generic + color + size variant attributes
    write: / '--- Phase 2: Link existing articles to generics ---'.

    update zret_t_article
       set generic_article_id = 'GEN001'
           color              = 'Black'
           art_size           = '42'
       where article_id = 'ART001'.
    write: / |  ART001 -> GEN001 (Black, 42)|.

    update zret_t_article
       set generic_article_id = 'GEN002'
           color              = 'Black'
           art_size           = 'M'
       where article_id = 'ART002'.
    write: / |  ART002 -> GEN002 (Black, M)|.

    update zret_t_article
       set generic_article_id = 'GEN003'
           color              = 'Silver'
           art_size           = '0.7L'
       where article_id = 'ART003'.
    write: / |  ART003 -> GEN003 (Silver, 0.7L)|.

    " ART004 (protein bar) + ART005 (wool beanie) remain orphan
    " to demonstrate backwards compatibility with legacy articles
    write: / |  ART004 + ART005 left unlinked (legacy articles without generic)|.

    commit work and wait.
    write: /.
  endmethod.

endclass.

start-of-selection.
  write: / '========================================='.
  write: / '  Generic Article Seeder'.
  write: / '========================================='.
  write: /.

  lcl_seeder=>seed_generics( ).
  lcl_seeder=>link_articles( ).

  write: / '========================================='.
  write: / '  Done'.
  write: / '========================================='.
