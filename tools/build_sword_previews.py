from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path('artifacts')
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
labels=['一段 · 斜斩','二连 · 斜斩 → 上挑','三连 · 再接横斩','四连 · 再接下劈','五连 · 斜斩收势']
for n in range(1,6):
 frames=[]
 for p in sorted((root/'sword_frames').glob(f'combo{n}_*.png')):
  im=Image.open(p).convert('RGB').resize((600,480),Image.Resampling.LANCZOS)
  ImageDraw.Draw(im).text((18,16),labels[n-1],font=font,fill='#ead6a4')
  frames.append(im)
 frames += [frames[-1]]*12
 frames[0].save(root/f'sword_combo{n}.gif',save_all=True,append_images=frames[1:],duration=33,loop=0,optimize=True)
# Only final cut of each module, showing five different directions.
board=Image.new('RGB',(1500,620),'#293c45');draw=ImageDraw.Draw(board)
for i,t in enumerate([.32,.78,1.24,1.70,2.16]):
 im=Image.open(root/'sword_frames'/f'combo{i+1}_{round(t*30):03}.png').crop((190,105,740,680)).resize((300,314),Image.Resampling.LANCZOS)
 board.paste(im,(i*300,150));draw.text((i*300+16,65),labels[i],font=font,fill='#ead6a4')
board.save(root/'sword_combo_designs.png')
