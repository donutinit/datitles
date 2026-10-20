--[[--
datitles: créditos finales que suben de abajo hacia arriba, o tarjetas centradas con fade.

Un solo texto con marcas simples:

  # Título         display grande en el color del título; varias líneas seguidas forman un bloque
  ## Cierre        display mediano, como "Fin"
  Rol | Nombre     fila a dos columnas: el rol a la izquierda, el nombre a la derecha
  | Nombre         solo el nombre, en la columna derecha
  Texto suelto     línea centrada en mono: departamentos y notas
  > Comentario     línea en la fuente de texto, tal como se escribe; varias seguidas son un párrafo
  línea vacía      separa bloques

Con Tipo en Rollo, los créditos cruzan la pantalla de abajo hacia arriba en todo el clip. Con Tipo
en Tarjetas, cada bloque se vuelve una tarjeta centrada que entra y sale con fade.

Copyright (C) 2026 Von Diego · AGPL-3.0-only · https://github.com/donutinit/datitles
--]]--

FuRegisterClass("datitles", CT_Tool, {
	REGS_Name = "datitles",
	REGS_Category = "Fuses\\datitles",
	REGS_OpIconString = "dTi",
	REGS_OpDescription = "Créditos que suben o tarjetas con fade",
	REGS_URL = "https://github.com/donutinit/datitles",
	REG_OpNoMask = true,
	REG_NoObjMatCtrls = true,
	REG_NoMotionBlurCtrls = true,
	REG_TimeVariant = true, -- el rollo cambia en cada cuadro aunque nada esté animado
	REG_Version = 3,
})

local DEFAULT_TEXT = [[
# Título
# de la película

Dirección | Nombre Apellido
Guion | Nombre Apellido
Producción | Nombre Apellido
| Nombre Apellido

Fotografía
Dirección de fotografía | Nombre Apellido
Operación de cámara | Nombre Apellido

> Gracias a quienes hicieron posible esta película.

## Fin

Ciudad, Estado]]

local FONTS = {
	{ key = "title", id = "Title", label = "Títulos", font = "League Gothic", style = "Regular" },
	{ key = "text", id = "Text", label = "Texto", font = "Newsreader", style = "Regular" },
	{ key = "mono", id = "Mono", label = "Mono", font = "IBM Plex Mono", style = "Regular" },
}

-- Colores por omisión, en sRGB.
local COLORS = {
	{ key = "paper", id = "Paper", label = "Fondo", rgb = { 0.0479, 0.0314, 0.0288 } },
	{ key = "accent", id = "Accent", label = "Título", rgb = { 0.8317, 0.0456, 0.0471 } },
	{ key = "ink", id = "Ink", label = "Nombres y cierre", rgb = { 0.9266, 0.9051, 0.8817 } },
	{ key = "muted", id = "Muted", label = "Roles y mono", rgb = { 0.6072, 0.5781, 0.5655 } },
}

-- El tamaño del texto va en % del alto del cuadro; lo demás, en múltiplos del texto, para que
-- todo escale junto.
local MEASURES = {
	{ key = "size", id = "Size", label = "Texto (% del alto)", default = 2.4, min = 0.5, max = 6 },
	{ key = "titleScale", id = "TitleScale", label = "Título (× texto)", default = 5.2, min = 1, max = 10 },
	{ key = "closeScale", id = "CloseScale", label = "Cierre (× texto)", default = 3.7, min = 1, max = 10 },
	{ key = "monoScale", id = "MonoScale", label = "Mono (× texto)", default = 0.867, min = 0.5, max = 1.5 },
	{ key = "roleScale", id = "RoleScale", label = "Rol en una columna (× texto)", default = 0.8, min = 0.5, max = 1.5 },
	{ key = "width", id = "Width", label = "Ancho (% del ancho)", default = 58, min = 20, max = 100 },
	{ key = "gutter", id = "Gutter", label = "Entre columnas (× texto)", default = 1.6, min = 0, max = 6 },
	{ key = "lineHeight", id = "LineHeight", label = "Interlineado", default = 1.6, min = 0.8, max = 3 },
	{ key = "rowGap", id = "RowGap", label = "Entre filas (× texto)", default = 0.533, min = 0, max = 3 },
	{ key = "blockGap", id = "BlockGap", label = "Entre bloques (× texto)", default = 4.267, min = 0, max = 12 },
}

