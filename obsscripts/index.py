from math import ceil, floor
import obspython as S
import os

# Configure
focus_cols = 2
focus_rows = 2
screen_width = 1920
screen_height = 1080
screen_estate=.3

# Don't configure
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
        global prev_instances
        global prev_locked_count
        global prev_passive_count

        test_scene = S.obs_get_scene_by_name('Test Verification')
        if not test_scene:
            return

        filePath = "D:\speedrunning\\boyenn-wall\MultiResetWall\data\obs.txt"
        if not os.path.exists(filePath):
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
            locked_rows = ceil(locked_count / focus_cols)

            backupRow = 0
            lockedCol = 0
            for item in range(len(instances)):
                if instances[item].hidden:
                    if passive_count == prev_passive_count and instances[item] == prev_instances[item]:
                        backupRow+=1
                        continue
                    scene_item = S.obs_scene_find_source(test_scene, 'RSG'+instances[item].suffix)
                    inst_height = screen_height / passive_count
                    move_source(scene_item, screen_width*screen_estate,backupRow * inst_height )
                    scale_source(scene_item,screen_width*(1-screen_estate),inst_height)
                    backupRow+=1
                    continue
                if instances[item].locked:
                    if locked_count == prev_locked_count and instances[item] == prev_instances[item]:
                        lockedCol+=1
                        continue
                    scene_item = S.obs_scene_find_source(test_scene, 'RSG'+instances[item].suffix)

                    inst_width = (screen_width * screen_estate) / min(locked_count,focus_cols)
                    inst_height = (screen_height*(1-screen_estate)) / locked_rows
                    move_source(scene_item, inst_width * (lockedCol%focus_rows),screen_height * screen_estate + (inst_height * floor(lockedCol / focus_rows) ) )
                    scale_source(scene_item,inst_width, inst_height )
                    lockedCol+=1
                    continue
                row = floor(item/focus_rows)
                col = floor(item%focus_cols)

                scene_item = S.obs_scene_find_source(test_scene, 'RSG'+instances[item].suffix)
                move_source(scene_item, col*(screen_width*screen_estate/focus_cols),row*(screen_height*screen_estate/focus_rows))
                scale_source(scene_item,screen_width*screen_estate/focus_cols,screen_height*screen_estate/focus_rows)
            prev_instances = instances
            prev_passive_count = passive_count
            prev_locked_count = locked_count
    except Exception as e:
        print(e)
        return

def script_properties():  # ui
    props = S.obs_properties_create()
    S.obs_properties_add_button(props, "button", "Test", test)
    return props
def script_update(settings):
    S.timer_remove(test)
    S.timer_add(test,  100)


