*&---------------------------------------------------------------------*
*& Report ZRET_R_WH_TASK_LIST
*&---------------------------------------------------------------------*
*& ALV display of warehouse tasks.
*&  - empty status: shows all
*&  - given status: filter on Open / Confirmed / Cancelled
*&---------------------------------------------------------------------*
report zret_r_wh_task_list.

parameters p_stat type zret_t_wh_task-status default ''.

class lcl_app definition.
  public section.
    class-methods:
      run
        importing iv_status type zret_t_wh_task-status.
endclass.

class lcl_app implementation.

  method run.
    data lt_tasks type table of zret_t_wh_task.
    data lo_alv   type ref to cl_salv_table.
    data lv_title type lvc_title.

    if iv_status is initial.
      select * from zret_t_wh_task
        into table @lt_tasks
        order by wh_task_num descending.
      lv_title = 'Warehouse Tasks - All'.
    else.
      select * from zret_t_wh_task
        into table @lt_tasks
        where status = @iv_status
        order by wh_task_num descending.
      lv_title = |Warehouse Tasks - Status { iv_status }|.
    endif.

    if lt_tasks is initial.
      message 'No warehouse tasks found' type 'I'.
      return.
    endif.

    try.
        cl_salv_table=>factory(
          importing r_salv_table = lo_alv
          changing  t_table      = lt_tasks
        ).

        lo_alv->get_columns( )->set_optimize( abap_true ).

        try.
            lo_alv->get_columns( )->get_column( 'CLIENT' )->set_visible( abap_false ).
          catch cx_salv_not_found.
        endtry.

        lo_alv->get_display_settings( )->set_list_header( lv_title ).
        lo_alv->get_functions( )->set_all( abap_true ).

        lo_alv->display( ).

      catch cx_salv_msg into data(lo_ex).
        message lo_ex->get_text( ) type 'E'.
    endtry.
  endmethod.

endclass.

start-of-selection.
  lcl_app=>run( p_stat ).
