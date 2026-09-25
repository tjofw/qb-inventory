const app = document.getElementById('app');
const grid = document.getElementById('grid');
const groundGrid = document.getElementById('ground-grid');

const weightText = document.getElementById('weight');
const weightFill = document.getElementById('weight-fill');
const playerName = document.getElementById('player-name');

let inventory = {};
let groundItems = [];

let maxSlots = 40;
let maxWeight = 120000;

let selectedSlot = null;
let selectedGroundIndex = null;


// =========================================================
// DRAG SYSTEM
// =========================================================

const DRAG_DISTANCE = 6;

let dragState = {
    active: false,
    started: false,

    type: null,

    sourceSlot: null,
    sourceGroundIndex: null,

    item: null,

    startX: 0,
    startY: 0,

    currentTarget: null,

    ghost: null
};


// =========================================================
// QUEUED SERVER UPDATE
// =========================================================
//
// If the server sends an inventory update while dragging,
// don't throw it away. Store it and apply it after the drag.
// This prevents the UI from rebuilding underneath the mouse.
//

let pendingInventoryUpdate = null;
let pendingGroundUpdate = null;


// =========================================================
// RESOURCE
// =========================================================

function resource() {
    return typeof GetParentResourceName === 'function'
        ? GetParentResourceName()
        : 'qb-inventory';
}


// =========================================================
// NUI POST
// =========================================================

function post(endpoint, data = {}) {
    return fetch(
        `https://${resource()}/${endpoint}`,
        {
            method: 'POST',

            headers: {
                'Content-Type': 'application/json; charset=UTF-8'
            },

            body: JSON.stringify(data)
        }
    ).catch(() => {});
}


// =========================================================
// WEIGHT
// =========================================================

function formatWeight(value) {
    const kg = Number(value || 0) / 1000;

    if (kg >= 100) {
        return `${kg.toFixed(0)} kg`;
    }

    return `${kg.toFixed(1)} kg`;
}


function totalWeight() {
    let total = 0;

    for (let slot = 1; slot <= maxSlots; slot++) {
        const item = getPlayerItem(slot);

        if (!item) {
            continue;
        }

        total +=
            (Number(item.weight) || 0) *
            (Number(item.amount) || 0);
    }

    return total;
}


// =========================================================
// IMAGE
// =========================================================

function imageFor(item) {
    if (!item) {
        return '';
    }

    return `images/${item.image || `${item.name}.png`}`;
}


// =========================================================
// PLAYER ITEM
// =========================================================
//
// IMPORTANT:
//
// QBCore/Lua inventories use slots starting at 1.
//
// When a Lua table is sent to NUI, FiveM can sometimes turn
// a numeric-keyed table into a JavaScript array.
//
// JavaScript arrays start at index 0.
//
// Therefore:
//
// Lua slot 1 -> JS array index 0
// Lua slot 2 -> JS array index 1
// Lua slot 3 -> JS array index 2
//
// This function hides that difference completely.
//
// Every other part of this file MUST use this function.
//

function getPlayerItem(slot) {
    slot = Number(slot);

    if (
        !Number.isInteger(slot) ||
        slot < 1 ||
        slot > maxSlots
    ) {
        return null;
    }


    // -----------------------------------------------------
    // Array inventory
    // -----------------------------------------------------

    if (Array.isArray(inventory)) {
        return inventory[slot - 1] || null;
    }


    // -----------------------------------------------------
    // Object inventory
    // -----------------------------------------------------

    if (
        inventory &&
        typeof inventory === 'object'
    ) {
        return (
            inventory[String(slot)] ||
            inventory[slot] ||
            null
        );
    }

    return null;
}


// =========================================================
// GROUND ITEM
// =========================================================

function getGroundItem(index) {
    index = Number(index);

    if (
        !Number.isInteger(index) ||
        index < 0
    ) {
        return null;
    }

    if (Array.isArray(groundItems)) {
        return groundItems[index] || null;
    }

    if (
        groundItems &&
        typeof groundItems === 'object'
    ) {
        return (
            groundItems[String(index)] ||
            groundItems[index] ||
            null
        );
    }

    return null;
}


// =========================================================
// SELECTION
// =========================================================

