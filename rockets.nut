/*
-----------------------------------------------------------------------------
rockets.nut: TF2 Vscript to spawn rockets that collide with players
by axios

Repository: https://github.com/axiostf/rockets.nut
-----------------------------------------------------------------------------
*/

/*
-----------------------------------------------------------------------------
Constants & Defines
-----------------------------------------------------------------------------
*/
::ROCKETS <- {};
ROCKETS.Helpers <- {};

//Default values of spawned rockets, if not overwritten in spawn functions
ROCKETS.Globals <- {
  ROCKET_DAMAGE                   = 90.0,                           // Rocket damage
  ROCKET_SPEED                    = 1100.0,                         // Rocket speed
  ROCKET_COLLISION_AVOIDANCE      = true,                           // Do homing rockets try to avoid world geometry?
  ROCKET_TARGET_PREDICTION        = true,                           // Do homing rockets try to predict the target position at impact time?
  PARTICLE_SYSTEM_NAME            = "critical_rocket_blue",         // Particles added to the rocket trail attachment
  ROCKET_BOUNDS_P                 = Vector(18.3205, 3.417, 3.417),  // Rocket bounds
  ROCKET_FOLLOW_SPEED_MULTIPLIER  = 2,                              // Homing rockets that are slower than target speed accelerate to x times target speed
  ROCKET_EXPLODE                  = true,                           // Do rockets explode?
  ROCKET_SCALE                    = 1.0,                            // Rocket model & hitbox scale
  MAX_TURNRATE                    = 0.7,                            // Max turnrate. 1 = instant turning to target, 0 = cant turn.
  MIN_TURNRATE                    = 0.23,                           // Min turnrate
  MAX_TURNRATE_DISTANCE           = 50,                             // If distance to target is this or lower, turnrate = MAX_TURNRATE
  MIN_TURNRATE_DISTANCE           = 400,                            // If distance to target is this or greater, turnrate = MIN_TURNRATE
  ROCKET_ONLY_DAMAGE_TARGET       = true,                           // Rockets only damage its target
  ROCKET_HOMING                   = false,                          // Is the rocket homing?
  ROCKET_TARGET                   = null,                           // Rocket target
  ROCKET_LIMIT                    = -1,                             // Rocket spawn limit with SpawnRocketAtEntity. Limit is per player
};
ROCKETS.RocketArgs <- {
  position                = null,
  direction               = null,
  speed                   = ROCKETS.Globals.ROCKET_SPEED,
  damage                  = ROCKETS.Globals.ROCKET_DAMAGE,
  explode                 = ROCKETS.Globals.ROCKET_EXPLODE,
  target                  = ROCKETS.Globals.ROCKET_TARGET,
  scale                   = ROCKETS.Globals.ROCKET_SCALE,
  follow_speed_multiplier = ROCKETS.Globals.ROCKET_FOLLOW_SPEED_MULTIPLIER,
  collision_avoidance     = ROCKETS.Globals.ROCKET_COLLISION_AVOIDANCE,
  target_prediction       = ROCKETS.Globals.ROCKET_TARGET_PREDICTION,
  limit                   = ROCKETS.Globals.ROCKET_LIMIT,
  homing                  = ROCKETS.Globals.ROCKET_HOMING,
  damage_everyone         = !ROCKETS.Globals.ROCKET_ONLY_DAMAGE_TARGET,
};


/*
---------------------------------------------------------------
Main functions
---------------------------------------------------------------
*/

/*
  ReplaceRocket()

  Replace user fired rockets.
*/
function ReplaceRocket(args_table = {}) {
  local args = ROCKETS.Helpers.PopulateArgs(args_table);

  local player_rocket = activator;
  if (player_rocket == null) return;

  local player_rocket_velocity = player_rocket.GetAbsVelocity() + player_rocket.GetBaseVelocity();
  local player_rocket_angles = ROCKETS.Helpers.VectorAngles(player_rocket_velocity);
  local player_rocket_speed = player_rocket_velocity.Length();

  args.target = args.target == null ? player_rocket.GetOwner() : Entities.FindByName(null, args.target);
  if (args.target == null) return;

  args.position = player_rocket.GetOrigin();
  args.direction = player_rocket_angles;
  args.speed = args.speed ? args.speed : player_rocket_speed;

  ROCKETS.SpawnedRocket(args);

  player_rocket.Kill();
}

