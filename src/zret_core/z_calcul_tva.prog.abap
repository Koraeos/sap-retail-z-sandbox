REPORT z_calcul_tva.

PARAMETERS: p_ht   TYPE p LENGTH 8 DECIMALS 2 OBLIGATORY DEFAULT '19.99',
            p_taux TYPE p LENGTH 5 DECIMALS 2 OBLIGATORY DEFAULT '20.00'.

DATA: lv_tva TYPE p LENGTH 8 DECIMALS 2,
      lv_ttc TYPE p LENGTH 8 DECIMALS 2.

START-OF-SELECTION.

  lv_tva = ( p_ht * p_taux ) / 100.
  lv_ttc = p_ht + lv_tva.

  WRITE: / 'HT saisi    :', p_ht,
         / 'Taux TVA    :', p_taux,
         / 'Montant TVA :', lv_tva,
         / 'Montant TTC :', lv_ttc.
