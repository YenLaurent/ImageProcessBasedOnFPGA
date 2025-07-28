import cv2
import numpy as np
import time
import matplotlib.pyplot as plt
import os

def process_image_software(image_bgr):
    """
    执行完整的图像处理流水线（软件优化算法）。
    
    Args:
        image_bgr (np.array): 输入的RGB格式图像数组 (200x200)。

    Returns:
        tuple: 包含灰度图、中值滤波图和Sobel边缘图的元组。
    """
    # 1. 灰度化 (Grayscale Conversion)
    # 使用OpenCV的标准色彩空间转换，这是最常见的软件实现
    gray_image = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)

    # 2. 中值滤波 (Median Filtering)
    # 使用3x3的核进行中值滤波
    median_filtered_image = cv2.medianBlur(gray_image, 3)

    # 3. Sobel边缘检测 (Sobel Edge Detection)
    # 使用64位浮点数以避免梯度计算中的溢出
    # 分别计算x和y方向的梯度
    sobel_x = cv2.Sobel(median_filtered_image, cv2.CV_64F, 1, 0, ksize=3)
    sobel_y = cv2.Sobel(median_filtered_image, cv2.CV_64F, 0, 1, ksize=3)

    # 计算梯度的绝对值并转换回8位无符号整数
    abs_sobel_x = cv2.convertScaleAbs(sobel_x)
    abs_sobel_y = cv2.convertScaleAbs(sobel_y)

    # 将x和y方向的梯度加权合并，得到最终的边缘图
    sobel_combined = cv2.addWeighted(abs_sobel_x, 0.5, abs_sobel_y, 0.5, 0)
    
    return gray_image, median_filtered_image, sobel_combined

def measure_software_performance(image_path="test.jpg", resize_dim=(200, 200), num_runs=100):
    """
    加载图像，测量其软件处理延迟，并显示结果。

    Args:
        image_path (str): 输入测试图像的路径。
        resize_dim (tuple): 目标处理尺寸 (宽度, 高度)。
        num_runs (int): 为获得稳定结果而运行的次数。
    """
    print("--- 软件端图像处理性能测试 ---")

    # =================================================================
    # 步骤 1: 图像加载与预处理 (此部分不计入延迟时间)
    # =================================================================
    try:
        # 使用OpenCV读取图像，它默认以BGR格式加载
        original_image = cv2.imread(image_path)
        if original_image is None:
            raise FileNotFoundError
        print(f"成功读取图像: {image_path}")
    except FileNotFoundError:
        print(f"错误: 无法在 '{image_path}' 找到测试图片。请确保文件存在。")
        return

    # 将图像缩放到指定的200x200尺寸
    # 使用cv2.INTER_AREA插值算法，它在缩小图像时效果最好
    resized_image_bgr = cv2.resize(original_image, resize_dim, interpolation=cv2.INTER_AREA)
    print(f"图像已缩放至 {resize_dim[0]}x{resize_dim[1]} 像素。")
    
    # =================================================================
    # 步骤 2: 核心处理延迟测量
    # =================================================================
    exec_times = []
    print(f"\n开始执行处理流程 {num_runs} 次以测量平均延迟...")

    for i in range(num_runs):
        # --- 计时开始 ---
        # 使用perf_counter以获得最高精度的单调时钟
        start_time = time.perf_counter()

        # 调用核心处理函数
        process_image_software(resized_image_bgr)

        # --- 计时结束 ---
        end_time = time.perf_counter()
        
        # 记录本次执行时间
        exec_times.append(end_time - start_time)

    # 忽略第一次运行（可能包含缓存加载等一次性开销），计算后续运行的平均值
    avg_delay = np.mean(exec_times[1:])
    
    print("\n--- 性能测试结果 ---")
    print(f"平均单帧处理延迟: {avg_delay * 1000:.4f} 毫秒 (ms)")
    print(f"等效处理帧率 (FPS): {1 / avg_delay:.2f}")
    
    # =================================================================
    # 步骤 3: 处理并显示最终图像 (此部分不计入延迟时间)
    # =================================================================
    print("\n正在生成并绘制最终处理结果图像...")
    
    # 最后运行一次以获取用于显示的图像
    gray_result, median_result, sobel_result = process_image_software(resized_image_bgr)
    
    # Matplotlib需要RGB格式的图像，而OpenCV是BGR，所以需要转换
    resized_image_rgb = cv2.cvtColor(resized_image_bgr, cv2.COLOR_BGR2RGB)

    # 创建一个2x2的图框来显示所有图像
    plt.figure(figsize=(10, 10))
    
    plt.subplot(2, 2, 1)
    plt.imshow(resized_image_rgb)
    plt.title("1. Original Image (200x200)")
    plt.axis('off')

    plt.subplot(2, 2, 2)
    plt.imshow(gray_result, cmap='gray')
    plt.title("2. Grayscale")
    plt.axis('off')

    plt.subplot(2, 2, 3)
    plt.imshow(median_result, cmap='gray')
    plt.title("3. Median Filtered")
    plt.axis('off')

    plt.subplot(2, 2, 4)
    plt.imshow(sobel_result, cmap='gray')
    plt.title("4. Sobel Edge Detection")
    plt.axis('off')

    plt.tight_layout()
    plt.suptitle("Software Image Processing Results", fontsize=16)
    plt.show()


# --- 主程序入口 ---
if __name__ == "__main__":
    # 如果当前目录下没有test.jpg，则创建一个用于演示
    if not os.path.exists("test.jpg"):
        print("未找到'test.jpg'，正在创建一个随机噪声图像用于演示...")
        dummy_array = np.random.randint(0, 256, (480, 640, 3), dtype=np.uint8)
        cv2.imwrite("test.jpg", dummy_array)
    
    measure_software_performance(image_path="D:/Documents/Vivado/ImageProcess/ImageProcess.srcs/sim_1/new/test.jpg", resize_dim=(200, 200), num_runs=100)