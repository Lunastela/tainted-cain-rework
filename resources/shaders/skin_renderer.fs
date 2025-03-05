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

#define MAX_STEPS 50
#define MAX_DIST 10.
#define SURF_DIST .005
#define TAU 6.283185
#define PI 3.141592

struct Cube {
    vec3 position, size, rotation;
    // Texture Offsets
    ivec2 topTexture, leftTexture, frontTexture, backTexture, rightTexture, bottomTexture;
    // Alt Texture Offsets
    ivec2 topAltTexture, leftAltTexture, frontAltTexture, backAltTexture, rightAltTexture, bottomAltTexture;
};

const float zoomFactor = 1. / 16.;
const float sizeTexture = 64.;

const float positionConstant = (sizeTexture * zoomFactor) / 16.;

#define CUBE_COUNT 6
Cube cubes[CUBE_COUNT];
// head
void initCubes() {
    cubes[0] = Cube(
        vec3(0., 5., 0.) * positionConstant,
        vec3(8.) * zoomFactor, 
        vec3(0.),
        // Texture Offsets
        ivec2(8, 0), // top
        ivec2(0, 8), // left
        ivec2(8, 8), // front
        ivec2(24, 8), // back
        ivec2(16, 8), // right
        ivec2(16, 0), // bottom
        // Alt Texture Offsets
        ivec2(40, 0), // top
        ivec2(32, 8), // left
        ivec2(40, 8), // front
        ivec2(56, 8), // back
        ivec2(48, 8), // right
        ivec2(48, 0) // bottom
    );
    cubes[1] = Cube(
        vec3(0.) * positionConstant,
        vec3(8., 12., 4.) * zoomFactor, 
        vec3(0.),
        // Texture Offsets
        ivec2(20, 16), // top
        ivec2(16, 20), // left
        ivec2(20, 20), // front
        ivec2(32, 20), // back
        ivec2(28, 20), // right
        ivec2(28, 16), // bottom
        // Alt Texture Offsets
        ivec2(20, 32), // top
        ivec2(16, 36), // left
        ivec2(20, 36), // front
        ivec2(32, 36), // back
        ivec2(28, 36), // right
        ivec2(28, 32) // bottom
    );
    cubes[2] = Cube(
        vec3(-1., -6., 0.) * positionConstant,
        vec3(4., 12., 4.) * zoomFactor, 
        vec3(0.),
        // Texture Offsets
        ivec2(4, 16), // top
        ivec2(0, 20), // left
        ivec2(4, 20), // front
        ivec2(12, 20), // back
        ivec2(8, 20), // right
        ivec2(8, 16), // bottom
        // Alt Texture Offsets
        ivec2(4, 16), // top
        ivec2(0, 36), // left
        ivec2(4, 36), // front
        ivec2(12, 36), // back
        ivec2(8, 36), // right
        ivec2(8, 32) // bottom
    );
    cubes[3] = Cube(
        vec3(1., -6., 0.) * positionConstant,
        vec3(4., 12., 4.) * zoomFactor, 
        vec3(0.),
        // Texture Offsets
        ivec2(20, 48), // top
        ivec2(16, 52), // left
        ivec2(20, 52), // front
        ivec2(28, 52), // back
        ivec2(24, 52), // right
        ivec2(24, 48), // bottom
        // Alt Texture Offsets
        ivec2(4, 48), // top
        ivec2(0, 52), // left
        ivec2(4, 52), // front
        ivec2(12, 52), // back
        ivec2(8, 52), // right
        ivec2(8, 48) // bottom
    );
    cubes[4] = Cube(
        vec3(-2.75, 0., 0.) * positionConstant,
        vec3(3., 12., 4.) * zoomFactor, 
        vec3(0.),
        // Texture Offsets
        ivec2(44, 16), // top
        ivec2(47, 20), // left
        ivec2(44, 20), // front
        ivec2(40, 20), // back
        ivec2(40, 20), // right
        ivec2(47, 16), // bottom
        // Alt Texture Offsets
        ivec2(44, 32), // top
        ivec2(47, 36), // left
        ivec2(44, 36), // front
        ivec2(40, 36), // back
        ivec2(40, 36), // right
        ivec2(47, 32) // bottom
    );
    cubes[5] = Cube(
        vec3(2.75, 0., 0.) * positionConstant,
        vec3(3., 12., 4.) * zoomFactor, 
        vec3(0.),
        // Texture Offsets
        ivec2(36, 48), // top
        ivec2(41, 52), // left
        ivec2(36, 52), // front
        ivec2(39, 52), // back
        ivec2(32, 52), // right
        ivec2(39, 48), // bottom
        // Alt Texture Offsets
        ivec2(54, 48), // top
        ivec2(60, 52), // left
        ivec2(54, 52), // front
        ivec2(57, 52), // back
        ivec2(50, 52), // right
        ivec2(57, 48) // bottom
    );
}

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

const float altLayerSize = 1.15;
float sdBox(vec3 p, vec3 s) {
    p = abs(p) - abs(s);
    return length(max(p, 0.)) + min(max(p.x, max(p.y, p.z)), 0.);
}

Cube armDistortion(vec3 pos, Cube cube) {
    float sineDisplacement = ((sin(ColorizeOut.g * 1.) - 1.) / 16.);
    float altDisplacement = (sin(ColorizeOut.g / 2.) / 16.);
    if ((cube != cubes[0]) && (cube != cubes[1])
    && (cube != cubes[2]) && (cube != cubes[3])) {
       if (cube == cubes[5]) {
           sineDisplacement *= -1.;
           altDisplacement *= -1.;
       }
       cube.rotation.z = sineDisplacement;
       cube.position.x += sineDisplacement / 2.;
       
       cube.rotation.x = altDisplacement;
       cube.position.z -= altDisplacement / 2.;
    }
    return cube;
}

