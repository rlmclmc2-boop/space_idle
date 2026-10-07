extends RefCounted
## CPU-baked thumbnail, once per bounded appearance key. No viewport or frame work.
const WIDTH=192
static func polygon(image: Image,points: PackedVector2Array,color: Color) -> void:
 var bounds=Rect2(points[0],Vector2.ZERO)
 for p in points:bounds=bounds.expand(p)
 for y in range(maxi(0,int(bounds.position.y)),mini(WIDTH,int(bounds.end.y)+1)):
  for x in range(maxi(0,int(bounds.position.x)),mini(WIDTH,int(bounds.end.x)+1)):
   if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),points):image.set_pixel(x,y,color)
static func rect(image: Image,region: Rect2i,color: Color) -> void:
 image.fill_rect(region.intersection(Rect2i(0,0,WIDTH,WIDTH)),color)
static func circle(image: Image,center: Vector2,radius: float,color: Color,width: float=0) -> void:
 for y in range(maxi(0,int(center.y-radius-1)),mini(WIDTH,int(center.y+radius+2))):
  for x in range(maxi(0,int(center.x-radius-1)),mini(WIDTH,int(center.x+radius+2))):
   var distance=Vector2(x+0.5,y+0.5).distance_to(center)
   if absf(distance-radius)<=width*0.5 if width>0 else distance<=radius:image.set_pixel(x,y,color)
static func bake(style: Dictionary,source: Image,ultimate_color: Color) -> Texture2D:
 var image=Image.create(WIDTH,WIDTH,false,Image.FORMAT_RGBA8);image.fill(Color(0,0,0,0))
 var source_size=source.get_size();var ratio=minf(144.0/source_size.x,158.0/source_size.y)
 var dimensions=Vector2i(source_size*ratio);source.resize(dimensions.x,dimensions.y,Image.INTERPOLATE_CUBIC)
 image.blend_rect(source,Rect2i(Vector2i.ZERO,dimensions),Vector2i((WIDTH-dimensions.x)/2,(WIDTH-dimensions.y)/2))
 var accent: Color=style.color;var rank=int(style.rank)
 for side in [-1,1]:
  for n in rank:
   var x=96+side*75;var y=49+n*39
   var shape=PackedVector2Array([Vector2(x-side*11,y-13),Vector2(x+side*11,y-22),Vector2(x+side*7,y+19),Vector2(x-side*7,y+11)])
   polygon(image,shape,accent.darkened(0.15))
   var inset=PackedVector2Array([Vector2(x-side*7,y-10),Vector2(x+side*7,y-16),Vector2(x+side*4,y+13),Vector2(x-side*4,y+6)])
   polygon(image,inset,Color("dae3eb"))
   rect(image,Rect2i(x+side*5-2,y-12,4,20),accent)
 if rank>=2:rect(image,Rect2i(42,167,108,5),accent)
 if rank==3:
  for side in [-1,1]:
   var x=96+side*24
   polygon(image,PackedVector2Array([Vector2(x,2),Vector2(x+11,22),Vector2(x-11,22)]),accent)
  polygon(image,PackedVector2Array([Vector2(96,4),Vector2(104,19),Vector2(96,29),Vector2(88,19)]),accent)
 if style.ultimate:
  circle(image,Vector2(96,96),49,Color("243d50"),8);circle(image,Vector2(96,96),49,ultimate_color,4)
  polygon(image,PackedVector2Array([Vector2(175,8),Vector2(184,18),Vector2(175,28),Vector2(166,18)]),ultimate_color)
 if not style.category.is_empty():
  var at=Vector2(29,174);var ink=Color("243d50")
  if style.category=="shield":circle(image,at,10,ink,4)
  elif style.category=="attack":
   for n in 3:polygon(image,PackedVector2Array([at+Vector2((n-1)*10-3,8),at+Vector2((n-1)*10,-10),at+Vector2((n-1)*10+3,8)]),ink)
  elif style.category=="chain":
   rect(image,Rect2i(13,172,32,4),ink)
   for side in [-1,0,1]:circle(image,at+Vector2(side*14,0),4,ink)
  else:
   for side in [-1,1]:circle(image,at+Vector2(side*7,0),5,ink)
  if int(style.tier)==1:rect(image,Rect2i(12,188,34,3),accent)
 return ImageTexture.create_from_image(image)
