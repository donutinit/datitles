-- Lo justo de la API de Fuses para correr datitles.fuse fuera de Resolve (con LuaJIT, como Fusion).
-- Las fuentes vienen de metrics.py en em. Para que size funcione como en los ejemplos del SDK,
-- las métricas se dan divididas entre 10 y el em de los glifos mide tfm.Scale.

local mock = { renderEnd = 0, output = nil }

CT_Tool = 1
mock.registered = nil
function FuRegisterClass(id, kind, attrs)
	mock.registered = { id = id, kind = kind, attrs = attrs }
end

function Text(v)
	return { Value = v }
end

function Pixel(t)
	return { R = t.R or 0, G = t.G or 0, B = t.B or 0, A = t.A or 0 }
end

-- Entradas --------------------------------------------------------------------------------

local Input = {}
Input.__index = Input

function Input:GetValue(req)
	if type(self.value) == "table" then
		return self.value
	end
	return { Value = self.value }
end

function Input:SetSource(v, time)
	self.value = v.Value
end

function Input:SetAttrs(attrs) end

self = { inputs = {}, order = {}, nests = {}, Comp = {} }

function self.Comp:GetAttrs()
	return { COMPN_RenderStart = 0, COMPN_RenderEnd = mock.renderEnd }
end

function self.Comp:GetPrefs(key)
	assert(key == "Comp.FrameFormat.Rate", "preferencia desconocida para el simulador: " .. key)
	return 24
end

function self:AddInput(name, id, attrs)
	assert(not self.inputs[id], "ID repetido: " .. id)
	local value = attrs.INP_Default
	if attrs.LINKID_DataType == "Text" then
		value = attrs.INPS_DefaultText or ""
	end
	local inp = setmetatable({ name = name, id = id, attrs = attrs, value = value }, Input)
	self.inputs[id] = inp
	self.order[#self.order + 1] = id
	if self.openNest then
		self.openNest.count = self.openNest.count + 1
	end
	return inp
end

function self:AddOutput(name, id, attrs)
	return {
		Set = function(_, req, img)
			mock.output = img
		end,
	}
end

function self:BeginControlNest(name, id, expanded)
	assert(not self.openNest, "nest dentro de nest")
	self:AddInput(name, id, { INPID_InputControl = "LabelControl" })
	self.openNest = { id = id, count = 0 }
	self.nests[id] = self.openNest
end

function self:EndControlNest()
	self.openNest = nil
end

-- Fuentes ---------------------------------------------------------------------------------

FontManager = {}
function FontManager:GetFontList()
	return { mock = true }
end
function FontManager:ScanDir() end

function TextStyleFont(name, style)
	return { face = name .. "/" .. style }
end

local Metrics = {}
Metrics.__index = Metrics

function TextStyleFontMetrics(font)
	local m = mock.metrics[font.face]
	assert(m, "fuente sin métricas en el simulador: " .. font.face)
	return setmetatable({
		face = font.face,
		m = m,
		Scale = 1000,
		TextAscent = m.asc / 10,
		TextDescent = m.desc / 10,
		TextInternalLeading = (m.asc + m.desc - 1) / 10,
		TextExternalLeading = 0,
	}, Metrics)
end

function Metrics:CharacterWidth(cp)
	assert(type(cp) == "number", "CharacterWidth espera un punto de código")
	local w = self.m.adv[cp]
	assert(w, ("carácter %d sin avance en %s"):format(cp, self.face))
	return w / 10
end

function Metrics:CharacterKerning(a, b)
	return (self.m.kern[a .. "," .. b] or 0) / 10
end

-- Formas y matrices: solo se registran glifos con su escala y posición.

local Shape_ = {}
Shape_.__index = Shape_

function Shape()
	return setmetatable({ glyphs = {} }, Shape_)
end

-- Un glifo crudo tiene el origen en el centro de su avance, sobre la línea base, y su em mide
-- tfm.Scale unidades.
function Metrics:GetCharacterShape(cp, flag)
	local sh = Shape()
	sh.glyphs[1] = { cp = cp, face = self.face, em = self.Scale, x = 0, y = 0 }
	return sh
end

function Shape_:AddShape(other)
	for _, g in ipairs(other.glyphs) do
		self.glyphs[#self.glyphs + 1] = g
	end
end

function Shape_:TransformOfShape(m)
	assert(math.abs(m.a - m.d) < 1e-12, "escala no uniforme")
	local out = Shape()
	for _, g in ipairs(self.glyphs) do
		out.glyphs[#out.glyphs + 1] = {
			cp = g.cp,
			face = g.face,
			em = g.em * m.a,
			x = m.a * g.x + m.tx,
			y = m.d * g.y + m.ty,
		}
	end
	return out
end

local Matrix = {}
Matrix.__index = Matrix

function Matrix4()
	return setmetatable({ a = 1, d = 1, tx = 0, ty = 0 }, Matrix)
end

function Matrix:Identity()
	self.a, self.d, self.tx, self.ty = 1, 1, 0, 0
end

function Matrix:Scale(sx, sy, sz)
	self.a, self.d = self.a * sx, self.d * sy
	self.tx, self.ty = self.tx * sx, self.ty * sy
end

function Matrix:Move(dx, dy, dz)
	self.tx, self.ty = self.tx + dx, self.ty + dy
end

-- Imágenes --------------------------------------------------------------------------------

local Image_ = {}
Image_.__index = Image_

function mock.image(w, h)
	return setmetatable({ Width = w, Height = h, XScale = 1, YScale = 1, fill = nil, draws = {} }, Image_)
end

function Image_:CopyOf()
	local img = mock.image(self.Width, self.Height)
	img.fill = self.fill
	return img
end

function Image_:Fill(p)
	self.fill = p
	self.draws = {}
end

function FillStyle()
	return {}
end

function ChannelStyle()
	return {}
end

function ImageChannel(img, quality)
	assert(type(quality) == "number")
	return {
		SetStyleFill = function(ic, fs)
			ic.fs = fs
		end,
		ShapeFill = function(ic, sh)
			ic.shape = sh
		end,
		PutToImage = function(ic, mode, cs)
			assert(ic.fs and ic.shape, "ShapeFill antes de PutToImage")
			assert(mode == "CM_Merge")
			img.draws[#img.draws + 1] = { color = cs.Color, glyphs = ic.shape.glyphs }
		end,
	}
end

function mock.request(time)
	return {
		Time = time,
		IsQuick = function()
			return false
		end,
	}
end

return mock
