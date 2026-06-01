*&---------------------------------------------------------------------*
*& Report znamespace
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT znamespace.

DATA: lv_srvb_name TYPE tadir-obj_name,
      lv_package   TYPE tadir-devclass,
      lv_namespace TYPE tdevc-namespace.

" Gán tên Service Binding cần kiểm tra (Viết hoa hoàn toàn)
lv_srvb_name = 'ZUI_FLIGHT_257_V4'.

" Thực hiện Join 2 bảng hệ thống để bốc đầu Package và Namespace cùng lúc
SELECT SINGLE a~devclass, b~namespace
  FROM tadir AS a
  INNER JOIN tdevc AS b ON a~devclass = b~devclass
  INTO ( @lv_package, @lv_namespace )
  WHERE a~pgmid    = 'R3TR'
    AND a~object   = 'SRVB'
    AND a~obj_name = @lv_srvb_name.

IF sy-subrc = 0.
  " Chúc mừng bạn đã lấy thông tin thành công!
  " lv_package: Tên Package (Ví dụ: Z_MY_PACK)
  " lv_namespace: Namespace hệ thống nếu có (Ví dụ: /COMPANY/)
   write : / lv_package.
ELSE.
  " Xử lý lỗi: Service Binding này không tồn tại trong hệ thống SAP hiện tại
  write: / 'lỗi'.
ENDIF.
