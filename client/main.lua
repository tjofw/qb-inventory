local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData = {}
local InventoryOpen = false

-- =========================================================
-- HAS ITEM
-- Compatibility export for QBCore / qb-radio / other resources
-- =========================================================

local function HasItem(items, amount)
    amount = tonumber(amount) or 1

    local inventory = PlayerData.items or {}

    -- Single item
    if type(items) == 'string' then
        local wanted = items:lower()

        for _, item in pairs(inventory) do
            if item
                and item.name
                and item.name:lower() == wanted
                and (tonumber(item.amount) or 0) >= amount
            then
                return true
            end
        end

        return false
    end

    -- Multiple items
    if type(items) == 'table' then
        for itemName, requiredAmount in pairs(items) do
            requiredAmount = tonumber(requiredAmount) or 1

            local found = false

            for _, item in pairs(inventory) do
                if item
                    and item.name
                    and item.name:lower() == tostring(itemName):lower()
                    and (tonumber(item.amount) or 0) >= requiredAmount
                then
                    found = true
                    break
                end
            end

            if not found then
                return false
            end
        end

        return true
    end

    return false
end

exports('HasItem', HasItem)

-- =========================================================
-- PLAYER DATA
-- =========================================================

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end

    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    PlayerData = data
end)

RegisterNetEvent('QBCore:Client:OnPlayerUpdated', function(key, value)
    if key == 'items' then
        PlayerData.items = value
    elseif key == 'all' then
        PlayerData = value
    end
end)

-- =========================================================
-- INVENTORY STATE
-- =========================================================

local function closeInventory()
    if not InventoryOpen then return end

    InventoryOpen = false

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'close'
    })

    TriggerServerEvent('qb-inventory:server:close')
end

local function requestOpen()
    if InventoryOpen then
        closeInventory()
        return
    end

    TriggerServerEvent('qb-inventory:server:open')
end

RegisterCommand('traves_inventory', function()
    requestOpen()
end, false)

RegisterKeyMapping(
    'traves_inventory',
    'Open Traves Inventory',
    'keyboard',
    'TAB'
)

-- =========================================================
-- SERVER -> CLIENT INVENTORY
-- =========================================================

RegisterNetEvent('qb-inventory:client:open', function(
    inventory,
    maxSlots,
    maxWeight,
    playerName,
    ground
)
    InventoryOpen = true

    PlayerData = QBCore.Functions.GetPlayerData()

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        inventory = inventory or {},
        maxSlots = maxSlots or 40,
        maxWeight = maxWeight or 120000,
        playerName = playerName or GetPlayerName(PlayerId()),
        ground = ground or {}
    })
end)

RegisterNetEvent('qb-inventory:client:update', function(inventory)
    PlayerData.items = inventory or {}

    SendNUIMessage({
        action = 'update',
        inventory = inventory or {}
    })
end)

RegisterNetEvent('qb-inventory:client:groundUpdate', function(drops)
    SendNUIMessage({
        action = 'groundUpdate',
        ground = drops or {}
    })
end)

RegisterNetEvent('qb-inventory:client:itemBox', function(item, action, amount)
    SendNUIMessage({
        action = 'itemBox',
        item = item,
        actionType = action,
        amount = amount or 1
    })
end)

RegisterNetEvent('qb-inventory:client:notify', function(message, notifyType)
    QBCore.Functions.Notify(
        message,
        notifyType or 'primary'
    )
end)

-- =========================================================
-- NUI CALLBACKS
-- =========================================================

RegisterNUICallback('CloseInventory', function(_, cb)
    closeInventory()
    cb('ok')
end)

RegisterNUICallback('MoveItem', function(data, cb)
    if not data then
        cb('ok')
        return
    end

    TriggerServerEvent(
        'qb-inventory:server:move',
        data.fromSlot,
        data.toSlot,
        data.amount
    )

    cb('ok')
end)

--RegisterNUICallback('UseItem', function(data, cb)
--    if not data or not data.item then
--        cb('ok')
--        return
--    end
--
--    TriggerServerEvent(
--        'qb-inventory:server:use',
--        data.item
--    )
--
--    cb('ok')
--end)
RegisterNUICallback('UseItem', function(data, cb)

    if not data or not data.item then
        cb(false)
        return
    end

    local slot =
        tonumber(data.item.slot)

    if not slot then
        cb(false)
        return
    end

    TriggerServerEvent(
        'qb-inventory:server:use',
        slot
    )

    cb('ok')
end)