function clearSelection() {
    selectedSlot = null;
    selectedGroundIndex = null;

    document
        .querySelectorAll('.slot.selected')
        .forEach(element => {
            element.classList.remove('selected');
        });
}


function selectSlot(slot) {
    slot = Number(slot);

    if (
        !Number.isInteger(slot) ||
        slot < 1 ||
        slot > maxSlots
    ) {
        return;
    }

    selectedSlot = slot;
    selectedGroundIndex = null;

    document
        .querySelectorAll('.slot.selected')
        .forEach(element => {
            element.classList.remove('selected');
        });

    const element = document.querySelector(
        `#grid .slot[data-slot="${slot}"]`
    );

    if (element) {
        element.classList.add('selected');
    }
}


function selectGround(index) {
    index = Number(index);

    if (
        !Number.isInteger(index) ||
        index < 0
    ) {
        return;
    }

    selectedGroundIndex = index;
    selectedSlot = null;

    document
        .querySelectorAll('.slot.selected')
        .forEach(element => {
            element.classList.remove('selected');
        });

    const element = document.querySelector(
        `#ground-grid .slot[data-ground-index="${index}"]`
    );

    if (element) {
        element.classList.add('selected');
    }
}


// =========================================================
// SELECTED ITEMS
// =========================================================

function selectedItem() {
    if (selectedSlot === null) {
        return null;
    }

    return getPlayerItem(selectedSlot);
}


function selectedGroundItem() {
    if (selectedGroundIndex === null) {
        return null;
    }

    return getGroundItem(selectedGroundIndex);
}


// =========================================================
// USE
// =========================================================
//
// Send ONLY the real inventory slot.
// The server decides what item is actually in that slot.
//

function useSelected() {
    const item = selectedItem();

    if (
        !item ||
        selectedSlot === null
    ) {
        return;
    }

    post('UseItem', {
        slot: Number(selectedSlot)
    });
}


// =========================================================
// GIVE
// =========================================================

function giveSelected() {
    const item = selectedItem();

    if (
        !item ||
        selectedSlot === null
    ) {
        return;
    }

    let amount = Number(
        prompt(
            `Amount to give (max ${item.amount})`,
            1
        )
    );

    if (!Number.isFinite(amount)) {
        return;
    }

    amount = Math.floor(amount);

    if (amount < 1) {
        return;
    }

    amount = Math.min(
        amount,
        Number(item.amount) || 1
    );

    post('GiveItem', {
        slot: Number(selectedSlot),
        amount: amount
    });
}


// =========================================================
// DROP
// =========================================================

function dropSelected() {
    const item = selectedItem();

    if (
        !item ||
        selectedSlot === null
    ) {
        return;
    }

    let amount = Number(
        prompt(
            `Amount to drop (max ${item.amount})`,
            1
        )
    );

    if (!Number.isFinite(amount)) {
        return;
    }

    amount = Math.floor(amount);

    if (amount < 1) {
        return;
    }

    amount = Math.min(
        amount,
        Number(item.amount) || 1
    );

    post('DropItem', {
        slot: Number(selectedSlot),
        amount: amount
    });
}


// =========================================================
// PICKUP GROUND
// =========================================================

function pickupSelectedGround() {
    const item = selectedGroundItem();

    if (!item) {
        return;
    }

    const targetSlot =
        findPickupSlot(item);

    if (!targetSlot) {
        return;
    }

    post('PickupGround', {
        dropId: item.dropId,
        groundSlot: item.groundSlot,
        amount: Number(item.amount) || 1,
        targetSlot: Number(targetSlot)
    });
}


// =========================================================
// FIND PICKUP SLOT
// =========================================================

function findPickupSlot(item) {

    // -----------------------------------------------------
    // Try to merge first.
    // -----------------------------------------------------

    if (!item.unique) {

        for (
            let slot = 1;
            slot <= maxSlots;
            slot++
        ) {

            const existing =
                getPlayerItem(slot);

            if (!existing) {
                continue;
            }

            if (
                existing.name === item.name &&
                !existing.unique
            ) {
                return slot;
            }
        }
    }


    // -----------------------------------------------------
    // Find empty slot.
    // -----------------------------------------------------

    for (
        let slot = 1;
        slot <= maxSlots;
        slot++
    ) {

        if (!getPlayerItem(slot)) {
            return slot;
        }
    }

    return null;
}


