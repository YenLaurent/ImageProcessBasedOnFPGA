# Dependencies
import os
import numpy as np
from PIL import Image
import matplotlib.pyplot as plt

# Hyperparameter
WIDTH = 200
HEIGHT = 200

def gray_filter_testbench_stimulus_generator(
    image_path="test.jpg", 
    gray_output_file="gray_golden.txt",
    r_output_file="r_input.txt",
    g_output_file="g_input.txt",
    b_output_file="b_input.txt",
    output_size=(WIDTH, HEIGHT)):
    """
    Processes a color image to generate stimulus files for a Verilog testbench
    and a golden grayscale output.

    Args:
        image_path (str): Path to the input color image, ABSOLUTE PATH maybe needed.
        gray_output_file (str): The output text file for the filtered gray scale pixels, ABSOLUTE PATH maybe needed.
        r_output_file (str): The output text file for the stimulus input red channel pixels, ABSOLUTE PATH maybe needed.
        g_output_file (str): The output text file for the stimulus input green channel pixels, ABSOLUTE PATH maybe needed.
        b_output_file (str): The output text file for the stimulus input blue channel pixels, ABSOLUTE PATH maybe needed.
        output_size (tuple): A tuple (width, height) for resizing the image.
    """
    print("--- Starting Python Simulation of Verilog Median Filter ---\n")
    print(f"Starting image processing for: {image_path}")

    # 1. Read the image file
    try:
        img = Image.open(image_path)
        print(f"Successfully opened image: {image_path}")
    except FileNotFoundError:
        print(f"Error: Image file not found at {image_path}, maybe you should use ABSOLUTE PATH.")
        return
    except Exception as e:
        print(f"Error opening image: {e}")
        return

    # 2. Ensure image is in RGB format (if it's RGBA, for example)
    if img.mode != 'RGB':
        img = img.convert('RGB')
        print("Converted image to RGB format.")

    # 3. Resize the image to 200x200 pixels
    img_resized = img.resize(size=output_size,
                             resample=Image.Resampling.LANCZOS)
    # Using LANCZOS for good quality resize
    print(f"Resized image to {output_size[0]}x{output_size[1]} pixels.")

    # 4. Convert the resized image to a NumPy array
    # The array will have shape (height, width, 3) for RGB
    img_array = np.array(img_resized)
    print(f"Converted resized image to NumPy array with shape: {img_array.shape}")

    # 5. Separate R, G, B channels and flatten them
    # Pixels are typically read row by row (from top-left to bottom-right)
    # Numpy expects color-channel-last format
    r_channel = img_array[:, :, 0].flatten() # All rows, all columns, 0th channel (Red)
    g_channel = img_array[:, :, 1].flatten() # All rows, all columns, 1st channel (Green)
    b_channel = img_array[:, :, 2].flatten() # All rows, all columns, 2nd channel (Blue)
    print("Separated and flattened R, G, B channels.")

    # 6. Output R, G, B channels to .txt files in hexadecimal format
    # The testbench expects one hex value per line, without "0x" or "h"
    def write_channel_to_file(channel_data, filename):
        with open(filename, 'w') as f:
            for pixel_value in channel_data:
                # Format as two-digit hexadecimal (e.g., 0A, FF)
                f.write(f"{pixel_value:02X}\n") # :02X ensures uppercase hex, at least 2 digits, zero-padded
        print(f"Successfully wrote data to {filename}")

    write_channel_to_file(r_channel, r_output_file)
    write_channel_to_file(g_channel, g_output_file)
    write_channel_to_file(b_channel, b_output_file)

    # 7. Calculate grayscale image using the "WEIGHT" method
    # gray = (77*R + 150*G + 29*B) >> 8
    # Ensure calculations are done with integer arithmetic to match Verilog precisely.
    # The intermediate products can exceed 8 bits.
    # Verilog: gray_tmp = red_x77 + green_x150 + blue_x29;
    #          assign gray = gray_tmp[15:8];
    # This means the sum is calculated, and then the result is right-shifted by 8.

    # Use the original R, G, B channels before flattening for easier indexing
    r_values = img_array[:, :, 0].astype(np.uint16) # Cast to uint16 to prevent overflow during multiplication
    g_values = img_array[:, :, 1].astype(np.uint16)
    b_values = img_array[:, :, 2].astype(np.uint16)

    # Perform the weighted sum. Note: NumPy performs element-wise operations.
    # These are equivalent to the Verilog intermediate sums (e.g., red_x77)
    # before they are added together.
    weighted_r = r_values * 77
    weighted_g = g_values * 150
    weighted_b = b_values * 29

    gray_tmp_sum = weighted_r + weighted_g + weighted_b
    # Perform the right shift by 8 (integer division by 256)
    golden_gray_pixels = (gray_tmp_sum // 256).astype(np.uint8) # Ensure final result is uint8
    # //是向下取整除法

    # Reshape the flattened gray pixels back to a 2D image array for display
    golden_gray_image = golden_gray_pixels # It's already in 2D (height, width)
    print("Calculated golden gray scale image using the 'WEIGHT' method.")

    # 8. Display the generated gray scale image (optional, but good for verification)
    print("Displaying the golden gray scale image.")
    plt.imshow(golden_gray_image, cmap='gray', vmin=0, vmax=255)
    plt.title("Image after gray filter")
    plt.axis('off') # Turn off axis numbers and ticks
    plt.show()

    # 9. Output the golden grayscale image pixels to gray_golden.txt
    write_channel_to_file(golden_gray_image.flatten(), gray_output_file)

    print(f"All files generated successfully for an image of size {output_size[0]}x{output_size[1]}.\n")
    print("--- Python Simulation Finished ---")

gray_filter_testbench_stimulus_generator(image_path="D:/Documents/Vivado/ImageProcess/ImageProcess.srcs/sim_1/new/test.jpg",
                                         gray_output_file="D:/Documents/Vivado/ImageProcess/ImageProcess.srcs/sim_1/new/gray_golden.txt",
                                         r_output_file="D:/Documents/Vivado/ImageProcess/ImageProcess.srcs/sim_1/new/r_input.txt",
                                         g_output_file="D:/Documents/Vivado/ImageProcess/ImageProcess.srcs/sim_1/new/g_input.txt",
                                         b_output_file="D:/Documents/Vivado/ImageProcess/ImageProcess.srcs/sim_1/new/b_input.txt",
                                         output_size=(WIDTH, HEIGHT))
