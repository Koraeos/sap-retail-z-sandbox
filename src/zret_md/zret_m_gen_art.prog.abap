report zret_m_gen_art.

data: gv_id          type zret_t_gen_art-generic_article_id,
      gv_name        type zret_t_gen_art-generic_name,
      gv_type        type zret_t_gen_art-article_type,
      gv_base_uom    type zret_t_gen_art-base_uom,
      gv_description type zret_t_gen_art-description.

data: ok_code    type sy-ucomm,
      gv_save_ok type sy-ucomm.

start-of-selection.
  call screen 9000.

module status_9000 output.
  set pf-status 'STATUS_9000'.
  set titlebar  'TITLE_9000'.
endmodule.

module user_command_9000 input.
  gv_save_ok = ok_code.
  clear ok_code.

  case gv_save_ok.
    when 'SAVE' or 'EXECUTE'.
      perform save_record.

    when 'DISPLAY'.
      perform load_record.

    when 'DELETE'.
      perform delete_record.

    when 'RESET' or 'CANCEL'.
      perform reset_screen.

    when 'BACK' or 'EXIT'.
      leave program.

  endcase.
endmodule.

form save_record.
  if gv_id is initial or gv_name is initial.
    message 'Generic ID and Name are required' type 'E'.
    exit.
  endif.

  data lv_exists type abap_bool value abap_false.

  " Vérifie si l'enregistrement existe (sans planter sur not-found)
  try.
      data(ls_existing) = zcl_ret_generic_art=>get_by_id( gv_id ).
      if ls_existing-generic_article_id is not initial.
        lv_exists = abap_true.
      endif.
    catch zcx_ret_core.
      " Not found est ok, lv_exists reste false → on créera
  endtry.

  " Save proprement dit
  try.
      if lv_exists = abap_true.
        zcl_ret_generic_art=>update(
          iv_id          = gv_id
          iv_name        = gv_name
          iv_description = gv_description
        ).
        message |Generic Article { gv_id } updated successfully| type 'S'.
      else.
        zcl_ret_generic_art=>create(
          iv_id          = gv_id
          iv_name        = gv_name
          iv_type        = gv_type
          iv_base_uom    = gv_base_uom
          iv_description = gv_description
        ).
        message |Generic Article { gv_id } created successfully| type 'S'.
      endif.
    catch zcx_ret_core into data(lx_error).
      message lx_error->get_text( ) type 'E'.
  endtry.
endform.

form load_record.
  if gv_id is initial.
    message 'Please enter a Generic Article ID first' type 'E'.
    exit.
  endif.

  try.
      data(ls_record) = zcl_ret_generic_art=>get_by_id( gv_id ).

      if ls_record-generic_article_id is initial.
        message |Generic Article { gv_id } not found| type 'W'.
        exit.
      endif.

      gv_name        = ls_record-generic_name.
      gv_type        = ls_record-article_type.
      gv_base_uom    = ls_record-base_uom.
      gv_description = ls_record-description.
      message |Loaded { gv_id }| type 'S'.

    catch zcx_ret_core.
      message 'Error loading generic article' type 'E'.
  endtry.
endform.

form delete_record.
  if gv_id is initial.
    message 'Please enter a Generic Article ID first' type 'E'.
    exit.
  endif.

  try.
      zcl_ret_generic_art=>deactivate( gv_id ).
      message |Generic Article { gv_id } deactivated| type 'S'.
      perform reset_screen.
    catch zcx_ret_core.
      message 'Cannot deactivate (active variants exist?)' type 'E'.
  endtry.
endform.

form reset_screen.
  clear: gv_id, gv_name, gv_type, gv_base_uom, gv_description.
endform.
