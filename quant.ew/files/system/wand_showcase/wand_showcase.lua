local EZWand = dofile_once("mods/quant.ew/files/lib/EZWand.lua")

local gui = GuiCreate()

local module = {}

local INSPECT_DISTANCE = 160
local INSPECT_DISTANCE_SQ = INSPECT_DISTANCE * INSPECT_DISTANCE
local SLOT_STEP = 13
local SLOT_BG_SCALE = 0.64
local SLOT_ICON_SCALE = 0.58
local WAND_TOOLTIP_ESTIMATED_WIDTH = 150

local spell_lookup
local gui_id = 1000

local spell_type_bgs = {
    [ACTION_TYPE_PROJECTILE] = "data/ui_gfx/inventory/item_bg_projectile.png",
    [ACTION_TYPE_STATIC_PROJECTILE] = "data/ui_gfx/inventory/item_bg_static_projectile.png",
    [ACTION_TYPE_MODIFIER] = "data/ui_gfx/inventory/item_bg_modifier.png",
    [ACTION_TYPE_DRAW_MANY] = "data/ui_gfx/inventory/item_bg_draw_many.png",
    [ACTION_TYPE_MATERIAL] = "data/ui_gfx/inventory/item_bg_material.png",
    [ACTION_TYPE_OTHER] = "data/ui_gfx/inventory/item_bg_other.png",
    [ACTION_TYPE_UTILITY] = "data/ui_gfx/inventory/item_bg_utility.png",
    [ACTION_TYPE_PASSIVE] = "data/ui_gfx/inventory/item_bg_passive.png",
}

local function new_id()
    gui_id = gui_id + 1
    return gui_id
end

local function inspect_key_down()
    local rebind = tonumber(ModSettingGet("quant.ew.rebind_wand_showcase") or 226) or 226
    return rebind ~= 0 and InputIsKeyDown(rebind)
end

local function is_wand(entity_id)
    if entity_id == nil or entity_id == 0 or not EntityGetIsAlive(entity_id) then
        return false
    end

    local ok, result = pcall(EZWand.IsWand, entity_id)
    return ok and result == true
end

local function get_active_wand(player_data)
    if player_data == nil or player_data.entity == nil or not EntityGetIsAlive(player_data.entity) then
        return nil
    end

    local active_item = player_fns.get_active_held_item(player_data.entity)
    if not is_wand(active_item) then
        return nil
    end

    return EZWand(active_item)
end

local function nearest_player()
    local my_x, my_y = EntityGetTransform(ctx.my_player.entity)
    local nearest
    local nearest_dist_sq = INSPECT_DISTANCE_SQ

    for peer_id, player_data in pairs(ctx.players) do
        if peer_id ~= ctx.my_id and player_data.entity ~= nil and EntityGetIsAlive(player_data.entity) and not player_data.dc then
            local x, y = EntityGetTransform(player_data.entity)
            local dx = x - my_x
            local dy = y - my_y
            local dist_sq = dx * dx + dy * dy
            if dist_sq <= nearest_dist_sq then
                nearest = player_data
                nearest_dist_sq = dist_sq
            end
        end
    end

    return nearest
end

local function text_with_shadow(x, y, text)
    GuiZSetForNextWidget(gui, -3)
    GuiColorSetForNextWidget(gui, 1, 1, 1, 1)
    GuiText(gui, x, y, text)
    GuiZSetForNextWidget(gui, -2)
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_NoLayouting)
    GuiColorSetForNextWidget(gui, 0, 0, 0, 0.85)
    local _, _, _, prev_x, prev_y = GuiGetPreviousWidgetInfo(gui)
    GuiText(gui, prev_x, prev_y + 1, text)
end

local function translated(value, fallback)
    if value == nil or value == "" then
        return fallback
    end

    local text = GameTextGetTranslatedOrNot(value)
    if text == nil or text == "" then
        return fallback or value
    end
    return text
end

