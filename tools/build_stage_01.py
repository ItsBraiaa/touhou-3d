"""Offline Stage 1 authoring. Rewrites only Stage 1 and its static preview.
Do not rerun over integration edits. No gameplay logic is generated.
"""
from pathlib import Path
import math
import random

ROOT = Path(__file__).resolve().parents[1]
resources, nodes = [], []
def vec(p): return 'Vector3(' + ', '.join(str(round(x, 4)) for x in p) + ')'
def res(kind, name, props):
    resources.append(f'[sub_resource type="{kind}" id="{name}"]\n{props}\n')
    return f'SubResource("{name}")'
def node(name, kind, parent=None, props=''):
    nodes.append(f'[node name="{name}" type="{kind}"' + (f' parent="{parent}"' if parent is not None else '') + f']\n{props}\n')
def mat(name, rgb, glow=False, alpha=1):
    p = f'albedo_color = Color({rgb}, {alpha})\nroughness = 0.9'
    if glow: p += f'\nemission_enabled = true\nemission = Color({rgb}, 1)\nemission_energy_multiplier = 1.8'
    if alpha < 1: p += '\ntransparency = 1\ncull_mode = 2\nshading_mode = 0'
    return res('StandardMaterial3D', name, p)
stone = mat('Stone', '0.17, 0.25, 0.25')
moss = mat('Moss', '0.12, 0.23, 0.20')
wood = mat('Wood', '0.31, 0.105, 0.08')
bark = mat('Bark', '0.085, 0.12, 0.125')
leaf = mat('Leaves', '0.06, 0.20, 0.18')
leaf2 = mat('LeavesLight', '0.12, 0.29, 0.25')
gold = mat('LanternGold', '1, 0.61, 0.19', True)
teal = mat('CheckpointTeal', '0.12, 0.9, 0.73', True)
violet = mat('Corrupted', '0.66, 0.25, 0.68', True)
barrier = mat('Barrier', '0.48, 0.21, 0.59', False, 0.055)
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

node('Stage','Node3D',props='metadata/stage_id = "stage_01"\nmetadata/handoff_state = "SCENE_READY_STATIC"')
for n in ['Environment','Geometry','Encounters','Checkpoints','Gates','RuntimeActors','FlightBounds']:
    node(n,'Node3D','.')
sky_mat=res('ProceduralSkyMaterial','SkyMaterial','sky_top_color = Color(0.035, 0.075, 0.14, 1)\nsky_horizon_color = Color(0.31, 0.39, 0.40, 1)\nground_bottom_color = Color(0.04, 0.08, 0.09, 1)\nground_horizon_color = Color(0.31, 0.39, 0.40, 1)')
sky=res('Sky','Sky',f'sky_material = {sky_mat}')
env=res('Environment','Env',f'background_mode = 2\nsky = {sky}\nambient_light_source = 3\nambient_light_color = Color(0.44, 0.66, 0.75, 1)\nambient_light_energy = 0.8\ntonemap_mode = 2\nfog_enabled = true\nfog_density = 0.002\nfog_light_color = Color(0.13, 0.25, 0.28, 1)\nglow_enabled = true')
node('WorldEnvironment','WorldEnvironment','Environment',f'environment = {env}')
node('Moonlight','DirectionalLight3D','Environment','rotation_degrees = Vector3(-48, -25, 0)\nlight_color = Color(0.65, 0.81, 1, 1)\nlight_energy = 1.3\nshadow_enabled = true\ndirectional_shadow_max_distance = 160.0')
# Broad terraces provide depth references; players fly above them, never climb steps.
for name, start, end, height in [('Entry',35,-140,0),('AscentLower',-140,-185,5),('AscentUpper',-185,-225,12),('Portal',-225,-335,18),('ShrineApproach',-335,-445,23),('Sanctuary',-445,-570,28)]:
    solid(name,'Geometry',(0,height-3,(start+end)/2),(90,6,start-end),moss)
    for x in [-46,46]:
        solid(name+('WestBank' if x<0 else 'EastBank'),'Geometry',(x,height+4,(start+end)/2),(4,14,start-end),stone)
