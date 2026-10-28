from pathlib import Path
import io
import json
import subprocess
from PIL import Image,ImageDraw

O=Path('/private/tmp/dart3d-w34-ios-live-production-review-20261028/r1')
P=Path('/private/tmp/dart3d-w34-ios-live-production-20261028/r1/parent')
receipts=[]
for stage,times in {
    'before':[1,3,5,7,9,11,13,15,17,19,21,22],
    'blend-before':[0.5,1,3,5,7,9,11,13,15,17,19,20],
    'blend-after':[1,3,5,9,11,13,15,17,19,21,23,25,27,29,31,33],
    'final-clean':[1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31],
}.items():
    sheet=Image.new('RGB',(804,((len(times)+3)//4)*305),'white');draw=ImageDraw.Draw(sheet)
    for i,t in enumerate(times):
        cmd=['ffmpeg','-v','error','-threads','2','-ss',str(t),'-i',str(P/stage/'journey.mp4'),'-frames:v','1','-vf','scale=402:874','-f','image2pipe','-vcodec','png','-']
        r=subprocess.run(cmd,capture_output=True)
        assert r.returncode==0 and r.stdout
        im=Image.open(io.BytesIO(r.stdout)).convert('RGB')
        crop=im.crop((0,70,402,640)).resize((201,285))
        x,y=(i%4)*201,(i//4)*305
        draw.text((x+3,y+3),f'{stage} {t}s',fill='black');sheet.paste(crop,(x,y+20))
        receipts.append({'stage':stage,'timeSeconds':t,'command':cmd,'exit':r.returncode})
    sheet.save(O/(stage+'-original-video-samples.png'))
(O/'visual-frame-receipts.json').write_text(json.dumps(receipts,indent=2)+'\n')
print('Created 56 timestamped samples from four original recordings; scene crop only, no color conversion added.')