local function ensure_spell_lookup()
    if spell_lookup ~= nil then
        return
    end

    dofile_once("data/scripts/gun/gun_actions.lua")
    spell_lookup = {}
    for _, action in ipairs(actions or {}) do
        spell_lookup[action.id] = {
            icon = action.sprite,
            name = action.name,
            description = action.description,
            type = action.type,
        }
    end
end

local function get_spell_info(item)
    local item_action = EntityGetFirstComponentIncludingDisabled(item, "ItemActionComponent")
    if item_action == nil then
        return nil
    end

    ensure_spell_lookup()
    local action_id = ComponentGetValue2(item_action, "action_id")
    local info = spell_lookup[action_id]
    if info == nil then
        return { name = action_id, description = "", icon = "data/ui_gfx/gun_actions/unidentified.png" }
    end
    return info
end

local function get_item_sprite(entry)
    local item = entry.entity
    local item_comp = EntityGetFirstComponentIncludingDisabled(item, "ItemComponent")
    if item_comp ~= nil then
        local ui_sprite = ComponentGetValue2(item_comp, "ui_sprite")
        if ui_sprite ~= nil and ui_sprite ~= "" then
            return ui_sprite
        end
    end

    local spell_info = get_spell_info(item)
    if spell_info ~= nil and spell_info.icon ~= nil and spell_info.icon ~= "" then
        return spell_info.icon
    end

    if entry.is_wand then
        local ok, sprite = pcall(function()
            return EZWand(item):GetSprite()
        end)
        if ok and sprite ~= nil and sprite ~= "" then
            return sprite
        end
    end

    for _, sprite in ipairs(EntityGetComponentIncludingDisabled(item, "SpriteComponent") or {}) do
        local image = ComponentGetValue2(sprite, "image_file")
        if image ~= nil and image ~= "" then
            return image
        end
    end

    return "data/ui_gfx/gun_actions/unidentified.png"
end

local function get_item_bg(entry)
    local spell_info = get_spell_info(entry.entity)
    if spell_info ~= nil and spell_info.type ~= nil then
        return spell_type_bgs[spell_info.type] or spell_type_bgs[ACTION_TYPE_OTHER]
    end
    return spell_type_bgs[ACTION_TYPE_OTHER]
end

local function get_item_tooltip(entry)
    if entry.is_wand then
        return entry.active and "法杖（当前手持）" or "法杖", "栏位 " .. tostring(entry.slot_x + 1)
    end

    local spell_info = get_spell_info(entry.entity)
    if spell_info ~= nil then
        return translated(spell_info.name, spell_info.name or "法术"),
            translated(spell_info.description, spell_info.description or "")
    end

    local item_comp = EntityGetFirstComponentIncludingDisabled(entry.entity, "ItemComponent")
    if item_comp ~= nil then
        local name = translated(ComponentGetValue2(item_comp, "item_name"), "物品")
        local description = translated(ComponentGetValue2(item_comp, "ui_description"), "")
        return name, description
    end

    return "物品", ""
end

local function render_item_icon(entry, x, y)
    GuiZSetForNextWidget(gui, -4)
    if entry.active then
        GuiColorSetForNextWidget(gui, 1, 0.92, 0.42, 1)
    else
        GuiColorSetForNextWidget(gui, 1, 1, 1, 0.78)
    end
    GuiImage(gui, new_id(), x, y, "data/ui_gfx/inventory/inventory_box.png", 1, SLOT_BG_SCALE, SLOT_BG_SCALE)

    local alive = entry.entity ~= nil and EntityGetIsAlive(entry.entity)
    local name, description = "物品", ""
    if alive then
        name, description = get_item_tooltip(entry)
    end
    GuiTooltip(gui, name, description)

    if not alive then
        return
    end

    GuiZSetForNextWidget(gui, -5)
    GuiImage(gui, new_id(), x + 1, y + 1, get_item_bg(entry), 0.7, SLOT_ICON_SCALE, SLOT_ICON_SCALE)

    local sprite = get_item_sprite(entry)
    if sprite ~= nil and sprite ~= "" then
        GuiZSetForNextWidget(gui, -6)
        GuiImage(gui, new_id(), x + 2, y + 2, sprite, 1, SLOT_ICON_SCALE, SLOT_ICON_SCALE)
    end
