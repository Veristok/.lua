-- SaveManager.lua - Адаптировано для Xd.lua
local SaveManager = {}

-- Настройки
SaveManager.Folder = "UtopiaSettings"
SaveManager.SubFolder = "Configs"
SaveManager.Ignore = {}
SaveManager.Library = nil

-- Функции для работы с папками
function SaveManager:BuildFolderTree()
    local paths = {
        self.Folder,
        self.Folder .. "/" .. self.SubFolder,
    }
    
    for _, path in ipairs(paths) do
        if not isfolder(path) then
            makefolder(path)
        end
    end
end

-- Сохранение конфига
function SaveManager:Save(name)
    if not name then return false, "no name" end
    self:BuildFolderTree()
    
    local data = { objects = {} }
    
    for flag, value in pairs(self.Library.Flags) do
        if self.Ignore[flag] then continue end
        
        local obj = { flag = flag }
        
        if type(value) == "boolean" then
            obj.type = "Toggle"
            obj.value = value
        elseif type(value) == "number" then
            obj.type = "Slider"
            obj.value = value
        elseif type(value) == "string" then
            obj.type = "Input"
            obj.value = value
        elseif type(value) == "table" then
            if value.Key then
                obj.type = "KeyPicker"
                obj.key = value.Key
                obj.mode = value.Mode
            elseif value.HexValue then
                obj.type = "ColorPicker"
                obj.value = value.HexValue
                obj.transparency = value.Alpha
            else
                obj.type = "Dropdown"
                obj.value = value
            end
        end
        
        table.insert(data.objects, obj)
    end
    
    local json = game:GetService("HttpService"):JSONEncode(data)
    writefile(string.format("%s/%s/%s.json", self.Folder, self.SubFolder, name), json)
    return true
end

-- Загрузка конфига
function SaveManager:Load(name)
    if not name then return false, "no name" end
    
    local path = string.format("%s/%s/%s.json", self.Folder, self.SubFolder, name)
    if not isfile(path) then return false, "file not found" end
    
    local data = game:GetService("HttpService"):JSONDecode(readfile(path))
    
    for _, obj in ipairs(data.objects) do
        if self.Ignore[obj.flag] then continue end
        
        local setFunc = self.Library.SetFlags[obj.flag]
        if not setFunc then continue end
        
        if obj.type == "Toggle" or obj.type == "Slider" or obj.type == "Input" then
            setFunc(obj.value)
        elseif obj.type == "Dropdown" then
            setFunc(obj.value)
        elseif obj.type == "ColorPicker" then
            setFunc(obj.value, obj.transparency or 0)
        elseif obj.type == "KeyPicker" then
            setFunc({ key = obj.key, mode = obj.mode })
        end
    end
    
    return true
end

-- Остальные функции (Delete, Refresh, Autoload) - добавить по желанию

function SaveManager:SetLibrary(lib)
    self.Library = lib
end

function SaveManager:IgnoreThemeSettings()
    self:SetIgnoreIndexes({
        "Themes List", "Theme Name", "ThemesList",
        "ThemeBackground", "ThemeMain", "ThemeAccent",
        "ThemeText", "ThemeOutline"
    })
end

function SaveManager:SetIgnoreIndexes(list)
    for _, key in ipairs(list) do
        self.Ignore[key] = true
    end
end

-- Создание GUI секции
function SaveManager:BuildConfigSection(section)
    assert(self.Library, "Set Library first!")
    
    -- Поле для имени конфига
    local nameInput = section:Textbox({
        Name = "Config name",
        Flag = "SM_ConfigName",
        Placeholder = "enter name..."
    })
    
    -- Кнопка создания
    section:Button({ Name = "Create config", Callback = function()
        local name = self.Library.Flags.SM_ConfigName
        if not name or name == "" then
            self.Library:Notification("Invalid name", 2, Color3.fromRGB(255,0,0))
            return
        end
        local success = self:Save(name)
        if success then
            self.Library:Notification("Created: " .. name, 2, Color3.fromRGB(0,255,0))
            configDropdown:Refresh(self:RefreshConfigList())
        end
    end })
    
    section:Label("──────────", "Center")
    
    -- Список конфигов
    local configDropdown = section:Dropdown({
        Name = "Config list",
        Flag = "SM_ConfigList",
        Items = self:RefreshConfigList() or {},
        MaxSize = 150
    })
    
    -- Кнопка загрузки
    section:Button({ Name = "Load config", Callback = function()
        local name = self.Library.Flags.SM_ConfigList
        if not name then
            self.Library:Notification("Select config", 2, Color3.fromRGB(255,0,0))
            return
        end
        local success = self:Load(name)
        if success then
            self.Library:Notification("Loaded: " .. name, 2, Color3.fromRGB(0,255,0))
        end
    end })
    
    -- Кнопка обновления списка
    section:Button({ Name = "Refresh list", Callback = function()
        configDropdown:Refresh(self:RefreshConfigList())
    end })
    
    self:SetIgnoreIndexes({ "SM_ConfigName", "SM_ConfigList" })
end

function SaveManager:RefreshConfigList()
    local files = listfiles(self.Folder .. "/" .. self.SubFolder)
    local list = {}
    for _, file in ipairs(files) do
        if file:match("%.json$") then
            local name = file:match("([^/\\]+)%.json$")
            if name then table.insert(list, name) end
        end
    end
    return list
end

-- Инициализация
SaveManager:BuildFolderTree()

return SaveManager
