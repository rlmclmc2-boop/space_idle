from pathlib import Path
import zlib,struct,json

def png(p):
 data=p.read_bytes();at=8;chunks=[]
 while at<len(data):
  n=struct.unpack_from('>I',data,at)[0];typ=data[at+4:at+8];body=data[at+8:at+8+n];at+=12+n
  if typ==b'IHDR':w,h,depth,color,*_=struct.unpack('>IIBBBBB',body)
  if typ==b'IDAT':chunks.append(body)
 assert depth==8 and color in (2,6),(depth,color)
 channels=4 if color==6 else 3;stride=w*channels;raw=zlib.decompress(b''.join(chunks));result=bytearray();previous=bytearray(stride)
 def paeth(a,b,c):
  p=a+b-c;ds=[abs(p-a),abs(p-b),abs(p-c)];return [a,b,c][ds.index(min(ds))]
 for y in range(h):
  f=raw[y*(stride+1)];row=bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
  for x in range(stride):
   a=row[x-channels] if x>=channels else 0;b=previous[x];c=previous[x-channels] if x>=channels else 0
   add=0 if f==0 else a if f==1 else b if f==2 else (a+b)//2 if f==3 else paeth(a,b,c)
   row[x]=(row[x]+add)&255
  result.extend(row);previous=row
 return result,w,h,channels

if __name__=='__main__':
 p=Path('test/work/battle-fix-20261013/space-battleship/.runtime');rows=[]
 for f in p.glob('contact-*-0.png'):
  a,w,h,c=png(f);b,*_=png(f.with_name(f.name.replace('-0.png','-1.png')));diff=[abs(x-y) for x,y in zip(a,b)]
  rows.append(dict(age=f.stem,max=max(diff),mae=sum(diff)/len(diff),channels_gt4=sum(v>4 for v in diff),changed_pixels=sum(any(diff[i:i+c]) for i in range(0,len(diff),c))))
 assert rows and max(row['max'] for row in rows)<=2,rows
 assert png(p/'contact-paused.png')[0]==png(p/'contact-rebase-1.png')[0],'Paused image changed'
 assert png(p/'contact-cleared.png')[0]==png(p/'contact-0.14-1.png')[0],'Clear left visible contacts'
 print(json.dumps({'pixel_comparisons':rows,'pause_exact':True,'clear_exact':True},indent=2))