/*
  SpawnRocketAtEntity()

  Spawn a rocket at an entity.
*/
function SpawnRocketAtEntity(spawn_point_name, args_table = {}) {
  local spawn_point = Entities.FindByName(null, spawn_point_name);
  if (spawn_point == null) return;

  local args = ROCKETS.Helpers.PopulateArgs(args_table);

  args.target = args.target == null ? activator : Entities.FindByName(null, args.target);
  if (args.target == null) return;

  if (args.limit > 0 && activator.ValidateScriptScope()) {
    local scope = activator.GetScriptScope();

    if (!("rockets_limit" in scope)) scope["rockets_limit"] <- {};
    if (!(spawn_point_name in scope.rockets_limit)) scope.rockets_limit[spawn_point_name] <- 1;
    else scope.rockets_limit[spawn_point_name] += 1;

    if (scope.rockets_limit[spawn_point_name] > args.limit) return;
  }

  args.position = spawn_point.GetOrigin();
  args.direction = spawn_point.GetAbsAngles();

  ROCKETS.SpawnedRocket(args);
}

/*
  ResetLimit()

  Reset rocket limit for specific entity, for the !activator.
*/
function ResetLimit(limit_entity_name) {
  local scope = activator.GetScriptScope();
  if (!("rockets_limit" in scope)) return;

  if (limit_entity_name in scope.rockets_limit) {
    scope.rockets_limit[limit_entity_name] = 0;
  }
}

/*
  ResetLimits()

  Reset rocket limits for all entities, for the !activator.
*/
function ResetLimits() {
  local scope = activator.GetScriptScope();
  if (!("rockets_limit" in scope)) return;

  scope.rockets_limit <- {};
}

function Precache() {
  PrecacheModel("models/weapons/w_models/w_rocket.mdl");
  PrecacheEntityFromTable({
    classname = "info_particle_system",
    start_active = false,
    effect_name = ROCKETS.Globals.PARTICLE_SYSTEM_NAME
  });
  PrecacheEntityFromTable({
    classname = "env_explosion",
    spawnflags = 2,
    rendermode = 5
  });
}

function OnGameEvent_player_spawn(params) {
  if ("team" in params && params.team == 0 && "userid" in params) {
    local player = GetPlayerFromUserID(params.userid);
    player.ValidateScriptScope();
  }
}

/*
---------------------------------------------------------------
Rocket class
---------------------------------------------------------------
*/

class ROCKETS.SpawnedRocket {
  Entity                  = null; // Entity
  Position                = null; // Vector
  Direction               = null; // QAngle
  BaseSpeed               = null; // int
  Damage                  = null; // float
  Explode                 = null; // bool
  Target                  = null; // Entity
  Scale                   = null; // float
  FollowSpeedMultiplier   = null; // float
  CollisionAvoidance      = null; // bool
  TargetPrediction        = null; // bool
  Homing                  = null; // bool
  DamageEveryone          = null; // bool

