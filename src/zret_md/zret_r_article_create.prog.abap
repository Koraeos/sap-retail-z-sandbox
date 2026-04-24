REPORT zret_r_article_create.

" Selection screen: user enters article data
PARAMETERS:
  p_id    TYPE zret_t_article-article_id   OBLIGATORY,
  p_name  TYPE zret_t_article-article_name OBLIGATORY,
  p_type  TYPE zret_t_article-article_type OBLIGATORY DEFAULT 'HARD',
  p_ean   TYPE zret_t_article-ean,
  p_uom   TYPE zret_t_article-base_uom     OBLIGATORY DEFAULT 'PC',
  p_price TYPE zret_t_article-price        OBLIGATORY,
  p_curr  TYPE zret_t_article-currency     OBLIGATORY DEFAULT 'EUR'.

START-OF-SELECTION.

  " Build the article record from user input
  DATA ls_article TYPE zret_t_article.
  ls_article-article_id   = p_id.
  ls_article-article_name = p_name.
  ls_article-article_type = p_type.
  ls_article-ean          = p_ean.
  ls_article-base_uom     = p_uom.
  ls_article-price        = p_price.
  ls_article-currency     = p_curr.

  " Delegate to the domain class (all logic lives there)
  TRY.
      zcl_ret_article=>create( ls_article ).
      MESSAGE |Article { p_id } created successfully| TYPE 'S'.

    CATCH zcx_ret_core INTO DATA(lx_exc).
      IF lx_exc->article_id IS INITIAL.
        MESSAGE 'Creation failed: article ID is missing' TYPE 'E'.
      ELSE.
        MESSAGE |Creation failed for article { lx_exc->article_id } (duplicate, invalid name/price, or DB error)|
          TYPE 'E'.
      ENDIF.
  ENDTRY.
