-- Común ---------------------------------------------------------------------------------
-- Lo que comparten los Fuses de datitles. dev/build lo pega en cada Fuse donde dice "-- @comun".
-- clipRange lee las globales InFirst e InLast que crea addClipInputs.

-- Controles ---------------------------------------------------------------------------------

-- Fuente y estilo de cada entrada de fonts, en el grupo de controles 10 + i.
local function addFontInputs(fonts)
	local inputs = {}
	for i, f in ipairs(fonts) do
		local font = self:AddInput(f.label, f.id .. "Font", {
			LINKID_DataType = "Text",
			INPID_InputControl = "FontFileControl",
			IC_ControlGroup = 10 + i,
			IC_ControlID = 0,
			INP_Level = 1,
			INP_DoNotifyChanged = true,
		})
		local style = self:AddInput("Estilo", f.id .. "Style", {
			LINKID_DataType = "Text",
			INPID_InputControl = "FontFileControl",
			IC_ControlGroup = 10 + i,
			IC_ControlID = 1,
			INP_Level = 1,
			INP_DoNotifyChanged = true,
		})
		inputs[f.key] = { font = font, style = style }
	end
	return inputs
end

-- Rojo, verde y azul de cada color, en el grupo de controles 20 + i.
local function addColorInputs(colors)
	local inputs = {}
	for i, c in ipairs(colors) do
		local channels = {}
		for j, ch in ipairs({ { "Red", "Rojo" }, { "Green", "Verde" }, { "Blue", "Azul" } }) do
			channels[j] = self:AddInput(j == 1 and c.label or ch[2], c.id .. ch[1], {
				LINKID_DataType = "Number",
				INPID_InputControl = "ColorControl",
				INP_Default = c.rgb[j],
				INP_MinScale = 0,
				INP_MaxScale = 1,
				ICS_Name = c.label,
				IC_ControlGroup = 20 + i,
				IC_ControlID = j - 1,
			})
		end
		inputs[c.key] = channels
	end
	return inputs
end

-- El título de Edit page las ata a comp.RenderStart y comp.RenderEnd para que la animación dure
-- lo que dure el clip. Sin expresión (el Fuse suelto en Fusion) se usa el rango de la comp.
local function addClipInputs()
	InFirst = self:AddInput("Primer cuadro", "FirstFrame", {
		LINKID_DataType = "Number",
		INPID_InputControl = "SliderControl",
		INP_Default = 0,
		IC_Visible = false,
	})
	InLast = self:AddInput("Último cuadro", "LastFrame", {
		LINKID_DataType = "Number",
		INPID_InputControl = "SliderControl",
		INP_Default = 0,
		IC_Visible = false,
	})
end

-- FontFileControl no acepta un valor por omisión; se pone cuando llega vacío.
local function fontDefaults(fonts, inputs, inp, param, time)
	if not inputs or not param or (param.Value ~= nil and param.Value ~= "") then
		return
	end
	for _, f in ipairs(fonts) do
		local pair = inputs[f.key]
		if inp == pair.font then
			inp:SetSource(Text(f.font), time)
		elseif inp == pair.style then
			inp:SetSource(Text(f.style), time)
		end
	end
end

local function readFonts(req, fonts, inputs)
	local out = {}
	for _, f in ipairs(fonts) do
		local font = inputs[f.key].font:GetValue(req).Value
		local style = inputs[f.key].style:GetValue(req).Value
		out[f.key] = {
			(font and font ~= "") and font or f.font,
			(style and style ~= "") and style or f.style,
		}
	end
	return out
end

local function readColors(req, colors, inputs)
	local out = {}
	for _, c in ipairs(colors) do
		local ch = inputs[c.key]
		out[c.key] = { ch[1]:GetValue(req).Value, ch[2]:GetValue(req).Value, ch[3]:GetValue(req).Value }
	end
	return out
end

-- Texto -------------------------------------------------------------------------------------

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- UTF-8 a puntos de código. Un byte suelto que no forma secuencia se toma como Latin-1.
local function cont(b)
	return b and b >= 0x80 and b < 0xC0
end