  constructor(args) {
    this.Entity                 = Entities.CreateByClassname("tf_projectile_rocket");
    this.Position               = args.position;
    this.Direction              = args.direction;
    this.BaseSpeed              = args.speed;
    this.Damage                 = args.damage;
    this.Explode                = args.explode;
    this.Target                 = args.target;
    this.Scale                  = args.scale;
    this.FollowSpeedMultiplier  = args.follow_speed_multiplier;
    this.CollisionAvoidance     = args.collision_avoidance;
    this.TargetPrediction       = args.target_prediction;
    this.Homing                 = args.homing;
    this.DamageEveryone         = args.damage_everyone;

    args = null;

    this.Entity.Teleport(
      true, this.Position,
      true, this.Direction,
      false, Vector()
    );

    this.SetPropData("int", "m_bCritical", 0);
    this.SetPropData("int", "m_iTeamNum", 1);
    this.SetPropData("int", "m_iDeflected", 0);
    this.SetPropData("ent", "m_hOriginalLauncher", this.Entity);
    this.SetPropData("ent", "m_hLauncher", this.Entity);
    this.SetPropData("string", "m_iName", "spawned_rocket");
    this.SetPropData("int", "m_CollisionGroup", 24);
    this.SetPropData("int", "m_MoveType", 4);
    this.SetPropData("int", "m_nModelIndexOverrides", GetModelIndex("models/weapons/w_models/w_rocket.mdl"));
    this.SetPropData("int", "m_nNextThinkTick", -1);
    this.SetPropData("float", "m_flModelScale", this.Scale);

    Entities.DispatchSpawn(this.Entity);
    this.Entity.SetSize(ROCKETS.Globals.ROCKET_BOUNDS_P * this.Scale * -1, ROCKETS.Globals.ROCKET_BOUNDS_P * this.Scale);
    this.Entity.SetAbsVelocity(this.Direction.Forward() * this.BaseSpeed);
    AddCustomParticle();

    if (this.Explode) {
      SetDestroyCallback(this, function(entity, rocket) {
        ROCKETS.CreateExplosion(entity, rocket);
      });
    }

    if (this.Homing) {
      ROCKETS.Helpers.AddThinkFunc(this.Entity, this, "HomingRocketThink", function(rocket) {
        ROCKETS.HomingRocketThink(rocket);
      }, -1);
    } else {
      ROCKETS.Helpers.AddThinkFunc(this.Entity, this, "DefaultRocketThink", function(rocket) {
        ROCKETS.DefaultRocketThink(rocket);
      }, -1);
    }
  }

  function SetPropData(type, str, val) {
    switch(type) {
      case "int":
        NetProps.SetPropInt(this.Entity, str, val);
        break;
      case "float":
        NetProps.SetPropFloat(this.Entity, str, val);
        break;
      case "ent":
        NetProps.SetPropEntity(this.Entity, str, val);
        break;
      case "string":
        NetProps.SetPropString(this.Entity, str, val);
        break;
      default:
        return;
    }
  }

  function AddCustomParticle() {
    local particle_entity = SpawnEntityFromTable("info_particle_system", {
      start_active = false,
      effect_name = ROCKETS.Globals.PARTICLE_SYSTEM_NAME
    });

    if (particle_entity == null) return;

    particle_entity.Teleport(
      true, this.Entity.GetOrigin(),
      true, this.Entity.GetAbsAngles(),
      false, Vector()
    );
    particle_entity.AcceptInput("SetParent", "!activator", this.Entity, particle_entity);
    particle_entity.AcceptInput("SetParentAttachment", "trail", null, particle_entity);
    particle_entity.AcceptInput("Start", "", this.Entity, particle_entity);
  }

  // https://developer.valvesoftware.com/wiki/Team_Fortress_2/Scripting/Script_Functions#Hooks_2
  function SetDestroyCallback(rocket, callback){
    local entity = rocket.Entity;
    entity.ValidateScriptScope()
    local scope = entity.GetScriptScope()
    scope.setdelegate({}.setdelegate({
        parent   = scope.getdelegate()
        id       = entity.GetScriptId()
        index    = entity.entindex()
        callback = callback
        _get = function(k)
        {
          return parent[k]
        }
        _delslot = function(k)
        {
          if (k == id)
          {
            entity = EntIndexToHScript(index)
            local scope = entity.GetScriptScope()
            scope.self <- entity
            callback.pcall(scope, entity, rocket)
          }
          delete parent[k]
        }
      })
    )
  }
}

/*
---------------------------------------------------------------
Rocket functions
---------------------------------------------------------------
*/


// Default think functions for normal rockets.
function ROCKETS::DefaultRocketThink(rocket) {
  local rocket_entity = rocket.Entity;

  // Without this, rockets pushed with trigger_push don't point forward.
  rocket_entity.SetForwardVector(ROCKETS.Helpers.NormalizeVector(rocket_entity.GetAbsVelocity()));
}