# Outer collision covers the entire route; the arena remains wide enough to orbit.
for name,pos,size in [('West',(-47,38,-267.5),(4,80,605)),('East',(47,38,-267.5),(4,80,605)),('Entrance',(0,38,37),(98,80,4)),('End',(0,38,-572),(98,80,4)),('Ceiling',(0,77,-267.5),(98,4,613))]:
    solid(name,'FlightBounds',pos,size)
marker('PlayerStart','.',(0,7,20))
trunk=cylinder('Trunk',1.1,.65,16,bark)
canopy=cylinder('Canopy',7,0.7,15,leaf)
canopy2=cylinder('CanopyLight',5.5,0,12,leaf2)
lantern=box('Lantern',(0.9,1.3,0.9),gold)
cap=box('Cap',(1.35,.2,1.35),bark)
cord=cylinder('Cord',.035,.035,4,bark,6)
def ground(z):
    return 0 if z>-140 else 5 if z>-185 else 12 if z>-225 else 18 if z>-335 else 23 if z>-445 else 28
random.seed(11)
node('Forest','Node3D','Environment')
for i in range(130):
    z=random.uniform(-565,30); x=random.choice([-1,1])*random.uniform(44 if z < -470 else 32,65); y=ground(z)
    par=f'Environment/Forest/Tree{i}'
    node(f'Tree{i}','Node3D','Environment/Forest',f'position = {vec((x,y,z))}\nscale = {vec((1,random.uniform(0.85,1.5),1))}')
    visual('Trunk',par,(0,8,0),trunk)
    visual('Crown',par,(0,19,0),canopy)
    visual('Tip',par,(0,26,0),canopy2)
    # Trees inside the flight boundary have physical trunks; crowns are visual.
    if abs(x)<44: solid('TrunkBody',par,(0,8,0),(2.2,16,2.2))
node('LanternTrail','Node3D','Environment')
for i in range(45):
    z=20-i*12; y=ground(z)+9+(i%3)*1.6; x=math.sin(i*.38)*9
    for side in [-1,1]:
        par=f'Environment/LanternTrail/L{i}{"L" if side<0 else "R"}'
        node(par.split('/')[-1],'Node3D','Environment/LanternTrail','position = '+vec((x+side*15,y,z)))
        visual('Glow',par,(0,0,0),lantern)
        visual('Cap',par,(0,.8,0),cap)
        visual('Cord',par,(0,2.9,0),cord)
        if i%5==0: node('Light','OmniLight3D',par,'light_color = Color(1, 0.62, 0.24, 1)\nlight_energy = 2.0\nomni_range = 10.0')

def arch(name,parent,z,y,material):
    node(name,'Node3D',parent,'position = '+vec((0,y,z)))
    par=parent+'/'+name
    for side in [-1,1]: solid('Left' if side<0 else 'Right',par,(side*15,10,0),(1.5,20,1.5),wood)
    solid('Lintel',par,(0,20,0),(36,1.5,3),bark)
    visual('Trim',par,(0,18,0),box('Trim'+str(len(resources)),(32,.45,1.7),material))
    return par
gates={2:-140,3:-225,4:-315,5:-425}
for index,z in gates.items():
    name=f'Gate_S1_0{index}'
    node(name,'Node3D','Gates',f'metadata/encounter_id = "S1-0{index}"')
    par='Gates/'+name
    solid('BarrierBody',par,(0,37.5,z),(90,75,1),None)
    visual('ClosedVisual',par,(0,37.5,z),box('GateMesh'+str(index),(90,75,.1),barrier))
    arch('Arch',par,z,ground(z+.1),violet)