local function codepoints(s)
	local out, i, n = {}, 1, #s
	while i <= n do
		local c = s:byte(i)
		local cp, len = c, 1
		local c2, c3, c4 = s:byte(i + 1, i + 3)
		if c >= 0xC0 and c < 0xE0 and cont(c2) then
			cp, len = (c - 0xC0) * 64 + (c2 - 0x80), 2
		elseif c >= 0xE0 and c < 0xF0 and cont(c2) and cont(c3) then
			cp, len = (c - 0xE0) * 4096 + (c2 - 0x80) * 64 + (c3 - 0x80), 3
		elseif c >= 0xF0 and c < 0xF8 and cont(c2) and cont(c3) and cont(c4) then
			cp, len = (c - 0xF0) * 262144 + (c2 - 0x80) * 4096 + (c3 - 0x80) * 64 + (c4 - 0x80), 4
		end
		out[#out + 1] = cp
		i = i + len
	end
	return out
end

-- Mayúsculas de ASCII y Latin-1, que cubren el español (string.upper no toca los acentos).
local function upper(cps)
	local out = {}
	for i, cp in ipairs(cps) do
		if (cp >= 97 and cp <= 122) or (cp >= 224 and cp <= 254 and cp ~= 247) then
			cp = cp - 32
		elseif cp == 255 then
			cp = 376
		end
		out[i] = cp
	end
	return out
end

-- Fuentes y medición -------------------------------------------------------------------------

-- Las métricas de TextStyleFontMetrics se llevan a unidades de salida (1 = ancho del cuadro)
-- multiplicando por 10 * size, como en los ejemplos del SDK. Aquí size se elige para que el em
-- (alto de la caja menos el leading interno) mida lo que se pide, igual en todas las fuentes.
local function loadFont(face, em)
	local tfm = TextStyleFontMetrics(TextStyleFont(face[1], face[2]))
	local box = (tfm.TextAscent or 0) + (tfm.TextDescent or 0)
	local inner = tfm.TextInternalLeading or 0
	if inner < 0 or inner > box / 2 then
		inner = 0
	end
	local unit = box - inner > 0 and em / (box - inner) or em
	return {
		tfm = tfm,
		unit = unit,
		em = em,
		asc = (tfm.TextAscent or 0) * unit,
		desc = (tfm.TextDescent or 0) * unit,
		adv = {},
		kern = {},
		glyph = {},
	}
end

local function advance(f, cp)
	local w = f.adv[cp]
	if not w then
		w = f.tfm:CharacterWidth(cp) * f.unit
		f.adv[cp] = w
	end
	return w
end

local function kerning(f, a, b)
	local key = a * 1114112 + b
	local k = f.kern[key]
	if not k then
		k = (f.tfm:CharacterKerning(a, b) or 0) * f.unit
		f.kern[key] = k
	end
	return k
end

local function measure(f, cps, ls)
	local w, prev = 0, nil
	for i = 1, #cps do
		local cp = cps[i]
		if prev then
			w = w + kerning(f, prev, cp) + ls
		end
		w = w + advance(f, cp)
		prev = cp
	end
	return w
end

-- Parte en palabras y arma líneas que quepan en maxW. Una palabra más ancha se queda sola.
local function wrap(f, cps, ls, maxW)
	local words, word = {}, {}
	for i = 1, #cps do
		if cps[i] == 32 then
			if #word > 0 then
				words[#words + 1] = word
				word = {}
			end
		else
			word[#word + 1] = cps[i]
		end
	end
	if #word > 0 then
		words[#words + 1] = word
	end

	local lines, line = {}, {}
	for _, w in ipairs(words) do
		local candidate = {}
		for i = 1, #line do
			candidate[i] = line[i]
		end
		if #line > 0 then
			candidate[#candidate + 1] = 32
		end
		for i = 1, #w do
			candidate[#candidate + 1] = w[i]
		end
		if #line > 0 and measure(f, candidate, ls) > maxW then
			lines[#lines + 1] = line
			line = w
		else
			line = candidate
		end
	end
	if #line > 0 then
		lines[#lines + 1] = line
	end
	return lines
end

-- Dibujo -----------------------------------------------------------------------------------

-- Igual que drawstring del SDK: cada glifo se centra en su avance, sobre la línea base.
local function addGlyphs(shape, run, baseY)
	local f = run.font
	local size = f.unit / 10
	local pen, prev = run.x, nil
	for i = 1, #run.cps do
		local cp = run.cps[i]
		if prev then
			pen = pen + kerning(f, prev, cp) + run.ls
		end
		local cw = advance(f, cp)
		if cp ~= 32 then
			local glyph = f.glyph[cp]
			if glyph == nil then
				glyph = f.tfm:GetCharacterShape(cp, false) or false
				f.glyph[cp] = glyph
			end
			if glyph then
				local m = Matrix4()
				m:Identity()
				m:Scale(1.0 / f.tfm.Scale, 1.0 / f.tfm.Scale, 1.0)
				m:Scale(size, size, 1)
				m:Move(pen + cw / 2, baseY, 0)
				shape:AddShape(glyph:TransformOfShape(m))
			end
		end
		pen = pen + cw
		prev = cp
	end
end

-- Cada línea llega con su altura en el cuadro (y) y su opacidad. Se arma una forma por color y
-- nivel de opacidad, y cada forma es un PutToImage.
local function draw(out, lines, quality, colors)
	local groups, order = {}, {}
	for _, ln in ipairs(lines) do
		local level = math.floor(ln.alpha * 64 + 0.5)
		if level > 0 then
			local key = ln.run.color .. level
			local g = groups[key]
			if not g then
				g = { shape = Shape(), color = ln.run.color, alpha = level / 64 }
				groups[key] = g
				order[#order + 1] = g
			end
			addGlyphs(g.shape, ln.run, ln.y)
		end
	end
	for _, g in ipairs(order) do
		local rgb, a = colors[g.color], g.alpha
		local ic = ImageChannel(out, quality)
		local fs = FillStyle()
		local cs = ChannelStyle()
		-- Fusion trabaja con color premultiplicado.
		cs.Color = Pixel({ R = rgb[1] * a, G = rgb[2] * a, B = rgb[3] * a, A = a })
		ic:SetStyleFill(fs)
		ic:ShapeFill(g.shape)
		ic:PutToImage("CM_Merge", cs)
	end
end

local function clamp(x)
	return math.max(0, math.min(1, x))
end

-- Primer y último cuadro del clip.
local function clipRange(req, comp)
	local first = InFirst:GetValue(req).Value
	local last = InLast:GetValue(req).Value
	if last <= first then
		local ok, attrs = pcall(function()
			return comp:GetAttrs()
		end)
		if ok and type(attrs) == "table" then
			first = attrs.COMPN_RenderStart or 0
			last = attrs.COMPN_RenderEnd or 0
		end
	end
	return first, last
end

local function frameRate(comp)
	local ok, fps = pcall(function()
		return comp:GetPrefs("Comp.FrameFormat.Rate")
	end)
	if ok and type(fps) == "number" and fps > 0 then
		return fps
	end
	return 24
end
