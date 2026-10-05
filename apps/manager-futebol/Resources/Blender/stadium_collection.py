"""Five fictional stadium tiers. Run with Blender --background --python this_file."""
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'Assets.xcassets'
SCENES = Path(__file__).resolve().parent / 'exports' / 'stadiums'
SCENES.mkdir(parents=True, exist_ok=True)

def material(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*rgb, 1)
    return m

def box(name, xyz, size, mat, bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    if bevel:
        mod = o.modifiers.new('Rounded edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        o.modifiers.new('Normals', 'WEIGHTED_NORMAL')
    return o

def line(name, pts, mat, width=.018):
    c = bpy.data.curves.new(name, 'CURVE')
    c.dimensions = '3D'
    c.bevel_depth = width
    c.bevel_resolution = 1
    s = c.splines.new('POLY')
    s.points.add(len(pts)-1)
    for p, co in zip(s.points, pts):
        p.co = (*co, 1)
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)

def text(label, xyz, size, mat, rotation=(math.pi/2, 0, 0)):
    bpy.ops.object.text_add(location=xyz, rotation=rotation)
    o = bpy.context.object
    o.name = 'Fictional advertisement | ' + label
    o.data.body = label
    o.data.align_x = 'CENTER'
    o.data.align_y = 'CENTER'
    o.data.size = size
    o.data.extrude = .002
    o.data.materials.append(mat)

for tier, title in enumerate(['Varzea', 'Municipal', 'Regional', 'Profissional', 'UltraPremium'], 1):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    rng = random.Random(100+tier)
    grass = material('Grass', (.085, .34, .15))
    stripe = material('Grass stripes', (.12, .43, .20))
    white = material('Ivory', (.91, .93, .84))
    stone = material('Concrete', (.61, .60, .53))
    dark = material('Steel', (.035, .12, .12))
    gold = material('Gold', (.85, .59, .16))
    blue = material('Seating', (.08, .35, .49))
    dirt = material('Earth and concourse', (.43, .32, .19) if tier == 1 else (.25, .29, .28))
    glass = material('Skyboxes', (.20, .45, .50))
    shirts = [material('Fan shirt '+str(i), color) for i, color in enumerate([(.80,.22,.15),(.11,.39,.65),(.9,.75,.2),(.7,.7,.65)])]
    skin = material('Spectator heads', (.59,.37,.25))
    radius = 6.2 + tier*.32
    box('Stadium site', (0,0,-.18), (radius*2+1, 10+tier*.6,.35), dirt,.22)
    box('Football pitch', (0,0,.025), (9.8,5.9,.07),grass)
    if tier > 1:
        for i in range(10):
            box('Mowing stripe',(-4.4+i*.97,0,.067),(.47,5.8,.012),stripe,.005)
    z=.085
    line('Touchlines',[(-4.7,-2.75,z),(4.7,-2.75,z),(4.7,2.75,z),(-4.7,2.75,z),(-4.7,-2.75,z)],white)
    line('Halfway',[(0,-2.75,z),(0,2.75,z)],white)
    line('Center circle',[(.75*math.cos(i*math.tau/48),.75*math.sin(i*math.tau/48),z) for i in range(49)],white)
    for side in [-1,1]:
        x=side*4.7
        line('Penalty box',[(x,-1.4,z),(side*3.1,-1.4,z),(side*3.1,1.4,z),(x,1.4,z)],white)
        line('Goal frame',[(x,-.48,z),(x,-.48,.73),(x,.48,.73),(x,.48,z)],white,.035)
        for i in range(6):
            y=-.48+i*.192
            line('Goal net',[(x,y,.73),(x+side*.35,y,.1)],white,.008)
    # Vary the bowl footprint, number of tiers and standing/seated areas.
    sides = ['north'] if tier == 1 else (['north','west'] if tier == 2 else ['north','south','west','east'])
    rows = [2,3,4,6,8][tier-1]
    for stand in sides:
        long = stand in ['north','south']
        sign = 1 if stand in ['north','east'] else -1
        count=25 if long else 15
        for row in range(rows):
            height=.27+row*.29
            offset=(3.30 if long else 5.20)+row*.25
            loc=(0,sign*offset,height) if long else (sign*offset,0,height)
            dims=(10.3,.43,.25) if long else (.43,6.5,.25)
            box(stand+' terrace',loc,dims,stone if tier < 3 else blue,.035)
            for col in range(count):
                if col%8 == 0: # aisles remain open
                    continue
                along=(col-(count-1)/2)*.38
                px,py=(along,sign*offset) if long else (sign*offset,along)
                if tier>=2:
                    box('Individual seat',(px,py,height+.19),(.20,.19,.17),gold if row%3==0 else blue,.025)
                if rng.random() < (.40 if tier<3 else .72):
                    box('Spectator torso',(px,py,height+.38),(.12,.12,.22),rng.choice(shirts),.03)
                    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.073,location=(px,py,height+.56))
                    bpy.context.object.name='Spectator head'
                    bpy.context.object.data.materials.append(skin)
        # Covered grandstand, growing from one roof to a full elevated canopy.
        if tier>=2 and (tier>=4 or stand=='north'):
            h=.85+rows*.29
            center=(3.3+(rows-1)*.125) if long else (5.2+(rows-1)*.125)
            box(stand+' canopy',(0,sign*center,h) if long else (sign*center,0,h),
                (10.9,rows*.25+.65,.18) if long else (rows*.25+.65,7,.18),dark,.08)
            for along in [-4.6,0,4.6] if long else [-2.7,2.7]:
                px,py=(along,sign*(center+.28)) if long else (sign*(center+.28),along)
                box('Canopy column',(px,py,h/2),(.09,.09,h),stone,.015)
    if tier==1:
        # Open standing perimeter, simple shelter and wire fence.
        box('Changing room',(3.5,4.3,.43),(2.2,1.2,.85),stone)
        box('Changing room roof',(3.5,4.3,.90),(2.4,1.35,.12),dark)
        for x in range(-5,6):
            box('Fence post',(x,-3.55,.43),(.055,.055,.85),dark,.008)
        for h in [.25,.55,.83]:
            line('Wire fence',[(-5.8,-3.55,h),(5.8,-3.55,h)],dark,.009)
        for i in range(20):
            x=-4.5+i*.46
            box('Standing supporter',(x,-3.9,.34),(.14,.14,.40),rng.choice(shirts),.035)
    # Perimeter commercial boards, with tier-specific sponsor density.
    sponsors=['BOLA+','LOCAL','CHUTE','ARENA','FUTOS','GOL']
    for i in range([3,5,7,9,11][tier-1]):
        x=-4.5+i*9/max(1,[3,5,7,9,11][tier-1]-1)
        box('Advertising board',(x,3.04,.32),(.76,.09,.40),gold if i%2==0 else dark,.02)
        text(sponsors[i%6],(x,2.985,.32),.115,white)
    if tier>=3:
        box('Scoreboard',(0,4.8+rows*.20,2.2),(2.1,.25,.85),dark)
        text('HOME  0 : 0  AWAY',(0,4.65+rows*.20,2.2),.14,white)
    if tier>=4:
        box('VIP lounge facade',(0,4.65+rows*.15,1.9),(7.6,.35,.72),glass,.06)
        for x in range(-3,4):
            box('VIP window mullion',(x,4.44+rows*.15,1.9),(.05,.06,.70),gold,.01)
    if tier==5:
        # Premium upper ring, glass hospitality facade, generous entrance plaza.
        for side in [-1,1]:
            box('Upper premium gallery',(0,side*5.35,2.5),(11.7,.60,.30),gold,.07)
            box('Glass hospitality ring',(0,side*5.4,2.95),(11.5,.12,.55),glass,.04)
        box('Main entrance plaza',(0,-5.8,.12),(5.5,1.3,.18),stone,.1)
        for x in [-2,-1,0,1,2]:
            box('Premium entry portal',(x,-5.5,.65),(.65,.22,1.1),dark,.04)
    if tier>=2:
        for x,y in [(-5.7,-3.7),(5.7,-3.7),(-5.7,3.7),(5.7,3.7)]:
            h=2.5+tier*.5
            box('Lighting mast',(x,y,h/2),(.095,.095,h),stone,.018)
            box('Floodlight array',(x,y,h),(.65,.20,.22),white,.025)
    bpy.ops.object.camera_add(location=(15,-20,22))
    camera=bpy.context.object
    camera.rotation_euler=(Vector((0,0,.8))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'
    camera.data.ortho_scale=22
    scene=bpy.context.scene
    scene.camera=camera
    for pos,energy in [((-8,-10,18),2800),((8,6,12),1100)]:
        bpy.ops.object.light_add(type='AREA',location=pos)
        bpy.context.object.data.energy=energy
        bpy.context.object.data.size=12
    scene.render.engine='BLENDER_EEVEE'
    scene.eevee.taa_render_samples=48
    scene.render.resolution_x=1200
    scene.render.resolution_y=900
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.view_settings.view_transform='Standard'
    scene.view_settings.look='Medium High Contrast'
    asset=OUTPUT / ('Stadium'+title+'.imageset')
    asset.mkdir(parents=True,exist_ok=True)
    import json
    (asset/'Contents.json').write_text(json.dumps({'images':[{'filename':'stadium.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2))
    scene.render.filepath=str(asset/'stadium.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(SCENES/(title+'.blend')))
    bpy.ops.render.render(write_still=True)
    print('Completed stadium', tier, title, flush=True)
