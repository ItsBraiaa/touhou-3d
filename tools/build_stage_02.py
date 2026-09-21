"""Offline Stage 2 authoring. Rewrites Stage 2 and its static preview only.
Reconcile all integration changes before rerunning. No gameplay logic generated.
"""
from pathlib import Path
import math
import random

ROOT = Path(__file__).resolve().parents[1]
resources, nodes, external = [], [], []
rng = random.Random(2209)
ART = ROOT / 'assets/environment/stage_02'
ART.mkdir(parents=True, exist_ok=True)
def ext(kind, path, name):
    external.append(f'[ext_resource type="{kind}" path="res://{path}" id="{name}"]\n')
    return f'ExtResource("{name}")'
def mesh_asset(name, vertices, faces):
    # Original offline mesh; UVs repeat predictably for flowing water.
    lines = [f'v {x:.4f} {y:.4f} {z:.4f}' for x,y,z in vertices]
    lines += [f'vt {x*.1:.4f} {z*.1:.4f}' for x,y,z in vertices]
    lines += ['f '+' '.join(f'{i+1}/{i+1}' for i in face) for face in faces]
    (ART / (name+'.obj')).write_text('\n'.join(lines)+'\n')
    return ext('ArrayMesh', f'assets/environment/stage_02/{name}.obj', name)

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

# World-space texture breaks up large surfaces without per-model UV seams.
terrain_shader = ext('Shader', 'assets/environment/stage_02/terrain.gdshader', 'terrain_shader')
wind_shader = ext('Shader', 'assets/environment/stage_02/wind.gdshader', 'wind_shader')
gate_shader = ext('Shader', 'assets/environment/stage_02/gate_veil.gdshader', 'gate_shader')
water_shader = ext('Shader', 'assets/environment/stage_02/water.gdshader', 'water_shader')
noise=res('FastNoiseLite','RockNoise','seed = 29\nfrequency = 0.035\nfractal_octaves = 4')
grain=res('NoiseTexture2D','RockGrain',f'width = 512\nheight = 512\nseamless = true\nnoise = {noise}')
def terrain_material(name, stone, moss, amount):
    return res('ShaderMaterial',name,f'shader = {terrain_shader}\nshader_parameter/grain = {grain}\nshader_parameter/stone_color = Color({stone}, 1)\nshader_parameter/moss_color = Color({moss}, 1)\nshader_parameter/moss_amount = {amount}')
rock = terrain_material('WeatheredGranite','0.26, 0.28, 0.25','0.18, 0.27, 0.11',0.45)
groundmat = terrain_material('MossAndGravel','0.37, 0.32, 0.22','0.20, 0.31, 0.095',0.9)
snow = terrain_material('SummitLichen','0.59, 0.59, 0.48','0.28, 0.37, 0.18',0.55)
cloud = mat('Cloud', '0.66, 0.71, 0.67')
ice = mat('WindCyan', '0.14, 0.64, 0.63', True)
storm = mat('StormViolet', '0.65, 0.26, 0.69', True)
veil = mat('StormVeil', '0.37, 0.25, 0.65', False, 0.025)
gateveil = res('ShaderMaterial','GateWisps',f'shader = {gate_shader}')
wood = terrain_material('VermilionWood','0.44, 0.09, 0.035','0, 0, 0',0.0)
bark = mat('TreeBark','0.20, 0.14, 0.08')
roofmat = mat('SlateRoof','0.12, 0.20, 0.20')
bronze = mat('AgedGold','0.64, 0.40, 0.12')
lanternmat = mat('WarmLantern','1.0, 0.57, 0.16',True)
watermat = res('ShaderMaterial','FlowingWater',f'shader = {water_shader}\nshader_parameter/grain = {grain}')
flagmat=res('ShaderMaterial','PrayerCloth',f'shader = {wind_shader}\nshader_parameter/leaf_color = Color(0.69, 0.24, 0.07, 1)\nshader_parameter/sway = 0.35')
leaves=[]
for name,color in [('Pine','0.13, 0.30, 0.18'),('Jade','0.28, 0.42, 0.12'),('Amber','0.76, 0.35, 0.055')]:
    leaves.append(res('ShaderMaterial',name,f'shader = {wind_shader}\nshader_parameter/leaf_color = Color({color}, 1)\nshader_parameter/sway = 0.12'))
