local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()

    while not IsTravesDatabaseReady() do
        Wait(100)
    end

    print('^3[qb-inventory]^7 Synchronising QBCore items...')

    local count = 0

    for itemName, item in pairs(QBCore.Shared.Items) do

        if item then

            local name = itemName
            local label = item.label or itemName
            local weight = tonumber(item.weight) or 0
            local type = item.type or 'item'
            local image = item.image or (itemName .. '.png')
            local unique = item.unique and 1 or 0
            local useable = item.useable and 1 or 0
            local description = item.description or ''

            MySQL.query.await([[
                INSERT INTO traves_items
                (
                    name,
                    label,
                    weight,
                    type,
                    image,
                    unique_item,
                    useable,
                    description
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)

                ON DUPLICATE KEY UPDATE
                    label = VALUES(label),
                    weight = VALUES(weight),
                    type = VALUES(type),
                    image = VALUES(image),
                    unique_item = VALUES(unique_item),
                    useable = VALUES(useable),
                    description = VALUES(description)
            ]], {
                name,
                label,
                weight,
                type,
                image,
                unique,
                useable,
                description
            })

            count = count + 1

        end

    end

    print((
        '^2[qb-inventory]^7 Synchronized %s items.'
    ):format(count))

end)