end

local function get_inventory_sizes(player_data, quick_entries, full_entries)
    local quick_slots = 10
    local full_slots_x = 16
    local full_slots_y = 1
    local inventory2 = EntityGetFirstComponentIncludingDisabled(player_data.entity, "Inventory2Component")
    if inventory2 ~= nil and inventory2 ~= 0 then
        quick_slots = ComponentGetValue2(inventory2, "quick_inventory_slots") or quick_slots
        full_slots_x = ComponentGetValue2(inventory2, "full_inventory_slots_x") or full_slots_x
        full_slots_y = ComponentGetValue2(inventory2, "full_inventory_slots_y") or full_slots_y
    end

    for _, entry in ipairs(quick_entries) do
        quick_slots = math.max(quick_slots, entry.slot_x + 1)
    end
    for _, entry in ipairs(full_entries) do
        full_slots_x = math.max(full_slots_x, entry.slot_x + 1)
        full_slots_y = math.max(full_slots_y, entry.slot_y + 1)
    end

    return quick_slots, full_slots_x, full_slots_y
end

local function get_inventory_entries(player_data, inventory_name)
    local entries = {}
    if player_data == nil or player_data.entity == nil or inventory_helper == nil then
        return entries
    end

    local active_item = player_fns.get_active_held_item(player_data.entity)
    for _, item in ipairs(inventory_helper.get_inventory_items(player_data, inventory_name) or {}) do
        local item_comp = EntityGetFirstComponentIncludingDisabled(item, "ItemComponent")
        if item_comp ~= nil then
            local slot_x, slot_y = ComponentGetValue2(item_comp, "inventory_slot")
            table.insert(entries, {
                entity = item,
                slot_x = slot_x or 0,
                slot_y = slot_y or 0,
                active = item == active_item,
                is_wand = is_wand(item),
            })
        end
    end

    table.sort(entries, function(a, b)
        if a.slot_y == b.slot_y then
            return a.slot_x < b.slot_x
        end
        return a.slot_y < b.slot_y
    end)
    return entries
end

local function collect_inventory(player_data)
    local quick = get_inventory_entries(player_data, "inventory_quick")
    local full = get_inventory_entries(player_data, "inventory_full")
    local wands = {}

    for _, entry in ipairs(quick) do
        if entry.is_wand then
            table.insert(wands, entry)
        end
    end
    for _, entry in ipairs(full) do
        if entry.is_wand then
            table.insert(wands, entry)
        end
    end

    local quick_slots, full_slots_x, full_slots_y = get_inventory_sizes(player_data, quick, full)
    return {
        quick = quick,
        full = full,
        wands = wands,
        quick_slots = quick_slots,
        full_slots_x = full_slots_x,
        full_slots_y = full_slots_y,
    }
end

local function render_inventory_grid(label, entries, slots_x, slots_y, x, y)
    text_with_shadow(x, y, label)
    y = y + 10

    local by_slot = {}
    for _, entry in ipairs(entries) do
        by_slot[entry.slot_y * 1000 + entry.slot_x] = entry
    end

    for row = 0, slots_y - 1 do
        for col = 0, slots_x - 1 do
            local slot_x = x + col * SLOT_STEP
            local slot_y = y + row * SLOT_STEP
            local entry = by_slot[row * 1000 + col]
            if entry ~= nil then
                render_item_icon(entry, slot_x, slot_y)
            else
                GuiZSetForNextWidget(gui, -4)
                GuiColorSetForNextWidget(gui, 1, 1, 1, 0.32)
                GuiImage(gui, new_id(), slot_x, slot_y, "data/ui_gfx/inventory/inventory_box.png", 1, SLOT_BG_SCALE, SLOT_BG_SCALE)
            end
        end
    end

    return x + slots_x * SLOT_STEP, y + slots_y * SLOT_STEP
end