// =========================================================
// DRAG GHOST
// =========================================================

function removeDragGhost() {

    if (
        dragState.ghost &&
        dragState.ghost.parentNode
    ) {

        dragState.ghost.parentNode.removeChild(
            dragState.ghost
        );
    }

    dragState.ghost = null;
}


function createDragGhost(item) {

    removeDragGhost();

    if (!item) {
        return;
    }

    const ghost =
        document.createElement('div');

    ghost.className =
        'drag-ghost';

    ghost.style.position =
        'fixed';

    ghost.style.pointerEvents =
        'none';

    ghost.style.zIndex =
        '999999';

    const image =
        document.createElement('img');

    image.src =
        imageFor(item);

    image.draggable =
        false;

    image.style.pointerEvents =
        'none';

    image.onerror = () => {
        image.style.display =
            'none';
    };

    ghost.appendChild(image);

    document.body.appendChild(
        ghost
    );

    dragState.ghost =
        ghost;
}


function updateDragGhost(x, y) {

    if (!dragState.ghost) {
        return;
    }

    dragState.ghost.style.left = `${x}px`;
    dragState.ghost.style.top = `${y}px`;

    // Keep the centre of the dragged image directly
    // underneath the FiveM mouse cursor.
    dragState.ghost.style.transform =
        'translate(-50%, -50%)';
}


// =========================================================
// DRAG TARGETS
// =========================================================

function clearDragTargets() {

    document
        .querySelectorAll('.drag-target')
        .forEach(element => {

            element.classList.remove(
                'drag-target'
            );
        });
}


function getDropTarget(x, y) {

    const element =
        document.elementFromPoint(
            x,
            y
        );

    if (!element) {
        return null;
    }

    const slot =
        element.closest('.slot');

    if (!slot) {
        return null;
    }


    // -----------------------------------------------------
    // Player inventory
    // -----------------------------------------------------

    if (
        slot.closest('#grid')
    ) {

        const value =
            Number(
                slot.dataset.slot
            );

        if (
            !Number.isInteger(value) ||
            value < 1
        ) {
            return null;
        }

        return {
            type: 'player',
            slot: value
        };
    }


    // -----------------------------------------------------
    // Ground inventory
    // -----------------------------------------------------

    if (
        slot.closest('#ground-grid')
    ) {

        const value =
            Number(
                slot.dataset.groundIndex
            );

        if (
            !Number.isInteger(value) ||
            value < 0
        ) {
            return null;
        }

        return {
            type: 'ground',
            index: value
        };
    }

    return null;
}


function updateDropTarget(x, y) {

    clearDragTargets();

    dragState.currentTarget =
        null;

    if (
        !dragState.started
    ) {
        return;
    }

    const target =
        getDropTarget(
            x,
            y
        );

    if (!target) {
        return;
    }

    dragState.currentTarget =
        target;

    let element = null;


    if (
        target.type === 'player'
    ) {

        element =
            document.querySelector(
                `#grid .slot[data-slot="${target.slot}"]`
            );

    } else {

        element =
            document.querySelector(
                `#ground-grid .slot[data-ground-index="${target.index}"]`
            );
    }

    if (element) {

        element.classList.add(
            'drag-target'
        );
    }
}


// =========================================================
// BEGIN DRAG
// =========================================================

function beginDrag(
    type,
    slot,
    groundIndex,
    item,
    event
) {

    if (
        !item ||
        event.button !== 0 ||
        dragState.active
    ) {
        return;
    }

    dragState.active =
        true;

    dragState.started =
        false;

    dragState.type =
        type;

    dragState.sourceSlot =
        slot !== null
            ? Number(slot)
            : null;

    dragState.sourceGroundIndex =
        groundIndex !== null
            ? Number(groundIndex)
            : null;

    dragState.item =
        item;

    dragState.startX =
        event.clientX;

    dragState.startY =
        event.clientY;

    dragState.currentTarget =
        null;

    event.preventDefault();
}


// =========================================================
// ACTIVATE DRAG
// =========================================================

