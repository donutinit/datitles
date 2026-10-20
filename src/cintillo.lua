--[[--
datitles cintillo: nombre y cargo en el tercio inferior, de la familia de datitles.

El nombre va en display y el cargo en mono, como los títulos y los departamentos de los créditos.
Entra al principio del clip y sale al final, con fade o subiendo.

Copyright (C) 2026 Von Diego · AGPL-3.0-only · https://github.com/donutinit/datitles
--]]--

FuRegisterClass("datitles_cintillo", CT_Tool, {
	REGS_Name = "datitles cintillo",
	REGS_Category = "Fuses\\datitles",
	REGS_OpIconString = "dCi",
	REGS_OpDescription = "Cintillo con nombre y cargo",
	REGS_URL = "https://github.com/donutinit/datitles",
	REG_OpNoMask = true,
	REG_NoObjMatCtrls = true,
	REG_NoMotionBlurCtrls = true,
	REG_TimeVariant = true, -- la entrada y la salida cambian en cada cuadro aunque nada esté animado
	REG_Version = 1,
})

local FONTS = {
	{ key = "name", id = "Name", label = "Nombre", font = "League Gothic", style = "Regular" },
	{ key = "role", id = "Role", label = "Cargo", font = "IBM Plex Mono", style = "Regular" },
}

-- Los mismos tonos que los créditos: nombres claros y roles apagados.
local COLORS = {
	{ key = "ink", id = "Ink", label = "Nombre", rgb = { 0.9266, 0.9051, 0.8817 } },
	{ key = "muted", id = "Muted", label = "Cargo", rgb = { 0.6072, 0.5781, 0.5655 } },
}

local MEASURES = {
	{ key = "nameSize", id = "NameSize", label = "Nombre (% del alto)", default = 6, min = 1, max = 15 },
	{ key = "roleScale", id = "RoleScale", label = "Cargo (× nombre)", default = 0.4, min = 0.1, max = 1 },
	{ key = "gap", id = "Gap", label = "Entre líneas (× cargo)", default = 0.25, min = 0, max = 3 },
}

local PLACEMENT = {
	{ key = "margin", id = "Margin", label = "Margen lateral (% del ancho)", default = 8, min = 0, max = 40 },
	{ key = "height", id = "Height", label = "Altura (% del alto)", default = 12, min = 0, max = 90 },
}

-- @comun

InSliders = {}

local function addSliders(list)
	for _, m in ipairs(list) do
		InSliders[m.key] = self:AddInput(m.label, m.id, {
			LINKID_DataType = "Number",
			INPID_InputControl = "SliderControl",
			INP_Default = m.default,
			INP_MinScale = m.min,
			INP_MaxScale = m.max,
			INP_MinAllowed = 0,
		})
	end
end

function Create()
	InName = self:AddInput("Nombre", "Name", {
		LINKID_DataType = "Text",
		INPID_InputControl = "TextEditControl",
		TEC_Lines = 1,
		INPS_DefaultText = "Nombre Apellido",
	})
	InRole = self:AddInput("Cargo", "Role", {
		LINKID_DataType = "Text",
		INPID_InputControl = "TextEditControl",
		TEC_Lines = 1,
		INPS_DefaultText = "Cargo",
	})

	self:BeginControlNest("Animación", "AnimationNest", true)
	InMotion = self:AddInput("Entrada", "Motion", {
		LINKID_DataType = "Number",
		INPID_InputControl = "MultiButtonControl",
		INP_Default = 1,
		INP_Integer = true,
		{ MBTNC_AddButton = "Fade", MBTNCD_ButtonWidth = 0.5 },
		{ MBTNC_AddButton = "Sube", MBTNCD_ButtonWidth = 0.5 },
	})
	InIn = self:AddInput("Entrada (s)", "InTime", {
		LINKID_DataType = "Number",
		INPID_InputControl = "SliderControl",
		INP_Default = 0.6,
		INP_MinScale = 0,
		INP_MaxScale = 3,
		INP_MinAllowed = 0,
	})
	InOut = self:AddInput("Salida (s)", "OutTime", {
		LINKID_DataType = "Number",
		INPID_InputControl = "SliderControl",
		INP_Default = 0.6,
		INP_MinScale = 0,
		INP_MaxScale = 3,
		INP_MinAllowed = 0,
	})
	self:EndControlNest()

	self:BeginControlNest("Posición", "PositionNest", true)
	InAlign = self:AddInput("Alineación", "Align", {
		LINKID_DataType = "Number",
		INPID_InputControl = "MultiButtonControl",
		INP_Default = 0,
		INP_Integer = true,
		{ MBTNC_AddButton = "Izquierda", MBTNCD_ButtonWidth = 1 / 3 },
		{ MBTNC_AddButton = "Centro", MBTNCD_ButtonWidth = 1 / 3 },
		{ MBTNC_AddButton = "Derecha", MBTNCD_ButtonWidth = 1 / 3 },
	})
	addSliders(PLACEMENT)
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
	addSliders(MEASURES)
	self:EndControlNest()

	self:BeginControlNest("Colores", "ColorNest", false)
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

