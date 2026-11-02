import cv2
import numpy as np
import math
import tkinter as tk
from tkinter import filedialog
import os

def select_image():
    root = tk.Tk()
    root.withdraw() # Ẩn cửa sổ chính
    file_path = filedialog.askopenfilename(
        title="Chọn ảnh",
        filetypes=[("Image files", "*.jpg *.jpeg *.png *.bmp")]
    )
    return file_path

# Biến toàn cục để lưu trạng thái
points = []
image = None
clone_image = None
cm_per_pixel = None
ruler_length_cm = 10.0

def click_event(event, x, y, flags, param):
    global points, image, clone_image, cm_per_pixel
    
    if event == cv2.EVENT_LBUTTONDOWN:
        if len(points) < 4:
            points.append((x, y))
            
            # 2 điểm đầu tiên là để xác định kích thước thước
            if len(points) <= 2:
                cv2.circle(image, (x, y), 4, (0, 255, 0), -1) # Màu xanh lá cho thước
                if len(points) == 2:
                    dist_pixel = math.hypot(points[1][0] - points[0][0], points[1][1] - points[0][1])
                    if dist_pixel == 0:
                        print("2 điểm trùng nhau, vui lòng chọn lại bằng phím 'c'.")
                        return
                    cm_per_pixel = ruler_length_cm / dist_pixel
                    cv2.line(image, points[0], points[1], (0, 255, 0), 2)
                    print(f"Đã xác định tỷ lệ: {cm_per_pixel:.4f} cm/pixel. Bây giờ hãy chọn 2 điểm để đo khoảng cách.")
                    
            # 2 điểm tiếp theo là để đo khoảng cách
            elif len(points) <= 4:
                cv2.circle(image, (x, y), 4, (0, 0, 255), -1) # Màu đỏ cho điểm cần đo
                if len(points) == 4:
                    p1 = points[2]
                    p2 = points[3]
                    
                    # Điểm góc vuông để tạo thành tam giác vuông cho rx và ry
                    p_corner = (p2[0], p1[1])
                    
                    dx_pixel = abs(p2[0] - p1[0])
                    dy_pixel = abs(p2[1] - p1[1])
                    dist_pixel = math.hypot(dx_pixel, dy_pixel)
                    
                    dist_cm = dist_pixel * cm_per_pixel
                    dx_cm = dx_pixel * cm_per_pixel
                    dy_cm = dy_pixel * cm_per_pixel
                    
                    # Quy ước màu sắc (BGR trong OpenCV)
                    color_d = (255, 0, 0)       # Xanh dương
                    color_rx = (0, 165, 255)    # Cam
                    color_ry = (255, 0, 255)    # Tím/Hồng
                    
                    # Vẽ vector chính D
                    cv2.arrowedLine(image, p1, p2, color_d, 2, tipLength=0.03) 
                    
                    # Vẽ vector rx (từ p1 đến p_corner) theo trục ngang
                    if dx_pixel > 0:
                        cv2.arrowedLine(image, p1, p_corner, color_rx, 2, tipLength=0.05)
                        
                    # Vẽ vector ry (từ p_corner đến p2) theo trục dọc
                    if dy_pixel > 0:
                        cv2.arrowedLine(image, p_corner, p2, color_ry, 2, tipLength=0.05)
                    
                    # --- Vẽ bảng hiển thị kết quả ---
                    box_x, box_y = 10, 10
                    box_w, box_h = 320, 140
                    
                    # 1. Vẽ nền trắng trong suốt (alpha blending)
                    overlay = image.copy()
                    cv2.rectangle(overlay, (box_x, box_y), (box_x + box_w, box_y + box_h), (255, 255, 255), -1)
                    alpha = 0.8
                    cv2.addWeighted(overlay, alpha, image, 1 - alpha, 0, image)
                    
                    # 2. Vẽ viền hộp (màu đen)
                    cv2.rectangle(image, (box_x, box_y), (box_x + box_w, box_y + box_h), (0, 0, 0), 2)
                    
                    # 3. Ghi text vào bảng
                    font = cv2.FONT_HERSHEY_SIMPLEX
                    cv2.putText(image, "KET QUA DO:", (box_x + 10, box_y + 30), font, 0.7, (0, 0, 0), 2)
                    cv2.putText(image, f"D  (Xanh duong) : {dist_cm:.2f} cm", (box_x + 10, box_y + 65), font, 0.6, color_d, 2)
                    cv2.putText(image, f"rx (Cam)        : {dx_cm:.2f} cm", (box_x + 10, box_y + 95), font, 0.6, color_rx, 2)
                    cv2.putText(image, f"ry (Tim)        : {dy_cm:.2f} cm", (box_x + 10, box_y + 125), font, 0.6, color_ry, 2)
                    
                    print(f"Khoảng cách D={dist_cm:.2f}cm, rx={dx_cm:.2f}cm, ry={dy_cm:.2f}cm")
                    
            cv2.imshow("Image", image)

