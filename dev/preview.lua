-- Corre datitles.fuse con el simulador, como lo armaría el título de Edit page, y deja en JSON
-- los glifos de cada cuadro para que render.py los dibuje. Antes revisa el .setting contra el
-- Fuse: que cargue, que publique entradas que existen y que los grupos plegables cuadren.
--
-- luajit dev/preview.lua METRICAS.lua SALIDA.json ANCHO ALTO CUADROS_DEL_CLIP CUADRO... [--texto ARCHIVO]

local root = arg[0]:match("^(.*)/dev/[^/]*$") or "."
local metricsPath, outPath = arg[1], arg[2]
local width, height, duration = tonumber(arg[3]), tonumber(arg[4]), tonumber(arg[5])
local frames, textPath = {}, nil
local i = 6
while arg[i] do
	if arg[i] == "--texto" then
		textPath = arg[i + 1]
		i = i + 2
	else
		frames[#frames + 1] = tonumber(arg[i])
		i = i + 1
	end
end

local mock = dofile(root .. "/dev/fusion_mock.lua")
mock.metrics = dofile(metricsPath)
mock.renderEnd = duration - 1

dofile(root .. "/Fuses/datitles.fuse")
local fuseType = "Fuse." .. mock.registered.id
Create()

-- El .setting es una tabla de Lua con constructores de Fusion; aquí cada uno solo etiqueta.
local function readSetting(path)
	local src = assert(io.open(path, "rb")):read("*a")
	local env = setmetatable({}, {
		__index = function(_, name)
			if name == "ordered" then
				return function()
					return function(t)
						return t
					end
				end
			end
			local function ctor(kind)
				return function(t)
					t.__type = kind
					return t
				end
			end
			if name == "Fuse" then
				return setmetatable({}, {
					__index = function(_, id)
						return ctor("Fuse." .. id)
					end,
				})
			end
			return ctor(name)
		end,
	})
	local fn = assert(loadstring("return " .. src, "@" .. path))
	setfenv(fn, env)
	return fn()
end

local setting = readSetting(root .. "/Templates/Edit/Titles/datitles.setting")
local problems = {}
local function check(ok, msg)
	if not ok then
		problems[#problems + 1] = msg
	end
end

local group = setting.Tools[setting.ActiveTool]
check(group and group.__type == "GroupOperator", "ActiveTool no es el GroupOperator")
local tool, toolName
for name, t in pairs(group.Tools) do
	if t.__type == fuseType then
		tool, toolName = t, name
	end
end
check(tool, "el macro no trae un " .. fuseType)
check(group.Outputs.MainOutput1.SourceOp == toolName, "la salida del macro no es el Fuse")
check(group.Tools[tool.Inputs.Input.SourceOp], "la entrada del Fuse apunta a una herramienta que no existe")

-- Entradas publicadas en su orden (InputN), contra las del Fuse.
local published = {}
for key, inst in pairs(group.Inputs) do
	published[#published + 1] = { n = tonumber(key:match("^Input(%d+)$")), inst = inst }
end
table.sort(published, function(a, b)
	return a.n < b.n
end)
local sources = {}
for k, p in ipairs(published) do
	local inst = p.inst
	check(inst.SourceOp == toolName, "Input" .. p.n .. " no viene del Fuse")
	local inp = self.inputs[inst.Source]
	check(inp, "Input" .. p.n .. " publica " .. tostring(inst.Source) .. ", que el Fuse no tiene")
	if inp and inst.Default ~= nil then
		check(inst.Default == inp.attrs.INP_Default, inst.Source .. ": Default no coincide con el Fuse")
	end
	sources[k] = inst.Source
end
local isPublished = {}
for k, s in ipairs(sources) do
	isPublished[s] = k
end
for _, id in ipairs(self.order) do
	local a = self.inputs[id].attrs
	if a.IC_Visible ~= false and a.LINKID_DataType ~= "Image" then
		check(isPublished[id], "el macro no publica " .. id)
	end
end
for id, nest in pairs(self.nests) do
	local k = isPublished[id]
	if k then
		local start
		for j, oid in ipairs(self.order) do
			if oid == id then
				start = j
			end
		end
		for j = 1, nest.count do
			check(sources[k + j] == self.order[start + j], id .. ": el grupo plegable no cuadra en el macro")
		end
	end
end

-- Valores del Fuse dentro del macro, con las expresiones del rango de la comp.
for id, input in pairs(tool.Inputs) do
	if id ~= "Input" then
		local inp = self.inputs[id]
		check(inp, "el macro le pone " .. id .. " al Fuse, que no existe")
		if inp then
			if input.Expression == "comp.RenderStart" then
				inp.value = 0
			elseif input.Expression == "comp.RenderEnd" then
				inp.value = mock.renderEnd
			elseif input.Expression then
				check(false, id .. ": expresión desconocida para el simulador")
			else
				inp.value = input.Value
			end
		end
	end
end
check(tool.Inputs.Credits.Value == self.inputs.Credits.attrs.INPS_DefaultText,
	"el texto por omisión del macro y el del Fuse no son iguales")

if #problems > 0 then
	io.stderr:write("datitles.setting:\n  " .. table.concat(problems, "\n  ") .. "\n")
	os.exit(1)
end

if textPath then
	self.inputs.Credits.value = assert(io.open(textPath, "rb")):read("*a")
end

-- Cuadros --------------------------------------------------------------------------------

local function num(x)
	return string.format("%.6f", x)
end

local out = { '{"width":' .. width .. ',"height":' .. height .. ',"frames":[' }
for f, t in ipairs(frames) do
	InImage.value = mock.image(width, height)
	local t0 = os.clock()
	Process(mock.request(t))
	local img = mock.output
	local parts = {}
	for _, d in ipairs(img.draws) do
		local gl = {}
		for _, g in ipairs(d.glyphs) do
			gl[#gl + 1] = '[' .. g.cp .. ',"' .. g.face .. '",' .. num(g.em) .. ',' .. num(g.x) .. ',' .. num(g.y) .. ']'
		end
		local c = d.color
		parts[#parts + 1] = '{"color":[' .. num(c.R) .. ',' .. num(c.G) .. ',' .. num(c.B) .. '],"glyphs":[' .. table.concat(gl, ",") .. ']}'
	end
	local fill = img.fill and ('[' .. num(img.fill.R) .. ',' .. num(img.fill.G) .. ',' .. num(img.fill.B) .. ',' .. num(img.fill.A) .. ']') or "null"
	out[#out + 1] = (f > 1 and "," or "") .. '{"time":' .. t .. ',"fill":' .. fill .. ',"draws":[' .. table.concat(parts, ",") .. ']}'
	io.stderr:write(("cuadro %d: %d grupos, %.1f ms\n"):format(t, #parts, (os.clock() - t0) * 1000))
end
out[#out + 1] = "]}"
local fh = assert(io.open(outPath, "wb"))
fh:write(table.concat(out))
fh:close()
