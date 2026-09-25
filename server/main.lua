local QBCore = exports['qb-core']:GetCoreObject()

local OpenInventories = {}
local OpenCitizenIds = {}

local GROUND_DISTANCE = 5.0


-- =========================================================
-- DEBUG
-- =========================================================

local function debugPrint(...)
    if Config.Debug then
        print('[qb-inventory:server]', ...)
    end
end


-- =========================================================
-- PLAYER
-- =========================================================

local function getPlayer(source)
    return QBCore.Functions.GetPlayer(tonumber(source))
end


-- =========================================================
-- GET CITIZEN ID
-- =========================================================

local function GetCitizenId(source)

    source = tonumber(source)

    if not source then
        return nil
    end

    local Player = getPlayer(source)

    if Player
        and Player.PlayerData
        and Player.PlayerData.citizenid then

        local citizenid = Player.PlayerData.citizenid

        OpenCitizenIds[source] = citizenid

        return citizenid
    end

    if OpenCitizenIds[source] then
        return OpenCitizenIds[source]
    end

    return nil
end


-- =========================================================
-- COUNT INVENTORY
-- =========================================================

local function CountInventoryItems(inventory)

    local count = 0

    if type(inventory) ~= 'table' then
        return 0
    end

    for _, item in pairs(inventory) do

        if type(item) == 'table'
            and item.name
            and (tonumber(item.amount) or 0) > 0 then

            count = count + 1
        end
    end

    return count
end


-- =========================================================
-- DEBUG INVENTORY
-- =========================================================

local function PrintInventoryDebug(inventory)

    if type(inventory) ~= 'table' then
        print('[qb-inventory]   *** INVENTORY IS NOT A TABLE ***')
        return
    end

    local count = 0

    for slot, item in pairs(inventory) do

        if type(item) == 'table'
            and item.name
            and (tonumber(item.amount) or 0) > 0 then

            count = count + 1

            print(
                ('[qb-inventory]   slot %s = %sx %s')
                :format(
                    tostring(slot),
                    tonumber(item.amount) or 0,
                    tostring(item.name)
                )
            )
        end
    end

    if count == 0 then
        print('[qb-inventory]   *** INVENTORY IS EMPTY ***')
    end
end


-- =========================================================
-- ITEM NORMALIZATION
-- =========================================================

local function normalizeItem(item)

    if type(item) ~= 'table' then
        return nil
    end

    if not item.name then
        return nil
    end

    local name = tostring(item.name):lower()

    local shared = QBCore.Shared.Items[name]

    if not shared then
        debugPrint('Unknown item:', name)
        return nil
    end

    item.name = name

    item.amount =
        tonumber(item.amount)
        or 1

    item.slot =
        tonumber(item.slot)

    if type(item.info) ~= 'table' then
        item.info = {}
    end

    item.type =
        item.type
        or shared.type
        or 'item'

    item.label =
        item.label
        or shared.label
        or name

    item.description =
        item.description
        or shared.description
        or ''

    item.weight =
        tonumber(item.weight)
        or tonumber(shared.weight)
        or 0

    if item.unique ~= nil then
        item.unique = item.unique
    else
        item.unique =
            shared.unique
            or false
    end

    if item.useable ~= nil then
        item.useable = item.useable
    else
        item.useable =
            shared.useable
            or false
    end

    item.image =
        item.image
        or shared.image
        or (name .. '.png')

    if item.shouldClose ~= nil then
        item.shouldClose = item.shouldClose
    else
        item.shouldClose =
            shared.shouldClose
            or false
    end

    return item
end


-- =========================================================
-- NORMALIZE INVENTORY
-- =========================================================

local function NormalizeInventory(inventory)

    local result = {}

    if type(inventory) ~= 'table' then
        return result
    end

    for key, item in pairs(inventory) do

        if type(item) == 'table'
            and item.name then

            local normalized =
                normalizeItem(item)

            if normalized then

                local keySlot =
                    tonumber(key)

                local itemSlot =
                    tonumber(normalized.slot)

                local slot

                if keySlot
                    and keySlot >= 1
                    and keySlot <= Config.MaxSlots then

                    slot = keySlot

                elseif itemSlot
                    and itemSlot >= 1
                    and itemSlot <= Config.MaxSlots then

                    slot = itemSlot
                end

                if slot
                    and normalized.amount > 0 then

                    normalized.slot = slot

                    result[slot] =
                        normalized
                end
            end
        end
    end

    return result
end


-- =========================================================
-- LOAD INVENTORY
-- =========================================================

local function LoadInventory(source)

    source = tonumber(source)

    if not source then
        return {}
    end

    local Player =
        getPlayer(source)

    if not Player then
        return {}
    end

    local citizenid =
        Player.PlayerData.citizenid

    if not citizenid then
        return {}
    end

    OpenCitizenIds[source] =
        citizenid

    local result =
        MySQL.single.await(
            [[
                SELECT inventory
                FROM traves_inventories
                WHERE citizenid = ?
            ]],
            {
                citizenid
            }
        )

    if not result then

        local empty =
            {}

        local inserted =
            MySQL.insert.await(
                [[
                    INSERT INTO traves_inventories
                    (
                        citizenid,
                        inventory,
                        maxweight,
                        maxslots
                    )
                    VALUES (?, ?, ?, ?)
                ]],
                {
                    citizenid,
                    json.encode(empty),
                    Config.MaxWeight,
                    Config.MaxSlots
                }
            )

        if inserted then

            debugPrint(
                ('Created inventory row for %s (%s).')
                :format(
                    GetPlayerName(source) or 'Unknown',
                    citizenid
                )
            )
        end

        return {}
    end

    local success, decoded =
        pcall(
            json.decode,
            result.inventory
        )

    if not success
        or type(decoded) ~= 'table' then

        print(
            ('^1[qb-inventory]^7 Failed to decode inventory for %s.')
            :format(citizenid)
        )

        return {}
    end

    local normalized =
        NormalizeInventory(decoded)

    debugPrint(
        ('Loaded inventory for %s (%s) containing %s slot(s).')
        :format(
            GetPlayerName(source) or 'Unknown',
            citizenid,
            CountInventoryItems(normalized)
        )
    )

    return normalized
end


-- =========================================================
-- SAVE INVENTORY
-- =========================================================

