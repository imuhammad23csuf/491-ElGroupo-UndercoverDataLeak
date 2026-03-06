local SuspicionManager = {}

local currentSuspicion = 0
local MAX_VAL = 100

local BindableEvent = Instance.new("BindableEvent")
SuspicionManager.Changed = BindableEvent.Event

function SuspicionManager.Add(amount)
	currentSuspicion = math.clamp(currentSuspicion + amount, 0, MAX_VAL)
	BindableEvent:Fire(currentSuspicion)
end

-- NEW: Function to lower suspicion (SCRUM-90)
function SuspicionManager.Reduce(amount)
	currentSuspicion = math.clamp(currentSuspicion - amount, 0, MAX_VAL)
	BindableEvent:Fire(currentSuspicion)
end

function SuspicionManager.Get()
	return currentSuspicion
end

return SuspicionManager