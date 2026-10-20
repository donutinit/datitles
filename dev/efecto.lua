-- Revisa una plantilla de efecto hecha con nodos de Fusion (sin Fuse) y, si se piden cuadros,
-- deja en JSON los nodos con sus valores ya resueltos en cada cuadro para que pelicula.py los
-- aproxime. Lo llama preview.lua.
--
-- Los ids de cada tipo de nodo salen de plantillas reales y del manual de Fusion; un id que no
-- esté aquí es un error, porque en Resolve no lo podemos probar.

local KNOWN = {
	PipeRouter = { "Input" },
	BrightnessContrast = { "Input", "EffectMask", "Blend", "Gain", "Lift", "Gamma", "Contrast", "Brightness",
		"Saturation", "Low", "High", "ClipBlack", "ClipWhite", "Red", "Green", "Blue", "Alpha" },
	Blur = { "Input", "EffectMask", "Blend", "Filter", "Red", "Green", "Blue", "Alpha", "XBlurSize", "YBlurSize",
		"LockXY", "ClippingMode", "Passes" },
	Merge = { "Background", "Foreground", "EffectMask", "Blend", "ApplyMode", "Operator", "Gain",
		"PerformDepthMerge", "SubtractiveAdditive" },
	FilmGrain = { "Input", "EffectMask", "Blend", "Complexity", "AlphaMultiply", "LogProcessing", "TimeLockSeed",
		"Seed", "Monochrome", "LockSizeXY", "MasterXSize", "MasterYSize", "MasterStrength", "MasterRoughness",
		"MasterOffset" },
	Transform = { "Input", "EffectMask", "Blend", "Center", "Pivot", "Size", "Angle", "Edges", "FilterMethod" },
	Shake = { "LockXY", "XMinimum", "XMaximum", "YMinimum", "YMaximum", "Smoothness", "RandomSeed" },
	EllipseMask = { "Filter", "SoftEdge", "Invert", "Width", "Height", "Center", "BorderWidth" },
}

-- Lo que sale de cada tipo de nodo.
local OUTPUTS = { Shake = "Position", EllipseMask = "Mask" }

local function set(list)
	local s = {}
	for _, v in ipairs(list) do
		s[v] = true
	end
	return s
end

local function num(x)
	return string.format("%.6f", x)
end

-- Un valor de entrada en JSON: número, punto, texto o FuID.
local function json(v)
	if type(v) == "number" then
		return num(v)
	elseif type(v) == "string" then
		return string.format("%q", v)
	elseif type(v) == "table" and v.__type == "FuID" then
		return string.format("%q", v[1])
	elseif type(v) == "table" and #v == 2 then
		return "[" .. num(v[1]) .. "," .. num(v[2]) .. "]"
	end
	return "null"
end