local function SaveInventory(source, inventory)

    source = tonumber(source)

    if not source then
        return false
    end

    local Player =
        getPlayer(source)

    local citizenid =
        GetCitizenId(source)

    if not citizenid then

        print(
            ('^1[qb-inventory]^7 SAVE FAILED - no citizenid for source %s.')
            :format(source)
        )

        return false
    end


    -- =====================================================
    -- NORMALIZE INCOMING INVENTORY
    -- =====================================================

    local normalized =
        NormalizeInventory(
            inventory or {}
        )


    -- =====================================================
    -- INVENTORY COUNTS
    -- =====================================================

    local incomingCount =
        CountInventoryItems(normalized)

    local existingCached =
        OpenInventories[source]

    local cachedCount =
        CountInventoryItems(existingCached)


    -- =====================================================
    -- PROTECTION #1
    --
    -- If we already have a valid cached inventory and
    -- something tries to save an empty inventory, use the
    -- cached inventory instead.
    -- =====================================================

    if incomingCount == 0
        and cachedCount > 0 then

        debugPrint(
            ('BLOCKED EMPTY SAVE for %s (%s).')
            :format(
                GetPlayerName(source) or 'Unknown',
                citizenid
            )
        )

        debugPrint(
            ('Incoming inventory had 0 items, but cached inventory has %s items.')
            :format(cachedCount)
        )

        print(
            ('^3[qb-inventory]^7 Prevented empty inventory overwrite for %s (%s).')
            :format(
                GetPlayerName(source) or 'Unknown',
                citizenid
            )
        )

        normalized =
            NormalizeInventory(
                existingCached
            )

        incomingCount =
            CountInventoryItems(normalized)
    end


    -- =====================================================
    -- PROTECTION #2
    --
    -- This is the important QBCore/multichara protection.
    --
    -- If there is NO cached inventory but the database
    -- already contains a real inventory, do NOT allow an
    -- empty save to wipe it.
    --
    -- This handles:
    --
    -- SaveInventory(source, {})
    --
    -- being called during character unload/switching.
    -- =====================================================

    if incomingCount == 0
        and cachedCount == 0 then

        local existingDatabase =
            MySQL.single.await(
                [[
                    SELECT inventory
                    FROM traves_inventories
                    WHERE citizenid = ?
                ]],
                {
                    citizenid
                }
            )

        if existingDatabase
            and existingDatabase.inventory then

            local success, decoded =
                pcall(
                    json.decode,
                    existingDatabase.inventory
                )

            if success
                and type(decoded) == 'table' then

                local databaseInventory =
                    NormalizeInventory(decoded)

                local databaseCount =
                    CountInventoryItems(databaseInventory)

                if databaseCount > 0 then

                    print(
                        ('^3[qb-inventory]^7 BLOCKED EMPTY DATABASE OVERWRITE | Player: %s | CitizenID: %s | Database Items: %s')
                        :format(
                            GetPlayerName(source) or 'Unknown',
                            citizenid,
                            databaseCount
                        )
                    )

                    print(
                        '^3[qb-inventory]^7 This empty save was most likely caused by a QBCore/multichara unload.'
                    )

                    -- Keep the database inventory alive.
                    -- Also restore our cache so subsequent saves
                    -- continue using the correct inventory.

                    OpenInventories[source] =
                        databaseInventory

                    OpenCitizenIds[source] =
                        citizenid

                    if Player then

                        Player.PlayerData.items =
                            databaseInventory

                    end

                    return true
                end
            end
        end
    end


    -- =====================================================
    -- SAVE DIAGNOSTICS
    -- =====================================================

    print(
        ('^5[qb-inventory]^7 SAVE ATTEMPT | Player: %s | CitizenID: %s | Items: %s')
        :format(
            GetPlayerName(source) or 'Unknown',
            citizenid,
            incomingCount
        )
    )

    if Config.Debug then
        PrintInventoryDebug(normalized)
    end


    -- =====================================================
    -- ENCODE
    -- =====================================================

    local encoded =
        json.encode(normalized)

    if not encoded then

        print(
            ('^1[qb-inventory]^7 Failed to encode inventory for %s.')
            :format(citizenid)
        )

        return false
    end


    -- =====================================================
    -- CHECK DATABASE ROW
    -- =====================================================

    local existing =
        MySQL.single.await(
            [[
                SELECT citizenid
                FROM traves_inventories
                WHERE citizenid = ?
            ]],
            {
                citizenid
            }
        )


    -- =====================================================
    -- UPDATE EXISTING ROW
    -- =====================================================

    if existing then

        local success =
            MySQL.update.await(
                [[
                    UPDATE traves_inventories
                    SET
                        inventory = ?,
                        maxweight = ?,
                        maxslots = ?
                    WHERE citizenid = ?
                ]],
                {
                    encoded,
                    Config.MaxWeight,
                    Config.MaxSlots,
                    citizenid
                }
            )

        if success == nil then

            print(
                ('^1[qb-inventory]^7 DATABASE UPDATE FAILED for %s.')
                :format(citizenid)
            )

            return false
        end


    -- =====================================================
    -- INSERT MISSING ROW
    -- =====================================================

    else
        local inserted = MySQL.insert.await(
            [[
                INSERT INTO traves_inventories
                (
                    citizenid,
                    inventory,
                    maxweight,
                    maxslots
                )
                VALUES (?, ?, ?, ?)
            ]],
            {
                citizenid,
                encoded,
                Config.MaxWeight,
                Config.MaxSlots
            }
        )

        if not inserted then

            print(
                ('^1[qb-inventory]^7 DATABASE INSERT FAILED for %s.')
                :format(citizenid)
            )

            return false
        end

        debugPrint(
            ('Created missing inventory row for %s.')
            :format(citizenid)
        )
    end


    -- =====================================================
    -- UPDATE QBCORE PLAYER DATA
    -- =====================================================

    if Player then

        Player.PlayerData.items =
            normalized

    end


    -- =====================================================
    -- UPDATE OUR CACHE
    -- =====================================================

    OpenInventories[source] =
        normalized

    OpenCitizenIds[source] =
        citizenid


    -- =====================================================
    -- SUCCESS
    -- =====================================================

    print(
        ('^2[qb-inventory]^7 SAVE SUCCESS | Player: %s | CitizenID: %s | Items: %s')
        :format(
            GetPlayerName(source) or 'Unknown',
            citizenid,
            CountInventoryItems(normalized)
        )
    )

    return true
end


-- =========================================================
-- SYNC PLAYER DATA
-- =========================================================

local function SyncPlayerData(source, inventory)

    local Player =
        getPlayer(source)

    if not Player then
        return
    end

    Player.PlayerData.items =
        inventory

    TriggerClientEvent(
        'QBCore:Player:SetPlayerData',
        source,
        Player.PlayerData
    )

    TriggerClientEvent(
        'QBCore:Client:OnPlayerUpdated',
        source,
        'items',
        inventory
    )
end


-- =========================================================
-- INVENTORY WEIGHT
-- =========================================================

local function GetInventoryWeight(inventory)

    local weight = 0

    for _, item in pairs(inventory or {}) do

        if item then

            weight =
                weight
                + (
                    (tonumber(item.weight) or 0)
                    * (tonumber(item.amount) or 0)
                )
        end
    end

    return weight
end


-- =========================================================
-- FREE SLOT
-- =========================================================

local function GetFreeSlot(inventory)

    for slot = 1, Config.MaxSlots do

        if not inventory[slot] then
            return slot
        end
    end

    return nil
end


-- =========================================================
-- DROP ID
-- =========================================================

local function GenerateDropId()

    return (
        'drop_%s_%s'
    ):format(
        os.time(),
        math.random(100000, 999999)
    )
end


-- =========================================================
-- PLAYER COORDINATES
-- =========================================================

local function GetPlayerCoords(source)

    local ped =
        GetPlayerPed(source)

    if not ped
        or ped <= 0 then

        return nil
    end

    local coords =
        GetEntityCoords(ped)

    if not coords then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
end


-- =========================================================
-- DISTANCE
-- =========================================================

local function Distance(a, b)

    if not a or not b then
        return 999999.0
    end

    local dx =
        (a.x or 0.0)
        - (b.x or 0.0)

    local dy =
        (a.y or 0.0)
        - (b.y or 0.0)

    local dz =
        (a.z or 0.0)
        - (b.z or 0.0)

    return math.sqrt(
        dx * dx
        + dy * dy
        + dz * dz
    )
end


-- =========================================================
-- GROUND DROPS
-- =========================================================