node('Stage','Node3D',props='metadata/stage_id = "stage_02"\nmetadata/handoff_state = "SCENE_READY_STATIC"')
for name in ['Environment','Geometry','Encounters','Checkpoints','Gates','RuntimeActors','FlightBounds']:
    node(name,'Node3D','.')
node('Limits','Marker3D','FlightBounds','metadata/min = Vector3(-55, 0, -760)\nmetadata/max = Vector3(55, 160, 40)')
skymat=res('ProceduralSkyMaterial','MountainSkyMaterial','sky_top_color = Color(0.12, 0.24, 0.29, 1)\nsky_horizon_color = Color(0.78, 0.73, 0.57, 1)\nground_bottom_color = Color(0.16, 0.24, 0.22, 1)\nground_horizon_color = Color(0.60, 0.65, 0.56, 1)')
sky=res('Sky','MountainSky',f'sky_material = {skymat}')
env=res('Environment','MountainEnvironment',f'background_mode = 2\nsky = {sky}\nambient_light_source = 3\nambient_light_color = Color(0.72, 0.79, 0.76, 1)\nambient_light_energy = 0.55\ntonemap_mode = 0\nfog_enabled = true\nfog_density = 0.0012\nfog_light_color = Color(0.48, 0.57, 0.54, 1)\nglow_enabled = true')
node('WorldEnvironment','WorldEnvironment','Environment',f'environment = {env}')
node('StormLight','DirectionalLight3D','Environment','rotation_degrees = Vector3(-38, -38, 0)\nlight_color = Color(1.0, 0.86, 0.64, 1)\nlight_energy = 1.0\nshadow_enabled = true\ndirectional_shadow_max_distance = 240.0')
# Terraces establish a rising floor without constricting the orbit space.
terraces=[('Approach',40,-90,0),('Ledges',-90,-195,14),('Basin',-195,-345,25),('Duel',-345,-450,48),('Ascent',-450,-570,65),('Summit',-570,-760,83)]
def surface_height(x,z):
    index=next(i for i,(_,start,end,_) in enumerate(terraces) if end <= z <= start)
    name,_,end,height=terraces[index]
    next_height=terraces[min(index+1,len(terraces)-1)][3]
    ramp_length=6 if name=='Duel' else 28
    ramp=max(0,1-(z-end)/ramp_length)
    ramp=ramp*ramp*(3-2*ramp)
    edge=max(0,abs(x)-32)/48
    return height+(next_height-height)*ramp+edge**2*(3+2*math.sin(z*.13+x*.08))
for name,start,end,height in terraces:
    # Deep foundations remove floating-slab gaps; sculpted surface matches collision.
    solid(name,'Geometry',(0,height-45,(start+end)/2),(110,90,start-end),rock)
    vertices=[]; faces=[]
    steps=64
    for row in range(steps+1):
        z=start+(end-start)*row/steps
        for col in range(17):
            x=-80+col*10
            vertices.append((x,surface_height(x,z),z))
    for row in range(steps):
        for col in range(16):
            a=row*17+col
            faces.extend([(a,a+1,a+17),(a+1,a+18,a+17)])
    mesh=mesh_asset('terrain_'+name.lower(),vertices,faces)
    # Surface vertices are stage-local; cancel the foundation transform.
    visual('Surface','Geometry/'+name,(0,45-height,-(start+end)/2),mesh, 'material_override = '+(groundmat if height<65 else snow))
    # Godot collision triangles use clockwise winding; OBJ uses counterclockwise.
    tris=[coordinate for face in faces for index in reversed(face) for coordinate in vertices[index]]
    shape=res('ConcavePolygonShape3D',name+'TerrainCollision','data = PackedVector3Array('+', '.join(str(round(v,4)) for v in tris)+')')
    node('SurfaceBody','StaticBody3D','Geometry/'+name,'position = '+vec((0,45-height,-(start+end)/2))+'\ncollision_layer = 1\ncollision_mask = 2')
    node('Collision','CollisionShape3D','Geometry/'+name+'/SurfaceBody','shape = '+shape)
