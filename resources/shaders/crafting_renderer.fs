#ifdef GL_ES
precision highp float;
#endif

#if __VERSION__ >= 140

in vec4 Color0;
in vec2 TexCoord0;
in vec4 ColorizeOut;
in vec3 ColorOffsetOut;
in vec2 TextureSizeOut;
in float PixelationAmountOut;
in vec3 ClipPlaneOut;
out vec4 fragColor;

#else

varying vec4 Color0;
varying vec2 TexCoord0;
varying vec4 ColorizeOut;
varying vec3 ColorOffsetOut;
varying vec2 TextureSizeOut;
varying float PixelationAmountOut;
varying vec3 ClipPlaneOut;
#define fragColor gl_FragColor
#define texture texture2D

#endif

uniform sampler2D Texture0;
const vec3 _lum = vec3(0.212671, 0.715160, 0.072169);

const int MAX_ITER = 64;
const float MAX_DIST = 20.0;
const float EPSILON = 0.0005;

const float pi = 3.14159;

float box(vec3 pos, vec3 size) {
   return length(max(abs(pos) - size, 0.0));
}

mat3 rotateY(float theta) {
   float c = cos(theta);
   float s = sin(theta);
   return mat3(
      vec3(c, 0, s),
      vec3(0, 1, 0),
      vec3(-s, 0, c)
   );
}

const vec3 gradientColor = vec3(167. / 255., 85. / 255., 1.) * 0.8;
float Hash(in vec2 p, in float scale) {
	p = mod(p, scale);
	return fract(sin(dot(p, vec2(27.16898, 38.90563))) * 5151.5473453);
}

float Noise(in vec2 p, in float scale ) {
	vec2 f;
	p *= scale;

	f = fract(p);
    p = floor(p);
	
    f = f*f*(3.0-2.0*f);
	
    float res = mix(mix(Hash(p, scale),
		Hash(p + vec2(1.0, 0.0), scale), f.x),
		mix(Hash(p + vec2(0.0, 1.0), scale),
		Hash(p + vec2(1.0, 1.0), scale), f.x), f.y);
    return res;
}

float fBm(in vec2 p, in float scale) {
	float f = 0.0;

    p = mod(p, scale);
	float amp = 0.7;
	
	for (int i = 0; i < 5; i++) {
		f += Noise(p, scale) * amp;
		amp *= .5;
		scale *= 2.;
	}
	return min(f, 1.0);
}

const float slope = 2.;
vec3 enchantmentGlint(vec2 uv, float time) {
    vec3 color = gradientColor * max(fBm(vec2(uv.x - time, 0.), 2.), 0.2);
    color += gradientColor * max(fBm(vec2(0., (uv.y + ((uv.x + (time * slope)) / slope))), 2.) - 0.25, 0.);
    if (time > 0.)
        return color;
    return vec3(0.);
}

void main(void)
{
  	vec2 s_pos = (vec2(TexCoord0.x, 1. - TexCoord0.y) - vec2(.5)) * (2. * (41.45 / 46.));

	float rotation = -(ColorizeOut.r);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 c_pos = vec3(8.0, 6.0, 8.0) * rotateY(rotation);
	vec3 c_targ = vec3(0.0, 0.0, 0.0);

	vec3 c_dir = normalize(c_targ - c_pos);
	vec3 c_right = cross(c_dir, up);
	vec3 c_up = cross(c_right, c_dir);
	
	vec3 r_dir = normalize(c_dir);
	vec3 pos = c_pos + c_right * s_pos.x + c_up * s_pos.y;
	
	float total_dist = 0.0;
	float dist = EPSILON;
	
	vec3 cubeSize = vec3(.5);
	for (int i = 0; i < MAX_ITER; i++) {
		if (dist < EPSILON || total_dist > MAX_DIST)
			break;
		
		dist = box(pos, cubeSize);
		total_dist += dist;
		pos += dist * r_dir;
	}
	
	if (dist < EPSILON) {
		vec2 eps = vec2(0.0, EPSILON);
		vec3 normal = normalize(vec3(
         box(pos + eps.yxx, cubeSize) - box(pos - eps.yxx, cubeSize),
			box(pos + eps.xyx, cubeSize) - box(pos - eps.xyx, cubeSize),
			box(pos + eps.xxy, cubeSize) - box(pos - eps.xxy, cubeSize)
      ));
		
		// Determine UV coordinates based on the normal
		vec2 uv;
		vec3 lighting = vec3(1.);
		if (abs(normal.x) > 0.99) {
			uv = pos.zy / cubeSize.zy * vec2(.125, .25) + vec2(0.5 + 0.125, 0.25);
			uv = (vec2(1.) - uv.xy);
            if (sign(normal.x) == -1.) {
                uv.x = 1. - uv.x;
                uv.x += 0.25;
            }
		} else if (abs(normal.y) > 0.99) {
			uv = pos.zx / cubeSize.xz * vec2(.125, .25) + vec2(0.625, 0.25);
            uv.x = 1. - uv.x;
		} else if (abs(normal.z) > 0.99) {
			uv = (pos.xy / cubeSize.xy * vec2(.125, .25)) + vec2(0.25 - 0.125, 0.25);
			uv.y = 1. - uv.y;
            if (sign(normal.z) == -1.) {
                uv.x += 0.25;
                uv.x = 1. - uv.x;
            }
		}
      
		vec3 textureColor = (enchantmentGlint(uv, ColorizeOut.a) * 0.65) + texture(Texture0, uv).rgb;

		// Sample the texture using the UV coordinates
		vec3 lightDir = vec3(.4, 1., .7) * rotateY(rotation);
		float intensity = max(dot(normal, lightDir), 0.1);
		fragColor = vec4((textureColor.rgb *  max(intensity, 0.4)), texture(Texture0, uv).a);
	}
}
