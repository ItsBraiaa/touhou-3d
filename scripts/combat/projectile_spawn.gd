class_name ProjectileSpawn
extends RefCounted
## A request for one Projectile, handed to [method ProjectileField.spawn].
##
## A plain value: the field copies the six fields and never keeps the request, so a caller
## may change and reuse one request for a whole volley.

## Who fired the Projectile. HOSTILE ones are swept against the player's Core and Graze
## Volume (F5-02); PLAYER ones against the hit spheres enemies register (F5-03).
enum Faction { PLAYER, HOSTILE }

## World position the Projectile starts from.
var position: Vector3
## World velocity in units per second, constant for the Projectile's whole life.
var velocity: Vector3
## Who fired it.
var faction: Faction = Faction.HOSTILE
## Seconds before the Projectile is removed; must be above 0.
var lifetime: float = 1.0
## Collision radius in world units; must be above 0.
var radius: float = 0.25
## Damage a hit deals: Health points against the player (CombatState), hit points against
## an enemy.
var damage: int = CombatState.HIT_DAMAGE


func _init(p_position := Vector3.ZERO, p_velocity := Vector3.ZERO,
		p_faction := Faction.HOSTILE, p_lifetime := 1.0, p_radius := 0.25,
		p_damage := CombatState.HIT_DAMAGE) -> void:
	position = p_position
	velocity = p_velocity
	faction = p_faction
	lifetime = p_lifetime
	radius = p_radius
	damage = p_damage