return function(group, check, render)
	local tools = group.Tools
	local inputsOf = {}
	for name, t in pairs(tools) do
		local known = KNOWN[t.__type]
		check(known, name .. ": tipo de nodo sin ids conocidos (" .. tostring(t.__type) .. ")")
		local ids = set(known or {})
		for id, uc in pairs(t.UserControls or {}) do
			ids[id] = uc
		end
		inputsOf[name] = ids
		for id, input in pairs(t.Inputs or {}) do
			check(ids[id], name .. "." .. id .. ": entrada que ese nodo no tiene")
			if input.SourceOp then
				local src = tools[input.SourceOp]
				check(src, name .. "." .. id .. ": viene de " .. input.SourceOp .. ", que no existe")
				if src then
					local out = OUTPUTS[src.__type] or "Output"
					check(input.Source == out, name .. "." .. id .. ": " .. input.SourceOp .. " no tiene la salida " .. tostring(input.Source))
				end
			end
		end
	end

	-- El clip entra por MainInput1 y sale por MainOutput1.
	local main = group.Inputs.MainInput1
	check(main and tools[main.SourceOp] and main.Source == "Input", "MainInput1 no entra a un nodo")
	local mainOut = group.Outputs.MainOutput1
	check(mainOut and tools[mainOut.SourceOp] and mainOut.Source == "Output", "MainOutput1 no sale de un nodo")

	-- Entradas publicadas: existen, y cada grupo plegable tiene detrás las que dice.
	local published = {}
	for key, inst in pairs(group.Inputs) do
		local n = tonumber(key:match("^Input(%d+)$"))
		if n then
			published[#published + 1] = { n = n, inst = inst }
		end
	end
	table.sort(published, function(a, b)
		return a.n < b.n
	end)
	for k, p in ipairs(published) do
		local inst = p.inst
		check(p.n == k, "las entradas publicadas no van de Input1 en adelante sin huecos")
		local ids = inputsOf[inst.SourceOp]
		check(ids and ids[inst.Source], "Input" .. p.n .. " publica " .. tostring(inst.SourceOp) .. "." .. tostring(inst.Source) .. ", que no existe")
		local uc = ids and type(ids[inst.Source]) == "table" and ids[inst.Source]
		local t = tools[inst.SourceOp]
		local input = t and (t.Inputs or {})[inst.Source]
		if inst.Default ~= nil then
			local v = input and input.Value
			if v == nil and uc then
				v = uc.INP_Default
			end
			check(v ~= nil and inst.Default == v, inst.SourceOp .. "." .. inst.Source .. ": Default no coincide con el valor del nodo")
		end
		if uc and uc.INPID_InputControl == "LabelControl" then
			check(k + uc.LBLC_NumInputs <= #published, inst.Source .. ": el grupo plegable pide más entradas de las que hay")
		end
	end

	-- Expresiones: Lua con time, Point y los valores de los demás nodos (Nodo.Entrada).
	local function value(t, id)
		local input = (t.Inputs or {})[id]
		if input and input.Value ~= nil then
			return input.Value
		end
		local uc = (t.UserControls or {})[id]
		return uc and uc.INP_Default
	end
	local function env(time)
		local e = setmetatable({ time = time, math = math }, {
			__index = function(_, name)
				local t = tools[name]
				if t then
					return setmetatable({}, { __index = function(_, id) return value(t, id) end })
				end
				return math[name]
			end,
		})
		e.Point = function(x, y)
			return { x, y }
		end
		return e
	end
	local exprs = {}
	for name, t in pairs(tools) do
		for id, input in pairs(t.Inputs or {}) do
			if input.Expression then
				local fn, err = loadstring("return " .. input.Expression)
				check(fn, name .. "." .. id .. ": la expresión no se entiende: " .. tostring(err))
				if fn then
					local ok, v = pcall(setfenv(fn, env(0)))
					check(ok and v ~= nil, name .. "." .. id .. ": la expresión falla: " .. tostring(v))
					exprs[#exprs + 1] = { tool = name, id = id, fn = fn }
				end
			end
		end
	end

	if not render then
		return
	end

	-- Nodos con sus valores en cada cuadro.
	local out = { '{"output":"' .. mainOut.SourceOp .. '","input":"' .. main.SourceOp .. '","duration":' .. render.duration .. ',"frames":[' }
	for f, time in ipairs(render.frames) do
		local resolved = {}
		for _, e in ipairs(exprs) do
			resolved[e.tool .. "." .. e.id] = setfenv(e.fn, env(time))()
		end
		local parts = {}
		for name, t in pairs(tools) do
			local fields = {}
			for id, input in pairs(t.Inputs or {}) do
				local v = resolved[name .. "." .. id]
				if v == nil then
					v = input.Value
				end
				if input.SourceOp then
					fields[#fields + 1] = string.format('%q:{"from":%q}', id, input.SourceOp)
				elseif v ~= nil then
					fields[#fields + 1] = string.format("%q:", id) .. json(v)
				end
			end
			parts[#parts + 1] = string.format('%q:{"type":%q,"inputs":{', name, t.__type) .. table.concat(fields, ",") .. "}}"
		end
		out[#out + 1] = (f > 1 and "," or "") .. '{"time":' .. time .. ',"tools":{' .. table.concat(parts, ",") .. "}}"
	end
	out[#out + 1] = "]}"
	local fh = assert(io.open(render.out, "wb"))
	fh:write(table.concat(out))
	fh:close()
end