local function GetNearbyGroundDrops(source)

    local playerCoords =
        GetPlayerCoords(source)

    if not playerCoords then
        return {}
    end

    local rows =
        MySQL.query.await(
            [[
                SELECT
                    drop_id,
                    items,
                    x,
                    y,
                    z
                FROM traves_drops
            ]]
        )

    local result = {}

    if not rows then
        return result
    end

    for _, row in ipairs(rows) do

        local coords = {
            x = tonumber(row.x) or 0.0,
            y = tonumber(row.y) or 0.0,
            z = tonumber(row.z) or 0.0
        }

        if Distance(
            playerCoords,
            coords
        ) <= GROUND_DISTANCE then

            local success, decoded =
                pcall(
                    json.decode,
                    row.items or '{}'
                )

            if success
                and type(decoded) == 'table' then

                for slot, item in pairs(decoded) do

                    local normalized =
                        normalizeItem(item)

                    if normalized
                        and normalized.amount > 0 then

                        normalized.slot =
                            tonumber(normalized.slot)
                            or tonumber(slot)

                        normalized.dropId =
                            row.drop_id

                        normalized.groundSlot =
                            normalized.slot

                        normalized.x =
                            coords.x

                        normalized.y =
                            coords.y

                        normalized.z =
                            coords.z

                        result[#result + 1] =
                            normalized
                    end
                end
            end
        end
    end

    return result
end


-- =========================================================
-- SEND GROUND UPDATE
-- =========================================================

local function SendGroundUpdate(source)

    local drops =
        GetNearbyGroundDrops(source)

    TriggerClientEvent(
        'qb-inventory:client:groundUpdate',
        source,
        drops
    )
end


-- =========================================================
-- OPEN INVENTORY
-- =========================================================

RegisterNetEvent(
    'qb-inventory:server:open',
    function()

        local source =
            source

        local Player =
            getPlayer(source)

        if not Player then
            return
        end

        while not IsTravesDatabaseReady() do
            Wait(50)
        end

        local citizenid =
            Player.PlayerData.citizenid

        OpenCitizenIds[source] =
            citizenid

        local inventory =
            LoadInventory(source)

        inventory =
            NormalizeInventory(inventory)

        OpenInventories[source] =
            inventory

        SyncPlayerData(
            source,
            inventory
        )

        local charinfo =
            Player.PlayerData.charinfo

        local playerName =
            GetPlayerName(source)

        if charinfo then

            playerName =
                (charinfo.firstname or '')
                .. ' '
                .. (charinfo.lastname or '')
        end

        local ground =
            GetNearbyGroundDrops(source)

        TriggerClientEvent(
            'qb-inventory:client:open',
            source,
            inventory,
            Config.MaxSlots,
            Config.MaxWeight,
            playerName,
            ground
        )
    end
)


-- =========================================================
-- CLOSE INVENTORY
-- =========================================================

RegisterNetEvent(
    'qb-inventory:server:close',
    function()

        local source =
            source

        if not OpenInventories[source] then
            return
        end

        local success =
            SaveInventory(
                source,
                OpenInventories[source]
            )

        if success then

            debugPrint(
                ('Inventory closed and saved for player %s.')
                :format(source)
            )

        else

            print(
                ('^1[qb-inventory]^7 FAILED to save inventory on close for player %s.')
                :format(source)
            )
        end
    end
)


-- =========================================================
-- UPDATE INVENTORY
-- =========================================================

local function UpdateInventory(source, inventory)

    inventory =
        NormalizeInventory(inventory)

    OpenInventories[source] =
        inventory

    SyncPlayerData(
        source,
        inventory
    )

    TriggerClientEvent(
        'qb-inventory:client:update',
        source,
        inventory
    )
end


-- =========================================================
-- MOVE ITEMS
-- =========================================================

RegisterNetEvent(
    'qb-inventory:server:move',
    function(
        fromSlot,
        toSlot,
        amount
    )

        local source =
            source

        local inventory =
            OpenInventories[source]

        if not inventory then
            return
        end

        fromSlot =
            tonumber(fromSlot)

        toSlot =
            tonumber(toSlot)

        amount =
            tonumber(amount) or 1

        if not fromSlot
            or not toSlot then

            return
        end

        if fromSlot < 1
            or fromSlot > Config.MaxSlots
            or toSlot < 1
            or toSlot > Config.MaxSlots then

            return
        end

        local fromItem =
            inventory[fromSlot]

        if not fromItem then
            return
        end

        local toItem =
            inventory[toSlot]

        amount =
            math.min(
                amount,
                tonumber(fromItem.amount) or 0
            )

        if amount <= 0 then
            return
        end

        if toItem
            and toItem.name == fromItem.name
            and not toItem.unique then

            toItem.amount =
                (tonumber(toItem.amount) or 0)
                + amount

            fromItem.amount =
                (tonumber(fromItem.amount) or 0)
                - amount

            if fromItem.amount <= 0 then
                inventory[fromSlot] = nil
            end

        elseif not toItem then

            fromItem.slot =
                toSlot

            inventory[toSlot] =
                fromItem

            inventory[fromSlot] =
                nil

        else

            if amount ~=
                tonumber(fromItem.amount) then

                return
            end

            fromItem.slot =
                toSlot

            toItem.slot =
                fromSlot

            inventory[fromSlot] =
                toItem

            inventory[toSlot] =
                fromItem
        end

        UpdateInventory(
            source,
            inventory
        )

        SaveInventory(
            source,
            inventory
        )
    end
)


-- =========================================================
-- DROP ITEM
-- =========================================================

RegisterNetEvent(
    'qb-inventory:server:drop',
    function(
        slot,
        amount
    )

        local source =
            source

        local Player =
            getPlayer(source)

        if not Player then
            return
        end

        slot =
            tonumber(slot)

        amount =
            tonumber(amount) or 1

        if not slot
            or amount <= 0 then

            return
        end

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end

        local item =
            inventory[slot]

        if not item then
            return
        end

        local itemAmount =
            tonumber(item.amount) or 0

        if amount > itemAmount then
            return
        end

        local coords =
            GetPlayerCoords(source)

        if not coords then
            return
        end

        local droppedItem = {}

        for key, value in pairs(item) do
            droppedItem[key] =
                value
        end

        droppedItem.amount =
            amount

        droppedItem.slot =
            1

        item.amount =
            itemAmount - amount

        if item.amount <= 0 then
            inventory[slot] =
                nil
        end

        local dropId =
            GenerateDropId()

        local groundItems = {
            [1] = droppedItem
        }

        MySQL.insert.await(
            [[
                INSERT INTO traves_drops
                (
                    drop_id,
                    items,
                    x,
                    y,
                    z
                )
                VALUES (?, ?, ?, ?, ?)
            ]],
            {
                dropId,
                json.encode(groundItems),
                coords.x,
                coords.y,
                coords.z
            }
        )

        UpdateInventory(
            source,
            inventory
        )

        SaveInventory(
            source,
            inventory
        )

        SendGroundUpdate(source)

        TriggerClientEvent(
            'qb-inventory:client:notify',
            source,
            ('Dropped %sx %s.'):format(
                amount,
                item.label or item.name
            ),
            'primary'
        )

        debugPrint(
            ('Player %s dropped %sx %s as %s')
            :format(
                source,
                amount,
                item.name,
                dropId
            )
        )
    end
)


-- =========================================================
-- REQUEST GROUND
-- =========================================================

RegisterNetEvent(
    'qb-inventory:server:requestGround',
    function()

        local source =
            source

        SendGroundUpdate(source)
    end
)


-- =========================================================
-- PICK UP GROUND ITEM
-- =========================================================

RegisterNetEvent(
    'qb-inventory:server:pickupGround',
    function(
        dropId,
        groundSlot,
        amount,
        targetSlot
    )

        local source =
            source

        local Player =
            getPlayer(source)

        if not Player then
            return
        end

        if not dropId then
            return
        end

        groundSlot =
            tonumber(groundSlot)

        amount =
            tonumber(amount) or 1

        targetSlot =
            tonumber(targetSlot)

        if not groundSlot
            or amount <= 0 then

            return
        end

        local coords =
            GetPlayerCoords(source)

        if not coords then
            return
        end

        local row =
            MySQL.single.await(
                [[
                    SELECT
                        drop_id,
                        items,
                        x,
                        y,
                        z
                    FROM traves_drops
                    WHERE drop_id = ?
                ]],
                {
                    tostring(dropId)
                }
            )

        if not row then

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'That ground item no longer exists.',
                'error'
            )

            SendGroundUpdate(source)

            return
        end

        local dropCoords = {
            x = tonumber(row.x) or 0.0,
            y = tonumber(row.y) or 0.0,
            z = tonumber(row.z) or 0.0
        }

        if Distance(
            coords,
            dropCoords
        ) > GROUND_DISTANCE then

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'You are too far away from that item.',
                'error'
            )

            return
        end

        local success, items =
            pcall(
                json.decode,
                row.items or '{}'
            )

        if not success
            or type(items) ~= 'table' then

            return
        end

        local groundItem =
            items[groundSlot]

        if not groundItem then
            return
        end

        groundItem =
            normalizeItem(groundItem)

        if not groundItem then
            return
        end

        local available =
            tonumber(groundItem.amount) or 0

        amount =
            math.min(
                amount,
                available
            )

        if amount <= 0 then
            return
        end

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end

        local finalSlot =
            targetSlot

        if not finalSlot
            or finalSlot < 1
            or finalSlot > Config.MaxSlots then

            finalSlot =
                GetFreeSlot(inventory)
        end

        if not finalSlot then

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'Your inventory is full.',
                'error'
            )

            return
        end

        local currentWeight =
            GetInventoryWeight(inventory)

        local addedWeight =
            (tonumber(groundItem.weight) or 0)
            * amount

        if currentWeight + addedWeight
            > Config.MaxWeight then

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'You cannot carry that much weight.',
                'error'
            )

            return
        end

        local existing =
            inventory[finalSlot]

        if existing
            and existing.name == groundItem.name
            and not existing.unique then

            existing.amount =
                (tonumber(existing.amount) or 0)
                + amount

        elseif not existing then

            local newItem = {}

            for key, value in pairs(groundItem) do
                newItem[key] =
                    value
            end

            newItem.dropId = nil
            newItem.groundSlot = nil
            newItem.x = nil
            newItem.y = nil
            newItem.z = nil

            newItem.slot =
                finalSlot

            newItem.amount =
                amount

            inventory[finalSlot] =
                newItem

        else

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'That inventory slot is occupied.',
                'error'
            )

            return
        end

        groundItem.amount =
            available - amount

        if groundItem.amount <= 0 then

            items[groundSlot] =
                nil

        else

            items[groundSlot] =
                groundItem
        end

        local hasItems =
            false

        for _, value in pairs(items) do

            if value
                and tonumber(value.amount or 0) > 0 then

                hasItems =
                    true

                break
            end
        end

        if hasItems then

            MySQL.update.await(
                [[
                    UPDATE traves_drops
                    SET items = ?
                    WHERE drop_id = ?
                ]],
                {
                    json.encode(items),
                    tostring(dropId)
                }
            )

        else

            MySQL.update.await(
                [[
                    DELETE FROM traves_drops
                    WHERE drop_id = ?
                ]],
                {
                    tostring(dropId)
                }
            )
        end

        UpdateInventory(
            source,
            inventory
        )

        SaveInventory(
            source,
            inventory
        )

        SendGroundUpdate(source)

        TriggerClientEvent(
            'qb-inventory:client:notify',
            source,
            ('Picked up %sx %s.'):format(
                amount,
                groundItem.label or groundItem.name
            ),
            'success'
        )
    end
)


