-- Project-specific source roots, applied only when the project actually has
-- them. These used to be listed unconditionally, which meant every Python
-- project was told to search a handful of ./source/isaaclab* directories that
-- almost never exist.
local function extra_paths()
  local paths = {}
  for _, dir in ipairs(vim.fn.glob("source/isaaclab*", false, true)) do
    if vim.fn.isdirectory(dir) == 1 then
      table.insert(paths, "./" .. dir)
    end
  end
  return paths
end

return {
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "requirements.txt",
    ".git",
  },
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        extraPaths = extra_paths(),
      },
    },
  },
}
