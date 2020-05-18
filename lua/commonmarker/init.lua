package.loaded["rust"] = nil -- Force module reload during dev
local rust = require("libvim_commonmark")

local rustymarks = vim.api.nvim_create_namespace("rustymarks")

-- The Lua API is verbose and repetative
local call_function = vim.api.nvim_call_function
local buf_add_highlight = vim.api.nvim_buf_add_highlight
local buf_attach = vim.api.nvim_buf_attach
local buf_get_lines = vim.api.nvim_buf_get_lines
local buf_clear_namespace = vim.api.nvim_buf_clear_namespace

local _attachments = {}

-- luacheck: ignore dump
local function dump(...)
	if select("#", ...) == 1 then
		vim.api.nvim_out_write(vim.inspect((...)))
	else
		vim.api.nvim_out_write(vim.inspect {...})
	end
	vim.api.nvim_out_write("\n")
end

local function byte2pos (byte)
	local line = call_function("byte2line", { byte })
	-- local col = byte - vim.api.nvim_buf_get_offset(buffer, line)
	local col = byte - call_function("line2byte", { line })
	return line, col
end

local function get_contents (buffer)
	local lines = buf_get_lines(buffer, 0, -1, true)
	for i = 1, #lines do lines[i] = lines[i] .. "\n" end
	return table.concat(lines)
end

local function highlight (buffer)
	local contents = get_contents(buffer)
	local events = rust.get_offsets(contents)
	for _, event in ipairs(events) do
		local sline, scol = byte2pos(event.first)
		local eline, ecol = byte2pos(event.last)
		if sline < eline then
			buf_add_highlight(buffer, rustymarks, event.group, sline - 1, scol, -1)
			sline = sline + 1
			while sline < eline do
				buf_add_highlight(buffer, rustymarks, event.group, sline - 1, 0, -1)
				sline = sline + 1
			end
			buf_add_highlight(buffer, rustymarks, event.group, sline - 1, 0, ecol)
		else
			buf_add_highlight(buffer, rustymarks, event.group, sline - 1, scol, ecol)
		end
	end
end

local function attach (buffer)
	if _attachments[buffer] then return end
	_attachments[buffer] = true
	highlight(buffer)
	buf_attach(buffer, false, {
			on_lines = function (_, _, _, _, _, _)
				if not _attachments[buffer] then return end
				buf_clear_namespace(buffer, rustymarks, 0, -1)
				highlight(buffer)
			end,
			on_detach = function ()
				_attachments[buffer] = nil
			end
		})
end

return {
	attach = attach,
}
