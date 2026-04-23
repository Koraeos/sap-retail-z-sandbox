*"* use this source file for your ABAP unit test classes

CLASS ltcl_article_tests DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS:
      returns_all_active             FOR TESTING,
      filter_by_hard_type            FOR TESTING,
      ttc_is_ht_times_1_20           FOR TESTING,
      hard_row_is_green              FOR TESTING,
      raises_when_no_match           FOR TESTING,
      get_by_id_returns_article      FOR TESTING,
      get_by_id_raises_if_not_found  FOR TESTING.
ENDCLASS.


CLASS ltcl_article_tests IMPLEMENTATION.

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
        " Expected - test passes
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
         CATCH zcx_ret_core.
           " Expected - test passes
       ENDTRY.
     ENDMETHOD.

ENDCLASS.
