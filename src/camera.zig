const std = @import("std");
const gl = @import("gl");
const math = @import("zmath");
const Camera = @This();

pub const DEG2RAD = (std.math.pi/180.0);
pub const RAD2DEG = (180.0/std.math.pi);

pub const CameraMovement = enum {
  FORWARD,
  BACKWARD,
  LEFT,
  RIGHT,
};

const WORLD_UP = math.loadArr3(.{0.0, 1.0, 0.0});
const MOVEMENT_SPEED: f32 = 2.5;
const MOUSE_SENSITIVITY: f32 = 0.1;

// Camera attributes
position: math.F32x4 = math.loadArr3(.{0.0, 0.0, 0.0}),
front: math.F32x4 = math.loadArr3(.{0.0, 0.0, -1.0}),
up: math.F32x4 = undefined,
right: math.F32x4 = undefined,

// euler Angles
yaw: f32 = -90,
pitch: f32 = 0.0,
    
// camera options
zoom: f32 = 45.0,


pub fn camera(position: ?math.F32x4) Camera {
  const _position = p: {
    if(position) |value| {
      break :p value; 
    }  
    else {
      break :p math.loadArr3(.{0.0, 0.0, 0.0});
    }
  };

  const _front = math.loadArr3(.{0.0, 0.0, -1.0});
  const _world_up = math.loadArr3(.{0.0, 1.0, 0.0});
  const _right = math.normalize3(math.cross3(_front, _world_up));
  const _up = math.normalize3(math.cross3(_right, _front));

  return Camera{
    .position = _position,
    .right = _right,  // normalize the vectors, because their length gets closer to 0 the more you look up or down which results in slower movement.
    .up    = _up,
  };
}

// returns the view matrix calculated using Euler Angles and the LookAt Matrix
pub fn getViewMatrix(self: *Camera) math.Mat {
  return math.lookAtRh(self.position, self.position + self.front, self.up);
}

// processes input received from any keyboard-like input system. Accepts input parameter in the form of camera defined ENUM (to abstract it from windowing systems)
pub fn processKeyboard(self: *Camera, direction: Camera.CameraMovement, delta_time: f32) void {
  const velocity = math.f32x4s(MOVEMENT_SPEED * delta_time);
  switch (direction) {   
    .FORWARD => self.position += self.front * velocity,
    .BACKWARD => self.position -= self.front * velocity,
    .LEFT => self.position -= self.right * velocity,
    .RIGHT => self.position += self.right * velocity,
  }
}

// processes input received from a mouse input system. Expects the offset value in both the x and y direction.
pub fn processMouseMovement(self: *Camera, xoffset: f64, yoffset: f64, constrain_pitch: bool) void {
  const _xoffset = @as(f32, @floatCast(xoffset)) * MOUSE_SENSITIVITY;
  const _yoffset = @as(f32, @floatCast(yoffset)) * MOUSE_SENSITIVITY;

  self.yaw += _xoffset;
  self.pitch += _yoffset;

  // make sure that when pitch is out of bounds, screen doesn't get flipped
  if (constrain_pitch) {
    if (self.pitch > 89.0)
      self.pitch = 89.0;
    if (self.pitch < -89.0)
      self.pitch = -89.0;
  }

  // update Front, Right and Up Vectors using the updated Euler angles
  self.updateCameraVectors();
}

// processes input received from a mouse scroll-wheel event. Only requires input on the vertical wheel-axis
pub fn processMouseScroll(self: *Camera, yoffset: f64) void {
  self.zoom -= @as(f32, @floatCast(yoffset));
  if (self.zoom < 1.0)
    self.zoom = 1.0;
  if (self.zoom > 45.0)
    self.zoom = 45.0;
}

// calculates the front vector from the Camera's (updated) Euler Angles
fn updateCameraVectors(self: *Camera) void {
    // calculate the new Front vector
    var front: math.F32x4 = undefined;
    front[0] = @cos(self.yaw * DEG2RAD) * @cos(self.pitch * DEG2RAD);
    front[1] = @sin(self.pitch * DEG2RAD);
    front[2] = @sin(self.yaw * DEG2RAD) * @cos(self.pitch * DEG2RAD);
    self.front = front;
    // also re-calculate the Right and Up vector
    self.right = math.normalize3(math.cross3(self.front, WORLD_UP));  // normalize the vectors, because their length gets closer to 0 the more you look up or down which results in slower movement.
    self.up    = math.normalize3(math.cross3(self.right, self.front));
}