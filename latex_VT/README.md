# Pivot Point IEEE Paper — Overleaf Upload Guide (v2)

## Cấu trúc thư mục

```
latex_VT/
├── main.tex          ← File LaTeX chính (compile file này)
└── .latexmkrc        ← Config build cho Overleaf

hinhanh_VT/           ← Upload toàn bộ thư mục này lên Overleaf root
├── image1.png        ← Hệ tọa độ và các điểm đặc trưng (từ Pivot_IMU.tex)
├── image2.png        ← Sơ đồ gá đặt IMU và hiệu chuẩn trục
├── image3.png        ← FFT + LPF trước/sau lọc
├── image6.png        ← PCA hiệu chỉnh cross-talk
├── So_do_tien_xu_ly.png  ← Pipeline tiền xử lý tín hiệu
└── fig5_accel_comparison.png  ← So sánh gia tốc đo vs mô hình
```

## Upload lên Overleaf

1. Tạo project mới → **Upload Project** → upload `main.tex`
2. Upload **tất cả file `.png`** trong `hinhanh_VT/` vào **root** của project
3. Compiler: **pdfLaTeX**
4. Compile → xem PDF

## Nguồn số liệu

| Bảng/Hình | Nguồn |
|-----------|-------|
| Table I (params) | Dashboard_Stewart5.m |
| Table II (Roll results) | Pivot_IMU.tex – kết quả thực nghiệm |
| Table III (Pitch results) | Pivot_IMU.tex – kết quả thực nghiệm |
| Fig. FFT/SNR | image3.png – dữ liệu IMU thực |
| Fig. PCA | image6.png – dữ liệu IMU thực |

**Không có số liệu nào bịa đặt.** Tất cả lấy trực tiếp từ `Pivot_IMU.tex`.
