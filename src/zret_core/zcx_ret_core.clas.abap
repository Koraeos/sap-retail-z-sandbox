class ZCX_RET_CORE definition
  public
  inheriting from CX_STATIC_CHECK
  final
  create public .

  public section.

    interfaces IF_T100_MESSAGE .
    interfaces IF_T100_DYN_MSG .

    data ARTICLE_ID type ZRET_T_ARTICLE-ARTICLE_ID read-only .

    methods CONSTRUCTOR
      importing
        !TEXTID     like IF_T100_MESSAGE=>T100KEY optional
        !PREVIOUS   like PREVIOUS optional
        !ARTICLE_ID type ZRET_T_ARTICLE-ARTICLE_ID optional .

  protected section.
  private section.
ENDCLASS.


CLASS ZCX_RET_CORE IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    CALL METHOD super->constructor
      EXPORTING
        previous = previous.
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
    me->article_id = article_id.
  ENDMETHOD.

ENDCLASS.
