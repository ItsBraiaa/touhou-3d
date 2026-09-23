from pathlib import Path
import math

ROOT=Path(__file__).resolve().parents[1]
class Scene:
    def __init__(self, external=''):
        self.resources=[]; self.nodes=[]; self.external=external
    def resource(self,kind,name,props):
        self.resources.append(f'[sub_resource type="{kind}" id="{name}"]\n{props}\n')
        return f'SubResource("{name}")'
    def node(self,name,kind,parent=None,props='',instance=None):
        tag=f'[node name="{name}"'
        if kind: tag+=f' type="{kind}"'
        if parent is not None: tag+=f' parent="{parent}"'
        if instance: tag+=f' instance={instance}'
        self.nodes.append(tag+']\n'+props+'\n')
    def save(self,path):
        (ROOT/path).write_text('[gd_scene format=3]\n\n'+self.external+'\n'+'\n'.join(self.resources+self.nodes),encoding='utf-8')
def v(x,y,z): return f'Vector3({x:.5f}, {y:.5f}, {z:.5f})'
def color(c): return 'Color('+', '.join(map(str,c))+')'
def material(s,n,c,emission=False,unshaded=False):
    props=f'albedo_color = {color(c)}\nroughness = 0.85'
    if emission: props+=f'\nemission_enabled = true\nemission = {color(c)}\nemission_energy_multiplier = 2.0'
    if unshaded: props+='\nshading_mode = 0'
    return s.resource('StandardMaterial3D',n,props)
def mesh(s,kind,n,props,mat):return s.resource(kind,n,props+f'\nmaterial = {mat}')

p=Scene('''[ext_resource type="PackedScene" path="res://assets/models/player/craft_speederA.glb" id="1_ship"]
[ext_resource type="Script" path="res://scripts/player/player_controller.gd" id="2_player"]
[ext_resource type="Script" path="res://scripts/player/camera_rig.gd" id="3_camera"]
[ext_resource type="Script" path="res://scripts/player/targeting.gd" id="4_target"]
[ext_resource type="Script" path="res://scripts/combat/player_weapon.gd" id="5_weapon"]
''')
teal=material(p,'Teal',(.08,.95,.84,1),True)
white=p.resource('StandardMaterial3D','CoreWhite','albedo_color = Color(0.75, 1, 1, 1)\nshading_mode = 0\nno_depth_test = true\nrender_priority = 10')
body=p.resource('BoxShape3D','BodyShape','size = Vector3(2, 0.8, 2.1)')
core=p.resource('SphereShape3D','CoreShape','radius = 0.18')
graze=p.resource('SphereShape3D','GrazeShape','radius = 0.55')
orb=mesh(p,'SphereMesh','CoreMesh','radius = 0.18\nheight = 0.36\nradial_segments = 16\nrings = 8',white)
engine=mesh(p,'SphereMesh','EngineMesh','radius = 0.12\nheight = 0.24\nradial_segments = 12\nrings = 6',teal)
p.node('PlayerShip','CharacterBody3D',props='collision_layer = 2\ncollision_mask = 1\nscript = ExtResource("2_player")\nmetadata/base_speed = 12.0\nmetadata/focus_multiplier = 0.45')
p.node('BodyCollision','CollisionShape3D','.',f'shape = {body}')
p.node('VisualRoot','Node3D','.')
p.node('Model',None,'VisualRoot','position = Vector3(-2, -0.4, -1.5)', 'ExtResource("1_ship")')
for x in [-.52,.52]:
    p.node('EngineL' if x<0 else 'EngineR','MeshInstance3D','VisualRoot',f'position = {v(x,-.08,.83)}\nmesh = {engine}\ncast_shadow = 0')
p.node('DamageCore','Area3D','.', 'collision_layer = 4\ncollision_mask = 0\nmonitoring = false')
p.node('CollisionShape3D','CollisionShape3D','DamageCore',f'shape = {core}')
p.node('CoreVisual','MeshInstance3D','DamageCore',f'mesh = {orb}\ncast_shadow = 0')
p.node('GrazeVolume','Area3D','.', 'collision_layer = 8\ncollision_mask = 0\nmonitoring = false')
p.node('CollisionShape3D','CollisionShape3D','GrazeVolume',f'shape = {graze}')
p.node('Muzzle','Marker3D','.', 'position = Vector3(0, 0, -1.25)')
p.node('FamiliarAnchors','Node3D','.')
for name,x in [('Left',-1.6),('Right',1.6)]:
    p.node(name,'Marker3D','FamiliarAnchors',f'position = {v(x,.25,.1)}')
p.node('Weapon','Node','.', 'script = ExtResource("5_weapon")')
p.node('Targeting','Node','.', 'script = ExtResource("4_target")')
p.node('CameraRig','Node3D','.', 'script = ExtResource("3_camera")')
p.node('Camera3D','Camera3D','CameraRig', 'position = Vector3(0, 3.2, 8.5)\nrotation = Vector3(-0.16, 0, 0)\ncurrent = true\nfov = 68.0\nnear = 0.1\nfar = 500.0')
p.save(Path('scenes/player/player_ship.tscn'))

