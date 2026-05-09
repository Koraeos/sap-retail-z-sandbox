REPORT z_calculatrice.

PARAMETERS: p_num1 TYPE i OBLIGATORY DEFAULT 10,
            p_num2 TYPE i OBLIGATORY DEFAULT 3.

DATA: lv_somme TYPE i,
      lv_diff  TYPE i,
      lv_prod  TYPE i,
      lv_quot  TYPE p LENGTH 8 DECIMALS 2.

START-OF-SELECTION.

  lv_somme = p_num1 + p_num2.
  lv_diff  = p_num1 - p_num2.
  lv_prod  = p_num1 * p_num2.

    IF p_num2 = 0.
  WRITE: / 'Erreur : division par zéro impossible.'.
ELSE.
  lv_quot = p_num1 / p_num2.
  WRITE: / 'Quotient :', lv_quot.
ENDIF.

  WRITE: / 'Somme        :', lv_somme,
         / 'Différence   :', lv_diff,
         / 'Produit      :', lv_prod,
         / 'Quotient     :', lv_quot.
