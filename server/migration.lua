local QBCore = exports['qb-core']:GetCoreObject()

local function DecodeInventory(inventory)

    if not inventory then
        return {}
    end

    if type(inventory) == 'table' then
        return inventory
    end

    if type(inventory) == 'string' then

        local success, decoded = pcall(json.decode, inventory)

        if success and decoded then
            return decoded
        end

    end

    return {}

end

local function InventoryHasItems(items)

    if not items then
        return false
    end

    for _, item in pairs(items) do

        if item and item.name and item.amount and item.amount > 0 then
            return true
        end

    end

    return false

end

local function MigratePlayerInventory(citizenid, oldInventory)

    if not citizenid then
        return false
    end

    local items = DecodeInventory(oldInventory)

    if not InventoryHasItems(items) then
        return false
    end

    local existing = MySQL.single.await(
        'SELECT id FROM traves_inventories WHERE citizenid = ?',
        { citizenid }
    )

    if existing then

        print((
            '^3[qb-inventory]^7 Inventory already exists for %s - skipping migration.'
        ):format(citizenid))

        return false

    end

    local encoded = json.encode(items)

    MySQL.insert.await([[
        INSERT INTO traves_inventories
        (
            citizenid,
            inventory,
            maxweight,
            maxslots
        )
        VALUES (?, ?, ?, ?)
    ]], {
        citizenid,
        encoded,
        120000,
        40
    })

    print((
        '^2[qb-inventory]^7 Migrated inventory for %s'
    ):format(citizenid))

    return true

end

CreateThread(function()

    while not IsTravesDatabaseReady() do
        Wait(100)
    end

    print('^3[qb-inventory]^7 Checking existing QBCore inventories...')

    local players = MySQL.query.await([[
        SELECT
            citizenid,
            inventory
        FROM players
        WHERE inventory IS NOT NULL
        AND inventory != ''
    ]])

    if not players then
        print('^2[qb-inventory]^7 No player inventories found.')
        return
    end

    local migrated = 0

    for _, player in ipairs(players) do

        if MigratePlayerInventory(
            player.citizenid,
            player.inventory
        ) then

            migrated = migrated + 1

        end

    end

    print((
        '^2[qb-inventory]^7 Migration complete. %s inventories imported.'
    ):format(migrated))

end)