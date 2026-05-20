#version 330 core

// Output color
out vec4 FragColor;

// Uniforms from C++
uniform float u_time;

// Hardcoded resolution based on your C++ code (800x600)
vec2 u_resolution = vec2(800.0, 600.0);

// --- Smooth Palette Algorithm ---
vec3 getPalette(float t) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.0, 0.33, 0.67); 
    return a + b * cos(6.28318 * (c * t + d));
}

// Bezier SDF (Signed Distance Field)
vec2 sdBezier(vec3 p, vec3 A, vec3 B, vec3 C) {    
    vec3 a = B - A;
    vec3 b = A - 2.0*B + C;
    vec3 c = a * 2.0;
    vec3 d = A - p;
    float kk = 1.0 / dot(b,b);
    float kx = kk * dot(a,b);
    float ky = kk * (2.0*dot(a,a)+dot(d,b)) / 3.0;
    float kz = kk * dot(d,a);      
    float resT = 0.0;
    float p1 = ky - kx*kx;
    float q = kx*(2.0*kx*kx - 3.0*ky) + kz;
    float h = q*q + 4.0*p1*p1*p1;
    if(h >= 0.0) { 
        h = sqrt(h);
        vec2 x = (vec2(h, -h) - q) / 2.0;
        vec2 uv = sign(x)*pow(abs(x), vec2(1.0/3.0));
        resT = clamp(uv.x + uv.y - kx, 0.0, 1.0);
    } else {
        float z = sqrt(-p1);
        float v = acos(q/(p1*z*2.0)) / 3.0;
        float m = cos(v);
        float n = sin(v)*1.7320508;
        vec3 t = clamp(vec3(m+m, -n-m, n-m) - kx, 0.0, 1.0);
        float d1 = length(d+(c+b*t.x)*t.x);
        float d2 = length(d+(c+b*t.y)*t.y);
        resT = (d1 < d2) ? t.x : t.y;
    }
    return vec2(length(d + (c + b*resT)*resT), resT);
}

// Rotation helper
mat3 rotateY(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        c, 0, s,
        0, 1, 0,
       -s, 0, c
    );
}

void main() {
    // Normalizing coordinates
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.y, u_resolution.x);

    // 2. Camera Setup
    vec3 ro = vec3(0.0, 0.0, -3.0);          // Ray Origin
    vec3 rd = normalize(vec3(uv, 1.0));     // Ray Direction

    // 3. Rotating the Curve
    float angle = u_time * 0.5;
    mat3 rot = rotateY(angle);

    vec3 p0_base = vec3(-1.5, -0.5 + sin(u_time), 0.5);
    vec3 p1_base = vec3(0.0, 1.5, 0.0);
    vec3 p2_base = vec3(1.5, -0.5, -0.5);
    
    vec3 offset = vec3(0.0, 0.0, 3.5); 

    vec3 p0 = (rot * p0_base) + offset;
    vec3 p1 = (rot * p1_base) + offset;
    vec3 p2 = (rot * p2_base) + offset;

    // 4. Raymarching loop
    float t_hit = 0.0;
    float curve_t = 0.0;
    bool hit = false;
    for(int i = 0; i < 80; i++) {
        vec3 p = ro + rd * t_hit;
        vec2 res = sdBezier(p, p0, p1, p2);
        float d = res.x - 0.15; // 0.15 is the thickness of the tube
        if(d < 0.001) {
            hit = true;
            curve_t = res.y;
            break;
        }
        t_hit += d;
        if(t_hit > 15.0) break;
    }

    // 5. Shading
    vec3 bgColor = vec3(0.01, 0.01, 0.02);
    vec3 col = bgColor;

    if(hit) {
        vec3 hueCol = getPalette(curve_t + u_time * 0.2);
        float fade = exp(-0.12 * t_hit);
        
        // Simple rim lighting
        float rim = pow(1.0 - max(0.0, dot(-rd, vec3(0,0,1))), 2.0);
        col = hueCol * fade + (rim * 0.3 * hueCol);
    }

    // Fog and Gamma Correction
    col = mix(col, bgColor, 1.0 - exp(-0.01 * t_hit * t_hit));
    FragColor = vec4(pow(col, vec3(0.4545)), 1.0);
}