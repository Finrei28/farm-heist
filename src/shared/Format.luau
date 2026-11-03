-- Numbers as players read them: 1234567 → "1,234,567". Every note and
-- window that names an amount goes through this (UI.formatNumber on the
-- client), so no amount shows up without its commas.
local Format = {}

function Format.number(n: number): string
	local text = string.reverse((string.gsub(string.reverse(tostring(math.floor(n))), "(%d%d%d)", "%1,")))
	return (string.gsub(text, "^,", ""))
end

return Format