s=Scene('[ext_resource type="PackedScene" path="res://scenes/player/player_ship.tscn" id="1_player"]\n')
stone=material(s,'Stone',(.19,.26,.29,1)); rim=material(s,'Rim',(.34,.43,.44,1)); dark=material(s,'Dark',(.055,.11,.13,1)); wood=material(s,'Wood',(.36,.11,.075,1)); gold=material(s,'Gold',(.95,.53,.14,1),True); teal=material(s,'Teal',(.07,.8,.76,1),True); green=material(s,'Green',(.085,.23,.2,1)); mountain=material(s,'Mountain',(.16,.28,.31,1))
def box(n,size,mat):return mesh(s,'BoxMesh',n,'size = '+v(*size),mat)
def cylinder(n,r,h,mat,top=None):return mesh(s,'CylinderMesh',n,f'top_radius = {r if top is None else top}\nbottom_radius = {r}\nheight = {h}\nradial_segments = 32',mat)
floor=cylinder('FloorMesh',39,1.5,stone)
rimmesh=cylinder('RimMesh',40,.65,rim)
floorshape=s.resource('CylinderShape3D','FloorShape','radius = 39.0\nheight = 1.5')
wallshape=s.resource('BoxShape3D','BoundaryShape','size = Vector3(3, 32, 80)')
post=box('PostMesh',(1,13,1),wood); beam=box('BeamMesh',(19,1.1,1.6),wood); beamdark=box('TopMesh',(22,.65,2.4),dark)
lantern=box('LanternMesh',(.7,1,.7),gold); cap=box('CapMesh',(1,.16,1),dark); pole=box('PoleMesh',(.14,5,.14),dark)
line=box('LineMesh',(.06,.025,64),rim)
ring=mesh(s,'TorusMesh','RingMesh','inner_radius = 1.65\nouter_radius = 1.78\nrings = 48\nring_segments = 8',teal)
targetorb=mesh(s,'SphereMesh','TargetOrb','radius = 0.7\nheight = 1.4\nradial_segments = 12\nrings = 6',gold)
targetshape=s.resource('SphereShape3D','TargetShape','radius = 0.85')
rock=mesh(s,'PrismMesh','RockMesh','size = Vector3(12, 28, 14)',mountain)
tree=mesh(s,'CylinderMesh','TreeMesh','top_radius = 0.0\nbottom_radius = 4.0\nheight = 12.0\nradial_segments = 7',green)
sky_mat=s.resource('ProceduralSkyMaterial','SkyMaterial','sky_top_color = Color(0.04, 0.12, 0.2, 1)\nsky_horizon_color = Color(0.65, 0.49, 0.37, 1)\nground_bottom_color = Color(0.08, 0.14, 0.17, 1)\nground_horizon_color = Color(0.65, 0.49, 0.37, 1)')
sky=s.resource('Sky','Sky',f'sky_material = {sky_mat}')
env=s.resource('Environment','Environment',f'background_mode = 2\nsky = {sky}\nambient_light_source = 3\nambient_light_color = Color(0.5, 0.72, 0.85, 1)\nambient_light_energy = 0.65\nreflected_light_source = 2\ntonemap_mode = 2\nfog_enabled = true\nfog_light_color = Color(0.22, 0.35, 0.39, 1)\nfog_density = 0.0015\nglow_enabled = true')
s.node('CombatArena','Node3D',props='metadata/handoff_state = "SCENE_READY_STATIC"')
s.node('Environment','Node3D','.')
s.node('WorldEnvironment','WorldEnvironment','Environment',f'environment = {env}')
s.node('Sun','DirectionalLight3D','Environment','rotation_degrees = Vector3(-38, -32, 0)\nlight_color = Color(1, 0.79, 0.56, 1)\nlight_energy = 1.6\nshadow_enabled = true\ndirectional_shadow_max_distance = 110.0')
s.node('Geometry','Node3D','.')
s.node('Floor','StaticBody3D','Geometry','position = Vector3(0, -0.75, -6)\ncollision_layer = 1\ncollision_mask = 2')
s.node('Mesh','MeshInstance3D','Geometry/Floor',f'mesh = {floor}')
s.node('Collision','CollisionShape3D','Geometry/Floor',f'shape = {floorshape}')
s.node('Foundation','MeshInstance3D','Geometry',f'position = Vector3(0, -1.55, -6)\nmesh = {rimmesh}')
for i,x in enumerate(range(-24,25,8)):
    s.node(f'GridLong{i}','MeshInstance3D','Geometry',f'position = {v(x,.015,-6)}\nmesh = {line}')
    s.node(f'GridCross{i}','MeshInstance3D','Geometry',f'position = {v(0,.015,x-6)}\nrotation_degrees = Vector3(0, 90, 0)\nmesh = {line}')
