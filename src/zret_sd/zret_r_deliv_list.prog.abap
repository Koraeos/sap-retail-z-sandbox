REPORT zret_r_deliv_list.

TABLES zret_t_deliv.

" Selection screen — filters
SELECT-OPTIONS so_site FOR zret_t_deliv-source_site_id.
SELECT-OPTIONS so_stat FOR zret_t_deliv-status.

" Local type extending zret_t_deliv with a color column
TYPES: BEGIN OF ty_deliv_display.
         INCLUDE TYPE zret_t_deliv.
TYPES:   t_color TYPE lvc_t_scol,
       END OF ty_deliv_display.
TYPES: ty_deliv_display_tab TYPE STANDARD TABLE OF ty_deliv_display WITH DEFAULT KEY.

" Local class for double-click event handling
CLASS lcl_handler DEFINITION.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING it_deliv TYPE ty_deliv_display_tab.
    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
  PRIVATE SECTION.
    DATA mt_deliv TYPE ty_deliv_display_tab.
ENDCLASS.

CLASS lcl_handler IMPLEMENTATION.

  METHOD constructor.
    mt_deliv = it_deliv.
  ENDMETHOD.

  METHOD on_double_click.
    DATA(ls_deliv) = mt_deliv[ row ].

    " Load full delivery via the domain class
    DATA ls_full TYPE zcl_ret_delivery=>ty_full.
    TRY.
        ls_full = zcl_ret_delivery=>get_by_id( ls_deliv-deliv_number ).
      CATCH zcx_ret_core.
        MESSAGE 'Cannot load Delivery details' TYPE 'I'.
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
          text   = |Delivery { ls_full-header-deliv_number } - Items|
        ).
        lo_pop_header->create_label(
          row    = 2
          column = 1
          text   = |From SO: { ls_full-header-so_number }  -  Source: { ls_full-header-source_site_id }|
        ).
        lo_pop_header->create_label(
          row    = 3
          column = 1
          text   = |Customer: { ls_full-header-customer_id } - { ls_full-header-customer_name }|
        ).
        lo_pop_header->create_label(
          row    = 4
          column = 1
          text   = |Destination: { ls_full-header-destination_city } ( { ls_full-header-destination_country } )|
        ).
        lo_popup->set_top_of_list( lo_pop_header ).

        lo_popup->display( ).

      CATCH cx_salv_msg.
        MESSAGE 'Error displaying delivery items' TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

" Data
DATA: lt_deliv_display TYPE ty_deliv_display_tab,
      lo_alv           TYPE REF TO cl_salv_table,
      lo_handler       TYPE REF TO lcl_handler.

START-OF-SELECTION.

  " Delegate data retrieval to the domain class
  DATA(lt_deliv) = zcl_ret_delivery=>select_all(
    it_site_range   = so_site[]
    it_status_range = so_stat[] ).

  IF lt_deliv IS INITIAL.
    MESSAGE 'No delivery found for these filters' TYPE 'I'.
    RETURN.
  ENDIF.

  " Enrich each row with a color based on status
  DATA: ls_display TYPE ty_deliv_display,
        ls_color   TYPE lvc_s_scol.

  LOOP AT lt_deliv INTO DATA(ls_deliv).
    CLEAR ls_display.
    MOVE-CORRESPONDING ls_deliv TO ls_display.

    CLEAR ls_color.
    CASE ls_deliv-status.
      WHEN zcl_ret_delivery=>c_status-created.  ls_color-color-col = 1. " blue
      WHEN zcl_ret_delivery=>c_status-shipped.  ls_color-color-col = 5. " green
      WHEN zcl_ret_delivery=>c_status-received. ls_color-color-col = 4. " blue-green
    ENDCASE.
    ls_color-color-int = 1.
    APPEND ls_color TO ls_display-t_color.

    APPEND ls_display TO lt_deliv_display.
  ENDLOOP.

  " Compute stats for header
  DATA: lv_count_c TYPE i,
        lv_count_s TYPE i,
        lv_count_r TYPE i.

  LOOP AT lt_deliv INTO DATA(ls_stat).
    CASE ls_stat-status.
      WHEN zcl_ret_delivery=>c_status-created.  lv_count_c = lv_count_c + 1.
      WHEN zcl_ret_delivery=>c_status-shipped.  lv_count_s = lv_count_s + 1.
      WHEN zcl_ret_delivery=>c_status-received. lv_count_r = lv_count_r + 1.
    ENDCASE.
  ENDLOOP.

  " Build the main ALV
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = lt_deliv_display ).

      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_columns( )->set_optimize( abap_true ).
      lo_alv->get_columns( )->set_color_column( 'T_COLOR' ).

      DATA(lo_header) = NEW cl_salv_form_layout_grid( ).

      lo_header->create_label(
        row    = 1
        column = 1
        text   = 'Delivery List - ZRET_R_DELIV_LIST'
      ).
      lo_header->create_label(
        row    = 2
        column = 1
        text   = |Date: { sy-datum DATE = USER }  -  User: { sy-uname }|
      ).
      lo_header->create_label(
        row    = 3
        column = 1
        text   = |Total: { lines( lt_deliv ) } deliveries  -  Created: { lv_count_c }  Shipped: { lv_count_s }  Received: { lv_count_r }|
      ).

      lo_alv->set_top_of_list( lo_header ).

      lo_handler = NEW lcl_handler( lt_deliv_display ).
      SET HANDLER lo_handler->on_double_click FOR lo_alv->get_event( ).

      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv TYPE 'E'.
  ENDTRY.
