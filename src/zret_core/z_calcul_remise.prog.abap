*&---------------------------------------------------------------------*
*& Report Z_CALCUL_REMISE
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_calcul_remise.

PARAMETERS: p_prix TYPE p LENGTH 8 DECIMALS 2 OBLIGATORY DEFAULT '99.99',
            p_remise TYPE p LENGTH 8 DECIMALS 2 OBLIGATORY DEFAULT '15.00'.

DATA: lv_montant TYPE p LENGTH 8 DECIMALS 2,
      lv_final TYPE p LENGTH 8 DECIMALS 2.

START-OF-SELECTION.

lv_montant = ( p_prix * p_remise ) / 100.
lv_final = p_prix - lv_montant.

WRITE: / 'Prix initial  : ', p_prix,
       / 'Taux de remise : ', p_remise,
       / 'Montant de la remise  : ', lv_montant,
       / 'Prix Final  :', lv_final.
