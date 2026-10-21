"""Prepare same-performer Japanese voice recordings; see Audio_Revision3.txt."""
from pathlib import Path
import subprocess,concurrent.futures,json,hashlib
base=Path('source/audio/japanese_voice');base.mkdir(exist_ok=True)
clips={'hero_hurt_0':'202_hidan/ita_01.wav','hero_hurt_1':'202_hidan/uu_01.wav','hero_hurt_2':'202_hidan/aah_01.wav','hero_death':'202_hidan/aaaa_02.wav','pain_medium_0':'195_serifu_others/haa_09.wav','pain_medium_1':'195_serifu_others/haa_15.wav','pain_medium_2':'195_serifu_others/haa_16.wav','pain_heavy_0':'195_serifu_others/zeihaa_01.wav','pain_heavy_1':'202_hidan/uu_06.wav','pain_heavy_2':'202_hidan/uu_11.wav'}
def prepare(job):
 name,relative=job
 url='https://amitaro.net/download/voice/'+relative
 original=base/relative.split('/')[-1]
 subprocess.run(['curl.exe','-sS','-L','--fail','--max-time','40','-e','https://amitaro.net/voice/voice_dl/',url,'-o',str(original)],check=True)
 target=Path('assets/audio/sfx')/(name+'.wav')
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(original),'-af','silenceremove=start_periods=1:start_duration=0.015:start_threshold=-48dB,areverse,silenceremove=start_periods=1:start_duration=0.015:start_threshold=-48dB,areverse,loudnorm=I=-20:TP=-3:LRA=7','-ar','44100','-ac','1','-c:a','pcm_s16le',str(target)],check=True)
 return name,{'source':url,'sha256':hashlib.sha256(original.read_bytes()).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:results=dict(pool.map(prepare,clips.items()))
# Keep the red-health variations breath-led: a short weak pain take followed
# by a different recorded panting phrase, rather than a lone hit grunt.
for name,start,end in [('pain_heavy_1',.69,1.67),('pain_heavy_2',1.90,3.75)]:
 target=Path('assets/audio/sfx')/(name+'.wav')
 temporary=target.with_suffix('.tmp.wav')
 filters=f'[0:a]asetpts=PTS-STARTPTS,apad=pad_dur=0.12[g];[1:a]atrim=start={start}:end={end},asetpts=PTS-STARTPTS,loudnorm=I=-20:TP=-3:LRA=7[b];[g][b]concat=n=2:v=0:a=1,loudnorm=I=-20:TP=-3:LRA=7[out]'
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(target),'-i',str(base/'zeihaa_01.wav'),'-filter_complex',filters,'-map','[out]','-ar','44100','-ac','1','-c:a','pcm_s16le',str(temporary)],check=True)
 temporary.replace(target)
 results[name]['breath_source']=results['pain_heavy_0']['source']
 results[name]['breath_source_sha256']=results['pain_heavy_0']['sha256']
 results[name]['breath_excerpt_seconds']=[start,end]
(base/'sources.json').write_text(json.dumps(results,indent=2))
print('Prepared',len(results),'Japanese voice clips')
