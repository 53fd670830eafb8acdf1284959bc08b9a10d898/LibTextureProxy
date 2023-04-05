-- Addon
LibAnimatedTextures = {
    ['Name'] = "LibAnimatedTextures",
    ['Author'] = "voidbiscuit",
    ['Version'] = "1.0",
    ['VariableVersion'] = 1,
    ['APIVersion'] = "101034",
}
local LibAnimatedTextures = LibAnimatedTextures

LibAnimatedTextures.default_saved_variables = {
    settings = {
        -- General
        enabled = false,
        cooldown = 1,
        speed = 1,
        -- Debug
        debug_enabled = false,
    }
}
LibAnimatedTextures.saved_variables = {}

LibAnimatedTextures.values = {
    colour = {
        addon = "|cFFA500",
        default = "|r",
        error = "|cFF0000",
    },
}

-- Helper

local function filter(tbl, func)
    -- Out
    local list = {};
    -- Loop
    for i, v in ipairs(tbl) do
      if func(v) then
        table.insert(list, v)
      end
    end
    -- Return
    return list
end

-- Debug
function LibAnimatedTextures.Message(message, ...)
    if type(message) == type("") then
        -- Format
        message = string.format(message, ...)
        -- Print
        d(string.format(
            -- Msg format
            "%s[%s]%s %s",
            -- Vals
            LibAnimatedTextures.values.colour.addon, 
            LibAnimatedTextures.Name, 
            LibAnimatedTextures.values.colour.default, 
            message
        ))
    else
      d(message)
    end
end

function LibAnimatedTextures.Debug(message, ...)
    -- Check enabled
    if LibAnimatedTextures.saved_variables.settings.debug_enabled ~= true then return end
    -- Call
    LibAnimatedTextures.Message(message, ...)
end

-- Override

-- Objects

-- - Texture
local Texture = ZO_Object:Subclass()
LibAnimatedTextures.Texture = Texture

function Texture:New(data)
    -- Create
    local texture = ZO_Object.New(self)
    -- Attr
    texture.name = data.name
    texture.enabled = data.enabled
    texture.frames = data.frames
    texture.fps = data.fps
    texture.current_frame_index = data.current_frame_index
    -- Return
    return texture
end


