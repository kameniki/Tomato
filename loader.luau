-- Rivals: 全コスメアンロック + エイムアシスト（統合版）
-- 注意：使用は自己責任です

local __a1b2c3 = setmetatable({}, { 
    __index = function(__d4e5f6, __g7h8i9) 
        local __j0k1l2, __m3n4o5 = pcall(function() 
            return game:GetService(__g7h8i9) 
        end) 
        if __m3n4o5 then 
            return cloneref(__m3n4o5) 
        end 
        return nil 
    end 
})

local __p6q7r8 = getgenv()
local _plrs = __a1b2c3.Players
local _rs = __a1b2c3.ReplicatedStorage
local _http = __a1b2c3.HttpService
local _run = __a1b2c3.RunService
local _ws = __a1b2c3.Workspace
local _lp = _plrs.LocalPlayer
local _pscripts = _lp.PlayerScripts
local _ctrl = _pscripts.Controllers
local _mods = _rs:WaitForChild("Modules", 10)

-- ========== パート1: コスメアンロック ==========
local _enumLib = require(_mods:WaitForChild("EnumLibrary", 10))
if _enumLib then pcall(function() _enumLib:WaitForEnumBuilder() end) end

local _cosLib = require(_mods:WaitForChild("CosmeticLibrary", 10))
local _itmLib = require(_mods:WaitForChild("ItemLibrary", 10))
local _datCtrl = require(_ctrl:WaitForChild("PlayerDataController", 10))

local _eq, _favs = {}, {}
local _buildingWep, _viewProf = nil, nil
local _lastWep = nil
local _fakeInv = {}
local _cfgFile = "rivals_unlocker_config.json"
local _saveLock = false

local function _mkCosmetic(nm, ctype, opts)
    local _base = _cosLib.Cosmetics[nm]
    if not _base then return nil end
    local _d = {}
    for k, v in pairs(_base) do _d[k] = v end
    _d.Name = nm
    _d.Type = _d.Type or ctype
    _d.Seed = _d.Seed or math.random(1, 1000000)
    if _enumLib then
        local _s, _eid = pcall(_enumLib.ToEnum, _enumLib, nm)
        if _s and _eid then
            _d.Enum = _eid
            _d.ObjectID = _d.ObjectID or _eid
        end
    end
    if opts then
        if opts.inverted ~= nil then _d.Inverted = opts.inverted end
        if opts.favoritesOnly ~= nil then _d.OnlyUseFavorites = opts.favoritesOnly end
    end
    return _d
end

local function _stripForSave()
    local _out = {}
    for wn, cos in pairs(_eq) do
        _out[wn] = {}
        for ct, cd in pairs(cos) do
            if cd and cd.Name then
                _out[wn][ct] = {
                    Name = cd.Name,
                    Inverted = cd.Inverted,
                    OnlyUseFavorites = cd.OnlyUseFavorites
                }
            end
        end
    end
    return { equipped = _out, favorites = _favs }
end

local function _loadCfg()
    if not isfile or not readfile then return end
    local _ok1, _ex = pcall(isfile, _cfgFile)
    if not _ok1 or not _ex then return end
    local _ok2, _raw = pcall(readfile, _cfgFile)
    if not _ok2 or not _raw or _raw == "" then return end
    local _ok3, _dec = pcall(_http.JSONDecode, _http, _raw)
    if not _ok3 or not _dec then return end
    if _dec.favorites then _favs = _dec.favorites end
    if _dec.equipped then
        _eq = {}
        for wn, cos in pairs(_dec.equipped) do
            _eq[wn] = {}
            for ct, sd in pairs(cos) do
                if sd and sd.Name then
                    if _cosLib.Cosmetics[sd.Name] then
                        local _cloned = _mkCosmetic(sd.Name, ct, {
                            inverted = sd.Inverted,
                            favoritesOnly = sd.OnlyUseFavorites
                        })
                        if _cloned then
                            _eq[wn][ct] = _cloned
                        end
                    end
                end
            end
            if not next(_eq[wn]) then _eq[wn] = nil end
        end
    end
end

local function _saveCfg()
    if not writefile or _saveLock then return end
    _saveLock = true
    task.spawn(function()
        task.wait(1)
        local _payload = _stripForSave()
        local _ok, _enc = pcall(_http.JSONEncode, _http, _payload)
        if _ok then pcall(writefile, _cfgFile, _enc) end
        _saveLock = false
    end)
end

_loadCfg()

local _cosTypes = {"Skin","Wrap","Charm","Dance","Emote"}
local function _isCosType(cosObj)
    if not cosObj then return false end
    for _, t in ipairs(_cosTypes) do
        if cosObj.Type == t then return true end
    end
    return false
