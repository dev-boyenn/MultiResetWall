from math import ceil, floor
import obspython as S
import os
import re
import configparser

# Don't configure

focus_cols = 1
focus_rows = 1
screen_estate_horizontal = 1
screen_estate_vertical = 1
locked_rows_before_rollover = 1
wall_scene_name = ""
instance_source_format = ""
focused_count = focus_rows * focus_cols
prev_instances = []
prev_passive_count = 0
prev_locked_count = 0
lastUpdate = 0.0
update_interval = 50
freeze_percent = 70
hide_dirt_mode = "cover"
screen_width = 0
screen_height = 0
single_scene = False
locked_ready_count_source_name = ""
hide_when_playing_name = ""

class FileInstance():
    def __init__(self, suffix, locked, hidden, dirt, freeze, playing):
        self.suffix = suffix
        self.locked = locked
        self.hidden = hidden
        self.dirt = dirt
        self.freeze = freeze
        self.playing = playing

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
        if (pos.x == x and pos.y == y):
            return
        pos.x = x
        pos.y = y
        S.obs_sceneitem_set_pos(source, pos)


def scale_source(source, width, height):
    if source:
        bounds = S.vec2()
        bounds.x = width
        bounds.y = height
        S.obs_sceneitem_set_bounds(source, bounds)


def parse_instances_string(input: str) -> 'list[FileInstance]':
    raw_instances = input.split(",")

    return list(map(lambda inst: FileInstance(suffix= re.sub("L|D|H|F|P", "", inst).strip(), locked="L" in inst, hidden="H" in inst, dirt="D" in inst, freeze="F" in inst,playing="P" in inst), raw_instances))


def passive_instance_count(instances: 'list[FileInstance]'):
    return len(list(filter(lambda inst: inst.hidden, instances)))


def locked_instance_count(instances: 'list[FileInstance]'):
    return len(list(filter(lambda inst: inst.locked, instances)))


