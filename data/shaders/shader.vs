#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aCoord;
layout (location = 2) in vec3 aNormal;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 FragPos;
out vec2 UV;
out vec3 Normal;

void main()
{
    mat4 mvp = projection * view * model;

    FragPos = vec3(mvp * vec4(aPos, 1.0));
    Normal = (mat3(transpose(inverse(model))) * aNormal);

    UV = aCoord;

    gl_Position = mvp * vec4(aPos, 1.0);
}