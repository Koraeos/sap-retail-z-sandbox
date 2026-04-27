*&---------------------------------------------------------------------*
*& Report ZRET_R_SEED_SUPPLIERS
*&---------------------------------------------------------------------*
*& Seeds 3 sample suppliers for portfolio demo
*&---------------------------------------------------------------------*
report zret_r_seed_suppliers.

start-of-selection.

  data lt_suppliers type table of zret_t_supplier.

  append value #(
    client        = sy-mandt
    supplier_id   = 'SUP001'
    supplier_name = 'Acme Distribution'
    address_line  = '12 rue de la Logistique'
    city          = 'Lille'
    country       = 'FR'
    active_flag   = 'X'
    created_by    = sy-uname
    created_on    = sy-datum
  ) to lt_suppliers.

  append value #(
    client        = sy-mandt
    supplier_id   = 'SUP002'
    supplier_name = 'Global Sportswear Ltd'
    address_line  = '45 Industry Road'
    city          = 'Manchester'
    country       = 'GB'
    active_flag   = 'X'
    created_by    = sy-uname
    created_on    = sy-datum
  ) to lt_suppliers.

  append value #(
    client        = sy-mandt
    supplier_id   = 'SUP003'
    supplier_name = 'EcoTextiles GmbH'
    address_line  = 'Hauptstrasse 18'
    city          = 'Munich'
    country       = 'DE'
    active_flag   = 'X'
    created_by    = sy-uname
    created_on    = sy-datum
  ) to lt_suppliers.

  modify zret_t_supplier from table @lt_suppliers.

  if sy-subrc = 0.
    commit work and wait.
    write: / |Suppliers seeded: { lines( lt_suppliers ) } rows|.
    loop at lt_suppliers into data(ls).
      write: / |  { ls-supplier_id } - { ls-supplier_name } ({ ls-city }, { ls-country })|.
    endloop.
  else.
    write: / 'ERROR while inserting suppliers'.
  endif.
