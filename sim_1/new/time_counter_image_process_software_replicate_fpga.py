# Dependencies
import numpy as np
import collections
import os
from PIL import Image
import matplotlib.pyplot as plt
import time

# Hyperparameter
WIDTH = 200
HEIGHT = 200
THRESHOLD = 128

def time_counter(WIDTH=WIDTH,
                 HEIGHT=HEIGHT,
                 THRESHOLD=THRESHOLD,
                 image_path="test.jpg"):
  img = Image.open(image_path)
  """
  To count the image processing time using PYTHON, not including file reading/writing and visualizing time.

  Args:
    WIDTH (int): The width of the image.
    HEIGHT (int): The height of the image.
    THRESHOLD (int): The threshold of the sobel filter.
    image_path (str): The path of the image to be processed, ABSOLUTE PATH maybe needed.
  """

  # Start to calculate the time
  start_time_internal = time.perf_counter()

  # I. rgb2gray
  if img.mode != 'RGB':
    img = img.convert('RGB')

  img_resized = img.resize(size=(WIDTH, HEIGHT),
                          resample=Image.Resampling.LANCZOS)
  img_array = np.array(img_resized)
  r_channel = img_array[:, :, 0].flatten() # All rows, all columns, 0th channel (Red)
  g_channel = img_array[:, :, 1].flatten() # All rows, all columns, 1st channel (Green)
  b_channel = img_array[:, :, 2].flatten() # All rows, all columns, 2nd channel (Blue)

  r_values = img_array[:, :, 0].astype(np.uint16) # Cast to uint16 to prevent overflow during multiplication
  g_values = img_array[:, :, 1].astype(np.uint16)
  b_values = img_array[:, :, 2].astype(np.uint16)

  weighted_r = r_values * 77
  weighted_g = g_values * 150
  weighted_b = b_values * 29

  gray_tmp_sum = weighted_r + weighted_g + weighted_b

  golden_gray_pixels = (gray_tmp_sum // 256).astype(np.uint8) # Ensure final result is uint8

  # II. gray_through_median_filter

  # 1. Initializing line buffer and sliding window
  line_buffer = collections.deque((0 for i in range(WIDTH*2)), maxlen=WIDTH*2)
  window = np.zeros(shape=(3, 3), dtype=np.uint8)
  median_output_pixels = []   # The final output

  golden_gray = golden_gray_pixels.flatten()

  for pixel in golden_gray:
    window = np.roll(window, shift=-1, axis=1)
    window[0, 2] = line_buffer[WIDTH*2-1]
    window[1, 2] = line_buffer[WIDTH-1]
    window[2, 2] = int(pixel)

    # 3. Compare
    flatten_window = window.flatten()
    sorted_pixels = np.sort(flatten_window)
    median_pixel = sorted_pixels[4]   # The median value

    # 4. Memorize
    median_output_pixels.append(median_pixel.item())

    # 5. Shift register
    line_buffer.appendleft(int(pixel))
    # NOTE: 这一步操作必须在Sliding Window之后

  # III. sobel
  # 1. Initializing line buffer, sliding window and sobel kernel
  line_buffer = collections.deque((0 for i in range(WIDTH*2)), maxlen=WIDTH*2)
  window = np.zeros(shape=(3, 3), dtype=np.uint8)
  # Sobel kernel
  sobel_kernel_x = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]])
  sobel_kernel_y = np.array([[1, 2, 1], [0, 0, 0], [-1, -2, -1]])
  # The final output
  sobel_output_pixels = []

  for pixel in median_output_pixels:
    # 2. Sliding window
    window = np.roll(window, shift=-1, axis=1)
    window[0, 2] = line_buffer[WIDTH*2-1]
    window[1, 2] = line_buffer[WIDTH-1]
    window[2, 2] = int(pixel)

    # 3. Convolution
    G_x = np.sum(np.multiply(window, sobel_kernel_x)).item()
    G_y = np.sum(np.multiply(window, sobel_kernel_y)).item()
    G = np.abs(G_x) + np.abs(G_y)

    # 4. Memorize
    sobel_output_pixels.append(0 if G > THRESHOLD else 1)

    # 5. Shift register
    line_buffer.appendleft(int(pixel))
    # NOTE: 这一步操作必须在Sliding Window之后

  # The TIME CONSUMPTION
  end_time_internal = time.perf_counter()

  # print(f"The total time consuming in Python Code for Image Process is: {time.perf_counter() - start_time} seconds.")

  plt.figure(figsize=(7, 7))

  plt.subplot(2, 2, 1)
  plt.imshow(img_resized)
  plt.axis('off')
  plt.title("Original Image")

  plt.subplot(2, 2, 2)
  plt.imshow(np.array(golden_gray).reshape(WIDTH, HEIGHT), cmap='gray')
  plt.axis('off')
  plt.title("Image after gray filter")

  plt.subplot(2, 2, 3)
  plt.imshow(np.array(median_output_pixels).reshape(WIDTH, HEIGHT), cmap='gray')
  plt.axis('off')
  plt.title("Image after median filter")

  plt.subplot(2, 2, 4)
  plt.imshow(np.array(sobel_output_pixels).reshape(WIDTH, HEIGHT), cmap='gray')
  plt.axis('off')
  plt.title("Image after sobel filter")

  plt.show()

  return end_time_internal - start_time_internal

CIRCLE = 1
time_total = 0
time_onecircle = 0

for i in range(CIRCLE):
  time_onecircle = time_counter(image_path="D:/Documents/Vivado/ImageProcess/ImageProcess.srcs/sim_1/new/test.jpg")
  time_total = time_total + time_onecircle

print(f"Total circle: {CIRCLE} | The average time consuming in Python Code for Image Process is: {time_total/100.0} seconds.")

