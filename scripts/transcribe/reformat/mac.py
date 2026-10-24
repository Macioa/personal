import reformat


# Mac recording: single audio stream
def load_audio(src):
    return reformat.decode(src, "[0:a:0]anull")
