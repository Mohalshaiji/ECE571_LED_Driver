import tkinter as tk
from tkinter import ttk
from vcdvcd import VCDVCD
import os
import time

# NOTE: Made with help from ChatGPT

# ------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------
VCD_PATH = "wave.vcd"
LED_SIGNAL = "led_controller_tb.LEDS[3:0]"
FPS = 50        # GUI frames per second
SPEED = 0.25     # 1.0 ~= realtime (just a bit slower)
# ------------------------------------------------------

# Utility ------------------------------------------------
def parse_bus_value(val):
    if not len(val) == 4: return "0000"
    return val[0:][::-1]   # reverse to make [0]=LSB


def duty_cycle_window(tv, target_time, window_ps, bit_index):
    """Compute duty cycle in a sliding window ending at target_time."""
    start = target_time - window_ps
    if start < 0: start = 0

    high_time = 0
    last_t = None
    last_bits = None

    for t, v in tv:
        bits = parse_bus_value(v)

        if last_t is None:
            last_t = t
            last_bits = bits
            continue

        if t < start:
            last_t = t
            last_bits = bits
            continue

        # window starts inside previous segment?
        seg_start = max(last_t, start)
        seg_end = min(t, target_time)

        if seg_end > seg_start:
            if bit_index < len(last_bits) and last_bits[bit_index] == '1':
                high_time += (seg_end - seg_start)

        last_t = t
        last_bits = bits

        if t > target_time:
            break

    return high_time / (target_time - start) if (target_time - start) > 0 else 0


# ------------------------------------------------------
# Load VCD ONCE and prepare playback timeline
# ------------------------------------------------------
if not os.path.exists(VCD_PATH):
    raise FileNotFoundError("Could not find VCD: " + VCD_PATH)

vcd = VCDVCD(VCD_PATH)
tv = vcd[LED_SIGNAL].tv

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
    global current_time, playing

    # Clamp
    if current_time > SIM_END:
        playing = False
        play_btn.config(text="Play")
        current_time = 0

    if playing:
        # Compute brightness for each LED
        window = int(1000 / FPS)*1_000_000_000*SPEED  # integration window
        for i in range(4):
            b = duty_cycle_window(tv, current_time, window, i)
            leds[i].set_brightness(b)

        # Update time label
        time_label.config(text=f"Time: {current_time/1_000_000_000:.2f} ms")

        # Advance time if playing
        dt = (1e12 / FPS) * SPEED      # ps/frame
        current_time += dt

    # Schedule next frame
    root.after(int(1000 / FPS), update_leds)

# Start GUI
update_leds()
root.mainloop()
