shader_type canvas_item;
render_mode unshaded;
uniform sampler2D camera_texture : repeat_disable,filter_nearest;
uniform sampler2D emission_texture : repeat_disable,filter_linear;
uniform float brightness_gain = 0.4;
uniform vec4 lamp_color : source_color = vec4(0.0,0.157,1.0,1.0);
uniform vec4 core_color : source_color = vec4(0.863,0.980,1.0,1.0);
vec3 to_linear(vec3 value) {return mix(value/12.92,pow((value+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),value));}
vec3 to_srgb(vec3 value) {return mix(value*12.92,1.055*pow(value,vec3(1.0/2.4))-0.055,step(vec3(0.0031308),value));}
float local_halo(vec2 uv,float radius,vec2 pixel_size) {
    vec2 delta=pixel_size*radius;
    float total=texture(emission_texture,uv).r*4.0;
    total+=texture(emission_texture,uv+vec2(delta.x,0.0)).r*2.0;
    total+=texture(emission_texture,uv-vec2(delta.x,0.0)).r*2.0;
    total+=texture(emission_texture,uv+vec2(0.0,delta.y)).r*2.0;
    total+=texture(emission_texture,uv-vec2(0.0,delta.y)).r*2.0;
    total+=texture(emission_texture,uv+delta).r+texture(emission_texture,uv-delta).r;
    total+=texture(emission_texture,uv+vec2(delta.x,-delta.y)).r+texture(emission_texture,uv+vec2(-delta.x,delta.y)).r;
    return total/16.0;
}
void fragment() {
    vec3 base=to_linear(textureLod(camera_texture,UV,0.0).rgb);
    float core=textureLod(emission_texture,UV,0.0).r;
    float halo=0.65*local_halo(UV,2.0,SCREEN_PIXEL_SIZE)+0.25*local_halo(UV,5.0,SCREEN_PIXEL_SIZE)+0.10*local_halo(UV,9.0,SCREEN_PIXEL_SIZE);
    vec3 emission=24.0*core_color.rgb*core+3.0*lamp_color.rgb*halo;
    COLOR=vec4(to_srgb(clamp(max(base,emission)*brightness_gain,vec3(0.0),vec3(1.0))),1.0);
}
