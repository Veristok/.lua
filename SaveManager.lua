-- SaveManager.lua - АБСОЛЮТНО ПОЛНАЯ РАБОЧАЯ ВЕРСИЯ
local SaveManager = {}

-- Настройки
SaveManager.Folder = "UtopiaSettings"
SaveManager.SubFolder = "Configs"
SaveManager.Ignore = {}
SaveManager.Library = nil

-- ===== ОСНОВНЫЕ ФУНКЦИИ =====

function SaveManager:SetLibrary(lib)
    self.Library = lib
end

function SaveManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end

function SaveManager:SetSubFolder(folder)
    self.SubFolder = folder
    self:BuildFolderTree()
end

function SaveManager:SetIgnoreIndexes(list)
    for _, key in ipairs(list) do
        self.Ignore[key] = true
    end
end

function SaveManager:IgnoreThemeSettings()
    self:SetIgnoreIndexes({
        "Themes List", "Theme Name", "ThemesList",
        "ThemeBackground", "ThemeMain", "ThemeAccent",
        "ThemeText", "ThemeOutline"
    })
end

-- ===== РАБОТА С ПАПКАМИ =====

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

-- ===== СОХРАНЕНИЕ =====

function SaveManager:Save(name)
    if not name then return false, "no name" end
    self:BuildFolderTree()
    
    local data = { objects = {} }
    
    for flag, value in pairs(self.Library.Flags) do
        if self.Ignore[flag] then goto continue end
        
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
            -- ПРОВЕРЯЕМ KEYBIND (по наличию Key и Mode)
            if value.Key ~= nil and value.Mode ~= nil then
                obj.type = "Keybind"
                -- Сохраняем имя клавиши
                if type(value.Key) == "userdata" then
                    obj.key = tostring(value.Key):gsub("Enum.KeyCode.", "")
                else
                    obj.key = tostring(value.Key)
                end
                obj.mode = value.Mode
                print("🔵 СОХРАНЯЮ КЛАВИШУ:", flag, "=", obj.key, obj.mode)
            elseif value.HexValue ~= nil then
                obj.type = "ColorPicker"
                obj.value = value.HexValue
                obj.transparency = value.Alpha or 0
            else
                obj.type = "Dropdown"
                obj.value = value
            end
        end
        
        table.insert(data.objects, obj)
        ::continue::
    end
    
    local json = game:GetService("HttpService"):JSONEncode(data)
    writefile(string.format("%s/%s/%s.json", self.Folder, self.SubFolder, name), json)
    print("✅ КОНФИГ СОХРАНЕН:", name)
    return true
end

-- ===== ЗАГРУЗКА =====

function SaveManager:Load(name)
    if not name then return false, "no name" end
    
    local path = string.format("%s/%s/%s.json", self.Folder, self.SubFolder, name)
    if not isfile(path) then return false, "file not found" end
    
    local data = game:GetService("HttpService"):JSONDecode(readfile(path))
    print("📂 ЗАГРУЖАЮ КОНФИГ:", name)
    
    for _, obj in ipairs(data.objects) do
        if self.Ignore[obj.flag] then goto continue end
        
        local setFunc = self.Library.SetFlags[obj.flag]
        if not setFunc then 
            print("⚠️ НЕТ SetFlags ДЛЯ:", obj.flag)
            goto continue
        end
        
        -- Загружаем с защитой
        local success = pcall(function()
            if obj.type == "Toggle" or obj.type == "Slider" or obj.type == "Input" then
                setFunc(obj.value)
            elseif obj.type == "Dropdown" then
                setFunc(obj.value)
            elseif obj.type == "ColorPicker" then
                setFunc(obj.value, obj.transparency or 0)
            elseif obj.type == "Keybind" then
                print("🟢 ЗАГРУЖАЮ КЛАВИШУ:", obj.flag, obj.key, obj.mode)
                
                -- Пробуем получить Enum
                local keyEnum
                if obj.key then
                    keyEnum = Enum.KeyCode[obj.key]
                    if not keyEnum then
                        keyEnum = Enum.UserInputType[obj.key]
                    end
                end
                
                setFunc({ 
                    key = keyEnum or obj.key or Enum.KeyCode.Z, 
                    mode = obj.mode or "Toggle" 
                })
            end
        end)
        
        if not success then
            print("❌ ОШИБКА ЗАГРУЗКИ:", obj.flag)
        end
        ::continue::
    end
    
    print("✅ КОНФИГ ЗАГРУЖЕН:", name)
    return true
