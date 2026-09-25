local QBCore = exports['qb-core']:GetCoreObject()

local DatabaseReady = false

CreateThread(function()

    print('^3[qb-inventory]^7 Initialising database...')

    -- =========================================================
    -- PLAYER INVENTORIES
    -- =========================================================

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `traves_inventories` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `inventory` LONGTEXT NOT NULL,
            `maxweight` INT NOT NULL DEFAULT 120000,
            `maxslots` INT NOT NULL DEFAULT 40,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- =========================================================
    -- STASHES
    -- =========================================================

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `traves_stashes` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `stash_id` VARCHAR(100) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `inventory` LONGTEXT NOT NULL,
            `maxweight` INT NOT NULL DEFAULT 120000,
            `maxslots` INT NOT NULL DEFAULT 50,
            `owner` VARCHAR(50) DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_stash` (`stash_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- =========================================================
    -- VEHICLE TRUNKS
    -- =========================================================

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `traves_vehicle_inventories` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `plate` VARCHAR(20) NOT NULL,
            `inventory` LONGTEXT NOT NULL,
            `maxweight` INT NOT NULL DEFAULT 120000,
            `maxslots` INT NOT NULL DEFAULT 50,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_plate` (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- =========================================================
    -- GLOVEBOXES
    -- =========================================================

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `traves_gloveboxes` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `plate` VARCHAR(20) NOT NULL,
            `inventory` LONGTEXT NOT NULL,
            `maxweight` INT NOT NULL DEFAULT 50000,
            `maxslots` INT NOT NULL DEFAULT 10,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_glovebox_plate` (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- =========================================================
    -- GROUND DROPS
    -- =========================================================

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `traves_drops` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `drop_id` VARCHAR(100) NOT NULL,
            `items` LONGTEXT NOT NULL,

            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,

            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_drop` (`drop_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- =========================================================
    -- SHOPS
    -- =========================================================

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `traves_shops` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `shop_id` VARCHAR(100) NOT NULL,
            `label` VARCHAR(100) NOT NULL,

            `maxweight` INT NOT NULL DEFAULT 120000,
            `maxslots` INT NOT NULL DEFAULT 50,

            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_shop` (`shop_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- =========================================================
    -- SHOP ITEMS
    -- =========================================================

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `traves_shop_items` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `shop_id` VARCHAR(100) NOT NULL,
            `item` VARCHAR(100) NOT NULL,
            `price` INT NOT NULL DEFAULT 0,
            `amount` INT NOT NULL DEFAULT 0,
            `slot` INT NOT NULL DEFAULT 1,
            `info` LONGTEXT DEFAULT NULL,

            PRIMARY KEY (`id`),

            KEY `shop_id` (`shop_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- =========================================================
    -- ITEM DEFINITIONS
    -- =========================================================

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `traves_items` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(100) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `weight` INT NOT NULL DEFAULT 0,
            `type` VARCHAR(50) NOT NULL DEFAULT 'item',
            `image` VARCHAR(255) DEFAULT NULL,
            `unique_item` TINYINT(1) NOT NULL DEFAULT 0,
            `useable` TINYINT(1) NOT NULL DEFAULT 0,
            `description` TEXT DEFAULT NULL,

            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_item_name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    DatabaseReady = true

    print('^2[qb-inventory]^7 Database initialisation complete.')

end)

function IsTravesDatabaseReady()
    return DatabaseReady
end