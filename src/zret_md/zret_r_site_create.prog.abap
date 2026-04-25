REPORT zret_r_site_create.

PARAMETERS:
  p_id      TYPE zret_t_site-site_id      OBLIGATORY,
  p_name    TYPE zret_t_site-site_name    OBLIGATORY,
  p_type    TYPE zret_t_site-site_type    OBLIGATORY DEFAULT 'S',
  p_addr    TYPE zret_t_site-address_line,
  p_city    TYPE zret_t_site-city,
  p_cntry   TYPE zret_t_site-country      DEFAULT 'FR'.

START-OF-SELECTION.

  DATA ls_site TYPE zret_t_site.
  ls_site-site_id      = p_id.
  ls_site-site_name    = p_name.
  ls_site-site_type    = p_type.
  ls_site-address_line = p_addr.
  ls_site-city         = p_city.
  ls_site-country      = p_cntry.

  TRY.
      zcl_ret_site=>create( ls_site ).
      MESSAGE |Site { p_id } created successfully| TYPE 'S'.
    CATCH zcx_ret_core.
      MESSAGE 'Site creation failed: invalid input, duplicate ID, or invalid type' TYPE 'E'.
  ENDTRY.
