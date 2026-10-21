import numpy as np,wave
from pathlib import Path
rate=22050
t=np.arange(int(rate*1.4))/rate
rng=np.random.default_rng(37)
noise=rng.normal(0,1,len(t))
soft=np.convolve(noise,np.ones(13)/13,mode='same')
phase=2*np.pi*(95*(1-np.exp(-t*3))/3+31*t)
boom=np.sin(phase)*np.exp(-t*4)
crack=noise*np.exp(-t*32)*.32
rumble=soft*np.exp(-t*2.7)*1.4
x=(boom*.7+crack+rumble)*(1-np.exp(-t*1300))
x*=np.minimum(1,(1.4-t)/.18)
x=x/(np.max(np.abs(x))+1e-9)*.88
with wave.open('assets/audio/rv_explosion.wav','wb') as f:
 f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes((x*32767).astype('<i2').tobytes())