def test():
    global screen_width
    global screen_height
    global wall_scene_name
    if(screen_height == 0):
        scene = S.obs_get_scene_by_name(wall_scene_name)
        wall_scene = S.obs_scene_get_source(scene)

        screen_width = S.obs_source_get_width(wall_scene)
        screen_height = S.obs_source_get_height(wall_scene)
        S.obs_source_release(wall_scene)
        S.obs_scene_release(scene)
            
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
        S.obs_scene_release(test_scene)

        path = os.path.dirname(os.path.realpath(__file__))
        filePath = os.path.abspath(os.path.realpath(
            os.path.join(path, '..', 'data', 'obs.txt')))
        if not os.path.exists(filePath):
            print("Can't find obs.txt")
            return
        currentTime = os.path.getmtime(filePath)
        if currentTime == lastUpdate:
            return
        lastUpdate = currentTime

        with open(filePath) as f:
            lines = f.readlines()
            raw_instances_string = lines[0].strip()
            ready_count = lines[1]
            instances = parse_instances_string(raw_instances_string)
            print(raw_instances_string)
            print(ready_count)
            passive_count = passive_instance_count(instances)
            locked_count = locked_instance_count(instances)
            locked_cols = ceil(locked_count / locked_rows_before_rollover)
            in_play_mode = ("P" in raw_instances_string) and single_scene

            backupRow = 0
            lockedIndex = 0

            if not in_play_mode:
                for item in range(len(instances)):
                    if instances[item].hidden:
                        if passive_count == prev_passive_count and instances[item] == prev_instances[item]:
                            backupRow += 1
                            continue
                        test_scene = S.obs_get_scene_by_name(wall_scene_name)
                        scene_item = S.obs_scene_find_source_recursive(
                            test_scene, instance_source_format.replace("*", instances[item].suffix))
                        S.obs_scene_release(test_scene)
                        inst_height = screen_height / passive_count
                        move_source(scene_item, screen_width *
                                    screen_estate_horizontal, backupRow * inst_height)
                        scale_source(scene_item, screen_width *
                                    (1-screen_estate_horizontal), inst_height)
                        backupRow += 1
                        continue
                    if instances[item].locked:
                        if locked_count == prev_locked_count and instances[item] == prev_instances[item]:
                            lockedIndex += 1
                            continue
                        test_scene = S.obs_get_scene_by_name(wall_scene_name)
                        scene_item = S.obs_scene_find_source_recursive(
                            test_scene, instance_source_format.replace("*", instances[item].suffix))
                        S.obs_scene_release(test_scene)

                        inst_width = (
                            screen_width*screen_estate_horizontal) / locked_cols
                        inst_height = (screen_height * (1-screen_estate_vertical)) / \
                            min(locked_count, locked_rows_before_rollover)
                        move_source(scene_item, (inst_width * floor(lockedIndex / locked_rows_before_rollover)),
                                    screen_height * screen_estate_vertical + inst_height * (lockedIndex % locked_rows_before_rollover))
                        scale_source(scene_item, inst_width, inst_height)
                        lockedIndex += 1
                        continue
                    row = floor(item/focus_cols)
                    col = floor(item % focus_cols)

                    test_scene = S.obs_get_scene_by_name(wall_scene_name)
                    scene_item = S.obs_scene_find_source_recursive(
                        test_scene, instance_source_format.replace("*", instances[item].suffix))
                    S.obs_scene_release(test_scene)
                    move_source(scene_item, col*(screen_width*screen_estate_horizontal /
                                focus_cols), row*(screen_height*screen_estate_vertical/focus_rows))
                    scale_source(scene_item, screen_width*screen_estate_horizontal /
                                focus_cols, screen_height*screen_estate_vertical/focus_rows)

            for item in range(len(instances)):
                test_scene = S.obs_get_scene_by_name(wall_scene_name)
                scene_item = S.obs_scene_find_source_recursive(test_scene, instance_source_format.replace("*", instances[item].suffix))
                S.obs_scene_release(test_scene)

                if in_play_mode or  (instances[item].dirt and hide_dirt_mode == "hide"):
                    move_source(scene_item, screen_width, 0)
                if hide_dirt_mode == "cover":
                    pos = S.vec2()
                    scale = S.vec2()
                    S.obs_sceneitem_get_pos(scene_item, pos)
                    S.obs_sceneitem_get_bounds(scene_item, scale)
                    test_scene = S.obs_get_scene_by_name(wall_scene_name)
                    dirt_item = S.obs_scene_find_source_recursive(test_scene, "Dirt " + instances[item].suffix)
                    S.obs_scene_release(test_scene)
                    move_source(dirt_item, pos.x, pos.y)
                    S.obs_sceneitem_set_bounds_type(dirt_item,1)
                    S.obs_sceneitem_set_bounds(dirt_item,scale)
                    S.obs_sceneitem_set_visible(dirt_item,instances[item].dirt and (not in_play_mode))
                if (freeze_percent > 0):
                    item_source = S.obs_sceneitem_get_source(scene_item)
                    filter = S.obs_source_get_filter_by_name(item_source, "Freeze filter")
                
                    if (instances[item].freeze):
                        S.obs_source_set_enabled(filter, True)
                    else:
                        S.obs_source_set_enabled(filter, False)
                    S.obs_source_release(filter)
                if instances[item].playing and in_play_mode:
                    test_scene = S.obs_get_scene_by_name(wall_scene_name)
                    scene_item = S.obs_scene_find_source_recursive(test_scene, instance_source_format.replace("*", instances[item].suffix))
                    S.obs_scene_release(test_scene)
                    move_source(scene_item, 0, 0)
                    scale_source(scene_item, screen_width, screen_height)
                    if hide_dirt_mode == "cover":
                        test_scene = S.obs_get_scene_by_name(wall_scene_name)
                        dirt_item = S.obs_scene_find_source_recursive(test_scene, "Dirt " + instances[item].suffix)
                        S.obs_scene_release(test_scene)
                        S.obs_sceneitem_set_visible(dirt_item,False)

                    if freeze_percent>0:
                        filter = S.obs_source_get_filter_by_name(S.obs_sceneitem_get_source(scene_item), "Freeze filter")
                        
                        S.obs_source_set_enabled(filter, False)
                        S.obs_source_release(filter)


            prev_instances = instances
            prev_passive_count = passive_count
            prev_locked_count = locked_count

            if locked_ready_count_source_name:
                wall_scene = S.obs_get_scene_by_name(wall_scene_name)
                text_source = S.obs_sceneitem_get_source(S.obs_scene_find_source_recursive(wall_scene, locked_ready_count_source_name))
                S.obs_scene_release(wall_scene)
                textdata = S.obs_data_create()
                S.obs_data_set_string(textdata, "text", ready_count)
                S.obs_source_update(text_source,textdata)
                S.obs_data_release(textdata)
            if hide_when_playing_name:
                wall_scene = S.obs_get_scene_by_name(wall_scene_name)
                scene_item = S.obs_scene_find_source_recursive(wall_scene, hide_when_playing_name)
                S.obs_scene_release(wall_scene)
                S.obs_sceneitem_set_visible(scene_item, not in_play_mode)
                
    except Exception as e:
        print(e)
        return


def create_group(props, desc):
    group = S.obs_properties_create()
    groupprop = S.obs_properties_add_group(
        props, desc, desc, S.OBS_GROUP_NORMAL, group)
    S.obs_property_set_long_description(groupprop, "aaaa")
    return group


