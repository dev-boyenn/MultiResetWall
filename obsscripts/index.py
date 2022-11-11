from math import ceil, floor
import obspython as S
import os

# Configure
wall_scene = S.obs_scene_get_source(S.obs_get_scene_by_name(wall_scene_name))
screen_width = S.obs_source_get_width(wall_scene)
screen_height = S.obs_source_get_height(wall_scene)
S.obs_source_release(wall_scene)

# Don't configure

focus_cols = 0
focus_rows = 0
screen_estate_horizontal = 0
screen_estate_vertical = 0
locked_rows_before_rollover = 0
wall_scene_name = ""
instance_source_format = ""
focused_count = focus_rows * focus_cols
prev_instances = []
prev_passive_count = 0
prev_locked_count = 0
lastUpdate = 0.0



class FileInstance():
    def __init__(self, suffix,locked,hidden):
        self.suffix = suffix
        self.locked = locked
        self.hidden = hidden
    def __eq__(self, other):
        """Overrides the default implementation"""
        if isinstance(other, FileInstance):
            return self.suffix == other.suffix and self.locked == other.locked and self.hidden == other.hidden
        return False
    def __str__(self) -> str:
        return self.suffix + ("L"if self.locked else "") + ("H" if self.hidden else "")
    pass

def move_source(source, x, y): 
    if source:
        pos = S.vec2()
        S.obs_sceneitem_get_pos(source, pos)  
        if(pos.x == x and pos.y == y):
            return
        pos.x = x
        pos.y = y
        S.obs_sceneitem_set_pos(source, pos)

def scale_source(source, width, height): 
    if source:
        bounds = S.vec2();
        bounds.x = width;
        bounds.y=height;
        S.obs_sceneitem_set_bounds(source, bounds)  

def parse_instances_string(input:str) -> 'list[FileInstance]': 
    raw_instances = input.split(",")
    return list(map(lambda inst: FileInstance(suffix=inst.split("L")[0].split("H")[0],locked="L" in inst, hidden = "H" in inst),raw_instances))

def passive_instance_count(instances:'list[FileInstance]'):
    return len(list(filter(lambda inst: inst.hidden ,instances)))

def locked_instance_count(instances:'list[FileInstance]'):
    return len(list(filter(lambda inst: inst.locked ,instances)))

def test():
    try:
        global lastUpdate
        global prev_instances
        global prev_locked_count
        global prev_passive_count
        global locked_rows_before_rollover

        test_scene = S.obs_get_scene_by_name(wall_scene_name)
        if not test_scene:
            print("Can't find scene")
            return

        path = os.path.dirname(os.path.realpath(__file__))
        filePath = os.path.abspath(os.path.realpath(os.path.join(path,'..','data','obs.txt')))
        if not os.path.exists(filePath):
            print("Can't find obs.txt")
            return
        currentTime = os.path.getmtime(filePath)
        if currentTime == lastUpdate:
            return
        lastUpdate = currentTime

        with open(filePath) as f:
            
            raw_instances_string = f.readlines()[0]
            instances = parse_instances_string(raw_instances_string)
            print(raw_instances_string)
            passive_count = passive_instance_count(instances)
            locked_count = locked_instance_count(instances)
            locked_cols = ceil(locked_count / locked_rows_before_rollover)

            backupRow = 0
            lockedIndex = 0
            for item in range(len(instances)):
                if instances[item].hidden:
                    if passive_count == prev_passive_count and instances[item] == prev_instances[item]:
                        backupRow+=1
                        continue
                    scene_item = S.obs_scene_find_source(test_scene, instance_source_format.replace("*",instances[item].suffix))
                    inst_height = screen_height / passive_count
                    move_source(scene_item, screen_width*screen_estate_horizontal,backupRow * inst_height )
                    scale_source(scene_item,screen_width*(1-screen_estate_horizontal),inst_height)
                    backupRow+=1
                    continue
                if instances[item].locked:
                    if locked_count == prev_locked_count and instances[item] == prev_instances[item]:
                        lockedIndex+=1
                        continue
                    scene_item = S.obs_scene_find_source(test_scene, instance_source_format.replace("*",instances[item].suffix))

                    inst_width = (screen_width*screen_estate_horizontal) / locked_cols
                    inst_height = (screen_height * (1-screen_estate_vertical)) / min(locked_count,locked_rows_before_rollover)
                    move_source(scene_item, (inst_width * floor(lockedIndex / locked_rows_before_rollover)) ,screen_height * screen_estate_vertical + inst_height * (lockedIndex%locked_rows_before_rollover))
                    scale_source(scene_item,inst_width, inst_height )
                    lockedIndex+=1
                    continue
                row = floor(item/focus_cols)
                col = floor(item%focus_cols)

                scene_item = S.obs_scene_find_source_recursive(test_scene, instance_source_format.replace("*",instances[item].suffix))
                move_source(scene_item, col*(screen_width*screen_estate_horizontal/focus_cols),row*(screen_height*screen_estate_vertical/focus_rows))
                scale_source(scene_item,screen_width*screen_estate_horizontal/focus_cols,screen_height*screen_estate_vertical/focus_rows)
            prev_instances = instances
            prev_passive_count = passive_count
            prev_locked_count = locked_count
    except Exception as e:
        print(e)
        return

