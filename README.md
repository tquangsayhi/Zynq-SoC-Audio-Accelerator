# Hardware-Accelerated Audio FIR Filter on Zynq SoC

## 📌 Project Overview
This project implements a complete, end-to-end System-on-Chip (SoC) audio processing pipeline on the **PYNQ-Z1 board**. It demonstrates hardware-software co-design by offloading real-time digital signal processing (DSP) to custom FPGA fabric while maintaining high-level software control via an ARM Cortex-A9 processor.

The core of the project is a custom **32-tap Low-Pass FIR Filter** written in Verilog, wrapped in an AXI4-Stream interface, and fed by a Direct Memory Access (DMA) engine. A Python driver manages physical memory allocation, DMA chunking, and `.wav` file processing.

## 🏗️ System Architecture
The system bridges the Programmable Logic (PL) and the Processing System (PS) of the Zynq-7000 SoC:

* **Processing System (PS - ARM Cortex-A9):** Runs Ubuntu Linux and Jupyter. Responsible for `.wav` file parsing, contiguous physical memory allocation (`CMA`), and dispatching control signals.
* **Direct Memory Access (DMA):** Bypasses the CPU to fetch bulk audio data directly from DDR3 RAM via the high-bandwidth **`S_AXI_HP0`** port and streams it to the custom IP.
* **Programmable Logic (PL - Custom IP):**
    * **AXI-Stream Wrapper:** Manages the `TVALID`, `TREADY`, `TDATA`, and `TLAST` handshake protocol. Features a custom 7-cycle shift register to perfectly synchronize the End-of-File (`TLAST`) marker with the filter's arithmetic latency.
    * **FIR Filter Engine:** A 32-tap shift-register pipeline processing 16-bit integer audio samples at 50MHz. Utilizes a `[30:15]` bit-shift for output scaling ($/ 2^{15}$).

## 🛠️ Tech Stack
* **Hardware Description:** Verilog, Xilinx Vivado 2024
* **Protocols:** AXI4-Lite (Control), AXI4-Stream (Data), AXI4 Memory-Mapped (DDR Access)
* **Software/Drivers:** Python 3, PYNQ Framework, Jupyter Notebooks
* **DSP/Math:** NumPy, SciPy (Signal processing and audio formatting)

## 🎧 How to Run

### 1. Hardware Setup
* Ensure your PYNQ-Z1 board is powered on and connected to your network.
* Upload the `fir_filter.bit` and `fir_filter.hwh` files to the Jupyter environment.
* Upload a standard 16-bit PCM `.wav` audio file (e.g., `input.wav`) to the same directory.

### 2. Software Execution
Run the provided Python script to flash the FPGA, allocate memory, and process the audio:

```import numpy as np
from scipy.io import wavfile
from pynq import Overlay, allocate
from IPython.display import Audio

# 1. Flash the FPGA
overlay = Overlay("fir_filter.bit")
dma = overlay.axi_dma_0

# 2. Load Audio
sample_rate, audio_data = wavfile.read("input.wav")
if len(audio_data.shape) > 1: 
    audio_data = audio_data[:, 0] # Convert to Mono
audio_data = audio_data.astype(np.int16)

# 3. Allocate Physical Memory
num_samples = len(audio_data)
input_buffer = allocate(shape=(num_samples,), dtype=np.int16)
output_buffer = allocate(shape=(num_samples,), dtype=np.int16)
np.copyto(input_buffer, audio_data)

# 4. Stream via DMA (Single Bulk Transfer)
print("Sending the entire audio file to the FPGA...")

# Open the receive bucket first, then fire the send hose
dma.recvchannel.transfer(output_buffer)
dma.sendchannel.transfer(input_buffer)

# Sleep until the hardware fires the completion interrupt
dma.sendchannel.wait()
dma.recvchannel.wait()

print("Hardware filtering complete!")

# 5. Play Hardware Output
display(Audio(output_buffer, rate=sample_rate))