RegisterNUICallback('GiveItem', function(data, cb)
    if not data or not data.item then
        cb('ok')
        return
    end

    TriggerServerEvent(
        'qb-inventory:server:give',
        data.item,
        data.amount
    )

    cb('ok')
end)

RegisterNUICallback('DropItem', function(data, cb)
    if not data or not data.item then
        cb('ok')
        return
    end

    TriggerServerEvent(
        'qb-inventory:server:drop',
        data.item.slot,
        data.amount
    )

    cb('ok')
end)

RegisterNUICallback('PickupGround', function(data, cb)
    if not data then
        cb('ok')
        return
    end

    TriggerServerEvent(
        'qb-inventory:server:pickupGround',
        data.dropId,
        data.sourceSlot,
        data.amount,
        data.toSlot
    )

    cb('ok')
end)

RegisterNUICallback('RequestGround', function(_, cb)
    TriggerServerEvent(
        'qb-inventory:server:requestGround'
    )

    cb('ok')
end)

-- =========================================================
-- HOTBAR
-- =========================================================

local function useHotbarSlot(slot)
    if not slot then return end

    slot = tonumber(slot)

    if not slot or slot < 1 or slot > 5 then
        return
    end

    TriggerServerEvent(
        'qb-inventory:server:useSlot',
        slot
    )
end

RegisterCommand('traves_slot_1', function()
    useHotbarSlot(1)
end, false)

RegisterCommand('traves_slot_2', function()
    useHotbarSlot(2)
end, false)

RegisterCommand('traves_slot_3', function()
    useHotbarSlot(3)
end, false)

RegisterCommand('traves_slot_4', function()
    useHotbarSlot(4)
end, false)

RegisterCommand('traves_slot_5', function()
    useHotbarSlot(5)
end, false)

RegisterKeyMapping(
    'traves_slot_1',
    'Traves Inventory Slot 1',
    'keyboard',
    '1'
)

RegisterKeyMapping(
    'traves_slot_2',
    'Traves Inventory Slot 2',
    'keyboard',
    '2'
)

RegisterKeyMapping(
    'traves_slot_3',
    'Traves Inventory Slot 3',
    'keyboard',
    '3'
)

RegisterKeyMapping(
    'traves_slot_4',
    'Traves Inventory Slot 4',
    'keyboard',
    '4'
)

RegisterKeyMapping(
    'traves_slot_5',
    'Traves Inventory Slot 5',
    'keyboard',
    '5'
)

-- =========================================================
-- GROUND REFRESH
-- =========================================================

CreateThread(function()
    while true do
        if InventoryOpen then
            TriggerServerEvent(
                'qb-inventory:server:requestGround'
            )

            Wait(2000)
        else
            Wait(1000)
        end
    end
end)

-- =========================================================
-- INVENTORY CONTROLS
-- =========================================================

CreateThread(function()
    while true do
        if InventoryOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)

            DisableControlAction(0, 37, true)

            DisableControlAction(0, 200, true)

            if IsControlJustReleased(0, 200) then
                closeInventory()
            end

            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- =========================================================
-- WEAPON DRAW / HOLSTER SYSTEM
-- PORTED FROM QB-WEAPONS
-- =========================================================

