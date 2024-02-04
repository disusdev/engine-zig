const std = @import("std");
const print = std.debug.print;
const os = std.os;
const assert = std.debug.assert;
const glfw: type = @import("mach-glfw");
const stb: type = @import("zstbi");
const math: type = @import("zmath");
const gl: type = @import("gl");
const Shader: type = @import("shaders.zig");

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
  const vertices = [_]f32 {
  //|vertex         |uv       |color
     0.5,  0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, // top right
     0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, // bottom right
    -0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, // bottom left
    -0.5,  0.5, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, // top left
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
  gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), null);
  gl.enableVertexAttribArray(0);

  // colors
  const col_offset: [*c]c_uint = (3 * @sizeOf(f32));
  gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), col_offset);
  gl.enableVertexAttribArray(1);

  // texture coords
  const tex_offset: [*c]c_uint = (6 * @sizeOf(f32));
  gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), tex_offset);
  gl.enableVertexAttribArray(2);

  // zstbi: loading an image.
  stb.init(allocator);
  defer stb.deinit();

  var image1 = try stb.Image.loadFromFile("data/textures/container.jpg", 0);
  defer image1.deinit();
  std.debug.print(
    "\nImage 1 info:\n\n  img width: {any}\n  img height: {any}\n  nchannels: {any}\n",
    .{ image1.width, image1.height, image1.num_components },
  );

  stb.setFlipVerticallyOnLoad(true);
  var image2 = try stb.Image.loadFromFile("data/textures/awesomeface.png", 0);
  defer image2.deinit();
  std.debug.print(
    "\nImage 2 info:\n\n  img width: {any}\n  img height: {any}\n  nchannels: {any}\n",
    .{ image2.width, image2.height, image2.num_components },
  );

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


  // note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
  gl.bindBuffer(gl.ARRAY_BUFFER, 0);

  // You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
  // VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
  gl.bindVertexArray(0);

  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);


  // Wireframe mode
  // gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

  shaderProgram.use();
  shaderProgram.setInt("texture1", 0);
  shaderProgram.setInt("texture2", 1);

  // Wait for the user to close the window.
  while (!window.shouldClose())
  {
    glfw.pollEvents();

    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture1);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, texture2);
    gl.bindVertexArray(VAO);

    // Construction of the tranformation matrix
    const rotZ = math.rotationZ(@floatCast(glfw.getTime()));
    const scale = math.scaling(0.5, 0.5, 0.5);
    const transformM = math.mul(rotZ, scale);
    var transform: [16]f32 = undefined;
    math.storeMat(&transform, transformM);

    // Sending our transformation matrix to our vertex shader
    const transformLoc = gl.getUniformLocation(shaderProgram.ID, "transform");
    gl.uniformMatrix4fv(transformLoc, 1, gl.FALSE, &transform);


    gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

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