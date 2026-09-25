local QBCore = exports['qb-core']:GetCoreObject()

-- =========================================================
-- TRAVES INVENTORY WEAPON SYSTEM
-- =========================================================

local CurrentWeapon = `WEAPON_UNARMED`
local CurrentWeaponName = nil
local WeaponBusy = false
local CanFire = true

-- =========================================================
-- WEAPONS THAT USE THE HOLSTER DRAW
-- From qb-weapons Config.WeapDraw
-- =========================================================

local HolsterWeapons = {
    [`WEAPON_PISTOL`] = true,
    [`WEAPON_PISTOL_MK2`] = true,
    [`WEAPON_COMBATPISTOL`] = true,
    [`WEAPON_APPISTOL`] = true,
    [`WEAPON_PISTOL50`] = true,
    [`WEAPON_REVOLVER`] = true,
    [`WEAPON_SNSPISTOL`] = true,
    [`WEAPON_HEAVYPISTOL`] = true,
    [`WEAPON_VINTAGEPISTOL`] = true,
}

-- =========================================================
-- ANIMATION DICTS
-- =========================================================

local function LoadAnimDict(dict)
    if not dict then
        return false
    end

    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)

    local timeout = GetGameTimer() + 5000

    while not HasAnimDictLoaded(dict) do
        Wait(10)

        if GetGameTimer() > timeout then
            print('[qb-inventory] Failed to load animation:', dict)
            return false
        end
    end

    return true
end

-- =========================================================
-- GET WEAPON HASH FROM ANY INPUT
-- =========================================================

local function GetWeaponHash(weapon)

    -- Item table from Traves inventory
    if type(weapon) == 'table' then

        if weapon.name then
            return joaat(weapon.name)
        end

        if weapon.hash then
            return tonumber(weapon.hash)
        end

        if weapon.weapon then
            return joaat(weapon.weapon)
        end

        return `WEAPON_UNARMED`
    end

    -- Weapon name
    if type(weapon) == 'string' then
        return joaat(weapon)
    end

    -- Already a hash
    if type(weapon) == 'number' then
        return weapon
    end

    return `WEAPON_UNARMED`
end

-- =========================================================
-- GET WEAPON NAME
-- =========================================================

local function GetWeaponName(weapon)

    if type(weapon) == 'table' then
        return weapon.name
    end

    if type(weapon) == 'string' then
        return weapon
    end

    return nil
end

-- =========================================================
-- GET ITEM INFO
-- =========================================================

local function GetWeaponInfo(item)

    if type(item) ~= 'table' then
        return {}
    end

    if type(item.info) == 'table' then
        return item.info
    end

    if type(item.metadata) == 'table' then
        return item.metadata
    end

    return {}
end

-- =========================================================
-- CHECK HOLSTER
-- =========================================================

local function HasHolster(ped)

    -- qb-weapons uses clothing component 8 for this setup.
    local drawable8 = GetPedDrawableVariation(ped, 8)

    local variants = {
        [130] = true,
        [122] = true,
        [3] = true,
        [6] = true,
        [8] = true,
    }

    if variants[drawable8] then
        return true
    end

    -- Also check component 7 because some clothing packs
    -- place the holster/accessory there.
    local drawable7 = GetPedDrawableVariation(ped, 7)

    if variants[drawable7] then
        return true
    end

    return false
end

-- =========================================================
-- APPLY AMMO
-- =========================================================

local function ApplyAmmo(ped, weaponHash, info)

    if not info then
        return
    end

    local ammo = tonumber(info.ammo)

    if ammo == nil then
        ammo = 0
    end

    if ammo < 0 then
        ammo = 0
    end

    SetPedAmmo(
        ped,
        weaponHash,
        ammo
    )
end

-- =========================================================
-- APPLY ATTACHMENTS
-- =========================================================

local function ApplyAttachments(ped, weaponHash, info)

    if not info then
        return
    end

    local attachments = info.attachments

    if type(attachments) ~= 'table' then
        return
    end

    for _, attachment in pairs(attachments) do

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
-- APPLY WEAPON DATA
-- =========================================================