Config.WeapDraw = Config.WeapDraw or {
    variants = {
        130,
        122,
        3,
        6,
        8
    },

    weapons = {
        'WEAPON_PISTOL',
        'WEAPON_PISTOL_MK2',
        'WEAPON_COMBATPISTOL',
        'WEAPON_APPISTOL',
        'WEAPON_PISTOL50',
        'WEAPON_REVOLVER',
        'WEAPON_SNSPISTOL',
        'WEAPON_SNSPISTOL_MK2',
        'WEAPON_HEAVYPISTOL',
        'WEAPON_VINTAGEPISTOL',
        'WEAPON_MARKSMANPISTOL',
        'WEAPON_DOUBLEACTION',
        'WEAPON_CERAMICPISTOL',
        'WEAPON_NAVYREVOLVER',
        'WEAPON_GADGETPISTOL',
        'WEAPON_MICROSMG',
        'WEAPON_SMG',
        'WEAPON_SMG_MK2',
        'WEAPON_ASSAULTSMG',
        'WEAPON_COMBATPDW',
        'WEAPON_MACHINEPISTOL',
        'WEAPON_MINISMG',
        'WEAPON_PUMPSHOTGUN',
        'WEAPON_PUMPSHOTGUN_MK2',
        'WEAPON_SAWNOFFSHOTGUN',
        'WEAPON_ASSAULTSHOTGUN',
        'WEAPON_BULLPUPSHOTGUN',
        'WEAPON_MUSKET',
        'WEAPON_HEAVYSHOTGUN',
        'WEAPON_DBSHOTGUN',
        'WEAPON_AUTOSHOTGUN',
        'WEAPON_COMBATSHOTGUN',
        'WEAPON_ASSAULTRIFLE',
        'WEAPON_ASSAULTRIFLE_MK2',
        'WEAPON_CARBINERIFLE',
        'WEAPON_CARBINERIFLE_MK2',
        'WEAPON_ADVANCEDRIFLE',
        'WEAPON_SPECIALCARBINE',
        'WEAPON_SPECIALCARBINE_MK2',
        'WEAPON_BULLPUPRIFLE',
        'WEAPON_BULLPUPRIFLE_MK2',
        'WEAPON_COMPACTRIFLE',
        'WEAPON_MILITARYRIFLE',
        'WEAPON_HEAVYRIFLE',
        'WEAPON_TACTICALRIFLE',
        'WEAPON_MG',
        'WEAPON_COMBATMG',
        'WEAPON_COMBATMG_MK2',
        'WEAPON_GUSENBERG',
        'WEAPON_SNIPERRIFLE',
        'WEAPON_HEAVYSNIPER',
        'WEAPON_HEAVYSNIPER_MK2',
        'WEAPON_MARKSMANRIFLE',
        'WEAPON_MARKSMANRIFLE_MK2',
        'WEAPON_PRECISIONRIFLE',
        'WEAPON_RPG',
        'WEAPON_GRENADELAUNCHER',
        'WEAPON_GRENADELAUNCHER_SMOKE',
        'WEAPON_MINIGUN',
        'WEAPON_RAILGUN',
        'WEAPON_HOMINGLAUNCHER',
        'WEAPON_COMPACTLAUNCHER',
        'WEAPON_RAYMINIGUN',
        'WEAPON_RAYCARBINE'
    }
}

-- =========================================================
-- WEAPON STATE
-- =========================================================

local holstered = true
local canFire = true

local currWeap = `WEAPON_UNARMED`

local currHolster = nil
local currHolsterTexture = nil

local wearingHolster = nil

local weaponDrawing = false

-- =========================================================
-- ANIMATION DICTIONARY
-- =========================================================

local function loadAnimDict(dict)
    if not dict then return false end

    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)

        local timeout = GetGameTimer() + 5000

        while not HasAnimDictLoaded(dict) do
            Wait(10)

            if GetGameTimer() > timeout then
                return false
            end
        end
    end

    return true
end

-- =========================================================
-- WEAPON CHECK
-- =========================================================

local function checkWeapon(newWeap)
    for _, weapon in ipairs(Config.WeapDraw.weapons) do
        if newWeap == GetHashKey(weapon) then
            return true
        end
    end

    return false
end

-- =========================================================
-- HOLSTERABLE CHECK
-- =========================================================

local function isWeaponHolsterable(weap)
    if not Config.WeapDraw
        or not Config.WeapDraw.weapons then
        return false
    end

    for _, weapon in ipairs(Config.WeapDraw.weapons) do
        if GetHashKey(weapon) == weap then
            return true
        end
    end

    return false
end

-- =========================================================
-- INVENTORY WEAPON LOOKUP
-- =========================================================

local function FindInventoryWeapon(weaponHash)
    local data = QBCore.Functions.GetPlayerData()

    if not data or not data.items then
        return nil
    end

    for _, item in pairs(data.items) do
        if item and item.name then
            if item.type == 'weapon' then
                if GetHashKey(item.name) == weaponHash then
                    return item
                end
            end
        end
    end

    return nil
end

-- =========================================================
-- APPLY WEAPON AMMO
-- =========================================================

local function ApplyWeaponAmmo(ped, item, weaponHash)
    if not ped or not item then
        return
    end

    local info = item.info

    if type(info) ~= 'table' then
        return
    end

    if info.ammo ~= nil then
        local ammo = tonumber(info.ammo) or 0

        SetPedAmmo(
            ped,
            weaponHash,
            ammo
        )
    end
end

-- =========================================================
-- APPLY WEAPON ATTACHMENTS
-- =========================================================