local function render_inventory_panel(player_data, inventory, x, y)
    text_with_shadow(x, y, (player_data.name or "玩家") .. "的背包")

    local quick_right, quick_bottom = render_inventory_grid("快捷栏", inventory.quick, inventory.quick_slots, 1, x, y + 13)
    local full_right, full_bottom =
        render_inventory_grid("完整背包", inventory.full, inventory.full_slots_x, inventory.full_slots_y, x, quick_bottom + 6)

    return math.max(quick_right, full_right), full_bottom
end

local function estimate_wand_height(wand)
    local capacity = 10
    local ok, value = pcall(function()
        return wand.capacity
    end)
    if ok and type(value) == "number" then
        capacity = value
    end
    return 78 + math.max(0, math.ceil(capacity / 10) - 1) * 14
end

local function render_wand(label, wand, x, y, id_prefix)
    text_with_shadow(x, y, label)
    if id_prefix ~= nil then
        GuiIdPushString(gui, id_prefix)
    end
    local ok, right, bottom = pcall(function()
        return wand:RenderTooltip(x, y + 11, gui, -2)
    end)
    if id_prefix ~= nil then
        GuiIdPop(gui)
    end
    if ok then
        return right, bottom
    end

    text_with_shadow(x, y + 11, "无法渲染法杖")
    return x + 90, y + 22
end

local function render_target_wands(inventory, x, y, screen_w, screen_h)
    if #inventory.wands == 0 then
        text_with_shadow(x, y, "没有已同步的法杖")
        return x + 80, y + 11
    end

    local start_y = y
    local column_x = x
    local column_y = y
    local column_width = WAND_TOOLTIP_ESTIMATED_WIDTH
    local right = x
    local bottom = y

    for index, entry in ipairs(inventory.wands) do
        local ok, wand = pcall(EZWand, entry.entity)
        if ok and wand ~= nil then
            local estimated_height = estimate_wand_height(wand)
            if column_y > start_y and column_y + estimated_height > screen_h - 8 then
                column_x = column_x + column_width + 14
                column_y = start_y
                column_width = WAND_TOOLTIP_ESTIMATED_WIDTH
            end

            if column_x + WAND_TOOLTIP_ESTIMATED_WIDTH > screen_w - 8 then
                text_with_shadow(column_x, column_y, "还有 " .. tostring(#inventory.wands - index + 1) .. " 根法杖")
                return right, math.max(bottom, column_y + 11)
            end

            local label = "法杖 " .. tostring(index)
            if entry.active then
                label = label .. "（当前手持）"
            end

            local wand_right, wand_bottom =
                render_wand(label, wand, column_x, column_y, "ew_target_wand_" .. tostring(index))
            column_width = math.max(column_width, wand_right - column_x)
            right = math.max(right, wand_right)
            bottom = math.max(bottom, wand_bottom)
            column_y = wand_bottom + 8
        end
    end

    return right, bottom
end

function module.on_world_update()
    if ctx.is_texting or ctx.is_paused or not inspect_key_down() then
        return
    end

    local target = nearest_player()
    if target == nil then
        return
    end

    GuiStartFrame(gui)
    GuiZSet(gui, -2)
    gui_id = 1000

    local screen_w, screen_h = GuiGetScreenDimensions(gui)
    local x = 8
    local y = 18
    local inventory = collect_inventory(target)
    local inventory_right, inventory_bottom = render_inventory_panel(target, inventory, x, y)
    local target_right = inventory_right
    if #inventory.wands > 0 then
        local wands_right = render_target_wands(inventory, x, inventory_bottom + 8, screen_w, screen_h)
        target_right = math.max(target_right, wands_right)
    else
        text_with_shadow(x, inventory_bottom + 8, "没有已同步的法杖")
    end

    local my_wand = get_active_wand(ctx.my_player)
    if my_wand ~= nil then
        local compare_x = math.max(target_right + 14, screen_w * 0.62)
        if compare_x + WAND_TOOLTIP_ESTIMATED_WIDTH < screen_w then
            render_wand("你的法杖", my_wand, compare_x, y, "ew_my_wand")
        end
    end
end

return module
