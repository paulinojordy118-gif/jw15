-- ============================================================================
-- JW DUPLICATOR HUB - DATASTORE SYNC & UI BINDING EDITION
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- LIMPIEZA DE INTERFACES ANTERIORES
pcall(function()
    if CoreGui:FindFirstChild("JW_TDHub") then CoreGui.JW_TDHub:Destroy() end
    if LocalPlayer.PlayerGui:FindFirstChild("JW_TDHub") then LocalPlayer.PlayerGui.JW_TDHub:Destroy() end
end)

-- ============================================================================
-- PARTE 1: LÓGICA DEL SERVIDOR (DATASTORE Y SINCRONIZACIÓN DE INVENTARIO)
-- ============================================================================
if RunService:IsServer() then
    local DataStoreService = game:GetService("DataStoreService")
    local TDDataStore = DataStoreService:GetDataStore("JW_CameramanTD_SaveSystem_v4")

    local function GenerarUUID()
        local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
        return string.gsub(template, "[xy]", function(c)
            local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
            return string.format("%x", v)
        end)
    end

    local function ObtenerDatosPorDefecto()
        return {
            Monedas = 1000,
            Unidades = {
                { UniqueID = GenerarUUID(), Name = "Large Cameraman", Level = 1 },
                { UniqueID = GenerarUUID(), Name = "Cameraman", Level = 1 }
            }
        }
    end

    local sesionesJugadores = {}

    Players.PlayerAdded:Connect(function(player)
        local userId = "Player_" .. player.UserId
        pcall(function()
            TDDataStore:UpdateAsync(userId, function(datosActuales)
                return datosActuales == nil and ObtenerDatosPorDefecto() or datosActuales
            end)
            local currentData = TDDataStore:GetAsync(userId)
            if currentData then
                sesionesJugadores[player] = currentData
                print("[JW SERVER] Datos cargados para: " .. player.Name)
            end
        end)
    end)

    -- Configuración de canales remotos
    local remotesFolder = ReplicatedStorage:FindFirstChild("JW_Remotes")
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "JW_Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end

    local tdFunction = remotesFolder:FindFirstChild("TD_ManagerFunction")
    if not tdFunction then
        tdFunction = Instance.new("RemoteFunction")
        tdFunction.Name = "TD_ManagerFunction"
        tdFunction.Parent = remotesFolder
    end

    local getInventoryFunc = remotesFolder:FindFirstChild("GetInventoryFunction")
    if not getInventoryFunc then
        getInventoryFunc = Instance.new("RemoteFunction")
        getInventoryFunc.Name = "GetInventoryFunction"
        getInventoryFunc.Parent = remotesFolder
    end

    -- Enviar la tabla real del DataStore al cliente cuando la solicite
    getInventoryFunc.OnServerInvoke = function(player)
        local datos = sesionesJugadores[player]
        if datos and datos.Unidades then
            return datos.Unidades
        end
        return {}
    end

    -- Manejar duplicación y guardado persistente
    tdFunction.OnServerInvoke = function(player, accion, targetUniqueID)
        local datosJugador = sesionesJugadores[player]
        if not datosJugador then return false, "Sesión no lista." end

        if accion == "DuplicarUnidad" then
            for _, u in ipairs(datosJugador.Unidades) do
                if u.UniqueID == targetUniqueID then
                    local clon = {
                        UniqueID = GenerarUUID(),
                        Name = u.Name,
                        Level = u.Level or 1,
                        EsDuplicado = true
                    }
                    table.insert(datosJugador.Unidades, clon)
                    pcall(function()
                        TDDataStore:SetAsync("Player_" .. player.UserId, datosJugador)
                    end)
                    return true, "¡Unidad duplicada y guardada en DataStore!"
                end
            end
        end
        return false, "Unidad no encontrada en el DataStore."
    end

    Players.PlayerRemoving:Connect(function(player)
        local userId = "Player_" .. player.UserId
        local datosJugador = sesionesJugadores[player]
        if datosJugador then
            pcall(function()
                TDDataStore:SetAsync(userId, datosJugador)
            end)
            sesionesJugadores[player] = nil
        end
    end)

