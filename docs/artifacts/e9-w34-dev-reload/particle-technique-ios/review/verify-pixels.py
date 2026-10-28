from pathlib import Path
import struct,zlib,json,hashlib
P=Path('/private/tmp/dart3d-e9-particle-technique-probe-20261027/r1')
R=Path('/private/tmp/dart3d-e9-native-particle-review-20261027/r1')
# Independent standard-library PNG decoder; never executes or imports the parent's analyzer.
def png(path):
    data=path.read_bytes(); assert data[:8]==b'\x89PNG\r\n\x1a\n'
    off=8; compressed=b''; chunks=[]
    while off<len(data):
        size=struct.unpack('>I',data[off:off+4])[0]; typ=data[off+4:off+8]; body=data[off+8:off+8+size]
        assert zlib.crc32(typ+body)&0xffffffff==struct.unpack('>I',data[off+8+size:off+12+size])[0]
        if typ==b'IHDR': w,h,depth,color,compression,filtering,interlace=struct.unpack('>IIBBBBB',body)
        if typ==b'IDAT': compressed+=body
        chunks.append(typ.decode()); off+=size+12
    assert depth==8 and color in (2,6) and compression==filtering==interlace==0
    bpp=3 if color==2 else 4; stride=w*bpp; raw=zlib.decompress(compressed)
    assert len(raw)==h*(stride+1)
    prev=bytearray(stride); rows=[]
    for y in range(h):
        f=raw[y*(stride+1)]; row=bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
        for i in range(stride):
            a=row[i-bpp] if i>=bpp else 0; b=prev[i]; c=prev[i-bpp] if i>=bpp else 0
            if f==1: add=a
            elif f==2: add=b
            elif f==3: add=(a+b)//2
            elif f==4:
                estimate=a+b-c; distances=[abs(estimate-a),abs(estimate-b),abs(estimate-c)]
                add=[a,b,c][distances.index(min(distances))]
            else: assert f==0; add=0
            row[i]=(row[i]+add)&255
        rows.append([tuple(row[i:i+3]) for i in range(0,stride,bpp)]); prev=row
    return w,h,rows
cache={}
for folder in ['parent-runtime','parent-runtime-r2']:
    for path in (P/folder).glob('*.png'): cache[(folder,path.name)]=png(path)
def pixels(folder,name): return cache[(folder,name)][2]
def coords(rect):
    x,y,w,h=rect
    return ((a,b) for b in range(y,y+h) for a in range(x,x+w))
def different(a,b,rect): return sum(a[y][x]!=b[y][x] for x,y in coords(rect))
def magenta(c): return c[0]>240 and c[1]<20 and c[2]>240
def green(c): return c[1]>c[0]+25 and c[1]>c[2]+15
folder='parent-runtime-r2'; baseline=pixels(folder,'01-frozen-off.png'); constant=pixels(folder,'02-constant.png'); crop=(0,100,402,620); region=(220,180,160,380)
result={'decoder':'independent Python standard-library PNG unfilter/zlib; CRC checked; RGB bytes without color management','scene_crop_xywh':crop,'mesh_roi_xywh':(30,295,140,150),'image_dimensions':{f'{f}/{n}':[w,h] for (f,n),(w,h,_) in cache.items()},'r2':{}}
for path in sorted((P/folder).glob('*.png')):
    if path.name=='video-contact-sheet.png':continue
    im=pixels(folder,path.name)
    result['r2'][path.name]={'scene_changed_vs_frozen':different(im,baseline,crop),'mesh_roi_changed_vs_frozen':different(im,baseline,(30,295,140,150)),'magenta_scene_pixels_strict_r_gt240_g_lt20_b_gt240':sum(magenta(im[y][x]) for x,y in coords(crop)),'magenta_scene_pixels_parent_r_gt220_g_lt50_b_gt220':sum(im[y][x][0]>220 and im[y][x][1]<50 and im[y][x][2]>220 for x,y in coords(crop)),'samples':{f'{x},{y}':im[y][x] for x,y in [(80,360),(300,360),(270,255)]}}
interior=[]
for x,y in coords(region):
    c=baseline[y][x]
    if green(c) and all(baseline[y+dy][x+dx]==c for dx in [-1,0,1] for dy in [-1,0,1]): interior.append((x,y))
result['r2_green_interiors']={'region_xywh':region,'selection':'baseline g>r+25 and g>b+15, all nine RGB pixels in 3x3 equal center; selected on baseline only','selected':len(interior),'still_green':sum(green(constant[y][x]) for x,y in interior),'became_magenta':sum(magenta(constant[y][x]) for x,y in interior),'max_channel_delta':max(abs(constant[y][x][c]-baseline[y][x][c]) for x,y in interior for c in range(3))}
# Different selection thresholds and no interior filter give an additional independent check.
allgreen=[(x,y) for x,y in coords(region) if green(baseline[y][x])]
result['r2_all_baseline_green']={'selected':len(allgreen),'still_green':sum(green(constant[y][x]) for x,y in allgreen),'became_magenta':sum(magenta(constant[y][x]) for x,y in allgreen)}
f='parent-runtime'; old=pixels(f,'01-frozen-off.png'); result['r1']={}
for path in sorted((P/f).glob('*.png')):
    im=pixels(f,path.name)
    result['r1'][path.name]={'scene_changed_vs_frozen':different(im,old,crop),'magenta_scene_pixels_strict_r_gt240_g_lt20_b_gt240':sum(magenta(im[y][x]) for x,y in coords(crop)),'magenta_scene_pixels_parent_r_gt220_g_lt50_b_gt220':sum(im[y][x][0]>220 and im[y][x][1]<50 and im[y][x][2]>220 for x,y in coords(crop)),'samples':{f'{x},{y}':im[y][x] for x,y in [(80,360),(300,360)]}}
(R/'pixel-receipt.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result,indent=2))