def main():
    global image, clone_image, points, cm_per_pixel
    
    image_path = select_image()
    if not image_path:
        print("Chưa chọn ảnh.")
        return
        
    image = cv2.imread(image_path)
    if image is None:
        print("Không thể đọc ảnh.")
        return
        
    # Resize ảnh nếu quá lớn
    max_dimension = 1000
    height, width = image.shape[:2]
    if max(height, width) > max_dimension:
        scale = max_dimension / max(height, width)
        image = cv2.resize(image, (int(width * scale), int(height * scale)))
        print(f"Ảnh đã được resize xuống {image.shape[1]}x{image.shape[0]} để hiển thị.")
        
    clone_image = image.copy()
    
    print("--- HƯỚNG DẪN SỬ DỤNG ---")
    print("1. Click 2 điểm đầu tiên để chọn độ dài thước (10cm).")
    print("2. Click 2 điểm tiếp theo để đo khoảng cách (D, rx, ry).")
    print("3. Nhấn phím 'm' để xóa kết quả đo, giữ lại thước và đo vị trí khác.")
    print("4. Nhấn phím 'c' để xóa TẤT CẢ, chọn lại thước từ đầu.")
    print("5. Nhấn phím 's' để lưu ảnh kết quả (.jpg).")
    print("6. Nhấn phím 'q' để thoát.")
        
    cv2.imshow("Image", image)
    cv2.setMouseCallback("Image", click_event)
    
    while True:
        key = cv2.waitKey(1) & 0xFF
        
        # Nhấn 'q' để thoát
        if key == ord("q"):
            break
            
        # Nhấn 'c' để xóa tất cả
        elif key == ord("c"):
            image = clone_image.copy()
            points = []
            cm_per_pixel = None
            cv2.imshow("Image", image)
            print("Đã xóa tất cả. Hãy click 2 điểm để xác định thước.")
            
        # Nhấn 'm' để đo điểm khác (giữ lại thước)
        elif key == ord("m"):
            if len(points) >= 2:
                points = points[:2] # Giữ lại 2 điểm đầu (thước)
                image = clone_image.copy()
                # Vẽ lại thước
                cv2.circle(image, points[0], 4, (0, 255, 0), -1)
                cv2.circle(image, points[1], 4, (0, 255, 0), -1)
                cv2.line(image, points[0], points[1], (0, 255, 0), 2)
                cv2.imshow("Image", image)
                print("Đã xóa kết quả đo. Hãy click 2 điểm mới để đo.")
            
        # Nhấn 's' để lưu
        elif key == ord("s"):
            base_name = os.path.basename(image_path)
            name, ext = os.path.splitext(base_name)
            save_path = f"{name}_result.jpg" 
            cv2.imwrite(save_path, image)
            print(f"Đã lưu ảnh kết quả tại thư mục hiện tại: {save_path}")

    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
