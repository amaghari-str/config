-- --- hypr/user.lua --------------------------------------------------------
-- Your Hyprland overrides, in Ryoku's `hl` Lua API. Loaded LAST, so anything
-- here wins over Ryoku's defaults and over Ryoku Settings. Updates never touch
-- it. Reach for it only for raw config the GUI does not expose.
--
-- --- who owns what --------------------------------------------------------
--   Ryoku defaults   the base modules           replaced by updates   don't edit
--   Ryoku Settings   settings*.lua, rebinds.lua the GUI writes these edit in-app
--   you              this file (edit it here); whole-file forks in user_edits  yours
--
-- --- take over a whole module ---------------------------------------------
-- Copy it into the overlay at the same path and edit there, e.g.
--   ~/.config/ryoku/user_edits/hypr/modules/binds.lua
-- You then own that file: `ryoku doctor` warns when an update changes the
-- original, and `ryoku reset hypr/modules/binds.lua` hands it back.
--
-- --- examples -------------------------------------------------------------
-- hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("kitty"))
-- hl.window_rule({ name = "float-mpv", match = { class = "mpv" }, float = true })
-- hl.config({ general = { border_size = 3 } })

-- --- Alt+Tab across all open windows (MRU order) --------------------------
do
    local K = require("modules.rebind")
    local cycle_list = nil
    local cycle_idx = 1

    local function build_mru_list()
        local wins = {}
        for _, w in ipairs(hl.get_windows()) do
            if w.mapped and w.address and w.address ~= "" then
                wins[#wins + 1] = {
                    address = w.address,
                    hist = w.focus_history_id or 999999,
                }
            end
        end
        table.sort(wins, function(a, b)
            if a.hist ~= b.hist then
                return a.hist < b.hist
            end
            return a.address < b.address
        end)
        local addrs = {}
        for i, item in ipairs(wins) do
            addrs[i] = item.address
        end
        return addrs
    end

    local function focus_address(addr)
        local w = hl.get_window("address:" .. addr)
        if not w or not w.mapped then
            return false
        end
        local ws = w.workspace
        local mon = w.monitor or hl.get_active_monitor()
        if not (ws and ws.special) and mon then
            local sws = hl.get_active_special_workspace(mon)
            if sws and sws.name then
                local sname = sws.name:gsub("^special:", "")
                if sname ~= "" then
                    hl.dispatch(hl.dsp.workspace.toggle_special(sname))
                end
            end
        end
        hl.dispatch(hl.dsp.focus({ window = "address:" .. addr }))
        hl.dispatch(hl.dsp.window.bring_to_top())
        return true
    end

    local function alt_tab_step(delta)
        local active = hl.get_active_window()
        local active_addr = active and active.address or nil

        -- Rebuild snapshot if Alt was released or focus changed outside the cycle
        if not cycle_list or #cycle_list == 0 or cycle_list[cycle_idx] ~= active_addr then
            cycle_list = build_mru_list()
            local n = #cycle_list
            if n == 0 then
                cycle_list = nil
                return
            end
            if active_addr and cycle_list[1] == active_addr then
                cycle_idx = 1
            else
                -- Starting from an empty workspace: first press focuses MRU #1
                cycle_idx = delta > 0 and 1 or n
                focus_address(cycle_list[cycle_idx])
                return
            end
        end

        local n = #cycle_list
        if n <= 1 then
            if n == 1 then
                focus_address(cycle_list[1])
            end
            return
        end

        for _ = 1, n do
            cycle_idx = ((cycle_idx - 1 + delta) % n) + 1
            if focus_address(cycle_list[cycle_idx]) then
                return
            end
        end
        cycle_list = nil
    end

    local default_chord = K("ALT + Tab")
    if default_chord then
        hl.unbind(default_chord)
    end

    hl.bind("ALT + Tab", function() alt_tab_step(1) end, { repeating = true })
    hl.bind("ALT + SHIFT + Tab", function() alt_tab_step(-1) end, { repeating = true })
    hl.bind("ALT + SHIFT + ISO_Left_Tab", function() alt_tab_step(-1) end, { repeating = true })

    -- Reset MRU snapshot as soon as Left Alt (64) or Right Alt (108) is released
    for _, key in ipairs({ "code:64", "code:108" }) do
        hl.bind(key, function() cycle_list = nil end, {
            release = true,
            transparent = true,
            ignore_mods = true,
            non_consuming = true,
        })
    end
end