// Think function for homing rockets.
function ROCKETS::HomingRocketThink(rocket) {
  if (rocket == null) return;

  local rocket_entity = rocket.Entity;
  local target = rocket.Target;
  local speed = rocket.BaseSpeed;
  local follow_speed_multiplier = rocket.FollowSpeedMultiplier;
  local collision_avoidance = rocket.CollisionAvoidance;
  local target_prediction = rocket.TargetPrediction;

  if (!target.IsValid()) {
    rocket_entity.Kill();
    return;
  } else {
    local current_dir = rocket_entity.GetForwardVector();
    local center = target.GetCenter();
    local bounds = target.GetBoundingMaxs();
    local targetPosBase = Vector(center.x, center.y, center.z - (bounds.z / 2)); // target position is at the players feet, to maximize upward velocity on impact.
    local targetDistance = (targetPosBase - rocket_entity.GetOrigin()).Length();
    local targetHeading = ROCKETS.Helpers.NormalizeVector(target.GetAbsVelocity());
    local targetSpeed = target.GetAbsVelocity().Length();
    local speedDiff = targetSpeed - speed;

    // Catch up to target
    if (follow_speed_multiplier > 1.0 && speedDiff > 0) {
      local followSpeed = targetSpeed * follow_speed_multiplier;

      if (speed < followSpeed) speed = followSpeed;
    }

    local targetPos = targetPosBase;
    local dontCheckFloor = false;

    // Predict target position
    if (target_prediction) {
      local timeToImpact = targetDistance / speed;
      local targetPosBase_prediction = targetPosBase + targetHeading.Scale(targetSpeed * timeToImpact);
      local z_offset_distance = bounds.z;

      // Check if the player is near the ground
      local trace_output = {
        start = targetPosBase,
        end = targetPosBase - Vector(0.0, 0.0, 1.0) * z_offset_distance,
        mask = 100679691,
        ignore = target
      };
      TraceLineEx(trace_output);

      dontCheckFloor = trace_output.hit;

      if (trace_output.hit) z_offset_distance = trace_output.fraction * z_offset_distance;

      // Try to fly below the player before hitting him. This is to always hit the players feet, to maximize upward velocity.
      local preferredTargetPosLow = Vector(targetPosBase_prediction.x, targetPosBase_prediction.y, targetPosBase_prediction.z - z_offset_distance);
      local preferredTargetPosHigh = Vector(targetPosBase_prediction.x, targetPosBase_prediction.y, targetPosBase_prediction.z - (z_offset_distance / 2));

      if (((targetPosBase.z < rocket_entity.GetOrigin().z) || (targetDistance > z_offset_distance * 2)) && rocket_entity.GetOrigin().z < preferredTargetPosLow.z) {
        targetPosBase_prediction = preferredTargetPosLow;
      } else if ((targetDistance > z_offset_distance) && rocket_entity.GetOrigin().z < preferredTargetPosHigh.z) {
        targetPosBase_prediction = preferredTargetPosHigh;
      } else if (targetDistance < z_offset_distance / 2) {
        targetPosBase_prediction = targetPosBase;
      }

      targetPos = targetPosBase_prediction;
    }

    local percentage = ROCKETS.Helpers.ClampValue(
      ROCKETS.Helpers.RangePercentage(ROCKETS.Globals.MAX_TURNRATE_DISTANCE, ROCKETS.Globals.MIN_TURNRATE_DISTANCE, targetDistance),
      0,
      100
    );
    local turnrate = ROCKETS.Helpers.RangeValue(ROCKETS.Globals.MAX_TURNRATE, ROCKETS.Globals.MIN_TURNRATE, percentage);
    local target_direction = ROCKETS.Helpers.CalculateDirectionToPosition(rocket_entity, targetPos);
    local final_direction = ROCKETS.Helpers.LerpVectors(current_dir, target_direction, turnrate);

    // Collision avoidance
    if (collision_avoidance) {
      final_direction = ROCKETS.RocketCollision(rocket_entity, final_direction, dontCheckFloor, targetDistance, bounds.z);
    }

    rocket_entity.SetAbsVelocity(final_direction.Scale(speed));
    rocket_entity.SetForwardVector(final_direction);
  }
}

