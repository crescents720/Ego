from pathlib import Path
import subprocess,concurrent.futures,struct,json,zlib,time
base=Path('artifacts/android_export_setup');size=123102082;step=4*1024*1024
partial=base/'android_template_entry.bin'
if partial.exists():
 data=partial.read_bytes()
 for start in range(0,len(data)//step*step,step):(base/f'part_{start}.bin').write_bytes(data[start:start+step])
def fetch(start):
 end=min(size,start+step)-1;p=base/f'part_{start}.bin'
 if p.exists()and p.stat().st_size==end-start+1:return
 subprocess.run(['curl.exe','-sS','-L','--fail','--retry','2','--connect-timeout','15','--max-time','90','-H','Accept: application/octet-stream','-r',f'{start}-{end}','https://api.github.com/repos/godotengine/godot-builds/releases/assets/425482597','-o',str(p)],check=True)
 if p.stat().st_size!=end-start+1:raise RuntimeError('Range length mismatch')
 print('Downloaded chunk',start//step+1,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=8)as pool:list(pool.map(fetch,range(0,size,step)))
data=b''.join((base/f'part_{start}.bin').read_bytes()for start in range(0,size,step))
h=struct.unpack_from('<4s5H3I2H',data,0);entry=next(e for e in json.loads((base/'template_entries.json').read_text())if e['name'].endswith('android_debug.apk'))
body=data[30+h[9]+h[10]:30+h[9]+h[10]+entry['compressed']];apk=zlib.decompress(body,-15)
assert len(apk)==entry['size'] and zlib.crc32(apk)==entry['crc'],'ZIP CRC verification failed'
p=Path('source/export_templates/4.6.3/android_debug.apk');p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(apk)
print('Official Android 4.6.3 debug template verified:',len(apk),flush=True)
