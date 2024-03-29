#version 330 core

out vec4 FragColor;

in vec3 FragPos;
in vec2 UV;
in vec3 Normal;

uniform sampler2D texture1;
uniform sampler2D texture2;

uniform vec3 lightPos;
uniform vec3 objectColor;
uniform vec3 lightColor;
uniform vec3 viewPos;

void main()
{
   float ambientStrength = 0.1;
   vec3 ambient = ambientStrength * lightColor;

   float specularStrength = 0.75;
   
   vec3 norm = normalize(Normal);
   vec3 lightDir = normalize(lightPos - FragPos);
   float diff = max(dot(norm, lightDir), 0.0);
   vec3 diffuse = diff * lightColor;

   float dst = min(length(lightPos - FragPos), 5);
   float ndst = (dst / 5);

   vec3 viewDir = normalize(viewPos - FragPos);
   vec3 reflectDir = reflect(-lightDir, norm);
   float spec = pow(max(dot(viewDir, reflectDir), 0.0), 256);
   vec3 specular = specularStrength * spec * lightColor;   

   vec3 result = (ambient + diffuse) * objectColor;

   //FragColor = mix(texture(texture1, UV),texture(texture2, UV), 0.5f) * vec4(result, 1.0f);
   FragColor = texture(texture1, UV) * vec4(result, 1.0f);
   //FragColor = vec4(result, 1.0f);

   // vec3 light = normalize(lightPos - FragPos);
   // light = max(dot(Normal, light), 0.0) * objectColor;
   // FragColor = texture(texture1, UV) * vec4(light, 1.0);
};