// World geometry avoidance
function ROCKETS::RocketCollision(rocket_entity, current_direction, dont_check_floor, targetDistance, z_offset_distance) {
  rocket_entity.ValidateScriptScope();
  local scope = rocket_entity.GetScriptScope();
  local current_dir = rocket_entity.GetForwardVector();
  if (!("last_normal" in scope)) scope["last_normal"] <- null;

  // Check if the rocket is heading towards geometry.
  local trace_output = {
    start = rocket_entity.GetOrigin(),
    end = rocket_entity.GetOrigin() + current_dir * 200,
    mask = 67125259,
    ignore = rocket_entity
  };
  TraceLineEx(trace_output);

  if(trace_output.hit) {
    local normal = trace_output.plane_normal;
    // Maintain current heading if close to target and the target is close to the ground
    if (dont_check_floor && normal.z > 0.5 && targetDistance < z_offset_distance * 4) return current_direction;
    if (targetDistance < (trace_output.endpos - rocket_entity.GetOrigin()).Length()) return current_direction;

    // Save last normal vector of the geometry that was detected
    scope.last_normal = normal;

    local percentage = 100 - (trace_output.fraction * 100);
    local turnrate = ROCKETS.Helpers.RangeValue(ROCKETS.Globals.MAX_TURNRATE, ROCKETS.Globals.MIN_TURNRATE, percentage);
    //Try to fly perpendicular to the detected geometry
    local target_direction = ROCKETS.Helpers.NormalizeVector(current_dir + normal);

    return ROCKETS.Helpers.LerpVectors(current_dir, target_direction, turnrate);
  } else {
    if (scope.last_normal != null) {
      local last_normal_inverted = scope.last_normal * -1;

      // Check if the geometry is still next to us
      local trace_output2 = {
        start = rocket_entity.GetOrigin(),
        end = rocket_entity.GetOrigin() + last_normal_inverted * 90,
        mask = 67125259,
        ignore = rocket_entity
      };
      TraceLineEx(trace_output2);

      if (!trace_output2.hit) {
        scope.last_normal = null
        return current_direction;
      } else {
        // Fly away from the geometry by a tiny bit
        return current_dir + scope.last_normal * 0.01;
      }
    } else {
      return current_direction;
    }
  }
}

// Creates an explosion + impulse to the player
function ROCKETS::CreateExplosion(rocket_entity, rocket) {
  local explosion_entity = ROCKETS.CreateExplosionEntity();

  explosion_entity.Teleport(
    true, rocket_entity.GetOrigin(),
    false, QAngle(),
    false, Vector()
  );

  explosion_entity.AcceptInput("Explode", "", rocket_entity, rocket_entity);
  explosion_entity.Kill();

  ROCKETS.CreateImpulse(rocket_entity, rocket);
}

// Creates env_explosion. Mainly used for the particles, since m_flDamageForce seems to be broken - the player won't get knocked back more after a certain amount.
function ROCKETS::CreateExplosionEntity() {
  local explosion_entity = SpawnEntityFromTable("env_explosion", {
    spawnflags = 2,
    rendermode = 5
  });
  if (explosion_entity == null) return;

  NetProps.SetPropInt(explosion_entity, "m_iMagnitude", ROCKETS.Globals.ROCKET_DAMAGE);
  NetProps.SetPropFloat(explosion_entity, "m_flDamageForce", 0);
  NetProps.SetPropInt(explosion_entity, "m_iRadiusOverride", 100);

  return explosion_entity;
}

// Creates an impulse to players
function ROCKETS::CreateImpulse(rocket_entity, rocket)
{
  local damage = rocket.Damage;
  local explosion_position = rocket_entity.GetOrigin() + Vector(0, 0, -50);

  if (rocket.Damage <= 0) return;

  if (rocket.DamageEveryone) {
    for (local i = 1; i <= MaxClients().tointeger(); i++) {
      player = PlayerInstanceFromIndex(i);
      if (player == null) continue;

      ROCKETS.ApplyEntityImpulse(player, explosion_position, damage);
    }
  } else {
    local target = rocket.Target;
    if (target == null) return;

    ROCKETS.ApplyEntityImpulse(target, explosion_position, damage)
  }
}