-- ============================================================================
-- PARTE 2: LÓGICA DEL CLIENTE (INTERFAZ Y CARGA DESDE EL DATASTORE)
-- ============================================================================
elseif RunService:IsClient() then
    task.spawn(function()
        local parentGui = CoreGui
        local success, _ = pcall(function() return CoreGui.Name end)
        if not success then
            parentGui = LocalPlayer:WaitForChild("PlayerGui")
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "JW_TDHub"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.Parent = parentGui

        -- Botón flotante JW
        local JWBtn = Instance.new("TextButton")
        JWBtn.Name = "JWButton"
        JWBtn.Size = UDim2.new(0, 50, 0, 50)
        JWBtn.Position = UDim2.new(0.02, 0, 0.4, 0)
        JWBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        JWBtn.TextColor3 = Color3.fromRGB(0, 210, 255)
        JWBtn.Text = "JW"
        JWBtn.TextSize = 22
        JWBtn.Font = Enum.Font.SourceSansBold
        JWBtn.BorderSizePixel = 2
        JWBtn.BorderColor3 = Color3.fromRGB(0, 170, 255)
        JWBtn.Active = true
        JWBtn.Draggable = true
        JWBtn.Parent = ScreenGui

        -- Ventana Principal
        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 310, 0, 320)
        MainFrame.Position = UDim2.new(0.02, 60, 0.35, 0)
        MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        MainFrame.BorderSizePixel = 2
        MainFrame.BorderColor3 = Color3.fromRGB(0, 170, 255)
        MainFrame.Visible = false
        MainFrame.Parent = ScreenGui

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, 0, 0, 30)
        Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.Text = "CAMERAMAN TD - JW HUB"
        Title.TextSize = 13
        Title.Font = Enum.Font.SourceSansBold
        Title.Parent = MainFrame

        local ScrollList = Instance.new("ScrollingFrame")
        ScrollList.Size = UDim2.new(0.9, 0, 0.5, 0)
        ScrollList.Position = UDim2.new(0.05, 0, 0.15, 0)
        ScrollList.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        ScrollList.BorderColor3 = Color3.fromRGB(50, 50, 50)
        ScrollList.ScrollBarThickness = 6
        ScrollList.Parent = MainFrame

        local UIListLayout = Instance.new("UIListLayout")
        UIListLayout.Parent = ScrollList
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout.Padding = UDim.new(0, 4)

        local SelectedLabel = Instance.new("TextLabel")
        SelectedLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
        SelectedLabel.Position = UDim2.new(0.05, 0, 0.67, 0)
        SelectedLabel.BackgroundTransparency = 1
        SelectedLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        SelectedLabel.Text = "Selecciona una torre..."
        SelectedLabel.TextSize = 12
        SelectedLabel.Font = Enum.Font.SourceSans
        SelectedLabel.Parent = MainFrame

        local RefreshBtn = Instance.new("TextButton")
        RefreshBtn.Size = UDim2.new(0.42, 0, 0.12, 0)
        RefreshBtn.Position = UDim2.new(0.05, 0, 0.78, 0)
        RefreshBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        RefreshBtn.Text = "Actualizar"
        RefreshBtn.TextSize = 13
        RefreshBtn.Font = Enum.Font.SourceSansBold
        RefreshBtn.Parent = MainFrame

        local DupeBtn = Instance.new("TextButton")
        DupeBtn.Size = UDim2.new(0.42, 0, 0.12, 0)
        DupeBtn.Position = UDim2.new(0.53, 0, 0.78, 0)
        DupeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
        DupeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        DupeBtn.Text = "Duplicate JW"
        DupeBtn.TextSize = 13
        DupeBtn.Font = Enum.Font.SourceSansBold
        DupeBtn.Parent = MainFrame

        local unidadSeleccionADA = nil
        local idUnicoSeleccionado = nil

        -- Función que pide los datos directamente al DataStore del Servidor
        local function cargarInventarioDesdeServidor()
            local listaUnidades = {}
            pcall(function()
                local remotesFolder = ReplicatedStorage:WaitForChild("JW_Remotes", 5)
                local getInv = remotesFolder and remotesFolder:WaitForChild("GetInventoryFunction", 5)
                if getInv then
                    listaUnidades = getInv:InvokeServer()
                end
            end)
            return listaUnidades
        end

        local function cargarListaEnUI()
            for _, item in ipairs(ScrollList:GetChildren()) do
                if item:IsA("TextButton") then item:Destroy() end
            end

            local lista = cargarInventarioDesdeServidor()

            for _, unidad in ipairs(lista) do
                local btnUnidad = Instance.new("TextButton")
                btnUnidad.Size = UDim2.new(1, -6, 0, 30)
                btnUnidad.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                btnUnidad.TextColor3 = Color3.fromRGB(255, 255, 255)
                -- Muestra el nombre y si es clonado o su nivel
                btnUnidad.Text = unidad.Name .. (unidad.EsDuplicado and " [DUP]" or " (Nvl " .. tostring(unidad.Level or 1) .. ")")
                btnUnidad.TextSize = 13
                btnUnidad.Font = Enum.Font.SourceSansSemibold
                btnUnidad.Parent = ScrollList

                btnUnidad.MouseButton1Click:Connect(function()
                    unidadSeleccionADA = unidad.Name
                    idUnicoSeleccionado = unidad.UniqueID
                    SelectedLabel.Text = "Seleccionado: " .. unidad.Name
                    SelectedLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
                end)
            end
            ScrollList.CanvasSize = UDim2.new(0, 0, 0, #lista * 34)
        end

        JWBtn.MouseButton1Click:Connect(function()
            MainFrame.Visible = not MainFrame.Visible
            if MainFrame.Visible then cargarListaEnUI() end
        end)

        RefreshBtn.MouseButton1Click:Connect(function()
            cargarListaEnUI()
            SelectedLabel.Text = "¡Inventario sincronizado con DataStore!"
            SelectedLabel.TextColor3 = Color3.fromRGB(0, 210, 255)
        end)

        DupeBtn.MouseButton1Click:Connect(function()
            if not unidadSeleccionADA or not idUnicoSeleccionado then
                SelectedLabel.Text = "¡Selecciona una torre primero!"
                SelectedLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
                return
            end

            SelectedLabel.Text = "Guardando duplicado..."
            SelectedLabel.TextColor3 = Color3.fromRGB(255, 215, 0)

            local remotesFolder = ReplicatedStorage:FindFirstChild("JW_Remotes")
            local tdFunction = remotesFolder and remotesFolder:FindFirstChild("TD_ManagerFunction")

            if tdFunction then
                local success, exitoServer, msg = pcall(function()
                    return tdFunction:InvokeServer("DuplicarUnidad", idUnicoSeleccionado)
                end)
                if success and exitoServer then
                    SelectedLabel.Text = "¡" .. unidadSeleccionADA .. " duplicada con éxito!"
                    SelectedLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
                    cargarListaEnUI() -- Recarga la tabla con el nuevo elemento añadido al DataStore
                    return
                else
                    SelectedLabel.Text = msg or "Error al duplicar en servidor."
                    SelectedLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
                end
            else
                SelectedLabel.Text = "Error de conexión con el backend."
                SelectedLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
            end
        end)

        print("[JW HUB v4] Conectado al DataStore y listo.")
    end)
end