def script_properties():  # ui
    props = S.obs_properties_create()
    p = S.obs_properties_add_list(
        props,
        "scene",
        "Wall Scene",
        S.OBS_COMBO_TYPE_EDITABLE,
        S.OBS_COMBO_FORMAT_STRING,
    )

    scenes = S.obs_frontend_get_scenes()
    for scene in scenes:
        name = S.obs_source_get_name(scene)
        S.obs_property_list_add_string(p, name, name)
    S.source_list_release(scenes)

    S.obs_property_set_long_description(
        S.obs_properties_add_text(
            props,
            "instance_source_format",
            "Instance Source Format",
            S.OBS_TEXT_DEFAULT
        ),
        "Instance Source Format\nThe names of the captures in your Wall scene.\nUse * for numbers\nExample: main mc *",
    )

    S.obs_properties_add_int(
        create_group(props, "Number of rows ( Vertical ) in the focus grid."),
        "focus_rows",
        "Focus Grid Rows",
        0,
        4,
        1
    )
    S.obs_properties_add_int(
        create_group(
            props, "Number of Columns ( Horizontal ) in the focus grid."),
        "focus_cols",
        "Focus Grid Cols",
        0,
        4,
        1
    )

    S.obs_properties_add_float(
        create_group(
            props, "Ratio of screen width used for the focus grid. (0-1)"),
        "screen_estate_horizontal",
        "Horizontal screen estate",
        0,
        1,
        .1
    )

    S.obs_properties_add_float(
        create_group(
            props, "Ratio of screen height used for the focus grid. (0-1)"),
        "screen_estate_vertical",
        "Vertical screen estate",
        0,
        1,
        .1
    )
    S.obs_properties_add_int(
        create_group(props, "How many insts per row in the locked grid."),
        "locked_rows_before_rollover",
        "Locked Rows Before Rollover",
        0,
        5,
        1
    )
    S.obs_properties_add_int(
        create_group(
            props, "Proactive moving speed ( Higher = slower, less lag )"),
        "update_interval",
        "Update Interval ( miliseconds )",
        10,
        2000,
        10
    )
    S.obs_properties_add_int(
        create_group(props, "Instance Preview Freezing ( 0 - 100 )"),
        "freeze_percent",
        "Freeze Percent ( 0 for disable )",
        0,
        100,
        5
    )

    p = S.obs_properties_add_list(
        create_group(
            props, "Hides loading screens to make things less jarring"),
        "hide_dirt_mode",
        "Hide Loading Screen Mode",
        S.OBS_COMBO_TYPE_EDITABLE,
        S.OBS_COMBO_FORMAT_STRING,
    )

    
    S.obs_property_list_add_string(p, "hide", "hide")
    S.obs_property_list_add_string(p, "none", "none")
    S.obs_property_list_add_string(p, "cover", "cover")

    S.obs_properties_add_bool(create_group(props, "Single scene ( Disable in bg scene or if you want transitions )"),"single_scene","Single Scene")
    
    wall_scene = S.obs_get_scene_by_name(wall_scene_name)
    scene_items = S.obs_scene_enum_items(wall_scene)
    S.obs_scene_release(wall_scene)
    p = S.obs_properties_add_list(
        create_group(props,"Text Source to display Ready Locked Instances Count"),
        "locked_ready_count_source_name",
        "Source",
        S.OBS_COMBO_TYPE_EDITABLE,
        S.OBS_COMBO_FORMAT_STRING,
    )
    hide_p = S.obs_properties_add_list(
        create_group(props,"Source ( or group ) to hide when playing ( Single Scene only )"),
        "hide_when_playing_name",
        "Source Or Group",
        S.OBS_COMBO_TYPE_EDITABLE,
        S.OBS_COMBO_FORMAT_STRING,
    )
    if scene_items is not None:
        for scene_item in scene_items:
            name = S.obs_source_get_name(
                S.obs_sceneitem_get_source(scene_item))
            S.obs_property_list_add_string(p, name, name)
            S.obs_property_list_add_string(hide_p, name, name)
            
    S.sceneitem_list_release(scene_items)
   
    return props

