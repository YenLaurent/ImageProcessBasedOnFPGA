# PC UDP Binary Image Viewer

This is a small utility to display the 1-bit-per-pixel (1bpp) image streamed from the FPGA over UDP.
Each UDP packet contains a 2-byte line number header followed by 160 bytes of packed bits for a 1280-pixel line.

- Image size: 1280 x 720
- Payload per line: 162 bytes (= 2-byte line index + 160 data bytes)
- Line index: big-endian uint16 by default (change LINE_NUM_STRUCT in the script if needed)
- UDP port: 6102 by default (match DES_UDP_PORT in your HDL)

## Setup (Windows PowerShell)

```powershell
# Optional: create venv
python -m venv .venv ; .\.venv\Scripts\Activate.ps1

# Install deps
pip install -r requirements.txt

# Run viewer (adjust IP/port in script if necessary)
python .\udp_binary_viewer.py
```

If the viewer runs on a different PC than the FPGA is connected to, ensure your NIC IP is in the same subnet (e.g., 192.168.0.x) and no firewall blocks UDP 6102.

## Tuning
- If pixels appear inverted (white/black swapped), invert the `frame` before display: `frame = 255 - frame`.
- If the line appears mirrored, change `bitorder='big'` to `'little'` in `np.unpackbits`.
- If the line numbering is 1-based, the script auto-detects and converts (1..H -> 0..H-1). If your firmware uses a different convention, adjust the mapping logic.
- If you see tearing or missing lines, increase `SOCKET_RCVBUF`.

## Saving Frames
Press `s` in the OpenCV window to add a quick save snippet if desired. For now, you can add:
```python
if key == ord('s'):
    cv2.imwrite(f"frame_{int(time.time())}.png", frame)
```
right after `cv2.waitKey` handling.