float GetDistMin(vec3 p, Cube myCube, bool alt) {
    Cube cube = armDistortion(p, myCube);
    vec3 pos = Rotate(p - cube.position, -cube.rotation);
    return sdBox(pos, cube.size * (alt ? altLayerSize : 1.));
}

vec3 GetNormal(vec3 p, Cube cube, bool alt) {
    vec2 e = vec2(SURF_DIST, 0);
    vec3 n = GetDistMin(p, cube, alt) - 
    vec3(
        GetDistMin(p-e.xyy, cube, alt), 
        GetDistMin(p-e.yxy, cube, alt), 
        GetDistMin(p-e.yyx, cube, alt)
    );
    return normalize(n);
}

const float resizeFactor = 1. / 8.;
vec2 GetUV(vec3 pos, vec3 normal, Cube cube, bool alt) {
    vec2 uv;
    float upscale = resizeFactor / zoomFactor;
    vec3 size = cube.size * upscale;
    pos *= upscale;
    if (abs(normal.x) > 0.99) {
        vec2 originalUV = (pos.zy + size.zy) * resizeFactor / 2.;
        vec2 myTextureSide = vec2(
            normal.x > 0.0 ? (alt ? cube.leftAltTexture : cube.leftTexture) 
            : (alt ? cube.rightAltTexture : cube.rightTexture)
        ) / sizeTexture;
        uv = vec2(originalUV.x + myTextureSide.x, myTextureSide.y + size.y * resizeFactor - originalUV.y);
        if (normal.x <= 0.0) 
            uv.x = myTextureSide.x + size.z * resizeFactor - originalUV.x;
    } else if (abs(normal.y) > 0.99) {
        uv = (pos.xz + size.xz) * resizeFactor / 2.;
        uv += vec2(
            normal.y > 0.0 ? (alt ? cube.topAltTexture : cube.topTexture) 
            : (alt ? cube.bottomAltTexture : cube.bottomTexture)
        ) / sizeTexture;
    } else if (abs(normal.z) > 0.99) {
        uv = (pos.xy + size.xy) * resizeFactor / 2.;
        vec2 myTextureSide = vec2(
            normal.z > 0.0 ? (alt ? cube.frontAltTexture : cube.frontTexture) 
            : (alt ? cube.backAltTexture : cube.backTexture)
        ) / sizeTexture;
        uv = vec2(uv.x + myTextureSide.x, myTextureSide.y + size.y * resizeFactor - uv.y);
    }
    return uv;
}

vec4 ColorAtCubePosition(vec3 p, int selectedCube, bool alt, vec3 lightDir) {
    Cube cube = armDistortion(p, cubes[selectedCube]);
    vec3 n = Rotate(GetNormal(p, cubes[selectedCube], alt), -cube.rotation);
    vec3 pos = Rotate(p - cube.position, -cube.rotation);
    if (sdBox(pos, cube.size * (alt ? altLayerSize : 1.)) < SURF_DIST) {
        vec2 texUV = GetUV(pos / (alt ? altLayerSize : 1.), n * 2., cube, alt);
        vec4 col = texture(Texture0, texUV).rgba;
        float intensity = max(dot(n, lightDir), 0.1);
        col.rgb *= max(intensity, 0.4);
        return col;
    }
    return vec4(0.);
}

float RayMarch(vec3 ro, vec3 rd, out int selectedCube, bool alt) {
    float dO = 0.;
    vec4 col = vec4(0.);
    float lastAlpha = 0.;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        float dS = MAX_DIST;
        for (int i = 0; i < CUBE_COUNT; i++) {
            float minDist = GetDistMin(p, cubes[i], alt);
            float newAlpha = ColorAtCubePosition(ro + rd * minDist, i, alt, vec3(0.)).a;
            if (minDist < dS) {
                dS = minDist;
                lastAlpha = newAlpha;
                selectedCube = i;
            }
        }
        if (dO > MAX_DIST || dS < SURF_DIST) 
            break;
        dO += dS;
    }
    return dO;
}

vec3 GetRayDir(vec2 uv, vec3 p, vec3 l, float z) {
    vec3 f = normalize(l - p);
    vec3 r = normalize(cross(vec3(0, 1, 0), f));
    vec3 u = cross(f, r);
    vec3 c = f * z;
    vec3 i = c + uv.x * r + uv.y * u;
    return normalize(i);
}

void main(void) {
    initCubes();
    vec2 pa = vec2(1.0 + PixelationAmountOut, 1.0 + PixelationAmountOut) / TextureSizeOut;
    vec2 uv = PixelationAmountOut > 0.0 ? TexCoord0 - mod(TexCoord0, pa) + pa * 0.5 : TexCoord0;
    uv.xy = vec2(.5) - uv.xy;

    vec2 m = vec2(ColorizeOut.r, ColorizeOut.b);
    m.x = -m.x;
    
    vec3 ro = Rotate(vec3(0, 5, -5), vec3(mix(PI / 4.0, -PI / 1.4, m.y), -m.x * TAU, 0.));
    vec3 rd = GetRayDir(uv, ro, vec3(0.), 1.);
    
    vec4 col = vec4(0);
    vec3 lightDir = Rotate(vec3(.4, 1., .7), vec3(0., -(m.x + 0.5) * TAU, 0.));
    
    int selectedCube = 0;
    
    float d = RayMarch(ro, rd, selectedCube, false);
    col = ColorAtCubePosition(ro + rd * d, selectedCube, false, lightDir);
    
    d = RayMarch(ro, rd, selectedCube, true);
    vec4 altLayer = ColorAtCubePosition(ro + rd * d, selectedCube, true, lightDir);

    fragColor = Color0 * mix(col, altLayer, altLayer.a);
}