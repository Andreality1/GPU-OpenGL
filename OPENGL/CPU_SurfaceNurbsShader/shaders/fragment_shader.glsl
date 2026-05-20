#version 330 core

out vec4 FragColor;

uniform float u_time;

// Based on your glfwCreateWindow(800, 600, ...)
vec2 u_resolution = vec2(800.0, 600.0);

const int MAX_STEPS = 128;
const float SURF_DIST = 0.005;
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

// --- MATH HELPERS ---

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float dfLine(vec3 p, vec3 a, vec3 b) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float dfSphere(vec3 p, vec3 center, float radius) {
    return length(p - center) - radius;
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

float solveNURBS(vec3 p, ControlPoint cp[9], out vec2 outUV) {
    vec2 uv = vec2(0.5);
    float minDistSq = 1e10;
    const int GRID = 4; 
    for(int i = 0; i <= GRID; i++) {
        for(int j = 0; j <= GRID; j++) {
            vec2 testUV = vec2(float(i)/float(GRID), float(j)/float(GRID));
            vec3 pS = getPatchPoint(testUV.x, testUV.y, cp);
            float d2 = dot(p - pS, p - pS);
            if(d2 < minDistSq) { minDistSq = d2; uv = testUV; }
        }
    }
    for(int i = 0; i < 5; i++) {
        vec3 pS = getPatchPoint(uv.x, uv.y, cp);
        float e = 0.001;
        vec3 du = (getPatchPoint(uv.x + e, uv.y, cp) - pS) / e;
        vec3 dv = (getPatchPoint(uv.x, uv.y + e, cp) - pS) / e;
        vec3 r = pS - p;
        float a = dot(du, du);
        float b = dot(du, dv);
        float c = dot(dv, dv);
        float det = a * c - b * b;
        if (abs(det) < 1e-7) break; 
        vec2 delta = vec2(dot(r, du) * c - dot(r, dv) * b, 
                          dot(r, dv) * a - dot(r, du) * b) / det;
        uv = clamp(uv - delta * 0.5, 0.0, 1.0); 
    }
    outUV = uv;
    return length(p - getPatchPoint(uv.x, uv.y, cp));
}

float getControlVisuals(vec3 p, ControlPoint cp[9], out float dPoints) {
    float dNet = 1e10;
    dPoints = 1e10;
    float netThickness = 0.015;
    float pointRadius = 0.18;

    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            dPoints = min(dPoints, dfSphere(p, cp[i*3+j].pos, pointRadius));
            if (i < 2) dNet = min(dNet, dfLine(p, cp[i*3+j].pos, cp[(i+1)*3+j].pos));
            if (j < 2) dNet = min(dNet, dfLine(p, cp[i*3+j].pos, cp[i*3+(j+1)].pos));
        }
    }
    return dNet - netThickness;
}

// --- SCENE ---

