"""Offline Stage 2 authoring. Rewrites Stage 2 and its static preview only.
Reconcile all integration changes before rerunning. No gameplay logic generated.
"""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parents[1]
resources, nodes = [], []
def vec(p):
    assert len(p) == 3, p
    return 'Vector3(' + ', '.join(str(round(x, 4)) for x in p) + ')'
def res(kind, name, props):
    name = name.replace('-', '_')
    resources.append(f'[sub_resource type="{kind}" id="{name}"]\n{props}\n')
    return f'SubResource("{name}")'
def node(name, kind, parent=None, props=''):
    nodes.append(f'[node name="{name}" type="{kind}"' + (f' parent="{parent}"' if parent is not None else '') + f']\n{props}\n')
def mat(name, rgb, glow=False, alpha=1):
    p = f'albedo_color = Color({rgb}, {alpha})\nroughness = 0.9'
    if glow: p += f'\nemission_enabled = true\nemission = Color({rgb}, 1)\nemission_energy_multiplier = 1.8'
    if alpha < 1: p += '\ntransparency = 1\ncull_mode = 2\nshading_mode = 0'
    return res('StandardMaterial3D', name, p)
teal = mat('CheckpointTeal', '0.12, 0.9, 0.73', True)
def box(name, size, material):
    return res('BoxMesh', name, f'size = {vec(size)}\nmaterial = {material}')
def cylinder(name, bottom, top, height, material, segments=8):
    return res('CylinderMesh', name, f'bottom_radius = {bottom}\ntop_radius = {top}\nheight = {height}\nradial_segments = {segments}\nmaterial = {material}')
def visual(name, parent, position, mesh, extra=''):
    node(name, 'MeshInstance3D', parent, f'position = {vec(position)}\nmesh = {mesh}\n{extra}')
def solid(name, parent, position, size, material=None):
    node(name, 'StaticBody3D', parent, f'position = {vec(position)}\ncollision_layer = 1\ncollision_mask = 2')
    path = name if parent == '.' else parent + '/' + name
    sh = res('BoxShape3D', 'Shape' + str(len(resources)), 'size = ' + vec(size))
    node('Collision', 'CollisionShape3D', path, f'shape = {sh}')
    if material: visual('Mesh', path, (0,0,0), box('Box' + str(len(resources)),size,material))
def area(name, parent, position, size, metadata=''):
    node(name, 'Area3D', parent, f'position = {vec(position)}\ncollision_layer = 0\ncollision_mask = 2\nmonitoring = false\n{metadata}')
    sh=res('BoxShape3D','AreaShape'+str(len(resources)), 'size = '+vec(size))
    node('Collision','CollisionShape3D',parent+'/'+name,f'shape = {sh}')
def marker(name,parent,pos,extra=''): node(name,'Marker3D',parent,'position = '+vec(pos)+'\n'+extra)

# Cold stone and sparse cyan guidance separate the mountain from the warm forest.
rock = mat('MountainRock', '0.20, 0.25, 0.36')
snow = mat('PaleSummit', '0.55, 0.64, 0.73')
cloud = mat('Cloud', '0.30, 0.38, 0.52')
ice = mat('WindCyan', '0.25, 0.75, 1.0', True)
storm = mat('StormViolet', '0.70, 0.31, 1.0', True)
veil = mat('StormVeil', '0.37, 0.25, 0.65', False, 0.025)
node('Stage','Node3D',props='metadata/stage_id = "stage_02"\nmetadata/handoff_state = "SCENE_READY_STATIC"')
for name in ['Environment','Geometry','Encounters','Checkpoints','Gates','RuntimeActors','FlightBounds']:
    node(name,'Node3D','.')
node('Limits','Marker3D','FlightBounds','metadata/min = Vector3(-55, 0, -760)\nmetadata/max = Vector3(55, 160, 40)')
skymat=res('ProceduralSkyMaterial','MountainSkyMaterial','sky_top_color = Color(0.045, 0.055, 0.12, 1)\nsky_horizon_color = Color(0.31, 0.39, 0.54, 1)\nground_bottom_color = Color(0.07, 0.09, 0.18, 1)\nground_horizon_color = Color(0.31, 0.39, 0.54, 1)')
sky=res('Sky','MountainSky',f'sky_material = {skymat}')
env=res('Environment','MountainEnvironment',f'background_mode = 2\nsky = {sky}\nambient_light_source = 3\nambient_light_color = Color(0.60, 0.70, 0.95, 1)\nambient_light_energy = 0.7\ntonemap_mode = 2\nfog_enabled = true\nfog_density = 0.0015\nfog_light_color = Color(0.21, 0.26, 0.40, 1)\nglow_enabled = true')
node('WorldEnvironment','WorldEnvironment','Environment',f'environment = {env}')
node('StormLight','DirectionalLight3D','Environment','rotation_degrees = Vector3(-42, -32, 0)\nlight_color = Color(0.72, 0.82, 1, 1)\nlight_energy = 1.5\nshadow_enabled = true')
# Terraces establish a rising floor without constricting the orbit space.
terraces=[('Approach',40,-90,0),('Ledges',-90,-195,14),('Basin',-195,-345,25),('Duel',-345,-450,48),('Ascent',-450,-570,65),('Summit',-570,-760,83)]
for name,start,end,height in terraces:
    solid(name,'Geometry',(0,height-5,(start+end)/2),(110,10,start-end),rock if height<65 else snow)
