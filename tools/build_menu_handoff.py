"""Offline UI scene authoring. Do not rerun after scene integration without review."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def write(path, content):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def landscape(mountain=False):
    far = "#243747" if mountain else "#153b3f"
    middle = "#182536" if mountain else "#0e2b31"
    shapes = []
    for i in range(11):
        x = i * 145 - 70
        height = 180 + (i * 79 % 190)
        shapes.append(f'<path d="M{x},650 L{x+112},{650-height} L{x+260},650Z" fill="{far}"/>')
        if mountain:
            shapes.append(f'<path d="M{x+85},{650-height+55} L{x+112},{650-height} L{x+156},{650-height+78} L{x+116},{650-height+58}Z" fill="#58616a" opacity=".55"/>')
        else:
            for j in range(2):
                tx = x + j * 80
                shapes.append(f'<path d="M{tx-55},570 L{tx},{300+(i*31%130)} L{tx+55},570Z" fill="{middle}"/>')
    if mountain:
        detail = '<path d="M980 295l-42 92 37-5-25 77 73-117-44 7 30-54Z" fill="#91d4d2" opacity=".65"/><path d="M710 478l136-73 108 39 176-64 100 58" fill="none" stroke="#94c5c7" stroke-width="2" opacity=".18"/>'
    else:
        detail = '''<g fill="#071c25"><path d="M805 365h290l-17 14H822Z"/><path d="M827 390h246v9H827Z"/><path d="M847 372h13l-5 155h-14Z"/><path d="M1041 372h13l6 155h-14Z"/></g>
<g fill="#e6b575"><path d="M777 486h14v21h-14Z"/><path d="M1110 486h14v21h-14Z"/><path d="M721 516h9v14h-9Z"/><path d="M1172 516h9v14h-9Z"/></g>
<g stroke="#a87b51" opacity=".45"><path d="M784 507v49M1117 507v49M725 530v36M1176 530v36"/></g>'''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">
<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#0a1726"/><stop offset=".7" stop-color="{'#36475b' if mountain else '#245256'}"/><stop offset="1" stop-color="#09232b"/></linearGradient><linearGradient id="shade"><stop stop-color="#07121f" stop-opacity=".98"/><stop offset=".42" stop-color="#07121f" stop-opacity=".88"/><stop offset="1" stop-color="#07121f" stop-opacity=".08"/></linearGradient><linearGradient id="water" x2="0" y2="1"><stop stop-color="#142f38"/><stop offset="1" stop-color="#07131f"/></linearGradient></defs>
<path fill="url(#sky)" d="M0 0h1280v720H0Z"/>
<circle cx="953" cy="237" r="90" fill="none" stroke="#bcd8d1" opacity=".08"/><circle cx="953" cy="237" r="67" fill="{'#b7cdd6' if mountain else '#ecc9a0'}" opacity=".85"/>
<g fill="#b9d8d7" opacity=".6"><circle cx="740" cy="125" r="1.5"/><circle cx="1140" cy="165" r="1"/><circle cx="850" cy="85" r="1"/><circle cx="1080" cy="95" r="1.5"/><circle cx="675" cy="216" r="1"/></g>
{''.join(shapes)}{detail}<path d="M0 565Q620 536 1280 569V720H0Z" fill="url(#water)"/>
<g stroke="#9cbbaf" opacity=".1"><path d="M780 581h270M848 595h125M707 614h405M839 637h236M605 676h505"/></g>
<path fill="url(#shade)" d="M0 0h1280v720H0Z"/>
<g fill="#e5b17b" opacity=".6"><circle cx="1020" cy="527" r="2"/><circle cx="918" cy="552" r="1.5"/><circle cx="848" cy="495" r="1"/></g>
</svg>'''


write('assets/ui/menu_forest.svg', landscape())
write('assets/ui/menu_mountain.svg', landscape(True))
write('assets/ui/wind_emblem.svg', '''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="28" fill="none" stroke="#d6b486" stroke-width="1.5"/><path d="M13 34l35-15-12 16-18 10 9-13Z" fill="none" stroke="#d6b486" stroke-width="2"/><path d="M12 44h10M39 12h8" stroke="#d6b486"/></svg>''')

# Shared UI resources: real Godot controls, scalable typography, strong focus outline.
write('assets/ui/menu_theme.tres', '''[gd_resource type="Theme" load_steps=9 format=3]

[sub_resource type="StyleBoxFlat" id="ButtonNormal"]
bg_color = Color(0.04, 0.085, 0.12, 0.86)
border_width_bottom = 1
border_color = Color(0.19, 0.29, 0.32, 1)
content_margin_left = 22.0
content_margin_right = 22.0
content_margin_top = 12.0
content_margin_bottom = 12.0

[sub_resource type="StyleBoxFlat" id="ButtonHover"]
bg_color = Color(0.1, 0.22, 0.25, 0.96)
border_width_left = 3
border_color = Color(0.84, 0.7, 0.48, 1)
content_margin_left = 22.0
content_margin_right = 22.0
content_margin_top = 12.0
content_margin_bottom = 12.0

[sub_resource type="StyleBoxFlat" id="ButtonPressed"]
bg_color = Color(0.19, 0.32, 0.33, 1)
content_margin_left = 22.0
content_margin_right = 22.0
content_margin_top = 12.0
content_margin_bottom = 12.0

[sub_resource type="StyleBoxFlat" id="Focus"]
bg_color = Color(0, 0, 0, 0)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.83, 0.71, 0.51, 1)

[sub_resource type="StyleBoxFlat" id="Panel"]
bg_color = Color(0.035, 0.073, 0.108, 0.96)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.15, 0.24, 0.28, 1)
content_margin_left = 24.0
content_margin_top = 24.0
content_margin_right = 24.0
content_margin_bottom = 24.0

[sub_resource type="StyleBoxFlat" id="Slider"]
bg_color = Color(0.11, 0.19, 0.23, 1)
content_margin_top = 3.0
content_margin_bottom = 3.0

[sub_resource type="StyleBoxFlat" id="SliderFill"]
bg_color = Color(0.42, 0.72, 0.68, 1)
content_margin_top = 3.0
content_margin_bottom = 3.0

[sub_resource type="StyleBoxEmpty" id="Empty"]

[resource]
default_font_size = 20
Label/colors/font_color = Color(0.87, 0.91, 0.9, 1)
Button/colors/font_color = Color(0.82, 0.87, 0.86, 1)
Button/colors/font_hover_color = Color(1, 0.9, 0.73, 1)
Button/colors/font_focus_color = Color(1, 0.9, 0.73, 1)
Button/colors/font_pressed_color = Color(1, 1, 1, 1)
Button/styles/normal = SubResource("ButtonNormal")
Button/styles/hover = SubResource("ButtonHover")
Button/styles/pressed = SubResource("ButtonPressed")
Button/styles/focus = SubResource("Focus")
Panel/styles/panel = SubResource("Panel")
PanelContainer/styles/panel = SubResource("Panel")
OptionButton/styles/normal = SubResource("ButtonNormal")
OptionButton/styles/hover = SubResource("ButtonHover")
OptionButton/styles/pressed = SubResource("ButtonPressed")
OptionButton/styles/focus = SubResource("Focus")
HSlider/styles/slider = SubResource("Slider")
HSlider/styles/grabber_area = SubResource("SliderFill")
HSlider/styles/grabber_area_highlight = SubResource("SliderFill")
HSlider/styles/focus = SubResource("Focus")
CheckButton/styles/focus = SubResource("Focus")
''')


def q(s): return json.dumps(s, ensure_ascii=False)


class UI:
    def __init__(self, root, background=True):
        self.root = root
        self.nodes = []
        self.focus = []
        self.node(root, 'Control', None, 'layout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\ntheme = ExtResource("1_theme")\nscript = ExtResource("5_controller")')
        if background:
            self.node('Background', 'TextureRect', '.', 'layout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\ntexture = ExtResource("2_forest")\nexpand_mode = 1\nstretch_mode = 6')
        self.node('Layout', 'Control', '.', 'layout_mode = 0\nanchor_left = 0.5\nanchor_top = 0.5\nanchor_right = 0.5\nanchor_bottom = 0.5\noffset_left = -640.0\noffset_top = -360.0\noffset_right = 640.0\noffset_bottom = 360.0\nmouse_filter = 2')

    def node(self, name, kind, parent, props=''):
        header = f'[node name="{name}" type="{kind}"'
        if parent is not None: header += f' parent="{parent}"'
        self.nodes.append([header+']', props])

    def rect(self, name, kind, x, y, w, h, props='', parent='Layout'):
        self.node(name, kind, parent, f'layout_mode = 0\noffset_left = {float(x)}\noffset_top = {float(y)}\noffset_right = {float(x+w)}\noffset_bottom = {float(y+h)}\n'+props)

    def label(self, name, text, x, y, w, h=36, size=20, muted=False, parent='Layout'):
        self.rect(name,'Label',x,y,w,h,f'mouse_filter = 2\ntext = {q(text)}\ntheme_override_font_sizes/font_size = {size}\n'+('theme_override_colors/font_color = Color(0.48, 0.62, 0.63, 1)' if muted else ''),parent)

    def button(self, name, text, x, y, w=320, h=52, parent='Layout'):
        self.rect(name,'Button',x,y,w,h,f'text = {q(text)}\nalignment = 0\nfocus_mode = 2',parent)
        self.focus.append((len(self.nodes)-1,parent+'/'+name))

    def header(self, section, subtitle=None):
        self.rect('Emblem','TextureRect',64,42,42,42,'mouse_filter = 2\ntexture = ExtResource("4_emblem")\nexpand_mode = 1')
        self.label('Brand','GUARDIÃ DOS VENTOS',122,46,440,32,17,True)
        self.label('Heading',section,64,112,1060,65,44)
        if subtitle: self.label('Subtitle',subtitle,66,182,900,28,18,True)

    def footer(self):
        self.label('NavigationHint','↑ ↓  Navegar     Enter  Confirmar',64,664,670,25,15,True)
        self.label('ChapterLabel','UMA JORNADA ENTRE ESPÍRITOS',900,664,330,25,13,True)

    def save(self, name):
        # Explicit neighbors avoid inconsistent spatial selection on grid layouts.
        for i,(index,path) in enumerate(self.focus):
            prev=self.focus[(i-1)%len(self.focus)][1]
            nxt=self.focus[(i+1)%len(self.focus)][1]
            # Root-anchored relative reference from any descendant.
            depth=path.count('/')+1
            prefix='../'*depth
            self.nodes[index][1]+=f'\nfocus_next = NodePath("{prefix}{nxt}")\nfocus_previous = NodePath("{prefix}{prev}")'
        externals='''[gd_scene format=3]
[ext_resource type="Theme" path="res://assets/ui/menu_theme.tres" id="1_theme"]
[ext_resource type="Texture2D" path="res://assets/ui/menu_forest.svg" id="2_forest"]
[ext_resource type="Texture2D" path="res://assets/ui/menu_mountain.svg" id="3_mountain"]
[ext_resource type="Texture2D" path="res://assets/ui/wind_emblem.svg" id="4_emblem"]
[ext_resource type="Script" path="res://scripts/ui/menu_controller.gd" id="5_controller"]
'''
        write('scenes/ui/'+name+'.tscn',externals+'\n'+'\n\n'.join(a+'\n'+b for a,b in self.nodes)+'\n')


ui=UI('MainMenu')
ui.rect('Emblem','TextureRect',76,66,52,52,'mouse_filter = 2\ntexture = ExtResource("4_emblem")\nexpand_mode = 1')
ui.label('Eyebrow','ENTRE O VENTO E O SAGRADO',146,78,440,30,15,True)
ui.label('Title','GUARDIÃ\nDOS VENTOS',76,142,640,162,62)
ui.label('Subtitle','O céu guarda seus próprios mistérios.',80,312,560,32,20,True)
for i,(name,text) in enumerate([('StartButton','Iniciar'),('StageSelectButton','Selecionar fase'),('OptionsButton','Opções'),('QuitButton','Sair')]):
    ui.button(name,text,78,376+i*57,342,49)
ui.footer()
ui.save('main_menu')

ui=UI('StageSelect')
ui.header('Selecionar fase')
for idx,(key,title,desc,tex) in enumerate([('Forest','Floresta das Lanternas','01  /  FLORESTA','2_forest'),('Mountain','Montanha da Tempestade','02  /  MONTANHA','3_mountain')]):
    x=64+idx*592
    ui.rect(key+'Card','Panel',x,218,560,328)
    par='Layout/'+key+'Card'
    ui.rect('Artwork','TextureRect',1,1,558,230,f'mouse_filter = 2\ntexture = ExtResource("{tex}")\nexpand_mode = 1\nstretch_mode = 6',par)
    ui.label('StageNumber',desc,22,240,510,25,14,True,par)
    ui.button('SelectButton',title,12,272,536,48,par)
ui.button('BackButton','Voltar',64,590,180)
ui.footer();ui.save('stage_select')

ui=UI('Options')
ui.header('Opções')
for key,x in [('Audio',64),('Display',462),('Controls',860)]:ui.rect(key,'Panel',x,210,356,352)
ui.label('Title','ÁUDIO',22,16,300,30,16,True,'Layout/Audio')
for i,(key,txt,val) in enumerate([('MasterVolume','Geral',80),('MusicVolume','Música',65),('SfxVolume','Efeitos',80)]):
    par='Layout/Audio'; y=66+i*82
    ui.label(key+'Label',txt,22,y,280,30,20,False,par)
    ui.rect(key,'HSlider',22,y+34,308,25,f'min_value = 0.0\nmax_value = 100.0\nstep = 1.0\nvalue = {float(val)}\nfocus_mode = 2',par)
    ui.focus.append((len(ui.nodes)-1,par+'/'+key))
def option(ui,key,parent,y,items,selected=0):
    props=f'focus_mode = 2\nselected = {selected}\nitem_count = {len(items)}'
    for i,item in enumerate(items):props+=f'\npopup/item_{i}/text = {q(item)}\npopup/item_{i}/id = {i}'
    ui.rect(key,'OptionButton',22,y,308,44,props,parent)
    ui.focus.append((len(ui.nodes)-1,parent+'/'+key))
ui.label('Title','TELA',22,16,300,30,16,True,'Layout/Display')
ui.label('ModeLabel','Modo',22,66,300,30,20,False,'Layout/Display')
option(ui,'WindowMode','Layout/Display',102,['Janela','Tela cheia'])
ui.label('ResolutionLabel','Resolução',22,168,300,30,20,False,'Layout/Display')
option(ui,'Resolution','Layout/Display',206,['1280 × 720','1600 × 900','1920 × 1080'])
ui.label('Title','CONTROLES',22,16,300,30,16,True,'Layout/Controls')
option(ui,'InputDevice','Layout/Controls',62,['Automático','Teclado','Controle'])
ui.label('SensitivityLabel','Sensibilidade',22,120,300,30,20,False,'Layout/Controls')
ui.rect('Sensitivity','HSlider',22,156,308,26,'min_value = 0.2\nmax_value = 2.0\nstep = 0.05\nvalue = 1.0\nfocus_mode = 2','Layout/Controls');ui.focus.append((len(ui.nodes)-1,'Layout/Controls/Sensitivity'))
ui.rect('InvertVertical','CheckButton',16,203,312,42,'text = "Inverter câmera vertical"\ntheme_override_font_sizes/font_size = 17\nfocus_mode = 2','Layout/Controls');ui.focus.append((len(ui.nodes)-1,'Layout/Controls/InvertVertical'))
ui.button('BindingsButton','Ver comandos',22,275,308,48,'Layout/Controls')
ui.button('BackButton','Voltar',64,590,180)
ui.button('DefaultsButton','Restaurar padrões',266,590,240)
ui.button('CreditsButton','Créditos',1036,590,180)
ui.footer();ui.save('options')

ui=UI('Controls')
ui.header('Comandos')
ui.rect('Bindings','Panel',64,206,1152,376)
ui.label('ActionHeader','AÇÃO',88,222,450,28,15,True)
ui.label('KeyboardHeader','TECLADO',540,222,330,28,15,True)
ui.label('ControllerHeader','CONTROLE',910,222,260,28,15,True)
rows=[('Mover','W A S D','Analógico esquerdo'),('Subir / descer','Espaço / Ctrl','RB / LB'),('Câmera','Setas / mouse','Analógico direito'),('Disparar','J','RT'),('Foco','Shift','LT'),('Fixar / trocar alvo','K / Tab','Y / X'),('Bomba','L','B'),('Pausa','Esc','Menu / Start')]
for i,(a,b,c) in enumerate(rows):
    y=267+i*37
    for n,t,x,w in [('Action',a,88,430),('Key',b,540,350),('Pad',c,910,280)]:ui.label(n+str(i),t,x,y,w,30,19)
ui.button('BackButton','Voltar',64,606,180);ui.footer();ui.save('controls')

# Pause and result scenes are overlays. A temporary background is supplied by QA only.
def overlay(root,title,kicker):
    ui=UI(root,False)
    ui.rect('Dim','ColorRect',0,0,1280,720,'mouse_filter = 2\ncolor = Color(0.015, 0.035, 0.06, 0.9)')
    ui.rect('Panel','Panel',390,95,500,530)
    ui.label('Kicker',kicker,430,126,420,28,15,True)
    ui.label('Heading',title,430,170,430,66,44)
    return ui
ui=overlay('PauseMenu','Pausa','GUARDIÃ DOS VENTOS')
ui.label('Score','Pontos  —     Graze  —',430,246,420,30,17,True)
for i,(name,text) in enumerate([('ResumeButton','Continuar'),('RestartButton','Reiniciar fase'),('OptionsButton','Opções'),('MenuButton','Voltar ao menu')]):ui.button(name,text,430,300+i*62,420,50)
ui.save('pause_menu')
ui=overlay('Defeat','Tente outra vez','A JORNADA CONTINUA')
ui.label('RetryLocation','Último checkpoint',430,250,420,30,20,True)
ui.button('RetryButton','Tentar novamente',430,352,420)
ui.button('MenuButton','Menu principal',430,422,420)
ui.save('defeat')
ui=overlay('Results','Fase concluída','O VENTO VOLTOU A SOPRAR')
for i,(name,title) in enumerate([('Time','Tempo'),('Score','Pontos'),('Graze','Graze'),('Bombs','Bombas usadas')]):
    ui.label(name+'Label',title,430,251+i*35,260,30,18,True)
    ui.label(name+'Value','—',740,251+i*35,110,30,18)
ui.button('ContinueButton','Continuar',430,432,420)
ui.button('ReplayButton','Jogar novamente',430,432,420)
ui.nodes[-1][1]+='\nvisible = false'
ui.button('MenuButton','Menu principal',430,498,420)
ui.button('CreditsButton','Créditos',430,557,420,44)
ui.save('results')
ui=UI('Credits')
ui.header('Créditos')
ui.label('GameName','GUARDIÃ DOS VENTOS',64,234,900,54,30)
ui.label('ModelsHeader','MODELO DA NAVE',66,326,800,30,15,True)
ui.label('Models','Kenney · Space Kit · CC0',66,366,950,35,24)
ui.label('ArtHeader','CENÁRIOS E INTERFACE',66,443,800,30,15,True)
ui.label('Art','Arte original do projeto',66,482,950,35,24)
ui.button('BackButton','Voltar',64,594,180);ui.footer();ui.save('credits')
print('Created shared theme, vector artwork and 8 menu scenes.')
