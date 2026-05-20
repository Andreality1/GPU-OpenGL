#version 330 core

out vec4 FragColor;

uniform float u_time;

// We can derive the coordinates from the screen position 
// effectively creating a coordinate system from -1.0 to 1.0
void main()
{
    // Normalize coordinates (gl_FragCoord is in pixels, but since we use 
    // a full screen quad, we can also use a custom varyings approach.
    // Here we use a simpler method based on the screen center.)
    vec2 uv = (gl_FragCoord.xy * 2.0 - vec2(800.0, 600.0)) / 600.0;
    vec2 uv0 = uv;
    vec3 finalColor = vec3(0.0);
    
    // Iteration loop to create layered fractal-like depth
    for (float i = 0.0; i < 4.0; i++) {
        // Repeatedly offset and scale the UV coordinates
        uv = fract(uv * 1.5) - 0.5;

        // Calculate distance from center for a circular shape
        float d = length(uv) * exp(-length(uv0));

        // Use time to shift colors through a cosine palette
        vec3 col = 0.5 + 0.5 * cos(u_time + uv0.xyx + vec3(0, 2, 4));

        // Apply a "neon glow" math function
        d = sin(d * 8.0 + u_time) / 8.0;
        d = abs(d);
        d = pow(0.01 / d, 1.2);

        finalColor += col * d;
    }

    FragColor = vec4(finalColor, 1.0);
}