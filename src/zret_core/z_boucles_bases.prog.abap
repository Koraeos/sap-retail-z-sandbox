REPORT z_boucle_bases.

PARAMETERS p_n TYPE i OBLIGATORY DEFAULT 10.

DATA: lv_somme    TYPE i,
      lv_facto    TYPE p LENGTH 16 DECIMALS 0,
      lv_compteur TYPE i VALUE 1.

START-OF-SELECTION.

  " Partie A : somme des entiers de 1 à N (avec DO)
  DO p_n TIMES.
    lv_somme = lv_somme + sy-index.
  ENDDO.

  " Partie B : factorielle de N (avec WHILE)
  lv_facto = 1.
  WHILE lv_compteur <= p_n.
    lv_facto    = lv_facto * lv_compteur.
    lv_compteur = lv_compteur + 1.
  ENDWHILE.

  WRITE: / 'Somme de 1 à', p_n, ':', lv_somme,
         / 'Factorielle de', p_n, ':', lv_facto.
