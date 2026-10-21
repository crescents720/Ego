"""Recorded second-pass foley/voices. Run after the initial base and Kenney tools."""
from pathlib import Path
import subprocess,json,wave,hashlib
import numpy as np
R=44100
root=Path(__file__).resolve().parents[1];base=root/'source/audio/revision2';out=root/'assets/audio/sfx';records=[]
def read(path,start=None,duration=None,filters=None,trim=True):
 path=base/path;cmd=['ffmpeg','-v','error','-i',str(path)]
 if start is not None:cmd+=['-ss',str(start)]
 if duration is not None:cmd+=['-t',str(duration)]
 if filters:cmd+=['-af',filters]
 cmd+=['-ac','1','-ar',str(R),'-f','f32le','-']
 x=np.frombuffer(subprocess.check_output(cmd),dtype='<f4').copy()
 if trim:
  indices=np.flatnonzero(np.abs(x)>max(np.max(np.abs(x))*.018,.0002))
  if len(indices):x=x[max(0,indices[0]-220):min(len(x),indices[-1]+1000)]
 return x
def save(name,x,sources,peak=.80):
 x=x.copy();x-=x.mean();x*=peak/max(np.max(np.abs(x)),1e-8)
 n=min(441,len(x)//4);x[:n]*=np.linspace(0,1,n);x[-n:]*=np.linspace(1,0,n)
 with wave.open(str(out/(name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(R);f.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
 records.append({'output':name+'.wav','sources':sources,'duration':len(x)/R,'peak':peak})
def mix(parts):
 x=np.zeros(max(int(delay*R)+len(y) for y,gain,delay in parts))
 for y,gain,delay in parts:
  i=int(delay*R);x[i:i+len(y)]+=y*gain
 return x
# New dry one-shot footsteps. Short body of the step, no trailing station echoes.
for i in range(3):
 path=['01-footstep_0.ogg','02-footstep.ogg','03-footstep.ogg'][i]
 x=read(Path(path),filters='highpass=f=70,lowpass=f=3600')[:int(.42*R)]
 save(f'step_hard_{i}',x,path,.50)
 path=f'Fantozzi-footsteps/flac/Fantozzi-SandL{i+1}.flac'
 save(f'step_grass_{i}',read(Path(path),filters='highpass=f=70,lowpass=f=4000')[:int(.42*R)],path,.50)
 # The new indoor take uses the other real walking recordings with a softer top end.
 path=['04-footstep.ogg','05-footstep.ogg','06-footstep.ogg'][i]
 save(f'step_inside_{i}',read(Path(path),filters='highpass=f=80,lowpass=f=2200')[:int(.40*R)],path,.45)
for i in range(3):
 path=f'swishes/swishes/swish-{5+i}.wav';x=read(Path(path),filters='highpass=f=150,lowpass=f=6500')
 save(f'bat_swing_{i}',x,path,.65)
 path=f'swishes/swishes/swish-{1+i}.wav';save(f'swing_{i}',read(Path(path)),path,.55)
 # Distinct body thump plus a short textured slap; no pitched metallic/score samples.
 path=f'hits/hit{[2,7,20][i]:02d}.mp3.flac';hit=read(Path(path),filters='highpass=f=45,lowpass=f=4200')[:int(.48*R)]
 save(f'punch_{i}',hit,path,.78)
 extra=f'hits/hit{[12,18,32][i]:02d}.mp3.flac';crack=read(Path(extra),filters='highpass=f=350,lowpass=f=5500')[:int(.22*R)]
 save(f'bat_hit_{i}',mix([(hit,.9,0),(crack,.3,.008)]),[path,extra],.86)
 heavy=f'hits/hit{[24,33,35][i]:02d}.mp3.flac';body=read(Path(heavy),filters='highpass=f=35,lowpass=f=1900')[:int(.65*R)]
 save(f'ram_flesh_{i}',mix([(body,1,0),(hit,.7,.035),(crack,.35,.012)]),[heavy,path,extra],.90)
 save(f'body_{i}',body,heavy,.70)
 for name,numbers in [('zombie',[19,20,21]),('zombie_hurt',[3,5,11]),('zombie_die',[16,17,18]),('bite',[2,4,6])]:
  path=f'zombies/zombies/zombie-{numbers[i]}.wav'
  save(f'{name}_{i}',read(Path(path)),path,.78)
# Same adult actress for hurt and death. No synthetic oscillator voices or cartoon pitch shifts.
for i,(start,duration) in enumerate([(2.07,.78),(3.68,.58),(7.30,.94)]):
 path='female_hurt_grunts_groans_1.ogg';save(f'hero_hurt_{i}',read(Path(path),start,duration),{'file':path,'start':start,'duration':duration},.77)
path='female_scream_1.ogg';save('hero_death',read(Path(path)),path,.82)
# Recorded breathing layered with restrained recorded pain, two clearly distinct injury levels.
breath=read(Path('breath.ogg'),35,7,filters='highpass=f=130,lowpass=f=6200',trim=False)
groan=read(Path('female_hurt_grunts_groans_1.ogg'),11.66,.98)
save('pain_medium',mix([(breath,.7,0),(groan,.12,1.4)]),['breath.ogg 35–42s','female_hurt_grunts_groans_1.ogg 11.66–12.64s'],.58)
breath=read(Path('breath.ogg'),3,5,filters='highpass=f=130,lowpass=f=6800',trim=False)
groan=read(Path('female_hurt_grunts_groans_1.ogg'),4.88,1.35)
gasp=read(Path('female_hurt_grunts_groans_1.ogg'),.30,.94)
save('pain_heavy',mix([(breath,.8,0),(groan,.22,.5),(gasp,.17,3.2)]),['breath.ogg 3–8s','female_hurt_grunts_groans_1.ogg 4.88–6.23s / .30–1.24s'],.66)
path='engine_start_up_01.wav';save('start',read(Path(path)),path,.88)
engines=list(base.rglob('engine-loop-1-normalized.wav'))
if engines:
 path=engines[0].relative_to(base);x=read(path,trim=False)
 # Equal-power-like short seam blending; no hard edge when the loop restarts.
 n=880;x[:n]=x[:n]*np.linspace(0,1,n)+x[-n:]*np.linspace(1,0,n);x=x[:-n]
 save('engine',x,str(path),.66)
 # A real motor tail gives the stopping transition a mechanical texture, not a UI note.
 save('stop',x[:int(.5*R)]*np.linspace(1,0,min(len(x),int(.5*R))),str(path),.45)
(base/'runtime_mapping.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
print('Prepared',len(records),'recorded replacement effects')