-- =========================================================
-- EXECUTE QBCORE USABLE ITEM
-- =========================================================

local function ExecuteUsableItem(source, item)
    if not item or not item.name then
        return false
    end

    local itemName = tostring(item.name):lower()

    local usable = nil

    -- Use the actual QBCore usable-item registry.
    if QBCore.Functions.CanUseItem then
        local success, result = pcall(
            QBCore.Functions.CanUseItem,
            itemName
        )

        if not success then
            print((
                '^1[qb-inventory]^7 CanUseItem error for %s: %s'
            ):format(
                itemName,
                tostring(result)
            ))

            return false
        end

        usable = result
    end

    if not usable then
        print((
            '^3[qb-inventory]^7 No usable handler registered for: %s'
        ):format(itemName))

        TriggerClientEvent(
            'qb-inventory:client:notify',
            source,
            'This item cannot be used right now.',
            'error'
        )

        return false
    end

    local callback = nil

    -- Your QBCore stores usable items like:
    --
    -- QBCore.UsableItems[item] = {
    --     func = callback,
    --     resource = resource
    -- }

    if type(usable) == 'table'
        and type(usable.func) == 'function'
    then
        callback = usable.func

    elseif type(usable) == 'function' then
        callback = usable
    end

    if not callback then
        print((
            '^1[qb-inventory]^7 Usable item %s has no valid callback.'
        ):format(itemName))

        TriggerClientEvent(
            'qb-inventory:client:notify',
            source,
            'This item cannot be used right now.',
            'error'
        )

        return false
    end

    local success, result = pcall(
        callback,
        source,
        item
    )

    if not success then
        print((
            '^1[qb-inventory]^7 Error using %s: %s'
        ):format(
            itemName,
            tostring(result)
        ))

        TriggerClientEvent(
            'qb-inventory:client:notify',
            source,
            'There was an error using this item.',
            'error'
        )

        return false
    end

    -- A usable callback can explicitly return false
    -- to tell the inventory that the item wasn't used.
    if result == false then
        return false
    end

    debugPrint((
        'Successfully used usable item %s for player %s.'
    ):format(
        itemName,
        source
    ))

    return true
end


-- =========================================================
-- ID CARD
-- =========================================================

local function UseIdCard(source, itemData)

    local Player = getPlayer(source)

    if not Player then
        return false
    end

    TriggerClientEvent(
        'qb-inventory:client:itemBox',
        source,
        QBCore.Shared.Items[itemData.name],
        'use',
        1
    )

    local playerPed = GetPlayerPed(source)

    if not playerPed or playerPed <= 0 then
        return false
    end

    local playerCoords = GetEntityCoords(playerPed)

    local players = QBCore.Functions.GetPlayers()

    local info = itemData.info or {}

    local gender = 'Unknown'

    if tonumber(info.gender) == 0 then
        gender = 'Male'
    elseif tonumber(info.gender) == 1 then
        gender = 'Female'
    end

    for _, target in pairs(players) do

        local targetPed = GetPlayerPed(target)

        if targetPed and targetPed > 0 then

            local targetCoords = GetEntityCoords(targetPed)

            local dist = #(playerCoords - targetCoords)

            if dist < 3.0 then

                TriggerClientEvent(
                    'chat:addMessage',
                    target,
                    {
                        template =
                            '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #74807c); display: flex;">' ..
                            '<div style="margin-right: 10px;">' ..
                            '<i class="far fa-id-card" style="height: 100%;"></i>' ..
                            '<strong> {0}</strong><br>' ..
                            '<strong>Civ ID:</strong> {1}<br>' ..
                            '<strong>First Name:</strong> {2}<br>' ..
                            '<strong>Last Name:</strong> {3}<br>' ..
                            '<strong>Birthdate:</strong> {4}<br>' ..
                            '<strong>Gender:</strong> {5}<br>' ..
                            '<strong>Nationality:</strong> {6}' ..
                            '</div></div>',

                        args = {
                            'ID Card',
                            info.citizenid or 'Unknown',
                            info.firstname or 'Unknown',
                            info.lastname or 'Unknown',
                            info.birthdate or 'Unknown',
                            gender,
                            info.nationality or 'Unknown'
                        }
                    }
                )

            end
        end
    end

    return true
end


-- =========================================================
-- DRIVER LICENSE
-- =========================================================

local function UseDriverLicense(source, itemData)

    local Player = getPlayer(source)

    if not Player then
        return false
    end

    TriggerClientEvent(
        'qb-inventory:client:itemBox',
        source,
        QBCore.Shared.Items[itemData.name],
        'use',
        1
    )

    local playerPed = GetPlayerPed(source)

    if not playerPed or playerPed <= 0 then
        return false
    end

    local playerCoords = GetEntityCoords(playerPed)

    local players = QBCore.Functions.GetPlayers()

    local info = itemData.info or {}

    for _, target in pairs(players) do

        local targetPed = GetPlayerPed(target)

        if targetPed and targetPed > 0 then

            local targetCoords = GetEntityCoords(targetPed)

            local dist = #(playerCoords - targetCoords)

            if dist < 3.0 then

                TriggerClientEvent(
                    'chat:addMessage',
                    target,
                    {
                        template =
                            '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #657175); display: flex;">' ..
                            '<div style="margin-right: 10px;">' ..
                            '<i class="far fa-id-card" style="height: 100%;"></i>' ..
                            '<strong> {0}</strong><br>' ..
                            '<strong>First Name:</strong> {1}<br>' ..
                            '<strong>Last Name:</strong> {2}<br>' ..
                            '<strong>Birth Date:</strong> {3}<br>' ..
                            '<strong>Licenses:</strong> {4}' ..
                            '</div></div>',

                        args = {
                            'Drivers License',
                            info.firstname or 'Unknown',
                            info.lastname or 'Unknown',
                            info.birthdate or 'Unknown',
                            info.type or 'Unknown'
                        }
                    }
                )

            end
        end
    end

    return true
end


-- =========================================================
-- USE ITEM
-- =========================================================

