-- Rebuilds docs/DesignMap.html (opens in any browser) from
-- docs/DesignMap.source.html (the page as published to claude.ai, which adds
-- its own doctype and head). Run after editing the source (from the project
-- folder):
--   lune run tools/designmap
-- The published copy is https://claude.ai/artifact/5zbB8YiWAd4i67Rs4g2eU2:
-- ask Claude to republish docs/DesignMap.source.html to that link.
local fs = require("@lune/fs")

local HEAD = table.concat({
	"<!doctype html>",
	'<html lang="en">',
	'<meta charset="utf-8">',
	'<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">',
	"<style>[hidden]{display:none!important}body{margin:0}img{max-width:100%}</style>",
	"",
}, "\n")

local source = fs.readFile("docs/DesignMap.source.html")
fs.writeFile("docs/DesignMap.html", HEAD .. source)
print(`Wrote docs/DesignMap.html ({#HEAD + #source} bytes)`)