end

-- コスメ所有権の書き換え
_cosLib.OwnsCosmeticNormally = function(self, inv, nm, wep)
    local c = _cosLib.Cosmetics[nm]
    if c and c.Type == "Skin" then return true end
    return false
end
_cosLib.OwnsCosmeticUniversally = function(self, inv, nm, wep)
    local c = _cosLib.Cosmetics[nm]
    if c and c.Type == "Skin" then return true end
    return false
end
_cosLib.OwnsCosmeticForWeapon = function(self, inv, nm, wep)
    local c = _cosLib.Cosmetics[nm]
    if c and c.Type == "Skin" then return true end
    return false
end

local _origOwns = _cosLib.OwnsCosmetic
_cosLib.OwnsCosmetic = function(self, inv, nm, wep)
    if nm:find("MISSING_") or nm == "Bubble Gun" then
        return _origOwns(self, inv, nm, wep)
    end
    local c = _cosLib.Cosmetics[nm]
    if c and _isCosType(c) then return true end
    return _origOwns(self, inv, nm, wep)
end

local _origGet = _datCtrl.Get
_datCtrl.Get = function(self, key)
    local _val = _origGet(self, key)
    if key == "CosmeticInventory" then
        local _prx = {}
        if _val then
            for k, v in pairs(_val) do
                local c = _cosLib.Cosmetics[k]
                if c and _isCosType(c) then _prx[k] = v end
            end
        end
        return setmetatable(_prx, {
            __index = function(t, k)
                local c = _cosLib.Cosmetics[k]
                if c and _isCosType(c) then return true end
                return nil
            end
        })
    end
    if key == "FavoritedCosmetics" then
        local _res = _val and table.clone(_val) or {}
        for wep, fv in pairs(_favs) do
            _res[wep] = _res[wep] or {}
            for nm, isFav in pairs(fv) do
                local c = _cosLib.Cosmetics[nm]
                if c and _isCosType(c) then
                    _res[wep][nm] = isFav
                end
            end
        end
        return _res
    end
    return _val
end

local _origGetWep = _datCtrl.GetWeaponData
_datCtrl.GetWeaponData = function(self, wn)
    local _d = _origGetWep(self, wn)
    if not _d then return nil end
    local _m = {}
    for k, v in pairs(_d) do _m[k] = v end
    _m.Name = wn
    if _eq[wn] then
        for ct, cd in pairs(_eq[wn]) do
            _m[ct] = cd
        end
    end
    return _m
end

local _fightCtrl
pcall(function() _fightCtrl = require(_ctrl:WaitForChild("FighterController", 10)) end)

if hookmetamethod then
    local _remotes = _rs:FindFirstChild("Remotes")
    local _dataRem = _remotes and _remotes:FindFirstChild("Data")
    local _equipRem = _dataRem and _dataRem:FindFirstChild("EquipCosmetic")
    local _favRem = _dataRem and _dataRem:FindFirstChild("FavoriteCosmetic")
    local _repRem = _remotes and _remotes:FindFirstChild("Replication")
    local _fightRem = _repRem and _repRem:FindFirstChild("Fighter")
    local _useItmRem = _fightRem and _fightRem:FindFirstChild("UseItem")

    if _equipRem then
        local _onc
        _onc = hookmetamethod(game, "__namecall", function(self, ...)
            if getnamecallmethod() ~= "FireServer" then
                return _onc(self, ...)
            end
            local _a = {...}

            if _useItmRem and self == _useItmRem then
                local _oid = _a[1]
                if _fightCtrl then
                    pcall(function()
                        local _f = _fightCtrl:GetFighter(_lp)
                        if _f and _f.Items then
                            for _, itm in pairs(_f.Items) do
                                if itm:Get("ObjectID") == _oid then
                                    _lastWep = itm.Name
                                    break
                                end
                            end
                        end
                    end)
                end
            end

            if self == _equipRem then
                local _wn = _a[1]
                local _ct = _a[2]
                local _cn = _a[3]
                local _opts = _a[4] or {}
                if _cn and _cn ~= "None" and _cn ~= "" then
                    local _inv = _datCtrl:Get("CosmeticInventory")
                    if _inv and rawget(_inv, _cn) then
                        return _onc(self, ...)
                    end
                end
                _eq[_wn] = _eq[_wn] or {}
                if not _cn or _cn == "None" or _cn == "" then
                    _eq[_wn][_ct] = nil
                    if not next(_eq[_wn]) then _eq[_wn] = nil end
                else
                    local _cloned = _mkCosmetic(_cn, _ct, {
                        inverted = _opts.IsInverted,
                        favoritesOnly = _opts.OnlyUseFavorites
                    })
                    if _cloned then _eq[_wn][_ct] = _cloned end
                end
                task.defer(function()
                    pcall(function() _datCtrl.CurrentData:Replicate("WeaponInventory") end)
                end)
                _saveCfg()
                return
            end

            if self == _favRem then
                local _cos = _cosLib.Cosmetics[_a[2]]
                if _cos then
                    _favs[_a[1]] = _favs[_a[1]] or {}
                    _favs[_a[1]][_a[2]] = _a[3] or nil
                    task.spawn(function()
                        pcall(function() _datCtrl.CurrentData:Replicate("FavoritedCosmetics") end)
                    end)
                    _saveCfg()
                end
                return
            end
            return _onc(self, ...)
        end)
    end