RegisterNetEvent(
    'qb-inventory:server:use',
    function(slot)
        local source = source

        local Player = getPlayer(source)

        if not Player then
            return
        end

        slot = tonumber(slot)

        if not slot
            or slot < 1
            or slot > Config.MaxSlots
        then
            return
        end

        local inventory = OpenInventories[source]

        if not inventory then

            inventory = LoadInventory(source)

            OpenInventories[source] = inventory
        end

        inventory = NormalizeInventory(inventory)

        local itemData = inventory[slot]

        if not itemData then

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'There is no item in that slot.',
                'error'
            )

            return
        end

        -- =================================================
        -- WEAPONS
        -- =================================================

        if itemData.type == 'weapon' then

            local shootable = true

            if itemData.info
                and itemData.info.quality ~= nil
            then
                shootable =
                    (tonumber(itemData.info.quality) or 0) > 0
            end

            TriggerClientEvent(
                'qb-inventory:client:DrawWeapon',
                source,
                itemData,
                shootable
            )

            TriggerClientEvent(
                'qb-inventory:client:itemBox',
                source,
                QBCore.Shared.Items[itemData.name],
                'use',
                1
            )

            return
        end

        -- =================================================
        -- ID CARD
        -- =================================================

        if itemData.name == 'id_card' then

            UseIdCard(
                source,
                itemData
            )

            return
        end

        -- =================================================
        -- DRIVER LICENSE
        -- =================================================

        if itemData.name == 'driver_license' then

            UseDriverLicense(
                source,
                itemData
            )

            return
        end

        -- =================================================
        -- NORMAL QBCORE USABLE ITEM
        -- =================================================

        local used = ExecuteUsableItem(
            source,
            itemData
        )

        if not used then
            return
        end

        -- =================================================
        -- IMPORTANT
        --
        -- We DO NOT remove the item here.
        --
        -- The usable resource is responsible for doing:
        --
        -- Player.Functions.RemoveItem(...)
        --
        -- or otherwise changing PlayerData.items.
        --
        -- This prevents food/drinks/etc. being removed twice.
        -- =================================================

        TriggerClientEvent(
            'qb-inventory:client:itemBox',
            source,
            QBCore.Shared.Items[itemData.name],
            'use',
            1
        )

        -- Give the usable callback a moment to update
        -- PlayerData.items before syncing our inventory.
        Wait(50)

        local latest = Player.PlayerData.items

        if type(latest) == 'table' then

            latest = NormalizeInventory(latest)

            OpenInventories[source] = latest

            TriggerClientEvent(
                'qb-inventory:client:update',
                source,
                latest
            )

            SaveInventory(
                source,
                latest
            )

        else

            -- If the usable callback didn't modify the
            -- player's inventory, keep our existing copy.
            debugPrint((
                'Usable item %s did not return a PlayerData inventory table.'
            ):format(itemData.name))

        end
    end
)

-- =========================================================
-- HOTBAR USE
-- =========================================================

RegisterNetEvent(
    'qb-inventory:server:useSlot',
    function(slot)

        local source = source

        slot = tonumber(slot)

        if not slot
            or slot < 1
            or slot > 5
        then
            return
        end

        local Player = getPlayer(source)

        if not Player then
            return
        end

        -- Dead / last stand / handcuffed protection
        local metadata = Player.PlayerData.metadata

        if metadata then

            if metadata.isdead
                or metadata.inlaststand
                or metadata.ishandcuffed
            then
                return
            end

        end

        local inventory = OpenInventories[source]

        if not inventory then

            inventory = LoadInventory(source)

            OpenInventories[source] = inventory

        end

        inventory = NormalizeInventory(inventory)

        local item = inventory[slot]

        if not item then
            return
        end

        -- =================================================
        -- WEAPON
        -- =================================================

        if item.type == 'weapon' then

            local shootable = true

            if item.info
                and item.info.quality ~= nil
            then
                shootable =
                    (tonumber(item.info.quality) or 0) > 0
            end

            TriggerClientEvent(
                'qb-inventory:client:DrawWeapon',
                source,
                item,
                shootable
            )

            return
        end

        -- =================================================
        -- ID CARD
        -- =================================================

        if item.name == 'id_card' then

            UseIdCard(
                source,
                item
            )

            return
        end

        -- =================================================
        -- DRIVER LICENSE
        -- =================================================

        if item.name == 'driver_license' then

            UseDriverLicense(
                source,
                item
            )

            return
        end

        -- =================================================
        -- NORMAL USABLE ITEM
        -- =================================================

        local used = ExecuteUsableItem(
            source,
            item
        )

        if not used then
            return
        end

        Wait(50)

        local latest = Player.PlayerData.items

        if type(latest) == 'table' then

            latest = NormalizeInventory(latest)

            OpenInventories[source] = latest

            TriggerClientEvent(
                'qb-inventory:client:update',
                source,
                latest
            )

            SaveInventory(
                source,
                latest
            )

        end
    end
)


-- =========================================================
-- GIVE ITEM
-- =========================================================

RegisterNetEvent(
    'qb-inventory:server:give',
    function(
        targetId,
        sourceSlot,
        amount
    )

        local source =
            source

        targetId =
            tonumber(targetId)

        sourceSlot =
            tonumber(sourceSlot)

        amount =
            tonumber(amount) or 1

        if not targetId
            or not sourceSlot
            or amount <= 0 then

            return
        end

        local SourcePlayer =
            getPlayer(source)

        local TargetPlayer =
            getPlayer(targetId)

        if not SourcePlayer
            or not TargetPlayer then

            return
        end

        local sourcePed =
            GetPlayerPed(source)

        local targetPed =
            GetPlayerPed(targetId)

        if not sourcePed
            or not targetPed
            or sourcePed <= 0
            or targetPed <= 0 then

            return
        end

        local sourceCoords =
            GetEntityCoords(sourcePed)

        local targetCoords =
            GetEntityCoords(targetPed)

        local distance =
            #(sourceCoords - targetCoords)

        if distance > 5.0 then

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'That player is too far away.',
                'error'
            )

            return
        end

        local sourceInventory =
            OpenInventories[source]

        if not sourceInventory then

            sourceInventory =
                LoadInventory(source)

            OpenInventories[source] =
                sourceInventory
        end

        local targetInventory =
            OpenInventories[targetId]

        if not targetInventory then

            targetInventory =
                LoadInventory(targetId)

            OpenInventories[targetId] =
                targetInventory
        end

        local sourceItem =
            sourceInventory[sourceSlot]

        if not sourceItem then

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'You do not have that item.',
                'error'
            )

            return
        end

        local sourceAmount =
            tonumber(sourceItem.amount) or 0

        if amount > sourceAmount then
            return
        end

        local sharedItem =
            QBCore.Shared.Items[sourceItem.name]

        if not sharedItem then
            return
        end

        local currentWeight =
            GetInventoryWeight(targetInventory)

        local addedWeight =
            (tonumber(sourceItem.weight) or 0)
            * amount

        if currentWeight + addedWeight
            > Config.MaxWeight then

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'That player does not have enough inventory weight.',
                'error'
            )

            TriggerClientEvent(
                'qb-inventory:client:notify',
                targetId,
                'Your inventory is too heavy to receive that item.',
                'error'
            )

            return
        end

        local targetSlot

        if not sharedItem.unique then

            for slot, item in pairs(targetInventory) do

                if item
                    and item.name == sourceItem.name
                    and not item.unique then

                    targetSlot =
                        tonumber(slot)

                    break
                end
            end
        end

        if not targetSlot then

            targetSlot =
                GetFreeSlot(targetInventory)
        end

        if not targetSlot then

            TriggerClientEvent(
                'qb-inventory:client:notify',
                source,
                'The player has no free inventory slots.',
                'error'
            )

            TriggerClientEvent(
                'qb-inventory:client:notify',
                targetId,
                'Your inventory is full.',
                'error'
            )

            return
        end

        if sourceItem.type == 'weapon' then

            local sourceWeapon =
                GetSelectedPedWeapon(sourcePed)

            local weaponInfo =
                QBCore.Shared.Weapons[sourceWeapon]

            if weaponInfo
                and weaponInfo.name == sourceItem.name then

                RemoveWeaponFromPed(
                    sourcePed,
                    sourceWeapon
                )

                TriggerClientEvent(
                    'qb-inventory:client:DrawWeapon',
                    source,
                    {
                        name = sourceItem.name,
                        info = sourceItem.info or {}
                    },
                    false
                )
            end
        end

        sourceItem.amount =
            sourceAmount - amount

        if sourceItem.amount <= 0 then
            sourceInventory[sourceSlot] =
                nil
        end

        if targetInventory[targetSlot]
            and targetInventory[targetSlot].name
                == sourceItem.name
            and not sharedItem.unique then

            targetInventory[targetSlot].amount =
                (
                    tonumber(
                        targetInventory[targetSlot].amount
                    ) or 0
                )
                + amount

        else

            local newItem = {}

            for key, value in pairs(sourceItem) do
                newItem[key] =
                    value
            end

            newItem.slot =
                targetSlot

            newItem.amount =
                amount

            targetInventory[targetSlot] =
                newItem
        end

        UpdateInventory(
            source,
            sourceInventory
        )

        SaveInventory(
            source,
            sourceInventory
        )

        UpdateInventory(
            targetId,
            targetInventory
        )

        SaveInventory(
            targetId,
            targetInventory
        )

        local sourceName =
            GetPlayerName(source)
            or 'Player'

        local targetName =
            GetPlayerName(targetId)
            or 'Player'

        TriggerClientEvent(
            'qb-inventory:client:notify',
            source,
            ('Gave %sx %s to %s.'):format(
                amount,
                sharedItem.label or sourceItem.name,
                targetName
            ),
            'success'
        )

        TriggerClientEvent(
            'qb-inventory:client:notify',
            targetId,
            ('You received %sx %s.'):format(
                amount,
                sharedItem.label or sourceItem.name
            ),
            'success'
        )

        TriggerClientEvent(
            'qb-inventory:client:itemBox',
            source,
            sharedItem,
            'remove',
            amount
        )

        TriggerClientEvent(
            'qb-inventory:client:itemBox',
            targetId,
            sharedItem,
            'add',
            amount
        )

        print(
            ('[qb-inventory] %s (%s) gave %sx %s to %s (%s).')
            :format(
                sourceName,
                source,
                amount,
                sourceItem.name,
                targetName,
                targetId
            )
        )
    end
)


