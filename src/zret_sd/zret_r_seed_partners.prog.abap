report zret_r_seed_partners.

start-of-selection.

  perform wipe_existing_data.
  perform create_test_customers.
  perform seed_partner_functions.
  perform assign_b2c_scenario.
  perform assign_b2b_scenario.
  perform display_partner_matrix.


form wipe_existing_data.
  " Idempotent : on wipe les data de test pour pouvoir rejouer

  delete from zret_t_cust_prt
    where customer_id in ( 'HQPARIS', 'DUPONT01' ).
  commit work and wait.

  delete from zret_t_customer
    where customer_id in ( 'HQPARIS', 'DEP_LYON', 'DEP_MAR',
                           'DEP_LIL', 'BNPBANK', 'DUPONT01' ).
  commit work and wait.

  write: / 'Wipe completed.'.
endform.


form create_test_customers.
  data lt_customers type standard table of zret_t_customer.

  lt_customers = value #(
    ( mandt = sy-mandt
      customer_id      = 'HQPARIS'
      customer_name    = 'Decathlon HQ Paris'
      customer_type    = 'B'
      city             = 'Paris'
      country          = 'FR'
      default_currency = 'EUR'
      active_flag      = 'X'
      created_by       = sy-uname
      created_on       = sy-datum
      changed_by       = sy-uname
      changed_on       = sy-datum )

    ( mandt = sy-mandt
      customer_id      = 'DEP_LYON'
      customer_name    = 'Depot Lyon'
      customer_type    = 'B'
      city             = 'Lyon'
      country          = 'FR'
      default_currency = 'EUR'
      active_flag      = 'X'
      created_by       = sy-uname
      created_on       = sy-datum
      changed_by       = sy-uname
      changed_on       = sy-datum )

    ( mandt = sy-mandt
      customer_id      = 'DEP_MAR'
      customer_name    = 'Depot Marseille'
      customer_type    = 'B'
      city             = 'Marseille'
      country          = 'FR'
      default_currency = 'EUR'
      active_flag      = 'X'
      created_by       = sy-uname
      created_on       = sy-datum
      changed_by       = sy-uname
      changed_on       = sy-datum )

    ( mandt = sy-mandt
      customer_id      = 'DEP_LIL'
      customer_name    = 'Depot Lille'
      customer_type    = 'B'
      city             = 'Lille'
      country          = 'FR'
      default_currency = 'EUR'
      active_flag      = 'X'
      created_by       = sy-uname
      created_on       = sy-datum
      changed_by       = sy-uname
      changed_on       = sy-datum )

    ( mandt = sy-mandt
      customer_id      = 'BNPBANK'
      customer_name    = 'BNP Paribas Finance'
      customer_type    = 'B'
      city             = 'Paris'
      country          = 'FR'
      default_currency = 'EUR'
      active_flag      = 'X'
      created_by       = sy-uname
      created_on       = sy-datum
      changed_by       = sy-uname
      changed_on       = sy-datum )

    ( mandt = sy-mandt
      customer_id      = 'DUPONT01'
      customer_name    = 'Mr Dupont'
      customer_type    = 'C'
      city             = 'Lyon'
      country          = 'FR'
      default_currency = 'EUR'
      active_flag      = 'X'
      created_by       = sy-uname
      created_on       = sy-datum
      changed_by       = sy-uname
      changed_on       = sy-datum )
  ).

  insert zret_t_customer from table @lt_customers.
  if sy-subrc <> 0.
    write: / 'Error creating customers'.
    return.
  endif.
  commit work and wait.

  write: / |Created { lines( lt_customers ) } customers.|.
endform.


form seed_partner_functions.
  try.
      zcl_ret_cust_partner=>seed_partner_functions( ).
      write: / 'Partner functions reference seeded (AG/WE/RE/RG).'.
    catch zcx_ret_core.
      write: / 'Error seeding partner functions.'.
  endtry.
endform.


