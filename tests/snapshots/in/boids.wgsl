// Copyright 2020 The Tint Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// vertex shader

[[location(0)]] var<in> a_particlePos : vec2<f32>;
[[location(1)]] var<in> a_particleVel : vec2<f32>;
[[location(2)]] var<in> a_pos : vec2<f32>;
[[builtin(position)]] var gl_Position : vec4<f32>;

[[stage(vertex)]]
fn main() {
  const angle : f32 = -atan2(a_particleVel.x, a_particleVel.y);
  const pos : vec2<f32> = vec2<f32>(
      (a_pos.x * cos(angle)) - (a_pos.y * sin(angle)),
      (a_pos.x * sin(angle)) + (a_pos.y * cos(angle)));
  gl_Position = vec4<f32>(pos + a_particlePos, 0.0, 1.0);
}

// fragment shader
[[location(0)]] var<out> fragColor : vec4<f32>;

[[stage(fragment)]]
fn main() {
  fragColor = vec4<f32>(1.0, 1.0, 1.0, 1.0);
}

// compute shader
[[block]]
struct Particle {
  [[span(8)]] pos : vec2<f32>;
  [[span(8)]] vel : vec2<f32>;
};

[[block]]
struct SimParams {
  deltaT : f32;
  rule1Distance : f32;
  rule2Distance : f32;
  rule3Distance : f32;
  rule1Scale : f32;
  rule2Scale : f32;
  rule3Scale : f32;
};

[[block]]
struct Particles {
  particles : [[stride(16)]] array<Particle, 5>;
};

[[group(0), binding(0)]] var<uniform> params : SimParams;
[[group(0), binding(1)]] var<storage> particlesA : [[access(read_write)]] Particles;
[[group(0), binding(2)]] var<storage> particlesB : [[access(read_write)]] Particles;

[[builtin(global_invocation_id)]] var gl_GlobalInvocationID : vec3<u32>;

// https://github.com/austinEng/Project6-Vulkan-Flocking/blob/master/data/shaders/computeparticles/particle.comp
[[stage(compute), workgroup_size(1)]]
fn main() {
  const index : u32 = gl_GlobalInvocationID.x;
  if (index >= 5u) {
    return;
  }

  var vPos : vec2<f32> = particlesA.particles[index].pos;
  var vVel : vec2<f32> = particlesA.particles[index].vel;

  var cMass : vec2<f32> = vec2<f32>(0.0, 0.0);
  var cVel : vec2<f32> = vec2<f32>(0.0, 0.0);
  var colVel : vec2<f32> = vec2<f32>(0.0, 0.0);
  var cMassCount : i32 = 0;
  var cVelCount : i32 = 0;

  var pos : vec2<f32>;
  var vel : vec2<f32>;
  var i : u32 = 0u;
  loop {
    if (i >= 5u) {
      break;
    }
    if (i == index) {
      continue;
    }

    pos = particlesA.particles[i].pos.xy;
    vel = particlesA.particles[i].vel.xy;

    if (distance(pos, vPos) < params.rule1Distance) {
      cMass = cMass + pos;
      cMassCount = cMassCount + 1;
    }
    if (distance(pos, vPos) < params.rule2Distance) {
      colVel = colVel - (pos - vPos);
    }
    if (distance(pos, vPos) < params.rule3Distance) {
      cVel = cVel + vel;
      cVelCount = cVelCount + 1;
    }

    continuing {
      i = i + 1u;
    }
  }
  if (cMassCount > 0) {
    cMass = (cMass / vec2<f32>(vec2<i32>(cMassCount, cMassCount))) + vPos;
  }
  if (cVelCount > 0) {
    cVel = cVel / vec2<f32>(vec2<i32>(cVelCount, cVelCount));
  }

  vVel = vVel + (cMass * params.rule1Scale) + (colVel * params.rule2Scale) +
      (cVel * params.rule3Scale);

  // clamp velocity for a more pleasing simulation
  vVel = normalize(vVel) * clamp(length(vVel), 0.0, 0.1);

  // kinematic update
  vPos = vPos + (vVel * params.deltaT);

  // Wrap around boundary
  if (vPos.x < -1.0) {
    vPos.x = 1.0;
  }
  if (vPos.x > 1.0) {
    vPos.x = -1.0;
  }
  if (vPos.y < -1.0) {
    vPos.y = 1.0;
  }
  if (vPos.y > 1.0) {
    vPos.y = -1.0;
  }

  // Write back
  particlesB.particles[index].pos = vPos;
  particlesB.particles[index].vel = vVel;
}
