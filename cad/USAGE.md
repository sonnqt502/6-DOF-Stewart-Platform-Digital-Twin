# Hướng dẫn kỹ thuật — Nhập và Quản lý Mô hình CAD vào MATLAB Simulink

> **Tham chiếu chuẩn:** Mục 4.1 (Trang 60–63), Đồ án tốt nghiệp *ĐATN_NQTS.pdf*.

---

## 1. Yêu cầu môi trường

- **Phần mềm thiết kế:** SOLIDWORKS (phiên bản 2021 trở lên).
- **Add-In bắt buộc:** MATLAB Simscape Multibody Link (phải cùng phiên bản hoặc tương thích với MATLAB).
- **Phần mềm tính toán mô phỏng:** MATLAB & Simulink (tích hợp toolbox Simscape Multibody).

---

## 2. Quy trình thao tác chi tiết từng bước

### Bước 1: Chuẩn bị mô hình lắp ráp tĩnh trong SolidWorks

1. Mở cụm lắp ráp con (sub-assembly) trong SolidWorks.
2. Vào **File $\rightarrow$ Save As**.
3. Chọn mục **Save as copy and continue**.
4. Tại ô **Save as type**, chọn định dạng Part: **`*.prt`** hoặc **`*.sldprt`**.
5. Bấm **Save**.  
   *(Lưu ý: Bắt buộc lưu tất cả các file đã chuyển đổi vào cùng một thư mục).*
6. Tạo một tệp lắp ráp tổng thể (**`SolidAssembly`**) mới bằng cách ghép các chi tiết Part tĩnh vừa xuất.

### Bước 2: Xuất mô hình sang tệp tin cấu trúc .xml

1. Trong SolidWorks, mở menu **Tools $\rightarrow$ Add-Ins...**
2. Tìm tiện ích **Simscape Multibody Link** và tích chọn ô kiểm. Bấm **OK**.
3. Vào menu **Tools $\rightarrow$ Simscape Multibody Link $\rightarrow$ Export $\rightarrow$ Simscape Multibody...**
4. Chọn thư mục lưu trữ và đặt tên tệp tin `.xml`.
5. SolidWorks sẽ tự động xuất tệp cấu trúc `.xml` và các tệp hình học đi kèm vào cùng thư mục.

### Bước 3: Nhập mô hình vào MATLAB Simulink

1. Mở phần mềm MATLAB và chuyển thư mục làm việc hiện tại (`Current Folder`) về đúng thư mục chứa tệp `.xml`.
2. Tại cửa sổ Command Window của MATLAB, chạy lệnh:

```matlab
smimport('Tên_file.xml')
```

*(Ví dụ: `smimport('Final_CKASForSIM30_11_SIM_multibody.xml')`)*

3. MATLAB sẽ tự động sinh ra một file mô hình Simulink mới chứa đầy đủ các khối chức năng (`World Frame`, `Mechanism Configuration`, `Transform`, `Revolute Joint`, `Spherical Joint`).

---

## 3. Cấu hình khối chức năng sau khi Import

- **Cấu hình Trọng lực:** Mở khối `Mechanism Configuration`, đảm bảo thông số vector trọng trường là `[0, 0, -9.81]` với đơn vị `m/s^2`.
- **Đo lường góc và vận tốc góc khớp động cơ:** Mở khối `Revolute Joint` tương ứng của từng chân $\rightarrow$ chuyển sang thẻ **Sensing** $\rightarrow$ tích chọn **Position** và **Velocity** để đưa tín hiệu ra Scope hoặc Workspace.
- **Truyền động khớp:** Tại thẻ **Actuation**, thiết lập **Motion: Provided by Input** để nạp dữ liệu góc quay $\phi_i(t)$ được tính toán từ chương trình động học ngược.

---

## 4. Các lỗi thường gặp và cách khắc phục

| Hiện tượng lỗi | Nguyên nhân | Cách xử lý chuẩn theo ĐATN |
|---|---|---|
| Lệnh `smimport` báo lỗi không tìm thấy file hình học | Các file hình học phụ trợ nằm khác thư mục với file `.xml` | Đảm bảo file `.xml` và toàn bộ các tệp Part `.sldprt` / `.STEP` nằm trong cùng một thư mục làm việc của MATLAB |
| Bộ giải Simulink chạy chậm hoặc báo lỗi Algebraic Loop | Mô hình lắp ráp SolidWorks còn chứa các ràng buộc Mate tĩnh thừa | Thực hiện đúng Bước 1: Lưu các cụm sub-assembly thành Part đơn khối trước khi xuất `.xml` |
| Báo lỗi cú pháp khi gõ `smimport('*.STEP')` | Lệnh `smimport` chỉ hỗ trợ định dạng `.xml` | Không dùng `smimport` cho file `.STEP`. File `.STEP` được Simscape gọi gián tiếp qua file `.xml` |
