import numpy as np
import matplotlib.pyplot as plt
from scipy.io import wavfile
from pynq import Overlay, allocate
from IPython.display import Audio

# 1. Program the FPGA fabric first!
print("Loading Hardware...")
overlay = Overlay("fir_filter.bit") # Make sure this matches your filename!
dma = overlay.axi_dma_0

# 1. Load the Hardware (Assuming you already loaded the overlay in a previous cell)
# dma = overlay.axi_dma_0

# 2. Read the Audio File
file_name = "your_audio_file.wav"  # CHANGE THIS to your uploaded file's name
sample_rate, audio_data = wavfile.read("input2.wav")

# Pre-process: If the audio is stereo (2 channels), grab just the left channel (mono)
if len(audio_data.shape) > 1:
    audio_data = audio_data[:, 0]

# Cast to int16 to perfectly match your Verilog hardware limits
audio_data = audio_data.astype(np.int16)
num_samples = len(audio_data)
print(f"Loaded {num_samples} samples at {sample_rate} Hz.")

# 3. Allocate Contiguous Memory for the DMA
input_buffer = allocate(shape=(num_samples,), dtype=np.int16)
output_buffer = allocate(shape=(num_samples,), dtype=np.int16)

# 4. Copy the real audio data into the DMA's input buffer
np.copyto(input_buffer, audio_data)

# 5. Fire the DMA! (Bucket first, then Hose)
print("Sending audio to the FPGA...")
dma.recvchannel.transfer(output_buffer)
dma.sendchannel.transfer(input_buffer)

# Wait for the hardware interrupt to signal completion
dma.sendchannel.wait()
dma.recvchannel.wait()
print("Hardware filtering complete!")

# 6. Save the filtered audio to a new file you can download
wavfile.write("filtered_output.wav", sample_rate, output_buffer)
print("Saved to 'filtered_output.wav'")

# 7. Listen to your hardware output directly in Jupyter!
display(Audio(output_buffer, rate=sample_rate))