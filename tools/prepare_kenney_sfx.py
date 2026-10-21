"""Install a small CC0 selection from the two original Kenney archives."""
from pathlib import Path
import zipfile, subprocess, wave, numpy as np, json
root=Path(__file__).resolve().parents[1]
archive=root/'source/audio';out=root/'assets/audio/sfx'
selected=archive/'kenney_selected';selected.mkdir(exist_ok=True)
impact=zipfile.ZipFile(archive/'kenney_impact.zip');interface=zipfile.ZipFile(archive/'kenney_interface.zip')
for label,z in [('Impact',impact),('Interface',interface)]:
 (root/'licenses'/f'Kenney_{label}_Audio_CC0.txt').write_bytes(z.read('License.txt'))
groups={'step_hard':'footstep_concrete','step_grass':'footstep_grass','step_inside':'footstep_wood','punch':'impactPunch_medium','bat_hit':'impactPunch_heavy','body':'impactSoft_heavy','metal':'impactPlate_heavy','crash':'impactMetal_heavy'}
items=[]
for key,source in groups.items():
 for v in range(3):items.append((impact,f'Audio/{source}_{v:03d}.ogg',f'{key}_{v}'))
for key,source in {'pickup':'select','equip':'click','transfer':'drop','trash':'drop'}.items():
 for v in range(3):items.append((interface,f'Audio/{source}_{v+1:03d}.ogg',f'{key}_{v}'))
for key,source in {'ui':'click_001','reject':'error_004','complete':'confirmation_001'}.items():items.append((interface,f'Audio/{source}.ogg',key))
records=[]
for z,name,key in items:
 original=selected/Path(name).name;original.write_bytes(z.read(name))
 data=subprocess.check_output(['ffmpeg','-v','error','-i',str(original),'-ar','22050','-ac','1','-f','f32le','-'])
 samples=np.frombuffer(data,dtype='<f4').copy();samples*=.72/max(np.max(np.abs(samples)),1e-8)
 with wave.open(str(out/(key+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(22050);f.writeframes((samples*32767).astype('<i2').tobytes())
 records.append({'output':key+'.wav','archive':Path(z.filename).name,'original':name})
(archive/'kenney_mapping.json').write_text(json.dumps(records,indent=2))
print('Installed',len(items),'CC0 recorded effects')