-- =========================================================
-- GET INVENTORY CALLBACK
-- =========================================================

QBCore.Functions.CreateCallback(
    'qb-inventory:server:getInventory',
    function(source, cb)

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end

        cb(
            inventory or {}
        )
    end
)


-- =========================================================
-- QBCORE PLAYER UNLOAD
-- =========================================================

RegisterNetEvent(
    'QBCore:Server:OnPlayerUnload',
    function()

        local source =
            source

        local inventory =
            OpenInventories[source]


        -- =====================================================
        -- NO CACHE
        --
        -- Do NOT attempt to save Player.PlayerData.items here.
        --
        -- During multicharacter switching QBCore can temporarily
        -- have an empty PlayerData.items table. Saving that would
        -- wipe the real database inventory.
        -- =====================================================

        if not inventory then

            debugPrint(
                ('QBCore unload for %s but no cached inventory exists. Database inventory will be preserved.')
                :format(
                    GetPlayerName(source) or source
                )
            )

            return
        end


        -- =====================================================
        -- SAVE CACHED INVENTORY
        -- =====================================================

        debugPrint(
            ('QBCore player unload detected for %s. Saving cached inventory...')
            :format(source)
        )

        local success =
            SaveInventory(
                source,
                inventory
            )


        if success then

            debugPrint(
                ('Inventory successfully saved during QBCore unload for %s.')
                :format(source)
            )

        else

            print(
                ('^1[qb-inventory]^7 FAILED to save inventory during QBCore unload for %s.')
                :format(source)
            )
        end


        -- IMPORTANT:
        --
        -- Do NOT delete OpenCitizenIds here.
        --
        -- qb-multichara can still need the citizen ID while
        -- switching characters.
    end
)


-- =========================================================
-- PLAYER DROPPED
-- =========================================================

AddEventHandler(
    'playerDropped',
    function()

        local source =
            source

        local inventory =
            OpenInventories[source]

        if inventory then

            debugPrint(
                ('Player %s disconnected. Saving inventory...')
                :format(source)
            )

            SaveInventory(
                source,
                inventory
            )

        else

            debugPrint(
                ('Player %s disconnected with no cached inventory.')
                :format(source)
            )
        end

        OpenInventories[source] =
            nil

        OpenCitizenIds[source] =
            nil
    end
)


-- =========================================================
-- RESOURCE STOP
-- =========================================================

AddEventHandler(
    'onResourceStop',
    function(resourceName)

        if resourceName
            ~= GetCurrentResourceName() then

            return
        end

        print(
            '^3[qb-inventory]^7 Resource stopping. Saving open inventories...'
        )

        for source, inventory
            in pairs(OpenInventories) do

            SaveInventory(
                source,
                inventory
            )
        end

        print(
            '^2[qb-inventory]^7 Open inventories saved.'
        )
    end
)


-- =========================================================
-- /GIVEITEM
-- =========================================================

QBCore.Commands.Add(
    'giveitem',
    'Give an item to a player',
    {
        {
            name = 'id',
            help = 'Player server ID'
        },
        {
            name = 'item',
            help = 'Item name'
        },
        {
            name = 'amount',
            help = 'Amount'
        }
    },
    true,

    function(source, args)

        local targetId =
            tonumber(args[1])

        local itemName =
            args[2]

        local amount =
            tonumber(args[3]) or 1

        if not targetId then

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                'Usage: /giveitem [id] [item] [amount]',
                'error'
            )

            return
        end

        if not itemName then

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                'You must specify an item.',
                'error'
            )

            return
        end

        if amount < 1 then

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                'Amount must be at least 1.',
                'error'
            )

            return
        end

        itemName =
            string.lower(
                tostring(itemName)
            )

        local sharedItem =
            QBCore.Shared.Items[itemName]

        if not sharedItem then

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                ('Unknown item: %s'):format(itemName),
                'error'
            )

            return
        end

        local TargetPlayer =
            QBCore.Functions.GetPlayer(targetId)

        if not TargetPlayer then

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                'That player is not online.',
                'error'
            )

            return
        end

        OpenCitizenIds[targetId] =
            TargetPlayer.PlayerData.citizenid

        local inventory =
            OpenInventories[targetId]

        if not inventory then

            inventory =
                LoadInventory(targetId)

            OpenInventories[targetId] =
                inventory
        end

        inventory =
            NormalizeInventory(inventory)

        local itemWeight =
            tonumber(sharedItem.weight)
            or 0

        local currentWeight =
            GetInventoryWeight(inventory)

        local addedWeight =
            itemWeight * amount

        if currentWeight + addedWeight
            > Config.MaxWeight then

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                'The player does not have enough inventory weight.',
                'error'
            )

            TriggerClientEvent(
                'QBCore:Notify',
                targetId,
                'Your inventory is too heavy to receive an item.',
                'error'
            )

            return
        end

        local targetSlot

        if not sharedItem.unique then

            for slot, item in pairs(inventory) do

                if item
                    and item.name == itemName
                    and not item.unique then

                    targetSlot =
                        tonumber(slot)

                    break
                end
            end
        end

        if not targetSlot then

            targetSlot =
                GetFreeSlot(inventory)
        end

        if not targetSlot then

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                'The player has no free inventory slots.',
                'error'
            )

            TriggerClientEvent(
                'QBCore:Notify',
                targetId,
                'Your inventory is full.',
                'error'
            )

            return
        end

        if inventory[targetSlot]
            and inventory[targetSlot].name
                == itemName
            and not sharedItem.unique then

            inventory[targetSlot].amount =
                (
                    tonumber(
                        inventory[targetSlot].amount
                    ) or 0
                )
                + amount

        else

            inventory[targetSlot] = {

                name =
                    itemName,

                amount =
                    amount,

                info =
                    {},

                type =
                    sharedItem.type
                    or 'item',

                slot =
                    targetSlot,

                label =
                    sharedItem.label
                    or itemName,

                description =
                    sharedItem.description
                    or '',

                weight =
                    itemWeight,

                unique =
                    sharedItem.unique
                    or false,

                useable =
                    sharedItem.useable
                    or false,

                image =
                    sharedItem.image
                    or (itemName .. '.png'),

                shouldClose =
                    sharedItem.shouldClose
                    or false
            }
        end

        UpdateInventory(
            targetId,
            inventory
        )

        SaveInventory(
            targetId,
            inventory
        )

        local senderName =
            GetPlayerName(source)
            or 'Console'

        local targetName =
            GetPlayerName(targetId)
            or 'Player'

        TriggerClientEvent(
            'QBCore:Notify',
            source,
            ('Gave %sx %s to %s.'):format(
                amount,
                sharedItem.label or itemName,
                targetName
            ),
            'success'
        )

        TriggerClientEvent(
            'QBCore:Notify',
            targetId,
            ('You received %sx %s.'):format(
                amount,
                sharedItem.label or itemName
            ),
            'success'
        )

        print(
            ('[qb-inventory] %s (%s) gave %sx %s to %s (%s).')
            :format(
                senderName,
                source,
                amount,
                itemName,
                targetName,
                targetId
            )
        )
    end,

    'admin'
)


-- =========================================================
-- EXPORT: LOAD INVENTORY
-- =========================================================

exports(
    'LoadInventory',
    function(source)

        source =
            tonumber(source)

        if not source then
            return {}
        end

        local inventory =
            LoadInventory(source)

        OpenInventories[source] =
            inventory or {}

        local citizenid =
            GetCitizenId(source)

        if citizenid then
            OpenCitizenIds[source] =
                citizenid
        end

        return inventory or {}
    end
)


-- =========================================================
-- EXPORT: SAVE INVENTORY
-- =========================================================