# too lazy to rename, actually does more
def create_dirt_covers():
    wall_scene = S.obs_get_scene_by_name(wall_scene_name)
    path = os.path.dirname(os.path.realpath(__file__))
    filePath = os.path.abspath(os.path.realpath(
        os.path.join(path, '..', 'media', 'dirt.png')))

    scene_items = S.obs_scene_enum_items(wall_scene)
    if scene_items is not None:
        for scene_item in scene_items:
            name = S.obs_source_get_name(
                S.obs_sceneitem_get_source(scene_item))
            if re.sub('\d+', '*', name) == instance_source_format:
                # Keeping this print so we can spot quicker if people mess up their instance source format
                print("Found instance " +
                      re.sub('[^0-9]', "", name) + " in capture \"" + name + "\"")

                settings = S.obs_data_create()

                if freeze_percent > 0:
                    filter = S.obs_source_create_private(
                        "freeze_filter", "Freeze filter", settings
                    )
                    S.obs_source_filter_remove(S.obs_sceneitem_get_source(scene_item), S.obs_source_get_filter_by_name(
                        S.obs_sceneitem_get_source(scene_item), "Freeze filter"))
                    S.obs_source_filter_add(
                        S.obs_sceneitem_get_source(scene_item), filter)

                S.obs_data_release(settings)

                # Found an instance source, looking for dirt cover now
                dirt_cover_name = "Dirt " + re.sub('[^0-9]', "", name)
                dirt_cover_source = S.obs_scene_find_source_recursive(wall_scene, dirt_cover_name)
                if dirt_cover_source:
                    # Dirt cover for this instance already exists
                    if hide_dirt_mode != "cover":
                        S.obs_sceneitem_remove(dirt_cover_source)
                    continue
                if hide_dirt_mode == "cover":
                    settings = S.obs_data_create()
                    S.obs_data_set_string(
                        settings, "file", filePath
                    )
                    source = S.obs_source_create(
                        "image_source", dirt_cover_name, settings, None)
                    S.obs_scene_add(wall_scene, source)
                    S.obs_data_release(settings)
    
    S.sceneitem_list_release(scene_items)
    S.obs_scene_release(wall_scene)

def script_update(settings):
    global wall_scene_name
    global instance_source_format
    global focus_rows
    global focus_cols
    global screen_estate_horizontal
    global screen_estate_vertical
    global locked_rows_before_rollover
    global screen_width
    global screen_height
    global update_interval
    global freeze_percent
    global prev_instances
    global prev_locked_count
    global prev_passive_count
    global lastUpdate
    global hide_dirt_mode
    global locked_ready_count_source_name
    global hide_when_playing_name
    global single_scene

    wall_scene_name = S.obs_data_get_string(settings, "scene")
    S.obs_data_set_string(settings, "scene", wall_scene_name)

    instance_source_format = S.obs_data_get_string(
        settings, "instance_source_format")
    S.obs_data_set_string(
        settings, "instance_source_format", instance_source_format)

    focus_rows = S.obs_data_get_int(settings, "focus_rows") or 2
    S.obs_data_set_int(settings, "focus_rows", focus_rows)

    focus_cols = S.obs_data_get_int(settings, "focus_cols") or 2
    S.obs_data_set_int(settings, "focus_cols", focus_cols)

    screen_estate_horizontal = S.obs_data_get_double(
        settings, "screen_estate_horizontal") or 0.5
    S.obs_data_set_double(settings, "screen_estate_horizontal",
                       screen_estate_horizontal)

    screen_estate_vertical = S.obs_data_get_double(
        settings, "screen_estate_vertical") or 0.5
    S.obs_data_set_double(settings, "screen_estate_vertical",
                       screen_estate_vertical)

    locked_rows_before_rollover = S.obs_data_get_int(
        settings, "locked_rows_before_rollover") or 2
    S.obs_data_set_int(settings, "locked_rows_before_rollover",
                       locked_rows_before_rollover)

    update_interval = S.obs_data_get_int(settings, "update_interval") or 30
    S.obs_data_set_int(settings, "update_interval",
                       update_interval)

    freeze_percent = S.obs_data_get_int(settings, "freeze_percent")
    S.obs_data_set_int(settings, "freeze_percent", freeze_percent)
    hide_dirt_mode = S.obs_data_get_string(settings, "hide_dirt_mode") or "cover"
    S.obs_data_set_string(settings, "hide_dirt_mode", hide_dirt_mode)
    single_scene = S.obs_data_get_bool(settings, "single_scene")

    locked_ready_count_source_name = S.obs_data_get_string(settings, "locked_ready_count_source_name") or ""
    S.obs_data_set_string(settings, "locked_ready_count_source_name", locked_ready_count_source_name)
    hide_when_playing_name = S.obs_data_get_string(settings, "hide_when_playing_name") or ""
    S.obs_data_set_string(settings, "hide_when_playing_name", hide_when_playing_name)

    
    prev_instances = []
    prev_passive_count = 0
    prev_locked_count = 0
    lastUpdate = 0


    create_dirt_covers()
    update_config_file()
    S.timer_remove(test)
    S.timer_add(test,  update_interval)

def update_config_file():
    config = configparser.ConfigParser()
    config['obs'] = {
        'rows': focus_rows,
        'cols': focus_cols,
        'screen_estate_horizontal': format(screen_estate_horizontal, '.2f'),
        'screen_estate_vertical': format(screen_estate_vertical, '.2f'),
        'locked_rows_before_rollover': locked_rows_before_rollover,
        'update_interval': update_interval,
        'freeze_percent': freeze_percent,
        'single_scene': single_scene

    }
    with open(os.path.abspath(os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'obssettings.ini'))), 'w') as configfile:
        config.write(configfile)
