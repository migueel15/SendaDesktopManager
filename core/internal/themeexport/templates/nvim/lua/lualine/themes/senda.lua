-- Generado por Senda a partir del tema "{{.Name}}". Se sobrescribe al cambiar de tema.
-- Uso: require("lualine").setup({ options = { theme = "senda" } })
-- Sigue la distribución de colores del tema de lualine de catppuccin/nvim (MIT).
local c = { bg = "{{.K.mantle}}", fg = "{{.K.text}}" }

local function mode(color)
  return { a = { bg = color, fg = "{{.K.mantle}}", gui = "bold" }, b = { bg = "{{.K.surface0}}", fg = color }, c = c }
end

return {
  normal = mode("{{.K.blue}}"),
  insert = mode("{{.K.green}}"),
  terminal = mode("{{.K.green}}"),
  command = mode("{{.K.peach}}"),
  visual = mode("{{.K.mauve}}"),
  replace = mode("{{.K.red}}"),
  inactive = {
    a = { bg = "{{.K.mantle}}", fg = "{{.K.blue}}" },
    b = { bg = "{{.K.mantle}}", fg = "{{.K.surface1}}", gui = "bold" },
    c = { bg = "{{.K.mantle}}", fg = "{{.K.overlay0}}" },
  },
}
