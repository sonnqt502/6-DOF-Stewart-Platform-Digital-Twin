import os
from docx import Document
from docx.shared import Pt
from docx.enum.text import WD_PARAGRAPH_ALIGNMENT

doc = Document()

# Define styles if needed
style = doc.styles['Normal']
font = style.font
font.name = 'Times New Roman'
font.size = Pt(13)

# Title
title = doc.add_paragraph()
title.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER
run = title.add_run('DÀN Ý CHI TIẾT ĐỒ ÁN TỐT NGHIỆP')
run.bold = True
run.font.size = Pt(16)

title2 = doc.add_paragraph()
title2.alignment = WD_PARAGRAPH_ALIGNMENT.CENTER
run2 = title2.add_run('Đề tài: Nghiên cứu thiết kế phần mềm mô phỏng hoạt động của hệ thống mô phỏng lái CKAS W2 6 bậc tự do')
run2.bold = True
run2.font.size = Pt(14)

doc.add_paragraph('Mục tiêu số trang: Tối thiểu 80 trang (không bao gồm Lời cảm ơn, Phụ lục, Tài liệu tham khảo)\n')

# Content
content = """
PHẦN MỞ ĐẦU (Dự kiến: 3 - 4 trang)
1. Tính cấp thiết của đề tài
- Nhu cầu đào tạo lái xe và mô phỏng hiện nay.
- Vai trò của các bệ động (Motion Platforms) đặc biệt là bệ 6 bậc tự do (6-DOF) trong việc tạo cảm giác chân thực.
- Sự cần thiết phải xây dựng một phần mềm mô phỏng hệ thống CKAS W2 để phân tích, đánh giá giới hạn và kiểm định quỹ đạo trước khi vận hành thực tế nhằm đảm bảo an toàn và tối ưu hóa điều khiển.
2. Mục tiêu nghiên cứu
- Tìm hiểu cơ sở lý thuyết về động học bệ Stewart 6 bậc tự do (động học thuận, động học ngược).
- Xây dựng mô hình 3D và không gian mô phỏng bằng Simscape / Simulink.
- Phát triển phần mềm/GUI tích hợp các module đã xây dựng: mô phỏng chuyển động, hiệu chuẩn tâm quay, kiểm tra giới hạn không gian hoạt động.
3. Đối tượng và phạm vi nghiên cứu
- Đối tượng: Hệ thống mô phỏng lái CKAS W2 6 bậc tự do.
- Phạm vi: Phân tích động học, lập trình MATLAB, mô phỏng Simulink/Simscape (không bao gồm phần cứng).
4. Phương pháp nghiên cứu
- Phương pháp phân tích lý thuyết: Phân tích phương trình toán học động học 6-DOF.
- Phương pháp mô phỏng: Sử dụng phần mềm MATLAB/Simulink/Simscape.
- Phương pháp kiểm chứng: So sánh kết quả toán học (động học thuận/ngược) với kết quả mô hình vật lý Simscape.
5. Ý nghĩa khoa học và thực tiễn

CHƯƠNG 1: TỔNG QUAN VỀ HỆ THỐNG MÔ PHỎNG LÁI XE VÀ BỆ ĐỘNG LỤC GIÁC STEWART (Dự kiến: 15 - 18 trang)
1.1. Giới thiệu chung về hệ thống mô phỏng lái xe (Driving Simulators)
1.1.1. Lịch sử phát triển và phân loại
1.1.2. Ứng dụng trong đào tạo, nghiên cứu và giải trí
1.2. Tổng quan về bệ động 6 bậc tự do (6-DOF Stewart Platform)
1.2.1. Cấu trúc cơ bản và nguyên lý hoạt động
1.2.2. Các bậc tự do: Surge, Sway, Heave, Roll, Pitch, Yaw
1.3. Hệ thống mô phỏng lái CKAS W2 6 DOF
1.3.1. Đặc điểm cấu tạo
1.3.2. Các thông số kỹ thuật cơ bản (hành trình xylanh, tải trọng, kích thước)
1.4. Tình hình nghiên cứu trong và ngoài nước
1.4.1. Các nghiên cứu trên thế giới
1.4.2. Các nghiên cứu tại Việt Nam
1.5. Kết luận Chương 1

CHƯƠNG 2: CƠ SỞ LÝ THUYẾT VỀ ĐỘNG HỌC BỆ ĐỘNG 6 BẬC TỰ DO (Dự kiến: 20 - 25 trang)
2.1. Các hệ tọa độ và phép biến đổi tọa độ
2.1.1. Thiết lập hệ tọa độ gốc (Base) và hệ tọa độ bệ động (Platform)
2.1.2. Ma trận biến đổi thuần nhất (Homogeneous Transformation Matrix)
2.1.3. Các góc Euler (Roll, Pitch, Yaw)
2.2. Bài toán động học ngược (Inverse Kinematics)
2.2.1. Phương trình toán học xác định chiều dài các xy-lanh (chân)
2.2.2. Thuật toán giải bài toán động học ngược
2.3. Bài toán động học thuận (Forward Kinematics)
2.3.1. Tính chất phức tạp của bài toán động học thuận
2.3.2. Phương pháp số giải bài toán động học thuận (Newton-Raphson)
2.3.3. Áp dụng giải thuật Newton-Raphson vào hệ thống CKAS W2
2.4. Phân tích không gian hoạt động (Workspace Analysis)
2.4.1. Định nghĩa và phương pháp xác định không gian làm việc
2.4.2. Giới hạn cơ khí (góc khớp Cardan/Universal) và giới hạn hành trình xy-lanh
2.5. Xác định và hiệu chỉnh tâm quay (Center of Rotation Calibration)
2.5.1. Ảnh hưởng của tâm quay đến cảm giác chuyển động
2.5.2. Công thức toán học tịnh tiến tâm quay từ gốc tọa độ
2.6. Kết luận Chương 2

CHƯƠNG 3: THIẾT KẾ VÀ XÂY DỰNG PHẦN MỀM MÔ PHỎNG HỆ THỐNG CKAS W2 (Dự kiến: 25 - 30 trang)
3.1. Phân tích yêu cầu và lựa chọn công cụ
3.1.1. Yêu cầu chức năng của phần mềm (Dashboard, Calibration, Workspace Demo)
3.1.2. Lựa chọn ngôn ngữ MATLAB và công cụ Simulink / Simscape
3.2. Xây dựng mô hình vật lý 3D trong Simscape (Dựa trên Dashboard_stewart3.m)
3.2.1. Thiết lập thông số hình học của Base và Platform
3.2.2. Xây dựng mô hình các khớp nối (Spherical/Universal Joints) và xy-lanh (Prismatic Joints)
3.2.3. Tích hợp tín hiệu điều khiển vào mô hình Simscape
3.3. Thiết kế các module tính toán (Algorithms & Logic)
3.3.1. Module Động học thuận và Động học ngược
3.3.2. Module Kiểm tra cấu hình và giới hạn hành trình xy-lanh
3.3.3. Module Chuyển đổi tọa độ tâm quay (Dựa trên motion_calibration_v1.m)
3.3.4. Module Quét và vẽ không gian hoạt động (Dựa trên kinematic_demo_gui.m)
3.4. Thiết kế Giao diện người dùng (GUI Dashboard)
3.4.1. Kiến trúc giao diện (App Designer / GUIDE)
3.4.2. Thiết kế bảng điều khiển (Control Panel) cho 6 DOF
3.4.3. Đồ thị hiển thị trực quan hóa (Real-time plotting của chiều dài chân và quỹ đạo)
3.5. Ghép nối và đồng bộ hóa giữa GUI và Simulink
3.6. Kết luận Chương 3

CHƯƠNG 4: ĐÁNH GIÁ KẾT QUẢ MÔ PHỎNG VÀ CHẠY THỬ NGHIỆM PHẦN MỀM (Dự kiến: 15 - 20 trang)
4.1. Thiết lập các kịch bản kiểm thử (Test Cases)
4.1.1. Kịch bản chuyển động tịnh tiến thuần túy (Surge, Sway, Heave cực đại)
4.1.2. Kịch bản chuyển động quay thuần túy (Roll, Pitch, Yaw cực đại)
4.1.3. Kịch bản chuyển động phức hợp mô phỏng xe chạy trên đường gồ ghề
4.2. Kết quả kiểm tra giới hạn không gian hoạt động
4.2.1. Biểu đồ đám mây điểm 3D (3D Workspace point cloud) từ kinematic_demo_gui.m
4.2.2. Phân tích các vùng giới hạn và điểm kì dị (Singularity)
4.3. Kết quả đánh giá độ chính xác của động học thuận
4.3.1. So sánh tọa độ tính toán từ thuật toán Newton-Raphson và tọa độ đo được từ Simscape
4.3.2. Phân tích sai số và tốc độ hội tụ của thuật toán
4.4. Đánh giá tính năng hiệu chỉnh tâm quay
4.4.1. Quan sát quỹ đạo bệ động trước và sau khi thay đổi vị trí tâm quay (từ motion_calibration_v1.m)
4.4.2. Đánh giá khả năng tối ưu hóa quỹ đạo để tránh va chạm cơ khí
4.5. Đánh giá tổng quan hiệu năng và tính ổn định của Dashboard
4.6. Kết luận Chương 4

KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN (Dự kiến: 2 - 3 trang)
1. Những kết quả đạt được của đề tài
2. Những hạn chế còn tồn tại
3. Hướng phát triển trong tương lai

TÀI LIỆU THAM KHẢO
PHỤ LỤC
- Phụ lục A: Hướng dẫn cài đặt và sử dụng phần mềm (Dashboard GUI)
- Phụ lục B: Các đoạn mã nguồn MATLAB/Simulink quan trọng
"""

