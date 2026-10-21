"""Deterministic original procedural effects; no third-party recordings."""
from pathlib import Path
import numpy as np, wave
R=22050
out=Path(__file__).resolve().parents[1]/'assets/audio/sfx';out.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(20261018)
def write(name,x,loop=False):
 x=np.asarray(x); x-=x.mean()
 if loop:
  n=min(2205,len(x)//8); cross=np.linspace(0,1,n); x[:n]=x[:n]*cross+x[-n:]*(1-cross); x=x[:-n]
 else:
  x*=np.minimum(1,np.arange(len(x))/110)*np.minimum(1,np.arange(len(x))[::-1]/330)
 x=x/max(np.max(np.abs(x)),1e-8)*.72
 with wave.open(str(out/(name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(R);f.writeframes((x*32767).astype('<i2').tobytes())
def base(d):
 t=np.arange(int(d*R))/R;n=rng.normal(0,1,len(t));return t,n,np.convolve(n,np.ones(25)/25,'same')
for group in ['step_hard','step_grass','step_inside','swing','bat_swing','punch','bat_hit','hurt','zombie','bite','body','door','metal','crash','pickup','equip','transfer','trash','repair']:
 for v in range(3):
  d={'zombie':1.5,'hurt':.32,'door':.55,'repair':.8}.get(group,.27)
  t,n,low=base(d);env=np.exp(-t*18);x=low*env
  if group.startswith('step'):x=(low*2+np.sin(2*np.pi*95*t)*.16)*env+(n*.05*np.exp(-t*27) if group=='step_grass' else 0)
  elif group in ['swing','bat_swing']:x=low*np.sin(np.pi*t/d)**2*np.sin(2*np.pi*140*t)*2
  elif group in ['punch','bat_hit','body','crash']:x=(np.sin(2*np.pi*(90*t-40*t*t))*.5+low*2+n*.1)*np.exp(-t*(13 if group!='crash' else 9))
  elif group in ['zombie','hurt','bite']:
   freq={'zombie':64,'hurt':210,'bite':95}[group]+v*11
   phase=2*np.pi*(freq*t+5*np.sin(t*9))
   x=(np.sin(phase)+.35*np.sin(phase*2)+low*.9)*np.sin(np.pi*t/d)**2*(.65+.35*np.sin(t*23))
  elif group in ['metal','door','repair']:x=(np.sin(2*np.pi*173*t)*.3+np.sin(2*np.pi*437*t)*.15+low)*env
  elif group in ['pickup','equip','transfer','trash']:x=low*env+np.sin(2*np.pi*(480 if group!='trash' else 240)*t)*env*.12
  write(f'{group}_{v}',x)
for name,freq in [('ui',650),('reject',180),('warning',440),('complete',800),('death',115),('start',72),('stop',55),('brake',120)]:
 t,n,low=base(.45);write(name,(np.sin(2*np.pi*(freq*t+freq*.15*t*t))*.5+low*.2)*np.exp(-t*9))
for name in ['engine','wind','night','lake','fire']:
 t,n,low=base(8)
 if name=='engine':x=sum(np.sin(2*np.pi*f*t)*a for f,a in [(48,.5),(96,.28),(144,.16),(240,.08)])*(.8+.2*np.sin(t*17))+low*.18
 elif name=='night':x=low*.12+np.sin(2*np.pi*2800*t)*np.maximum(0,np.sin(2*np.pi*2.3*t))**12*.04
 elif name=='lake':x=low*(.5+.5*np.sin(t*2.8))
 elif name=='fire':x=low+n*np.maximum(0,n-2.6)*.12
 else:x=low*(.65+.2*np.sin(t*.9))
 write(name,x,True)
print('Generated',len(list(out.glob('*.wav'))),'original effects')
