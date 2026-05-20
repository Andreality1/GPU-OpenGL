#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

// For GPU Memory Enumeration on Windows
#include <dxgi.h>
#pragma comment(lib, "dxgi.lib")

/* 
 * 1. DRIVER FLAGS (The "Request")
 */
extern "C" {
    // Force NVIDIA Dedicated GPU
    __declspec(dllexport) unsigned long NvOptimusEnablement = 0x00000001;
    // Force AMD Dedicated GPU (included for compatibility)
    __declspec(dllexport) int AmdPowerXpressRequestHighPerformance = 1;
}

// 2. HELPER: Find GPU with highest Dedicated Video Memory
void PrintGPUMemoryInfo() {
    IDXGIFactory* pFactory;
    if (FAILED(CreateDXGIFactory(__uuidof(IDXGIFactory), (void**)&pFactory))) return;
    
    IDXGIAdapter* pAdapter;
    std::cout << "--- System GPU Enumeration ---" << std::endl;
    for (UINT i = 0; pFactory->EnumAdapters(i, &pAdapter) != DXGI_ERROR_NOT_FOUND; ++i) {
        DXGI_ADAPTER_DESC desc;
        pAdapter->GetDesc(&desc);
        std::wcout << L"GPU " << i << L": " << desc.Description << std::endl;
        std::cout << "   VRAM: " << desc.DedicatedVideoMemory / (1024 * 1024) << " MB" << std::endl;
        pAdapter->Release();
    }
    pFactory->Release();
    std::cout << "------------------------------" << std::endl;
}

std::string readFile(const char* filePath) {
    std::ifstream file(filePath);
    if (!file.is_open()) return "";
    std::stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

int main() {
    // Check hardware before starting OpenGL
    PrintGPUMemoryInfo();

    if (!glfwInit()) return -1;

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    // Create the window
    GLFWwindow* window = glfwCreateWindow(800, 600, "NURBS Raymarcher", NULL, NULL);
    if (!window) {
        glfwTerminate();
        return -1;
    }

    glfwMakeContextCurrent(window);
    gladLoadGLLoader((GLADloadproc)glfwGetProcAddress);

    // 3. LOG THE ACTIVE GPU
    const GLubyte* renderer = glGetString(GL_RENDERER);
    std::cout << "OPENGL IS CURRENTLY USING: " << renderer << std::endl;

    // --- SHADER SETUP ---
    std::string vCode = readFile("shaders/vertex_shader.glsl");
    std::string fCode = readFile("shaders/fragment_shader.glsl");
    const char* vPtr = vCode.c_str();
    const char* fPtr = fCode.c_str();

    unsigned int vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &vPtr, NULL);
    glCompileShader(vs);

    unsigned int fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &fPtr, NULL);
    glCompileShader(fs);

    unsigned int shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vs);
    glAttachShader(shaderProgram, fs);
    glLinkProgram(shaderProgram);
    glDeleteShader(vs);
    glDeleteShader(fs);

    // Full Screen Quad
    float vertices[] = { -1,1,0, -1,-1,0, 1,-1,0, -1,1,0, 1,-1,0, 1,1,0 };
    unsigned int VBO, VAO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    int timeLoc = glGetUniformLocation(shaderProgram, "u_time");
    int resLoc = glGetUniformLocation(shaderProgram, "u_resolution");

    // --- FPS COUNTER VARIABLES ---
    double lastTime = glfwGetTime();
    int nbFrames = 0;

    // --- RENDER LOOP ---
    while (!glfwWindowShouldClose(window)) {
        // Measure speed
        double currentTime = glfwGetTime();
        nbFrames++;
        if (currentTime - lastTime >= 1.0) { 
            // Calculate FPS and display in Title Bar
            double msPerFrame = 1000.0 / double(nbFrames);
            std::string title = "NURBS Raymarcher | FPS: " + std::to_string(nbFrames) + 
                                " | " + std::to_string(msPerFrame).substr(0, 4) + "ms";
            glfwSetWindowTitle(window, title.c_str());
            
            nbFrames = 0;
            lastTime += 1.0;
        }

        int w, h;
        glfwGetFramebufferSize(window, &w, &h);
        glViewport(0, 0, w, h);
        
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(shaderProgram);
        glUniform1f(timeLoc, (float)glfwGetTime());
        glUniform2f(resLoc, (float)w, (float)h);

        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    // Cleanup
    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteProgram(shaderProgram);

    glfwTerminate();
    return 0;
}