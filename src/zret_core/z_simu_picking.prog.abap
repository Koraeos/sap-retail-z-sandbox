*&---------------------------------------------------------------------*
*& Report Z_SIMU_PICKING
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*

REPORT z_simu_picking.

PARAMETERS: p_stock TYPE i OBLIGATORY DEFAULT 80,
            p_qty_t TYPE i OBLIGATORY DEFAULT 15.

DATA: lv_stock_rest   TYPE i,
      lv_num_task     TYPE i,
      lv_total_picked TYPE i,
      lv_qty_to_pick  TYPE i. " Variable pour la quantité réelle de la tâche

START-OF-SELECTION.

  lv_stock_rest   = p_stock.
  lv_num_task     = 1.
  lv_total_picked = 0.

  WHILE lv_stock_rest > 0.

    IF lv_stock_rest >= p_qty_t.
      lv_qty_to_pick = p_qty_t.
    ELSE.
      lv_qty_to_pick = lv_stock_rest.
    ENDIF.

    lv_stock_rest = lv_stock_rest - lv_qty_to_pick.
    lv_total_picked = lv_total_picked + lv_qty_to_pick.

    WRITE: / 'WT n°', lv_num_task,
             ': prélevé', lv_qty_to_pick,
             'unités | stock restant :', lv_stock_rest.

    lv_num_task = lv_num_task + 1.

  ENDWHILE.

ULINE.
  WRITE: / 'Simulation terminée. Total prélevé :', lv_total_picked.