// Apply velocity impulse to entity
function ROCKETS::ApplyEntityImpulse(entity, impulse_origin, magnitude) {
	local impulse_strength = 0.0;
	local impulse_direction = null;
  local entity_position = entity.GetOrigin();
  local distance_to_explosion = (impulse_origin - entity_position).Length();
  if (distance_to_explosion >= magnitude) return;

  impulse_direction = entity_position - impulse_origin;
  impulse_direction.Norm();

  if (distance_to_explosion < (magnitude / 2)) impulse_strength = magnitude * 3;
  else impulse_strength = (1.0 - ((2 * distance_to_explosion - magnitude) / magnitude)) * magnitude * 3; // Simple damage falloff

  entity.ApplyAbsVelocityImpulse(impulse_direction * impulse_strength);
}

/*
---------------------------------------------------------------
Helper functions
---------------------------------------------------------------
*/

// Adds a think function to a rocket
function ROCKETS::Helpers::AddThinkFunc(entity, rocket, name, func, delay = 0.1) {
  local entityScope = entity.GetScriptScope();

  if (!("ThinkClbs" in entityScope)) entityScope.ThinkClbs <- [];

  entityScope.ThinkClbs.append(func);
  entityScope["ThinkFuncs_"+name] <- function() {
    foreach (func in this.ThinkClbs) {
      func(rocket);
    }
    return delay;
	}

	AddThinkToEnt(entity, "ThinkFuncs_"+name);
}

// Used to instantiate rocket class
function ROCKETS::Helpers::PopulateArgs(input_table) {
  local args = clone ROCKETS.RocketArgs;

  foreach (key, value in input_table) {
    if (key in args) args[key] <- value;
  }

  return args;
}

function ROCKETS::Helpers::IsPlayerAlive(client) {
	return NetProps.GetPropInt(client, "m_lifeState") == 0;
}

function ROCKETS::Helpers::IsValidClient(client) {
	try {
		return client != null && client.IsValid() && client.IsPlayer() && IsPlayerAlive(client);
	} catch(e) {
		return false;
	}
}

function ROCKETS::Helpers::CalculateDirectionToPosition(rocket_entity, position) {
  local vTemp = position - rocket_entity.GetOrigin();
  vTemp.Norm();

  return vTemp;
}

function ROCKETS::Helpers::LerpVectors(vA, vB, t) {
	t = (t < 0.0) ? 0.0 : (t > 1.0) ? 1.0 : t;

	return vA + (vB - vA) * t;
}

function ROCKETS::Helpers::RangePercentage(a, b, t) {
  return ((t - a) * 100) / (b - a);
}

function ROCKETS::Helpers::RangeValue(a, b, t) {
  return (t * (b - a) / 100) + a;
}

function ROCKETS::Helpers::ClampValue(value, min, max) {
  return (value < min) ? min : (value > max) ? max : value;
}

function ROCKETS::Helpers::NormalizeVector(vector) {
  local length = vector.Length();
  if (length == 0.0) return vector;
  return Vector(vector.x / length, vector.y / length, vector.z / length);
}

// https://developer.valvesoftware.com/wiki/Team_Fortress_2/Scripting/VScript_Examples#Creating_Bots_That_Use_the_Navmesh
function ROCKETS::Helpers::VectorAngles(forward) {
	local yaw, pitch
	if ( forward.y == 0.0 && forward.x == 0.0 )
	{
		yaw = 0.0
		if (forward.z > 0.0)
			pitch = 270.0
		else
			pitch = 90.0
	}
	else
	{
		yaw = (atan2(forward.y, forward.x) * 180.0 / Constants.Math.Pi)
		if (yaw < 0.0)
			yaw += 360.0
		pitch = (atan2(-forward.z, forward.Length2D()) * 180.0 / Constants.Math.Pi)
		if (pitch < 0.0)
			pitch += 360.0
	}

	return QAngle(pitch, yaw, 0.0)
}
