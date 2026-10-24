import reformat


# AMR phone recording: 8 kHz mono, upsampled by decode
def load_audio(src):
    return reformat.decode(src, "[0:a:0]anull")