def floor(z):
    return next(height for _,start,end,height in terraces if end <= z <= start)
for name,pos,size in [('West',(-57,80,-360),(4,160,808)),('East',(57,80,-360),(4,160,808)),('Entrance',(0,80,42),(110,160,4)),('End',(0,80,-762),(110,160,4)),('Ceiling',(0,162,-360),(118,4,808)),('Floor',(0,-2,-360),(110,4,800))]:
    solid(name,'FlightBounds',pos,size)
marker('PlayerStart','.',(0,10,25))
# Broad, irregular rock masses replace identical conical peaks.
node('Peaks','Node3D','Environment')
crags=[]
for variant in range(3):
    vertices=[]; faces=[]; sides=9
    for level,(h,radius) in enumerate([(-1,0.85),(-.5,1.0),(.2,.82),(.72,.40),(1,.055)]):
        for j in range(sides):
            a=j*math.tau/sides
            r=radius*rng.uniform(.82,1.14)
            vertices.append((math.cos(a)*r+h*.16,h+rng.uniform(-.07,.07),math.sin(a)*r))
    for level in range(4):
        for j in range(sides):
            a=level*sides+j; b=level*sides+(j+1)%sides
            faces.extend([(a,a+sides,b),(b,a+sides,b+sides)])
    faces += [(36,36+j+1,36+j) for j in range(1,8)]
    crags.append(mesh_asset('crag_'+str(variant),vertices,faces))
