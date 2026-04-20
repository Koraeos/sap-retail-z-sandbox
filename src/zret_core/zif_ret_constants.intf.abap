INTERFACE zif_ret_constants
  PUBLIC.

  "! <p class="shorttext synchronized">Article categories</p>
  CONSTANTS:
    BEGIN OF c_article_type,
      food     TYPE c LENGTH 2 VALUE 'FD',
      non_food TYPE c LENGTH 2 VALUE 'NF',
      textile  TYPE c LENGTH 2 VALUE 'TX',
      sport    TYPE c LENGTH 2 VALUE 'SP',
    END OF c_article_type.

  "! <p class="shorttext synchronized">Sales channels</p>
  CONSTANTS:
    BEGIN OF c_sales_channel,
      store    TYPE c LENGTH 2 VALUE 'ST',
      web      TYPE c LENGTH 2 VALUE 'WB',
      mobile   TYPE c LENGTH 2 VALUE 'MB',
      wholesale TYPE c LENGTH 2 VALUE 'WS',
    END OF c_sales_channel.

  "! <p class="shorttext synchronized">Stock movement types</p>
  CONSTANTS:
    BEGIN OF c_movement,
      goods_receipt  TYPE c LENGTH 3 VALUE '101',
      goods_issue    TYPE c LENGTH 3 VALUE '201',
      transfer       TYPE c LENGTH 3 VALUE '301',
      inventory_diff TYPE c LENGTH 3 VALUE '701',
    END OF c_movement.

  "! <p class="shorttext synchronized">Document status</p>
  CONSTANTS:
    BEGIN OF c_status,
      draft     TYPE c LENGTH 1 VALUE 'D',
      open      TYPE c LENGTH 1 VALUE 'O',
      confirmed TYPE c LENGTH 1 VALUE 'C',
      shipped   TYPE c LENGTH 1 VALUE 'S',
      invoiced  TYPE c LENGTH 1 VALUE 'I',
      cancelled TYPE c LENGTH 1 VALUE 'X',
    END OF c_status.

ENDINTERFACE.