def script_properties():  # ui
    props = S.obs_properties_create()
    p = S.obs_properties_add_list(
        props,
        "scene",
        "Wall Scene\n--------------------------------------------------",
        S.OBS_COMBO_TYPE_EDITABLE,
        S.OBS_COMBO_FORMAT_STRING,
    )

    scenes = S.obs_frontend_get_scenes()
    for scene in scenes:
        name = S.obs_source_get_name(scene)
        S.obs_property_list_add_string(p, name, name)
    S.source_list_release(scenes)
    S.obs_properties_add_text(
        props,
        "instance_source_format",
        "Instance Source Format\nThe names of the captures in your Wall scene.\nUse * for numbers (e.g. RSG*)\n--------------------------------------------------",
        S.OBS_TEXT_DEFAULT
    )

    S.obs_properties_add_int(
        props,
        "focus_rows",
        "Grid rows (Horizontal)\n# of rows in the focus grid.\nSet rows in settings.ahk to the same number.\n--------------------------------------------------",
        1,
        4,
        1
    )
    S.obs_properties_add_int(
        props,
        "focus_cols",
        "Grid cols (Vertical)\n# of columns in the focus grid.\nSet cols in settings.ahk to the same number.\n--------------------------------------------------",
        1,
        4,
        1
    )
    S.obs_properties_add_float(
        props,
        "screen_estate_horizontal",
        "Horizontal screen estate\n% of screen width used for the focus grid. (0-1)\n--------------------------------------------------",
        0,
        1,
        .1
    )
    S.obs_properties_add_float(
        props,
        "screen_estate_vertical",
        "Vertical screen estate\n% of screen height used for the focus grid. (0-1)\n--------------------------------------------------",
        0,
        1,
        .1
    )
    S.obs_properties_add_int(
        props,
        "locked_rows_before_rollover",
        "How many insts per row in the locked grid.\nFor example, 2 makes the locked layout:\n1x1,2x1,2x2,2x2,2x3,2x3,...\n--------------------------------------------------",
        1,
        4,
        1
    )
    return props

def script_update(settings):
    global wall_scene_name
    global instance_source_format
    global focus_rows
    global focus_cols
    global screen_estate_horizontal
    global screen_estate_vertical
    global locked_rows_before_rollover
    wall_scene_name = S.obs_data_get_string(settings, "scene")
    instance_source_format = S.obs_data_get_string(settings, "instance_source_format")
    focus_rows = S.obs_data_get_int(settings, "focus_rows")
    focus_cols = S.obs_data_get_int(settings, "focus_cols")
    screen_estate_horizontal = S.obs_data_get_double(settings, "screen_estate_horizontal")
    screen_estate_vertical = S.obs_data_get_double(settings, "screen_estate_vertical")
    locked_rows_before_rollover = S.obs_data_get_int(settings, "locked_rows_before_rollover")
    S.timer_remove(test)
    S.timer_add(test,  100)


