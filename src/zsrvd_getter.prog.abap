*&---------------------------------------------------------------------*
*& Report zsrvd_getter
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zsrvd_getter.

DATA(lv_srvb_name) = CONV sxco_srvb_object_name( 'ZUI_FLIGHT_257_V4' ).
DATA(lv_srvb_name_api) = CONV sxco_srvb_object_name( 'ZSB_ODATA_REGISTRY_A4' ).

TRY.
    " 2. Khởi tạo đối tượng Service Binding
    DATA(lo_service_binding) = xco_abap_repository=>object->srvb->for( lv_srvb_name ).
    DATA(lo_sb) = xco_abap_repository=>object->srvb->for( lv_srvb_name_api ).
    " 3. Lấy thông tin cấu hình cơ bản (Binding Type / Protocol)
    DATA(lo_content) = lo_service_binding->content( ).
    DATA(lo_debug) = lo_content->get( ).
    DATA(lo_binding_type) = lo_content->get_binding_type( ).
    DATA(lv_srvd_type_str) = CONV string( lo_binding_type->value ).
    DATA(lo_bd) = lo_sb->content(  ).
    DATA(lo_bd_type) = lo_bd->get_binding_type(  ).
      WRITE |--- Thong tin Service Binding: { lv_srvb_name } ---| .

    WRITE |+ Binding Type / Protocol : { lv_srvd_type_str }| .
    WRITE |---------------------------------------------------------|.

    " 4. Đọc danh sách các Service được gắn bên trong thông qua API chuẩn
    DATA(lt_services) = lo_service_binding->services->all->get( ).

    " 5. Vòng lặp xuất ra các Service Definition (SRVD) được map
    LOOP AT lt_services INTO DATA(ls_service).
      DATA(lv_srvd_name) = ls_service->name.
      DATA(lv_srvd_version) = ls_service->versions->all->get(  ).
      WRITE: / lv_srvd_name.
      LOOP AT lv_srvd_version INTO DATA(ls_version).
        WRITE: / ls_version->version.
      ENDLOOP.
    ENDLOOP.

  CATCH cx_xco_runtime_exception INTO DATA(lx_exception).
    " Nếu Service Binding không tồn tại hoặc có lỗi, hệ thống sẽ quăng Exception vào đây
    WRITE 'Khong the doc du lieu (Co the object khong ton tai).' .
    WRITE lx_exception->get_text( ) .
ENDTRY.
