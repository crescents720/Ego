from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
r=Path('artifacts/sword_v2_frames')
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
for n in range(1,6):
 frames=[]
 for p in sorted((r/'view0').glob(f'combo{n}_*.png')):
  b=Image.new('RGB',(1000,440),'#293c45')
  for a in [0,1]:
   im=Image.open(r/f'view{a}'/p.name).resize((500,400),Image.Resampling.LANCZOS);b.paste(im,(500*a,40))
  d=ImageDraw.Draw(b);d.text((20,8),f'新版 {n}段 · 斜前方',font=font,fill='#ead6a4');d.text((520,8),'侧面检查',font=font,fill='#ead6a4');frames.append(b)
 frames+=[frames[-1]]*15
 frames[0].save(f'artifacts/sword_v2_combo{n}.gif',save_all=True,append_images=frames[1:],duration=33,loop=0,optimize=True)
# Keyposes across the complete five-cut action, both angles.
points=[0,.32,.43,.50,.84,1.0,1.35,1.54,1.96,2.14,2.66,2.88,3.56]
board=Image.new('RGB',(260*len(points),440*2),'#293c45');d=ImageDraw.Draw(board)
for i,t in enumerate(points):
 for a in [0,1]:
  im=Image.open(r/f'view{a}'/f'combo5_{round(t*30):03}.png').crop((190,100,730,700)).resize((260,289),Image.Resampling.LANCZOS)
  board.paste(im,(i*260,80+a*440));d.text((i*260+8,30+a*440),f'{t:.2f}s',font=font,fill='#ead6a4')
board.save('artifacts/sword_v2_pose_audit.png')
