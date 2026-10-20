-- Corre una plantilla de datitles con el simulador, como la armaría el Edit page, y deja en JSON
-- los glifos de cada cuadro para que render.py los dibuje. Antes revisa la plantilla contra su
-- Fuse: que cargue, que publique entradas que existen y en orden, que lo que no publica tenga
-- valor y que los grupos plegables cuadren.
--
-- Solo revisar:       luajit dev/preview.lua PLANTILLA
-- Revisar y simular:  luajit dev/preview.lua PLANTILLA METRICAS.lua SALIDA.json ANCHO ALTO
--                     CUADROS_DEL_CLIP CUADRO... [--texto ARCHIVO] [--valor ID=VALOR]...

local root = arg[0]:match("^(.*)/dev/[^/]*$") or "."
local settingPath, metricsPath, outPath = arg[1], arg[2], arg[3]
local width, height, duration = tonumber(arg[4]), tonumber(arg[5]), tonumber(arg[6])
local frames, textPath, overrides = {}, nil, {}
local i = 7
while arg[i] do
	if arg[i] == "--texto" then
		textPath = arg[i + 1]
		i = i + 2
	elseif arg[i] == "--valor" then
		local id, v = arg[i + 1]:match("^([^=]+)=(.*)$")
		overrides[#overrides + 1] = { id = id, value = tonumber(v) or v }
		i = i + 2
	else
		frames[#frames + 1] = tonumber(arg[i])
		i = i + 1
	end
end
local settingName = settingPath:match("([^/]+)%.setting$")

local mock = dofile(root .. "/dev/fusion_mock.lua")
if metricsPath then
	mock.metrics = dofile(metricsPath)
end
mock.renderEnd = (duration or 1) - 1

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

local problems = {}
local function check(ok, msg)
	if not ok then
		problems[#problems + 1] = msg
	end
end
local function finish()
	if #problems > 0 then
		io.stderr:write(settingName .. ".setting:\n  " .. table.concat(problems, "\n  ") .. "\n")
		os.exit(1)
	end
end

local setting = readSetting(settingPath)
local group = setting.Tools[setting.ActiveTool]
check(group and group.__type == "GroupOperator", "ActiveTool no es el GroupOperator")
finish()

local tool, toolName, fuseId
for name, t in pairs(group.Tools) do
	local id = t.__type:match("^Fuse%.(.+)$")
	if id then
		tool, toolName, fuseId = t, name, id
	end
end
-- Sin Fuse es un efecto hecho con nodos de Fusion: lo revisa efecto.lua.
if not tool then
	local efecto = dofile(root .. "/dev/efecto.lua")
	efecto(group, check, metricsPath and { out = outPath, frames = frames, duration = duration } or nil)
	finish()
	os.exit(0)
end

-- El Fuse que registra ese id, entre los de Fuses/.
local fusePath
for file in io.popen('ls "' .. root .. '/Fuses"'):lines() do
	if file:match("%.fuse$") then
		local src = assert(io.open(root .. "/Fuses/" .. file, "rb")):read("*a")
		if src:find('FuRegisterClass("' .. fuseId .. '"', 1, true) then
			fusePath = root .. "/Fuses/" .. file
		end
	end
end
check(fusePath, "ningún Fuse registra " .. fuseId)
finish()

dofile(fusePath)
Create()

check(group.Outputs.MainOutput1.SourceOp == toolName, "la salida del macro no es el Fuse")
check(group.Tools[tool.Inputs.Input.SourceOp], "la entrada del Fuse apunta a una herramienta que no existe")

-- Posición de cada entrada en el Fuse y el grupo plegable al que pertenece.
local index, nestOf = {}, {}
for j, id in ipairs(self.order) do
	index[id] = j
end
for id, nest in pairs(self.nests) do
	for j = 1, nest.count do
		nestOf[self.order[index[id] + j]] = id
	end
end

-- Valores que la plantilla le pone al Fuse, con las expresiones del rango de la comp.
local fixed = {}
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
				fixed[id] = input.Value
			end
		end
	end
end

-- Entradas publicadas en su orden (InputN), contra las del Fuse.
local published = {}
for key, inst in pairs(group.Inputs) do
	published[#published + 1] = { n = tonumber(key:match("^Input(%d+)$")), inst = inst }
end
table.sort(published, function(a, b)
	return a.n < b.n
end)
local sources, isPublished, lastIndex = {}, {}, 0
for k, p in ipairs(published) do
	local inst = p.inst
	check(p.n == k, "las entradas publicadas no van de Input1 en adelante sin huecos")
	check(inst.SourceOp == toolName, "Input" .. p.n .. " no viene del Fuse")
	local inp = self.inputs[inst.Source]
	check(inp, "Input" .. p.n .. " publica " .. tostring(inst.Source) .. ", que el Fuse no tiene")
	if inp then
		check(index[inst.Source] > lastIndex, inst.Source .. ": publicada fuera del orden del Fuse")
		lastIndex = index[inst.Source]
		local expected = fixed[inst.Source]
		if expected == nil then
			expected = inp.attrs.INP_Default
		elseif inp.attrs.LINKID_DataType == "Number" then
			check(inst.Default ~= nil, inst.Source .. ": la plantilla le pone valor y no lo publica como Default")
		end
		if inst.Default ~= nil then
			check(inst.Default == expected, inst.Source .. ": Default no coincide con el valor de la plantilla")
		end
	end
	sources[k] = inst.Source
	isPublished[inst.Source] = k
end

-- Lo que no se publica necesita valor en la plantilla o ir dentro de un grupo que no se publica.
for _, id in ipairs(self.order) do
	local a = self.inputs[id].attrs
	if a.IC_Visible ~= false and a.LINKID_DataType ~= "Image" and not self.nests[id] and not isPublished[id] then
		local nest = nestOf[id]
		check(fixed[id] ~= nil or (nest and not isPublished[nest]), "el macro no publica " .. id .. " ni le pone valor")
	end
	if isPublished[id] and nestOf[id] then
		check(isPublished[nestOf[id]], id .. ": publicada sin su grupo plegable " .. nestOf[id])
	end
end
for id, nest in pairs(self.nests) do
	local k = isPublished[id]
	if k then
		for j = 1, nest.count do
			check(sources[k + j] == self.order[index[id] + j], id .. ": el grupo plegable no cuadra en el macro")
		end
	end
end

-- La plantilla de créditos guarda el mismo texto por omisión que el Fuse.
if settingName == "datitles creditos" then
	check(tool.Inputs.Credits.Value == self.inputs.Credits.attrs.INPS_DefaultText,
		"el texto por omisión del macro y el del Fuse no son iguales")
end
finish()

if not metricsPath then
	os.exit(0)
end

if textPath then
	self.inputs.Credits.value = assert(io.open(textPath, "rb")):read("*a")
end
for _, o in ipairs(overrides) do
	assert(self.inputs[o.id], "el Fuse no tiene la entrada " .. tostring(o.id))
	self.inputs[o.id].value = o.value
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
		parts[#parts + 1] = '{"color":[' .. num(c.R) .. ',' .. num(c.G) .. ',' .. num(c.B) .. ',' .. num(c.A)
			.. '],"glyphs":[' .. table.concat(gl, ",") .. ']}'
	end
	local fill = img.fill and ('[' .. num(img.fill.R) .. ',' .. num(img.fill.G) .. ',' .. num(img.fill.B) .. ',' .. num(img.fill.A) .. ']') or "null"
	out[#out + 1] = (f > 1 and "," or "") .. '{"time":' .. t .. ',"fill":' .. fill .. ',"draws":[' .. table.concat(parts, ",") .. ']}'
	io.stderr:write(("cuadro %d: %d grupos, %.1f ms\n"):format(t, #parts, (os.clock() - t0) * 1000))
end
out[#out + 1] = "]}"
local fh = assert(io.open(outPath, "wb"))
fh:write(table.concat(out))
fh:close()