local function ApplyWeaponData(ped, weaponHash, item)

    local info = GetWeaponInfo(item)

    ApplyAmmo(
        ped,
        weaponHash,
        info
    )

    ApplyAttachments(
        ped,
        weaponHash,
        info
    )

end

-- =========================================================
-- CHECK WEAPON QUALITY
-- =========================================================

local function WeaponCanFire(item)

    if type(item) ~= 'table' then
        return true
    end

    local info = GetWeaponInfo(item)

    if info.quality == nil then
        return true
    end

    local quality = tonumber(info.quality)

    if not quality then
        return true
    end

    return quality > 0
end

-- =========================================================
-- STOP FIRING
-- =========================================================

local function StartCeaseFire()

    CanFire = false

    CreateThread(function()

        while not CanFire do

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

        end

    end)

end

-- =========================================================
-- DRAW ANIMATION
-- =========================================================

local function PlayDrawAnimation(ped, weaponHash)

    local useHolster =
        HolsterWeapons[weaponHash] == true
        and HasHolster(ped)

    -- =====================================================
    -- HOLSTER DRAW
    -- =====================================================

    if useHolster then

        if LoadAnimDict('rcmjosh4') then

            TaskPlayAnim(
                ped,
                'rcmjosh4',
                'josh_leadout_cop2',
                8.0,
                -8.0,
                450,
                48,
                0.0,
                false,
                false,
                false
            )

            Wait(300)

        end

        return
    end

    -- =====================================================
    -- NORMAL PISTOL DRAW
    -- =====================================================

    if HolsterWeapons[weaponHash] then

        if LoadAnimDict('reaction@intimidation@1h') then

            TaskPlayAnim(
                ped,
                'reaction@intimidation@1h',
                'intro',
                8.0,
                -8.0,
                900,
                48,
                0.0,
                false,
                false,
                false
            )

            Wait(650)

        end

        return
    end

    -- =====================================================
    -- RIFLES / SMGS / SHOTGUNS
    -- =====================================================

    if LoadAnimDict('reaction@intimidation@1h') then

        TaskPlayAnim(
            ped,
            'reaction@intimidation@1h',
            'intro',
            8.0,
            -8.0,
            500,
            48,
            0.0,
            false,
            false,
            false
        )

        Wait(350)

    end

end

-- =========================================================
-- HOLSTER ANIMATION
-- =========================================================

local function PlayHolsterAnimation(ped, weaponHash)

    local useHolster =
        HolsterWeapons[weaponHash] == true
        and HasHolster(ped)

    -- =====================================================
    -- HOLSTER PUT AWAY
    -- =====================================================

    if useHolster then

        if LoadAnimDict('reaction@intimidation@cop@unarmed') then

            TaskPlayAnim(
                ped,
                'reaction@intimidation@cop@unarmed',
                'intro',
                8.0,
                -8.0,
                650,
                48,
                0.0,
                false,
                false,
                false
            )

            Wait(500)

        end

        return
    end

    -- =====================================================
    -- NORMAL PUT AWAY
    -- =====================================================

    if LoadAnimDict('reaction@intimidation@1h') then

        TaskPlayAnim(
            ped,
            'reaction@intimidation@1h',
            'outro',
            8.0,
            -8.0,
            900,
            48,
            0.0,
            false,
            false,
            false
        )

        Wait(650)

    end

end

-- =========================================================
-- REMOVE CURRENT WEAPON
-- =========================================================

local function RemoveCurrentWeapon(ped)

    if CurrentWeapon == `WEAPON_UNARMED` then
        return
    end

    SetCurrentPedWeapon(
        ped,
        `WEAPON_UNARMED`,
        true
    )

    Wait(50)

    RemoveWeaponFromPed(
        ped,
        CurrentWeapon
    )

    CurrentWeapon = `WEAPON_UNARMED`
    CurrentWeaponName = nil

end

-- =========================================================
-- HOLSTER CURRENT WEAPON
-- =========================================================