for line in content.split('\n'):
    if line.strip().startswith('PHẦN') or line.strip().startswith('CHƯƠNG') or line.strip().startswith('KẾT LUẬN') or line.strip().startswith('TÀI LIỆU') or line.strip().startswith('PHỤ LỤC'):
        p = doc.add_paragraph()
        r = p.add_run(line.strip())
        r.bold = True
    elif line.strip().startswith('1.') or line.strip().startswith('2.') or line.strip().startswith('3.') or line.strip().startswith('4.'):
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Pt(12)
        r = p.add_run(line.strip())
        r.bold = True
    elif line.strip().startswith('1.1') or line.strip().startswith('1.2') or line.strip().startswith('1.3') or line.strip().startswith('1.4') or line.strip().startswith('1.5') or \
         line.strip().startswith('2.1') or line.strip().startswith('2.2') or line.strip().startswith('2.3') or line.strip().startswith('2.4') or line.strip().startswith('2.5') or line.strip().startswith('2.6') or \
         line.strip().startswith('3.1') or line.strip().startswith('3.2') or line.strip().startswith('3.3') or line.strip().startswith('3.4') or line.strip().startswith('3.5') or line.strip().startswith('3.6') or \
         line.strip().startswith('4.1') or line.strip().startswith('4.2') or line.strip().startswith('4.3') or line.strip().startswith('4.4') or line.strip().startswith('4.5') or line.strip().startswith('4.6'):
         p = doc.add_paragraph()
         p.paragraph_format.left_indent = Pt(24)
         r = p.add_run(line.strip())
         r.bold = True
    elif line.strip().startswith('-') or line.strip().startswith('3.2.1') or line.strip().startswith('3.2.2') or line.strip().startswith('3.2.3') or line.strip().startswith('3.3.1') or line.strip().startswith('3.3.2') or line.strip().startswith('3.3.3') or line.strip().startswith('3.3.4') or line.strip().startswith('3.4.1') or line.strip().startswith('3.4.2') or line.strip().startswith('3.4.3') or line.strip().startswith('4.1.1') or line.strip().startswith('4.1.2') or line.strip().startswith('4.1.3') or line.strip().startswith('4.2.1') or line.strip().startswith('4.2.2') or line.strip().startswith('4.3.1') or line.strip().startswith('4.3.2') or line.strip().startswith('4.4.1') or line.strip().startswith('4.4.2') or line.strip().startswith('1.1.1') or line.strip().startswith('1.1.2') or line.strip().startswith('1.2.1') or line.strip().startswith('1.2.2') or line.strip().startswith('1.3.1') or line.strip().startswith('1.3.2') or line.strip().startswith('1.4.1') or line.strip().startswith('1.4.2') or line.strip().startswith('2.1.1') or line.strip().startswith('2.1.2') or line.strip().startswith('2.1.3') or line.strip().startswith('2.2.1') or line.strip().startswith('2.2.2') or line.strip().startswith('2.3.1') or line.strip().startswith('2.3.2') or line.strip().startswith('2.3.3') or line.strip().startswith('2.4.1') or line.strip().startswith('2.4.2') or line.strip().startswith('2.5.1') or line.strip().startswith('2.5.2'):
         p = doc.add_paragraph()
         p.paragraph_format.left_indent = Pt(36)
         r = p.add_run(line.strip())
    else:
        if line.strip():
            doc.add_paragraph(line.strip())

doc.save('Dan_y_do_an_CKAS_W2.docx')
print('Created Dan_y_do_an_CKAS_W2.docx')
