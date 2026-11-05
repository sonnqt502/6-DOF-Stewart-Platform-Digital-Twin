# 🔩 Nhánh: `feature/cad`

> **Chủ đề:** File thiết kế CAD (định dạng STEP) của toàn bộ các chi tiết cơ khí trong cơ cấu Stewart Platform CKAS W2.

---

## Nội dung nhánh

Nhánh này chứa tất cả **file STEP (.STEP)** xuất từ SolidWorks, dùng để import vào Simscape Multibody hoặc các phần mềm CAD khác (Fusion 360, FreeCAD, v.v.).

> [!NOTE]
> Các file STEP là file nhị phân lớn. Nếu repo chưa dùng Git LFS, nên cân nhắc bật Git LFS cho extension `.STEP` trước khi push.

---

## Danh sách chi tiết CAD

### Cấu trúc bàn máy CKAS

| File STEP | Mã chi tiết | Mô tả |
|---|---|---|
| `P-CKAS-001.SIM_Default_sldprt.STEP` | P-CKAS-001 | Base frame (khung đáy) |
| `P-CKAS-002.SIM_Default_sldprt.STEP` | P-CKAS-002 | Platform (bàn trên) |
| `P-CKAS-003.SIM_Default_sldprt.STEP` | P-CKAS-003 | Cánh tay servo L1 |
| `P-CKAS-004.SIM_Default_sldprt.STEP` | P-CKAS-004 | Thanh nối L2 (connecting rod) |
| `P-CKAS-005.simulation.SIM_Default_sldprt.STEP` | P-CKAS-005 | Khâu trung gian (đã mô phỏng) |
| `P-CKAS-006.SIM_Default_sldprt.STEP` | P-CKAS-006 | Giá đỡ servo |
| `P-CKAS-007.SIM_Default_sldprt.STEP` | P-CKAS-007 | Chi tiết liên kết đáy |
| `P-CKAS-008.SIM_Default_sldprt.STEP` | P-CKAS-008 | Chi tiết liên kết platform |
| `P-CKAS-009.SIM_Default_sldprt.STEP` | P-CKAS-009 | Nắp bảo vệ |
| `P-CKAS-010.SIM_Default_sldprt.STEP` | P-CKAS-010 | Chi tiết phụ tổng hợp |

### Khớp cầu (Spherical Joint)

| File STEP | Mô tả |
|---|---|
| `MAB180-L1-35-114.3-200-M12-82.SIM_Default_sldprt.STEP` | Khớp cầu MAB Ø35, M12, dài 200mm |

### Khớp chữ U / khớp quay (Revolute / Universal Joint)

| File STEP | Mô tả |
|---|---|
| `HNT1-ST-MS20.SIM_Default_sldprt.STEP` | Khớp quay HNT1, trục M20 |
| `HNTL1N-STU-M20_214.SIM_Default_sldprt.STEP` | Khớp liên kết HNTL1N, M20, dài 214mm |
| `F-M20X150Y_Y_joint.SIM_Default_sldprt.STEP` | Khớp chữ Y M20×150 |

### Vòng bi & trục (Bearing & Shaft)

| File STEP | Mô tả |
|---|---|
| `E-B7204.SIM_Default_sldprt.STEP` | Vòng bi góc tiếp xúc B7204 |
| `E-GYN20_b.SIM_Default_sldprt.STEP` | Gối trượt GYN20 (thân) |
| `E-GYN20_h.SIM_Default_sldprt.STEP` | Gối trượt GYN20 (nắp) |

### Chi tiết tiêu chuẩn

| File STEP | Mô tả |
|---|---|
| `PWF20.SIM_Default_sldprt.STEP` | Bu lông cánh M20 (PWF20) |
| `SLW20.SIM_Default_sldprt.STEP` | Vít lục giác M20 (SLW20) |
| `hg-sr202b.SIM_Default_sldprt.STEP` | Thanh trượt HG-SR202B |

### Mô hình người ngồi (Ergonomics)

| File STEP | Mô tả |
|---|---|
| `Articulated_Dummy.SIM_Default_sldprt.STEP` | Nộm khớp đa khúc (crash dummy) |
| `SittingManActualSizeSmallFile.STEP` | Mô hình người ngồi kích thước thực |

---

## Thông số hình học chính (từ Simscape)

| Thông số | Giá trị |
|---|---|
| Bán kính base `ra` | 220 mm |
| Bán kính platform `rb` | 130 mm |
| Chiều dài cánh tay `L1` | 100 mm |
| Chiều dài thanh nối `L2` | 350 mm |
| Góc phân bố base `alpha_a` | 20° |
| Góc phân bố platform `alpha_b` | 10° |

---

## Hướng dẫn import vào Simscape

```matlab
% Import STEP vào Simscape Multibody
smimport('P-CKAS-001.SIM_Default_sldprt.STEP')

% Hoặc dùng SolidWorks Multibody Link → xuất XML trực tiếp
```

---

## Hướng dẫn import vào FreeCAD / Fusion 360

1. Mở FreeCAD → **File → Import → chọn .STEP**
2. Fusion 360 → **Upload → chọn .STEP** → tự động convert
3. Kiểm tra đơn vị: tất cả file xuất theo **milimét (mm)**

---

## Lưu ý Git LFS

Các file STEP thường > 1 MB. Khuyến nghị bật **Git Large File Storage**:

```bash
git lfs install
git lfs track "*.STEP"
git lfs track "*.step"
git add .gitattributes
git commit -m "chore: enable Git LFS for STEP files"
```

---

## Liên kết

- Nhánh `feature/dynamics` — Mô hình Simscape dùng các chi tiết này
- `main` — Cấu hình hình học trong `config.json` và `calc_Geometry.m`
