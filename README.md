# rockets.nut

VScript for spawning rockets that collide with players.
Place `rockets.nut` folder in `tf\scripts\vscripts` folder to get started.
Prefab with all necessary entities and examples is included (`rockets_script_examples_prefab.vmf`).

## Using the script

To use the script in a map, add a `logic_script` entity with the Entity Scripts field set to `rockets.nut` and with the name field set to `script`.
You can set defaults for various values for rockets by editing the `ROCKETS.Globals` table at the top of the `rocket.nut` file.

## Funtions

Both rocket spawning functions have an optional argument `parameters`, where you can set the properties of the rocket by passing it as a table with any of these values:
| Name | Type | Description |
|--|--|--|
| speed | float | Rocket speed |
| damage | float | Rocket explosion damage/knockback |
| homing | bool | Try to hit specified target |
| target | string | The target of the rocket (Default `!activator`) |
| scale | float | Model & Hitbox scale |
| limit | integer | How many rockets can be spawned at this entity before limit needs to be reset (Only works with `SpawnRocketAtEntity`) |
| collision_avoidance | bool | Avoid world geometry *(Only works with homing rockets)* |
| target_prediction | bool | Predict where the target will be at impact time *(Only works with homing rockets)* |
| follow_speed_multiplier | float | If the target is faster than rocket speed, speed up to x times target speed *(Only works with homing rockets)* |
| damage_everyone | bool | Damage all players in explosion range |
| explode | bool | Explode on impact |

You can set these by using this structure in your function call:
```
SpawnRocketAtEntity(`spawn_entity_name`, {target=`target_entity_name`,homing=true,damage=90.0,speed=1100,collision_avoidance=false})
```
*Note: To use strings in parameters, you have to use backticks (`). Do NOT use double quotation marks (") as this will corrup your .vmf file.*

Omitting the `target` parameter when spawning a homing rocket sets the `!activator` as the target.
The `target` parameter on non-homing (and also homing) rockets defines which entity or player is damaged by it, if the `damage_everyone` parameter is not set to `true`.

---

###  SpawnRocketAtEntity
Spawns a rocket at the location of an entity.

#### Arguments
| name | type | required |
|--|--|--|
| spawn_point_name | string | yes |
| parameters | table | no |
#### Usage

Create an `info_target` with a specific name and the angle at which the rocket will fly at. For this example, the name is set to `rocket1`.
Then, create something that will fire an output when you want to spawn the rocket, for example a `trigger_multiple` or a `func_button`. (`func_button` in this example)
Fill it with this output:
| My Output | Target Entity | Target Input | Parameter | Delay |
|--|--|--|--|--|
| OnPressed | script | RunScriptCode | SpawnRocketAtEntity(`rocket1`) | 0.00 |

---

### ReplaceRocket

Replaces a user fired rocket.
#### Arguments
| name | type | required |
|--|--|--|
| parameters | table | no |
#### Usage

Create a `trigger_multiple` with the `Everything (not including physics debris)` flag checked and the `Clients` flag unchecked. You need to have a filter for rocket projectiles set, so nothing else will trigger this. More about this later.
Add this output:
| My Output | Target Entity | Target Input | Parameter | Delay |
|--|--|--|--|--|
| OnStartTouch | script | RunScriptCode | ReplaceRocket() | 0.00 |

You can use this in combination with a `trigger_push` to reflect rockets back to the player that damage him.

---

### ResetLimit

Resets the rocket limit for a specific entity, for the `!activator` (The player that triggered `SpawnRocketAtEntity`).
#### Arguments
| name | type | required |
|--|--|--|
| entity_name | string | yes |

#### Usage
Fire an output with this to reset the limit for an entity that is targetet with `SpawnRocketAtEntity`, in this example a `trigger_multiple`:
| My Output | Target Entity | Target Input | Parameter | Delay |
|--|--|--|--|--|
| OnStartTouch | script | RunScriptCode | ResetLimit(`entity_name`) | 0.00 |

---

### ResetLimits

Resets the rocket limit for all entities, for the `!activator` (The player that triggers `SpawnRocketAtEntity`).
#### Arguments
None.
#### Usage
Fire an output with this to reset the limits for all entites targetet with `SpawnRocketAtEntity`, in this example a `trigger_multiple`:
| My Output | Target Entity | Target Input | Parameter | Delay |
|--|--|--|--|--|
| OnStartTouch | script | RunScriptCode | ResetLimits() | 0.00 |

---

## Filters
To filter for normal rockets, add two `filter_activator_class`, a `filter_activator_name` and two `filter_multi`entities with these settings to you map:

#### first `filter_activator_class`
| Property Name | Value |
|--|--|
| Name | is_stock_rocket |
| Filter mode | Allow ... |
| Filter Name | tf_projectile_rocket |
#### second `filter_activator_class`
| Property Name | Value |
|--|--|
| Name | is_cowmangler_rocket |
| Filter mode | Allow ... |
| Filter Name | tf_projectile_energy_ball |
#### `filter_activator_name`
| Property Name | Value |
|--|--|
| Name | is_not_spawned |
| Filter mode | Disallow ... |
| Filter Name | spawned_rocket |

The `Filter Name`will be red, this is normal.
#### first `filter_multi`
| Property Name | Value |
|--|--|
| Name | is_rocket |
| Logic Type | AND |
| Filter 1 | is_stock_rocket |
| Filter 2 | is_cowmangler_rocket |
#### second `filter_multi`
| Property Name | Value |
|--|--|
| Name | is_natural_rocket |
| Logic Type | AND |
| Filter 1 | is_rocket |
| Filter 2 | is_not_spawned |
---
Then, add the `is_natural_rocket` to any `trigger_multiple` or wherever you want to filter for normal rockets.
To filter for spawned rockets, add a `filter_activator_name` with Filter Name set to `spawned_rocket`.
