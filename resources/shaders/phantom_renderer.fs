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

#define MAX_STEPS 75
#define MAX_DIST 100.
#define SURF_DIST .005
#define TAU 6.283185
#define PI 3.141592

struct Cube {
    vec3 position;
    vec3 size;
    vec3 rotation;
    // Texture Offsets
    vec2 topTexture;
    vec2 leftTexture;
    vec2 frontTexture;
    vec2 backTexture;
    vec2 rightTexture;
    vec2 bottomTexture;
};

const float zoomFactor = 1. / 16.;
const float sizeTexture = 64.;

const float positionConstant = (sizeTexture * zoomFactor) / 16.;
Cube cubes[8] = Cube[](
    // head
    Cube(
        vec3(0., -.625, 3.) * positionConstant,
        vec3(7., 3., 5.) * zoomFactor, 
        vec3(0.0, 0.0, 0.0),
        // Texture Offsets
        vec2(5., 0.), // top
        vec2(0., 5.), // left
        vec2(5., 5.), // front
        vec2(17., 5.), // back
        vec2(12., 5.), // right
        vec2(12., 0.) // bottom
    ),
    // body
    Cube(
        vec3(0., 0., -.5) * positionConstant,
        vec3(5., 3., 9.) * zoomFactor, 
        vec3(0.0, 0.0, 0.0),
        // Texture Offsets
        vec2(9., 8.), // top
        vec2(0., 17.), // left
        vec2(9., 17.), // front
        vec2(23., 17.), // back
        vec2(14., 17.), // right
        vec2(14., 8.) // bottom
    ),
    // tail
    Cube(
        vec3(0., .25, -4.25) * positionConstant,
        vec3(3., 2., 6.) * zoomFactor, 
        vec3(0.0, 0.0, 0.0),
        // Texture Offsets
        vec2(9., 20.), // top
        vec2(3., 26.), // left
        vec2(9., 26.), // front
        vec2(18., 26.), // back
        vec2(12., 26.), // right
        vec2(12., 20.) // bottom
    ),
    // tail 2
    Cube(
        vec3(0., .25, -7.25) * positionConstant,
        vec3(1., 1., 6.) * zoomFactor, 
        vec3(0.0, 0.0, 0.0),
        // Texture Offsets
        vec2(10., 29.), // top
        vec2(4., 35.), // left
        vec2(10., 35.), // front
        vec2(17., 35.), // back
        vec2(11., 35.), // right
        vec2(11., 29.) // bottom
    ),
    // Wing R1
    Cube(
        vec3(2.75, .25, -.5) * positionConstant,
        vec3(6., 2., 9.) * zoomFactor, 
        vec3(0.0, 0.0, 0.0),
        // Texture Offsets
        vec2(32., 12.), // top
        vec2(38., 21.), // right
        vec2(32., 21.), // front
        vec2(47., 21.), // back
        vec2(24., 21.), // left
        vec2(38., 12.) // bottom
    ),
    Cube(
        vec3(7.5, .5, -.5) * positionConstant,
        vec3(13., 1., 9.) * zoomFactor, 
        vec3(0.0, 0.0, 0.0),
        // Texture Offsets
        vec2(25., 24.), // top
        vec2(42., 33.), // right
        vec2(25., 33.), // front
        vec2(51., 33.), // back
        vec2(24., 21.), // left
        vec2(38., 24.) // bottom
    ), // Wing L1
    Cube(
        vec3(-2.75, .25, -.5) * positionConstant,
        vec3(6., 2., 9.) * zoomFactor, 
        vec3(0.0, 0.0, 0.0),
        // Texture Offsets
        vec2(38., 36.), // top
        vec2(44., 45.), // right
        vec2(38., 45.), // front
        vec2(23., 45.), // back
        vec2(29., 45.), // left
        vec2(32., 36.) // bottom
    ),
    Cube(
        vec3(-7.5, .5, -.5) * positionConstant,
        vec3(13., 1., 9.) * zoomFactor, 
        vec3(0.0, 0.0, 0.0),
        // Texture Offsets
        vec2(38., 48.), // top
        vec2(51., 57.), // right
        vec2(25., 33.), // front
        vec2(51., 33.), // back
        vec2(25., 57.), // left
        vec2(25., 48.) // bottom
    )
);

mat2 Rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

vec3 Rotate(vec3 p, vec3 r) {
    p.yz *= Rot(r.x);
    p.xz *= Rot(r.y);
    p.xy *= Rot(r.z);
    return p;
}

float sdBox(vec3 p, vec3 s) {
    p = abs(p) - abs(s);
    return length(max(p, 0.)) + min(max(p.x, max(p.y, p.z)), 0.);
}