# Authored encounter frames stay at identity; all marker positions are stage-local.
data=[(1,20,-60,[],0),(2,-60,-140,[(1,'Spirit',[(-17,9,-95),(0,15,-110),(17,11,-96)]),(2,'Spirit',[(-20,15,-112),(4,8,-120),(19,18,-104)])],5),(3,-145,-225,[(1,'Sentry',[(-16,17,-172),(16,28,-207)])],0),(4,-230,-315,[(1,'Sentry',[(-24,29,-270),(0,44,-285),(24,34,-270)])],0),(5,-340,-425,[(1,'Spirit',[(-18,33,-365),(18,39,-370)]),(1,'Sentry',[(0,43,-386)]),(2,'Spirit',[(-20,40,-401),(19,31,-408)]),(2,'Sentry',[(0,35,-410)])],5),(6,-430,-460,[],0),(7,-465,-565,[(1,'Boss',[(0,43,-520)])],0)]
for index,entry,exit_z,waves,reward in data:
    eid=f'S1-0{index}'; par='Encounters/'+eid
    node(eid,'Node3D','Encounters',f'metadata/encounter_id = "{eid}"')
    area('EntryVolume',par,(0,37.5,entry),(90,75,4))
    area('ExitVolume',par,(0,37.5,exit_z+3),(90,75,4))
    node('Spawns','Node3D',par)
    counts={}
    for wave,kind,positions in waves:
        for pos in positions:
            key=(wave,kind); counts[key]=counts.get(key,0)+1
            marker(f'Wave{wave}_{kind}{counts[key]}',par+'/Spawns',pos)
    marker('RewardOrigin',par,(0,ground(exit_z+10)+9,exit_z+10))
    if index==3: marker('ShieldPickup',par,(12,24,-218))

for cid,z,y,resume in [('CP1-A',-325,18,'S1-05'),('CP1-B',-450,28,'S1-07')]:
    area(cid,'Checkpoints',(0,y+10,z),(30,20,5),f'metadata/checkpoint_id = "{cid}"\nmetadata/resume_encounter_id = "{resume}"')
    marker('Respawn','Checkpoints/'+cid,(0,-1,-4))
    arch(cid+'Arch','Geometry',z,y,teal)

# Visible links from the three guard positions to the sealed portal.
node('PortalLinks','Node3D','Environment')
for i,pos in enumerate([(-24,29,-270),(0,44,-285),(24,34,-270)]):
    end=(0,35,-314); delta=tuple(end[j]-pos[j] for j in range(3)); length=math.sqrt(sum(x*x for x in delta)); middle=tuple((pos[j]+end[j])/2 for j in range(3))
    # A box's local -Z points along the link direction; Euler pitch/yaw match Godot.
    pitch=math.asin(delta[1]/length); yaw=math.atan2(-delta[0],-delta[2])
    visual(f'GuardLink{i+1}','Environment/PortalLinks',middle,box(f'Link{i}',(.12,.12,length),violet),'rotation = '+vec((pitch,yaw,0)))

# Sanctuary platform, layered shrine roof and a suspended spiritual focal point.
platform=cylinder('ArenaPlatform',37,37,2,stone,48)
visual('ArenaPlatform','Geometry',(0,29,-515),platform)
arena_shape=res('CylinderShape3D','ArenaShape','radius = 37.0\nheight = 2.0')
node('ArenaBody','StaticBody3D','Geometry','position = Vector3(0, 29, -515)\ncollision_layer = 1\ncollision_mask = 2')
node('Collision','CollisionShape3D','Geometry/ArenaBody','shape = '+arena_shape)
solid('ShrineBase','Geometry',(0,32,-548),(14,4,10),stone)
solid('ShrineHouse','Geometry',(0,37,-550),(9,6,6),wood)
roof=res('PrismMesh','ShrineRoof','size = Vector3(18, 5, 13)\nmaterial = '+bark)
visual('ShrineRoof','Geometry',(0,42,-550),roof)
ring=res('TorusMesh','ArenaRing','inner_radius = 35.5\nouter_radius = 35.8\nrings = 64\nring_segments = 6\nmaterial = '+gold)
visual('ArenaRim','Geometry',(0,30.1,-515),ring)
arch('SanctuaryArch','Geometry',-465,28,gold)
marker('BossFocus','Geometry',(0,43,-520))
path=ROOT/'scenes/stages/stage_01.tscn'
path.write_text('[gd_scene format=3]\n\n'+'\n'.join(resources+nodes),encoding='utf-8')
(ROOT/'scenes/tests/stage_01_preview.tscn').write_text('''[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/stages/stage_01.tscn" id="1"]

[node name="Stage01Preview" type="Node3D"]

[node name="Stage" parent="." instance=ExtResource("1")]

[node name="PreviewCamera" type="Camera3D" parent="."]
position = Vector3(0, 12, 29)
rotation_degrees = Vector3(-5, 0, 0)
current = true
fov = 72.0
far = 750.0
''',encoding='utf-8')
print(f'Authored Stage 1: {len(nodes)} nodes, {len(resources)} resources.')