Hit sceneSDF(vec3 p) {
    float oscillation = sin(u_time * 2.0) * 3.0;
    float w_circ = 0.70710678;
    
    // 1. SLAB
    vec3 pSlab = p;
    pSlab.y -= oscillation;
    vec3 pSlabFold = vec3(abs(pSlab.x), pSlab.y, abs(pSlab.z));
    
    ControlPoint cpSlab[9];
    float R_anim = 3.0 * (0.75 + 0.25 * sin(u_time * 2.0)); 
    float m = 0.001;
    cpSlab[0]=ControlPoint(vec3(m,0,0),1.); cpSlab[1]=ControlPoint(vec3(m,0,m),1.); cpSlab[2]=ControlPoint(vec3(0,0,m),1.);
    cpSlab[3]=ControlPoint(vec3(R_anim*.5,0,0),1.); cpSlab[4]=ControlPoint(vec3(R_anim*.5,0,R_anim*.5),w_circ); cpSlab[5]=ControlPoint(vec3(0,0,R_anim*.5),1.);
    cpSlab[6]=ControlPoint(vec3(R_anim,0,0),1.); cpSlab[7]=ControlPoint(vec3(R_anim,0,R_anim),w_circ); cpSlab[8]=ControlPoint(vec3(0,0,R_anim),1.);

    vec2 uvSlab;
    float dSlabSurf = solveNURBS(pSlabFold, cpSlab, uvSlab);
    dSlabSurf = max(dSlabSurf - 0.05, abs(pSlab.y) - 0.4);
    
    float dSlabPoints;
    float dSlabNet = getControlVisuals(pSlabFold, cpSlab, dSlabPoints);

    // 2. PILLAR
    vec3 pPillFold = vec3(abs(p.x), p.y, abs(p.z));
    if (pPillFold.z > pPillFold.x) pPillFold.xz = pPillFold.zx;
    
    ControlPoint cpPill[9];
    float radius = 3.0; float halfH = 2.0;   
    for(int i = 0; i < 3; i++) {
        float y = (float(i) - 1.0) * halfH;
        cpPill[i*3+0] = ControlPoint(vec3(radius, y, 0.0), 1.0);
        cpPill[i*3+1] = ControlPoint(vec3(radius, y, radius), w_circ);
        cpPill[i*3+2] = ControlPoint(vec3(0.0,    y, radius), 1.0);
    }

    vec2 uvPill;
    float dPillSurf = solveNURBS(pPillFold, cpPill, uvPill) - 0.1;
    float dPillPoints;
    float dPillNet = getControlVisuals(pPillFold, cpPill, dPillPoints);

    // 3. COMPOSITION
    float k = 0.8;
    float h = clamp(0.5 + 0.5 * (dPillSurf - dSlabSurf) / k, 0.0, 1.0);
    float dScene = mix(dPillSurf, dSlabSurf, h) - k * h * (1.0 - h);
    
    Hit res = Hit(dScene, mix(uvPill, uvSlab, h), mix(2.0, 1.0, h));

    if (dSlabNet < res.dist) res = Hit(dSlabNet, vec2(0), 3.0);
    if (dPillNet < res.dist) res = Hit(dPillNet, vec2(0), 4.0);

    float allPoints = min(dSlabPoints, dPillPoints);
    if (allPoints < res.dist) res = Hit(allPoints, vec2(0), 5.0);

    return res;
}

// --- RENDER ---

vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.005, 0.0);
    return normalize(vec3(
        sceneSDF(p + e.xyy).dist - sceneSDF(p - e.xyy).dist,
        sceneSDF(p + e.yxy).dist - sceneSDF(p - e.yxy).dist,
        sceneSDF(p + e.yyx).dist - sceneSDF(p - e.yyx).dist
    ));
}

void main() {
    vec2 uv_s = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.y, u_resolution.x);
    
    float t = u_time * 0.15;
    vec3 ro = vec3(cos(t) * 14.0, 8.0, sin(t) * 14.0);
    vec3 tar = vec3(0, 1.0, 0);
    vec3 f = normalize(tar - ro), r = normalize(cross(vec3(0,1,0), f)), u = cross(f, r);
    vec3 rd = normalize(f * 2.0 + uv_s.x * r + uv_s.y * u);

    float d = 0.0;
    Hit hit;
    for(int i = 0; i < MAX_STEPS; i++) {
        hit = sceneSDF(ro + d * rd);
        if(abs(hit.dist) < SURF_DIST || d > MAX_DIST) break;
        d += hit.dist * 0.6; 
    }

    vec3 bg = vec3(0.01, 0.01, 0.02);
    vec3 col = bg;

    if(d < MAX_DIST) {
        if (hit.id >= 3.0) {
            if (hit.id == 3.0) col = vec3(1.0, 0.4, 0.1);      
            else if (hit.id == 4.0) col = vec3(0.0, 1.0, 0.8); 
            else if (hit.id == 5.0) col = vec3(1.0, 0.9, 0.2); 
        } else {
            vec3 p = ro + d * rd;
            vec3 n = getNormal(p);
            vec3 l = normalize(vec3(1, 2, 1));
            float diff = max(dot(n, l), 0.0);
            
            vec3 colSlab = mix(vec3(0.2, 0.2, 0.25), vec3(0.3, 0.3, 0.4), mod(floor(hit.uv.x*8.) + floor(hit.uv.y*8.), 2.0));
            vec3 colPillar = mix(vec3(0.1, 0.4, 0.8), vec3(1.0), (step(0.95, fract(hit.uv.x * 4.0)) + step(0.95, fract(hit.uv.y * 4.0))) * 0.4);
            
            float slabWeight = clamp(2.0 - hit.id, 0.0, 1.0);
            vec3 albedo = mix(colPillar, colSlab, slabWeight);
            
            col = albedo * (diff + 0.15);
            float spec = pow(max(dot(reflect(-l, n), -rd), 0.0), 32.0);
            col += spec * 0.4;
        }
        col = mix(col, bg, 1.0 - exp(-0.0005 * d * d));
    }

    FragColor = vec4(pow(col, vec3(0.4545)), 1.0);
}