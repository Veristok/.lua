-- SaveManager.lua - УПРОЩЕННАЯ ВЕРСИЯ
local SaveManager = {}

SaveManager.Folder = "UtopiaSettings"
SaveManager.SubFolder = "Configs"
SaveManager.Ignore = {}
SaveManager.Library = nil

function SaveManager:SetLibrary(lib) self.Library = lib end
function SaveManager:SetFolder(f) self.Folder = f; self:BuildFolderTree() end
function SaveManager:IgnoreThemeSettings() end

function SaveManager:BuildFolderTree()
    local paths = {self.Folder, self.Folder.."/"..self.SubFolder}
    for _, p in ipairs(paths) do if not isfolder(p) then makefolder(p) end end
end

function SaveManager:Save(name)
    if not name then return false end
    self:BuildFolderTree()
    local data = {objects={}}
    
    for flag, value in pairs(self.Library.Flags) do
        if self.Ignore[flag] then goto continue end
        
        local obj = {flag=flag}
        
        if type(value)=="boolean" then
            obj.type, obj.value = "Toggle", value
        elseif type(value)=="number" then
            obj.type, obj.value = "Slider", value
        elseif type(value)=="string" then
            obj.type, obj.value = "Input", value
        elseif type(value)=="table" then
            if value.Key then -- KeyBind
                obj.type = "Keybind"
                obj.key = tostring(value.Key)
                obj.mode = value.Mode or "Toggle"
                print("SAVING KEYBIND:", flag, "->", obj.key)
            elseif value.HexValue then
                obj.type, obj.value, obj.transparency = "ColorPicker", value.HexValue, value.Alpha or 0
            else
                obj.type, obj.value = "Dropdown", value
            end
        end
        
        table.insert(data.objects, obj)
        ::continue::
    end
    
    writefile(string.format("%s/%s/%s.json", self.Folder, self.SubFolder, name), 
              game:GetService("HttpService"):JSONEncode(data))
    return true
end

function SaveManager:Load(name)
    if not name then return false end
    local path = string.format("%s/%s/%s.json", self.Folder, self.SubFolder, name)
    if not isfile(path) then return false end
    
    local data = game:GetService("HttpService"):JSONDecode(readfile(path))
    
    for _, obj in ipairs(data.objects) do
        if self.Ignore[obj.flag] then goto continue end
        local set = self.Library.SetFlags[obj.flag]
        if not set then goto continue end
        
        if obj.type=="Toggle" or obj.type=="Slider" or obj.type=="Input" then
            set(obj.value)
        elseif obj.type=="Dropdown" then
            set(obj.value)
        elseif obj.type=="ColorPicker" then
            set(obj.value, obj.transparency or 0)
        elseif obj.type=="Keybind" then
            print("LOADING KEYBIND:", obj.flag, obj.key, obj.mode)
            local key = Enum.KeyCode[obj.key] or Enum.UserInputType[obj.key] or obj.key
            set({key=key, mode=obj.mode or "Toggle"})
        end
        ::continue::
    end
    return true
end

function SaveManager:RefreshConfigList()
    local files = listfiles(self.Folder.."/"..self.SubFolder)
    local list = {}
    for _, f in ipairs(files) do
        local name = f:match("([^/\\]+)%.json$")
        if name then table.insert(list, name) end
    end
    return list
end

function SaveManager:BuildConfigSection(section)
    assert(self.Library)
    
    local nameInput = section:Textbox({Name="Config name", Flag="SM_ConfigName", Placeholder="name..."})
    
    section:Button({Name="Create config", Callback=function()
        local name = self.Library.Flags.SM_ConfigName
        if not name or name=="" then
            self.Library:Notification("Invalid name", 2, Color3.fromRGB(255,0,0))
            return
        end
        if self:Save(name) then
            self.Library:Notification("Created: "..name, 2, Color3.fromRGB(0,255,0))
            listbox:Refresh(self:RefreshConfigList())
            if nameInput.Set then nameInput:Set("") end
        end
    end})
    
    section:Label("──────────", "Center")
    
    local listbox = section:Listbox({Name="Configs list", Flag="SM_ConfigList", 
                                     Items=self:RefreshConfigList() or {}, Size=120})
    
    section:Button({Name="Load config", Callback=function()
        local name = self.Library.Flags.SM_ConfigList
        if not name then
            self.Library:Notification("Select config", 2, Color3.fromRGB(255,0,0))
            return
        end
        if self:Load(name) then
            self.Library:Notification("Loaded: "..name, 2, Color3.fromRGB(0,255,0))
        end
    end})
    
    section:Button({Name="Refresh list", Callback=function()
        listbox:Refresh(self:RefreshConfigList())
    end})
    
    self:SetIgnoreIndexes({"SM_ConfigName", "SM_ConfigList"})
end

function SaveManager:SetIgnoreIndexes(list)
    for _, k in ipairs(list) do self.Ignore[k] = true end
end

SaveManager:BuildFolderTree()
return SaveManager
