# 🔩 Thiết kế CAD — Computer-Aided Design

> Nhánh `feature/cad` — File STEP thiết kế cơ khí Stewart Platform CKAS W2

---

## Danh sách file STEP

### Chi tiết bàn máy CKAS

| File | Mã | Mô tả |
|---|---|---|
| `P-CKAS-001.SIM_Default_sldprt.STEP` | P-001 | Base frame (khung đáy cố định) |
| `P-CKAS-002.SIM_Default_sldprt.STEP` | P-002 | Platform (bàn trên động) |
| `P-CKAS-003.SIM_Default_sldprt.STEP` | P-003 | Tay quay servo L1 |
| `P-CKAS-004.SIM_Default_sldprt.STEP` | P-004 | Thanh nối L2 (connecting rod) |
| `P-CKAS-005.simulation.SIM_Default_sldprt.STEP` | P-005 | Khâu trung gian (simulation body) |
| `P-CKAS-006.SIM_Default_sldprt.STEP` | P-006 | Giá đỡ servo |
| `P-CKAS-007.SIM_Default_sldprt.STEP` | P-007 | Liên kết đáy |
| `P-CKAS-008.SIM_Default_sldprt.STEP` | P-008 | Liên kết platform |
| `P-CKAS-009.SIM_Default_sldprt.STEP` | P-009 | Nắp bảo vệ |
| `P-CKAS-010.SIM_Default_sldprt.STEP` | P-010 | Tổng hợp chi tiết phụ |

### Khớp & tiêu chuẩn

| File | Mô tả |
|---|---|
| `MAB180-L1-35-114.3-200-M12-82.SIM_Default_sldprt.STEP` | Khớp cầu MAB Ø35, M12, L=200mm |
| `HNT1-ST-MS20.SIM_Default_sldprt.STEP` | Khớp quay HNT1, trục M20 |
| `HNTL1N-STU-M20_214.SIM_Default_sldprt.STEP` | Khớp liên kết HNTL1N, L=214mm |
| `F-M20X150Y_Y_joint.SIM_Default_sldprt.STEP` | Khớp chữ Y M20×150 |
| `E-B7204.SIM_Default_sldprt.STEP` | Vòng bi góc tiếp xúc B7204 |
| `E-GYN20_b.SIM_Default_sldprt.STEP` | Gối trượt GYN20 (thân) |
| `E-GYN20_h.SIM_Default_sldprt.STEP` | Gối trượt GYN20 (nắp) |
| `PWF20.SIM_Default_sldprt.STEP` | Bu lông cánh M20 |
| `SLW20.SIM_Default_sldprt.STEP` | Vít lục giác M20 |
| `hg-sr202b.SIM_Default_sldprt.STEP` | Thanh trượt HG-SR202B |

### Mô hình ergonomic

| File | Mô tả |
|---|---|
| `Articulated_Dummy.SIM_Default_sldprt.STEP` | Nộm khớp đa khúc |
| `SittingManActualSizeSmallFile.STEP` | Người ngồi kích thước thực |

---

## Thông số hình học (tham chiếu)

| Thông số | Giá trị | Đơn vị |
|---|---|---|
| `ra` — bán kính đế | 589.66 | mm |
| `rb` — bán kính bàn máy | 429.566 | mm |
| `L1` — tay quay servo | 150 | mm |
| `L2` — thanh nối | 747 | mm |

---

Xem **[USAGE.md](USAGE.md)** để import vào Simscape hoặc FreeCAD.