form assign_b2c_scenario.
  " B2C : DUPONT01 joue tous les rôles lui-même.
  " On n'assigne RIEN explicitement — le fallback de get_partner_for_function
  " retournera DUPONT01 pour toutes les fonctions interrogées.

  write: / ''.
  write: / '=== B2C Scenario (DUPONT01) ==='.
  write: / 'No explicit assignment — fallback to sold-to.'.
endform.


form assign_b2b_scenario.
  " B2B Decathlon-style : HQPARIS sold-to avec multi Ship-to + Payer dédié

  write: / ''.
  write: / '=== B2B Scenario (HQPARIS Decathlon-style) ==='.

  try.
      data(lv_counter) = zcl_ret_cust_partner=>assign_partner(
        iv_customer_id         = 'HQPARIS'
        iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-sold_to
        iv_partner_customer_id = 'HQPARIS' ).
      write: / |HQPARIS - AG (Sold-to)  -> HQPARIS  (counter { lv_counter })|.

      lv_counter = zcl_ret_cust_partner=>assign_partner(
        iv_customer_id         = 'HQPARIS'
        iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-ship_to
        iv_partner_customer_id = 'DEP_LYON' ).
      write: / |HQPARIS - WE (Ship-to)  -> DEP_LYON (counter { lv_counter })|.

      lv_counter = zcl_ret_cust_partner=>assign_partner(
        iv_customer_id         = 'HQPARIS'
        iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-ship_to
        iv_partner_customer_id = 'DEP_MAR' ).
      write: / |HQPARIS - WE (Ship-to)  -> DEP_MAR  (counter { lv_counter })|.

      lv_counter = zcl_ret_cust_partner=>assign_partner(
        iv_customer_id         = 'HQPARIS'
        iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-ship_to
        iv_partner_customer_id = 'DEP_LIL' ).
      write: / |HQPARIS - WE (Ship-to)  -> DEP_LIL  (counter { lv_counter })|.

      lv_counter = zcl_ret_cust_partner=>assign_partner(
        iv_customer_id         = 'HQPARIS'
        iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-bill_to
        iv_partner_customer_id = 'HQPARIS' ).
      write: / |HQPARIS - RE (Bill-to)  -> HQPARIS  (counter { lv_counter })|.

      lv_counter = zcl_ret_cust_partner=>assign_partner(
        iv_customer_id         = 'HQPARIS'
        iv_partner_function    = zcl_ret_cust_partner=>c_partner_function-payer
        iv_partner_customer_id = 'BNPBANK' ).
      write: / |HQPARIS - RG (Payer)    -> BNPBANK  (counter { lv_counter })|.

    catch zcx_ret_core.
      write: / 'Error in B2B scenario'.
  endtry.
endform.


form display_partner_matrix.
  " Démo : on appelle get_partner_for_function pour chaque (customer × fonction)
  " et on affiche le résultat — y compris le fallback B2C

  write: / ''.
  write: / '=== Resolved partners (with fallback) ==='.

  data: lt_customers type standard table of kunnr,
        lt_functions type standard table of zde_ret_part_fct.

  lt_customers = value #( ( 'HQPARIS' ) ( 'DUPONT01' ) ).
  lt_functions = value #( ( zcl_ret_cust_partner=>c_partner_function-sold_to )
                          ( zcl_ret_cust_partner=>c_partner_function-ship_to )
                          ( zcl_ret_cust_partner=>c_partner_function-bill_to )
                          ( zcl_ret_cust_partner=>c_partner_function-payer ) ).

  loop at lt_customers into data(lv_customer).
    write: / |Customer { lv_customer }:|.
    loop at lt_functions into data(lv_function).
      data(lv_partner) = zcl_ret_cust_partner=>get_partner_for_function(
        iv_customer_id      = lv_customer
        iv_partner_function = lv_function ).
      write: /  |  { lv_function } -> { lv_partner }|.
    endloop.
  endloop.
endform.
