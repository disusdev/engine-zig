const std = @import("std");
const print = std.debug.print;
const os = std.os;
const assert = std.debug.assert;
const glfw: type = @import("mach-glfw");
const gl: type = @import("gl");
const Shader: type = @import("shaders");

const vsSrc =
  \\ #version 410 core
  \\ layout (location = 0) in vec3 aPos;
  \\ void main()
  \\ {
  \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
  \\ }
;

const fsSrc =
  \\ #version 410 core
  \\ out vec4 FragColor;
  \\ void main() {
  \\  FragColor = vec4(1.0, 0.5, 0.2, 1.0);   
  \\ }
;


fn compile_shaders() c_uint {
  // Create vertex shader
  var vertexShader: c_uint = undefined;
  vertexShader = gl.createShader(gl.VERTEX_SHADER);
  defer gl.deleteShader(vertexShader);

  gl.shaderSource(vertexShader, 1, @ptrCast(&vsSrc), 0);
  gl.compileShader(vertexShader);

  // Check if vertex shader was compiled successfully
  var success: c_int = undefined;
  var infoLog: [512]u8 = [_]u8{0} ** 512;

  gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &success);

  if (success == 0)
  {
    gl.getShaderInfoLog(vertexShader, 512, 0, &infoLog);
    std.log.err("{s}", .{infoLog});
  }

  // Fragment shader
  var fragmentShader: c_uint = undefined;
  fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
  defer gl.deleteShader(fragmentShader);

  gl.shaderSource(fragmentShader, 1, @ptrCast(&fsSrc), 0);
  gl.compileShader(fragmentShader);

  gl.getShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);

  if (success == 0)
  {
    gl.getShaderInfoLog(fragmentShader, 512, 0, &infoLog);
    std.log.err("{s}", .{infoLog});
  }

  // create a program object
  var shaderProgram: c_uint = undefined;
  shaderProgram = gl.createProgram();
  

  // attach compiled shader objects to the program object and link
  gl.attachShader(shaderProgram, vertexShader);
  gl.attachShader(shaderProgram, fragmentShader);
  gl.linkProgram(shaderProgram);

  // check if shader linking was successfull
  gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
  if (success == 0)
  {
    gl.getProgramInfoLog(shaderProgram, 512, 0, &infoLog);
    std.log.err("{s}", .{infoLog});
  }

  return shaderProgram;
}


const WindowSize = struct
{
  pub const width: u32 = 800;
  pub const height: u32 = 600;
};

fn Gen(comptime T: type) type {
  return struct {
    some: [3]T = undefined,

    fn create(self: *@This(), a: T, b: T, c: T) void {
      self.*.some[0] = a;
      self.*.some[1] = b;
      self.*.some[2] = c;
    }
  };
}

fn test_fields() void {
  const U1s = packed struct {
    a: u1,
    b: u1,
    c: u1,
  };

  const x = U1s{ .a = 1, .b = 0, .c = 0 };
  inline for (std.meta.fields(@TypeOf(x))) |f| {
    std.log.debug(f.name ++ " {any}", .{@as(f.type, @field(x, f.name))});
  }
}

pub fn main() !void
{
  const arrInt = [_]i32 { 1, 2, 3 };
  _ = arrInt; // autofix

  const arrInt2 = [_]i32 { 0 } ** 16;
  _ = arrInt2; // autofix

  var arrInt3 = std.mem.zeroes([16]i32);
  for (&arrInt3, 0..) |*value, i| {
    value.* = @intCast(i);
  }

  const slice: []i32 = arrInt3[4..8];
  std.log.info("{any}", .{slice});

  test_fields();

  var arr = Gen(i32){};
  arr.create(1, 2, 3);
  print("{any}", .{arr.some});

  var arrStr = Gen([]const u8){};
  arrStr.create("hello", "dummy", "gog");
  print("{s}", .{arrStr.some});

  glfw.setErrorCallback(errorCallback);
  if (!glfw.init(.{}))
  {
    std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
    std.process.exit(1);
  }
  defer glfw.terminate();

  // Create our window
  const window = glfw.Window.create(1280, 800, "ogl", null, null, .{
    .opengl_profile = .opengl_core_profile,
    .context_version_major = 4,
    .context_version_minor = 0,
  }) orelse {
    std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
    std.process.exit(1);
  };
  defer window.destroy();

  window.setKeyCallback(keyCallback);
  window.setFramebufferSizeCallback(framebuffer_size_callback);

  glfw.makeContextCurrent(window);

  const proc: glfw.GLProc = undefined;
  try gl.load(proc, glGetProcAddress);

  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  const allocator = gpa.allocator();
  var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
  defer arena_allocator_state.deinit();
  const arena_allocator = arena_allocator_state.allocator();

  // create shader program
  const shaderProgram: Shader = Shader.create(arena_allocator, "shaders/shader_ex3.vs", "shaders/shader_ex3.fs");

  // const shaderProgram = compile_shaders();
  defer gl.deleteProgram(shaderProgram);

  std.log.info("size: {}", .{@sizeOf(u32)});

  // set up vertex data (and buffer(s)) and configure vertex attributes
  // ------------------------------------------------------------------
  const vertices = [12]f32 {
    0.5, 0.5, 0.0, // top right
    0.5, -0.5, 0.0, // bottom right
    -0.5, -0.5, 0.0, // bottom left
    -0.5, 0.5, 0.0, // top left
  };


  const indices = [6]u32 {
    // note that we start from 0!
    0, 1, 3, // first triangle
    1, 2, 3, // second triangle
  };


  var VBO: c_uint = undefined;
  var VAO: c_uint = undefined;
  var EBO: c_uint = undefined;

  gl.genVertexArrays(1, &VAO);
  defer gl.deleteVertexArrays(1, &VAO);

  gl.genBuffers(1, &VBO);
  defer gl.deleteBuffers(1, &VBO);

  gl.genBuffers(1, &EBO);
  defer gl.deleteBuffers(1, &EBO);

  // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
  gl.bindVertexArray(VAO);
  gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
  // Fill our buffer with the vertex data
  gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * indices.len, &indices, gl.STATIC_DRAW);

  // Specify and link our vertext attribute description
  gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
  gl.enableVertexAttribArray(0);


  // note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
  gl.bindBuffer(gl.ARRAY_BUFFER, 0);

  // You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
  // VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
  gl.bindVertexArray(0);

  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);


  // Wireframe mode
  gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);


  // Wait for the user to close the window.
  while (!window.shouldClose())
  {
    glfw.pollEvents();

    gl.clearColor(0.2, 0.3, 0.3, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.useProgram(shaderProgram);
    gl.bindVertexArray(VAO); // seeing as we only have a single VAO there's no need to bind it every time, but we'll do so to keethings a bit more organized
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
    gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
    gl.bindVertexArray(0);

    window.swapBuffers();
  }
}

fn framebuffer_size_callback(window: glfw.Window, width: u32, height: u32) void
{
  _ = window;
  gl.viewport(0, 0, @intCast(width), @intCast(height));
}

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer
{
  _ = p;
  return glfw.getProcAddress(proc);
}

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void
{
  std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

fn keyCallback(window:glfw.Window, key:glfw.Key, scancode:i32, action:glfw.Action, mods:glfw.Mods) void
{
  _ = scancode; // autofix
  _ = mods; // autofix
  if (key == glfw.Key.q and action == glfw.Action.press)
  {
    window.setShouldClose(true);
  }
}

test "simple test"
{
  try std.testing.expect(true);
}