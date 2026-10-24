import reformat


# AMR phone recording: 8 kHz mono, upsampled by decode; dynaudnorm lifts quiet far side (~17 dB lower)
def load_audio(src):
    return reformat.decode(src, "[0:a:0]dynaudnorm=f=150:g=15")