local function HolsterCurrentWeapon()

    if WeaponBusy then
        return
    end

    if CurrentWeapon == `WEAPON_UNARMED` then
        return
    end

    WeaponBusy = true

    local ped = PlayerPedId()

    if not DoesEntityExist(ped) then
        WeaponBusy = false
        return
    end

    StartCeaseFire()

    local oldWeapon = CurrentWeapon

    PlayHolsterAnimation(
        ped,
        oldWeapon
    )

    SetCurrentPedWeapon(
        ped,
        `WEAPON_UNARMED`,
        true
    )

    Wait(100)

    RemoveWeaponFromPed(
        ped,
        oldWeapon
    )

    ClearPedTasks(ped)

    CurrentWeapon = `WEAPON_UNARMED`
    CurrentWeaponName = nil

    CanFire = true
    WeaponBusy = false

end

-- =========================================================
-- DRAW SPECIFIC WEAPON
-- =========================================================

local function DrawSpecificWeapon(item)

    if WeaponBusy then
        return
    end

    if type(item) ~= 'table' then
        print('[qb-inventory] DrawSpecificWeapon received invalid item')
        return
    end

    if not item.name then
        print('[qb-inventory] Weapon item has no name')
        return
    end

    local weaponHash = GetWeaponHash(item)

    if weaponHash == `WEAPON_UNARMED` then
        return
    end

    local weaponName = GetWeaponName(item)

    local ped = PlayerPedId()

    if not DoesEntityExist(ped) then
        return
    end

    -- =====================================================
    -- SAME WEAPON = HOLSTER
    -- =====================================================

    if CurrentWeapon == weaponHash then

        HolsterCurrentWeapon()

        return
    end

    WeaponBusy = true

    StartCeaseFire()

    -- =====================================================
    -- PUT PREVIOUS WEAPON AWAY
    -- =====================================================

    if CurrentWeapon ~= `WEAPON_UNARMED` then

        local oldWeapon = CurrentWeapon

        PlayHolsterAnimation(
            ped,
            oldWeapon
        )

        SetCurrentPedWeapon(
            ped,
            `WEAPON_UNARMED`,
            true
        )

        Wait(100)

        RemoveWeaponFromPed(
            ped,
            oldWeapon
        )

        ClearPedTasks(ped)

        CurrentWeapon = `WEAPON_UNARMED`
        CurrentWeaponName = nil

    end

    -- =====================================================
    -- GIVE THE WEAPON TO PLAYER
    -- =====================================================

    GiveWeaponToPed(
        ped,
        weaponHash,
        0,
        false,
        false
    )

    Wait(50)

    -- =====================================================
    -- APPLY INVENTORY DATA
    -- =====================================================

    ApplyWeaponData(
        ped,
        weaponHash,
        item
    )

    -- =====================================================
    -- DRAW ANIMATION
    -- =====================================================

    PlayDrawAnimation(
        ped,
        weaponHash
    )

    -- =====================================================
    -- SELECT WEAPON
    -- =====================================================

    SetCurrentPedWeapon(
        ped,
        weaponHash,
        true
    )

    SetPedCurrentWeaponVisible(
        ped,
        true,
        true,
        true,
        true
    )

    CurrentWeapon = weaponHash
    CurrentWeaponName = weaponName

    ClearPedTasks(ped)

    Wait(100)

    -- =====================================================
    -- QUALITY
    -- =====================================================

    if WeaponCanFire(item) then
        CanFire = true
    else
        CanFire = false
    end

    WeaponBusy = false

end

-- =========================================================
-- MAIN TRAVES EVENT
-- =========================================================

RegisterNetEvent(
    'qb-inventory:client:DrawWeapon',
    function(item, shootable)

        DrawSpecificWeapon(item)

        if shootable == false then
            CanFire = false
        end

    end
)

-- =========================================================
-- COMPATIBILITY EVENT
-- =========================================================
-- Your current server was using UseWeapon.
-- Keep this so either event works.

RegisterNetEvent(
    'qb-inventory:client:UseWeapon',
    function(item, shootable)

        DrawSpecificWeapon(item)

        if shootable == false then
            CanFire = false
        end

    end
)

-- =========================================================
-- QB-WEAPONS COMPATIBILITY
-- =========================================================

RegisterNetEvent(
    'qb-weapons:client:DrawWeapon',
    function(item)

        DrawSpecificWeapon(item)

    end
)

-- =========================================================
-- RESET HOLSTER
-- =========================================================

