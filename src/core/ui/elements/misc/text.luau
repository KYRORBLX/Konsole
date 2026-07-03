--[[
	@name text
	@author driftingAurora, dullflowerr
	@time June 12, 2026
]]

--!strict

local Text = {}

function Text.callable(value: any): boolean
	if type(value) == "function" then
		return true
	end

	local meta = getmetatable(value :: any)
	return type(meta) == "table" and type((meta :: any).__call) == "function"
end

function Text.trim(value: any): string
	return string.match(tostring(value or ""), "^%s*(.-)%s*$") or ""
end

function Text.cleanStart(value: any): string
	return (string.gsub(tostring(value or ""), "^%s+", ""))
end

function Text.richEscape(text: any): string
	local out = tostring(text or "")
	out = string.gsub(out, "&", "&amp;")
	out = string.gsub(out, "<", "&lt;")
	out = string.gsub(out, ">", "&gt;")
	out = string.gsub(out, "\"", "&quot;")
	return out
end

function Text.stripRich(text: any): string
	return (string.gsub(tostring(text or ""), "<[^>]->", ""))
end

function Text.lineCount(text: any): number
	local count = 1
	for _ in string.gmatch(tostring(text or ""), "\n") do
		count += 1
	end

	return count
end

function Text.linesOf(text: any): { string }
	local lines: { string } = {}
	local source = tostring(text or "")
	for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
		table.insert(lines, line)
	end

	return lines
end

function Text.editDistance(a: any, b: any): number
	local left = string.lower(tostring(a or ""))
	local right = string.lower(tostring(b or ""))

	local previous: { number } = {}
	for index = 1, #right + 1 do
		previous[index] = index - 1
	end

	for i = 1, #left do
		local current: { number } = { i }
		local aChar = string.sub(left, i, i)
		for j = 1, #right do
			local cost = aChar == string.sub(right, j, j) and 0 or 1
			current[j + 1] = math.min(previous[j + 1] + 1, current[j] + 1, previous[j] + cost)
		end
		previous = current
	end

	return previous[#right + 1] or 0
end

function Text.fuzzyScore(query: any, candidate: any): number
	local q = string.lower(tostring(query or ""))
	local c = string.lower(tostring(candidate or ""))
	if q == "" then
		return 0
	end
	if string.find(c, q, 1, true) == 1 then
		return 100
	end
	if string.find(c, q, 1, true) then
		return 75
	end

	local score = 0
	for queryWord in string.gmatch(q, "%S+") do
		local best = 0
		for candidateWord in string.gmatch(c, "%S+") do
			local distance = Text.editDistance(queryWord, candidateWord)
			if queryWord == candidateWord then
				best = math.max(best, 28)
			elseif string.find(candidateWord, queryWord, 1, true) then
				best = math.max(best, 18)
			elseif distance <= 1 then
				best = math.max(best, 16)
			elseif distance <= 2 and #queryWord >= 5 then
				best = math.max(best, 10)
			end
		end
		score += best
	end

	return score
end

return table.freeze(Text)
