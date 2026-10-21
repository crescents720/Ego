from pathlib import Path
import numpy as np, wave
rng=np.random.default_rng(17); sr=22050; t=np.arange(sr*8)/sr
noise=rng.normal(0,.1,len(t)); low=np.convolve(noise,np.ones(25)/25,mode='same')*2
for at in rng.integers(0,len(t)-300,200):
 n=250;noise[at:at+n]+=rng.normal(0,.2,n)*np.exp(-np.arange(n)/30)
a=np.clip(low+noise*.25,-.9,.9)
with wave.open('assets/story/audio/fire.wav','wb') as f:f.setparams((1,2,sr,0,'NONE','not compressed'));f.writeframes((a*22000).astype('<i2').tobytes())
# Warm dream chime, then a low fracture hit; intentionally no external audio.
a=np.zeros(len(t))
for start,freq in [(0,523.25),(1.6,659.25),(3.2,783.99),(4.8,659.25),(6.4,523.25)]:
 u=t-start;env=np.where(u>=0,np.exp(-np.maximum(u,0)*1.1),0);a+=np.sin(2*np.pi*freq*u)*env*.10
with wave.open('assets/story/audio/dream.wav','wb') as f:f.setparams((1,2,sr,0,'NONE','not compressed'));f.writeframes((a*24000).astype('<i2').tobytes())