exports(
    'SaveInventory',
    function(source, inventory)

        source =
            tonumber(source)

        if not source then
            return false
        end


        -- =====================================================
        -- IF NO INVENTORY WAS PROVIDED
        --
        -- Always prefer our own cached inventory.
        --
        -- This is important because QBCore PlayerData.items
        -- can temporarily become empty during character
        -- switching/unloading.
        -- =====================================================

        if type(inventory) ~= 'table' then

            if OpenInventories[source] then

                inventory =
                    OpenInventories[source]

            else

                local Player =
                    getPlayer(source)

                if Player then

                    inventory =
                        Player.PlayerData.items
                        or {}

                else

                    inventory =
                        {}
                end
            end
        end


        -- =====================================================
        -- SAVE
        -- =====================================================

        local success =
            SaveInventory(
                source,
                inventory
            )


        -- =====================================================
        -- KEEP CACHE IN SYNC
        -- =====================================================

        if success then

            OpenInventories[source] =
                NormalizeInventory(inventory)
        end


        return success
    end
)

-- =========================================================
-- EXPORT: USE ITEM
-- QBCORE COMPATIBILITY
-- =========================================================

exports('UseItem', function(source, itemName)

    source = tonumber(source)

    if not source then
        return false
    end

    local Player = getPlayer(source)

    if not Player then
        return false
    end

    if not itemName then
        return false
    end

    itemName = tostring(itemName):lower()

    local inventory = OpenInventories[source]

    if not inventory then

        inventory = LoadInventory(source)

        OpenInventories[source] = inventory

    end

    inventory = NormalizeInventory(inventory)

    local itemData = nil

    for _, item in pairs(inventory) do

        if item
            and item.name
            and item.name:lower() == itemName
        then

            itemData = item

            break
        end

    end

    if not itemData then

        TriggerClientEvent(
            'qb-inventory:client:notify',
            source,
            'You do not have that item.',
            'error'
        )

        return false
    end

    -- Weapon
    if itemData.type == 'weapon' then

        local shootable = true

        if itemData.info
            and itemData.info.quality ~= nil
        then
            shootable =
                (tonumber(itemData.info.quality) or 0) > 0
        end

        TriggerClientEvent(
            'qb-inventory:client:DrawWeapon',
            source,
            itemData,
            shootable
        )

        return true
    end

    -- ID
    if itemData.name == 'id_card' then

        return UseIdCard(
            source,
            itemData
        )

    end

    -- Driver licence
    if itemData.name == 'driver_license' then

        return UseDriverLicense(
            source,
            itemData
        )

    end

    -- Normal usable
    local used = ExecuteUsableItem(
        source,
        itemData
    )

    if not used then
        return false
    end

    Wait(50)

    local latest = Player.PlayerData.items

    if type(latest) == 'table' then

        latest = NormalizeInventory(latest)

        OpenInventories[source] = latest

        TriggerClientEvent(
            'qb-inventory:client:update',
            source,
            latest
        )

        SaveInventory(
            source,
            latest
        )

    end

    return true
end)

-- =========================================================
-- EXPORT: GET INVENTORY
-- =========================================================

exports(
    'GetInventory',
    function(source)

        source =
            tonumber(source)

        if not source then
            return {}
        end

        if OpenInventories[source] then
            return OpenInventories[source]
        end

        local inventory =
            LoadInventory(source)

        OpenInventories[source] =
            inventory or {}

        return inventory or {}
    end
)
-- =========================================================
-- QBCORE COMPATIBILITY: ADD ITEM
-- =========================================================

exports('AddItem', function(source, itemName, amount, slot, info, reason)
    source = tonumber(source)
    amount = tonumber(amount) or 1

    if not source then
        return false
    end

    if amount <= 0 then
        return false
    end

    itemName = tostring(itemName or ''):lower()

    if itemName == '' then
        return false
    end

    -- Make sure the item exists in QBCore
    local sharedItem = QBCore.Shared.Items[itemName]

    if not sharedItem then
        print(('[qb-inventory] AddItem failed: item "%s" does not exist in QBCore.Shared.Items.'):format(itemName))
        return false
    end

    local Player = getPlayer(source)

    if not Player then
        print(('[qb-inventory] AddItem failed: player %s does not exist.'):format(source))
        return false
    end

    -- Load inventory if it isn't cached
    local inventory = OpenInventories[source]

    if not inventory then
        inventory = LoadInventory(source)

        if not inventory then
            inventory = {}
        end

        OpenInventories[source] = inventory
    end

    inventory = NormalizeInventory(inventory)

    -- Convert slot to number if supplied
    if slot ~= nil then
        slot = tonumber(slot)
    end

    -- =====================================================
    -- FIND EXISTING STACK
    -- =====================================================

    if not sharedItem.unique then
        if slot and inventory[slot] then
            local existing = inventory[slot]

            if existing.name == itemName then
                existing.amount = (tonumber(existing.amount) or 0) + amount

                inventory[slot] = normalizeItem(
                    existing,
                    itemName
                )

                UpdateInventory(source, inventory)
                SaveInventory(source, inventory)

                TriggerClientEvent(
                    'qb-inventory:client:itemBox',
                    source,
                    sharedItem,
                    'add',
                    amount
                )

                return true
            end
        end

        -- Search existing stacks
        for existingSlot, existing in pairs(inventory) do
            if existing
                and existing.name == itemName
                and not sharedItem.unique
            then
                existing.amount =
                    (tonumber(existing.amount) or 0) + amount

                inventory[existingSlot] =
                    normalizeItem(existing, itemName)

                UpdateInventory(source, inventory)
                SaveInventory(source, inventory)

                TriggerClientEvent(
                    'qb-inventory:client:itemBox',
                    source,
                    sharedItem,
                    'add',
                    amount
                )

                return true
            end
        end
    end

    -- =====================================================
    -- FIND SLOT
    -- =====================================================

    if not slot then
        slot = GetFreeSlot(inventory)
    end

    if not slot then
        print(('[qb-inventory] AddItem failed: inventory full for player %s.'):format(source))

        TriggerClientEvent(
            'qb-inventory:client:notify',
            source,
            'Your inventory is full.',
            'error'
        )

        return false
    end

    -- Don't overwrite another item when a specific slot was requested
    if inventory[slot] then
        print((
            '[qb-inventory] AddItem failed: slot %s is occupied for player %s.'
        ):format(slot, source))

        return false
    end

    -- =====================================================
    -- WEIGHT CHECK
    -- =====================================================

    local itemWeight =
        (tonumber(sharedItem.weight) or 0) * amount

    local currentWeight =
        GetInventoryWeight(inventory)

    local maxWeight =
        tonumber(Config.MaxWeight) or 0

    if maxWeight > 0
        and (currentWeight + itemWeight) > maxWeight
    then
        TriggerClientEvent(
            'qb-inventory:client:notify',
            source,
            'Your inventory is too heavy.',
            'error'
        )

        return false
    end

    -- =====================================================
    -- CREATE ITEM
    -- =====================================================

    local itemInfo = info or {}

    local newItem = {
        name = itemName,
        label = sharedItem.label,
        weight = sharedItem.weight,
        type = sharedItem.type or 'item',
        image = sharedItem.image,
        unique = sharedItem.unique or false,
        useable = sharedItem.useable or false,
        shouldClose = sharedItem.shouldClose ~= false,
        description = sharedItem.description or '',
        amount = amount,
        info = itemInfo,
        slot = slot
    }

    inventory[slot] = normalizeItem(
        newItem,
        itemName
    )

    -- =====================================================
    -- SAVE / SYNC
    -- =====================================================

    OpenInventories[source] = inventory

    UpdateInventory(source, inventory)

    SaveInventory(source, inventory)

    TriggerClientEvent(
        'qb-inventory:client:itemBox',
        source,
        sharedItem,
        'add',
        amount
    )

    debugPrint((
        'Added %sx %s to player %s in slot %s.'
    ):format(
        amount,
        itemName,
        source,
        slot
    ))

    return true
end)


-- =========================================================
-- QBCORE COMPATIBILITY
-- REMOVE ITEM
-- =========================================================