-- Cómo se ve cada tipo de línea centrada: fuente, interlineado y espaciado entre letras en em, y
-- si va en mayúsculas cuando el control Mayúsculas está prendido. Sin lh, usa el Interlineado.
local STYLES = {
	title = { font = "title", lh = 1, ls = 0.01, color = "accent", caps = true },
	close = { font = "close", lh = 1.02, ls = 0.01, color = "ink", caps = true },
	note = { font = "mono", lh = 1.5, ls = 0.08, color = "muted", caps = true },
	comment = { font = "text", ls = 0, color = "muted" },
}

-- @comun

function Create()
	InText = self:AddInput("Créditos", "Credits", {
		LINKID_DataType = "Text",
		INPID_InputControl = "TextEditControl",
		TEC_Lines = 16,
		INPS_DefaultText = DEFAULT_TEXT,
	})
	InKind = self:AddInput("Tipo", "Kind", {
		LINKID_DataType = "Number",
		INPID_InputControl = "MultiButtonControl",
		INP_Default = 0,
		INP_Integer = true,
		{ MBTNC_AddButton = "Rollo", MBTNCD_ButtonWidth = 0.5 },
		{ MBTNC_AddButton = "Tarjetas", MBTNCD_ButtonWidth = 0.5 },
	})

	self:BeginControlNest("Animación", "AnimationNest", true)
	InMode = self:AddInput("Duración", "Mode", {
		LINKID_DataType = "Number",
		INPID_InputControl = "MultiButtonControl",
		INP_Default = 0,
		INP_Integer = true,
		{ MBTNC_AddButton = "Todo el clip", MBTNCD_ButtonWidth = 0.5 },
		{ MBTNC_AddButton = "Manual", MBTNCD_ButtonWidth = 0.5 },
	})
	InProgress = self:AddInput("Progreso (manual)", "Progress", {
		LINKID_DataType = "Number",
		INPID_InputControl = "SliderControl",
		INP_Default = 0,
		INP_MinScale = 0,
		INP_MaxScale = 1,
	})
	self:EndControlNest()

	self:BeginControlNest("Rollo", "RollNest", true)
	InEdge = self:AddInput("Bordes difuminados (% del alto)", "EdgeFade", {
		LINKID_DataType = "Number",
		INPID_InputControl = "SliderControl",
		INP_Default = 0,
		INP_MinScale = 0,
		INP_MaxScale = 30,
		INP_MinAllowed = 0,
	})
	InHold = self:AddInput("Detener el cierre", "HoldClose", {
		LINKID_DataType = "Number",
		INPID_InputControl = "CheckboxControl",
		INP_Default = 0,
		INP_Integer = true,
	})
	InHoldTime = self:AddInput("Pausa del cierre (s)", "HoldTime", {
		LINKID_DataType = "Number",
		INPID_InputControl = "SliderControl",
		INP_Default = 3,
		INP_MinScale = 0,
		INP_MaxScale = 10,
		INP_MinAllowed = 0,
	})
	InCloseFade = self:AddInput("Fade del cierre (s)", "CloseFade", {
		LINKID_DataType = "Number",
		INPID_InputControl = "SliderControl",
		INP_Default = 1,
		INP_MinScale = 0,
		INP_MaxScale = 3,
		INP_MinAllowed = 0,
	})
	InWhole = self:AddInput("Píxeles enteros", "WholePixels", {
		LINKID_DataType = "Number",
		INPID_InputControl = "CheckboxControl",
		INP_Default = 0,
		INP_Integer = true,
	})
	self:EndControlNest()

	self:BeginControlNest("Tarjetas", "CardsNest", true)
	InFade = self:AddInput("Fade (s)", "Fade", {
		LINKID_DataType = "Number",
		INPID_InputControl = "SliderControl",
		INP_Default = 1,
		INP_MinScale = 0,
		INP_MaxScale = 3,
		INP_MinAllowed = 0,
	})
	InPacing = self:AddInput("Reparto", "Pacing", {
		LINKID_DataType = "Number",
		INPID_InputControl = "MultiButtonControl",
		INP_Default = 1,
		INP_Integer = true,
		{ MBTNC_AddButton = "Igual", MBTNCD_ButtonWidth = 0.5 },
		{ MBTNC_AddButton = "Según texto", MBTNCD_ButtonWidth = 0.5 },
	})
	self:EndControlNest()

	self:BeginControlNest("Tipografía", "FontNest", false)
	InFonts = addFontInputs(FONTS)
	InUpper = self:AddInput("Mayúsculas", "Uppercase", {
		LINKID_DataType = "Number",
		INPID_InputControl = "CheckboxControl",
		INP_Default = 1,
		INP_Integer = true,
	})
	self:EndControlNest()

	self:BeginControlNest("Medidas", "SizeNest", false)
	InRows = self:AddInput("Filas", "Rows", {
		LINKID_DataType = "Number",
		INPID_InputControl = "MultiButtonControl",
		INP_Default = 0,
		INP_Integer = true,
		{ MBTNC_AddButton = "Dos columnas", MBTNCD_ButtonWidth = 0.5 },
		{ MBTNC_AddButton = "Una columna", MBTNCD_ButtonWidth = 0.5 },
	})
	InMeasures = {}
	for _, m in ipairs(MEASURES) do
		InMeasures[m.key] = self:AddInput(m.label, m.id, {
			LINKID_DataType = "Number",
			INPID_InputControl = "SliderControl",
			INP_Default = m.default,
			INP_MinScale = m.min,
			INP_MaxScale = m.max,
			INP_MinAllowed = 0,
		})
	end
	self:EndControlNest()

	self:BeginControlNest("Colores", "ColorNest", false)
	InSolid = self:AddInput("Fondo sólido", "SolidBackground", {
		LINKID_DataType = "Number",
		INPID_InputControl = "CheckboxControl",
		INP_Default = 1,
		INP_Integer = true,
	})
	InColors = addColorInputs(COLORS)
	self:EndControlNest()

	addClipInputs()

	InImage = self:AddInput("Input", "Input", {
		LINKID_DataType = "Image",
		LINK_Main = 1,
	})
	OutImage = self:AddOutput("Output", "Output", {
		LINKID_DataType = "Image",
		LINK_Main = 1,
	})
