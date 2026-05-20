#version 330 core

layout (location = 0) in vec3 aPos;

void main() {
    // Directly output the position to cover the screen (-1 to 1)
    gl_Position = vec4(aPos, 1.0);
}