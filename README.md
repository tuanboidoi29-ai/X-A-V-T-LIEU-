# AntiFly

Plugin Paper `1.0.0` phat hien va canh bao nguoi choi co dau hieu bay bat thuong.

## Build

```bash
mvn package
```

File plugin duoc tao tai `target/anti-fly-1.0.0.jar`. Chep file nay vao thu muc `plugins/` cua server Paper 1.21.1.

## Quyen

Nguoi choi co quyen `antifly.alert` (mac dinh la operator) se nhan duoc canh bao. Nguong phat hien co the chinh trong `plugins/AntiFly/config.yml`.

## SketchUp extension

Extension: **TT - Xóa vật liệu**  
Version: **1.0.0**  
Creator: **TRẦN TUẤN**

### Chức năng

- Loader đăng ký bằng `SketchupExtension` và tự xuất hiện trong menu `Extensions`.
- Giao diện tiếng Việt bằng `UI::HtmlDialog`, chỉ mở khi người dùng gọi công cụ.
- Xóa vật liệu hiện tại khỏi mặt trước, mặt sau, group và component đang chọn.
- Mỗi nút đều gọi callback Ruby: xóa vật liệu, làm mới trạng thái và kiểm tra cập nhật.
- Tạo một operation duy nhất để có thể hoàn tác bằng `Ctrl + Z`.
- Có icon SVG dùng cho nhận diện extension và toolbar.

### Cài đặt RBZ

1. Mở SketchUp > `Extension Manager` > `Install Extension`.
2. Chọn file `TT-XoaVatLieu-1.0.0.rbz`.
3. Vào `Extensions > TT - Xóa vật liệu`.
4. Chọn vật liệu trong bảng Materials, chọn mặt/group/component, rồi bấm `Xóa vật liệu đang chọn`.

### Cập nhật không khởi động lại

Callback `Kiểm tra bản cập nhật` đã có sẵn. Để bật máy chủ cập nhật, điền URL manifest JSON vào `UPDATE_MANIFEST_URL` trong `tt_xoa_vat_lieu/main.rb`. Manifest có dạng:

```json
{"version":"1.0.1","url":"https://example.com/TT-XoaVatLieu-1.0.1.rbz"}
```

Việc xóa vật liệu không tự động diễn ra trên toàn model; chỉ các đối tượng người dùng đã chọn mới bị thay đổi.
