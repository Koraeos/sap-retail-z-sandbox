*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZRET_T_ARTICLE..................................*
DATA:  BEGIN OF STATUS_ZRET_T_ARTICLE                .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZRET_T_ARTICLE                .
CONTROLS: TCTRL_ZRET_T_ARTICLE
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZRET_T_ARTICLE                .
TABLES: ZRET_T_ARTICLE                 .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