local function ApplyWeaponAttachments(ped, weaponHash, item)
    if not item then return end

    local info = item.info

    if type(info) ~= 'table' then
        return
    end

    if type(info.attachments) ~= 'table' then
        return
    end

    for _, attachment in pairs(info.attachments) do
        if type(attachment) == 'table' then

            local component = attachment.component

            if component then
                component = tonumber(component)

                if component then
                    GiveWeaponComponentToPed(
                        ped,
                        weaponHash,
                        component
                    )
                end
            end
        end
    end
end

-- =========================================================
-- CEASE FIRE
-- =========================================================

local function CeaseFire(ped)
    if not ped then return end

    canFire = false

    DisablePlayerFiring(
        PlayerId(),
        true
    )

    SetPlayerCanDoDriveBy(
        PlayerId(),
        false
    )

    DisableControlAction(
        0,
        24,
        true
    )

    DisableControlAction(
        0,
        25,
        true
    )

    DisableControlAction(
        0,
        68,
        true
    )

    DisableControlAction(
        0,
        69,
        true
    )

    DisableControlAction(
        0,
        70,
        true
    )

    DisableControlAction(
        0,
        91,
        true
    )

    DisableControlAction(
        0,
        92,
        true
    )
end

-- =========================================================
-- RESET HOLSTER
-- =========================================================

RegisterNetEvent(
    'qb-inventory:client:ResetHolster',
    function()
        holstered = true
        currWeap = `WEAPON_UNARMED`
        currHolster = nil
        currHolsterTexture = nil
        wearingHolster = nil
        canFire = true
        weaponDrawing = false
    end
)

-- Compatibility with qb-weapons scripts
RegisterNetEvent(
    'qb-weapons:ResetHolster',
    function()
        holstered = true
        currWeap = `WEAPON_UNARMED`
        currHolster = nil
        currHolsterTexture = nil
        wearingHolster = nil
        canFire = true
        weaponDrawing = false
    end
)

-- =========================================================
-- DRAW WEAPON EVENT
-- =========================================================

