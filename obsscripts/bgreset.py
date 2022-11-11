from math import ceil, floor
import obspython as S
import os

# Configure
screen_width = 1920
screen_height = 1080

# Don't configure
focus_cols = 1
focus_rows = 5
background_wall_scene_name = ""
instance_source_format = ""
focused_count = focus_rows * focus_cols
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
        pos = S.vec2();
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

        test_scene = S.obs_get_scene_by_name(wall_scene_name)
        if not test_scene:
            print("Can't find scene")
            return

        basepath = os.path.dirname(os.path.realpath(__file__))
        basefilePath = os.path.abspath(os.path.realpath(os.path.join(basepath,'..','data','obs.txt')))

        path = os.path.dirname(os.path.realpath(__file__))
        filePath = os.path.abspath(os.path.realpath(os.path.join(path,'..','data','obsbg.txt')))
        currentTime = os.path.getmtime(filePath)
        
        if currentTime == lastUpdate :
            return
        if not os.path.exists(filePath):
            print("Can't find resetcursor.txt")
            return
       
        lastUpdate = currentTime
        with open(filePath) as f:
            with open(basefilePath) as bf:
                raw_instances_string = f.readlines()[0]
                base_instances_string = bf.readlines()[0]
                base_instances = parse_instances_string(base_instances_string)
                instances = parse_instances_string(raw_instances_string)
                for i in range(len(base_instances)):
                    scene_item = S.obs_scene_find_source(test_scene, instance_source_format.replace("*",base_instances[i].suffix))
                    S.obs_sceneitem_set_visible(scene_item,False)

                for i in range(len(instances)):
                    scene_item = S.obs_scene_find_source(test_scene, instance_source_format.replace("*",instances[i].suffix))

                    
                    row = floor(i%focus_rows)
                    
                    S.obs_sceneitem_set_visible(scene_item,True)
                    inst_width = screen_width
                    height_scaling = [.1,.2,.4,.2,.1]          
                    y = floor(sum(height_scaling[0:row]) * screen_height)
                    move_source(scene_item, (screen_width/2)-inst_width/2,y)
                    scale_source(scene_item,inst_width,floor(screen_height * height_scaling[row]))
                    

    except Exception as e:
        print(e)
        import traceback
        traceback.print_exc(e)
        return

def script_properties():  # ui
    props = S.obs_properties_create()
    p = S.obs_properties_add_list(
        props,
        "scene",
        "Background Reset Scene",
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
        "Instance Source Format.\nUse * for numbers.\nExample: RSG*",
        S.OBS_TEXT_DEFAULT
    )
    return props
def script_update(settings):
    global wall_scene_name
    global instance_source_format
    wall_scene_name = S.obs_data_get_string(settings, "scene")
    instance_source_format = S.obs_data_get_string(settings, "instance_source_format")
    S.timer_remove(test)
    S.timer_add(test,  100)