-- Cintillo ------------------------------------------------------------------------------------

-- Las fuentes se cargan una vez por tamaño; el texto cambia poco y se mide en cada cuadro.
local fontCache = {}

local function getFont(face, em)
	local key = face[1] .. "\0" .. face[2] .. "\0" .. em
	if not fontCache[key] then
		fontCache[key] = loadFont(face, em)
	end
	return fontCache[key]
end

-- x de una línea de ancho w según la alineación (0 izquierda, 1 centro, 2 derecha).
local function alignX(align, w, margin)
	if align > 1.5 then
		return 1 - margin - w
	elseif align > 0.5 then
		return 0.5 - w / 2
	end
	return margin
end

local function easeOut(x)
	return 1 - (1 - x) ^ 3
end

function Process(req)
	local img = InImage:GetValue(req)
	local out = img:CopyOf()
	local aspect = (out.Height * out.YScale) / (out.Width * out.XScale)

	-- Sin la interfaz abierta (un render en segundo plano) nadie ha escaneado las fuentes.
	if not next(FontManager:GetFontList()) then
		FontManager:ScanDir()
	end

	local m = {}
	for key, inp in pairs(InSliders) do
		m[key] = inp:GetValue(req).Value
	end
	local fonts = readFonts(req, FONTS, InFonts)
	local colors = readColors(req, COLORS, InColors)

	-- Opacidad: sube al principio del clip y baja al final.
	local first, last = clipRange(req, self.Comp)
	local fps = frameRate(self.Comp)
	local pos, frames = req.Time - first, last - first
	local inF, outF = InIn:GetValue(req).Value * fps, InOut:GetValue(req).Value * fps
	local aIn = inF > 0 and clamp(pos / inF) or 1
	local aOut = outF > 0 and clamp((frames - pos) / outF) or 1
	if frames <= 0 then
		aIn, aOut = 1, 1
	end

	local em = m.nameSize / 100 * aspect
	local nf = getFont(fonts.name, em)
	local rf = getFont(fonts.role, em * m.roleScale)
	local nls, rls = 0.01 * nf.em, 0.08 * rf.em
	local name = codepoints(trim(InName:GetValue(req).Value or ""))
	local role = codepoints(trim(InRole:GetValue(req).Value or ""))
	if InUpper:GetValue(req).Value > 0.5 then
		name, role = upper(name), upper(role)
	end
	local align, margin = InAlign:GetValue(req).Value, m.margin / 100

	-- De abajo hacia arriba: el cargo se apoya en la altura pedida y el nombre va encima.
	local rise = 0
	if InMotion:GetValue(req).Value > 0.5 then
		rise = (1 - easeOut(aIn)) * 0.6 * nf.em
	end
	local roleBase = m.height / 100 * aspect + rf.desc - rise
	local nameBase = roleBase
	if #role > 0 then
		nameBase = roleBase + rf.asc + m.gap * rf.em + nf.desc
	end

	local lines = {}
	local alpha = math.min(aIn, aOut)
	if #name > 0 then
		local run = { font = nf, cps = name, x = alignX(align, measure(nf, name, nls), margin), ls = nls, color = "ink" }
		lines[#lines + 1] = { run = run, y = nameBase, alpha = alpha }
	end
	if #role > 0 then
		local run = { font = rf, cps = role, x = alignX(align, measure(rf, role, rls), margin), ls = rls, color = "muted" }
		lines[#lines + 1] = { run = run, y = roleBase, alpha = alpha }
	end
	draw(out, lines, req:IsQuick() and 1 or 32, colors)

	OutImage:Set(req, out)
end
