local HarpoonLists = {}

HarpoonLists.__index = HarpoonLists

local harpoonConfig = require("harpoon.config")
local HARPOON_DEFAULT_LIST = harpoonConfig.DEFAULT_LIST

function HarpoonLists:new()
	local theHarpoon = require("harpoon")
	return setmetatable({
		currentList = HARPOON_DEFAULT_LIST,
		harpoon = theHarpoon
	}, self)
end

local function loadLists(buf, harpoonLists)
	local listsKey = harpoonLists.harpoon.config.settings.key()
	local lists = harpoonLists.harpoon.data._data[listsKey] or {}
	local listNames = {}
	local i = 1
	for listName, _ in pairs(lists) do
		listNames[i] = listName
		i = i + 1
	end
	if harpoonLists.currentList ~= nil then
		for index, name in ipairs(listNames) do
			if name == harpoonLists.currentList then
				table.remove(listNames, index)
				table.insert(listNames, 1, harpoonLists.currentList)
				break
			end
		end
	end

	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, listNames)

	local ns_id = vim.api.nvim_create_namespace("HarpoonListsNamespace")
	if harpoonLists.currentList ~= nil then
		vim.api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
			end_row = 1,
			hl_group = "Error",
			virt_text = { { "(Current)", "Comment" } },
			virt_text_pos = "eol",
		})
	end

	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	return listNames
end

local function delete_list(managerData, harpoonLists)
	local listNamesIndex = vim.api.nvim_win_get_cursor(0)[1]
	local listName = managerData.listNames[listNamesIndex]
	if listName == HARPOON_DEFAULT_LIST then
		vim.print("Cannot delete default list")
		return
	end
	if listName == harpoonLists.currentList then
		harpoonLists.currentList = HARPOON_DEFAULT_LIST
	end

	-- Get the up to date current lists
	local listsKey = harpoonLists.harpoon.config.settings.key()
	local lists1 = harpoonLists.harpoon.data._data[listsKey] or {}
	local lists2 = harpoonLists.harpoon.lists[listsKey] or {}
	-- Remove the list that was selected for deletion
	lists1[listName] = nil
	lists2[listName] = nil

	harpoonLists.harpoon:sync()
	managerData.listNames = loadLists(managerData.buf, harpoonLists)
	vim.api.nvim_buf_set_option(managerData.buf, "modifiable", false)
end

function HarpoonLists:open_manager()
	local screenWidth = vim.api.nvim_get_option("columns")
	local screenHeight = vim.api.nvim_get_option("lines")

	local buf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	local listNames = loadLists(buf, self)

	local managerData = {
		buf = buf,
		listNames = listNames,
	}

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		height = math.floor(screenHeight * 0.5),
		width = math.floor(screenWidth * 0.5),
		row = math.floor(screenHeight * 0.25),
		col = math.floor(screenWidth * 0.25),
		-- style = "minimal",
		border = "single",
		title = "Choose a Harpoon list",
		title_pos = "center",
	})

	-- Choose list and close window
	vim.keymap.set("n", "<CR>", function()
		self.currentList = managerData.listNames[vim.api.nvim_win_get_cursor(0)[1]]
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, noremap = true, silent = true })

	-- Create new list and close window
	vim.keymap.set("n", "n", function()
		self.currentList = vim.fn.input("New list name: ")
		self.harpoon:list(self.currentList)
		self.harpoon:sync()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, noremap = true, silent = true })

	-- Delete list and update list names
	vim.keymap.set("n", "d", function()
		delete_list(managerData, self)
	end, { buffer = buf, noremap = true, silent = true })

	-- Close window
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, noremap = true, silent = true })
end

function HarpoonLists:setup()
	vim.api.nvim_create_user_command(
		"HarpoonLists",
		function() self:open_manager() end,
		{}
	)
end

function HarpoonLists:list()
	return self.harpoon:list(self.currentList)
end

return HarpoonLists:new()
