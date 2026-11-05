# Hướng dẫn sử dụng — CAD

## 1. Import STEP vào Simscape Multibody (MATLAB)

```matlab
% Import một chi tiết
smimport('P-CKAS-003.SIM_Default_sldprt.STEP')

% Hoặc import assembly từ SolidWorks XML (khuyến nghị)
smimport('Final_CKASForSIM30_11_SIM_multibody.xml')
```

## 2. Import vào FreeCAD

1. Mở FreeCAD → **File → Import**
2. Chọn file `.STEP`
3. Kiểm tra đơn vị: **File → Preferences → Units → mm**

## 3. Import vào Autodesk Fusion 360

1. Fusion 360 → **Data panel → Upload**
2. Chọn file `.STEP` → **Open**
3. Fusion tự động convert sang format nội bộ

## 4. Import vào Onshape (online, miễn phí)

1. Tạo document mới
2. **Insert → Import file** → Upload `.STEP`

---

## Mapping chi tiết ↔ Simscape Body

| STEP File | Simscape Rigid Body | Khớp |
|---|---|---|
| `P-CKAS-001` | World Frame + Base Plate | Cố định (Weld) |
| `P-CKAS-002` | Platform Body | 6× Spherical Joint |
| `P-CKAS-003` | Servo Arm (×6) | 6× Revolute Joint |
| `P-CKAS-004` | Connecting Rod (×6) | 6× Cylindrical |
| `MAB180-...` | Spherical joint body | Spherical |

---

## Git LFS (khuyến nghị cho file STEP lớn)

Các file STEP > 50 MB nên dùng Git Large File Storage:

```bash
git lfs install
git lfs track "*.STEP"
git lfs track "*.step"
git add .gitattributes
git commit -m "chore: enable Git LFS for STEP files"
git push origin feature/cad
```

---

## Lưu ý

- Tất cả file STEP xuất từ **SolidWorks 2023**, đơn vị **millimét**.
- Suffix `.SIM_Default_sldprt` là do SolidWorks Simulation tự thêm vào khi export — không ảnh hưởng nội dung.
- File `Articulated_Dummy` và `SittingManActualSizeSmallFile` dùng để kiểm tra ergonomics, không tham gia tính toán động lực học.
