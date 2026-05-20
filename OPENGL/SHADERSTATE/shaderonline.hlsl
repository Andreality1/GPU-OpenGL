#version 330 core

out vec4 FragColor;

uniform float u_time;
uniform vec2 u_resolution; // Optional: add this to your C++ if you want correct aspect ratio

// Rotation matrix utility
mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// Signed Distance Function for a Torus
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// The "Scene" - defines the shapes in 3D space
float map(vec3 p) {
    // Twist the space over time
    p.xy *= rot(p.z * 0.3 + u_time * 0.5);
    p.zx *= rot(u_time * 0.2);
    
    // Create a repeating pattern of tori
    vec3 q = mod(p, 4.0) - 2.0; 
    
    float torus = sdTorus(q, vec2(1.5, 0.4));
    
    // Add some "noise" or displacement
    float displacement = sin(5.0 * q.x) * sin(5.0 * q.y) * sin(5.0 * q.z) * 0.1;
    
    return torus + displacement;
}

void main() {
    // 1. Normalize coordinates (range -1 to 1)
    // Note: If you haven't passed u_resolution yet, use gl_FragCoord.xy/800.0 (assuming 800px width)
    vec2 uv = (gl_FragCoord.xy * 2.0 - vec2(800.0, 600.0)) / 600.0;

    // 2. Camera Setup
    vec3 ro = vec3(0, 0, -5);          // Ray Origin (Camera position)
    vec3 rd = normalize(vec3(uv, 1));   // Ray Direction
    
    // 3. Raymarching Loop
    float t = 0.0; // Total distance traveled
    int i;
    for (i = 0; i < 80; i++) {
        vec3 p = ro + rd * t;          // Current point along the ray
        float d = map(p);              // Distance to the nearest object
        t += d;                        // "March" forward by that distance
        if (d < 0.001 || t > 20.0) break; // Stop if we hit something or go too far
    }

    // 4. Coloring based on depth and "glow"
    vec3 col = vec3(0.0);
    
    if (t < 20.0) {
        // Simple Diffuse Lighting based on iterations
        float edge = float(i) / 80.0;
        
        // Color palette based on time and distance
        vec3 baseColor = 0.5 + 0.5 * cos(u_time + vec3(0, 2, 4));
        col = baseColor * (1.0 - edge); 
        
        // Add a "fog" effect
        col *= exp(-0.1 * t);
    } else {
        // Background color (dark blue/black)
        col = vec3(0.02, 0.02, 0.05);
    }

    FragColor = vec4(col, 1.0);
}