end

-- ===== УДАЛЕНИЕ =====

function SaveManager:Delete(name)
    if not name then return false, "no name" end
    local path = string.format("%s/%s/%s.json", self.Folder, self.SubFolder, name)
    if not isfile(path) then return false, "file not found" end
    delfile(path)
    print("🗑️ КОНФИГ УДАЛЕН:", name)
    return true
end

-- ===== СПИСОК КОНФИГОВ =====

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

-- ===== АВТОЗАГРУЗКА =====

function SaveManager:SaveAutoload(name)
    if not name then return false end
    self:BuildFolderTree()
    local path = string.format("%s/%s/autoload.txt", self.Folder, self.SubFolder)
    writefile(path, name)
    return true
end

function SaveManager:GetAutoload()
    local path = string.format("%s/%s/autoload.txt", self.Folder, self.SubFolder)
    if isfile(path) then
        return readfile(path)
    end
    return nil
end

function SaveManager:LoadAutoload()
    local name = self:GetAutoload()
    if name then
        return self:Load(name)
    end
    return false, "no autoload"
end

-- ===== GUI СЕКЦИЯ =====

function SaveManager:BuildConfigSection(section)
    assert(self.Library, "🛑 Сначала установи Library!")
    
    -- Поле для имени
    local nameInput = section:Textbox({
        Name = "Config name",
        Flag = "SM_ConfigName",
        Placeholder = "enter name..."
    })
    
    -- Кнопка создания
    section:Button({ Name = "💾 Create config", Callback = function()
        local name = self.Library.Flags.SM_ConfigName
        if not name or name == "" then
            self.Library:Notification("❌ Invalid name", 2, Color3.fromRGB(255,0,0))
            return
        end
        local success = self:Save(name)
        if success then
            self.Library:Notification("✅ Created: " .. name, 2, Color3.fromRGB(0,255,0))
            configListbox:Refresh(self:RefreshConfigList())
            if nameInput and nameInput.Set then
                nameInput:Set("")
            end
        end
    end })
    
    section:Label("──────────", "Center")
    
    -- LISTBOX для списка
    local configListbox = section:Listbox({
        Name = "Configs list",
        Flag = "SM_ConfigList",
        Items = self:RefreshConfigList() or {},
        Size = 120,
        Multi = false
    })
    
    -- Кнопка загрузки
    section:Button({ Name = "📂 Load config", Callback = function()
        local name = self.Library.Flags.SM_ConfigList
        if not name then
            self.Library:Notification("❌ Select config", 2, Color3.fromRGB(255,0,0))
            return
        end
        local success = self:Load(name)
        if success then
            self.Library:Notification("✅ Loaded: " .. name, 2, Color3.fromRGB(0,255,0))
        end
    end })
    
    -- Кнопка удаления
    section:Button({ Name = "🗑️ Delete config", Callback = function()
        local name = self.Library.Flags.SM_ConfigList
        if not name then
            self.Library:Notification("❌ Select config", 2, Color3.fromRGB(255,0,0))
            return
        end
        local success = self:Delete(name)
        if success then
            self.Library:Notification("✅ Deleted: " .. name, 2, Color3.fromRGB(0,255,0))
            configListbox:Refresh(self:RefreshConfigList())
        end
    end })
    
    -- Кнопка обновления
    section:Button({ Name = "🔄 Refresh list", Callback = function()
        configListbox:Refresh(self:RefreshConfigList())
    end })
    
    section:Label("──────────", "Center")
    
    -- Автозагрузка
    section:Button({ Name = "⭐ Set autoload", Callback = function()
        local name = self.Library.Flags.SM_ConfigList
        if not name then
            self.Library:Notification("❌ Select config", 2, Color3.fromRGB(255,0,0))
            return
        end
        self:SaveAutoload(name)
        self.Library:Notification("✅ Autoload: " .. name, 2, Color3.fromRGB(0,255,0))
    end })
    
    -- Информация
    local autoloadName = self:GetAutoload()
    section:Label("Current autoload: " .. (autoloadName or "none"), "Left")
    
    self:SetIgnoreIndexes({ "SM_ConfigName", "SM_ConfigList" })
end

-- Инициализация
SaveManager:BuildFolderTree()

return SaveManager
