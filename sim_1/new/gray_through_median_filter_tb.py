# Dependencies
import numpy as np
import collections
import os
from PIL import Image
import matplotlib.pyplot as plt

# Hyperparameter
WIDTH = 200
HEIGHT = 200

def median_filter_testbench_stimulus_generator(
    input_file="gray_golden.txt",
    output_file="median_golden.txt",
    WIDTH=WIDTH,
    HEIGHT=HEIGHT):
    """
    Simulates the exact behavior of the Verilog median filter module.

    This function reads grayscale pixel data, processes it using line buffers
    and a sliding window to mimic the Verilog hardware, and generates a
    golden output file for the testbench.

    Args:
        input_file (str): The input text file with hex pixel values, ABSOLUTE PATH maybe needed.
        output_file (str): The output text file for the filtered pixels, ABSOLUTE PATH maybe needed.
        width (int): The width of the image.
        height (int): The height of the image.
    """
    print("--- Starting Python Simulation of Verilog Median Filter ---\n")

    # 1. Initializing line buffer and sliding window
    line_buffer = collections.deque((0 for i in range(WIDTH*2)), maxlen=WIDTH*2)
    window = np.zeros(shape=(3, 3), dtype=np.uint8)
    median_output_pixels = []   # The final output

    print(f"Successfully initialized line buffer: {len(line_buffer)} length.\n Sliding window: \n{window}")

    with open(input_file, 'r') as f:
      for index, pixel in enumerate(f):
        # 2. Sliding window
        window = np.roll(window, shift=-1, axis=1)
        window[0, 2] = line_buffer[WIDTH*2-1]
        window[1, 2] = line_buffer[WIDTH-1]
        window[2, 2] = int(pixel.strip(), 16)

        # 3. Compare
        flatten_window = window.flatten()
        sorted_pixels = np.sort(flatten_window)
        median_pixel = sorted_pixels[4]   # The median value

        # 4. Memorize
        median_output_pixels.append(median_pixel)

        # 5. Shift register
        line_buffer.appendleft(int(pixel.strip(), 16))
        # NOTE: 这一步操作必须在Sliding Window之后

      print(f"Successfully simulated the behaviour of Verilog.")

    # 6. Visualize
    print("Visualizing the results.")
    results = np.array(median_output_pixels).reshape(WIDTH, HEIGHT)

    plt.figure(figsize=(7, 7))
    plt.imshow(results, cmap='gray')
    plt.axis('off')
    plt.title("Image after median filter")
    plt.show()

    np.set_printoptions(formatter={'int': '{:x}'.format})
    # To print the image in hexadecimal format
    print(f"The gray scale image after median filter is: \n{results}")

    # 7. Write the results to 'median_golden.txt'
    with open(output_file, 'w') as f:
      for pixel in median_output_pixels:
        f.write(f"{pixel:02X}\n")
      print(f"Successfully write results to {output_file}\n")

    print("--- Python Simulation Finished ---")

median_filter_testbench_stimulus_generator(input_file="D:/Documents/Vivado/ImageProcess/ImageProcess.srcs/sim_1/new/gray_golden.txt",
                                           output_file="D:/Documents/Vivado/ImageProcess/ImageProcess.srcs/sim_1/new/median_golden.txt",
                                           WIDTH=WIDTH,
                                           HEIGHT=HEIGHT)
