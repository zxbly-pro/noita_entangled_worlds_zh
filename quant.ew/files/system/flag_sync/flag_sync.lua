local flag_present = {}

for _, flag in ipairs(util.string_split(ctx.proxy_opt.progress, ",")) do
    flag_present[flag] = true
end

local function has_flag(flag)
    if flag_present[flag] == true then
        return true
    end
    -- 直接读取原版持久旗标，避免把长旗标再复制一份写进当前运行存档。
    if EwOriginalHasPersistentFlag ~= nil and EwOriginalHasPersistentFlag(flag) then
        return true
    end
    -- 兼容已经写入过 ew_pf_ 前缀运行旗标的旧存档。
    return GameHasFlagRun("ew_pf_" .. flag)
end

function EwHasPersistentFlag(flag)
    return has_flag(flag)
end

util.add_cross_call("ew_has_flag", has_flag)

return {}
