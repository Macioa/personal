import reformat


# Windows recording: mix all audio streams (mic + system)
def load_audio(src):
    return reformat.decode(src, reformat.mix(reformat.audio_streams(src)))
