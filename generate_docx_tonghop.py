import os
from docx import Document
from docx.shared import Pt
from docx.enum.text import WD_PARAGRAPH_ALIGNMENT

doc = Document()

# Define styles
style = doc.styles['Normal']
font = style.font
font.name = 'Times New Roman'
font.size = Pt(13)

# Title
title = doc.add_paragraph()
title.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER
run = title.add_run('DÀN Ý CHI TIẾT ĐỒ ÁN TỐT NGHIỆP\n(BẢN CẬP NHẬT TOÀN DIỆN)')
run.bold = True
run.font.size = Pt(16)

title2 = doc.add_paragraph()
title2.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER
run2 = title2.add_run('Đề tài: Nghiên cứu thiết kế cơ khí, mô phỏng Digital Twin và ứng dụng cảm biến trong hiệu chuẩn hệ thống mô phỏng lái Stewart Platform 6-RUS')
run2.bold = True
run2.font.size = Pt(14)

doc.add_paragraph('Mục tiêu số trang: 80 - 100 trang (không bao gồm Lời cảm ơn, Phụ lục, Tài liệu tham khảo)\n')

content = """
PHẦN MỞ ĐẦU (Dự kiến: 3 - 4 trang)
1. Tính cấp thiết của đề tài
- Nhu cầu về các hệ thống mô phỏng lái xe (Driving Simulator) chân thực, độ phản hồi cao.
- Ưu điểm của bệ động 6 bậc tự do cấu trúc 6-RUS so với các bệ dẫn động tịnh tiến truyền thống.
- Yêu cầu cấp thiết về một giải pháp toàn diện: từ đảm bảo an toàn cơ khí, mô phỏng số hóa (Digital Twin) để tránh va chạm, cho đến đo lường và bù trừ sai số hệ thống bằng tín hiệu cảm biến thực tế.
2. Mục tiêu nghiên cứu
- Thiết kế và kiểm bền cơ khí bệ động 6-RUS chịu tải trọng 200kg.
- Giải bài toán động học thuận/ngược và phân tích không gian làm việc an toàn.
- Xây dựng phần mềm Digital Twin (MATLAB/Simulink) để mô phỏng kiểm định quỹ đạo.
- Đề xuất thuật toán xử lý tín hiệu IMU nhằm tìm tâm quay (Pivot) thực tế của hệ thống.
3. Đối tượng và phạm vi nghiên cứu
4. Phương pháp nghiên cứu 
- Phương pháp phần tử hữu hạn FEM.
- Phương pháp mô phỏng số.
- Phương pháp thực nghiệm đo đạc và xử lý dữ liệu.
5. Ý nghĩa khoa học và thực tiễn

CHƯƠNG 1: TỔNG QUAN VỀ HỆ THỐNG MÔ PHỎNG LÁI XE VÀ BỆ ĐỘNG STEWART (Dự kiến: 10 - 15 trang)
1.1. Giới thiệu chung về hệ thống mô phỏng lái xe (Driving Simulators)
1.2. Tổng quan về bệ động 6 bậc tự do (6-DOF Stewart Platform)
- Phân tích bậc tự do (Surge, Sway, Heave, Roll, Pitch, Yaw).
- So sánh các kết cấu dẫn động: Dẫn động tịnh tiến (UPS) và dẫn động quay (RUS).
1.3. Cấu trúc 6-RUS (Revolute-Universal-Spherical) ứng dụng trong đề tài
- Đặc điểm cấu tạo, ưu điểm trong việc chế tạo và bảo dưỡng.
1.4. Tình hình nghiên cứu trong và ngoài nước
1.5. Kết luận Chương 1

CHƯƠNG 2: THIẾT KẾ CẤU TRÚC CƠ KHÍ VÀ KIỂM BỀN TĨNH (Dự kiến: 15 - 20 trang)
2.1. Yêu cầu nhiệm vụ và Phân tích cấu trúc hệ thống
- Tính toán bậc tự do theo công thức Chebychev-Grübler-Kutzbach.
- Yêu cầu hành trình (X, Y, Z, Roll, Pitch, Yaw) và tải trọng (200 kg).
2.2. Thiết kế chi tiết cơ khí (Mô hình CAD 3D)
- Thiết kế Đế (Base), Tay quay ngắn (Short link), Trục dài (Long link), Bệ di động (Platform), Chốt, Khớp cầu (Spherical Joint), Khớp chữ Y.
2.3. Phân tích và kiểm bền tĩnh bằng phần tử hữu hạn (FEM)
2.3.1. Thiết lập dữ liệu đầu vào và các giả thiết (vật liệu thép CT3, trọng lực -Z, v.v.).
2.3.2. Kiểm bền cụm Bệ di động (Platform) - Phân tích ứng suất Von Mises và hệ số an toàn.
2.3.3. Kiểm bền cụm thanh truyền dài (chịu lực uốn, nén dọc trục).
2.3.4. Kiểm bền chốt và khớp cầu ở các góc tới hạn.
2.3.5. Kiểm bền tay quay động cơ.
2.4. Kết luận Chương 2

CHƯƠNG 3: CƠ SỞ TOÁN HỌC VÀ ĐỘNG HỌC HỆ THỐNG (Dự kiến: 15 - 20 trang)
3.1. Các hệ tọa độ và phép biến đổi thuần nhất
- Ma trận xoay (Rotation Matrix) và quy ước góc Euler.
3.2. Bài toán Động học ngược (Inverse Kinematics)
- Thiết lập phương trình toán học xác định 6 góc quay động cơ từ tọa độ mong muốn.
3.3. Bài toán Động học thuận (Forward Kinematics)
- Sự phức tạp của cơ cấu vòng kín và phương pháp số giải bài toán (Newton-Raphson).
3.4. Phân tích không gian hoạt động (Workspace Analysis)
3.4.1. Ma trận Jacobi và thuật toán phát hiện điểm kỳ dị (Singularity loci).
3.4.2. Khảo sát các giới hạn vật lý: Giới hạn góc quay động cơ, nguy cơ va chạm cơ khí giữa các khâu.
3.4.3. Quét không gian làm việc an toàn 3D (Đám mây điểm Workspace).
3.5. Kết luận Chương 3

CHƯƠNG 4: XÂY DỰNG HỆ THỐNG MÔ PHỎNG SỐ (DIGITAL TWIN) (Dự kiến: 15 - 20 trang)
4.1. Kiến trúc hệ thống Digital Twin
- Sự kết hợp giữa động học lập trình (MATLAB) và mô hình vật lý ảo (Simulink/Simscape).
4.2. Xây dựng mô hình vật lý trên Simulink / Simscape Multibody
- Tối ưu hóa file CAD và xuất cấu trúc sang XML định dạng Simscape.
- Ghép nối tín hiệu điều khiển góc quay vào các khớp Revolute Joints trong sơ đồ khối Simulink.
4.3. Thiết kế phần mềm điều khiển trung tâm (Dashboard_Stewart3 GUI)
4.3.1. Tính năng cấu hình hệ thống và tùy chọn/tạo quỹ đạo chuyển động.
4.3.2. Thuật toán Safety Check: Cơ chế bảo vệ 3 lớp (Kiểm tra phần cứng, giới hạn góc xoay, điểm kỳ dị) trước khi cho phép mô phỏng.
4.3.3. Giao diện trực quan hóa, đồng bộ mô phỏng 3D thời gian thực và xuất dữ liệu quỹ đạo 15 tham số.
4.4. Đánh giá sai lệch mô phỏng số
- So sánh quỹ đạo lý thuyết của phần mềm GUI và độ phản hồi thực tế đo trên Simscape (sai số < 1%).
4.5. Kết luận Chương 4

CHƯƠNG 5: THỰC NGHIỆM ĐO ĐẠC VÀ XỬ LÝ TÍN HIỆU CẢM BIẾN IMU (Dự kiến: 15 - 20 trang)
5.1. Đặt vấn đề: Xác định tâm quay (Pivot Calibration) thực tế
- Ảnh hưởng của sai lệch tâm quay tới cảm giác lái và cần thiết phải bù trừ sai số thực tế.
5.2. Cơ sở lý thuyết xử lý tín hiệu vật rắn
- Mối liên hệ giữa gia tốc hướng tâm, gia tốc tiếp tuyến, vận tốc góc và khoảng cách (Offset r_x, r_y, r_z).
5.3. Quy trình đo lường thực nghiệm
- Gá đặt IMU lên đầu người lái (hình nhân), chạy quỹ đạo Pitch và Roll độc lập. Thu thập dữ liệu IMU và xuất dữ liệu mô phỏng đối chứng.
5.4. Các phương pháp xử lý nhiễu và sai số
5.4.1. Lọc nhiễu tần số cao: Ứng dụng FFT tìm tần số cắt và sử dụng bộ lọc thông thấp (Low-Pass Filter) cho tín hiệu gia tốc. Tính toán gia tốc góc qua đạo hàm.
5.4.2. Bù trừ sai lệch gá đặt (Misalignment Calibration): Sử dụng thuật toán PCA (Principal Component Analysis) và ma trận quay để căn chỉnh lại hệ tọa độ cảm biến vuông góc với trọng lực và đúng hướng chuyển động.
5.5. Xác định khoảng cách Offset bằng Bình phương tối thiểu (Least Squares)
- Tính toán Least Squares tổng hợp nhiều chu kì sóng để giải hệ phương trình khoảng cách trục XYZ.
- Đánh giá thuật toán: Phân tích chỉ số sai số RMSE và hệ số tương quan Pearson (>0.96).
5.6. Kết luận Chương 5

KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN (Dự kiến: 2 - 3 trang)
1. Kết quả đạt được của đề tài
- Hoàn thiện khép kín từ khâu thiết kế cơ khí, lập trình động học, mô phỏng Digital Twin đến xử lý tín hiệu thực nghiệm phần cứng.
2. Những hạn chế còn tồn tại
- Chưa kiểm soát triệt để các biến dạng động lực học phi tuyến, độ trễ thời gian thực.
3. Hướng phát triển trong tương lai
- Áp dụng MPC (Model Predictive Control) kết hợp Washout filter cải tiến.
- Triển khai Hardware-in-the-loop (HIL).

TÀI LIỆU THAM KHẢO
PHỤ LỤC
- Phụ lục A: Bản vẽ thiết kế cơ khí (Bản vẽ bóc tách một số chi tiết).
- Phụ lục B: Hướng dẫn cài đặt và sử dụng phần mềm Digital Twin (Dashboard).
- Phụ lục C: Mã nguồn một số hàm trọng yếu (Thuật toán PCA, Inverse Kinematics, Lọc nhiễu).
"""

for line in content.split('\n'):
    line_s = line.strip()
    if line_s.startswith('PHẦN') or line_s.startswith('CHƯƠNG') or line_s.startswith('KẾT LUẬN') or line_s.startswith('TÀI LIỆU') or line_s.startswith('PHỤ LỤC'):
        p = doc.add_paragraph()
        r = p.add_run(line_s)
        r.bold = True
    elif line_s.startswith('1.') or line_s.startswith('2.') or line_s.startswith('3.') or line_s.startswith('4.') or line_s.startswith('5.'):
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Pt(12)
        r = p.add_run(line_s)
        r.bold = True
    elif any(line_s.startswith(f"{c}.{n}.") for c in range(1,6) for n in range(1,7)):
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Pt(24)
        r = p.add_run(line_s)
        r.bold = True
    elif line_s.startswith('-') or any(line_s.startswith(f"{c}.{n}.{sub}.") for c in range(1,6) for n in range(1,7) for sub in range(1,6)):
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Pt(36)
        r = p.add_run(line_s)
    else:
        if line_s:
            doc.add_paragraph(line_s)

doc.save('Dan_y_do_an_CKAS_W2_TongHop.docx')
print('Created Dan_y_do_an_CKAS_W2_TongHop.docx')
