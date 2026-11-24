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
	Transform = { "Input", "EffectMask", "Blend", "Center", "Pivot", "Size", "Angle", "Edges", "FilterMethod",
		"MotionBlur", "Quality", "ShutterAngle" },
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

return function(group, report, render)
	-- Con un problema no se simula: preview.lua lo cuenta al volver.
	local failed = false
	local function check(ok, msg)
		failed = failed or not ok
		report(ok, msg)
	end
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

	-- Valores cambiados con --valor ID=VALOR: ID es una entrada que solo un nodo tiene en
	-- UserControls o con valor en la plantilla, o Nodo.Entrada. Un punto se escribe X,Y.
	for _, o in ipairs(render and render.overrides or {}) do
		local name, id = o.id:match("^([^.]+)%.(.+)$")
		if not name then
			id = o.id
			for n, t in pairs(tools) do
				if (t.UserControls or {})[id] or (t.Inputs or {})[id] then
					check(not name, id .. ": la tienen varios nodos, usa Nodo." .. id)
					name = n
				end
			end
		end
		check(name and inputsOf[name] and inputsOf[name][id], "el efecto no tiene la entrada " .. o.id)
		if name and inputsOf[name] and inputsOf[name][id] then
			local v = o.value
			if type(v) == "string" then
				local x, y = v:match("^([^,]+),([^,]+)$")
				if tonumber(x) and tonumber(y) then
					v = { tonumber(x), tonumber(y) }
				end
			end
			tools[name].Inputs = tools[name].Inputs or {}
			tools[name].Inputs[id] = { Value = v }
		end
	end

	-- Expresiones: Lua con time, comp, Point, las entradas del mismo nodo por su id y las de los
	-- demás como Nodo.Entrada. Si empiezan con ":" son varias líneas que terminan en return.
	local duration = render and render.duration or 24 * 60
	local comp = {
		RenderStart = 0,
		RenderEnd = duration - 1,
		GetPrefs = function(_, name)
			local prefs = { Comp = { FrameFormat = { Rate = 24 } } }
			if name == nil then
				return prefs
			end
			return name == "Comp.FrameFormat.Rate" and 24 or nil
		end,
	}
	local function Point(x, y)
		return { x, y, X = x, Y = y }
	end
	local compiled = {}
	local value
	local function env(name, time, memo)
		local own = inputsOf[name]
		return setmetatable({ time = time, comp = comp, math = math, Point = Point }, {
			__index = function(_, key)
				if own[key] then
					return value(name, key, time, memo)
				end
				if tools[key] then
					return setmetatable({}, { __index = function(_, id) return value(key, id, time, memo) end })
				end
				return math[key]
			end,
		})
	end
	-- El valor de una entrada en un cuadro, con las expresiones resueltas y guardadas en memo.
	function value(name, id, time, memo)
		local key = name .. "." .. id
		if memo[key] == false then
			error("las expresiones se llaman en círculo en " .. key)
		end
		if memo[key] == nil then
			local t = tools[name]
			local input = (t.Inputs or {})[id] or {}
			local uc = (t.UserControls or {})[id]
			local v
			if input.Expression then
				memo[key] = false
				v = setfenv(compiled[key], env(name, time, memo))()
			elseif input.Value ~= nil then
				v = input.Value
			elseif type(uc) == "table" then
				if uc.LINKID_DataType == "Point" then
					v = { uc.INP_DefaultX or 0.5, uc.INP_DefaultY or 0.5 }
				else
					v = uc.INP_Default
				end
			end
			if type(v) == "table" and v.__type == nil and #v == 2 then
				v = Point(v[1], v[2])
			end
			memo[key] = v
		end
		return memo[key]
	end
	local exprs = {}
	for name, t in pairs(tools) do
		for id, input in pairs(t.Inputs or {}) do
			if input.Expression then
				local src = input.Expression
				src = src:sub(1, 1) == ":" and src:sub(2) or "return " .. src
				local fn, err = loadstring(src, "=" .. name .. "." .. id)
				check(fn, name .. "." .. id .. ": la expresión no se entiende: " .. tostring(err))
				if fn then
					compiled[name .. "." .. id] = fn
					exprs[#exprs + 1] = { tool = name, id = id }
				end
			end
		end
	end
	for _, e in ipairs(exprs) do
		local ok, v = pcall(value, e.tool, e.id, 0, {})
		check(ok and v ~= nil, e.tool .. "." .. e.id .. ": la expresión falla: " .. tostring(v))
	end

	if not render or failed then
		return
	end

	-- Nodos con sus valores en cada cuadro.
	local out = { '{"output":"' .. mainOut.SourceOp .. '","input":"' .. main.SourceOp .. '","duration":' .. render.duration .. ',"frames":[' }
	for f, time in ipairs(render.frames) do
		local resolved, memo = {}, {}
		for _, e in ipairs(exprs) do
			resolved[e.tool .. "." .. e.id] = value(e.tool, e.id, time, memo)
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
