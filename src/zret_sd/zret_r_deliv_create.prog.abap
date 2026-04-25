REPORT zret_r_deliv_create.

" Selection screen
PARAMETERS:
  p_so       TYPE zret_t_so-so_number   OBLIGATORY,
  p_site     TYPE zret_t_site-site_id   OBLIGATORY DEFAULT 'WH01'.

START-OF-SELECTION.

  " Delegate to the domain class
  TRY.
      DATA(lv_deliv) = zcl_ret_delivery=>create_from_so(
        iv_so_number      = p_so
        iv_source_site_id = p_site ).

      MESSAGE |Delivery { lv_deliv } created from SO { p_so }. SO status is now Delivered.| TYPE 'S'.

    CATCH zcx_ret_core.
      MESSAGE 'Delivery creation failed: SO not found, not in Open status, or source site is not a warehouse' TYPE 'E'.
  ENDTRY.
