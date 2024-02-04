const std = @import("std");
const print = std.debug.print;
const os = std.os;
const assert = std.debug.assert;
const glfw: type = @import("mach-glfw");
const stb: type = @import("zstbi");
const math: type = @import("zmath");
const gl: type = @import("gl");
const Shader: type = @import("shaders.zig");
const Camera: type = @import("camera.zig");

// Camera
const camera_pos = math.loadArr3(.{ 0.0, 0.0, 5.0 });
var lastX: f64 = 0.0;
var lastY: f64 = 0.0;
var first_mouse = true;
var camera = Camera.camera(camera_pos);

// Timing
var delta_time: f32 = 0.0;
var last_frame: f32 = 0.0;

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
  const shaderProgram: Shader = Shader.create(arena_allocator, "data/shaders/shader.vs", "data/shaders/shader.fs");

  // const shaderProgram = compile_shaders();
  defer gl.deleteProgram(shaderProgram.ID);

  // set up vertex data (and buffer(s)) and configure vertex attributes
  // ------------------------------------------------------------------
  const vertices_2D = [_]f32{
    // positions      // colors        // texture coords
    0.5, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, // top right
    0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, // bottom right
    -0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, // bottom left
    -0.5, 0.5, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, // top left
  };

  _ = vertices_2D;

  const vertices_3D = [_]f32{
    -0.5, -0.5, -0.5, 0.0, 0.0,
    0.5,  -0.5, -0.5, 1.0, 0.0,
    0.5,  0.5,  -0.5, 1.0, 1.0,
    0.5,  0.5,  -0.5, 1.0, 1.0,
    -0.5, 0.5,  -0.5, 0.0, 1.0,
    -0.5, -0.5, -0.5, 0.0, 0.0,

    -0.5, -0.5, 0.5,  0.0, 0.0,
    0.5,  -0.5, 0.5,  1.0, 0.0,
    0.5,  0.5,  0.5,  1.0, 1.0,
    0.5,  0.5,  0.5,  1.0, 1.0,
    -0.5, 0.5,  0.5,  0.0, 1.0,
    -0.5, -0.5, 0.5,  0.0, 0.0,

    -0.5, 0.5,  0.5,  1.0, 0.0,
    -0.5, 0.5,  -0.5, 1.0, 1.0,
    -0.5, -0.5, -0.5, 0.0, 1.0,
    -0.5, -0.5, -0.5, 0.0, 1.0,
    -0.5, -0.5, 0.5,  0.0, 0.0,
    -0.5, 0.5,  0.5,  1.0, 0.0,

    0.5,  0.5,  0.5,  1.0, 0.0,
    0.5,  0.5,  -0.5, 1.0, 1.0,
    0.5,  -0.5, -0.5, 0.0, 1.0,
    0.5,  -0.5, -0.5, 0.0, 1.0,
    0.5,  -0.5, 0.5,  0.0, 0.0,
    0.5,  0.5,  0.5,  1.0, 0.0,

    -0.5, -0.5, -0.5, 0.0, 1.0,
    0.5,  -0.5, -0.5, 1.0, 1.0,
    0.5,  -0.5, 0.5,  1.0, 0.0,
    0.5,  -0.5, 0.5,  1.0, 0.0,
    -0.5, -0.5, 0.5,  0.0, 0.0,
    -0.5, -0.5, -0.5, 0.0, 1.0,

    -0.5, 0.5,  -0.5, 0.0, 1.0,
    0.5,  0.5,  -0.5, 1.0, 1.0,
    0.5,  0.5,  0.5,  1.0, 0.0,
    0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5, 0.5,  0.5,  0.0, 0.0,
    -0.5, 0.5,  -0.5, 0.0, 1.0,
  };

  const cube_positions = [_][3]f32{
    .{ 0.0, 0.0, 0.0 },
    .{ 2.0, 5.0, -15.0 },
    .{ -1.5, -2.2, -2.5 },
    .{ -3.8, -2.0, -12.3 },
    .{ 2.4, -0.4, -3.5 },
    .{ -1.7, 3.0, -7.5 },
    .{ 1.3, -2.0, -2.5 },
    .{ 1.5, 2.0, -2.5 },
    .{ 1.5, 0.2, -1.5 },
    .{ -1.3, 1.0, -1.5 },
  };


  var VBO: c_uint = undefined;
  var VAO: c_uint = undefined;
  // var EBO: c_uint = undefined;

  gl.genVertexArrays(1, &VAO);
  defer gl.deleteVertexArrays(1, &VAO);

  gl.genBuffers(1, &VBO);
  defer gl.deleteBuffers(1, &VBO);

  // gl.genBuffers(1, &EBO);
  // defer gl.deleteBuffers(1, &EBO);

  // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
  gl.bindVertexArray(VAO);
  gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
  // Fill our buffer with the vertex data
  gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices_3D.len, &vertices_3D, gl.STATIC_DRAW);

  // vertex
  gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), null);
  gl.enableVertexAttribArray(0);

  // texture coords
  const tex_offset: [*c]c_uint = (3 * @sizeOf(f32));
  gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), tex_offset);
  gl.enableVertexAttribArray(1);

  // zstbi: loading an image.
  stb.init(allocator);
  defer stb.deinit();

  var image1 = try stb.Image.loadFromFile("data/textures/container.jpg", 0);
  defer image1.deinit();
  std.debug.print("\nImage 1 info:\n\n  img width: {any}\n  img height: {any}\n  nchannels: {any}\n", .{ image1.width, image1.height, image1.num_components });

  stb.setFlipVerticallyOnLoad(true);
  var image2 = try stb.Image.loadFromFile("data/textures/awesomeface.png", 0);
  defer image2.deinit();
  std.debug.print("\nImage 2 info:\n\n  img width: {any}\n  img height: {any}\n  nchannels: {any}\n", .{ image2.width, image2.height, image2.num_components });

  // Create and bind texture1 resource
  var texture1: c_uint = undefined;

  gl.genTextures(1, &texture1);
  gl.activeTexture(gl.TEXTURE0); // activate the texture unit first before binding texture
  gl.bindTexture(gl.TEXTURE_2D, texture1);

  // set the texture1 wrapping parameters
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT); // set texture wrapping to GL_REPEAT (default wrapping method)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  // set texture1 filtering parameters
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    // Generate the texture1
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image1.width), @intCast(image1.height), 0, gl.RGB, gl.UNSIGNED_BYTE, @ptrCast(image1.data));
  gl.generateMipmap(gl.TEXTURE_2D);

  // Texture2
  var texture2: c_uint = undefined;

  gl.genTextures(1, &texture2);
  gl.activeTexture(gl.TEXTURE1); // activate the texture unit first before binding texture
  gl.bindTexture(gl.TEXTURE_2D, texture2);

  // set the texture1 wrapping parameters
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT); // set texture wrapping to GL_REPEAT (default wrapping method)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  // set texture1 filtering parameters
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

  // Generate the texture1
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image2.width), @intCast(image2.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, @ptrCast(image2.data));
  gl.generateMipmap(gl.TEXTURE_2D);

  // Enable OpenGL depth testing (use Z-buffer information)
  gl.enable(gl.DEPTH_TEST);

  shaderProgram.use();
  shaderProgram.setInt("texture1", 0);
  shaderProgram.setInt("texture2", 1);

  // Create the transformation matrices:
  // Degree to radians conversion factor
  const rad_conversion = std.math.pi / 180.0;

  // Buffer to store Model matrix
  var model: [16]f32 = undefined;

  // View matrix
  var view: [16]f32 = undefined;

  // Buffer to store Orojection matrix (in render loop)
  var proj: [16]f32 = undefined;

  // Wait for the user to close the window.
  while (!window.shouldClose())
  {
    glfw.pollEvents();

    // Time per frame
    const current_frame = @as(f32, @floatCast(glfw.getTime()));
    delta_time = current_frame - last_frame;
    last_frame = current_frame;

    processInput(window);

    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture1);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, texture2);
    gl.bindVertexArray(VAO);

        // Projection matrix
    const projM = x: {
      const window_size = window.getSize();
      const aspect: f32 = @as(f32, @floatFromInt(window_size.width)) / @as(f32, @floatFromInt(window_size.height));
      const projM = math.perspectiveFovRhGl(camera.zoom * Camera.RAD2DEG, aspect, 0.1, 100.0);
      break :x projM;
    };
    math.storeMat(&proj, projM);
    shaderProgram.setMat4f("projection", proj);

    // View matrix: Camera
    const viewM = camera.getViewMatrix();
    math.storeMat(&view, viewM);
    shaderProgram.setMat4f("view", view);

    for (cube_positions, 0..) |cube_position, i| {
      // Model matrix
      const cube_trans = math.translation(cube_position[0], cube_position[1], cube_position[2]);
      const rotation_direction = (((@mod(@as(f32, @floatFromInt(i + 1)), 2.0)) * 2.0) - 1.0);
      const cube_rot = math.matFromAxisAngle(
        math.f32x4(1.0, 0.3, 0.5, 1.0),
        @as(f32, @floatCast(glfw.getTime())) * 55.0 * rotation_direction * rad_conversion,
      );
      const modelM = math.mul(cube_rot, cube_trans);
      math.storeMat(&model, modelM);
      shaderProgram.setMat4f("model", model);

      gl.drawArrays(gl.TRIANGLES, 0, 36);
    }

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

fn processInput(window: glfw.Window) void {
  if (glfw.Window.getKey(window, glfw.Key.escape) == glfw.Action.press) {
    _ = glfw.Window.setShouldClose(window, true);
  }

  if (glfw.Window.getKey(window, glfw.Key.w) == glfw.Action.press) {
    camera.processKeyboard(Camera.CameraMovement.FORWARD, delta_time);
  }
  if (glfw.Window.getKey(window, glfw.Key.s) == glfw.Action.press) {
    camera.processKeyboard(Camera.CameraMovement.BACKWARD, delta_time);
  }
  if (glfw.Window.getKey(window, glfw.Key.a) == glfw.Action.press) {
    camera.processKeyboard(Camera.CameraMovement.LEFT, delta_time);
  }
  if (glfw.Window.getKey(window, glfw.Key.d) == glfw.Action.press) {
    camera.processKeyboard(Camera.CameraMovement.RIGHT, delta_time);
  }
}

test "simple test"
{
  try std.testing.expect(true);
}