RegisterNetEvent(
    'qb-inventory:client:ResetHolster',
    function()

        local ped = PlayerPedId()

        if DoesEntityExist(ped) then

            SetCurrentPedWeapon(
                ped,
                `WEAPON_UNARMED`,
                true
            )

        end

        CurrentWeapon = `WEAPON_UNARMED`
        CurrentWeaponName = nil
        WeaponBusy = false
        CanFire = true

    end
)

RegisterNetEvent(
    'qb-weapons:ResetHolster',
    function()

        local ped = PlayerPedId()

        if DoesEntityExist(ped) then

            SetCurrentPedWeapon(
                ped,
                `WEAPON_UNARMED`,
                true
            )

        end

        CurrentWeapon = `WEAPON_UNARMED`
        CurrentWeaponName = nil
        WeaponBusy = false
        CanFire = true

    end
)

-- =========================================================
-- 1-5 HOTKEY SUPPORT
-- =========================================================

local function UseInventorySlot(slot)

    TriggerServerEvent(
        'qb-inventory:server:useSlot',
        slot
    )

end

RegisterCommand(
    'travesinvslot1',
    function()
        UseInventorySlot(1)
    end,
    false
)

RegisterCommand(
    'travesinvslot2',
    function()
        UseInventorySlot(2)
    end,
    false
)

RegisterCommand(
    'travesinvslot3',
    function()
        UseInventorySlot(3)
    end,
    false
)

RegisterCommand(
    'travesinvslot4',
    function()
        UseInventorySlot(4)
    end,
    false
)

RegisterCommand(
    'travesinvslot5',
    function()
        UseInventorySlot(5)
    end,
    false
)

RegisterKeyMapping(
    'travesinvslot1',
    'Traves Inventory Slot 1',
    'keyboard',
    '1'
)

RegisterKeyMapping(
    'travesinvslot2',
    'Traves Inventory Slot 2',
    'keyboard',
    '2'
)

RegisterKeyMapping(
    'travesinvslot3',
    'Traves Inventory Slot 3',
    'keyboard',
    '3'
)

RegisterKeyMapping(
    'travesinvslot4',
    'Traves Inventory Slot 4',
    'keyboard',
    '4'
)

RegisterKeyMapping(
    'travesinvslot5',
    'Traves Inventory Slot 5',
    'keyboard',
    '5'
)

-- =========================================================
-- BLOCK FIRE WHEN WEAPON IS BROKEN
-- =========================================================

CreateThread(function()

    while true do

        if CurrentWeapon ~= `WEAPON_UNARMED` and not CanFire then

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
-- CLEANUP WHEN PLAYER DIES
-- =========================================================

CreateThread(function()

    while true do

        Wait(500)

        local ped = PlayerPedId()

        if DoesEntityExist(ped) and IsEntityDead(ped) then

            if CurrentWeapon ~= `WEAPON_UNARMED` then

                SetCurrentPedWeapon(
                    ped,
                    `WEAPON_UNARMED`,
                    true
                )

                RemoveWeaponFromPed(
                    ped,
                    CurrentWeapon
                )

                CurrentWeapon = `WEAPON_UNARMED`
                CurrentWeaponName = nil
                WeaponBusy = false
                CanFire = true

            end

        end

    end

end)

-- =========================================================
-- RESOURCE CLEANUP
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

            if CurrentWeapon ~= `WEAPON_UNARMED` then

                RemoveWeaponFromPed(
                    ped,
                    CurrentWeapon
                )

            end

        end

    end
)

-- =========================================================
-- EXPORTS
-- =========================================================

exports(
    'IsWeaponHolstered',
    function()

        return CurrentWeapon == `WEAPON_UNARMED`

    end
)

exports(
    'IsWeaponDrawn',
    function()

        return CurrentWeapon ~= `WEAPON_UNARMED`

    end
)

exports(
    'GetCurrentWeapon',
    function()

        return CurrentWeapon

    end
)

exports(
    'GetCurrentWeaponName',
    function()

        return CurrentWeaponName

    end
)

exports(
    'HolsterWeapon',
    function()

        HolsterCurrentWeapon()

    end
)

exports(
    'DrawWeapon',
    function(item)

        DrawSpecificWeapon(item)

    end
)

print('[qb-inventory] Weapon system loaded.')