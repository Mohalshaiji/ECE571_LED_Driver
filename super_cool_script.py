"""
LED PWM Viewer

The purpose of this script is to read & parse a .vcd waveform from the LED Driver testbench.
It then displays a realtime* replay of the LED behavior in a small GUI in order to make the 
tb results more tangible.

Author: Riley Cameron
Date:   11/30/2025
"""
import tkinter as tk
from tkinter import ttk
from vcdvcd import VCDVCD
import os
import threading
from bisect import bisect_left, bisect_right

# NOTE: Made with help from ChatGPT

# ------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------
VCD_PATH = "wave.vcd"
LED_SIGNAL = "led_controller_tb.LEDS[3:0]"
FPS = 25        # GUI frames per second
SPEED = 1.0     # 1.0 ~= realtime (just a bit slower)
# ------------------------------------------------------

# Utility ------------------------------------------------
brightness_buffer = [0.0, 0.0, 0.0, 0.0]
buffer_lock = threading.Lock()
worker_busy = False

def parse_bus_value(val):
    if not len(val) == 4: return "0000"
    return val[0:][::-1]   # reverse to make [0]=LSB


def duty_cycle_window(tv, tv_times, target_time, window_ps, bit_index):
    """Compute duty cycle in O(logN + K) instead of O(N)."""

    start_time = target_time - window_ps
    if start_time < 0:
        start_time = 0

    # Find transitions within [start_time, target_time]
    start_idx = bisect_left(tv_times, start_time)
    end_idx   = bisect_right(tv_times, target_time)

    high_time = 0

    # Get previous sample so we know state at window start
    if start_idx > 0:
        last_t, last_v = tv[start_idx - 1]
        last_bits = parse_bus_value(last_v)
        last_t = start_time  # we know the state extends into the window
    else:
        # window begins before first timestamp
        last_t, last_v = tv[0]
        last_bits = parse_bus_value(last_v)
        last_t = 0

    # Iterate only over transitions inside the window
    for i in range(start_idx, end_idx):
        t, v = tv[i]
        seg_start = last_t
        seg_end = min(t, target_time)

        if bit_index < len(last_bits) and last_bits[bit_index] == '1':
            high_time += seg_end - seg_start

        last_bits = parse_bus_value(v)
        last_t = t

    # Final segment from last transition → target_time
    if bit_index < len(last_bits) and last_bits[bit_index] == '1':
        high_time += target_time - last_t

    window_length = target_time - start_time
    return high_time / window_length if window_length > 0 else 0


def brightness_worker(start_time, window):
    global brightness_buffer, worker_busy, tv_times

    local_result = [0.0]*4
    for i in range(4):
        local_result[i] = duty_cycle_window(tv, tv_times, start_time, window, i)

    with buffer_lock:
        brightness_buffer = local_result
        worker_busy = False


# ------------------------------------------------------
# Load VCD ONCE and prepare playback timeline
# ------------------------------------------------------
if not os.path.exists(VCD_PATH):
    raise FileNotFoundError("Could not find VCD: " + VCD_PATH)

vcd = VCDVCD(VCD_PATH)
tv = vcd[LED_SIGNAL].tv
tv_times = [t for t, _ in tv]

# Total simulation time (ps)
SIM_END = vcd.endtime

# ------------------------------------------------------
# GUI
# ------------------------------------------------------
root = tk.Tk()
root.title("LED PWM Viewer")
root.configure(background="#222222")

canvas = tk.Canvas(root, width=500, height=150, bg="#222222", borderwidth=0, highlightthickness=0)
canvas.pack(fill='x')

# LED widgets
class LedWidget:
    def __init__(self, canvas, x, y, size, label):
        self.canvas = canvas
        self.id = canvas.create_oval(
            x, y, x+size, y+size, fill="#000000",
            outline="#555555", width=3
        )
        self.text_id = canvas.create_text(
            x + size/2, y + size + 18,
            text=label, fill="white", font=("Consolas", 12)
        )
        self.brightness = 0.0

    def set_brightness(self, b):
        self.brightness = max(0, min(1, b))
        level = int(self.brightness * 255)
        color = f"#{level:02x}{int(level*0.8):02x}00"
        self.canvas.itemconfig(self.id, fill=color)
        self.canvas.itemconfig(self.text_id, text=f"{self.brightness*100:5.1f}%")

leds = [
    LedWidget(canvas, 60 + i*100, 40, 50, f"LED {i}")
    for i in range(4)
]

# Playback state
playing = False
current_time = 0       # ns

# Controls frame
controls = tk.Frame(root, bg="#222222")
controls.pack(fill="x", pady=5)

# Speed Slider
style = ttk.Style(root)
style.configure('Custom.Horizontal.TScale', background="#222222")
speed_var = tk.DoubleVar(value=SPEED)
speed_slider = ttk.Scale(
    controls, from_=0.05, to=5.0, orient="horizontal",
    length=150, variable=speed_var, style='Custom.Horizontal.TScale'
)
speed_slider.pack(side="right", padx=10)

speed_label = tk.Label(controls, text="Speed:", fg="white", bg="#222222")
speed_label.pack(side="right")



def play_pause():
    global playing
    playing = not playing
    play_btn.config(text="Pause" if playing else "Play")

def restart():
    global current_time
    current_time = 0
    update_leds()

play_btn = tk.Button(controls, text="Play", width=8, command=play_pause)
play_btn.pack(side="left", padx=10)

time_label = tk.Label(controls, text="", fg="white", bg="#222222")
time_label.pack(side="left", padx=10)

print("Total Time:", SIM_END, "ps")

# Update loop
def update_leds():
    global current_time, playing, worker_busy

    # Stop at end
    if current_time > SIM_END:
        playing = False
        play_btn.config(text="Play")
        current_time = 0

    if playing:
        # How long to integrate (ps)
        window = int(1000/FPS)*1_000_000_000*speed_var.get()

        # Launch worker if not already running
        if not worker_busy:
            worker_busy = True
            threading.Thread(
                target=brightness_worker,
                args=(current_time, window),
                daemon=True
            ).start()

        # Draw most recently computed brightness
        with buffer_lock:
            for i in range(4):
                leds[i].set_brightness(brightness_buffer[i])

        # Update time label
        time_label.config(text=f"Time: {current_time/1_000_000_000:.2f} ms")

        # Advance time
        dt = (1e12 / FPS) * speed_var.get()
        current_time += dt

    # Schedule next GUI frame
    root.after(int(1000/FPS), update_leds)


# Start GUI
update_leds()
root.mainloop()