RegisterNetEvent(
    'qb-inventory:client:DrawWeapon',
    function(item, shootable)
        if weaponDrawing then
            return
        end

        local ped = PlayerPedId()

        if not DoesEntityExist(ped) then
            return
        end

        if IsEntityDead(ped) then
            return
        end

        if not item or not item.name then
            return
        end

        local weaponHash = GetHashKey(
            string.upper(item.name)
        )

        if weaponHash == `WEAPON_UNARMED` then
            return
        end

        weaponDrawing = true

        if shootable == nil then
            shootable = true
        end

        -- =================================================
        -- HOLSTER VARIANT
        -- =================================================

        local holsterVariant =
            GetPedDrawableVariation(
                ped,
                8
            )

        wearingHolster = false

        for _, variant in ipairs(
            Config.WeapDraw.variants or {}
        ) do
            if holsterVariant == variant then
                wearingHolster = true
                break
            end
        end

        -- =================================================
        -- ALREADY HOLDING THIS WEAPON
        -- PUT IT AWAY
        -- =================================================

        if currWeap == weaponHash
            and not holstered then

            if wearingHolster then

                loadAnimDict(
                    'reaction@intimidation@cop@unarmed'
                )

                CeaseFire(ped)

                TaskPlayAnim(
                    ped,
                    'reaction@intimidation@cop@unarmed',
                    'intro',
                    8.0,
                    2.0,
                    500,
                    50,
                    0.0,
                    false,
                    false,
                    false
                )

                Wait(500)

                if currHolster then
                    SetPedComponentVariation(
                        ped,
                        7,
                        currHolster,
                        currHolsterTexture or 0,
                        0
                    )
                end

                SetCurrentPedWeapon(
                    ped,
                    `WEAPON_UNARMED`,
                    true
                )

                Wait(300)

                ClearPedTasks(ped)

                holstered = true
                canFire = true

            else

                loadAnimDict(
                    'reaction@intimidation@1h'
                )

                CeaseFire(ped)

                TaskPlayAnim(
                    ped,
                    'reaction@intimidation@1h',
                    'outro',
                    8.0,
                    2.0,
                    1400,
                    50,
                    0.0,
                    false,
                    false,
                    false
                )

                Wait(1400)

                SetCurrentPedWeapon(
                    ped,
                    `WEAPON_UNARMED`,
                    true
                )

                ClearPedTasks(ped)

                holstered = true
                canFire = true
            end

            weaponDrawing = false
            return
        end

        -- =================================================
        -- SWITCH FROM ANOTHER WEAPON
        -- =================================================

        if currWeap ~= `WEAPON_UNARMED`
            and currWeap ~= weaponHash then

            local oldWeapon = currWeap

            if wearingHolster then

                loadAnimDict(
                    'reaction@intimidation@cop@unarmed'
                )

                loadAnimDict(
                    'rcmjosh4'
                )

                CeaseFire(ped)

                -- Put current weapon away
                TaskPlayAnim(
                    ped,
                    'reaction@intimidation@cop@unarmed',
                    'intro',
                    8.0,
                    2.0,
                    500,
                    50,
                    0.0,
                    false,
                    false,
                    false
                )

                Wait(500)

                if currHolster then
                    SetPedComponentVariation(
                        ped,
                        7,
                        currHolster,
                        currHolsterTexture or 0,
                        0
                    )
                end

                SetCurrentPedWeapon(
                    ped,
                    `WEAPON_UNARMED`,
                    true
                )

                Wait(300)

                -- Capture current holster component
                currHolster =
                    GetPedDrawableVariation(
                        ped,
                        7
                    )

                currHolsterTexture =
                    GetPedTextureVariation(
                        ped,
                        7
                    )

                -- Draw new weapon
                TaskPlayAnimAdvanced(
                    ped,
                    'rcmjosh4',
                    'josh_leadout_cop2',
                    GetEntityCoords(ped),
                    0.0,
                    0.0,
                    GetEntityHeading(ped),
                    8.0,
                    2.0,
                    300,
                    48,
                    0.0,
                    0,
                    0
                )

                Wait(300)

                SetCurrentPedWeapon(
                    ped,
                    weaponHash,
                    true
                )

                -- Weapon holster clothing mappings
                if isWeaponHolsterable(weaponHash) then
                    if holsterVariant == 8 then
                        SetPedComponentVariation(
                            ped,
                            7,
                            2,
                            currHolsterTexture or 0,
                            0
                        )
                    elseif holsterVariant == 1 then
                        SetPedComponentVariation(
                            ped,
                            7,
                            3,
                            currHolsterTexture or 0,
                            0
                        )
                    elseif holsterVariant == 6 then
                        SetPedComponentVariation(
                            ped,
                            7,
                            5,
                            currHolsterTexture or 0,
                            0
                        )
                    end
                end

                Wait(500)

                ClearPedTasks(ped)

                currWeap = weaponHash
                holstered = false
                canFire = shootable

            else

                loadAnimDict(
                    'reaction@intimidation@1h'
                )

                CeaseFire(ped)

                TaskPlayAnim(
                    ped,
                    'reaction@intimidation@1h',
                    'outro',
                    8.0,
                    2.0,
                    1600,
                    50,
                    0.0,
                    false,
                    false,
                    false
                )

                Wait(1600)

                SetCurrentPedWeapon(
                    ped,
                    `WEAPON_UNARMED`,
                    true
                )

                Wait(200)

                TaskPlayAnim(
                    ped,
                    'reaction@intimidation@1h',
                    'intro',
                    8.0,
                    2.0,
                    1000,
                    50,
                    0.0,
                    false,
                    false,
                    false
                )

                Wait(1000)

                SetCurrentPedWeapon(
                    ped,
                    weaponHash,
                    true
                )

                Wait(1400)

                ClearPedTasks(ped)

                currWeap = weaponHash
                holstered = false
                canFire = shootable
            end

            ApplyWeaponAmmo(
                ped,
                item,
                weaponHash
            )

            ApplyWeaponAttachments(
                ped,
                weaponHash,
                item
            )

            weaponDrawing = false
            return
        end

        -- =================================================
        -- DRAW FROM NOTHING
        -- =================================================

        if wearingHolster then

            loadAnimDict(
                'rcmjosh4'
            )

            CeaseFire(ped)

            currHolster =
                GetPedDrawableVariation(
                    ped,
                    7
                )

            currHolsterTexture =
                GetPedTextureVariation(
                    ped,
                    7
                )

            TaskPlayAnimAdvanced(
                ped,
                'rcmjosh4',
                'josh_leadout_cop2',
                GetEntityCoords(ped),
                0.0,
                0.0,
                GetEntityHeading(ped),
                8.0,
                2.0,
                300,
                48,
                0.0,
                0,
                0
            )

            Wait(300)

            SetCurrentPedWeapon(
                ped,
                weaponHash,
                true
            )

            if isWeaponHolsterable(weaponHash) then
                if holsterVariant == 8 then
                    SetPedComponentVariation(
                        ped,
                        7,
                        2,
                        currHolsterTexture or 0,
                        0
                    )
                elseif holsterVariant == 1 then
                    SetPedComponentVariation(
                        ped,
                        7,
                        3,
                        currHolsterTexture or 0,
                        0
                    )
                elseif holsterVariant == 6 then
                    SetPedComponentVariation(
                        ped,
                        7,
                        5,
                        currHolsterTexture or 0,
                        0
                    )
                end
            end

            Wait(300)

            ClearPedTasks(ped)

            currWeap = weaponHash
            holstered = false
            canFire = shootable

        else

            loadAnimDict(
                'reaction@intimidation@1h'
            )

            CeaseFire(ped)

            TaskPlayAnim(
                ped,
                'reaction@intimidation@1h',
                'intro',
                8.0,
                2.0,
                1000,
                50,
                0.0,
                false,
                false,
                false
            )

            Wait(1000)

            SetCurrentPedWeapon(
                ped,
                weaponHash,
                true
            )

            Wait(1400)

            ClearPedTasks(ped)

            currWeap = weaponHash
            holstered = false
            canFire = shootable
        end

        ApplyWeaponAmmo(
            ped,
            item,
            weaponHash
        )

        ApplyWeaponAttachments(
            ped,
            weaponHash,
            item
        )

        weaponDrawing = false
    end
)

