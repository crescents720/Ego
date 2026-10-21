from pathlib import Path
import concurrent.futures, subprocess, hashlib, json
root=Path(__file__).resolve().parents[1]
out=root/'assets/audio/music'; out.mkdir(parents=True,exist_ok=True)
archive=root/'source/audio';archive.mkdir(parents=True,exist_ok=True)
urls={
 'title':'https://www.scottbuckley.com.au/library/wp-content/uploads/2020/04/sb_signaltonoise.mp3',
 'explore':'https://www.scottbuckley.com.au/library/wp-content/uploads/2020/04/sb_signaltonoise_nomelody.mp3',
 'shelter':'https://www.scottbuckley.com.au/library/wp-content/uploads/2019/12/sb_undertow.mp3',
 'danger':'https://incompetech.com/music/royalty-free/mp3-royaltyfree/Lightless%20Dawn.mp3'}
expected={'title':14143939,'explore':14178456,'shelter':10000906,'danger':15197957}
(archive/'.gdignore').touch()
def fetch(pair):
 name,url=pair; dest=archive/(name+'.mp3')
 if not dest.exists() or dest.stat().st_size!=expected[name]:
  subprocess.run(['curl.exe','-L','--fail','--silent','--show-error','--connect-timeout','15','--max-time','600','-C','-',url,'-o',str(dest)],check=True)
 assert dest.stat().st_size==expected[name], f'Incomplete download: {name}'
 subprocess.run(['ffmpeg','-xerror','-hide_banner','-loglevel','error','-y','-i',str(dest),'-ar','44100','-c:a','libvorbis','-q:a','4',str(out/(name+'.ogg'))],check=True)
 return {'id':name,'url':url,'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: results=list(pool.map(fetch,urls.items()))
(archive/'downloads.json').write_text(json.dumps({'date':'2026-10-18','files':results},indent=2))
print('Music downloaded and converted:',len(results))
