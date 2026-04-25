REPORT zret_r_so_list.

TABLES zret_t_so.

" Selection screen — filters
SELECT-OPTIONS so_cust FOR zret_t_so-customer_id.
SELECT-OPTIONS so_stat FOR zret_t_so-status.

" Local type extending zret_t_so with a color column for ALV row coloring
TYPES: BEGIN OF ty_so_display.
         INCLUDE TYPE zret_t_so.
TYPES:   t_color TYPE lvc_t_scol,
       END OF ty_so_display.
TYPES: ty_so_display_tab TYPE STANDARD TABLE OF ty_so_display WITH DEFAULT KEY.

" Local class for double-click event handling
CLASS lcl_handler DEFINITION.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING it_so TYPE ty_so_display_tab.
    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
  PRIVATE SECTION.
    DATA mt_so TYPE ty_so_display_tab.
ENDCLASS.

CLASS lcl_handler IMPLEMENTATION.

  METHOD constructor.
    mt_so = it_so.
  ENDMETHOD.

  METHOD on_double_click.
    DATA(ls_so) = mt_so[ row ].

    " Load full SO (header + items) via the domain class
    DATA ls_full TYPE zcl_ret_sales_order=>ty_full.
    TRY.
        ls_full = zcl_ret_sales_order=>get_by_id( ls_so-so_number ).
      CATCH zcx_ret_core.
        MESSAGE 'Cannot load Sales Order details' TYPE 'I'.
        RETURN.
    ENDTRY.

    " Display items in a popup ALV
    DATA(lt_items) = ls_full-items.
    DATA lo_popup TYPE REF TO cl_salv_table.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_popup
          CHANGING  t_table      = lt_items ).

        lo_popup->set_screen_popup(
          start_column = 5
          end_column   = 100
          start_line   = 5
          end_line     = 20 ).

        lo_popup->get_columns( )->set_optimize( abap_true ).

        DATA(lo_pop_header) = NEW cl_salv_form_layout_grid( ).
        lo_pop_header->create_label(
          row    = 1
          column = 1
          text   = |Sales Order { ls_full-header-so_number } - Items|
        ).
        lo_pop_header->create_label(
          row    = 2
          column = 1
          text   = |Customer: { ls_full-header-customer_id } - { ls_full-header-customer_name }|
        ).
        lo_pop_header->create_label(
          row    = 3
          column = 1
          text   = |Total: { ls_full-header-total_amount } { ls_full-header-currency }|
        ).
        lo_popup->set_top_of_list( lo_pop_header ).

        lo_popup->display( ).

      CATCH cx_salv_msg.
        MESSAGE 'Error displaying SO items' TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

" Data
DATA: lt_so_display TYPE ty_so_display_tab,
      lo_alv        TYPE REF TO cl_salv_table,
      lo_handler    TYPE REF TO lcl_handler.

START-OF-SELECTION.

  " Delegate data retrieval to the domain class
  DATA(lt_so) = zcl_ret_sales_order=>select_all(
    it_customer_range = so_cust[]
    it_status_range   = so_stat[] ).

  IF lt_so IS INITIAL.
    MESSAGE 'No Sales Order found for these filters' TYPE 'I'.
    RETURN.
  ENDIF.

  " Enrich each row with a color based on status
  DATA: ls_display TYPE ty_so_display,
        ls_color   TYPE lvc_s_scol.

  LOOP AT lt_so INTO DATA(ls_so).
    CLEAR ls_display.
    MOVE-CORRESPONDING ls_so TO ls_display.

    CLEAR ls_color.
    CASE ls_so-status.
      WHEN zcl_ret_sales_order=>c_status-open.      ls_color-color-col = 1. " blue
      WHEN zcl_ret_sales_order=>c_status-delivered. ls_color-color-col = 5. " green
      WHEN zcl_ret_sales_order=>c_status-billed.    ls_color-color-col = 4. " blue-green
      WHEN zcl_ret_sales_order=>c_status-cancelled. ls_color-color-col = 6. " red
    ENDCASE.
    ls_color-color-int = 1.
    APPEND ls_color TO ls_display-t_color.

    APPEND ls_display TO lt_so_display.
  ENDLOOP.

  " Compute stats for header
  DATA: lv_count_o TYPE i,
        lv_count_d TYPE i,
        lv_count_b TYPE i,
        lv_count_c TYPE i,
        lv_total   TYPE p LENGTH 8 DECIMALS 2.

  LOOP AT lt_so INTO DATA(ls_stat).
    CASE ls_stat-status.
      WHEN zcl_ret_sales_order=>c_status-open.      lv_count_o = lv_count_o + 1.
      WHEN zcl_ret_sales_order=>c_status-delivered. lv_count_d = lv_count_d + 1.
      WHEN zcl_ret_sales_order=>c_status-billed.    lv_count_b = lv_count_b + 1.
      WHEN zcl_ret_sales_order=>c_status-cancelled. lv_count_c = lv_count_c + 1.
    ENDCASE.
    lv_total = lv_total + ls_stat-total_amount.
  ENDLOOP.

  " Build the main ALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = lt_so_display ).

      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_columns( )->set_optimize( abap_true ).
      lo_alv->get_columns( )->set_color_column( 'T_COLOR' ).

      DATA(lo_header) = NEW cl_salv_form_layout_grid( ).

      lo_header->create_label(
        row    = 1
        column = 1
        text   = 'Sales Order List - ZRET_R_SO_LIST'
      ).
      lo_header->create_label(
        row    = 2
        column = 1
        text   = |Date: { sy-datum DATE = USER }  -  User: { sy-uname }|
      ).
      lo_header->create_label(
        row    = 3
        column = 1
        text   = |Total: { lines( lt_so ) } SOs  -  Open: { lv_count_o }  Delivered: { lv_count_d }  Billed: { lv_count_b }  Cancelled: { lv_count_c }|
      ).
      lo_header->create_label(
        row    = 4
        column = 1
        text   = |Total amount: { lv_total } EUR|
      ).

      lo_alv->set_top_of_list( lo_header ).

      lo_handler = NEW lcl_handler( lt_so_display ).
      SET HANDLER lo_handler->on_double_click FOR lo_alv->get_event( ).

      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv TYPE 'E'.
  ENDTRY.
