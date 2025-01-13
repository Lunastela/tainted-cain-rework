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

const float pi = 3.14159;

const vec2 pixelSize = vec2(16.0, 16.0);
vec2 adjustUV(vec2 uv) {
    ivec2 textureSize2d = textureSize(Texture0, 0);
    float myTextureSize = float(textureSize2d.y) / pixelSize.y;
    float texelSize = 1.0 / myTextureSize;
    return (uv * vec2(1., texelSize)) + vec2(0., mod(floor(ColorizeOut.r * 32.), myTextureSize) * texelSize);
}

bool voxelHit(vec3 pos) {
    vec2 uv = (pos.zy / pixelSize.xy) + 0.5;
    uv.y = 1. - uv.y;
    if ((pos.x == 0.0)
    && (pos.y > -(pixelSize.x / 2.))
    && (pos.y <= (pixelSize.x / 2.))
    && (pos.z >= -(pixelSize.x / 2.))
    && (pos.z < (pixelSize.x / 2.)))
        return (texture(Texture0, adjustUV(uv)).a > 0.1);
    return false;
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

vec3 voxelColor(vec3 pos, vec3 norm) {
    pos.y = pos.y - 1.;
    vec2 uv = (pos.zy / pixelSize.xy) + 0.5;
    uv.y = 1. - uv.y;
    return (enchantmentGlint(uv, ColorizeOut.a) * 0.65) + texture(Texture0, adjustUV(uv)).rgb;
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

float castRay(vec3 eye, vec3 ray, out float dist, out vec3 norm) {
    vec3 pos = floor(eye);
    vec3 ri = 1.0 / ray;
    vec3 rs = sign(ray);
    vec3 ris = ri * rs;
    vec3 dis = (pos - eye + 0.5 + rs * 0.5) * ri;

    vec3 dim = vec3(0.0);
    for (int i = 0; i < MAX_ITER; ++i) {
        if (voxelHit(pos)) {
            dist = dot(dis - ris, dim);
            norm = -dim * rs;
            return 1.0;
        }

        dim = step(dis, dis.yzx);
        dim *= (1.0 - dim.zxy);

        dis += dim * ris;
        pos += dim * rs;
    }
    return 0.0;
}

void main(void) {
    ivec2 textureSize2d = textureSize(Texture0, 0);
    float myTextureSize = float(textureSize2d.y) / pixelSize.y;

  	vec2 s_pos = (vec2(TexCoord0.x, 1. - TexCoord0.y * myTextureSize) - vec2(.5)) * (2. * (41.45 / 46.));
	float rotation = -(ColorizeOut.r);

	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 c_pos = vec3(10., 6., 10.) * rotateY(rotation);
	vec3 c_targ = vec3(0.0, 0.0, 0.0);

	vec3 c_dir = normalize(c_targ - c_pos);
	vec3 c_right = cross(c_dir, up);
	vec3 c_up = cross(c_right, c_dir);

	vec3 r_dir = normalize(c_dir);
	vec3 f_dir = c_pos + c_right * s_pos.x * pixelSize.x + c_up * s_pos.y * pixelSize.y;
	
	float dist = 0.0;
	vec3 norm;
	
	float hit = castRay(f_dir, r_dir, dist, norm);
	if (hit > 0.0) {
		vec3 p_pos = f_dir + dist * r_dir;

		vec3 color = voxelColor(p_pos - 0.001 * norm, norm);
		vec3 lightDir = vec3(.4, 1., .7) * rotateY(rotation);
		float intensity = max(dot(norm, lightDir), 0.1);

		fragColor = vec4((color.rgb * max(intensity, 0.4)), 1.0);
	}
}
