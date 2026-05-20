#version 330 core
precision highp float;

uniform float u_time;
uniform vec2 u_resolution;
out vec4 outColor;

const int MAX_STEPS = 128;
const float SURF_DIST = 0.001;
const float MAX_DIST = 40.0;

struct ControlPoint {
    vec3 pos;
    float weight;
};

struct Hit {
    float dist;
    vec2 uv;
    float id; 
};

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 getBasis(float t) {
    float invT = 1.0 - t;
    return vec3(invT * invT, 2.0 * t * invT, t * t);
}

vec3 getPatchPoint(float u, float v, ControlPoint cp[9]) {
    vec3 bU = getBasis(u);
    vec3 bV = getBasis(v);
    vec3 pSum = vec3(0.0);
    float wSum = 0.0;
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            float w = bU[i] * bV[j] * cp[i * 3 + j].weight;
            pSum += cp[i * 3 + j].pos * w;
            wSum += w;
        }
    }
    return pSum / max(wSum, 0.00001);
}

Hit getNURBSSDF(vec3 p, ControlPoint cp[9]) {
    vec2 uv = vec2(0.5);
    float minDistSq = 1e10;
    const int GRID = 8; 
    for(int i = 0; i <= GRID; i++) {
        for(int j = 0; j <= GRID; j++) {
            vec2 testUV = vec2(float(i)/float(GRID), float(j)/float(GRID));
            vec3 pS = getPatchPoint(testUV.x, testUV.y, cp);
            float d2 = dot(p - pS, p - pS);
            if(d2 < minDistSq) { minDistSq = d2; uv = testUV; }
        }
    }
    for(int i = 0; i < 6; i++) {
        vec3 pS = getPatchPoint(uv.x, uv.y, cp);
        float e = 0.001;
        vec3 du = (getPatchPoint(uv.x + e, uv.y, cp) - pS) / e;
        vec3 dv = (getPatchPoint(uv.x, uv.y + e, cp) - pS) / e;
        vec3 r = pS - p;
        float a = dot(du, du);
        float b = dot(du, dv);
        float c = dot(dv, dv);
        float det = a * c - b * b;
        vec2 delta = vec2(dot(r, du) * c - dot(r, dv) * b, 
                          dot(r, dv) * a - dot(r, du) * b) / (det + 1e-6);
        uv = clamp(uv - delta * 0.5, 0.0, 1.0); 
    }
    vec3 pOnSurface = getPatchPoint(uv.x, uv.y, cp);
    return Hit(length(p - pOnSurface) - 0.02, uv, 1.0);
}

Hit sceneSDF(vec3 p) {
    ControlPoint cp[9];
    float R = 4.0;
    float w = 0.70710678; 
    float micro = 0.0001; 
    
    cp[0] = ControlPoint(vec3(micro, 0, 0), 1.0);
    cp[1] = ControlPoint(vec3(micro, 0, micro), 1.0);
    cp[2] = ControlPoint(vec3(0, 0, micro), 1.0);
    cp[3] = ControlPoint(vec3(R*0.5, 0, 0), 1.0);
    cp[4] = ControlPoint(vec3(R*0.5, 0, R*0.5), w);
    cp[5] = ControlPoint(vec3(0, 0, R*0.5), 1.0);
    cp[6] = ControlPoint(vec3(R, 0, 0), 1.0);
    cp[7] = ControlPoint(vec3(R, 0, R), w);
    cp[8] = ControlPoint(vec3(0, 0, R), 1.0);

    Hit res = getNURBSSDF(p, cp);
    
    for(int i = 0; i < 9; i++) {
        float d = length(p - cp[i].pos) - 0.15;
        if(d < res.dist) {
            res = Hit(d, vec2(0.0), 2.0 + float(i));
        }
    }
    return res;
}

vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        sceneSDF(p + e.xyy).dist - sceneSDF(p - e.xyy).dist,
        sceneSDF(p + e.yxy).dist - sceneSDF(p - e.yxy).dist,
        sceneSDF(p + e.yyx).dist - sceneSDF(p - e.yyx).dist
    ));
}

void main() {
    vec2 uv_scr = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.y, u_resolution.x);
    
    // Use u_time to add some movement
    vec3 ro = vec3(2.0 + cos(u_time)*2.0, 10.0, 2.0 + sin(u_time)*2.0); 
    vec3 target = vec3(2.0, 0.0, 2.0);
    
    vec3 f = normalize(target - ro);
    vec3 r = normalize(cross(vec3(0, 0, -1), f)); 
    vec3 u = cross(f, r);
    vec3 rd = normalize(f * 2.0 + uv_scr.x * r + uv_scr.y * u);

    float t = 0.0;
    Hit hit;
    for(int i = 0; i < MAX_STEPS; i++) {
        hit = sceneSDF(ro + t * rd);
        if(abs(hit.dist) < SURF_DIST || t > MAX_DIST) break;
        t += hit.dist;        
    }

    vec3 color = vec3(0.015, 0.015, 0.02);

    if(t < MAX_DIST) {
        vec3 p = ro + t * rd;
        vec3 n = getNormal(p);
        float diff = max(dot(n, normalize(vec3(1.0, 2.0, 1.0))), 0.0);
        
        if(hit.id < 1.5) { 
            vec2 grid = floor(hit.uv * 10.0);
            float checker = mod(grid.x + grid.y, 2.0);
            color = mix(vec3(0.08), vec3(0.12), checker) * (diff + 0.3);
        } else { 
            float noteIndex = hit.id - 2.0; 
            vec3 chromaticColor = hsv2rgb(vec3(noteIndex / 12.0, 0.85, 1.0));
            color = chromaticColor * (diff + 0.6);
            color += chromaticColor * 0.4; 
        }
    }

    outColor = vec4(pow(color, vec3(0.4545)), 1.0);
}