REPORT zret_r_so_create.

" Header parameters
PARAMETERS:
  p_custid    TYPE zret_t_so-customer_id    OBLIGATORY,
  p_curr      TYPE zret_t_so-currency       OBLIGATORY DEFAULT 'EUR'.

SELECTION-SCREEN SKIP 1.

" Item parameters (up to 3 lines)
PARAMETERS:
  p_art1      TYPE zret_t_so_item-article_id,
  p_qty1      TYPE p LENGTH 7 DECIMALS 3,
  p_art2      TYPE zret_t_so_item-article_id,
  p_qty2      TYPE p LENGTH 7 DECIMALS 3,
  p_art3      TYPE zret_t_so_item-article_id,
  p_qty3      TYPE p LENGTH 7 DECIMALS 3.

START-OF-SELECTION.

  " Build header (customer_name auto-filled by the class from customer master)
  DATA ls_header TYPE zret_t_so.
  ls_header-customer_id = p_custid.
  ls_header-currency    = p_curr.

  " Build items list
  DATA lt_items TYPE zcl_ret_sales_order=>ty_item_input_tab.

  IF p_art1 IS NOT INITIAL AND p_qty1 IS NOT INITIAL.
    APPEND VALUE #( article_id = p_art1 quantity = p_qty1 ) TO lt_items.
  ENDIF.
  IF p_art2 IS NOT INITIAL AND p_qty2 IS NOT INITIAL.
    APPEND VALUE #( article_id = p_art2 quantity = p_qty2 ) TO lt_items.
  ENDIF.
  IF p_art3 IS NOT INITIAL AND p_qty3 IS NOT INITIAL.
    APPEND VALUE #( article_id = p_art3 quantity = p_qty3 ) TO lt_items.
  ENDIF.

  " Delegate to the domain class
  TRY.
      DATA(lv_so_number) = zcl_ret_sales_order=>create(
        is_header = ls_header
        it_items  = lt_items ).
      MESSAGE |Sales Order { lv_so_number } created successfully| TYPE 'S'.

    CATCH zcx_ret_core.
      MESSAGE 'Sales Order creation failed: invalid customer, article, or input' TYPE 'E'.
  ENDTRY.