s.node('ShrineGate','Node3D','Geometry','position = Vector3(0, 0, -27)')
for n,x in [('Left',-8),('Right',8)]:s.node(n,'MeshInstance3D','Geometry/ShrineGate',f'position = {v(x,6.5,0)}\nmesh = {post}')
for n,y,m in [('Beam',10.5,beam),('Top',13,beamdark)]:s.node(n,'MeshInstance3D','Geometry/ShrineGate',f'position = {v(0,y,0)}\nmesh = {m}')
# Torii collision remains local to its visual posts/beam.
for n,x in [('LeftBody',-8),('RightBody',8)]:
    sh=s.resource('BoxShape3D',n+'Shape','size = Vector3(1, 13, 1)')
    s.node(n,'StaticBody3D','Geometry/ShrineGate',f'position = {v(x,6.5,0)}')
    s.node('Collision','CollisionShape3D','Geometry/ShrineGate/'+n,f'shape = {sh}')
beamshape=s.resource('BoxShape3D','BeamShape','size = Vector3(19, 1.1, 1.6)')
s.node('BeamBody','StaticBody3D','Geometry/ShrineGate','position = Vector3(0, 10.5, 0)')
s.node('Collision','CollisionShape3D','Geometry/ShrineGate/BeamBody',f'shape = {beamshape}')
s.node('FlightBounds','Node3D','.', 'metadata/min_corner = Vector3(-39, 0, -45)\nmetadata/max_corner = Vector3(39, 30, 33)')
for name,pos,rotate in [('West',(-40.5,15,-6),False),('East',(40.5,15,-6),False),('North',(0,15,-46.5),True),('South',(0,15,34.5),True)]:
    s.node(name,'StaticBody3D','FlightBounds',f'position = {v(*pos)}'+('\nrotation_degrees = Vector3(0, 90, 0)' if rotate else ''))
    s.node('Collision','CollisionShape3D','FlightBounds/'+name,f'shape = {wallshape}')
ceiling=s.resource('BoxShape3D','CeilingShape','size = Vector3(80, 3, 80)')
s.node('Ceiling','StaticBody3D','FlightBounds','position = Vector3(0, 31.5, -6)')
s.node('Collision','CollisionShape3D','FlightBounds/Ceiling',f'shape = {ceiling}')
s.node('Lanterns','Node3D','Geometry')
for i in range(12):
    a=2*math.pi*i/12; x=34*math.cos(a); z=34*math.sin(a)-6
    par=f'Geometry/Lanterns/Lantern{i}'
    s.node(f'Lantern{i}','Node3D','Geometry/Lanterns',f'position = {v(x,0,z)}')
    for n,y,m in [('Pole',2.5,pole),('Light',5,lantern),('Cap',5.6,cap)]:s.node(n,'MeshInstance3D',par,f'position = {v(0,y,0)}\nmesh = {m}')
s.node('Backdrop','Node3D','Environment')
for i in range(16):
    a=2*math.pi*i/16; x=62*math.cos(a); z=62*math.sin(a)-6
    s.node(f'Peak{i}','MeshInstance3D','Environment/Backdrop',f'position = {v(x,-2,z)}\nrotation_degrees = {v(0,i*37,0)}\nscale = {v(1+(i%3)*.35,1+(i%4)*.3,1)}\nmesh = {rock}')
for i in range(14):
    x=(-1 if i%2 else 1)*(29+(i%3)*3); z=-35+(i//2)*9
    s.node(f'Tree{i}','MeshInstance3D','Environment/Backdrop',f'position = {v(x,5,z)}\nmesh = {tree}')
s.node('Targets','Node3D','.')
for n,pos in [('Low',(-10,5,-8)),('Middle',(0,9,-20)),('High',(11,15,-10))]:
    s.node(n,'Node3D','Targets',f'position = {v(*pos)}\nmetadata/target_id = "{n.lower()}"')
    # Add the target group directly to the node declaration.
    s.nodes[-1]=s.nodes[-1].replace('parent="Targets"]','parent="Targets" groups=["targetable"]]')
    par='Targets/'+n
    s.node('Orb','MeshInstance3D',par,f'mesh = {targetorb}')
    s.node('Ring','MeshInstance3D',par,f'rotation_degrees = Vector3(90, 0, 0)\nmesh = {ring}')
    s.node('HitVolume','Area3D',par,'collision_layer = 16\ncollision_mask = 0\nmonitoring = false')
    s.node('Collision','CollisionShape3D',par+'/HitVolume',f'shape = {targetshape}')
s.node('PlayerStart','Marker3D','.', 'position = Vector3(0, 6, 18)')
s.node('PlayerShip',None,'.','position = Vector3(0, 6, 18)','ExtResource("1_player")')
s.node('RuntimeActors','Node3D','.')
s.node('ProjectileRoot','Node3D','.')
s.save(Path('scenes/tests/combat_arena.tscn'))
print('Authored player_ship.tscn and combat_arena.tscn')
