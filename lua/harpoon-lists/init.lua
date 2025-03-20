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

function HarpoonLists:setup()
	vim.api.nvim_create_user_command(
		"ChefHarpoon",
		function()
			local screenWidth = vim.api.nvim_get_option("columns")
			local screenHeight = vim.api.nvim_get_option("lines")

			local buf = vim.api.nvim_create_buf(false, false)
			vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
			vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

			local listsKey = self.harpoon.config.settings.key()

			local loadLists = function()
				local lists = self.harpoon.data._data[listsKey] or {}
				local listNames = {}
				local i = 1
				for listName, _ in pairs(lists) do
					listNames[i] = listName
					i = i + 1
				end
				if self.currentList ~= nil then
					for index, name in ipairs(listNames) do
						if name == self.currentList then
							table.remove(listNames, index)
							table.insert(listNames, 1, self.currentList)
							break
						end
					end
				end

				vim.api.nvim_buf_set_option(buf, "modifiable", true)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, listNames)

				local ns_id = vim.api.nvim_create_namespace("ChefHarpoonList")
				if self.currentList ~= nil then
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

			local listNames = loadLists()

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
				self.currentList = listNames[vim.api.nvim_win_get_cursor(0)[1]]
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
				local listNamesIndex = vim.api.nvim_win_get_cursor(0)[1]
				local listName = listNames[listNamesIndex]
				if listName == HARPOON_DEFAULT_LIST then
					vim.print("Cannot delete default list")
					return
				end
				if listName == self.currentList then
					self.currentList = HARPOON_DEFAULT_LIST
				end

				-- Get the up to date current lists
				local lists1 = self.harpoon.data._data[listsKey] or {}
				local lists2 = self.harpoon.lists[listsKey] or {}
				-- Remove the list that was selected for deletion
				lists1[listName] = nil
				lists2[listName] = nil

				self.harpoon:sync()
				listNames = loadLists()
				vim.api.nvim_buf_set_option(buf, "modifiable", false)
			end, { buffer = buf, noremap = true, silent = true })

			-- Close window
			vim.keymap.set("n", "q", function()
				vim.api.nvim_win_close(win, true)
			end, { buffer = buf, noremap = true, silent = true })
			vim.keymap.set("n", "<Esc>", function()
				vim.api.nvim_win_close(win, true)
			end, { buffer = buf, noremap = true, silent = true })
		end,
		{}
	)
end

function HarpoonLists:list()
	return self.harpoon:list(self.currentList)
end

return HarpoonLists:new()