function activateDrag(event) {

    if (
        !dragState.active ||
        dragState.started
    ) {
        return;
    }

    const dx =
        event.clientX -
        dragState.startX;

    const dy =
        event.clientY -
        dragState.startY;

    const distance =
        Math.sqrt(
            dx * dx +
            dy * dy
        );

    if (
        distance <
        DRAG_DISTANCE
    ) {
        return;
    }

    dragState.started =
        true;

    createDragGhost(
        dragState.item
    );

    document.body.classList.add(
        'inventory-dragging'
    );

    updateDragGhost(
        event.clientX,
        event.clientY
    );

    updateDropTarget(
        event.clientX,
        event.clientY
    );
}


// =========================================================
// APPLY QUEUED UPDATES
// =========================================================

function applyPendingUpdates() {

    if (
        pendingInventoryUpdate !== null
    ) {

        inventory =
            pendingInventoryUpdate;

        pendingInventoryUpdate =
            null;
    }

    if (
        pendingGroundUpdate !== null
    ) {

        groundItems =
            pendingGroundUpdate;

        pendingGroundUpdate =
            null;
    }

    render();
}


// =========================================================
// CANCEL DRAG
// =========================================================

function cancelDrag() {

    removeDragGhost();

    clearDragTargets();

    document.body.classList.remove(
        'inventory-dragging'
    );

    dragState.active =
        false;

    dragState.started =
        false;

    dragState.type =
        null;

    dragState.sourceSlot =
        null;

    dragState.sourceGroundIndex =
        null;

    dragState.item =
        null;

    dragState.currentTarget =
        null;

    // Do not apply queued updates here.
    // A normal ESC cancellation should simply
    // restore the latest server state.
    applyPendingUpdates();
}


// =========================================================
// FINISH DRAG
// =========================================================

function finishDrag(event) {

    if (!dragState.active) {
        return;
    }

    const wasDragging =
        dragState.started;

    const sourceType =
        dragState.type;

    const sourceSlot =
        dragState.sourceSlot;

    const sourceGroundIndex =
        dragState.sourceGroundIndex;

    const sourceItem =
        dragState.item;

    const target =
        dragState.currentTarget ||
        getDropTarget(
            event.clientX,
            event.clientY
        );


    // -----------------------------------------------------
    // Reset visual drag state first.
    // -----------------------------------------------------

    removeDragGhost();

    clearDragTargets();

    document.body.classList.remove(
        'inventory-dragging'
    );

    dragState.active =
        false;

    dragState.started =
        false;

    dragState.type =
        null;

    dragState.sourceSlot =
        null;

    dragState.sourceGroundIndex =
        null;

    dragState.item =
        null;

    dragState.currentTarget =
        null;


    // -----------------------------------------------------
    // It was only a click.
    // -----------------------------------------------------

    if (!wasDragging) {

        applyPendingUpdates();

        return;
    }


    // -----------------------------------------------------
    // No valid target.
    // -----------------------------------------------------

    if (!target) {

        applyPendingUpdates();

        return;
    }


    // =====================================================
    // PLAYER -> PLAYER
    // =====================================================

    if (
        sourceType === 'player' &&
        target.type === 'player'
    ) {

        if (
            sourceSlot === null ||
            sourceSlot === target.slot
        ) {

            applyPendingUpdates();

            return;
        }

        // IMPORTANT:
        // Read the source using the REAL slot.

        const item =
            getPlayerItem(
                sourceSlot
            );

        if (!item) {

            applyPendingUpdates();

            return;
        }

        post(
            'MoveItem',
            {
                fromSlot:
                    Number(sourceSlot),

                toSlot:
                    Number(target.slot),

                amount:
                    Number(item.amount) || 1
            }
        );

        applyPendingUpdates();

        return;
    }


    // =====================================================
    // PLAYER -> GROUND
    // =====================================================

    if (
        sourceType === 'player' &&
        target.type === 'ground'
    ) {

        if (
            sourceSlot === null
        ) {

            applyPendingUpdates();

            return;
        }

        const item =
            getPlayerItem(
                sourceSlot
            );

        if (!item) {

            applyPendingUpdates();

            return;
        }

        post(
            'DropItem',
            {
                slot:
                    Number(sourceSlot),

                amount:
                    Number(item.amount) || 1
            }
        );

        applyPendingUpdates();

        return;
    }


    // =====================================================
    // GROUND -> PLAYER
    // =====================================================

    if (
        sourceType === 'ground' &&
        target.type === 'player'
    ) {

        const ground =
            getGroundItem(
                sourceGroundIndex
            );

        if (!ground) {

            applyPendingUpdates();

            return;
        }

        post(
            'PickupGround',
            {
                dropId:
                    ground.dropId,

                groundSlot:
                    ground.groundSlot,

                amount:
                    Number(ground.amount) || 1,

                targetSlot:
                    Number(target.slot)
            }
        );

        applyPendingUpdates();

        return;
    }

    applyPendingUpdates();
}


