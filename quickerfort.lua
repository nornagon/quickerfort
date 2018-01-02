gui = require 'gui'
widgets = require 'gui.widgets'
guidm = require 'gui.dwarfmode'
utils = require 'utils'

local TYPES = {
    d = df.tile_dig_designation.Default,
    j = df.tile_dig_designation.DownStair,
    u = df.tile_dig_designation.UpStair,
    i = df.tile_dig_designation.UpDownStair,
    h = df.tile_dig_designation.Channel,
    r = df.tile_dig_designation.Ramp,
    x = df.tile_dig_designation.No,
}

function parseBlueprint(content)
    local layers = {[0] = {}, min = 0, max = 0}
    local layer = 0
    for line in string.gmatch(content.."\n", "([^\n]*)\n") do
        local tile_line = utils.split_string(line, "[,;]")
        for i=1,#tile_line do
            tile_line[i] = string.match(tile_line[i], "^%s*(.-)%s*$")
        end
        if string.match(tile_line[1], "^#") then
            if tile_line[1] == '#>' then
                layer = layer - 1
                if not layers[layer] then layers[layer] = {} end
                layers.min = math.min(layers.min, layer)
            elseif tile_line[1] == '#<' then
                layer = layer + 1
                if not layers[layer] then layers[layer] = {} end
                layers.max = math.max(layers.max, layer)
            end
        else
            if #tile_line > 0 then
                table.insert(layers[layer], tile_line)
            end
        end
    end
    return layers
end

-- reverses the elements of a list
function reversed(tbl)
    local reversed = {}
    local count = #tbl
    for k, v in ipairs(tbl) do
        reversed[count + 1 - k] = v
    end
    return reversed
end

-- transposes the elements of a list-of-lists
function transpose(tbl)
    -- TODO: this is broken sometimes and idk why
    local transposed = {}
    for y, line in ipairs(tbl) do
        for x, char in ipairs(line) do
            if not transposed[x] then transposed[x] = {} end
            transposed[x][y] = char
        end
    end
    return transposed
end

-- Shows a preview of what the blueprint will do
Preview = defclass(Preview, widgets.Widget)
Preview.ATTRS = {}
function Preview:init()
    self.data = ''
end
function Preview:onRenderBody(dc)
    if self.data then
        dc:clear()
        dc:fill(0,0, dc.width-1, dc.height-1, {ch=' ',bg=COLOR_GREEN})
        local layers = parseBlueprint(self.data)

        dc:pen(COLOR_WHITE)
        for z=layers.min,layers.max do
            for y, line in ipairs(layers[z]) do
                for x, char in ipairs(line) do
                    if TYPES[char] then
                        dc:seek(x,y):char(char)
                    end
                end
            end
            break -- TODO: preview layers other than the first, perhaps also show stats? e.g bounding box, # of digs, etc
        end
    end
end

-- List available blueprints, stored in <DF_ROOT>/blueprints
BlueprintList = defclass(BlueprintList, gui.FramedScreen)
BlueprintList.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = 'Blueprints',
    frame_width = 64,
    frame_height = 20,
    frame_inset = 1,
}

function BlueprintList:init()
    self:addviews{
        widgets.List{
            view_id = 'list',
            frame = {t = 0, l = 0},
            text_pen = COLOR_GREY,
            cursor_pen = COLOR_WHITE,
            choices = {},
            on_submit = self:callback('submit'),
            on_select = self:callback('select'),
        },
        Preview{
            view_id = 'preview',
            frame = {t = 0},
        },
        widgets.Label{
            view_id = 'controls',
            frame = {b = 0, l = 0},
            text = {
                {key = 'SELECT', text = ': Select, '},
                {key = 'LEAVESCREEN', text = ': Back', on_activate = self:callback('dismiss')},
            },
        },
        widgets.Label{
            view_id = 'scroll_up',
            frame = {t = 0, l = self.frame_width - 1},
            text = {{pen = COLOR_LIGHTCYAN, text=function()
                return self.subviews.list.page_top ~= 1 and string.char(24) or ''
            end}},
        },
        widgets.Label{
            view_id = 'scroll_down',
            frame = {t = 1, l = self.frame_width - 1},
            text = {{pen = COLOR_LIGHTCYAN, text=function()
                local list = self.subviews.list
                return list.page_top + list.page_size < #list:getChoices() and string.char(25) or ''
            end}},
        }
    }
    self:reread()
    self:refresh()

    self.subviews.list.frame.h = self.frame_height - self.subviews.controls.frame.h - 1
    self.subviews.scroll_down.frame.t = self.subviews.list.frame.h - 1
    self.subviews.preview.frame.l = self.frame_width / 2
    self.subviews.list.frame.w = self.frame_width / 2
end

function BlueprintList:reread()
    local root = dfhack.getDFPath() .. "/blueprints"
    local bps = {}
    for _,v in ipairs(dfhack.filesystem.listdir(root)) do
        local path = root .. "/" .. v
        if dfhack.filesystem.isfile(path) then
            local f = io.open(path, 'r')
            local contents = f:read('*all')
            f:close()
            table.insert(bps, {
                path = path,
                text = v,
                contents = contents,
            })
        end
    end
    self.blueprints = bps
end

function BlueprintList:refresh()
    self.subviews.list:setChoices(self.blueprints)
end

function BlueprintList:select(index, choice) -- called when moving the cursor through the list
    if choice then
        self.subviews.preview.data = choice.contents
    end
end

function BlueprintList:submit(_, choice)
    self:dismiss()
    Place{blueprint=choice}:show()
end

-- Map overlay for placing the blueprint in the world
Place = defclass(Place, guidm.MenuOverlay)
function Place:init(stuff)
    self.blueprint = stuff.blueprint
    self.parsed = parseBlueprint(self.blueprint.contents)
    self.saved_mode = df.global.ui.main.mode
