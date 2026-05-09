*&---------------------------------------------------------------------*
*& Report Z_REMISE_PALIER
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT Z_REMISE_PALIER.

PARAMETERS: p_prix TYPE p LENGTH 8 DECIMALS 2 OBLIGATORY DEFAULT '99.99'.

DATA: lv_taux TYPE p LENGTH 8 DECIMALS 2,
      lv_montant TYPE p LENGTH 8 DECIMALS 2,
      lv_final TYPE p LENGTH 8 DECIMALS 2.

START-OF-SELECTION.

IF p_prix >= 1000.
  lv_taux = 15.
ELSEIF p_prix >= 500.
  lv_taux = 10.
ELSEIF p_prix >= 100.
  lv_taux = 5.
ELSE.
  lv_taux = 0.
ENDIF.

lv_montant = ( p_prix * lv_taux ) / 100.
lv_final   = p_prix - lv_montant.

WRITE: / 'Prix initial    :', p_prix,
       / 'Taux remise     :', lv_taux,
       / 'Montant remise  :', lv_montant,
       / 'Prix final      :', lv_final.
