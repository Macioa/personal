import subprocess

import reformat


# Archive copy: AV1 CRF55 360p 0.5fps + Opus 12k voip mono -> <dst>.archive.mp4
def compress(src, dst):
    subprocess.check_call([
        "ffmpeg", "-y", "-v", "error", "-i", str(src),
        "-filter_complex", f"[0:v:0]fps=0.5,scale=-2:'min(360,ih)'[v];{reformat.mix(reformat.audio_streams(src))}[a]",
        "-map", "[v]", "-map", "[a]",
        "-c:v", "libaom-av1", "-crf", "55", "-b:v", "0", "-cpu-used", "6", "-row-mt", "1",
        "-c:a", "libopus", "-b:a", "12k", "-application", "voip", "-ac", "1",
        "-movflags", "+faststart", str(dst) + ".archive.mp4"])
