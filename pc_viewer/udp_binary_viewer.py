import socket
import struct
import sys
import time
from typing import Tuple

import cv2
import numpy as np

# ---- User params ----
IMAGE_WIDTH = 1280
IMAGE_HEIGHT = 720
BITS_PER_PIXEL = 1  # binary image
BYTES_PER_LINE = IMAGE_WIDTH // 8  # 160
LINE_HEADER_LEN = 2  # line number (uint16)
PAYLOAD_LEN = LINE_HEADER_LEN + BYTES_PER_LINE  # 162

# Network params (adjust to your sender configuration)
LISTEN_IP = "0.0.0.0"  # bind all interfaces
LISTEN_PORT = 6102      # must match DES_UDP_PORT on FPGA
RECV_BUF_SIZE = 10240    # socket recv buffer per call (UDP datagram max read)
SOCKET_RCVBUF = 8 * 1024 * 1024  # kernel socket buffer size

# Display params
WINDOW_NAME = "FPGA Binary Image (1bpp)"
DISPLAY_SCALE = 1  # 1 = 1280x720; set 2/3/4 to scale up for visibility
FPS_SMOOTHING = 0.9

# Line numbering: define endianness used by FPGA for the 2-byte line index
# Commonly network byte order (big-endian). Change to '<H' if little-endian.
LINE_NUM_STRUCT = ">H"  # preferred/default (will auto-detect per packet as well)

# Bit order within each data byte: True => MSB->LSB maps left->right; False => LSB-first
BITORDER_MSB_FIRST = True

# Optional display inversion for visibility (False = normal, True = invert)
INVERT_DISPLAY = False

# Debug controls
DEBUG_PRINT_FIRST_N = 8  # print first N packets header/len to help diagnose
DEBUG_COUNTERS = {
    "pkts": 0,
    "idx_from_BE": 0,
    "idx_from_LE": 0,
    "idx_ambiguous": 0,
    "idx_invalid": 0,
}

# Optional: map incoming line index by modulo H to absorb wrap-around/overflow
MAP_LINEIDX_BY_MOD = True


def init_socket() -> socket.socket:    
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    # improve robustness under bursty traffic
    try:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, SOCKET_RCVBUF)
    except OSError:
        pass
    s.bind((LISTEN_IP, LISTEN_PORT))
    s.settimeout(0.0)  # non-blocking
    return s


def bitpack_to_bytes(line_bits: bytes) -> np.ndarray:
    """Convert 160 bytes (each bit a pixel) to 1280 uint8 pixels {0,255}.

    V1: Each byte from FPGA assumed MSB->LSB is left->right pixel order.
        If your hardware packs in LSB-first, flip with np.unpackbits(bitorder='little').
    """
    assert len(line_bits) == BYTES_PER_LINE
    # Convert to bits array of shape (1280,) values in {0,1}
    bitorder = 'big' if BITORDER_MSB_FIRST else 'little'
    bits = np.unpackbits(np.frombuffer(line_bits, dtype=np.uint8), bitorder=bitorder)
    # Map to 0/255 and ensure shape (H, W)
    return (bits * 255).astype(np.uint8)


def parse_line_index(hdr2: bytes) -> tuple[int | None, str]:
    """Return (line_idx, how) with auto-handling of endianness and 0/1-based.
    how in {"BE","LE","AMB","INV"} for diagnostics.
    """
    be = struct.unpack('>H', hdr2)[0]
    le = struct.unpack('<H', hdr2)[0]

    candidates = []
    # Accept 0-based direct
    if 0 <= be < IMAGE_HEIGHT:
        candidates.append((be, 'BE'))
    # Accept 1-based -> 0-based
    if 1 <= be <= IMAGE_HEIGHT:
        candidates.append((be - 1, 'BE'))

    if 0 <= le < IMAGE_HEIGHT:
        candidates.append((le, 'LE'))
    if 1 <= le <= IMAGE_HEIGHT:
        candidates.append((le - 1, 'LE'))

    # Deduplicate by index value, keep preference: BE over LE if same index
    if not candidates:
        return None, 'INV'
    # pick the first unique value; prefer a BE candidate if available
    # group by index
    seen = {}
    for idx, how in candidates:
        if idx not in seen:
            seen[idx] = how
            # prefer BE if appears
            if how == 'BE':
                break
    # choose first entry in seen
    idx = next(iter(seen.keys()))
    how = seen[idx]
    return idx, how


def make_frame_buffer() -> np.ndarray:
    # pre-allocate grayscale image buffer
    return np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)


