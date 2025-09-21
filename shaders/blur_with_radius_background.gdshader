shader_type canvas_item;

// ===========================================================
// adapted from: https://godotshaders.com/shader/set-corner-radius-for-texture/ by drift - CC0
uniform float corner_radius = 0;
uniform float texture_width = 1;
uniform float texture_height = 1;

bool in_rect(vec2 uv,vec2 orign,vec2 end)
{
  return all(lessThan(uv,end))&&all( greaterThan(uv,orign));
}

bool is_hid(vec2 uv,vec2 size,float radius)
{
  vec2 center = vec2(size.x*0.5,size.y*0.5);
  vec2 a = vec2(radius,radius);
  vec2 b = vec2(size.x-radius,size.y-radius);
	
  vec2 c = vec2(size.x-radius,radius);
  vec2 d = vec2(radius,size.y-radius);
	
  vec2 rd_origin = vec2(size.x - radius,0);
  vec2 rd_end = vec2(size.x,radius);
	
  vec2 lu_origin = vec2(0,size.y - radius);
  vec2 lu_end = vec2(radius,size.y);
	
	
  if(!in_rect(uv,a,b))
  {
    float dis = radius - 1.f;
    if(in_rect(uv,vec2(0.f),a))
    {
      dis = distance(a,uv);
    }
    if(in_rect(uv,b,size))
    {
      dis = distance(b,uv);
    }
    if(in_rect(uv,rd_origin,rd_end))
    {			
      dis = distance(c,uv);
    }
    if(in_rect(uv,lu_origin,lu_end))
    {
      dis = distance(d,uv);
    }
    return dis > radius;		
  }
  return false;
}


vec4 apply_radius(vec2 texture_size, vec2 uv, vec4 color) 
{
  float pixel_size_x = 1.0 / texture_size.x;
  float pixel_size_y = 1.0 / texture_size.y;
  float max_r = min(pixel_size_x,pixel_size_y) / 2.f;

if(is_hid(vec2(uv.x*pixel_size_x,uv.y*pixel_size_y),vec2(pixel_size_x,pixel_size_y),min(corner_radius,max_r)))  
  {
    color = vec4(0.0);
  }
return color;
}

// ===========================================================

// https://godotshaders.com/shader/web-safe-darkened-gaussian-blur/ - crisp_lad - CC0

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture,repeat_disable, filter_nearest;
/**
* How blurry the result should be.
* Limited to 20 because of performance, if you want feel free to break it.
*/
uniform float strength : hint_range(0.1, 20.0) = 3.3;
/**
* How dark the blur will be
*/
uniform float mix_percentage: hint_range(0.0, 1.0) = 0.3;

uniform vec3 mix_color: source_color = vec3(0,0,0);

float gaussianDistribution(float x, float STD){ // STD stands for standard deviation
	return exp(-(x*x)/(2.*STD*STD))/(sqrt(2.*PI)*STD);
}

vec3 gaussianblur(sampler2D sampler, vec2 pos, vec2 pixel_size, float sigmaUsed, int radius){
    vec3 blurredPixel = vec3(0.0);
    float total_weight = 0.0;
	// Loop over the radius (technically its a square)
    for(int i = -radius ; i <= radius; i++){ 
        for(int j = -radius; j <= radius; j++){
			// Calculate the offset from the current pixel
			vec2 offset = vec2(float(i), float(j))*pixel_size;
			vec2 changedPos = pos + offset;        
			
			// Calculate the weight based on the Gaussian distribution multiplying both dimensions (how far are X and Y from the center (pos))
			float weight = gaussianDistribution(float(i), sigmaUsed)*gaussianDistribution(float(j), sigmaUsed);
			// Add the weighted color value to the blurred pixel
			blurredPixel += texture(SCREEN_TEXTURE, changedPos).rgb * weight;
			total_weight += weight;
        }
    }
	// Normalize the blurred pixel color by the total weight
	blurredPixel/=total_weight;
    return blurredPixel;
}
void fragment() {
    vec3 PixelBlurred = gaussianblur(SCREEN_TEXTURE, SCREEN_UV, SCREEN_PIXEL_SIZE, strength, int(round(3.0 * strength)));
	vec3 color = mix(PixelBlurred, mix_color, mix_percentage);
    // The radius is 3*strength because it is the point where the Gaussian weight is near zero.
	COLOR = vec4(color, 1.);
	COLOR = apply_radius(vec2(texture_width, texture_height), UV, COLOR);
}

// =================================================================================

