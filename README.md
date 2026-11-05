# 🔩 Chuyên đề CAD & Mô hình 3D SolidWorks — Simscape Multibody

> **Nhánh:** `feature/cad`  
> **Tài liệu đối chiếu:** Đồ án tốt nghiệp *ĐATN_NQTS.pdf* (Chương 2: Thiết kế hệ thống cơ khí & Chương 4.1: Mô phỏng bằng Matlab Simulink).

---

## 📌 Mục lục

- [1. Danh mục các chi tiết cơ khí và kiểm bền (Chương 2)](#1-danh-mục-các-chi-tiết-cơ-khí-và-kiểm-bền-chương-2)
- [2. Quy trình chuẩn bị và chuyển đổi CAD sang Simulink (Mục 4.1)](#2-quy-trình-chuẩn-bị-và-chuyển-đổi-cad-sang-simulink-mục-41)
  - [2.1. Bước 1 đến Bước 4: Tối giản hóa mô hình trên SolidWorks](#21-bước-1-đến-bước-4-tối-giản-hóa-mô-hình-trên-solidworks)
  - [2.2. Xuất tệp cấu trúc .xml bằng Simscape Multibody Link](#22-xuất-tệp-cấu-trúc-xml-bằng-simscape-multibody-link)
  - [2.3. Lệnh nhập vào MATLAB bằng smimport](#23-lệnh-nhập-vào-matlab-bằng-smimport)
- [3. Bảng tổng hợp kiểm bền các chi tiết (Bảng 2-1)](#3-bảng-tổng-hợp-kiểm-bền-các-chi-tiết-bảng-2-1)
- [4. Danh mục các tệp 3D trong thư mục](#4-danh-mục-các-tệp-3d-trong-thư-mục)

---

## 1. Danh mục các chi tiết cơ khí và kiểm bền (Chương 2)

Hệ thống cơ cấu Stewart Platform 6-RUS CKAS W2 được thiết kế 3D trên **SOLIDWORKS** và phân tích ứng suất tĩnh bằng **SOLIDWORKS Simulation**:

1. **Bệ cố định (Base):** Khung thép SS400 chịu lực, lắp đặt 6 động cơ chia thành 3 cặp.
2. **Tay ngắn (Servo Arm $L_1 = 150\text{ mm}$):** Gắn trực tiếp vào trục động cơ, quay quanh trục động cơ tạo chuyển động góc.
3. **Chốt và Khớp chữ Y:** Khớp các-đăng liên kết giữa cánh tay ngắn và thanh truyền dài.
4. **Tay dài (Thanh truyền $L_2 = 747\text{ mm}$):** Ống thép hợp kim 40Cr chịu lực kéo/nén chính trong suốt hành trình.
5. **Khớp cầu (Spherical Joint):** Đầu khớp cầu MAB công nghiệp liên kết đầu thanh truyền dài với bệ động.
6. **Bệ động (Platform):** Tấm nhôm hợp kim nhẹ, nơi lắp đặt cabin, ghế ngồi phi công và vô lăng.

---

## 2. Quy trình chuẩn bị và chuyển đổi CAD sang Simulink (Mục 4.1)

*(Trích xuất nguyên văn kỹ thuật từ Trang 60–63 của ĐATN_NQTS.pdf)*

Mô hình 3D trên SolidWorks được thiết kế với đầy đủ các ràng buộc về ghép nối khớp xoay (*Rotational*) và khớp cầu (*Spherical*). Để đưa mô hình sang Simscape Multibody mà không gây quá tải cho bộ giải Simulink, quy trình tinh chỉnh được thực hiện như sau:

### 2.1. Bước 1 đến Bước 4: Tối giản hóa mô hình trên SolidWorks

Các ràng buộc lắp ráp tĩnh (Mate) không tham gia truyền động như bu lông, đai ốc, hoặc các mối ghép bên trong một cụm assembly con được loại bỏ:
- **Bước 1:** Mở file sub-assembly con lên, vào menu **File $\rightarrow$ Save As**.
- **Bước 2:** Chọn tùy chọn **Save as copy and continue**.
- **Bước 3:** Chọn thư mục cần lưu. Ở dòng *Save as type*, chọn định dạng Part (**`*.prt`** hoặc **`*.sldprt`**), sau đó bấm **Save**.  
  *(Lưu ý: Tất cả các file chuyển đổi phải được Save As ở cùng một thư mục làm việc).*
- **Bước 4:** Tạo một file lắp ráp tổng thể (**`SolidAssembly`**) mới từ những file Part đã chuyển đổi ở trên. Mô hình mới này nhẹ và tối ưu cho quá trình mô phỏng động học/động lực học trong Simulink.

### 2.2. Xuất tệp cấu trúc .xml bằng Simscape Multibody Link

- **Bước 1:** Trong SolidWorks, mở menu **Tools $\rightarrow$ Add-Ins...** (hoặc Options $\rightarrow$ Add-Ins). Tích chọn tiện ích **Simscape Multibody Link**, sau đó bấm **OK**.
- **Bước 2:** Mở menu **Tools $\rightarrow$ Simscape Multibody Link $\rightarrow$ Export $\rightarrow$ Simscape Multibody...**
- Phần mềm sẽ tự động phân tích cây phả hệ liên kết của cơ cấu và xuất ra một tệp tin cấu trúc định dạng **`.xml`** (kèm các tệp khối hình học chi tiết).

### 2.3. Lệnh nhập vào MATLAB bằng smimport

Sau khi xuất file `.xml` từ SolidWorks, tại cửa sổ Command Window của MATLAB, chuyển thư mục làm việc về thư mục chứa file `.xml` và thực thi:

```matlab
smimport('Tên_file.xml')
```

*(Ví dụ: `smimport('Final_CKASForSIM30_11_SIM_multibody.xml')`)*

**Cơ chế hoạt động của MATLAB:**
- Tự động nhận diện cấu trúc lắp ghép từ tệp `.xml` và chuyển đổi thành sơ đồ khối Simulink tương ứng:
  - Khối **World Frame:** Hệ tọa độ toàn cục cố định của hệ thống.
  - Khối **Mechanism Configuration:** Thiết lập tham số vật lý toàn cục (vector gia tốc trọng trường $g = [0, 0, -9.81]\text{ m/s}^2$).
  - Khối **Solver Configuration:** Xác định bộ giải số và dung sai mô phỏng.
  - Khối **Transform:** Định nghĩa phép tịnh tiến và quay 3D giữa các khớp.
  - Khối **Rotational Joint (Revolute):** Mô tả 6 khớp quay của động cơ.
  - Khối **Spherical Joint:** Mô tả 6 khớp cầu tại bệ động.
- Để trích xuất phản hồi vị trí hoặc góc quay, người dùng cấu hình trong thẻ **Sensing** của từng khối khớp nối.

> **Cảnh báo kỹ thuật:** Lệnh `smimport` **không nhận trực tiếp tệp `.STEP`**. Các file `.STEP` là tệp dữ liệu hình học phụ trợ đi kèm do SolidWorks xuất ra, phục vụ việc hiển thị hình dáng ngoài của chi tiết trong Simscape Mechanics Explorer.

---

## 3. Bảng tổng hợp kiểm bền các chi tiết (Bảng 2-1)

Kết quả phân tích phần tử hữu hạn (FEA) trên SOLIDWORKS Simulation trong điều kiện chịu tải khắc nghiệt nhất:

| Chi tiết | Ứng suất Von Mises lớn nhất ($\sigma_{\max}$) | Biến dạng lớn nhất ($\delta_{\max}$) | Hệ số an toàn ($k$) | Kết luận |
|---|---|---|---|---|
| **Bệ động** | $38.18\text{ MPa}$ | $0.102\text{ mm}$ | **$6.15$** | Đạt bền vững |
| **Cụm tay dài ($L_2$)** | $5.693\text{ MPa}$ | $0.003669\text{ mm}$ | **$41.2$** | Đạt bền vững (ổn định dọc trục) |
| **Chốt liên kết** | $14.31\text{ MPa}$ | $0.004798\text{ mm}$ | **$16.4$** | Đạt bền vững |
| **Tay quay ngắn ($L_1$)** | $4.407\text{ MPa}$ | $0.005466\text{ mm}$ | **$53.32$** | Đạt bền vững |

---

## 4. Danh mục các tệp 3D trong thư mục

Các tệp 3D trong thư mục này được xuất từ SolidWorks theo đúng quy trình tinh chỉnh của ĐATN:

- `P-CKAS-001.SIM_Default_sldprt.STEP`: Khung bệ đế cố định.
- `P-CKAS-002.SIM_Default_sldprt.STEP`: Bệ động mâm trên.
- `P-CKAS-003.SIM_Default_sldprt.STEP`: Cánh tay quay động cơ ($L_1 = 150\text{ mm}$).
- `P-CKAS-004.SIM_Default_sldprt.STEP`: Thanh truyền dẫn động ($L_2 = 747\text{ mm}$).
- `P-CKAS-005.simulation.SIM_Default_sldprt.STEP`: Khâu liên kết mô phỏng.
- `P-CKAS-006.SIM_Default_sldprt.STEP` đến `010`: Các tai gá, giá đỡ động cơ và chốt liên kết.
- `MAB180-L1-35-114.3-200-M12-82.SIM_Default_sldprt.STEP`: Đầu khớp cầu MAB công nghiệp.
- `HNT1-ST-MS20.SIM_Default_sldprt.STEP` & `HNTL1N-STU-M20_214`: Khớp nối chịu tải.
- `SittingManActualSizeSmallFile.STEP` & `Articulated_Dummy`: Mô hình kiểm tra nhân trắc học phi công.
