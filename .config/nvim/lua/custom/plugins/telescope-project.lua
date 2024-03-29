return {
	"nvim-telescope/telescope-project.nvim",
	event = "VimEnter",
	dependencies = {
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		require("telescope").load_extension("project")
	end,
}
