"! Test class for ZCL_RET_GENERIC_ART
class ltcl_generic_art_test definition for testing
  duration short
  risk level harmless
  final.

  private section.
    constants:
      c_test_id_1  type zret_t_gen_art-generic_article_id value 'TST_GEN_01',
      c_test_art_1 type zret_t_article-article_id         value 'TST_ART_01',
      c_test_name  type zret_t_gen_art-generic_name       value 'Test Generic 01',
      c_test_type  type zret_t_gen_art-article_type       value 'HARD'.

    methods:
      teardown,

      test_create_ok                  for testing,
      test_create_duplicate           for testing,
      test_create_empty_name          for testing,
      test_count_variants_zero        for testing,
      test_get_variants_returns_link  for testing,
      test_deactivate_ok              for testing,
      test_deactivate_blocks_var      for testing.
endclass.


class ltcl_generic_art_test implementation.

  method teardown.
    " Clean test data after each test (TST_* prefix isolates)
    delete from zret_t_gen_art
      where generic_article_id like 'TST_%'.

    delete from zret_t_article
      where article_id like 'TST_%'.

    commit work and wait.
  endmethod.


  method test_create_ok.
    " GIVEN nothing
    " WHEN  create is called with valid input
    " THEN  generic exists with active_flag = 'X'
    try.
        zcl_ret_generic_art=>create(
          iv_id   = c_test_id_1
          iv_name = c_test_name
          iv_type = c_test_type
        ).

        data(ls_g) = zcl_ret_generic_art=>get_by_id( c_test_id_1 ).

        cl_abap_unit_assert=>assert_equals(
          exp = c_test_name
          act = ls_g-generic_name
          msg = 'Generic name should match input'
        ).

        cl_abap_unit_assert=>assert_equals(
          exp = zcl_ret_generic_art=>c_active-yes
          act = ls_g-active_flag
          msg = 'New generic should be active'
        ).

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.


  method test_create_duplicate.
    " GIVEN a generic already exists with this ID
    " WHEN  create called again with same ID
    " THEN  raises zcx_ret_core
    try.
        zcl_ret_generic_art=>create(
          iv_id   = c_test_id_1
          iv_name = c_test_name
          iv_type = c_test_type
        ).
      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Setup error: { lo_ex->get_text( ) }| ).
    endtry.

    try.
        zcl_ret_generic_art=>create(
          iv_id   = c_test_id_1
          iv_name = c_test_name
          iv_type = c_test_type
        ).
        cl_abap_unit_assert=>fail( msg = 'Should have raised exception for duplicate ID' ).
      catch zcx_ret_core.
        " expected
    endtry.
  endmethod.


  method test_create_empty_name.
    " GIVEN no generic
    " WHEN  create with empty name
    " THEN  raises zcx_ret_core (validation)
    try.
        zcl_ret_generic_art=>create(
          iv_id   = c_test_id_1
          iv_name = ''
          iv_type = c_test_type
        ).
        cl_abap_unit_assert=>fail( msg = 'Should have raised exception for empty name' ).
      catch zcx_ret_core.
        " expected
    endtry.
  endmethod.


  method test_count_variants_zero.
    " GIVEN a fresh generic with no linked articles
    " WHEN  count_variants
    " THEN  returns 0
    try.
        zcl_ret_generic_art=>create(
          iv_id   = c_test_id_1
          iv_name = c_test_name
          iv_type = c_test_type
        ).
      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Setup error: { lo_ex->get_text( ) }| ).
    endtry.

    data(lv_count) = zcl_ret_generic_art=>count_variants( c_test_id_1 ).

    cl_abap_unit_assert=>assert_equals(
      exp = 0
      act = lv_count
      msg = 'A new generic should have 0 variants'
    ).
  endmethod.


  method test_get_variants_returns_link.
    " GIVEN a generic + 1 article linked to it
    " WHEN  get_variants
    " THEN  returns the linked article
    try.
        zcl_ret_generic_art=>create(
          iv_id   = c_test_id_1
          iv_name = c_test_name
          iv_type = c_test_type
        ).
      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Setup error: { lo_ex->get_text( ) }| ).
    endtry.

    data ls_article type zret_t_article.
    ls_article-mandt              = sy-mandt.
    ls_article-article_id         = c_test_art_1.
    ls_article-article_name       = 'Test article 01'.
    ls_article-generic_article_id = c_test_id_1.
    ls_article-color              = 'Red'.
    ls_article-art_size           = 'L'.
    ls_article-active_flag        = 'X'.
    insert zret_t_article from ls_article.
    commit work and wait.

    data(lt_variants) = zcl_ret_generic_art=>get_variants( c_test_id_1 ).

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( lt_variants )
      msg = 'Should return 1 variant linked to the generic'
    ).
  endmethod.


  method test_deactivate_ok.
    " GIVEN a generic with no variants
    " WHEN  deactivate
    " THEN  active_flag flips to ' '
    try.
        zcl_ret_generic_art=>create(
          iv_id   = c_test_id_1
          iv_name = c_test_name
          iv_type = c_test_type
        ).

        zcl_ret_generic_art=>deactivate( c_test_id_1 ).

        data(ls_g) = zcl_ret_generic_art=>get_by_id( c_test_id_1 ).

        cl_abap_unit_assert=>assert_equals(
          exp = zcl_ret_generic_art=>c_active-no
          act = ls_g-active_flag
          msg = 'Generic should be deactivated'
        ).

      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lo_ex->get_text( ) }| ).
    endtry.
  endmethod.


  method test_deactivate_blocks_var.
    " GIVEN a generic + 1 article linked
    " WHEN  deactivate
    " THEN  raises zcx_ret_core (cannot deactivate generic in use)
    try.
        zcl_ret_generic_art=>create(
          iv_id   = c_test_id_1
          iv_name = c_test_name
          iv_type = c_test_type
        ).
      catch zcx_ret_core into data(lo_ex).
        cl_abap_unit_assert=>fail( msg = |Setup error: { lo_ex->get_text( ) }| ).
    endtry.

    data ls_article type zret_t_article.
    ls_article-mandt              = sy-mandt.
    ls_article-article_id         = c_test_art_1.
    ls_article-article_name       = 'Test article 01'.
    ls_article-generic_article_id = c_test_id_1.
    ls_article-active_flag        = 'X'.
    insert zret_t_article from ls_article.
    commit work and wait.

    try.
        zcl_ret_generic_art=>deactivate( c_test_id_1 ).
        cl_abap_unit_assert=>fail( msg = 'Should have raised when variants exist' ).
      catch zcx_ret_core.
        " expected
    endtry.
  endmethod.

endclass.