end

function NotifyChanged(inp, param, time)
	fontDefaults(FONTS, InFonts, inp, param, time)
end

-- Texto -------------------------------------------------------------------------------------

local function parse(text)
	text = text:gsub("\r\n?", "\n")
	local blocks, block = {}, nil
	for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
		local line = trim(raw)
		if line == "" then
			block = nil
		else
			local item
			local close = line:match("^##%s*(.*)$")
			local title = line:match("^#%s*(.*)$")
			local comment = line:match("^>%s*(.*)$")
			if close then
				item = { kind = "close", text = close }
			elseif title then
				item = { kind = "title", text = title }
			elseif comment then
				item = { kind = "comment", text = comment }
			elseif line:find("|", 1, true) then
				local role, name = line:match("^(.-)|(.*)$")
				item = { kind = "row", role = trim(role), name = trim(name) }
			else
				item = { kind = "note", text = line }
			end
			if not block then
				block = {}
				blocks[#blocks + 1] = block
			end
			block[#block + 1] = item
		end
	end
	return blocks
end

-- Maquetación ------------------------------------------------------------------------------

-- Distancias desde el borde superior del rollo, hacia abajo, en unidades de salida.
local function buildLayout(p, aspect)
	local em = p.size / 100 * aspect
	local fonts = {
		title = loadFont(p.fonts.title, em * p.titleScale),
		close = loadFont(p.fonts.title, em * p.closeScale),
		text = loadFont(p.fonts.text, em),
		role = loadFont(p.fonts.text, em * p.roleScale),
		mono = loadFont(p.fonts.mono, em * p.monoScale),
	}
	local blockW = p.width / 100
	local gutter = p.gutter * em
	local colW = math.max(em, (blockW - gutter) / 2)
	local rowGap = p.rowGap * em
	local runs = {}

	local function addLine(f, cps, x, top, lh, color, ls)
		local half = (lh - (f.asc + f.desc)) / 2
		runs[#runs + 1] = {
			font = f,
			cps = cps,
			x = x,
			base = top + half + f.asc,
			top = top,
			bottom = top + lh,
			color = color,
			ls = ls,
		}
	end

	local blocks = {}
	local d = 0
	for b, block in ipairs(parse(p.text)) do
		if b > 1 then
			d = d + p.blockGap * em
		end
		local first, words = #runs + 1, 0
		local prev
		for _, item in ipairs(block) do
			for _, s in ipairs({ item.text or "", item.role or "", item.name or "" }) do
				for _ in s:gmatch("%S+") do
					words = words + 1
				end
			end
			if prev then
				-- Las líneas seguidas de un título son un solo párrafo, sin hueco entre ellas.
				if item.kind ~= prev or item.kind == "row" or item.kind == "note" then
					d = d + rowGap
				end
				-- El departamento lleva un margen extra antes de sus filas.
				if prev == "note" and item.kind == "row" then
					d = d + rowGap
				end
				-- En una columna, cada rol nuevo se separa de la pareja anterior; "| Nombre" se queda pegado.
				if p.rows > 0.5 and prev == "row" and item.kind == "row" and item.role ~= "" then
					d = d + rowGap * 2
				end
			end
			if item.kind == "row" and p.rows > 0.5 then
				-- Una columna: el rol chico arriba y el nombre abajo, centrados.
				local rf, f = fonts.role, fonts.text
				local rlh, lh = p.lineHeight * rf.em, p.lineHeight * em
				for _, ln in ipairs(wrap(rf, codepoints(item.role), 0, blockW)) do
					addLine(rf, ln, 0.5 - measure(rf, ln, 0) / 2, d, rlh, "muted", 0)
					d = d + rlh
				end
				for _, ln in ipairs(wrap(f, codepoints(item.name), 0, blockW)) do
					addLine(f, ln, 0.5 - measure(f, ln, 0) / 2, d, lh, "ink", 0)
					d = d + lh
				end
			elseif item.kind == "row" then
				local f = fonts.text
				local lh = p.lineHeight * em
				local roles = wrap(f, codepoints(item.role), 0, colW)
				local names = wrap(f, codepoints(item.name), 0, colW)
				for i, ln in ipairs(roles) do
					addLine(f, ln, 0.5 - gutter / 2 - measure(f, ln, 0), d + (i - 1) * lh, lh, "muted", 0)
				end
				for i, ln in ipairs(names) do
					addLine(f, ln, 0.5 + gutter / 2, d + (i - 1) * lh, lh, "ink", 0)
				end
				d = d + math.max(#roles, #names, 1) * lh
			else
				local s = STYLES[item.kind]
				local f = fonts[s.font]
				local ls = s.ls * f.em
				local lh = (s.lh or p.lineHeight) * f.em
				local maxW = (item.kind == "note" or item.kind == "comment") and blockW or 0.9
				local cps = codepoints(item.text)
				if s.caps and p.upper > 0.5 then
					cps = upper(cps)
				end
				for _, ln in ipairs(wrap(f, cps, ls, maxW)) do
					addLine(f, ln, 0.5 - measure(f, ln, ls) / 2, d, lh, s.color, ls)
					d = d + lh
				end
			end
			prev = item.kind
		end
		-- Lo que ocupa el bloque en pantalla, para centrarlo cuando es una tarjeta.
		local info = { runs = {}, words = words, top = math.huge, bottom = -math.huge }
		for i = first, #runs do
			local r = runs[i]
			info.runs[#info.runs + 1] = r
			info.top = math.min(info.top, r.top)
			info.bottom = math.max(info.bottom, r.bottom)
		end
		if #info.runs > 0 then
			blocks[#blocks + 1] = info
		end
	end
	-- Margen inferior del rollo, como el padding de .credits__roll.
	d = d + p.blockGap * em
	return { runs = runs, blocks = blocks, height = d, em = em }
end

local cache = {}

local function getLayout(p, aspect)
	local key = { p.text, aspect, p.rows, p.upper }
	for _, f in ipairs(FONTS) do
		key[#key + 1] = p.fonts[f.key][1]
		key[#key + 1] = p.fonts[f.key][2]
	end
	for _, m in ipairs(MEASURES) do
		key[#key + 1] = p[m.key]
	end
	for i = 1, #key do
		key[i] = tostring(key[i])
	end
	key = table.concat(key, "\0")
	if cache.key ~= key then
		cache.key = key
		cache.layout = buildLayout(p, aspect)
	end
	return cache.layout
end

-- Cuánto tarda en leerse una tarjeta, en segundos, sin contar sus fades.
local function readingTime(block)
	return 1.5 + 0.3 * block.words
end

-- Hasta dónde sube el rollo y cuántos segundos se queda quieto al final. Sin pausa, sale entero
-- por arriba; con pausa, el último bloque se detiene en el centro.
local function rollStop(layout, aspect, r)
	if r.hold and #layout.blocks > 0 then
		local b = layout.blocks[#layout.blocks]
		return (b.top + b.bottom) / 2 + aspect / 2, r.holdTime + r.closeFade
	end
	return layout.height + aspect, 0
end

-- Lo que conviene que dure el clip, para escribirlo en la consola. px es cuántos píxeles mide
-- una unidad de salida en vertical.
local function advice(layout, aspect, s)
	if s.cards then
		local seconds = 0
		for _, b in ipairs(layout.blocks) do
			seconds = seconds + readingTime(b) + 2 * s.fade
		end
		return ("datitles: %d tarjetas, para leerlas con calma el clip dura %.0f s"):format(#layout.blocks, seconds)
	end
	local stop, tail = rollStop(layout, aspect, s.roll)
	-- Ritmo de lectura de referencia: 70 px/s con filas de 15 px (unas dos filas por segundo),
	-- y nunca menos de 20 s.
	local seconds = math.max(20, stop / (layout.em * 70 / 15))
	if s.roll.whole then
		local speed = math.max(1, math.floor(stop * s.px / (seconds * s.fps) + 0.5))
		local frames = math.ceil(stop * s.px / speed + tail * s.fps) + 1
		return ("datitles: a %d px por cuadro, el clip dura %d cuadros (%.1f s)"):format(speed, frames, frames / s.fps)
	end
	return ("datitles: a un ritmo de lectura cómodo, el clip dura %.0f s"):format(seconds + tail)
end

-- Animación ---------------------------------------------------------------------------------

local function progress(req, first, last)
	if InMode:GetValue(req).Value > 0.5 then
		return clamp(InProgress:GetValue(req).Value)
	end
	if last <= first then
		return 0
	end
	return clamp((req.Time - first) / (last - first))
end

-- La tarjeta que toca en t (de 0 a 1) y su opacidad. Con el reparto según texto, cada tarjeta
-- dura en proporción a su tiempo de lectura más sus fades.
local function card(blocks, t, frames, fade, fps, byText)
	local weights, total = {}, 0
	for k, b in ipairs(blocks) do
		weights[k] = byText and readingTime(b) + 2 * fade or 1
		total = total + weights[k]
	end
	local start = 0
	for k, b in ipairs(blocks) do
		local w = weights[k] / total
		if t < start + w or k == #blocks then
			local dur = w * frames
			local pos = (t - start) * frames
			local f = math.min(fade * fps, dur / 2)
			if f <= 0 then
				return b, 1
			end
			return b, clamp(math.min(pos, dur - pos) / f)
		end
		start = start + w
	end
end

-- Dónde va el rollo (top) en t, de 0 a 1, y la opacidad de todo. frames es lo que dura el clip
-- en cuadros (0 si no se sabe) y px, cuántos píxeles mide una unidad de salida en vertical.
local function rollState(layout, aspect, t, frames, fps, px, r)
	local stop, tail = rollStop(layout, aspect, r)
	local tailT = frames > 0 and math.min(tail * fps / frames, 0.9) or 0
	local top = stop * math.min(1, t / (1 - tailT))
	if r.whole and frames > 0 then
		-- Con una velocidad entera de píxeles por cuadro, cada cuadro es el anterior movido sin
		-- remuestrear, y los trazos finos no titilan.
		local speed = math.ceil(stop * px / (frames * (1 - tailT)))
		top = math.min(stop, speed * math.floor(t * frames + 0.5) / px)
	end
	local alpha = 1
	if r.hold and frames > 0 and r.closeFade > 0 then
		alpha = clamp((1 - t) * frames / (r.closeFade * fps))
	end
	return top, alpha
end

-- Las líneas del rollo que tocan el cuadro, con un em de margen por si los glifos salen de su
-- línea. En los bordes se desvanecen a lo largo de edge por ciento del alto.
local function rollLines(layout, top, aspect, alpha, edge)
	local zone = edge / 100 * aspect
	local lines = {}
	for _, run in ipairs(layout.runs) do
		local margin = run.font.em
		if top - run.top + margin > 0 and top - run.bottom - margin < aspect then
			local a = alpha
			if zone > 0 then
				local y = top - (run.top + run.bottom) / 2
				a = a * clamp(math.min(y, aspect - y) / zone)
			end
			lines[#lines + 1] = { run = run, y = top - run.base, alpha = a }
		end
	end
	return lines
end

local function cardLines(block, aspect, alpha)
	local top = (block.top + block.bottom) / 2 + aspect / 2
	local lines = {}
	for _, run in ipairs(block.runs) do
		lines[#lines + 1] = { run = run, y = top - run.base, alpha = alpha }
	end
	return lines
end

local lastAdvice

function Process(req)
	local img = InImage:GetValue(req)
	local out = img:CopyOf()
	local aspect = (out.Height * out.YScale) / (out.Width * out.XScale)

	-- Sin la interfaz abierta (un render en segundo plano) nadie ha escaneado las fuentes.
	if not next(FontManager:GetFontList()) then
		FontManager:ScanDir()
	end

	local p = {
		text = InText:GetValue(req).Value or "",
		rows = InRows:GetValue(req).Value,
		upper = InUpper:GetValue(req).Value,
		fonts = readFonts(req, FONTS, InFonts),
		colors = readColors(req, COLORS, InColors),
	}
	for _, m in ipairs(MEASURES) do
		p[m.key] = InMeasures[m.key]:GetValue(req).Value
	end

	if InSolid:GetValue(req).Value > 0.5 then
		local bg = p.colors.paper
		out:Fill(Pixel({ R = bg[1], G = bg[2], B = bg[3], A = 1 }))
	end

	local layout = getLayout(p, aspect)
	local first, last = clipRange(req, self.Comp)
	local t = progress(req, first, last)
	local cards = InKind:GetValue(req).Value > 0.5
	local fade = InFade:GetValue(req).Value
	local fps = frameRate(self.Comp)
	local px = out.Height / aspect
	local r = {
		edge = InEdge:GetValue(req).Value,
		hold = InHold:GetValue(req).Value > 0.5,
		holdTime = InHoldTime:GetValue(req).Value,
		closeFade = InCloseFade:GetValue(req).Value,
		whole = InWhole:GetValue(req).Value > 0.5,
	}
	local lines = {}
	if cards then
		local block, alpha = card(layout.blocks, t, last - first, fade, fps, InPacing:GetValue(req).Value > 0.5)
		if block then
			lines = cardLines(block, aspect, alpha)
		end
	else
		local top, alpha = rollState(layout, aspect, t, last - first, fps, px, r)
		lines = rollLines(layout, top, aspect, alpha, r.edge)
	end
	draw(out, lines, req:IsQuick() and 1 or 32, p.colors)

	local msg = advice(layout, aspect, { cards = cards, fade = fade, roll = r, fps = fps, px = px })
	if msg ~= lastAdvice then
		lastAdvice = msg
		print(msg)
	end

	OutImage:Set(req, out)
end