// =========================================================
// GLOBAL MOUSE MOVE
// =========================================================

document.addEventListener(
    'mousemove',
    event => {

        if (!dragState.active) {
            return;
        }

        activateDrag(event);

        if (
            dragState.started
        ) {

            updateDragGhost(
                event.clientX,
                event.clientY
            );

            updateDropTarget(
                event.clientX,
                event.clientY
            );
        }
    }
);


// =========================================================
// GLOBAL MOUSE UP
// =========================================================

document.addEventListener(
    'mouseup',
    event => {

        if (
            event.button !== 0
        ) {
            return;
        }

        finishDrag(event);
    }
);


// =========================================================
// PLAYER SLOT
// =========================================================

function createPlayerSlot(slot) {

    const element =
        document.createElement('div');

    element.className =
        'slot';

    element.dataset.slot =
        String(slot);

    element.innerHTML = `
        <span class="slot-number">
            ${String(slot).padStart(2, '0')}
        </span>
    `;


    // IMPORTANT:
    // Always retrieve the item using the real
    // QBCore slot number.

    const item =
        getPlayerItem(slot);


    if (item) {

        const itemElement =
            document.createElement('div');

        itemElement.className =
            'item';


        itemElement.innerHTML = `
            <img
                src="${imageFor(item)}"
                draggable="false"
            >

            <span class="item-amount">
                ${Number(item.amount) || 0}
            </span>

            <span class="item-label">
                ${item.label || item.name || ''}
            </span>
        `;


        const image =
            itemElement.querySelector(
                'img'
            );

        if (image) {

            image.addEventListener(
                'error',
                () => {
                    image.style.display =
                        'none';
                }
            );
        }


        // -------------------------------------------------
        // CLICK
        // -------------------------------------------------

        itemElement.addEventListener(
            'click',
            event => {

                event.preventDefault();
                event.stopPropagation();

                if (
                    dragState.started
                ) {
                    return;
                }

                selectSlot(slot);
            }
        );


        // -------------------------------------------------
        // DOUBLE CLICK
        // -------------------------------------------------

        itemElement.addEventListener(
            'dblclick',
            event => {

                event.preventDefault();
                event.stopPropagation();

                if (
                    dragState.started
                ) {
                    return;
                }

                selectSlot(slot);

                useSelected();
            }
        );


        // -------------------------------------------------
        // MOUSE DOWN
        // -------------------------------------------------

        itemElement.addEventListener(
            'mousedown',
            event => {

                if (
                    event.button !== 0
                ) {
                    return;
                }

                beginDrag(
                    'player',
                    slot,
                    null,
                    item,
                    event
                );
            }
        );


        element.appendChild(
            itemElement
        );
    }


    // -----------------------------------------------------
    // EMPTY SLOT CLICK
    // -----------------------------------------------------

    element.addEventListener(
        'click',
        event => {

            if (
                event.target.closest('.item')
            ) {
                return;
            }

            selectSlot(slot);
        }
    );

    return element;
}


// =========================================================
// GROUND SLOT
// =========================================================

