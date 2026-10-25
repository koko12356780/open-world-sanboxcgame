shader_type spatial;
uniform vec4 masonry : source_color;
uniform float style=0.0;
uniform float night_amount=0.0;
varying vec3 world;
varying vec3 wn;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize(mat3(MODEL_MATRIX)*NORMAL); }
void fragment() {
 float x=abs(wn.x)>.5?world.z:world.x;
 vec2 uv=vec2(x,world.y);
 vec2 cell=fract(uv/vec2(3.2,3.6));
 vec2 id=floor(uv/vec2(3.2,3.6));
 float pane=hash(id);
 float window=step(.17,cell.x)*step(cell.x,.83)*step(.22,cell.y)*step(cell.y,.86)*step(3.5,world.y)*step(abs(wn.y),.2);
 float frame=1.0-step(.205,cell.x)*step(cell.x,.795)*step(.26,cell.y)*step(cell.y,.825);
 vec2 brick=vec2(x*1.65+mod(floor(world.y*4.5),2.0)*.5,world.y*4.5);
 vec2 b=fract(brick);
 float mortar=1.0-smoothstep(.015,.045,min(min(b.x,1.-b.x),min(b.y,1.-b.y)));
 float grain=hash(floor(uv*95.0));
 float variation=hash(floor(brick));
 vec3 stone=masonry.rgb*(.85+grain*.06+variation*.17);
 if(style<.5) stone=mix(stone,vec3(.27,.25,.22),mortar*.45);
 else { float joint=step(.982,fract(world.y/3.6)); stone*=1.0-joint*.3; }
 float sill=step(.195,cell.y)*step(cell.y,.225)*step(.145,cell.x)*step(cell.x,.855);
 stone=mix(stone,masonry.rgb*.66,sill);
 vec3 view=normalize(CAMERA_POSITION_WORLD-world);
 float shift=(abs(wn.x)>.5?view.z:view.x)*.075;
 vec2 room=cell+vec2(shift,view.y*.045);
 float curtain=step(room.x,.28)+step(.73,room.x);
 float blind=step(.46,pane)*step(.55,room.y)*step(.68,fract(room.y*48.0));
 float ceiling=step(.72,room.y);
 float lit=step(.53,pane)*night_amount;
 vec3 glass=mix(vec3(.045,.075,.09),vec3(.15,.22,.26),pow(cell.y,2.0));
 glass=mix(glass,vec3(.33,.25,.15),lit*.7);
 glass*=1.0-curtain*.36-blind*.3;
 glass=mix(glass,vec3(.31,.34,.34),ceiling*.24);
 float mullion=1.0-smoothstep(.008,.018,abs(cell.x-.5));
 glass=mix(glass,vec3(.055,.061,.065),max(frame,mullion));
 ALBEDO=mix(stone,glass,window);
 ROUGHNESS=mix(.91,.22,window*(1.-max(frame,mullion)));
 METALLIC=window*.28;
 EMISSION=vec3(1.0,.63,.29)*window*lit*(1.-max(frame,mullion))*(.18+ceiling*.3)*(1.-curtain*.65);
}
