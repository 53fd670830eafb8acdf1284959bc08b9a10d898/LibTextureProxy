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
        cooldown = 100,
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

function Texture:New(name, textures)
    -- Create
    local texture = ZO_Object.New(self)
    -- Attr
    texture.name = name or ""
    texture.textures = textures
    texture.fps = 24 -- Between 15 and 24, apparently
    texture.enabled = true
    texture.current_frame_index = nil
    -- Register textures (to fix the bug)
    RedirectTexture(texture.name, texture.name)
    for _, texture in ipairs(texture.textures) do
        RedirectTexture(texture, texture)
    end
    -- If it's just 1 frame, set it and disable this emote
    texture:SetTexture(1)
    if #texture.textures <= 1 then
        texture.enabled = false
    end
    -- Return
    return texture
end

function Texture:SetTexture(frame_index)
    -- Check valid frame
    if not (0 < frame_index and frame_index <= #self.textures) then
        return
    end
    -- Check if same frame
    if self.current_frame_index == frame_index then return end
    self.current_frame_index = frame_index
    -- Get frame
    local frame_path = self.textures[frame_index]
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
    LibAnimatedTextures.Debug("Texture %s %s", self.name, self.enabled and "enabled" or "disabled")
    -- Debug
    LibAnimatedTextures.Debug(string.format("Updating %s", self.name))
    -- Get raw frame time (1000 fps)
    local frame_time = GetFrameTimeMilliseconds()
    -- Frame time modifier per texture
    frame_time = (frame_time * self.fps) / 1000
    frame_time = math.floor(frame_time)
    -- Find which frame to be on (time mod texture count)
    local frame_index = (frame_time % #self.textures) + 1
    -- Update texture
    self:SetTexture(frame_index)
end

-- - Texture Pack

local TexturePack = ZO_Object:Subclass()
LibAnimatedTextures.TexturePack = TexturePack

function TexturePack:New(name, textures)
    -- Create
    local texture_pack = ZO_Object.New(self)
    -- Attr
    texture_pack.name = name
    texture_pack.enabled = true
    texture_pack.textures = textures or {}
    -- Return
    return texture_pack
end

function TexturePack:RegisterTexture(texture)
    -- Check not exist
    if self.textures[texture.name] ~= nil then
        return
    end
    -- Set texture
    self.textures[texture.name] = texture
end

function TexturePack:DeregisterTexture(texture)
    -- Check does exist
    if self.textures[texture.name] == nil then
        return
    end
    -- Unset texture
    ZO_ClearTable(self.textures[texture.name])
    self.textures[texture.name] = nil
end

function TexturePack:Update()
    -- Check enabled
    LibAnimatedTextures.Debug("Texture pack %s %s", self.name, self.enabled and "enabled" or "disabled")
    if self.enabled ~= true then
        return
    end
    -- Update
    LibAnimatedTextures.Debug("Updating %s", self.name)
    for texture_name, texture in pairs(self.textures) do
        texture:Update()
    end
    LibAnimatedTextures.Debug("Updated %s", self.name)
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

function LibAnimatedTextures.UpdateTexturePacks()
    LibAnimatedTextures.Debug("Updating texture packs")
    -- Loop texturepacks
    for texture_pack_name, texture_pack in pairs(texture_packs) do
        texture_pack:Update()
    end
    -- Update chat window
    LibAnimatedTextures.UpdateChatWindow()
end

function LibAnimatedTextures.Loop()
    LibAnimatedTextures.Debug("loop")
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
            max = 5000,
            step = 1,
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
