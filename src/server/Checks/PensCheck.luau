--!strict
-- C01-M1 check 3 (spec 10.2), logic half: two players get different pens, and a rejoining player gets a free pen.
-- Drives MapService's pen allocator with fake players; the live half is the `pens` debug command in a 2-player
-- playtest. Not loaded at boot; run with the `check pens` debug command.

local MapService = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("MapService") :: ModuleScript)

local PensCheck = {}

function PensCheck.Run(): (boolean, string)
	local lines: { string } = {}
	local allOk = true
	local function expect(name: string, ok: boolean, detail: string)
		allOk = allOk and ok
		table.insert(lines, string.format("%s %-44s %s", if ok then "PASS" else "FAIL", name, detail))
	end

	local count = MapService.PenCount()
	expect("the map has 8 pen plots", count == 8, `found {count}`)

	local pens = MapService.NewPenAllocator(count)
	local a = pens:Assign("A")
	local b = pens:Assign("B")
	expect("two players get different pens", a ~= nil and b ~= nil and a ~= b, `A={a} B={b}`)
	expect("Assign is idempotent", pens:Assign("A") == a, `A again={pens:Assign("A")}`)

	pens:Release("A")
	expect("leaving frees the pen", pens:OwnerOf(a :: number) == nil and pens:PenOf("A") == nil, `pen {a} owner=nil`)
	local rejoin = pens:Assign("A")
	expect(
		"rejoining player gets a free pen",
		rejoin ~= nil and rejoin ~= b and pens:OwnerOf(rejoin :: number) == "A",
		`A rejoined -> {rejoin} (B keeps {b})`
	)

	for i = 1, count do
		pens:Assign(`P{i}`)
	end
	local overflow = pens:Assign("Extra")
	expect(`a player past {count} gets no pen`, overflow == nil, `Extra -> {overflow}`)

	pens:Release("B")
	local afterFree = pens:Assign("Extra")
	expect("a freed pen is reused", afterFree == b, `Extra -> {afterFree}`)

	table.insert(lines, if allOk then "PensCheck: ALL PASS" else "PensCheck: FAILURES ABOVE")
	return allOk, table.concat(lines, "\n")
end

return PensCheck
