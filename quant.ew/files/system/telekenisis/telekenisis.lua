local rpc = net.new_rpc_namespace()
local tele = {}
local who_has_tele = {}
local is_holding

rpc.opts_reliable()
function rpc.end_tele()
    local com = EntityGetFirstComponent(ctx.rpc_player_data.entity, "TelekinesisComponent")
    if com ~= nil and ComponentGetValue2(com, "mState") ~= 0 then
        ComponentSetValue2(com, "mInteract", true)
    end
    for i, p in ipairs(who_has_tele) do
        if p == ctx.rpc_peer_id then
            table.remove(who_has_tele, i)
            break
        end
    end
end

rpc.opts_reliable()
function rpc.send_tele(body_gid, n, extent, aimangle, bodyangle, distance, mindistance)
    local com = EntityGetFirstComponent(ctx.rpc_player_data.entity, "TelekinesisComponent")
    if com == nil then
        return
    end

    local ent = ewext.find_by_gid(body_gid)
    if ent == nil or not EntityGetIsAlive(ent) then
        ComponentSetValue2(com, "mState", 0)
        return
    end

    local x, y = EntityGetTransform(ent)
    local cx, cy = GameGetCameraPos()
    if x == nil then
        ComponentSetValue2(com, "mState", 0)
        return
    end

    local dx, dy = math.abs(x - cx), math.abs(y - cy)
    if
        dx > MagicNumbersGetValue("VIRTUAL_RESOLUTION_X") / 2
        or dy > MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y") / 2
    then
        ComponentSetValue2(com, "mState", 0)
        return
    end

    local body_ids = PhysicsBodyIDGetFromEntity(ent)
    local body_id = body_ids ~= nil and body_ids[n] or nil
    if body_id == nil then
        ComponentSetValue2(com, "mState", 0)
        return
    end

    if not table.contains(who_has_tele, ctx.rpc_peer_id) then
        table.insert(who_has_tele, ctx.rpc_peer_id)
        ComponentSetValue2(com, "mState", 1)
        if is_holding == ent then
            local mycom = EntityGetFirstComponent(ctx.my_player.entity, "TelekinesisComponent")
            if mycom ~= nil then
                ComponentSetValue2(mycom, "mInteract", true)
            end
            is_holding = nil
        end
    end

    ComponentSetValue(com, "mBodyID", body_id)
    ComponentSetValue2(com, "mStartBodyMaxExtent", extent)
    ComponentSetValue2(com, "mStartAimAngle", aimangle)
    ComponentSetValue2(com, "mStartBodyAngle", bodyangle)
    ComponentSetValue2(com, "mStartBodyDistance", distance)
    ComponentSetValue2(com, "mMinBodyDistance", mindistance)
end

local has_tele = false

local ent_to_body = {}
local body_to_ent_map = {}

local function clear_ent_body(ent)
    local bodies = ent_to_body[ent]
    if bodies ~= nil then
        for i, body_id in ipairs(bodies) do
            if body_to_ent_map[body_id] ~= nil and body_to_ent_map[body_id][1] == ent then
                body_to_ent_map[body_id] = nil
            end
        end
    end
    ent_to_body[ent] = nil
end

local function set_ent_body(ent, bodies)
    clear_ent_body(ent)
    if bodies ~= nil and #bodies ~= 0 then
        ent_to_body[ent] = bodies
        for i, body_id in ipairs(bodies) do
            body_to_ent_map[body_id] = { ent, i }
        end
    end
end

local function body_to_ent(id)
    local body_data = body_to_ent_map[id]
    if body_data ~= nil then
        return body_data[1], body_data[2]
    end
end

local sent_track_req = {}

local wait_for_ent = {}

local last_wait = {}

function tele.on_new_entity(arr)
    for _, ent in ipairs(arr) do
        table.insert(wait_for_ent, ent)
    end
end

function tele.on_world_update()
    for _, ent in ipairs(last_wait) do
        if EntityGetIsAlive(ent) then
            local lst = PhysicsBodyIDGetFromEntity(ent)
            if lst ~= nil and #lst ~= 0 then
                set_ent_body(ent, lst)
            end
        end
    end
    last_wait = wait_for_ent
    wait_for_ent = {}
    local part = GameGetFrameNum() % 180
    local len = 0
    for _, _ in pairs(ent_to_body) do
        len = len + 1
    end
    local chunk = math.max(math.floor(len / 180), 1)
    local start_i = part * chunk
    local end_i = math.min(start_i + chunk, len)
    local n = 0
    for ent, _ in pairs(ent_to_body) do
        if end_i <= n then
            break
        end
        n = n + 1
        if start_i <= n then
            if not EntityGetIsAlive(ent) then
                clear_ent_body(ent)
                sent_track_req[ent] = nil
            else
                local bodies = PhysicsBodyIDGetFromEntity(ent)
                if bodies ~= nil and #bodies ~= 0 then
                    set_ent_body(ent, bodies)
                else
                    clear_ent_body(ent)
                    sent_track_req[ent] = nil
                end
            end
        end
    end

    local com = EntityGetFirstComponent(ctx.my_player.entity, "TelekinesisComponent")
    if com ~= nil then
        if ComponentGetValue2(com, "mState") ~= 0 then
            local body = ComponentGetValue(com, "mBodyID")
            local ent, num = body_to_ent(tonumber(body))
            if ent ~= nil and EntityGetIsAlive(ent) then
                local gid
                for _, v in ipairs(EntityGetComponent(ent, "VariableStorageComponent") or {}) do
                    if ComponentGetValue2(v, "name") == "ew_gid_lid" then
                        gid = v
                        break
                    end
                end
                if gid ~= nil then
                    is_holding = ent
                    has_tele = true
                    rpc.send_tele(
                        ComponentGetValue2(gid, "value_string"),
                        num,
                        ComponentGetValue2(com, "mStartBodyMaxExtent"),
                        ComponentGetValue2(com, "mStartAimAngle"),
                        ComponentGetValue2(com, "mStartBodyAngle"),
                        ComponentGetValue2(com, "mStartBodyDistance"),
                        ComponentGetValue2(com, "mMinBodyDistance")
                    )
                elseif not sent_track_req[ent] then
                    sent_track_req[ent] = true
                    if EntityGetIsAlive(ent) then
                        ewext.track(ent)
                    end
                end
            end
        elseif has_tele then
            has_tele = false
            rpc.end_tele()
        end
    end
end

return tele