-- =========================================================
-- WEAPON MONITOR
-- =========================================================
--
-- This continuously watches the actual selected weapon.
-- This is important because GTA/FiveM can change the selected
-- weapon without the inventory being opened.
--
-- =========================================================

CreateThread(function()
    while true do

        local sleep = 500

        local ped = PlayerPedId()

        if DoesEntityExist(ped)
            and not IsEntityDead(ped)
            and not IsPedFalling(ped)
            and not IsPedInParachuteFreeFall(ped) then

            local selectedWeapon =
                GetSelectedPedWeapon(ped)

            -- =============================================
            -- WEAPON CHANGED
            -- =============================================

            if selectedWeapon ~= currWeap
                and not weaponDrawing then

                sleep = 0

                local oldWeapon = currWeap
                local newWeapon = selectedWeapon

                -- =========================================
                -- DRAWABLE WEAPON
                -- =========================================

                if checkWeapon(newWeapon) then

                    local item =
                        FindInventoryWeapon(newWeapon)

                    -- If this weapon was selected by GTA
                    -- rather than through Traves, still allow
                    -- the draw animation.
                    if not item then
                        item = {
                            name = string.lower(
                                GetWeaponDisplayNameFromHash(
                                    newWeapon
                                ) or ''
                            ),
                            type = 'weapon',
                            info = {}
                        }
                    end

                    if holstered then

                        local holsterVariant =
                            GetPedDrawableVariation(
                                ped,
                                8
                            )

                        local hasHolster = false

                        for _, variant in ipairs(
                            Config.WeapDraw.variants or {}
                        ) do
                            if holsterVariant == variant then
                                hasHolster = true
                                break
                            end
                        end

                        if hasHolster then

                            loadAnimDict(
                                'rcmjosh4'
                            )

                            CeaseFire(ped)

                            currHolster =
                                GetPedDrawableVariation(
                                    ped,
                                    7
                                )

                            currHolsterTexture =
                                GetPedTextureVariation(
                                    ped,
                                    7
                                )

                            -- Temporarily put weapon away
                            SetCurrentPedWeapon(
                                ped,
                                `WEAPON_UNARMED`,
                                true
                            )

                            TaskPlayAnimAdvanced(
                                ped,
                                'rcmjosh4',
                                'josh_leadout_cop2',
                                GetEntityCoords(ped),
                                0.0,
                                0.0,
                                GetEntityHeading(ped),
                                8.0,
                                2.0,
                                300,
                                48,
                                0.0,
                                0,
                                0
                            )

                            Wait(300)

                            SetCurrentPedWeapon(
                                ped,
                                newWeapon,
                                true
                            )

                            if isWeaponHolsterable(newWeapon) then
                                if holsterVariant == 8 then
                                    SetPedComponentVariation(
                                        ped,
                                        7,
                                        2,
                                        currHolsterTexture or 0,
                                        0
                                    )
                                elseif holsterVariant == 1 then
                                    SetPedComponentVariation(
                                        ped,
                                        7,
                                        3,
                                        currHolsterTexture or 0,
                                        0
                                    )
                                elseif holsterVariant == 6 then
                                    SetPedComponentVariation(
                                        ped,
                                        7,
                                        5,
                                        currHolsterTexture or 0,
                                        0
                                    )
                                end
                            end

                            Wait(300)

                            ClearPedTasks(ped)

                        else

                            loadAnimDict(
                                'reaction@intimidation@1h'
                            )

                            CeaseFire(ped)

                            SetCurrentPedWeapon(
                                ped,
                                `WEAPON_UNARMED`,
                                true
                            )

                            TaskPlayAnim(
                                ped,
                                'reaction@intimidation@1h',
                                'intro',
                                8.0,
                                2.0,
                                1000,
                                50,
                                0.0,
                                false,
                                false,
                                false
                            )

                            Wait(1000)

                            SetCurrentPedWeapon(
                                ped,
                                newWeapon,
                                true
                            )

                            Wait(1400)

                            ClearPedTasks(ped)
                        end

                        currWeap = newWeapon
                        holstered = false
                        canFire = true

                        if item then
                            ApplyWeaponAmmo(
                                ped,
                                item,
                                newWeapon
                            )

                            ApplyWeaponAttachments(
                                ped,
                                newWeapon,
                                item
                            )
                        end

                    -- =========================================
                    -- SWITCHING WEAPON
                    -- =========================================

                    elseif oldWeapon ~= `WEAPON_UNARMED` then

                        local holsterVariant =
                            GetPedDrawableVariation(
                                ped,
                                8
                            )

                        local hasHolster = false

                        for _, variant in ipairs(
                            Config.WeapDraw.variants or {}
                        ) do
                            if holsterVariant == variant then
                                hasHolster = true
                                break
                            end
                        end

                        CeaseFire(ped)

                        if hasHolster then

                            loadAnimDict(
                                'reaction@intimidation@cop@unarmed'
                            )

                            loadAnimDict(
                                'rcmjosh4'
                            )

                            TaskPlayAnim(
                                ped,
                                'reaction@intimidation@cop@unarmed',
                                'intro',
                                8.0,
                                2.0,
                                500,
                                50,
                                0.0,
                                false,
                                false,
                                false
                            )

                            Wait(500)

                            if currHolster then
                                SetPedComponentVariation(
                                    ped,
                                    7,
                                    currHolster,
                                    currHolsterTexture or 0,
                                    0
                                )
                            end

                            SetCurrentPedWeapon(
                                ped,
                                `WEAPON_UNARMED`,
                                true
                            )

                            Wait(300)

                            currHolster =
                                GetPedDrawableVariation(
                                    ped,
                                    7
                                )

                            currHolsterTexture =
                                GetPedTextureVariation(
                                    ped,
                                    7
                                )

                            TaskPlayAnimAdvanced(
                                ped,
                                'rcmjosh4',
                                'josh_leadout_cop2',
                                GetEntityCoords(ped),
                                0.0,
                                0.0,
                                GetEntityHeading(ped),
                                8.0,
                                2.0,
                                300,
                                48,
                                0.0,
                                0,
                                0
                            )

                            Wait(300)

                            SetCurrentPedWeapon(
                                ped,
                                newWeapon,
                                true
                            )

                            if isWeaponHolsterable(newWeapon) then
                                if holsterVariant == 8 then
                                    SetPedComponentVariation(
                                        ped,
                                        7,
                                        2,
                                        currHolsterTexture or 0,
                                        0
                                    )
                                elseif holsterVariant == 1 then
                                    SetPedComponentVariation(
                                        ped,
                                        7,
                                        3,
                                        currHolsterTexture or 0,
                                        0
                                    )
                                elseif holsterVariant == 6 then
                                    SetPedComponentVariation(
                                        ped,
                                        7,
                                        5,
                                        currHolsterTexture or 0,
                                        0
                                    )
                                end
                            end

                            Wait(500)

                            ClearPedTasks(ped)

                        else

                            loadAnimDict(
                                'reaction@intimidation@1h'
                            )

                            TaskPlayAnim(
                                ped,
                                'reaction@intimidation@1h',
                                'outro',
                                8.0,
                                2.0,
                                1600,
                                50,
                                0.0,
                                false,
                                false,
                                false
                            )

                            Wait(1600)

                            SetCurrentPedWeapon(
                                ped,
                                `WEAPON_UNARMED`,
                                true
                            )

                            Wait(200)

                            TaskPlayAnim(
                                ped,
                                'reaction@intimidation@1h',
                                'intro',
                                8.0,
                                2.0,
                                1000,
                                50,
                                0.0,
                                false,
                                false,
                                false
                            )

                            Wait(1000)

                            SetCurrentPedWeapon(
                                ped,
                                newWeapon,
                                true
                            )

                            Wait(1400)

                            ClearPedTasks(ped)
                        end

                        currWeap = newWeapon
                        holstered = false
                        canFire = true

                        if item then
                            ApplyWeaponAmmo(
                                ped,
                                item,
                                newWeapon
                            )

                            ApplyWeaponAttachments(
                                ped,
                                newWeapon,
                                item
                            )
                        end
                    end

                -- =========================================
                -- NON-DRAWABLE WEAPON
                -- =========================================

                else

                    if currWeap ~= `WEAPON_UNARMED`
                        and not holstered then

                        local holsterVariant =
                            GetPedDrawableVariation(
                                ped,
                                8
                            )

                        local hasHolster = false

                        for _, variant in ipairs(
                            Config.WeapDraw.variants or {}
                        ) do
                            if holsterVariant == variant then
                                hasHolster = true
                                break
                            end
                        end

                        CeaseFire(ped)

                        if hasHolster then

                            loadAnimDict(
                                'reaction@intimidation@cop@unarmed'
                            )

                            TaskPlayAnim(
                                ped,
                                'reaction@intimidation@cop@unarmed',
                                'intro',
                                8.0,
                                2.0,
                                500,
                                50,
                                0.0,
                                false,
                                false,
                                false
                            )

                            Wait(500)

                            if currHolster then
                                SetPedComponentVariation(
                                    ped,
                                    7,
                                    currHolster,
                                    currHolsterTexture or 0,
                                    0
                                )
                            end

                            SetCurrentPedWeapon(
                                ped,
                                `WEAPON_UNARMED`,
                                true
                            )

                            Wait(300)

                            ClearPedTasks(ped)

                        else

                            loadAnimDict(
                                'reaction@intimidation@1h'
                            )

                            TaskPlayAnim(
                                ped,
                                'reaction@intimidation@1h',
                                'outro',
                                8.0,
                                2.0,
                                1400,
                                50,
                                0.0,
                                false,
                                false,
                                false
                            )

                            Wait(1400)

                            SetCurrentPedWeapon(
                                ped,
                                `WEAPON_UNARMED`,
                                true
                            )

                            ClearPedTasks(ped)
                        end

                        holstered = true
                        canFire = true
                        currWeap = newWeapon

                        -- Let GTA select the non-inventory weapon
                        SetCurrentPedWeapon(
                            ped,
                            newWeapon,
                            true
                        )

                    else

                        SetCurrentPedWeapon(
                            ped,
                            newWeapon,
                            true
                        )

                        holstered = false
                        canFire = true
                        currWeap = newWeapon
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- =========================================================
-- FIRE CONTROL
-- =========================================================

CreateThread(function()
    while true do
        if not canFire then

            DisablePlayerFiring(
                PlayerId(),
                true
            )

            DisableControlAction(
                0,
                24,
                true
            )

            DisableControlAction(
                0,
                25,
                true
            )

            Wait(0)

        else
            Wait(250)
        end
    end
end)

-- =========================================================
-- PLAYER RESPAWN / DEATH RESET
-- =========================================================

CreateThread(function()
    while true do
        local ped = PlayerPedId()

        if DoesEntityExist(ped) then

            if IsEntityDead(ped) then

                holstered = true
                currWeap = `WEAPON_UNARMED`
                currHolster = nil
                currHolsterTexture = nil
                canFire = true
                weaponDrawing = false

            end
        end

        Wait(1000)
    end
end)

-- =========================================================
-- RESOURCE RESET
-- =========================================================

AddEventHandler(
    'onResourceStop',
    function(resource)
        if resource ~= GetCurrentResourceName() then
            return
        end

        local ped = PlayerPedId()

        if DoesEntityExist(ped) then
            SetCurrentPedWeapon(
                ped,
                `WEAPON_UNARMED`,
                true
            )

            ClearPedTasksImmediately(ped)
        end

        SetNuiFocus(false, false)
    end
)

-- =========================================================
-- DEBUG
-- =========================================================

print('========================================')
print('[TRAVES INVENTORY] CLIENT MAIN LOADED')
print('========================================')