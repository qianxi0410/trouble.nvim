local View = require("trouble.view")
local config = require("trouble.config")
local colors = require("trouble.colors")
local util = require("trouble.util")

colors.setup()

local Trouble = {}

local view

local function is_open() return view and view:is_valid() end

function Trouble.setup(options)
    config.setup(options)
    colors.setup()
end

function Trouble.close() if is_open() then view:close() end end

local function get_opts(opts)
    opts = opts or {}
    if type(opts) == "string" then opts = {mode = opts} end
    config.fix_mode(opts)
    return opts
end

function Trouble.open(opts)
    opts = get_opts(opts)
    if opts.mode and (opts.mode ~= config.options.mode) then
        config.options.mode = opts.mode
    end
    opts.focus = true

    if is_open() then
        Trouble.refresh(opts)
    else
        view = View.create(opts)
    end
end

function Trouble.toggle(opts)
    opts = get_opts(opts)

    if opts.mode and (opts.mode ~= config.options.mode) then
        config.options.mode = opts.mode
        Trouble.open()
        return
    end

    if is_open() then
        Trouble.close()
    else
        Trouble.open()
    end
end

function Trouble.help()
    local lines = {"# Key Bindings"}
    local height = 1
    for command, key in pairs(config.options.action_keys) do
        if type(key) == "table" then key = table.concat(key, " | ") end
        table.insert(lines, " * **" .. key .. "** " .. command:gsub("_", " "))
        height = height + 1
    end
    -- help
    vim.lsp.util.open_floating_preview(lines, "markdown", {
        border = "single",
        height = 20,
        offset_y = -2,
        offset_x = 2
    })
end

local updater = util.debounce(100, function()
    util.debug("refresh: auto")
    view:update({auto = true})
end)

function Trouble.refresh(opts)
    opts = opts or {}

    -- dont do an update if this is an automated refresh from a different provider
    if opts.auto then
        if opts.provider == "diagnostics" and config.options.mode ==
            "lsp_document_diagnostics" then
            opts.provider = "lsp_document_diagnostics"
        elseif opts.provider == "diagnostics" and config.options.mode ==
            "lsp_workspace_diagnostics" then
            opts.provider = "lsp_workspace_diagnostics"
        elseif opts.provider == "qf" and config.options.mode == "quickfix" then
            opts.provider = "quickfix"
        elseif opts.provider == "qf" and config.options.mode == "loclist" then
            opts.provider = "loclist"
        end
        if opts.provider ~= config.options.mode then return end
    end

    if is_open() then
        if opts.auto then
            updater()
        else
            util.debug("refresh")
            view:update(opts)
        end
    elseif opts.auto and config.options.auto_open and opts.mode ==
        config.options.mode then
        local items = require("trouble.providers").get(
                          vim.api.nvim_get_current_win(),
                          vim.api.nvim_get_current_buf(), config.options)
        if #items > 0 then Trouble.open(opts) end
    end
end

function Trouble.action(action)
    if action == "toggle_mode" then
        if config.options.mode == "lsp_document_diagnostics" then
            config.options.mode = "lsp_workspace_diagnostics"
        elseif config.options.mode == "lsp_workspace_diagnostics" then
            config.options.mode = "lsp_document_diagnostics"
        end
        action = "refresh"
    end

    if view and action == "on_win_enter" then view:on_win_enter() end
    if not is_open() then return end
    if action == "hover" then view:hover() end
    if action == "jump" then view:jump() end
    if action == "jump_close" then
        view:jump()
        Trouble.close()
    end
    if action == "open_folds" then Trouble.refresh({open_folds = true}) end
    if action == "close_folds" then Trouble.refresh({close_folds = true}) end
    if action == "toggle_fold" then view:toggle_fold() end
    if action == "on_enter" then view:on_enter() end
    if action == "on_leave" then view:on_leave() end
    if action == "cancel" then view:switch_to_parent() end
    if action == "next" then view:next_item() end
    if action == "previous" then view:previous_item() end

    if action == "toggle_preview" then
        config.options.auto_preview = not config.options.auto_preview
        if not config.options.auto_preview then
            view:close_preview()
        else
            action = "preview"
        end
    end
    if action == "auto_preview" and config.options.auto_preview then
        action = "preview"
    end
    if action == "preview" then view:preview() end

    if Trouble[action] then Trouble[action]() end
end

return Trouble