end
function Place:onShow()
    df.global.ui.main.mode = df.ui_sidebar_mode.LookAround
end
function Place:onDestroy()
    df.global.ui.main.mode = self.saved_mode
end

function Place:onRenderBody(p)
    p:clear()

    p:seek(1, 1):string("Placing blueprint"):newline():newline(1)
    p:key_string('CUSTOM_H', 'Flip Horizontal'):newline(1)
    p:key_string('CUSTOM_V', 'Flip Vertical'):newline(1)
    p:key_string('CUSTOM_R', 'Rotate'):newline(1)
    p:newline():newline(1)
    p:key_string('CUSTOM_L', 'Lock cursor: ')
        :string(self.lockCursor and 'Yes' or 'No', self.lockCursor and COLOR_GREEN or COLOR_RED)
    p:newline():newline(1)
    p:key_string('SELECT', 'Stamp blueprint'):newline(1)
    p:key_string('LEAVESCREEN', 'Done'):newline(1)

    local mdc = gui.Painter.new(self.df_layout.map):map(true)
    local cursor = df.global.cursor
    local vp = self:getViewport()

    for z=self.parsed.min,self.parsed.max do
        for y, line in ipairs(self.parsed[z]) do
            for x, char in ipairs(line) do
                if TYPES[char] then
                    local pos = {x=cursor.x+x-1,y=cursor.y+y-1,z=cursor.z+z}
                    local stile = vp:tileToScreen(pos)
                    if stile.z == 0 then
                        mdc:seek(stile.x, stile.y):char(char, COLOR_LIGHTGREEN)
                    end
                end
            end
        end
    end
end

-- dig out type at position, logic copied from digcircle.
function dig(type, p)
    local b = dfhack.maps.getTileBlock(p)
    if b then
        local tt = b.tiletype[p.x%16][p.y%16]
        local material = df.tiletype.attrs[tt].material
        local des = b.designation[p.x%16][p.y%16]
        if material == df.tiletype_material.CONSTRUCTION and not des.hidden then
            return
        end
        local shape = df.tiletype.attrs[tt].shape
        if shape == df.tiletype_shape.EMPTY and not des.hidden then
            return
        end
        local tsb = df.tiletype_shape.attrs[shape].basic_shape
        local legal = des.hidden or (
            tsb == df.tiletype_shape_basic.Wall or
                (tsb == df.tiletype_shape_basic.Floor and
                    (type == df.tile_dig_designation.DownStair or type == df.tile_dig_designation.Channel) and
                    shape ~= df.tiletype_shape.BRANCH and
                    shape ~= df.tiletype_shape.TRUNK_BRANCH and
                    shape ~= df.tiletype_shape.TWIG) or
                (tsb == df.tiletype_shape_basic.Stair and type == df.tile_dig_designation.Channel)
        )
        if legal then
            b.designation[p.x%16][p.y%16].dig = type
            b.occupancy[p.x%16][p.y%16].dig_marked = false
            b.flags.designated = true
        end
    end
end

-- designate the blueprint
function Place:stamp()
    local cursor = df.global.cursor
    local x_blocks, y_blocks, z_layers = dfhack.maps.getSize()
    for z=self.parsed.min,self.parsed.max do
        for y, line in ipairs(self.parsed[z]) do
            for x, char in ipairs(line) do
                local p = {x=cursor.x+x-1, y=cursor.y+y-1, z=cursor.z+z}
                if p.x == 0 or p.x == x_blocks * 16 - 1 then break end
                if p.y == 0 or p.y == y_blocks * 16 - 1 then break end
                local type = TYPES[char]
                if type then dig(type, p) end
            end
        end
    end
end

function Place:flipHorizontal()
    for z=self.parsed.min,self.parsed.max do
        for y, line in ipairs(self.parsed[z]) do
            self.parsed[z][y] = reversed(line)
        end
    end
end

function Place:flipVertical()
    for z=self.parsed.min,self.parsed.max do
        self.parsed[z] = reversed(self.parsed[z])
    end
end

function Place:rotate()
    for z=self.parsed.min,self.parsed.max do
        self.parsed[z] = transpose(reversed(self.parsed[z]))
    end
end

function Place:onInput(keys)
    if keys.LEAVESCREEN then
        self:dismiss()
        
    --[[
    elseif keys.CUSTOM_D then
        local cursor = df.global.cursor
        local p = {x=cursor.x, y=cursor.y, z=cursor.z}
        local b = dfhack.maps.getTileBlock(p)
        local tt = b.tiletype[p.x%16][p.y%16]
        local shape = df.tiletype.attrs[tt].shape
        local material = df.tiletype.attrs[tt].material
        local ts = df.tiletype_shape[shape]
        local basic_shape = df.tiletype_shape.attrs[shape].basic_shape
        local tsb = df.tiletype_shape_basic[basic_shape] or '?'
        local tile = df.tiletype[tt]
        print("tiletype:"..tile.."("..tt..") shape: "..ts.."("..shape..") tsb: "..tsb)
        print("hidden: "..(b.designation[p.x%16][p.y%16].hidden and 'y' or 'n'))
        print("mat: "..df.tiletype_material[material])
    --]]
    elseif keys.SELECT then
        self:stamp()
    elseif keys.CUSTOM_H then
        self:flipHorizontal()
    elseif keys.CUSTOM_V then
        self:flipVertical()
    elseif keys.CUSTOM_R then
        self:rotate()
    elseif keys.CUSTOM_L then
        self.lockCursor = not self.lockCursor
    else
        if self.lockCursor then
            self:simulateViewScroll(keys, nil, true)
        else
            self:propagateMoveKeys(keys)
        end
    end
end

BlueprintList():show()