end

local _cliItem
pcall(function()
    _cliItem = require(_lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
end)

if _cliItem and _cliItem._CreateViewModel then
    local _origCVM = _cliItem._CreateViewModel
    _cliItem._CreateViewModel = function(self, vmRef)
        local _wn = self.Name
        local _wp = self.ClientFighter and self.ClientFighter.Player
        _buildingWep = (_wp == _lp) and _wn or nil
        if _wp == _lp and _eq[_wn] then
            local _dk = self:ToEnum("Data")
            if vmRef[_dk] then
                if _eq[_wn].Skin then
                    vmRef[_dk][self:ToEnum("Skin")] = _eq[_wn].Skin
                    vmRef[_dk][self:ToEnum("Name")] = _eq[_wn].Skin.Name
                end
                if _eq[_wn].Charm then vmRef[_dk][self:ToEnum("Charm")] = _eq[_wn].Charm end
                if _eq[_wn].Wrap then vmRef[_dk][self:ToEnum("Wrap")] = _eq[_wn].Wrap end
            elseif vmRef.Data then
                if _eq[_wn].Skin then vmRef.Data.Skin = _eq[_wn].Skin; vmRef.Data.Name = _eq[_wn].Skin.Name end
                if _eq[_wn].Charm then vmRef.Data.Charm = _eq[_wn].Charm end
                if _eq[_wn].Wrap then vmRef.Data.Wrap = _eq[_wn].Wrap end
            end
        end
        local _r = _origCVM(self, vmRef)
        _buildingWep = nil
        return _r
    end
end

local _vmMod = _lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
if _vmMod then
    local _CVM = require(_vmMod)
    local _origNew = _CVM.new
    _CVM.new = function(repData, cliItm)
        local _wp = cliItm.ClientFighter and cliItm.ClientFighter.Player
        local _wn = _buildingWep or cliItm.Name
        if _wp == _lp and _eq[_wn] then
            local _RC = require(_rs.Modules.ReplicatedClass)
            local _dk = _RC:ToEnum("Data")
            repData[_dk] = repData[_dk] or {}
            local _cos = _eq[_wn]
            if _cos.Skin then repData[_dk][_RC:ToEnum("Skin")] = _cos.Skin end
            if _cos.Charm then repData[_dk][_RC:ToEnum("Charm")] = _cos.Charm end
            if _cos.Wrap then repData[_dk][_RC:ToEnum("Wrap")] = _cos.Wrap end
        end
        return _origNew(repData, cliItm)
    end
end

print("[統合] コスメアンロック読み込み完了")

-- ========== パート2: エイムアシスト ==========
local __z2a3b4 = setmetatable({}, {
    __index = function(_, __c5d6e7)
        local __f8g9h0 = _lp.Character
        if not __f8g9h0 then return nil end
        if __c5d6e7 == "__root" then
            return __f8g9h0:FindFirstChild("HumanoidRootPart")
        elseif __c5d6e7 == "__head" then
            return __f8g9h0:FindFirstChild("Head")
        end
        return nil
    end
})

local __t6u7v8 = require(_pscripts.Modules.ItemTypes.Gun)
local __w9x0y1 = require(_rs.Modules.Utility)

__p6q7r8.__s9t0u1 = {}

do
    local __i1j2k3 = __p6q7r8.__s9t0u1

    function __i1j2k3:__init()
        self.__active = true
        self.__target = nil
        self.__desync = false
        self.__conn1 = nil
        self.__conn2 = nil
        self.__task1 = nil
        self.__oldfunc = nil
        self:__setup()
    end

    function __i1j2k3:__setup()
        self.__conn1 = _run.Heartbeat:Connect(function()
            if not self.__active then return end
            self.__target = self:__find()
        end)

        local __l4m5n6 = __t6u7v8.StartShooting
        self.__oldfunc = __l4m5n6
        __t6u7v8.StartShooting = function(__o7p8q9, ...)
            local __r0s1t2 = {__l4m5n6(__o7p8q9, ...)}
            if not __o7p8q9.ClientFighter or not __o7p8q9.ClientFighter.IsLocalPlayer then
                return unpack(__r0s1t2)
            end

            local __u3v4w5 = __r0s1t2[3]
            if not __u3v4w5 or typeof(__u3v4w5) ~= "table" then
                return unpack(__r0s1t2)
            end

            __r0s1t2[4] = true
            local __x6y7z8 = self.__target

            if not self.__active or not __x6y7z8 or not __x6y7z8.Character then
                return unpack(__r0s1t2)
            end

            if not self.__desync or self.__curr ~= __x6y7z8 then
                self:__desync_start(__x6y7z8)
                task.wait(0.1)
            end

            if self.__task1 then
                task.cancel(self.__task1)
                self.__task1 = nil
            end

            local __a9b0c1 = __x6y7z8.Character:FindFirstChild("Head")
            if not __a9b0c1 then return unpack(__r0s1t2) end

            local __d2e3f4 = __a9b0c1.Position
            local __g5h6i7 = __a9b0c1.CFrame
            local __j8k9l0 = __d2e3f4 - Vector3.new(0, 5, 0)
            local __m1n2o3 = CFrame.lookAt(__j8k9l0, __d2e3f4)
            local __p4q5r6 = __g5h6i7:ToObjectSpace(CFrame.new(__d2e3f4 + Vector3.new(math.random(), math.random(), math.random())))

            __u3v4w5[utf8.char(0)] = __w9x0y1:EncodeCFrame(CFrame.new(__j8k9l0, __d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
            __u3v4w5[utf8.char(1)] = __w9x0y1:EncodeCFrame(CFrame.new(__d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
            __u3v4w5[utf8.char(2)] = __a9b0c1
            __u3v4w5[utf8.char(3)] = __w9x0y1:EncodeCFrame(__p4q5r6)

            self.__task1 = task.delay(0.15, function()
                self:__desync_stop()
            end)

            return unpack(__r0s1t2)
        end
    end

    function __i1j2k3:__find()
        local myChar = _lp.Character
        if not myChar then return nil end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
       
        local closest = nil
        local closestDist = math.huge
        local MAX_DISTANCE = 200

        for _, player in next, _plrs:GetPlayers() do
            if player == _lp then continue end
            if player:GetAttribute("TeamID") == _lp:GetAttribute("TeamID") then continue end
           
            local char = player.Character
            if not char then continue end

            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            
            if not (root and head and hum and hum.Health > 0) then continue end
           
            local dist = (myRoot.Position - root.Position).Magnitude
            
            if dist > MAX_DISTANCE then continue end
            
            if dist < closestDist then
                closestDist = dist
                closest = player
            end
        end
        
        return closest
    end

    function __i1j2k3:__desync_start(__c3d4e5)
        if self.__conn2 then self.__conn2:Disconnect() end
        self.__desync = true
        self.__curr = __c3d4e5

        self.__conn2 = _run.Heartbeat:Connect(function()
            if not self.__desync then return end
            local __f6g7h8 = __z2a3b4.__root
            if not __f6g7h8 then return end

            local __i9j0k1 = __c3d4e5.Character and __c3d4e5.Character:FindFirstChild("HumanoidRootPart")
            if not __i9j0k1 then
                self:__desync_stop()
                return
            end

            local __l2m3n4 = __f6g7h8.CFrame
            local __o5p6q7 = __f6g7h8.Velocity
            local __r8s9t0 = __f6g7h8.RotVelocity

            __f6g7h8.CFrame = __i9j0k1.CFrame * CFrame.new(0, -5, 0)

            _run:BindToRenderStep("__restore", 101, function()
                __f6g7h8.CFrame = __l2m3n4
                __f6g7h8.Velocity = __o5p6q7
                __f6g7h8.RotVelocity = __r8s9t0
                _run:UnbindFromRenderStep("__restore")
            end)
        end)
    end

    function __i1j2k3:__desync_stop()
        self.__desync = false
        self.__curr = nil
        if self.__conn2 then
            self.__conn2:Disconnect()
            self.__conn2 = nil
        end
    end

    function __i1j2k3:Shutdown()
        self.__active = false
        if self.__conn1 then self.__conn1:Disconnect() end
        if self.__conn2 then self.__conn2:Disconnect() end
        if self.__task1 then task.cancel(self.__task1) end
        if self.__oldfunc then
            __t6u7v8.StartShooting = self.__oldfunc
        end
    end

    __i1j2k3:__init()
end