def main():
    print(f"Listening on UDP {LISTEN_IP}:{LISTEN_PORT}, expecting payload={PAYLOAD_LEN} bytes per line")
    sock = init_socket()

    frame = make_frame_buffer()
    lines_received = np.zeros(IMAGE_HEIGHT, dtype=np.bool_)
    last_vsync_time = time.time()
    last_fps = 0.0
    next_report = time.time() + 1.0

    if DISPLAY_SCALE != 1:
        cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(WINDOW_NAME, IMAGE_WIDTH * DISPLAY_SCALE, IMAGE_HEIGHT * DISPLAY_SCALE)
    else:
        cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(WINDOW_NAME, IMAGE_WIDTH, IMAGE_HEIGHT)

    while True:
        # Gather packets available at this moment
        processed_any = False
        while True:
            try:
                data, addr = sock.recvfrom(RECV_BUF_SIZE)
            except BlockingIOError:
                break
            except socket.timeout:
                break

            if len(data) < PAYLOAD_LEN:
                # Ignore malformed/short packets
                continue

            # Debug: header and length for first few packets
            DEBUG_COUNTERS["pkts"] += 1
            if DEBUG_COUNTERS["pkts"] <= DEBUG_PRINT_FIRST_N:
                be_hdr = struct.unpack('>H', data[:2])[0]
                le_hdr = struct.unpack('<H', data[:2])[0]
                print(f"DEBUG pkt#{DEBUG_COUNTERS['pkts']}: len={len(data)} hdr_be={be_hdr} hdr_le={le_hdr}")

            # Parse line index robustly
            line_idx, how = parse_line_index(data[0:2])
            if line_idx is None:
                DEBUG_COUNTERS["idx_invalid"] += 1
                continue
            if MAP_LINEIDX_BY_MOD:
                line_idx = int(line_idx) % IMAGE_HEIGHT
            if how == 'BE':
                DEBUG_COUNTERS["idx_from_BE"] += 1
            elif how == 'LE':
                DEBUG_COUNTERS["idx_from_LE"] += 1
            else:
                DEBUG_COUNTERS["idx_ambiguous"] += 1

            line_bits = data[LINE_HEADER_LEN:LINE_HEADER_LEN + BYTES_PER_LINE]
            line_pixels = bitpack_to_bytes(line_bits)
            frame[line_idx, :] = line_pixels
            lines_received[line_idx] = True
            processed_any = True

        # If at least one line updated, show frame and compute FPS
        now = time.time()
        if processed_any:
            # Estimate FPS by detecting frame completion or using EWMA of line rate
            complete = bool(lines_received.all())
            if complete:
                last_vsync_time, last_fps = now, 1.0 / max(1e-6, now - last_vsync_time)
                lines_received.fill(False)
            else:
                # EWMA approximation based on line updates
                last_fps = FPS_SMOOTHING * last_fps + (1.0 - FPS_SMOOTHING) * (processed_any)

            show = frame if not INVERT_DISPLAY else (255 - frame)
            cv2.imshow(WINDOW_NAME, show)
            # 1ms wait keeps window responsive; ESC to quit
            k = cv2.waitKey(1) & 0xFF
            if k == 27:  # ESC
                break
            elif k == ord('i'):
                # toggle invert
                globals()['INVERT_DISPLAY'] = not INVERT_DISPLAY
                print(f"Invert display: {INVERT_DISPLAY}")
            elif k == ord('b'):
                # toggle bit order
                globals()['BITORDER_MSB_FIRST'] = not BITORDER_MSB_FIRST
                print(f"Bit order set to: {'MSB->LSB' if BITORDER_MSB_FIRST else 'LSB->MSB'}")
            elif k == ord('s'):
                out = f"frame_{int(time.time())}.png"
                cv2.imwrite(out, show)
                print(f"Saved {out}")

        # Periodic stats
        if now >= next_report:
            filled = int(lines_received.sum())
            print(f"{time.strftime('%H:%M:%S')} lines_in_frame={filled}/{IMAGE_HEIGHT} fps~={last_fps:.2f} "
                  f"pkts={DEBUG_COUNTERS['pkts']} BE={DEBUG_COUNTERS['idx_from_BE']} LE={DEBUG_COUNTERS['idx_from_LE']} "
                  f"AMB={DEBUG_COUNTERS['idx_ambiguous']} INV={DEBUG_COUNTERS['idx_invalid']}")
            next_report = now + 1.0

    sock.close()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