def floor(z):
    return next(height for _,start,end,height in terraces if end <= z <= start)
for name,pos,size in [('West',(-57,80,-360),(4,160,808)),('East',(57,80,-360),(4,160,808)),('Entrance',(0,80,42),(110,160,4)),('End',(0,80,-762),(110,160,4)),('Ceiling',(0,162,-360),(118,4,808)),('Floor',(0,-2,-360),(110,4,800))]:
    solid(name,'FlightBounds',pos,size)
marker('PlayerStart','.',(0,10,25))
# Faceted peaks stay outside the flight walls; no invisible decorative obstacles.
node('Peaks','Node3D','Environment')
peak=cylinder('Peak',29,2,110,rock,5)
cap=cylinder('SnowCap',11,0,42,snow,5)
for i in range(30):
    z=25-(i//2)*54; x=(-1 if i%2==0 else 1)*(90+(i%3)*9); y=floor(max(-759,z))
    par=f'Environment/Peaks/Peak{i}'
    node(f'Peak{i}','Node3D','Environment/Peaks',f'position = {vec((x,y,z))}\nrotation_degrees = Vector3(0, {i*37%360}, 0)')
    visual('Rock',par,(0,28,0),peak)
    visual('Snow',par,(0,82,0),cap)
# Low cloud shelves beyond the walls leave the route, seals and combat visible.
cloudmesh=res('SphereMesh','CloudMesh',f'radius = 32.0\nheight = 12.0\nradial_segments = 12\nrings = 6\nmaterial = {cloud}')
node('Clouds','Node3D','Environment')
for i in range(18):
    z=10-i*43
    visual(f'Cloud{i}','Environment/Clouds',((-1 if i%2 else 1)*95,floor(z)-12,z),cloudmesh)
# Guide stones sit at the route edge, with raised cyan fragments drawing the ascent.
node('WindTrail','Node3D','Environment')
shard=cylinder('WindShard',.4,0,2.2,ice,4)
for i in range(49):
    z=22-i*15; y=floor(z)+9
    for sign in [-1,1]:
        visual(f'Beacon{i}_{sign+1}','Environment/WindTrail',(sign*41,y,z),shard)

def arch(name,parent,z,y,material):
    node(name,'Node3D',parent,'position = '+vec((0,y,z)))
    par=parent+'/'+name
    for sign,label in [(-1,'Left'),(1,'Right')]:
        solid(label,par,(sign*20,13,0),(2,26,3),rock)
        visual(label+'Glow',par,(sign*18.8,16,1.6),box(name+label+'Trim',(.35,14,.3),material))
    solid('Lintel',par,(0,27,0),(44,2,4),snow)
    return par
for index,z in [(1,-90),(2,-195),(3,-330),(4,-450),(5,-570)]:
    par=f'Gates/Gate_S2_0{index}'
    node(f'Gate_S2_0{index}','Node3D','Gates',f'metadata/encounter_id = "S2-0{index}"')
    solid('BarrierBody',par,(0,80,z),(110,160,1))
    visual('ClosedVisual',par,(0,80,z),box(f'GateVeil{index}',(110,160,.1),veil))
    arch('Arch',par,z,floor(z+1),storm)
    node('OpenVisual','Node3D',par,'visible = false')
    visual('ClearBeacon',par+'/OpenVisual',(0,floor(z+1)+27,z),shard)

encounters=[
 (1,25,-90,[(1,'Spirit',[(-17,16,-45),(18,23,-68)])]),
 (2,-98,-195,[(1,'Spirit',[(-23,30,-124),(19,42,-133)]),(1,'Sentry',[(0,49,-150)]),(2,'Spirit',[(-20,47,-167),(23,33,-159)]),(2,'Sentry',[(0,38,-177)])]),
 (3,-203,-330,[]),
 (4,-376,-450,[(1,'Boss',[(0,76,-408)])]),
 (5,-458,-570,[(1,'Spirit',[(-23,81,-482),(20,92,-493)]),(1,'Sentry',[(0,99,-503)]),(2,'Spirit',[(-22,100,-533),(20,83,-541)]),(2,'Sentry',[(0,108,-548)])]),
 (6,-578,-610,[]),
 (7,-620,-749,[(1,'Boss',[(0,113,-690)])])]
for index,entry,exit_z,waves in encounters:
    eid=f'S2-0{index}'; par='Encounters/'+eid
    node(eid,'Node3D','Encounters',f'metadata/encounter_id = "{eid}"')
    area('EntryVolume',par,(0,80,entry),(110,160,4))
    area('ExitVolume',par,(0,80,exit_z+4),(110,160,4))
    node('Spawns','Node3D',par)
    counts={}
    for wave,kind,positions in waves:
        for pos in positions:
            key=(wave,kind); counts[key]=counts.get(key,0)+1
            marker(f'Wave{wave}_{kind}{counts[key]}',par+'/Spawns',pos)
    marker('RewardOrigin',par,(0,floor(exit_z+12)+13,exit_z+12))
    if index in [2,4]: marker('ShieldPickup',par,(12,floor(exit_z+12)+12,exit_z+12))

# Three independent approach volumes; links refer to guard markers, not actors.
par='Encounters/S2-03'
node('Seals','Node3D',par)
sealmesh=cylinder('SealCrystal',1.7,0,5,storm,6)
shieldmesh=res('SphereMesh','SealShield',f'radius = 3.4\nheight = 6.8\nmaterial = {veil}')
ring=res('TorusMesh','SealRing',f'inner_radius = 3.6\nouter_radius = 4.0\nrings = 32\nring_segments = 6\nmaterial = {ice}')
node('PortalLights','Node3D','Gates/Gate_S2_03')
for i,(label,pos) in enumerate([('Low',(-29,43,-256)),('Middle',(0,65,-285)),('High',(29,86,-267))],1):
    sp=f'{par}/Seals/Seal{i}'
    node(f'Seal{i}','Node3D',par+'/Seals',f'position = {vec(pos)}\nmetadata/seal_id = "S2-03-Seal{i}"')
    visual('Core',sp,(0,0,0),sealmesh)
    visual('ShieldVisual',sp,(0,0,0),shieldmesh)
    visual('OrbitRing',sp,(0,0,0),ring)
    area('ApproachVolume',sp,(0,0,10),(24,22,30))
    node('HitVolume','Area3D',sp,'collision_layer = 16\ncollision_mask = 0\nmonitoring = false\nmonitorable = false')
    shape=res('SphereShape3D',f'SealHit{i}','radius = 1.7')
    node('Collision','CollisionShape3D',sp+'/HitVolume',f'shape = {shape}')
    marker('RewardOrigin',sp,(0,-3,3))
    node('GuardLinks','Node3D',sp)
    for j,offset in enumerate([(-8,3,5),(8,5,-3)],1):
        guard=tuple(pos[k]+offset[k] for k in range(3))
        marker(f'Seal{i}_Sentry{j}',par+'/Spawns',guard)
        length=math.sqrt(sum(v*v for v in offset))
        visual(f'Guard{j}',sp+'/GuardLinks',tuple(v/2 for v in offset),box(f'GuardLink{i}{j}',(.12,.12,length),storm),
               'rotation = '+vec((math.asin(offset[1]/length),math.atan2(-offset[0],-offset[2]),0))+f'\nmetadata/guard_spawn = NodePath("Spawns/Seal{i}_Sentry{j}")')
    visual(f'Seal{i}','Gates/Gate_S2_03/PortalLights',((i-2)*8,58,-329),ring,'rotation_degrees = Vector3(90, 0, 0)')

for cid,z,y,resume in [('CP2-A',-354,62,'S2-04'),('CP2-B',-596,98,'S2-07')]:
    area(cid,'Checkpoints',(0,y,z),(38,26,6),f'metadata/checkpoint_id = "{cid}"\nmetadata/resume_encounter_id = "{resume}"')
    marker('Respawn','Checkpoints/'+cid,(0,0,-4))
    arch(cid+'Arch','Geometry',z,y-13,teal)
# Ringed platforms establish scale under each open boss volume.
for name,z,y,radius in [('Duel',-408,49,35),('Summit',-690,84,48)]:
    mesh=cylinder(name+'Platform',radius,radius,2,rock,48)
    visual(name+'Platform','Geometry',(0,y,z),mesh)
    shape=res('CylinderShape3D',name+'PlatformShape',f'radius = {radius}\nheight = 2.0')
    node(name+'PlatformBody','StaticBody3D','Geometry',f'position = {vec((0,y,z))}\ncollision_layer = 1\ncollision_mask = 2')
    node('Collision','CollisionShape3D','Geometry/'+name+'PlatformBody',f'shape = {shape}')
    rim=res('TorusMesh',name+'Rim',f'inner_radius = {radius-1}\nouter_radius = {radius-.5}\nrings = 64\nring_segments = 6\nmaterial = {ice}')
    visual(name+'Rim','Geometry',(0,y+1.1,z),rim)
arch('SummitThreshold','Geometry',-617,83,ice)
(ROOT/'scenes/stages/stage_02.tscn').write_text('[gd_scene format=3]\n\n'+'\n'.join(resources+nodes).rstrip()+'\n',encoding='utf-8')
(ROOT/'scenes/tests/stage_02_preview.tscn').write_text('''[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/stages/stage_02.tscn" id="1"]

[node name="Stage02Preview" type="Node3D"]

[node name="Stage" parent="." instance=ExtResource("1")]

[node name="PreviewCamera" type="Camera3D" parent="."]
position = Vector3(0, 17, 34)
rotation_degrees = Vector3(5, 0, 0)
current = true
fov = 72.0
far = 1100.0
''',encoding='utf-8')
print(f'Authored Stage 2: {len(nodes)} nodes, {len(resources)} resources.')
