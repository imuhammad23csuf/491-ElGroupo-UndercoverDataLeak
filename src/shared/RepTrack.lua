-- RepTrack module (shared)
-- Tracks reputation values RGood and Rbad (server authoritative)

local RepTrack = {}

local data = {
	RGood = 0,
	Rbad = 0,
}

local function normalizeNumber(value)
	local n = tonumber(value)
	if not n or n ~= n then
		return 0
	end
	return n
end

function RepTrack.GetRGood()
	return data.RGood
end

function RepTrack.GetRbad()
	return data.Rbad
end

function RepTrack.SetRGood(value)
	data.RGood = normalizeNumber(value)
	return data.RGood
end

function RepTrack.SetRbad(value)
	data.Rbad = normalizeNumber(value)
	return data.Rbad
end

function RepTrack.AddRGood(value)
	data.RGood = data.RGood + normalizeNumber(value)
	return data.RGood
end

function RepTrack.AddRbad(value)
	data.Rbad = data.Rbad + normalizeNumber(value)
	return data.Rbad
end

function RepTrack.GetAll()
	return {
		RGood = data.RGood,
		Rbad = data.Rbad,
	}
end

function RepTrack.Reset()
	data.RGood = 0
	data.Rbad = 0
	return RepTrack.GetAll()
end

return RepTrack
