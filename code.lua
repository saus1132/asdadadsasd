task.wait(3)    

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local placeId = 5094651510

local webhookUrl = "https://discord.com/api/webhooks/1229060337333047356/17FVxhJFQC1KTSxBd7m2FwZc7h6udWk9zz4qiV3ZBBoSkZITVnPMnOmRKO-N1uJRkoyB"

local positions = {
    Vector3.new(-2036.680419921875, 831.1228637695312, -3997.378173828125),
    Vector3.new(-3604.48681640625, 935.5105590820312, 1384.89306640625),
    Vector3.new(24.433820724487305, 730.15087890625, -209.9245147705078),
    Vector3.new(1757.43310546875, 1205.2265625, -1588.705078125),
    Vector3.new(-4530.0400390625, 906.32861328125, -2421.986572265625)
}

-- Send Discord notification
local function sendWebhook(message)
    pcall(function()
        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["content"] = message})
        })
    end)
end

-- Wait for loading screen
local function waitForLoading()
    local loadingGui = playerGui:FindFirstChild("LoadingScreen")
    if not loadingGui then return end
    
    local timeout = tick() + 45
    while loadingGui.Parent and tick() < timeout do
        task.wait(0.5)
    end
end

-- Get viable servers
local function getViableServers()
    local success, result = pcall(function()
        local response = request({
            Url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100",
            Method = "GET"
        })
        return response.Success and HttpService:JSONDecode(response.Body) or nil
    end)
    
    if not success or not result or not result.data then
        return {}
    end
    
    local viable = {}
    for _, server in ipairs(result.data) do
        if server.playing > 0 and server.playing < 50 and server.id ~= game.JobId then
            table.insert(viable, server.id)
        end
    end
    
    return viable
end

-- Point camera down
local function setCameraDown()
    local camera = workspace.CurrentCamera
    if camera then
        local pos = camera.CFrame.Position
        camera.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, -1, 0))
    end
end

-- Check and collect crystals on current server
local function checkAndCollect()
    local char = player.Character
    if not char then return false end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    
    -- Enable noclip
    local noclipConn = RunService.Heartbeat:Connect(function()
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
    
    -- Load all spawn areas
    for _, pos in ipairs(positions) do
        root.CFrame = CFrame.new(pos + Vector3.new(0, 50, 0))
        task.wait(1)
    end
    
    -- Find all crystals
    local crystals = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "Perfect Crystal" and obj:IsA("Model") then
            table.insert(crystals, obj)
        end
    end
    
    noclipConn:Disconnect()
    
    if #crystals == 0 then
        return false
    end
    
    -- Collect all crystals
    local collected = 0
    for _, crystal in ipairs(crystals) do
        local part = crystal:FindFirstChild("Part")
        local main = crystal:FindFirstChild("Main")
        
        if part then
            root.CFrame = CFrame.new(part.Position + Vector3.new(0, 5, 0))
            task.wait(1)
            
            setCameraDown()
            task.wait(0.3)
            
            -- Check Part for prompt
            local prompt = part:FindFirstChild("ProximityPrompt")
            if prompt then
                fireproximityprompt(prompt)
                collected = collected + 1
            end
            
            -- Check Main for prompt
            if main then
                prompt = main:FindFirstChild("ProximityPrompt")
                if prompt then
                    fireproximityprompt(prompt)
                    collected = collected + 1
                end
            end
            
            -- Press E as backup
            local VirtualInputManager = game:GetService("VirtualInputManager")
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            
            task.wait(0.5)
        end
    end
    
    -- Notify and wait for server to register
    sendWebhook(string.format("✅ Found %d crystal(s), collected %d | Server: %s | User: %s", 
        #crystals, collected, game.JobId, player.Name))
    
    task.wait(3)
    return true
end

-- Hop to next server with retries
local function hopToNextServer()
    local maxRetries = 5
    
    for attempt = 1, maxRetries do
        -- RE-QUEUE THIS SCRIPT BEFORE EVERY TELEPORT ATTEMPT
        pcall(function()
            queue_on_teleport('loadstring(game:HttpGet("https://pastebin.com/raw/AbDuVeUR"))()')
        end)
        
        local servers = getViableServers()
        
        -- Try specific server if available
        if #servers > 0 then
            local serverId = servers[math.random(1, #servers)]
            local success = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, serverId, player)
            end)
            if success then return true end
        end
        
        -- Fallback to random server
        local success = pcall(function()
            TeleportService:Teleport(placeId, player)
        end)
        if success then return true end
        
        -- Wait before retry (exponential backoff)
        if attempt < maxRetries then
            local delay = attempt * 2
            warn(string.format("Hop attempt %d/%d failed, retrying in %ds...", attempt, maxRetries, delay))
            task.wait(delay)
        end
    end
    
    sendWebhook("❌ All hop attempts failed | Server: " .. game.JobId .. " | User: " .. player.Name)
    return false
end

-- MAIN EXECUTION (runs once per server)
print("🔍 Crystal finder started - Server: " .. game.JobId)
print("🔍 Script run count:", (getgenv().RUN_COUNT or 0) + 1)
getgenv().RUN_COUNT = (getgenv().RUN_COUNT or 0) + 1

-- IMMEDIATELY queue for next teleport as soon as script starts
pcall(function()
    queue_on_teleport('loadstring(game:HttpGet("https://pastebin.com/raw/e26UkvKu"))()')
end)
print("✅ Queued script for next teleport")

-- Wait for character to load first
if not player.Character then
    player.CharacterAdded:Wait()
end

-- Wait for character to fully load
repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

print("⏳ Waiting for world to load...")
task.wait(5)  -- Give time for world to render

waitForLoading()
print("⏳ Loading screen done, waiting extra time...")
task.wait(3)  -- Extra buffer after loading screen

print("🔎 Starting crystal search...")
local success, foundCrystals = pcall(checkAndCollect)

if not success then
    sendWebhook("⚠️ Script error on server " .. game.JobId .. " | User: " .. player.Name)
    print("❌ Error:", foundCrystals)
end

print("🔄 Hopping to next server...")
task.wait(2)

-- Keep trying to hop until successful
while not hopToNextServer() do
    warn("Hop failed, retrying in 5s...")
    task.wait(5)
end