exports(
    'RemoveItem',
    function(source, itemName, amount, slot, reason)

        source = tonumber(source)
        amount = tonumber(amount) or 1

        if not source then
            return false
        end

        if not itemName then
            return false
        end

        itemName =
            tostring(itemName):lower()

        if amount <= 0 then
            return false
        end

        local Player =
            getPlayer(source)

        if not Player then
            return false
        end

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end

        inventory =
            NormalizeInventory(inventory)


        -- =====================================================
        -- FIND ITEMS
        -- =====================================================

        local remaining =
            amount

        local requestedSlot =
            tonumber(slot)

        local slots = {}


        -- =====================================================
        -- SPECIFIC SLOT
        -- =====================================================

        if requestedSlot
            and inventory[requestedSlot]
            and inventory[requestedSlot].name == itemName
        then

            slots[#slots + 1] =
                requestedSlot

        else

            -- =================================================
            -- SEARCH ALL STACKS
            -- =================================================

            for inventorySlot, item
                in pairs(inventory)
            do

                if item
                    and item.name == itemName
                then

                    slots[#slots + 1] =
                        tonumber(inventorySlot)

                end
            end
        end


        -- =====================================================
        -- CHECK TOTAL
        -- =====================================================

        local available =
            0

        for _, inventorySlot
            in ipairs(slots)
        do

            local item =
                inventory[inventorySlot]

            if item then

                available =
                    available
                    + (
                        tonumber(item.amount)
                        or 0
                    )

            end
        end


        if available < amount then

            debugPrint(
                ('RemoveItem failed - player %s only has %s %s.')
                :format(
                    source,
                    available,
                    itemName
                )
            )

            return false
        end


        -- =====================================================
        -- REMOVE
        -- =====================================================

        for _, inventorySlot
            in ipairs(slots)
        do

            if remaining <= 0 then
                break
            end

            local item =
                inventory[inventorySlot]

            if item then

                local itemAmount =
                    tonumber(item.amount)
                    or 0

                local removing =
                    math.min(
                        itemAmount,
                        remaining
                    )

                item.amount =
                    itemAmount - removing

                remaining =
                    remaining - removing

                if item.amount <= 0 then

                    inventory[inventorySlot] =
                        nil

                end

            end
        end


        -- =====================================================
        -- UPDATE
        -- =====================================================

        inventory =
            NormalizeInventory(inventory)

        UpdateInventory(
            source,
            inventory
        )


        -- =====================================================
        -- SAVE
        -- =====================================================

        local saved =
            SaveInventory(
                source,
                inventory
            )

        if not saved then

            return false

        end


        -- =====================================================
        -- ITEM BOX
        -- =====================================================

        local sharedItem =
            QBCore.Shared.Items[itemName]

        if sharedItem then

            TriggerClientEvent(
                'qb-inventory:client:itemBox',
                source,
                sharedItem,
                'remove',
                amount
            )

        end


        debugPrint(
            ('Removed %sx %s from player %s. Reason: %s')
            :format(
                amount,
                itemName,
                source,
                tostring(reason or 'unknown')
            )
        )


        return true
    end
)


-- =========================================================
-- QBCORE COMPATIBILITY
-- GET ITEM BY SLOT
-- =========================================================

exports(
    'GetItemBySlot',
    function(source, slot)

        source =
            tonumber(source)

        slot =
            tonumber(slot)

        if not source or not slot then
            return nil
        end

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end

        return inventory[slot]
    end
)


-- =========================================================
-- QBCORE COMPATIBILITY
-- GET ITEM BY NAME
-- =========================================================

exports(
    'GetItemByName',
    function(source, itemName)

        source =
            tonumber(source)

        if not source or not itemName then
            return nil
        end

        itemName =
            tostring(itemName):lower()

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end

        for _, item in pairs(inventory) do

            if item
                and item.name
                and item.name:lower() == itemName
            then

                return item

            end
        end

        return nil
    end
)


-- =========================================================
-- QBCORE COMPATIBILITY
-- GET ITEMS BY NAME
-- =========================================================

exports(
    'GetItemsByName',
    function(source, itemName)

        source =
            tonumber(source)

        if not source or not itemName then
            return {}
        end

        itemName =
            tostring(itemName):lower()

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end

        local result = {}

        for _, item in pairs(inventory) do

            if item
                and item.name
                and item.name:lower() == itemName
            then

                result[#result + 1] =
                    item

            end
        end

        return result
    end
)


-- =========================================================
-- QBCORE COMPATIBILITY
-- HAS ITEM
-- =========================================================

exports(
    'HasItem',
    function(source, items, amount)

        source =
            tonumber(source)

        amount =
            tonumber(amount) or 1

        if not source then
            return false
        end

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end


        -- =====================================================
        -- STRING
        -- =====================================================

        if type(items) == 'string' then

            local wanted =
                items:lower()

            local count =
                0

            for _, item
                in pairs(inventory)
            do

                if item
                    and item.name
                    and item.name:lower() == wanted
                then

                    count =
                        count
                        + (
                            tonumber(item.amount)
                            or 0
                        )

                end
            end

            return count >= amount
        end


        -- =====================================================
        -- TABLE
        -- =====================================================

        if type(items) == 'table' then

            -- Map:
            -- { water_bottle = 2, sandwich = 1 }

            for key, value in pairs(items) do

                local itemName
                local required

                if type(key) == 'number' then

                    itemName =
                        tostring(value)

                    required = 1

                else

                    itemName =
                        tostring(key)

                    required =
                        tonumber(value) or 1

                end

                if not exports['qb-inventory']:HasItem(
                    source,
                    itemName,
                    required
                ) then

                    return false

                end
            end

            return true
        end

        return false
    end
)


-- =========================================================
-- QBCORE COMPATIBILITY
-- SET ITEM
-- =========================================================

exports(
    'SetItem',
    function(source, itemName, amount, slot, info, reason)

        source =
            tonumber(source)

        amount =
            tonumber(amount) or 0

        slot =
            tonumber(slot)

        if not source
            or not itemName
            or not slot
        then
            return false
        end

        if slot < 1
            or slot > Config.MaxSlots
        then
            return false
        end

        local Player =
            getPlayer(source)

        if not Player then
            return false
        end

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end

        itemName =
            tostring(itemName):lower()

        if amount <= 0 then

            inventory[slot] =
                nil

        else

            local sharedItem =
                QBCore.Shared.Items[itemName]

            if not sharedItem then
                return false
            end

            if type(info) ~= 'table' then
                info = {}
            end

            inventory[slot] = {

                name =
                    itemName,

                amount =
                    amount,

                info =
                    info,

                type =
                    sharedItem.type
                    or 'item',

                slot =
                    slot,

                label =
                    sharedItem.label
                    or itemName,

                description =
                    sharedItem.description
                    or '',

                weight =
                    tonumber(sharedItem.weight)
                    or 0,

                unique =
                    sharedItem.unique
                    or false,

                useable =
                    sharedItem.useable
                    or false,

                image =
                    sharedItem.image
                    or (itemName .. '.png'),

                shouldClose =
                    sharedItem.shouldClose
                    or false
            }
        end

        inventory =
            NormalizeInventory(inventory)

        UpdateInventory(
            source,
            inventory
        )

        return SaveInventory(
            source,
            inventory
        )
    end
)


-- =========================================================
-- QBCORE COMPATIBILITY
-- SET ITEM DATA
-- =========================================================

exports(
    'SetItemData',
    function(source, itemName, key, value)

        source =
            tonumber(source)

        if not source
            or not itemName
            or not key
        then
            return false
        end

        itemName =
            tostring(itemName):lower()

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end

        for _, item in pairs(inventory) do

            if item
                and item.name == itemName
            then

                if type(item.info) ~= 'table' then
                    item.info = {}
                end

                item.info[key] =
                    value

                UpdateInventory(
                    source,
                    inventory
                )

                return SaveInventory(
                    source,
                    inventory
                )
            end
        end

        return false
    end
)


-- =========================================================
-- QBCORE COMPATIBILITY
-- CLEAR INVENTORY
-- =========================================================

exports(
    'ClearInventory',
    function(source, itemsToKeep)

        source =
            tonumber(source)

        if not source then
            return false
        end

        local inventory =
            OpenInventories[source]

        if not inventory then

            inventory =
                LoadInventory(source)

            OpenInventories[source] =
                inventory
        end


        local keep = {}

        if type(itemsToKeep) == 'table' then

            for _, itemName
                in pairs(itemsToKeep)
            do

                keep[
                    tostring(itemName):lower()
                ] = true

            end

        end


        for slot, item
            in pairs(inventory)
        do

            if item
                and item.name
            then

                if not keep[
                    item.name:lower()
                ] then

                    inventory[slot] =
                        nil

                end
            end
        end


        inventory =
            NormalizeInventory(inventory)

        UpdateInventory(
            source,
            inventory
        )

        return SaveInventory(
            source,
            inventory
        )
    end
)