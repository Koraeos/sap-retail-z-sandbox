REPORT zret_r_inv_create.

PARAMETERS:
  p_deliv     TYPE zret_t_deliv-deliv_number   OBLIGATORY.

START-OF-SELECTION.

  TRY.
      DATA(lv_inv) = zcl_ret_invoice=>create_from_delivery(
        iv_deliv_number = p_deliv ).

      MESSAGE |Invoice { lv_inv } created from Delivery { p_deliv }. SO status is now Billed.| TYPE 'S'.

    CATCH zcx_ret_core.
      MESSAGE 'Invoice creation failed: delivery not found, SO not in Delivered status, or already billed' TYPE 'E'.
  ENDTRY.
