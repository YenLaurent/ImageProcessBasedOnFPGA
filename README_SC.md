# 基于 FPGA 的图像预处理与以太网传输系统

[English](./README.md) | 简体中文

> 本项目基于电子科技大学 2024-2025 学年“强芯育苗”科研项目，依托校级大学生创新创业训练计划，编写并实现了一套基于 FPGA 的图像预处理传输系统：系统接收 OV5640 摄像头图像，经彩色图像灰度化滤波、灰度图像中值滤波与 Sobel 边缘检测三大模块处理后，通过以太网传输至 PC 端，供 PC 端进行后续的人工智能边缘检测识别处理。

---

## 展示

<p align="center">
  <img src="./results/image_process_results/testbench_results/image_process_example/fpga_method.png" alt="FPGA image processing example" width="75%"/>
  <br/>
  <em>图：FPGA 端图像预处理链路示例效果</em>
  <br/>
  <sup>图片路径：results/image_process_results/testbench_results/image_process_example/fpga_method.png</sup>
  
</p>

## 目录
- [基于 FPGA 的图像预处理与以太网传输系统](#基于-fpga-的图像预处理与以太网传输系统)
  - [展示](#展示)
  - [目录](#目录)
  - [应用场景](#应用场景)
  - [系统优势](#系统优势)
  - [目标与工程信息](#目标与工程信息)
  - [快速开始](#快速开始)
  - [相关参数](#相关参数)
  - [性能评估](#性能评估)
  - [算法选择考量](#算法选择考量)
    - [中值滤波 \& 高斯滤波](#中值滤波--高斯滤波)
    - [Sobel \& Canny](#sobel--canny)
  - [文件夹与项目结构](#文件夹与项目结构)

---

## 应用场景
各类边缘端图像预处理/传输场景，例如：检测机动车/非机动车闯红灯行为等。

## 系统优势
- 将原本在软件端执行的部分计算前移至边缘端，显著减轻主机计算负载。
- 极大降低网络传输带宽：由原始 RGB888 24 位宽信号变为 Sobel 1bit 位宽二值图像。

## 目标与工程信息
- 目标平台：Vivado 2023.2
- 目标 FPGA：Xilinx Artix-7 XC7A100T
- 位流：`bitstream/ImageProcess.bit`
- 仿真：`sim/`（包含 Verilog TB 与 Python 对比/驱动脚本）
- PC 端可视化：`pc_viewer/udp_binary_viewer.py`

## 快速开始
以下以“小梅哥 ACX720-V3 系列”对应型号 FPGA 开发板为例（若你使用的不是该品牌FPGA，那么或许需要重写约束文件后，再作烧录）：

1) 在 Vivado 中烧录位流
	- 直接烧录 `bitstream/ImageProcess.bit`。

2) 网络连接与参数设置
	- 将开发板与 PC 通过网线直连。
	- 将 PC 端网卡的 IPv4 地址设置为 `192.168.0.3`。
	- 在网卡属性中启用“巨型帧”（Jumbo Frame）。

3) 抓包确认
	- 打开 Wireshark，对传输的数据进行抓包确认（UDP/IPv4）。

4) PC 端可视化
	- 进入 `pc_viewer/`，按其 README 说明安装依赖并运行 `udp_binary_viewer.py`。
	- 可实时显示经过图像滤波后的二值图像。

可选（Windows PowerShell 示例）：

```powershell
cd pc_viewer
python -m pip install -r requirements.txt
python .\udp_binary_viewer.py
```

## 相关参数
- 传输图像尺寸：1280×720
- 帧率：30 FPS
- 协议：UDP / IPv4
- 传输粒度：以“行”为单位进行传输，每行前加入 2 Bytes 行号
- 图像预处理：全流水线设计（灰度化 → 中值滤波 → Sobel 边缘检测）

## 性能评估
- 传输带宽可降低至原始数据的 1/24。
- 对比传统使用 OpenCV 的软件端图像滤波，硬件端实现可将处理单帧图像的延迟降低约 12.74%–28.70%。
  - 统计口径：Processing a single frame of 200×200 image, latency comparison between Google Colab (free version) and Xilinx Artix-7 XC7A100T FPGA (@100MHz)。
- 在测试 FPGA 上，系统的 LUT/FF/LUTRAM 资源占用率均不足 10%，具备低成本大规模部署到边缘端的潜力。

> 示例结果与波形截图可见 `results/` 目录。

## 算法选择考量

### 中值滤波 & 高斯滤波
在图像中，常见噪声包括：
- 高斯噪声：连续随机噪声，呈高斯分布，导致像素值微小随机变化；
- 椒盐噪声：离散随机噪声，表现为随机白点/黑点；
- 均匀噪声：降低图像对比度；
- 波纹噪声：表现为周期性亮暗变化。

不同滤波算法的主要特征：
- 均值滤波：线性滤波，用邻域均值替代当前像素，对高斯噪声/均匀噪声有效，但损伤细节；
- 高斯滤波：线性滤波，距离中心越远权重越低（高斯分布），对高斯噪声更好，细节保留较均值更优；
- 中值滤波：非线性滤波，用中值替代当前像素，对椒盐噪声效果好，边缘与细节保留程度高。

在 FPGA 实现上：
- 中值滤波需要大量比较，资源消耗较大，但边缘保持最好；
- 高斯滤波用卷积做加权平均，计算量较小，但边缘损失相对更大。

考虑到系统需要进行边缘检测，本设计采用中值滤波进行噪声平滑，以最大程度保留边缘信息；其对高斯噪声的抑制不如高斯滤波，且资源开销相对较大，但在 Artix-7 上实测 LUT/FF/LUTRAM 均不足 10%，可接受。

此外，椒盐噪声易被边缘检测算法识别为“强边缘”，因此优先消除椒盐噪声更为合理（尽管摄像头的椒盐噪声通常少于高斯噪声）。

再考虑到 Sobel 算子的阈值敏感特性，使用中值滤波保留边缘特点也便于阈值设定，最大程度减小昼夜环境导致的阈值变化。

### Sobel & Canny
两者均为常见边缘检测算法：
- Sobel：计算量小；缺点是边缘较粗、对噪声与阈值较敏感；
- Canny：高斯滤波 + Sobel 梯度 + 非极大值抑制 + 双阈值检测 + 弱边缘连接；对边缘提取完整、边缘更细、准确率更高，但实现复杂、计算量大。

本工程只需提取如斑马线与非机动车边缘等相对简单的边缘特征，对边缘精度需求不高且对计算负载敏感，因此未采用 Canny，而选择 Sobel 以兼顾实时性与资源开销。

## 文件夹与项目结构
- `bitstream/`：包含可直接用于烧录的 `.bit` 与固化 `.bin` 文件。
- `constrs/`：FPGA IO 引脚约束（XDC）。
- `pc_viewer/`：提供一个用于传输数据可视化的 Python 脚本 `udp_binary_viewer.py`（感谢 GPT5）。
- `results/`：包含系统各模块的测试结果与 testbench 仿真结果（含图表/截图）。
- `sim/`：包含系统所有 testbench 所需文件（Verilog TB、Python 对比/驱动脚本、golden 数据等）。
- `sources/`：核心 IP 与 RTL 文件（如 `ImageProcess.v` 等），以及工程依赖的 IP 配置。

```
ImageProcessBasedOnFPGA
├─ bitstream/
├─ constrs/
├─ pc_viewer/
├─ results/
├─ sim/
├─ sources/
└─ ov5640/
```

如需英文版说明，请查看 [README.md](./README.md)。

