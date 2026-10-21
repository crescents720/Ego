"""Pack the programmatically rendered game-animation frames for review."""
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]/'artifacts'
for action in ['punch','bite','walk']:
    frames=[Image.open(p).convert('RGB').resize((600,400),Image.Resampling.LANCZOS)for p in sorted((root/'combat_frames').glob(action+'_*.png'))]
    frames[0].save(root/('combat_'+action+'.gif'),save_all=True,append_images=frames[1:],duration=33,loop=0)
    print(action,len(frames),'frames')
