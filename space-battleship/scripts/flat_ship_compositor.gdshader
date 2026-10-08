shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform vec2 origin;
uniform vec2 extent;
uniform int item_count = 0;
uniform float animation_time = 0.0;
uniform vec4 centers[48];
uniform vec4 params[48];
uniform vec4 assets[48];
uniform vec4 effects[48];
// Replaced with a bounded sampler switch once per appearance layout.
vec4 sample_asset(int index, vec2 uv) { return vec4(0.0); }

vec2 turn(vec2 p, vec2 axis) {
	float c=axis.x, s=axis.y;
	return vec2(c*p.x+s*p.y,-s*p.x+c*p.y);
}
vec4 atlas_sample(int index, vec2 p, float frame, float columns, bool height_map) {
	vec2 uv=p+0.5;
	if(any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0))))return vec4(0.0);
	vec2 tile=vec2(mod(frame,columns),floor(frame/columns));
	vec2 packed_uv=(tile+uv)/columns;
	packed_uv.y=(packed_uv.y+(height_map ? 1.0 : 0.0))*0.5;
	return sample_asset(index,packed_uv);
}
void fragment() {
	vec2 screen=origin+UV*extent;
	vec4 colors[48];
	float depths[48];
	bool additive[48];
	int count=0;
	for(int i=0;i<48;i++) {
		if(i>=item_count)break;
		vec4 center=centers[i], parameter=params[i], asset=assets[i], effect=effects[i];
		int kind=int(asset.x);
		vec2 world=(screen-center.xy)/center.zw;
		vec2 local=turn(screen-center.xy,vec2(asset.z,-asset.w))/center.zw;
		vec4 color=vec4(0.0);
		float depth=parameter.y;
		if(kind==1) {
			// Rotate the two bracketing renders onto the exact current silhouette.
			// Interpolation changes lighting, never steps the turret geometry.
			if(dot(world,world)>0.5)continue;
			float first=asset.z, second=asset.w;
			vec2 p0=turn(world,effect.zw);
			vec2 p1=turn(p0,vec2(0.995184726672,0.098017140330));
			vec4 c0=atlas_sample(int(asset.y),p0,first,effect.x,false);
			vec4 c1=atlas_sample(int(asset.y),p1,second,effect.x,false);
			float weight=effect.y;
			// Premultiplication avoids black fringes during interpolation.
			color=mix(c0,c1,weight);
			if(color.a>0.00001)color.rgb/=color.a;
			vec4 d0=atlas_sample(int(asset.y),p0,first,effect.x,true);
			vec4 d1=atlas_sample(int(asset.y),p1,second,effect.x,true);
			float w0=(1.0-weight)*d0.a,w1=weight*d1.a;
			depth+=parameter.z+parameter.w*(d0.r*(1.0-weight)+d1.r*weight)/max(w0+w1,0.00001);
		} else {
			if(any(greaterThan(abs(local),vec2(0.5))))continue;
			if(kind==4) {
				color=atlas_sample(int(asset.y),local,0.0,1.0,false);
				vec4 height=atlas_sample(int(asset.y),local,0.0,1.0,true);
				if(color.a>0.00001)color.rgb/=color.a;
				depth+=parameter.z+parameter.w*height.r/max(height.a,0.00001);
			} else if(kind==0)color=sample_asset(int(asset.y),local+0.5);
			else if(kind==2) {
				// Exported interpolants from the original 32x16 sphere mesh.
				vec4 map=sample_asset(int(asset.y),local+0.5);
				vec3 point=map.rgb/max(map.a,0.00001)*2.0-1.0;
				vec3 normal=normalize(point/vec3(effect.z,1.0,effect.w));
				float edge=pow(1.0-abs(normal.y),3.2);
				float distance_to_hit=length(normalize(point)-normalize(vec3(-0.45,0.65,-0.6)));
				float cap=1.0-smoothstep(0.06,0.64,distance_to_hit);
				float ring=1.0-smoothstep(0.02,0.08,abs(distance_to_hit-(1.0-effect.y)*0.65));
				float impact=effect.y*(cap*0.5+ring*0.8);
				color.rgb=mix(vec3(0.06,0.38,0.66),vec3(0.45,0.83,0.93),impact)*1.3;
				color.a=clamp(effect.x*(0.06+edge*1.6)+impact*effect.x*2.6,0.0,0.55)*map.a;
				depth+=point.y*parameter.w;
			} else {
				vec2 uv=local+0.5;
				float width=abs(uv.x-0.5)*2.0;
				float envelope=pow(max(0.0,1.0-width),1.6)*pow(1.0-uv.y,1.4);
				float pulse=0.88+sin(animation_time*12.0+effect.y)*0.07;
				color.rgb=mix(vec3(0.015,0.25,0.72),vec3(0.25,0.86,1.0),envelope)*1.5;
				color.a=envelope*pulse*clamp(effect.x*0.65,0.0,1.0);
			}
		}
		if(color.a<=0.00001)continue;
		// Only overlapping fragments enter this list. Sort actual depth, not
		// ship-center order: carriers and turret bases may cross the flagship.
		int cursor=count;
		for(int j=47;j>0;j--) {
			if(j>cursor)continue;
			if(depths[j-1]<=depth)break;
			colors[j]=colors[j-1];depths[j]=depths[j-1];additive[j]=additive[j-1];cursor=j-1;
		}
		colors[cursor]=color;depths[cursor]=depth;additive[cursor]=kind==3;count++;
	}
	vec4 result=vec4(0.0);
	for(int i=0;i<48;i++) {
		if(i>=count)break;
		vec4 c=colors[i];
		if(additive[i])result+=vec4(c.rgb*c.a,c.a*c.a);
		else result=vec4(c.rgb*c.a,c.a)+result*(1.0-c.a);
		result=clamp(result,vec4(0.0),vec4(1.0));
	}
	// Match both original stages: transparent 3D target accumulates premultiplied
	// RGB; ShipComposite uses the default CanvasItem blend_mix afterwards.
	result=clamp(result,vec4(0.0),vec4(1.0));
	COLOR=vec4(result.rgb*result.a,result.a);
}