Cube wingDistortion(vec3 pos, Cube cube) {
    float sineDisplacement = sin(ColorizeOut.g * 3.) * 1.5 / 16.;
    float tailDisplacement = -1. + sin(ColorizeOut.g * 5.) / 2.;
    if ((cube != cubes[0])
    && (cube != cubes[1])) {
        if ((cube == cubes[2])
        || (cube == cubes[3])) {
            float nextRotation = pow(pos.z, 2.) * tailDisplacement / 16.;
            if (cube == cubes[3]) 
                cube.position.y += nextRotation / 1.5;
            cube.rotation.x += nextRotation;
        } else 
            cube.position.y += pow(pos.x, 2.) * sineDisplacement;
    }
    return cube;
}

float GetDistMin(vec3 p, Cube myCube) {
    Cube cube = wingDistortion(p, myCube);
    vec3 pos = Rotate(p - cube.position, -cube.rotation);
    float d = sdBox(pos, cube.size);
    return d;
}

float GetDist(vec3 p) {
    float minDist = MAX_DIST;
    for (int i = 0; i < cubes.length(); i++)
        minDist = min(minDist, GetDistMin(p, cubes[i]));
    return minDist;
}

float RayMarch(vec3 ro, vec3 rd) {
    float dO = 0.;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        float dS = GetDist(p);
        if (dO > MAX_DIST || dS < SURF_DIST) 
            break;
        dO += dS;
    }
    return dO;
}

vec3 GetNormal(vec3 p, Cube cube) {
    vec2 e = vec2(SURF_DIST, 0);
    vec3 n = GetDistMin(p, cube) - 
    vec3(
        GetDistMin(p-e.xyy, cube), 
        GetDistMin(p-e.yxy, cube), 
        GetDistMin(p-e.yyx, cube)
    );
    return normalize(n);
}

const float resizeFactor = 1. / 8.;
vec2 GetUV(vec3 pos, vec3 normal, Cube cube) {
    vec2 uv;
    float upscale = resizeFactor / zoomFactor;
    vec3 size = cube.size * upscale;
    pos *= upscale;
    if (abs(normal.x) > 0.99) {
        vec2 originalUV = (pos.zy + size.zy) * resizeFactor / 2.;
        vec2 myTextureSide = (normal.x > 0.0 ? cube.leftTexture : cube.rightTexture) / sizeTexture;
        uv = vec2(originalUV.x + myTextureSide.x, myTextureSide.y + size.y * resizeFactor - originalUV.y);
        if (normal.x <= 0.0) uv.x = myTextureSide.x + size.z * resizeFactor - originalUV.x;
    } else if (abs(normal.y) > 0.99) {
        uv = (pos.xz + size.xz) * resizeFactor / 2.;
        uv += (normal.y > 0.0 ? cube.topTexture.xy : cube.bottomTexture.xy) / sizeTexture;
    } else if (abs(normal.z) > 0.99) {
        uv = (pos.xy + size.xy) * resizeFactor / 2.;
        vec2 myTextureSide = (normal.z > 0.0 ? cube.frontTexture : cube.backTexture) / sizeTexture;
        uv = vec2(uv.x + myTextureSide.x, myTextureSide.y + size.y * resizeFactor - uv.y);
    }
    return uv;
}

vec3 GetRayDir(vec2 uv, vec3 p, vec3 l, float z) {
    vec3 f = normalize(l - p);
    vec3 r = normalize(cross(vec3(0, 1, 0), f));
    vec3 u = cross(f, r);
    vec3 c = f * z;
    vec3 i = c + uv.x * r + uv.y * u;
    return normalize(i) * .5;
}

void main(void) {
	vec2 pa = vec2(1.0 + PixelationAmountOut, 1.0 + PixelationAmountOut) / TextureSizeOut;
    vec2 uv = PixelationAmountOut > 0.0 ? TexCoord0 - mod(TexCoord0, pa) + pa * 0.5 : TexCoord0;
    uv = (vec2(uv.x, 1. - uv.y) - vec2(.5));

	vec2 m = vec2(ColorizeOut.r, ColorizeOut.b);
    vec3 ro = Rotate(vec3(0, 5, -5), vec3(mix(PI / 4.0, -PI / 1.4, m.y), -m.x * TAU, 0.));
    
    vec3 rd = GetRayDir(uv, ro, vec3(0.), 1.);
    
    vec3 lightDir = Rotate(vec3(.4, 1., .7), rd);
    float d = RayMarch(ro, rd);
    if (d < MAX_DIST) {
        vec3 p = ro + rd * d;
        for (int i = 0; i < cubes.length(); i++) {
            Cube cube = wingDistortion(p, cubes[i]);
            vec3 n = Rotate(GetNormal(p, cubes[i]), -cube.rotation);
            vec3 pos = Rotate(p - cube.position, -cube.rotation);
            if (sdBox(pos, cube.size) < SURF_DIST) {
                vec2 texUV = GetUV(pos, n * 2., cube);
                float intensity = max(dot(n, lightDir), 0.1);
                fragColor = texture(Texture0, texUV).rgba;
                fragColor.rgb *= max(intensity, 0.4);
                break;
            }
        }
    }
}