function Texture:Create(data)
    -- Attrs
    data.name = data.name or "<Anonymous Emote>"
    data.enabled = data.enabled or true
    data.frames = data.frames or {}
    -- FPS
    data.fps = data.fps or 24 -- Between 15 and 24, apparently
    if (#data.frames == 2) then
        data.fps = 4
    end
    data.current_frame_index = data.current_frame_index or nil
    -- Make texture
    local texture = Texture:New(data)
    -- Register virtual texture
    RedirectTexture(texture.name, texture.name)
    -- Register real textures
    for frame_index, frame in ipairs(texture.frames) do
        RedirectTexture(frame, frame)
    end
    -- Set emote first frame
    texture:SetTexture(1)
    -- Return
    return texture
end

function Texture:SetTexture(frame_index)
    -- Check valid frame
    if not ((0 < frame_index) and (frame_index <= #self.frames)) then
        return
    end
    -- Return if same frame
    if self.current_frame_index == frame_index then return end
    -- Update frame index
    self.current_frame_index = frame_index
    -- Get frame
    local frame_path = self.frames[frame_index]
    -- Redirect texture
    RedirectTexture(self.name, self.name)
    RedirectTexture(self.name, frame_path)
    LibAnimatedTextures.Debug(string.format(" -> %s", frame_path))
end

function Texture:Update()
    -- Check enabled
    if self.enabled ~= true then
        return
    end
    -- Get raw frame time (1000 fps)
    local frame_time = GetFrameTimeMilliseconds() * LibAnimatedTextures.saved_variables.settings.speed
    -- Frame time modifier per texture
    frame_time = (frame_time * self.fps) / 1000
    frame_time = math.floor(frame_time)
    -- Find which frame to be on (time mod texture count)
    local frame_index = (frame_time % #self.frames) + 1
    -- Update texture
    self:SetTexture(frame_index)
    -- Debug
    if frame_time == 0 then
        LibAnimatedTextures.Debug("updated %s", self.name)
    end
end

function Texture:IsStatic()
    return (#self.frames <= 1)
end

function Texture:IsAnimated()
    return not (#self.frames <= 1)
end

-- - Texture Pack

local TexturePack = ZO_Object:Subclass()
LibAnimatedTextures.TexturePack = TexturePack

function TexturePack:New(data)
    -- Create
    local texture_pack = ZO_Object.New(self)
    -- Attr
    texture_pack.name = data.name
    texture_pack.enabled = data.enabled
    texture_pack.textures = data.textures
    -- Return
    return texture_pack
end

function TexturePack:Create(data)
    -- Attr
    data.name = data.name or "<Anonymous Texture Pack>"
    data.enabled = data.enabled or true
    data.textures = data.textures or {}
    -- Make texture pack
    local texture_pack = TexturePack:New(data)
    -- Return
    return texture_pack
end

function TexturePack:RegisterTexture(texture)
    -- Check not exist
    if not self.textures[texture.name] == nil then
        return
    end
    -- Save
    self.textures[texture.name] = texture
end

function TexturePack:DeregisterTexture(texture)
    -- Check does exist
    if self.textures[texture.name] == nil then
        return
    end
    -- Unset texture
    ZO_ClearTable(self.textures[texture.name] or {})
    -- Set nil
    self.textures[texture.name] = nil
end

function TexturePack:FromTextures(name, textures)
    -- Create
    local texture_pack = self:Create({name = name})
    -- Fill
    for texture_index, texture in ipairs(textures) do
        texture_pack:RegisterTexture(texture)
    end
    -- Return
    return texture_pack
end

function TexturePack:StaticTextures()
    local static_textures = filter(self.textures, function (texture) return texture:IsStatic() end)
    return static_textures
end

function TexturePack:AnimatedTextures()
    local animated_textures = filter(self.textures, function (texture) return texture:IsAnimated() end)
    return animated_textures
end

function TexturePack:AllTextures()
    local all_textures = filter(self.textures, function (texture) return true end)
    return all_textures
end


function TexturePack:Update()
    -- Check enabled
    if self.enabled ~= true then
        return
    end
    -- Update
    for texture_name, texture in pairs(self.textures) do
        texture:Update()
    end
end

-- Values

local texture_packs = {}
LibAnimatedTextures.texture_packs = texture_packs
local loop = nil
local expand_window = true

-- Functions

function LibAnimatedTextures.UpdateChatWindow()
    -- Resize, it's bad but it works.
    local current_width = CHAT_SYSTEM.control:GetWidth()
    if expand_window == true then
        CHAT_SYSTEM.control:SetWidth(current_width+1)
        expand_window = false
    else
        CHAT_SYSTEM.control:SetWidth(current_width-1)
        expand_window = true
    end
end

function LibAnimatedTextures.RegisterTexturePack(texture_pack)
    -- Check not exist
    if texture_packs[texture_pack.name] ~= nil then return end
    -- Set texture
    texture_packs[texture_pack.name] = texture_pack
end

function LibAnimatedTextures.DeregisterTexturePack(texture_pack)
    -- Check does exist
    if texture_packs[texture_pack.name] == nil then return end
    -- Unset texture
    ZO_ClearTable(texture_packs[texture_pack.name])
    texture_packs[texture_pack.name] = nil
end

function LibAnimatedTextures.GetRegisteredTexturePacks()
    LibAnimatedTextures.Message("Texture Packs")
    for k, v in pairs(texture_packs) do
        LibAnimatedTextures.Message("- %s", k)
    end
end

function LibAnimatedTextures.UpdateTexturePacks()
    -- Loop texturepacks
    for texture_pack_name, texture_pack in pairs(texture_packs) do
        texture_pack:Update()
    end
    -- Update chat window
    LibAnimatedTextures.UpdateChatWindow()
end

function LibAnimatedTextures.Loop()
    -- Check enabled
    if LibAnimatedTextures.saved_variables.settings.enabled ~= true then
        -- Kill loop
        loop = nil
        return
    end
    -- Run
    LibAnimatedTextures.UpdateTexturePacks()
    -- Loop
    zo_callLater(
        -- Recall
        function() LibAnimatedTextures.Loop() end,
        -- Cooldown
        LibAnimatedTextures.saved_variables.settings.cooldown
    )
end

function LibAnimatedTextures.StartLoop()
    -- Debug
    LibAnimatedTextures.Debug("Starting loop")
    -- Check loop not started
    if loop ~= nil then return end
    loop = true
    -- Start loop
    LibAnimatedTextures.Loop()
end


function LibAnimatedTextures.SetEnabled(value)
    -- Enable
    if value == true then
        -- Set enabled
        LibAnimatedTextures.saved_variables.settings.enabled = true
        -- Start loop
        LibAnimatedTextures.StartLoop()
    end
    -- Disable
    if value == false then
        -- Set disabled
        LibAnimatedTextures.saved_variables.settings.enabled = false
    end     
end

-- Addon Config

-- Saved vars
function LibAnimatedTextures.SavedVariables()
    -- Saved Variables
    LibAnimatedTextures.saved_variables = ZO_SavedVars:NewAccountWide(
        LibAnimatedTextures.Name .. "SavedVariables", 
        LibAnimatedTextures.VariableVersion, 
        nil, 
        LibAnimatedTextures.default_saved_variables, 
        GetWorldName()
    )
end

-- Menu
function LibAnimatedTextures.AddonMenu()
    -- Addon Menu
    local LAM = LibAddonMenu2
    local panel_name = LibAnimatedTextures.Name .. "SettingsPanel"
    local panel_data = {
        type = "panel",
        name = LibAnimatedTextures.Name,
        author = LibAnimatedTextures.Author
    }
    local panel = LAM:RegisterAddonPanel(panel_name, panel_data)
    local options_data = {
        -- # General
        {
            type = "header",
            name = "General",
        },
        {
            type = "checkbox",
            name = "Enabled",
            getFunc = function() return LibAnimatedTextures.saved_variables.settings.enabled end,
            setFunc = function(value) LibAnimatedTextures.SetEnabled(value) end,
            default = LibAnimatedTextures.default_saved_variables.settings.enabled,
        },
        {
            type = "slider",
            name = "Cooldown",
            getFunc = function() return LibAnimatedTextures.saved_variables.settings.cooldown end,
            setFunc = function(value) LibAnimatedTextures.saved_variables.settings.cooldown = value end,
            default = LibAnimatedTextures.default_saved_variables.settings.cooldown,
            min = 1,
            max = 1000,
            step = 1,
        },
        {
            type = "slider",
            name = "Speed",
            getFunc = function() return LibAnimatedTextures.saved_variables.settings.speed end,
            setFunc = function(value) LibAnimatedTextures.saved_variables.settings.speed = value end,
            default = LibAnimatedTextures.default_saved_variables.settings.speed,
            min = 0,
            max = 5,
            step = 0.01,
            decimals=2
        },
        {
            type = "header",
            name = "Debug",
        },
        {
            type = "checkbox",
            name = "Enabled",
            getFunc = function() return LibAnimatedTextures.saved_variables.settings.debug_enabled end,
            setFunc = function(value) LibAnimatedTextures.saved_variables.settings.debug_enabled = value end,
            default = LibAnimatedTextures.default_saved_variables.settings.debug_enabled,
        },
    }
    LAM:RegisterOptionControls(panel_name, options_data)
end

-- Addon Load
function LibAnimatedTextures.Initialize()
    -- Unregister
    EVENT_MANAGER:UnregisterForEvent(LibAnimatedTextures.Name, EVENT_ADD_ON_LOADED)
    -- Init
    LibAnimatedTextures.SavedVariables()
    LibAnimatedTextures.AddonMenu()
    -- Start loop
    LibAnimatedTextures.SetEnabled(LibAnimatedTextures.saved_variables.settings.enabled)
end

function LibAnimatedTextures.OnAddOnLoaded(event, addonName)
    if addonName == LibAnimatedTextures.Name then
        LibAnimatedTextures.Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(LibAnimatedTextures.Name, EVENT_ADD_ON_LOADED, LibAnimatedTextures.OnAddOnLoaded)
