local Workspace = game:GetService("Workspace")

local CameraMetadata = {}

local LOCATION_ATTRIBUTE_NAMES = {
	"Location",
	"CameraLocation",
	"DisplayName",
	"CameraName",
	"Label",
	"Area",
	"Room",
	"Zone",
}

local GENERIC_NAME_LOOKUP = {
	camera = true,
	cameras = true,
	workspace = true,
	model = true,
	folder = true,
	billboardgui = true,
	textlabel = true,
	label = true,
}

local function trim(text)
	return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function prettifyName(text)
	local value = trim(text)
	if value == "" then
		return ""
	end

	value = value:gsub("([%l%d])([%u])", "%1 %2")
	value = value:gsub("([%u]+)([%u][%l])", "%1 %2")
	value = value:gsub("[_%-%./]+", " ")
	value = value:gsub("%s+", " ")

	return trim(value)
end

local function isGenericName(name)
	local normalized = tostring(name or ""):gsub("[%s_%-]", ""):lower()
	return GENERIC_NAME_LOOKUP[normalized] == true
end

local function getLocationAttribute(instance)
	for _, attributeName in ipairs(LOCATION_ATTRIBUTE_NAMES) do
		local rawValue = instance:GetAttribute(attributeName)
		if typeof(rawValue) == "string" then
			local value = prettifyName(rawValue)
			if value ~= "" then
				return value
			end
		end
	end

	return nil
end

local function getBillboardLabel(cameraModel)
	for _, descendant in ipairs(cameraModel:GetDescendants()) do
		if descendant:IsA("TextLabel") and descendant:FindFirstAncestorWhichIsA("BillboardGui") then
			local fromName = prettifyName(descendant.Name)
			if fromName ~= "" and not isGenericName(descendant.Name) then
				return fromName
			end

			local fromText = prettifyName(descendant.Text)
			if fromText ~= "" and not isGenericName(descendant.Text) then
				return fromText
			end
		end
	end

	return nil
end

function CameraMetadata.GetLocationLabel(cameraModel)
	if not cameraModel then
		return "Unknown Location"
	end

	local billboardLabel = getBillboardLabel(cameraModel)
	if billboardLabel then
		return billboardLabel
	end

	local current = cameraModel
	while current and current ~= Workspace do
		local attributeLocation = getLocationAttribute(current)
		if attributeLocation then
			return attributeLocation
		end
		current = current.Parent
	end

	current = cameraModel
	while current and current ~= Workspace do
		local readableName = prettifyName(current.Name)
		if readableName ~= "" and not isGenericName(current.Name) then
			return readableName
		end
		current = current.Parent
	end

	return "Unknown Location"
end

return CameraMetadata
