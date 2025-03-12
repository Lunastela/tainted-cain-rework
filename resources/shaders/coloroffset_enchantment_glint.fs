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

const vec2 pixelSize = vec2(16.0, 16.0);
vec2 adjustUV(vec2 uv) {
    float myTextureSize = TextureSizeOut.y / pixelSize.y;
    float texelSize = 1.0 / myTextureSize;
    return (uv) + vec2(0., mod(floor(ColorizeOut.r * 32.), myTextureSize) * texelSize);
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
	// Clip
	if(dot(gl_FragCoord.xy, ClipPlaneOut.xy) < ClipPlaneOut.z)
		discard;
	
	// Pixelate
	vec2 pa = vec2(1.0 + PixelationAmountOut, 1.0 + PixelationAmountOut) / TextureSizeOut;
   	vec2 uv = PixelationAmountOut > 0.0 ? TexCoord0 - mod(TexCoord0, pa) + pa * 0.5 : TexCoord0; // uv silly

   	vec3 textureColor = (enchantmentGlint(uv, ColorizeOut.a) * 0.65) + texture(Texture0, adjustUV(uv)).rgb;
  	fragColor = Color0 * vec4(textureColor, texture(Texture0, adjustUV(uv)).a) * texture(Texture0, adjustUV(uv)).a;
	fragColor.rgb = mix(fragColor.rgb, fragColor.rgb - mod(fragColor.rgb, 1.0 / 16.0) + 1.0 / 32.0, clamp(PixelationAmountOut, 0.0, 1.0));
}