function createGroundSlot(
    index,
    item
) {

    const element =
        document.createElement('div');

    element.className =
        'slot';

    element.dataset.groundIndex =
        String(index);

    element.innerHTML = `
        <span class="slot-number">
            ${String(index + 1).padStart(2, '0')}
        </span>
    `;


    if (item) {

        const itemElement =
            document.createElement('div');

        itemElement.className =
            'item';

        itemElement.innerHTML = `
            <img
                src="${imageFor(item)}"
                draggable="false"
            >

            <span class="item-amount">
                ${Number(item.amount) || 0}
            </span>

            <span class="item-label">
                ${item.label || item.name || ''}
            </span>
        `;


        const image =
            itemElement.querySelector(
                'img'
            );

        if (image) {

            image.addEventListener(
                'error',
                () => {
                    image.style.display =
                        'none';
                }
            );
        }


        // -------------------------------------------------
        // CLICK
        // -------------------------------------------------

        itemElement.addEventListener(
            'click',
            event => {

                event.preventDefault();
                event.stopPropagation();

                if (
                    dragState.started
                ) {
                    return;
                }

                selectGround(index);
            }
        );


        // -------------------------------------------------
        // DOUBLE CLICK
        // -------------------------------------------------

        itemElement.addEventListener(
            'dblclick',
            event => {

                event.preventDefault();
                event.stopPropagation();

                if (
                    dragState.started
                ) {
                    return;
                }

                selectGround(index);

                pickupSelectedGround();
            }
        );


        // -------------------------------------------------
        // MOUSE DOWN
        // -------------------------------------------------

        itemElement.addEventListener(
            'mousedown',
            event => {

                if (
                    event.button !== 0
                ) {
                    return;
                }

                beginDrag(
                    'ground',
                    null,
                    index,
                    item,
                    event
                );
            }
        );


        element.appendChild(
            itemElement
        );
    }


    // -----------------------------------------------------
    // EMPTY SLOT CLICK
    // -----------------------------------------------------

    element.addEventListener(
        'click',
        event => {

            if (
                event.target.closest('.item')
            ) {
                return;
            }

            selectGround(index);
        }
    );

    return element;
}


// =========================================================
// RENDER PLAYER
// =========================================================

function renderPlayer() {

    if (!grid) {
        return;
    }

    grid.innerHTML = '';

    for (
        let slot = 1;
        slot <= maxSlots;
        slot++
    ) {

        grid.appendChild(
            createPlayerSlot(
                slot
            )
        );
    }
}


// =========================================================
// RENDER GROUND
// =========================================================

function renderGround() {

    if (!groundGrid) {
        return;
    }

    groundGrid.innerHTML = '';

    for (
        let index = 0;
        index < maxSlots;
        index++
    ) {

        groundGrid.appendChild(
            createGroundSlot(
                index,
                getGroundItem(index)
            )
        );
    }
}


// =========================================================
// RENDER
// =========================================================

function render() {

    renderPlayer();
    renderGround();


    // -----------------------------------------------------
    // Weight
    // -----------------------------------------------------

    const weight =
        totalWeight();

    if (weightText) {

        weightText.textContent =
            `${formatWeight(weight)} / ${formatWeight(maxWeight)}`;
    }


    const percentage =
        maxWeight > 0
            ? (
                weight /
                maxWeight
            ) * 100
            : 0;

    if (weightFill) {

        weightFill.style.width =
            `${Math.min(
                100,
                Math.max(
                    0,
                    percentage
                )
            )}%`;
    }


    // -----------------------------------------------------
    // Restore player selection
    // -----------------------------------------------------

    if (
        selectedSlot !== null
    ) {

        const slot =
            Number(selectedSlot);

        if (
            getPlayerItem(slot)
        ) {

            selectSlot(slot);

        } else {

            selectedSlot =
                null;
        }
    }


    // -----------------------------------------------------
    // Restore ground selection
    // -----------------------------------------------------

    if (
        selectedGroundIndex !== null
    ) {

        const index =
            Number(
                selectedGroundIndex
            );

        if (
            getGroundItem(index)
        ) {

            selectGround(index);

        } else {

            selectedGroundIndex =
                null;
        }
    }
}


// =========================================================
// MESSAGE EVENTS
// =========================================================

