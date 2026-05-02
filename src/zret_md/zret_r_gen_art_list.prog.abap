*&---------------------------------------------------------------------*
*& Report ZRET_R_GEN_ART_LIST
*&---------------------------------------------------------------------*
*& ALV display of Generic Articles with variants count + drill-down
*& popup on click for the linked variants (articles).
*&---------------------------------------------------------------------*
report zret_r_gen_art_list.

class lcl_app definition.
  public section.
    types:
      begin of ts_generic_view,
        generic_article_id type zret_t_gen_art-generic_article_id,
        generic_name       type zret_t_gen_art-generic_name,
        article_type       type zret_t_gen_art-article_type,
        base_uom           type zret_t_gen_art-base_uom,
        variant_count      type i,
        description        type zret_t_gen_art-description,
        active_flag        type zret_t_gen_art-active_flag,
        created_by         type zret_t_gen_art-created_by,
        created_on         type zret_t_gen_art-created_on,
      end of ts_generic_view,
      tt_generic_view type standard table of ts_generic_view with empty key.

    class-data:
      gt_generics type tt_generic_view,
      go_alv      type ref to cl_salv_table.

    class-methods:
      run,
      on_link_click for event link_click of cl_salv_events_table
        importing row column,
      show_variants_popup
        importing iv_id type zret_t_gen_art-generic_article_id.
endclass.

class lcl_app implementation.

  method run.
    " Load generics + count variants for each
    data(lt_generics) = zcl_ret_generic_art=>get_all( ).

    if lt_generics is initial.
      message 'No generic articles found in ZRET_T_GEN_ART' type 'I'.
      return.
    endif.

    loop at lt_generics into data(ls_g).
      append value #(
        generic_article_id = ls_g-generic_article_id
        generic_name       = ls_g-generic_name
        article_type       = ls_g-article_type
        base_uom           = ls_g-base_uom
        variant_count      = zcl_ret_generic_art=>count_variants( ls_g-generic_article_id )
        description        = ls_g-description
        active_flag        = ls_g-active_flag
        created_by         = ls_g-created_by
        created_on         = ls_g-created_on
      ) to gt_generics.
    endloop.

    " Display ALV
    try.
        cl_salv_table=>factory(
          importing r_salv_table = go_alv
          changing  t_table      = gt_generics
        ).

        go_alv->get_columns( )->set_optimize( abap_true ).

" Make GENERIC_ARTICLE_ID a clickable hotspot for drill-down
        try.
            data(lo_col_table) = cast cl_salv_column_table(
              go_alv->get_columns( )->get_column( 'GENERIC_ARTICLE_ID' )
            ).
            lo_col_table->set_cell_type( if_salv_c_cell_type=>hotspot ).
          catch cx_salv_not_found.
        endtry.

        go_alv->get_display_settings( )->set_list_header( 'Generic Articles - hierarchy overview' ).
        go_alv->get_functions( )->set_all( abap_true ).

        " Register link_click handler for drill-down
        data(lo_events) = go_alv->get_event( ).
        set handler on_link_click for lo_events.

        go_alv->display( ).

      catch cx_salv_msg into data(lo_ex).
        message lo_ex->get_text( ) type 'E'.
    endtry.
  endmethod.

  method on_link_click.
    " Drill-down: open variants popup for the clicked generic
    field-symbols <ls_g> type ts_generic_view.
    read table gt_generics assigning <ls_g> index row.
    if sy-subrc = 0.
      show_variants_popup( <ls_g>-generic_article_id ).
    endif.
  endmethod.

  method show_variants_popup.
    data lt_variants type zcl_ret_generic_art=>tt_articles.
    data lo_alv_v   type ref to cl_salv_table.

    lt_variants = zcl_ret_generic_art=>get_variants( iv_id ).

    if lt_variants is initial.
      message |No variants found for generic { iv_id }| type 'I'.
      return.
    endif.

    try.
        cl_salv_table=>factory(
          importing r_salv_table = lo_alv_v
          changing  t_table      = lt_variants
        ).

        lo_alv_v->get_columns( )->set_optimize( abap_true ).

        " Hide MANDT (technical client column)
        try.
            lo_alv_v->get_columns( )->get_column( 'MANDT' )->set_visible( abap_false ).
          catch cx_salv_not_found.
        endtry.

        lo_alv_v->get_display_settings( )->set_list_header( |Variants of generic { iv_id }| ).
        lo_alv_v->get_functions( )->set_all( abap_true ).

        lo_alv_v->display( ).

      catch cx_salv_msg into data(lo_ex).
        message lo_ex->get_text( ) type 'E'.
    endtry.
  endmethod.

endclass.

start-of-selection.
  lcl_app=>run( ).
