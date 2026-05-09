*&---------------------------------------------------------------------*
*& Report Z_VARIABLES_TEST
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT Z_VARIABLES_TEST.

DATA lv_age TYPE i VALUE 36.
DATA lv_prenom TYPE string VALUE 'Romain'.
DATA lv_salaire TYPE p LENGTH 8 DECIMALS 2 VALUE '3095.50'.
DATA lv_today TYPE D VALUE '20260505.'.

WRITE: / lv_age,
         lv_prenom,
         lv_salaire,
         lv_today.
