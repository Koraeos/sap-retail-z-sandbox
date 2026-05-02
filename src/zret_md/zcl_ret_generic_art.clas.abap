class zcl_ret_generic_art definition
  public
  final
  create public.

  public section.
    types:
      tt_articles type standard table of zret_t_article with empty key,
      tt_generics type standard table of zret_t_gen_art with empty key.

    constants:
      begin of c_active,
        yes type zret_t_gen_art-active_flag value 'X',
        no  type zret_t_gen_art-active_flag value ' ',
      end of c_active.

    class-methods:
      "! Create a new generic article (atomic LUW)
      create
        importing
          iv_id          type zret_t_gen_art-generic_article_id
          iv_name        type zret_t_gen_art-generic_name
          iv_type        type zret_t_gen_art-article_type
          iv_base_uom    type zret_t_gen_art-base_uom default 'PC'
          iv_description type zret_t_gen_art-description default ''
        raising
          zcx_ret_core,

      "! Read a single generic by id, raise if not found
      get_by_id
        importing
          iv_id             type zret_t_gen_art-generic_article_id
        returning
          value(rs_generic) type zret_t_gen_art
        raising
          zcx_ret_core,

      "! List all active generics
      get_all
        returning
          value(rt_generics) type tt_generics,

      "! Get all article variants linked to a generic
      get_variants
        importing
          iv_id              type zret_t_gen_art-generic_article_id
        returning
          value(rt_variants) type tt_articles,

      "! Returns abap_true if at least one variant exists for the generic
      has_variants
        importing
          iv_id          type zret_t_gen_art-generic_article_id
        returning
          value(rv_has)  type abap_bool,

      "! Returns the number of variants linked to the generic
      count_variants
        importing
          iv_id            type zret_t_gen_art-generic_article_id
        returning
          value(rv_count)  type i,

      "! Update a generic (only non-initial parameters are applied)
      update
        importing
          iv_id          type zret_t_gen_art-generic_article_id
          iv_name        type zret_t_gen_art-generic_name optional
          iv_description type zret_t_gen_art-description optional
        raising
          zcx_ret_core,

      "! Soft-deactivate a generic (active_flag -> ' ')
      "! Refuses if the generic still has variants
      deactivate
        importing
          iv_id type zret_t_gen_art-generic_article_id
        raising
          zcx_ret_core.

endclass.


class zcl_ret_generic_art implementation.

  method create.
    " Validation + atomic insert
    data ls_generic type zret_t_gen_art.

    if iv_id is initial or iv_name is initial.
      raise exception type zcx_ret_core.
    endif.

    " Check uniqueness
    select single @abap_true from zret_t_gen_art
      into @data(lv_exists)
      where generic_article_id = @iv_id.
    if lv_exists = abap_true.
      raise exception type zcx_ret_core.
    endif.

    ls_generic-client             = sy-mandt.
    ls_generic-generic_article_id = iv_id.
    ls_generic-generic_name       = iv_name.
    ls_generic-article_type       = iv_type.
    ls_generic-base_uom           = iv_base_uom.
    ls_generic-description        = iv_description.
    ls_generic-active_flag        = c_active-yes.
    ls_generic-created_by         = sy-uname.
    ls_generic-created_on         = sy-datum.
    ls_generic-changed_by         = sy-uname.
    ls_generic-changed_on         = sy-datum.

    insert zret_t_gen_art from ls_generic.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.

  method get_by_id.
    select single * from zret_t_gen_art
      into @rs_generic
      where generic_article_id = @iv_id.

    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.
  endmethod.

  method get_all.
    " Returns only active generics
    select * from zret_t_gen_art
      into table @rt_generics
      where active_flag = @c_active-yes
      order by generic_article_id.
  endmethod.

  method get_variants.
    " All articles linked to the generic, regardless of variant active_flag
    select * from zret_t_article
      into table @rt_variants
      where generic_article_id = @iv_id
      order by article_id.
  endmethod.

  method has_variants.
    select single @abap_true from zret_t_article
      into @rv_has
      where generic_article_id = @iv_id.

    if sy-subrc <> 0.
      rv_has = abap_false.
    endif.
  endmethod.

  method count_variants.
    select count(*) from zret_t_article
      into @rv_count
      where generic_article_id = @iv_id.
  endmethod.

  method update.
    " Read existing, apply non-initial params, write back
    data ls_generic type zret_t_gen_art.

    select single * from zret_t_gen_art
      into @ls_generic
      where generic_article_id = @iv_id.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    if iv_name is not initial.
      ls_generic-generic_name = iv_name.
    endif.

    if iv_description is not initial.
      ls_generic-description = iv_description.
    endif.

    ls_generic-changed_by = sy-uname.
    ls_generic-changed_on = sy-datum.

    update zret_t_gen_art from ls_generic.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.

  method deactivate.
    " Soft delete, refuses if variants still exist
    if has_variants( iv_id ) = abap_true.
      raise exception type zcx_ret_core.
    endif.

    data ls_generic type zret_t_gen_art.
    select single * from zret_t_gen_art
      into @ls_generic
      where generic_article_id = @iv_id.
    if sy-subrc <> 0.
      raise exception type zcx_ret_core.
    endif.

    ls_generic-active_flag = c_active-no.
    ls_generic-changed_by  = sy-uname.
    ls_generic-changed_on  = sy-datum.

    update zret_t_gen_art from ls_generic.
    if sy-subrc <> 0.
      rollback work.
      raise exception type zcx_ret_core.
    endif.

    commit work and wait.
  endmethod.

endclass.
