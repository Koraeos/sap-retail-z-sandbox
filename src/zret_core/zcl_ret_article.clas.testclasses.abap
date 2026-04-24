*"* use this source file for your ABAP unit test classes

CLASS ltcl_article_tests DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS:
      teardown,
      returns_all_active             FOR TESTING,
      filter_by_hard_type            FOR TESTING,
      ttc_is_ht_times_1_20           FOR TESTING,
      hard_row_is_green              FOR TESTING,
      raises_when_no_match           FOR TESTING,
      get_by_id_returns_article      FOR TESTING,
      get_by_id_raises_if_not_found  FOR TESTING,
      create_adds_article            FOR TESTING,
      create_raises_if_duplicate     FOR TESTING,
      update_modifies_article        FOR TESTING,
      delete_marks_inactive          FOR TESTING,
      delete_raises_if_not_found     FOR TESTING.
ENDCLASS.


CLASS ltcl_article_tests IMPLEMENTATION.

  METHOD teardown.
    " Runs after each test - cleans up any test article (ID starting with 'TEST')
    DELETE FROM zret_t_article WHERE article_id LIKE 'TEST%'.
    COMMIT WORK.
  ENDMETHOD.

  METHOD returns_all_active.
    TRY.
        DATA(lt_result) = zcl_ret_article=>select_all( ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( lt_result )
          exp = 4
          msg = 'Expected 4 active articles' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.

  METHOD filter_by_hard_type.
    DATA lt_range TYPE zcl_ret_article=>tty_type_range.
    lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'HARD' ) ).
    TRY.
        DATA(lt_result) = zcl_ret_article=>select_all( it_type_range = lt_range ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( lt_result )
          exp = 1
          msg = 'Expected only 1 HARD article' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.

  METHOD ttc_is_ht_times_1_20.
    DATA lv_expected TYPE zret_t_article-price.
    TRY.
        DATA(lt_result) = zcl_ret_article=>select_all( ).
        LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<ls_article>).
          lv_expected = <ls_article>-price * zcl_ret_article=>c_vat_rate.
          cl_abap_unit_assert=>assert_equals(
            act = <ls_article>-price_ttc
            exp = lv_expected
            msg = |TTC wrong for { <ls_article>-article_id }| ).
        ENDLOOP.
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.

  METHOD hard_row_is_green.
    DATA lt_range TYPE zcl_ret_article=>tty_type_range.
    lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'HARD' ) ).
    TRY.
        DATA(lt_result) = zcl_ret_article=>select_all( it_type_range = lt_range ).
        READ TABLE lt_result INTO DATA(ls_article) INDEX 1.
        READ TABLE ls_article-t_color INTO DATA(ls_color) INDEX 1.
        cl_abap_unit_assert=>assert_equals(
          act = ls_color-color-col
          exp = 5
          msg = 'HARD should be green (col = 5)' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core' ).
    ENDTRY.
  ENDMETHOD.

  METHOD raises_when_no_match.
    DATA lt_range TYPE zcl_ret_article=>tty_type_range.
    lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'XXXX' ) ).
    TRY.
        zcl_ret_article=>select_all( it_type_range = lt_range ).
        cl_abap_unit_assert=>fail( 'Should have raised zcx_ret_core' ).
      CATCH zcx_ret_core.
        " Expected
    ENDTRY.
  ENDMETHOD.

  METHOD get_by_id_returns_article.
    TRY.
        DATA(ls_article) = zcl_ret_article=>get_by_id( 'ART001' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_article-article_id
          exp = 'ART001'
          msg = 'Should return ART001' ).
        cl_abap_unit_assert=>assert_not_initial(
          act = ls_article-price_ttc
          msg = 'TTC should be computed after get_by_id' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'ART001 exists - no exception expected' ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_by_id_raises_if_not_found.
    TRY.
        zcl_ret_article=>get_by_id( 'ZZ999' ).
        cl_abap_unit_assert=>fail( 'Should have raised zcx_ret_core for unknown ID' ).
      CATCH zcx_ret_core INTO DATA(lx_exc).
        cl_abap_unit_assert=>assert_equals(
          act = lx_exc->article_id
          exp = 'ZZ999'
          msg = 'Exception should carry the article_id in context' ).
    ENDTRY.
  ENDMETHOD.

  METHOD create_adds_article.
    DATA ls_article TYPE zret_t_article.
    ls_article-article_id   = 'TEST01'.
    ls_article-article_name = 'Test Article'.
    ls_article-article_type = 'HARD'.
    ls_article-price        = '9.99'.
    ls_article-currency     = 'EUR'.
    ls_article-base_uom     = 'PC'.

    TRY.
        zcl_ret_article=>create( ls_article ).
        DATA(ls_result) = zcl_ret_article=>get_by_id( 'TEST01' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-article_name
          exp = 'Test Article'
          msg = 'Created article should be retrievable with correct name' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core during create' ).
    ENDTRY.
  ENDMETHOD.

  METHOD create_raises_if_duplicate.
    DATA ls_article TYPE zret_t_article.
    ls_article-article_id   = 'ART001'.
    ls_article-article_name = 'Duplicate'.
    ls_article-article_type = 'HARD'.
    ls_article-price        = '1.00'.
    ls_article-currency     = 'EUR'.
    ls_article-base_uom     = 'PC'.

    TRY.
        zcl_ret_article=>create( ls_article ).
        cl_abap_unit_assert=>fail( 'Should have raised zcx_ret_core for duplicate ID' ).
      CATCH zcx_ret_core INTO DATA(lx_exc).
        cl_abap_unit_assert=>assert_equals(
          act = lx_exc->article_id
          exp = 'ART001'
          msg = 'Exception should carry the duplicate article_id' ).
    ENDTRY.
  ENDMETHOD.

  METHOD update_modifies_article.
    DATA ls_article TYPE zret_t_article.
    ls_article-article_id   = 'TEST02'.
    ls_article-article_name = 'Original name'.
    ls_article-article_type = 'HARD'.
    ls_article-price        = '10.00'.
    ls_article-currency     = 'EUR'.
    ls_article-base_uom     = 'PC'.

    TRY.
        zcl_ret_article=>create( ls_article ).

        ls_article-article_name = 'Updated name'.
        ls_article-price        = '15.00'.
        zcl_ret_article=>update( ls_article ).

        DATA(ls_result) = zcl_ret_article=>get_by_id( 'TEST02' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-article_name
          exp = 'Updated name'
          msg = 'Name should be updated' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core during update flow' ).
    ENDTRY.
  ENDMETHOD.

  METHOD delete_marks_inactive.
    DATA ls_article TYPE zret_t_article.
    ls_article-article_id   = 'TEST03'.
    ls_article-article_name = 'To be soft-deleted'.
    ls_article-article_type = 'HARD'.
    ls_article-price        = '5.00'.
    ls_article-currency     = 'EUR'.
    ls_article-base_uom     = 'PC'.

    TRY.
        zcl_ret_article=>create( ls_article ).
        zcl_ret_article=>delete( 'TEST03' ).

        SELECT SINGLE active_flag FROM zret_t_article
          WHERE article_id = 'TEST03'
          INTO @DATA(lv_flag).

        cl_abap_unit_assert=>assert_equals(
          act = lv_flag
          exp = abap_false
          msg = 'Article should be soft-deleted (active_flag = false)' ).
      CATCH zcx_ret_core.
        cl_abap_unit_assert=>fail( 'Unexpected zcx_ret_core during delete flow' ).
    ENDTRY.
  ENDMETHOD.

  METHOD delete_raises_if_not_found.
    TRY.
        zcl_ret_article=>delete( 'TEST99' ).
        cl_abap_unit_assert=>fail( 'Should have raised zcx_ret_core for unknown ID' ).
      CATCH zcx_ret_core INTO DATA(lx_exc).
        cl_abap_unit_assert=>assert_equals(
          act = lx_exc->article_id
          exp = 'TEST99'
          msg = 'Exception should carry the unknown article_id' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