window.addEventListener(
    'message',
    event => {

        const data =
            event.data || {};


        // =================================================
        // OPEN
        // =================================================

        if (
            data.action === 'open'
        ) {

            cancelDrag();

            pendingInventoryUpdate =
                null;

            pendingGroundUpdate =
                null;


            inventory =
                data.inventory || {};

            groundItems =
                Array.isArray(data.ground)
                    ? data.ground
                    : (
                        data.ground &&
                        typeof data.ground === 'object'
                            ? data.ground
                            : []
                    );


            maxSlots =
                Number(data.slots) || 40;

            maxWeight =
                Number(data.maxWeight) ||
                120000;


            selectedSlot =
                null;

            selectedGroundIndex =
                null;


            if (playerName) {

                playerName.textContent =
                    data.playerName ||
                    'PLAYER';
            }


            if (app) {

                app.classList.remove(
                    'hidden'
                );
            }


            render();

            return;
        }


        // =================================================
        // PLAYER UPDATE
        // =================================================

        if (
            data.action === 'update'
        ) {

            const newInventory =
                data.inventory || {};


            /*
             * If we're currently dragging,
             * don't rebuild the DOM underneath
             * the mouse.
             *
             * Instead save the newest server state
             * and apply it when the drag finishes.
             */

            if (
                dragState.active
            ) {

                pendingInventoryUpdate =
                    newInventory;

                return;
            }


            inventory =
                newInventory;

            render();

            return;
        }


        // =================================================
        // GROUND UPDATE
        // =================================================

        if (
            data.action === 'groundUpdate'
        ) {

            const newGround =
                Array.isArray(data.ground)
                    ? data.ground
                    : (
                        data.ground &&
                        typeof data.ground === 'object'
                            ? data.ground
                            : []
                    );


            if (
                dragState.active
            ) {

                pendingGroundUpdate =
                    newGround;

                return;
            }


            groundItems =
                newGround;

            renderGround();

            return;
        }


        // =================================================
        // CLOSE
        // =================================================

        if (
            data.action === 'close'
        ) {

            cancelDrag();

            pendingInventoryUpdate =
                null;

            pendingGroundUpdate =
                null;


            if (app) {

                app.classList.add(
                    'hidden'
                );
            }


            selectedSlot =
                null;

            selectedGroundIndex =
                null;

            return;
        }
    }
);


// =========================================================
// BUTTONS
// =========================================================

const closeButton =
    document.getElementById(
        'close'
    );

if (closeButton) {

    closeButton.addEventListener(
        'click',
        () => {
            post(
                'CloseInventory'
            );
        }
    );
}


const useButton =
    document.getElementById(
        'use'
    );

if (useButton) {

    useButton.addEventListener(
        'click',
        () => {
            useSelected();
        }
    );
}


const giveButton =
    document.getElementById(
        'give'
    );

if (giveButton) {

    giveButton.addEventListener(
        'click',
        () => {
            giveSelected();
        }
    );
}


const dropButton =
    document.getElementById(
        'drop'
    );

if (dropButton) {

    dropButton.addEventListener(
        'click',
        () => {
            dropSelected();
        }
    );
}


const pickupButton =
    document.getElementById(
        'pickup'
    );

if (pickupButton) {

    pickupButton.addEventListener(
        'click',
        () => {
            pickupSelectedGround();
        }
    );
}


// =========================================================
// DISABLE NATIVE DRAG
// =========================================================

document.addEventListener(
    'dragstart',
    event => {
        event.preventDefault();
    }
);


// =========================================================
// CONTEXT MENU
// =========================================================

document.addEventListener(
    'contextmenu',
    event => {
        event.preventDefault();
    }
);


// =========================================================
// ESC
// =========================================================

document.addEventListener(
    'keydown',
    event => {

        if (
            event.key === 'Escape'
        ) {

            if (
                dragState.active
            ) {

                cancelDrag();

                return;
            }

            post(
                'CloseInventory'
            );
        }
    }
);

// =========================================================
// FIVE MOUSE CURSOR
// =========================================================
//
// Don't use the browser "grab" / "grabbing" cursor.
// FiveM will display its normal NUI mouse cursor.
//

document.documentElement.style.cursor = 'default';
document.body.style.cursor = 'default';

document.addEventListener(
    'mousedown',
    event => {

        if (event.button === 0) {
            document.body.style.cursor = 'default';
        }
    }
);

document.addEventListener(
    'mouseup',
    () => {
        document.body.style.cursor = 'default';
    }
);