rockmesh=res('SphereMesh','BrokenRock','radius = 1.0\nheight = 2.0\nradial_segments = 7\nrings = 4\nmaterial = '+rock)
for i in range(46):
    z=35-(i//2)*36+rng.uniform(-13,13)
    x=(-1 if i%2 else 1)*rng.uniform(125,155)
    y=floor(max(-759,min(39,z)))
    width=rng.uniform(28,41); height=rng.uniform(30,68)
    visual(f'Ridge{i}','Environment/Peaks',(x,y+height*.43,z),crags[i%3],
           'material_override = '+rock+'\nscale = '+vec((width,height,rng.uniform(26,46)))+'\nrotation_degrees = '+vec((rng.uniform(-8,8),rng.uniform(0,180),rng.uniform(-8,8))))
# Distant crags and pale cloud shelves create depth beyond the route.
node('Clouds','Node3D','Environment')
cloudmesh=res('SphereMesh','CloudMesh',f'radius = 1.0\nheight = 2.0\nradial_segments = 12\nrings = 6\nmaterial = {cloud}')
for i in range(24):
    z=30-i*34
    y=floor(max(-759,z))
    sign=-1 if i%2 else 1
    visual(f'Cloud{i}','Environment/Clouds',(sign*rng.uniform(165,225),y-18,z),cloudmesh,'scale = '+vec((rng.uniform(36,65),rng.uniform(4,8),rng.uniform(25,50))))
    visual(f'FarPeak{i}','Environment/Peaks',(sign*rng.uniform(250,340),y+95,z),crags[i%3],'material_override = '+rock+'\nscale = '+vec((rng.uniform(50,85),rng.uniform(85,150),rng.uniform(55,95))))
# Vegetation trunks stay outside the flight walls; canopies move in the wind.
node('Vegetation','Node3D','Environment')
trunkmesh=cylinder('TrunkMesh',.7,.4,11,bark,7)
leafmeshes=[res('SphereMesh',f'LeafMesh{i}',f'radius = 1.0\nheight = 2.0\nradial_segments = 7\nrings = 4\nmaterial = {material}') for i,material in enumerate(leaves)]
for i in range(74):
    z=rng.uniform(-750,35); x=(-1 if i%2 else 1)*rng.uniform(60,78); y=surface_height(x,z)
    if -332<z<-313 or -627<z<-610: continue
    par=f'Environment/Vegetation/Tree{i}'
    node(f'Tree{i}','Node3D','Environment/Vegetation','position = '+vec((x,y,z)))
    h=rng.uniform(.7,1.5)
    visual('Trunk',par,(0,5.5*h,0),trunkmesh,'scale = '+vec((1,h,1)))
    palette=2 if i%5==0 else i%2
    for j in range(3):
        visual(f'Canopy{j}',par,((j-1)*3.3,9*h+j*2.1,math.sin(i+j)*2),leafmeshes[palette],
               'scale = '+vec((rng.uniform(4,6),rng.uniform(2.2,3.5),rng.uniform(3,5))))
# Low shrubs, grass tufts and yellow flowers break up the foreground without hiding shots.
grassmesh=res('PrismMesh','GrassMesh',f'size = Vector3(0.45, 1.8, 0.18)\nmaterial = {leaves[1]}')
flower=mat('FlowerOchre','0.95, 0.65, 0.13')
flowermesh=res('SphereMesh','FlowerMesh',f'radius = 0.25\nheight = 0.23\nradial_segments = 6\nrings = 3\nmaterial = {flower}')
for i in range(260):
    z=rng.uniform(-753,33); x=(-1 if i%2 else 1)*rng.uniform(36,53)
    y=surface_height(x,z)
    visual(f'Grass{i}','Environment/Vegetation',(x,y+.7,z),grassmesh,'rotation_degrees = '+vec((0,rng.uniform(0,360),rng.uniform(-15,15))))
    if i%3==0: visual(f'Flower{i}','Environment/Vegetation',(x+.35,y+.8,z),flowermesh)
for i in range(180):
    z=rng.uniform(-753,33); x=(-1 if i%2 else 1)*rng.uniform(42,76)
    y=surface_height(x,z)
    visual(f'Shrub{i}','Environment/Vegetation',(x,y+.65,z),leafmeshes[1 if i%3 else 0],
           'scale = '+vec((rng.uniform(1.2,3),rng.uniform(.7,1.4),rng.uniform(1,2.4))))
# Waterfalls flank the basin and summit; UV flow animates continuously without scripts.
node('Waterfalls','Node3D','Environment')
fallmesh=res('PlaneMesh','WaterfallMesh',f'size = Vector2(7, 48)\nsubdivide_width = 5\nsubdivide_depth = 12\nmaterial = {watermat}')
poolmesh=res('CylinderMesh','PoolMesh',f'top_radius = 9\nbottom_radius = 9\nheight = 0.15\nradial_segments = 48\nmaterial = {watermat}')
for i,(x,z) in enumerate([(-66,-235),(66,-308),(-65,-660),(66,-718)]):
    y=floor(z)
    visual(f'Fall{i}','Environment/Waterfalls',(x,y+25,z),fallmesh,'rotation_degrees = Vector3(90, 0, 0)')
    visual(f'Lip{i}','Environment/Waterfalls',(x,y+49,z-2),rockmesh,'scale = Vector3(6, 3, 5)')
    visual(f'Pool{i}','Environment/Waterfalls',(x,y+.5,z+2),poolmesh)
    for j in range(3):
        visual(f'Rock{i}_{j}','Environment/Waterfalls',(x+(-1 if x<0 else 1)*(8+j*5),y+10+j*12,z-5),rockmesh,'scale = '+vec((12,18,12)))
# A meandering shallow stream remains below flight and away from spawn centers.
for name,start,end,height in terraces:
    vertices=[]; faces=[]
    for i in range(65):
        z=start+(end-start)*i/64; center=19+math.sin(z*.025)*9
        width=3.0+math.sin(z*.12)*.5
        vertices += [(center-width,surface_height(center-width,z)+.18,z),(center+width,surface_height(center+width,z)+.18,z)]
    for i in range(64):
        a=i*2; faces.extend([(a,a+1,a+2),(a+1,a+3,a+2)])
    visual('Stream'+name,'Environment/Waterfalls',(0,0,0),mesh_asset('stream_'+name.lower(),vertices,faces),'material_override = '+watermat)
node('SummitBackdrop','Node3D','Environment')
for i in range(7):
    visual(f'Crag{i}','Environment/SummitBackdrop',(-230+i*75,120+rng.uniform(-15,20),-950-rng.uniform(0,65)),
           crags[i%3],'material_override = '+rock+'\nscale = '+vec((rng.uniform(45,70),rng.uniform(80,160),50)))
# Guide stones sit at the route edge, with raised cyan fragments drawing the ascent.
node('WindTrail','Node3D','Environment')
shard=cylinder('WindShard',.4,0,2.2,ice,4)
for i in range(25):
    z=22-i*30; y=surface_height(0,z)+9
    for sign in [-1,1]:
        visual(f'Beacon{i}_{sign+1}','Environment/WindTrail',(sign*41,y,z),shard)

def arch(name,parent,z,y,material):
    node(name,'Node3D',parent,'position = '+vec((0,y,z)))
    par=parent+'/'+name
    for sign,label in [(-1,'Left'),(1,'Right')]:
        solid(label,par,(sign*20,13,0),(2,26,3),wood)
        visual(label+'Glow',par,(sign*18.8,16,1.6),box(name+label+'Trim',(.35,14,.3),material))
    solid('Lintel',par,(0,27,0),(44,2,4),wood)
    visual('Roof',par,(0,29,0),box(name+'Roof',(49,1.2,5.5),roofmat))
    visual('GoldTrim',par,(0,27.4,2.1),box(name+'GoldTrim',(42,.3,.2),bronze))
    for sign,label in [(-1,'WestLantern'),(1,'EastLantern')]:
        visual(label,par,(sign*17,22,1.8),box(name+label,(1.7,2.3,1.7),lanternmat))
    flagmesh=res('PlaneMesh',name+'Cloth',f'size = Vector2(2.2, 6)\nsubdivide_width = 4\nsubdivide_depth = 10\nmaterial = {flagmat}')
    visual('PrayerCloth',par,(-22,22,0),flagmesh,'rotation_degrees = Vector3(90, 0, 0)')
    return par
for index,z in [(1,-90),(2,-195),(3,-330),(4,-450),(5,-570)]:
    par=f'Gates/Gate_S2_0{index}'
    node(f'Gate_S2_0{index}','Node3D','Gates',f'metadata/encounter_id = "S2-0{index}"')
    solid('BarrierBody',par,(0,80,z),(110,160,1))
    visual('ClosedVisual',par,(0,80,z),box(f'GateVeil{index}',(110,160,.1),gateveil))
    arch('Arch',par,z,surface_height(0,z),storm)
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
# Sparse geometric inlays preserve a quiet floor beneath the boss patterns.
for arena,z,y,radius in [('Duel',-408,50.15,35),('Summit',-690,85.15,48)]:
    for i in range(12):
        a=i*math.tau/12
        visual(f'{arena}Inlay{i}','Geometry',(math.sin(a)*(radius-5),y,z+math.cos(a)*(radius-5)),
               box(f'{arena}InlayMesh{i}',(.35,.04,3),bronze),'rotation = '+vec((0,a,0)))
arch('SummitThreshold','Geometry',-617,83,ice)
(ROOT/'scenes/stages/stage_02.tscn').write_text('[gd_scene format=3]\n\n'+'\n'.join(external+resources+nodes).rstrip()+'\n',encoding='utf-8')
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
