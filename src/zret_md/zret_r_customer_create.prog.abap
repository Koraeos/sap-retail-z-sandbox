REPORT zret_r_customer_create.

" Selection screen
PARAMETERS:
  p_id      TYPE zret_t_customer-customer_id      OBLIGATORY,
  p_name    TYPE zret_t_customer-customer_name    OBLIGATORY,
  p_type    TYPE zret_t_customer-customer_type    OBLIGATORY DEFAULT 'M',
  p_city    TYPE zret_t_customer-city,
  p_cntry   TYPE zret_t_customer-country          DEFAULT 'FR',
  p_curr    TYPE zret_t_customer-default_currency DEFAULT 'EUR'.

START-OF-SELECTION.

  " Build customer record from selection screen
  DATA ls_customer TYPE zret_t_customer.
  ls_customer-customer_id      = p_id.
  ls_customer-customer_name    = p_name.
  ls_customer-customer_type    = p_type.
  ls_customer-city             = p_city.
  ls_customer-country          = p_cntry.
  ls_customer-default_currency = p_curr.

  " Delegate to the domain class
  TRY.
      zcl_ret_customer=>create( ls_customer ).
      MESSAGE |Customer { p_id } created successfully| TYPE 'S'.
    CATCH zcx_ret_core.
      MESSAGE 'Customer creation failed: invalid input, duplicate ID, or invalid type' TYPE 'E'.
  ENDTRY.
