local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local SUPPORTED_GAMES = {
    [3623096087] = "https://raw.githubusercontent.com/KING-STUDIO-OFFICIAL/SCRIPT-RAW/refs/heads/main/muscle-legends.lua",
    [3956818381] = "https://raw.githubusercontent.com/KING-STUDIO-OFFICIAL/SCRIPT-RAW/refs/heads/main/NINJA-LEGENDS.lua",
}

local function loadGameScript()
    local placeId = game.PlaceId
    local scriptUrl = SUPPORTED_GAMES[placeId]
    print("[Loader] Detected PlaceId:", placeId)

    if not scriptUrl then
        print("[Loader] ❌ Game NOT SUPPORTED")
        return
    end

    print("[Loader] ✅ Game SUPPORTED")
    print("[Loader] Script URL:", scriptUrl)

    local success, err = pcall(function()
        local scriptContent = game:HttpGet(scriptUrl)
        local scriptFunction = loadstring(scriptContent)

        if scriptFunction then
            scriptFunction()
        else
            error("loadstring returned nil – invalid script content")
        end
    end)

    if success then
        print("[Loader] ✅ SCRIPT LOADED SUCCESSFULLY")
    else
        warn("[Loader] ❌ FAILED TO LOAD: " .. tostring(err))
    end
end

loadGameScript()
