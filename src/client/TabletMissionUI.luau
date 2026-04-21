local TabletMissionUI = {}

local TextService = game:GetService("TextService")

local function clearRenderedFrames(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function addStrikeThrough(mk, target, color)
    mk("Frame", {
        Parent = target,
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0.5, -1),
    })
end

local function measureWrappedHeight(text, font, textSize, width, minHeight)
    local safeWidth = math.max(40, math.floor(width or 40))
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(tostring(text or ""), textSize, font, Vector2.new(safeWidth, 4096))
    end)
    local height = ok and bounds.Y or textSize
    return math.max(minHeight or 0, height)
end

local function getUsableWidth(guiObject, fallback)
    local width = 0
    if guiObject then
        width = guiObject.AbsoluteSize.X
    end
    if width <= 0 then
        width = fallback or 340
    end
    return width
end

local function refreshAncestorScroller(guiObject)
    local function applyLayoutSize(target)
        if not target then
            return
        end
        local layout = target:FindFirstChild("UIListLayout")
        if not layout or not layout:IsA("UIListLayout") then
            return
        end
        local paddingTop = 0
        local paddingBottom = 0
        local padding = target:FindFirstChildOfClass("UIPadding")
        if padding then
            paddingTop = padding.PaddingTop.Offset
            paddingBottom = padding.PaddingBottom.Offset
        end
        local height = layout.AbsoluteContentSize.Y + paddingTop + paddingBottom
        if target:IsA("ScrollingFrame") then
            target.CanvasSize = UDim2.new(0, 0, 0, height)
        else
            target.Size = UDim2.new(target.Size.X.Scale, target.Size.X.Offset, 0, height)
        end
    end

    local function update()
        applyLayoutSize(guiObject)
        local node = guiObject
        while node do
            if node:IsA("ScrollingFrame") then
                applyLayoutSize(node)
                break
            end
            node = node.Parent
        end
    end

    task.defer(function()
        update()
        task.defer(update)
        task.delay(0.03, update)
    end)
end

local function createStatusPill(mk, parent, text, color, props)
    local data = {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(13, 16, 24),
        BorderSizePixel = 0,
        Text = string.upper(tostring(text or "")),
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        TextColor3 = color,
        AutomaticSize = Enum.AutomaticSize.XY,
    }
    for key, value in pairs(props or {}) do
        data[key] = value
    end
    local pill = mk("TextLabel", data)
    mk("UIPadding", {
        Parent = pill,
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
    })
    return pill
end

function TabletMissionUI.renderMissionCards(missionsList, objectivesList, mk, round)
    if not missionsList then
        return
    end

    objectivesList = type(objectivesList) == "table" and objectivesList or {}
    clearRenderedFrames(missionsList)

    local listWidth = getUsableWidth(missionsList, 360)
    local cardWidthOffset = 4
    local cardInnerWidth = math.max(120, listWidth - cardWidthOffset - 20)

    for _, taskInfo in ipairs(objectivesList) do
        local isCompleted = taskInfo.status == "Completed"
        local titleColor = isCompleted and Color3.fromRGB(160, 160, 160) or Color3.new(1, 1, 1)
        local statusColor = Color3.fromRGB(150, 150, 150)
        if taskInfo.status == "Completed" then
            statusColor = Color3.fromRGB(0, 255, 100)
        elseif taskInfo.status == "In Progress" then
            statusColor = Color3.fromRGB(255, 200, 0)
        elseif taskInfo.status == "Locked" then
            statusColor = Color3.fromRGB(140, 140, 140)
        end

        local labelHeight = measureWrappedHeight(taskInfo.text, Enum.Font.GothamSemibold, 10, cardInnerWidth, 14)
        local statusY = 8 + labelHeight + 8
        local cardHeight = math.max(54, statusY + 24)

        local taskRow = mk("Frame", {
            Parent = missionsList,
            BackgroundColor3 = Color3.fromRGB(20, 26, 38),
            BorderSizePixel = 0,
            Size = UDim2.new(1, -cardWidthOffset, 0, cardHeight),
            ClipsDescendants = true,
        })
        round(taskRow, 8)

        local label = mk("TextLabel", {
            Parent = taskRow,
            BackgroundTransparency = 1,
            Text = tostring(taskInfo.text or ""),
            Font = Enum.Font.GothamSemibold,
            TextSize = 10,
            TextColor3 = titleColor,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            Position = UDim2.new(0, 10, 0, 8),
            Size = UDim2.new(1, -20, 0, labelHeight),
        })
        if isCompleted then
            addStrikeThrough(mk, label, Color3.fromRGB(160, 160, 160))
        end

        local pill = createStatusPill(mk, taskRow, tostring(taskInfo.status or ""), statusColor, {
            Position = UDim2.new(0, 10, 0, statusY),
        })
        round(pill, 999)
    end

    refreshAncestorScroller(missionsList)
end

function TabletMissionUI.getObjectiveStatusText(status)
    if status == "Locked" then
        return "Locked"
    elseif status == "Completed" then
        return "Completed"
    elseif status == "In Progress" then
        return "In Progress"
    end
    return "Unlocked"
end

function TabletMissionUI.getObjectiveStatusColor(status)
    if status == "Locked" then
        return Color3.fromRGB(140, 140, 140)
    elseif status == "Completed" then
        return Color3.fromRGB(0, 255, 100)
    elseif status == "In Progress" then
        return Color3.fromRGB(255, 200, 0)
    end
    return Color3.new(1, 1, 1)
end

function TabletMissionUI.normalizeChapterObjectives(rawObjectives)
    if type(rawObjectives) ~= "table" or #rawObjectives == 0 then
        return {}
    end

    local normalized = {}
    for _, chapter in ipairs(rawObjectives) do
        if type(chapter) == "table" and chapter.title then
            table.insert(normalized, chapter)
        end
    end
    return normalized
end

function TabletMissionUI.renderObjectiveCards(objectivesListGui, objectivesList, chapterExpanded, mk, round, onStartChapter, onToggleChapter)
    if not objectivesListGui then
        return
    end

    objectivesList = TabletMissionUI.normalizeChapterObjectives(objectivesList)
    clearRenderedFrames(objectivesListGui)

    local listWidth = getUsableWidth(objectivesListGui, 360)
    local cardWidthOffset = 4
    local cardInnerWidth = math.max(140, listWidth - cardWidthOffset - 20)

    for _, chapter in ipairs(objectivesList) do
        local chapterCompleted = chapter.status == "Completed"
        local canStart = chapter.status == "Not Started" and chapter.unlocked
        local expanded = chapterExpanded[chapter.id] == true
        local titleColor = chapterCompleted and Color3.fromRGB(160, 160, 160) or Color3.new(1, 1, 1)
        local titleHeight = measureWrappedHeight(chapter.title, Enum.Font.GothamSemibold, 10, cardInnerWidth - 18, 14)
        local metaY = 10 + titleHeight + 8
        local headerHeight = metaY + 22
        local totalHeight = headerHeight + 20

        local stepHeights = {}
        if expanded and type(chapter.steps) == "table" and #chapter.steps > 0 then
            for _, step in ipairs(chapter.steps) do
                local stepTextHeight = measureWrappedHeight(step.text, Enum.Font.Gotham, 9, cardInnerWidth - 16, 13)
                local stepStatusY = 8 + stepTextHeight + 6
                local stepHeight = math.max(48, stepStatusY + 22)
                table.insert(stepHeights, stepHeight)
                totalHeight = totalHeight + stepHeight + 6
            end
            totalHeight = totalHeight + 2
        end

        local card = mk("Frame", {
            Parent = objectivesListGui,
            BackgroundColor3 = Color3.fromRGB(20, 26, 38),
            BorderSizePixel = 0,
            Size = UDim2.new(1, -cardWidthOffset, 0, totalHeight),
            ClipsDescendants = true,
        })
        round(card, 10)

        local header = mk("TextButton", {
            Parent = card,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            Position = UDim2.new(0, 10, 0, 10),
            Size = UDim2.new(1, -20, 0, headerHeight),
        })

        mk("TextLabel", {
            Parent = header,
            BackgroundTransparency = 1,
            Text = expanded and "v" or ">",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(180, 180, 180),
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.fromOffset(14, 14),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        })

        local titleLabel = mk("TextLabel", {
            Parent = header,
            BackgroundTransparency = 1,
            Text = tostring(chapter.title or ""),
            Font = Enum.Font.GothamSemibold,
            TextSize = 10,
            TextColor3 = titleColor,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            Position = UDim2.new(0, 18, 0, 0),
            Size = UDim2.new(1, -18, 0, titleHeight),
        })
        if chapterCompleted then
            addStrikeThrough(mk, titleLabel, Color3.fromRGB(160, 160, 160))
        end

        local statusPill = createStatusPill(mk, header, TabletMissionUI.getObjectiveStatusText(chapter.status), TabletMissionUI.getObjectiveStatusColor(chapter.status), {
            Position = UDim2.new(0, 0, 0, metaY),
        })
        round(statusPill, 999)

        if canStart then
            local startBtn = mk("TextButton", {
                Parent = header,
                Text = "START",
                Font = Enum.Font.GothamBold,
                TextSize = 8,
                TextColor3 = Color3.new(1, 1, 1),
                BackgroundColor3 = Color3.fromRGB(79, 131, 255),
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(56, 20),
                Position = UDim2.new(1, -56, 0, metaY - 1),
            })
            round(startBtn, 999)
            startBtn.MouseButton1Click:Connect(function()
                if onStartChapter then
                    onStartChapter(chapter)
                end
            end)
        end

        header.MouseButton1Click:Connect(function()
            if onToggleChapter then
                onToggleChapter(chapter)
            end
        end)

        if expanded and type(chapter.steps) == "table" and #chapter.steps > 0 then
            local y = headerHeight + 18
            for index, step in ipairs(chapter.steps) do
                local stepHeight = stepHeights[index]
                local stepCompleted = step.status == "Completed"
                local stepTextColor = stepCompleted and Color3.fromRGB(160, 160, 160) or Color3.new(1, 1, 1)
                local stepTextHeight = measureWrappedHeight(step.text, Enum.Font.Gotham, 9, cardInnerWidth - 16, 13)
                local stepStatusY = 8 + stepTextHeight + 6

                local stepCard = mk("Frame", {
                    Parent = card,
                    BackgroundColor3 = Color3.fromRGB(13, 16, 24),
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 10, 0, y),
                    Size = UDim2.new(1, -20, 0, stepHeight),
                    ClipsDescendants = true,
                })
                round(stepCard, 8)

                local stepLabel = mk("TextLabel", {
                    Parent = stepCard,
                    BackgroundTransparency = 1,
                    Text = tostring(step.text or ""),
                    Font = Enum.Font.Gotham,
                    TextSize = 9,
                    TextColor3 = stepTextColor,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    TextWrapped = true,
                    TextTruncate = Enum.TextTruncate.None,
                    Position = UDim2.new(0, 8, 0, 8),
                    Size = UDim2.new(1, -16, 0, stepTextHeight),
                })
                if stepCompleted then
                    addStrikeThrough(mk, stepLabel, Color3.fromRGB(160, 160, 160))
                end

                local pill = createStatusPill(mk, stepCard, TabletMissionUI.getObjectiveStatusText(step.status), TabletMissionUI.getObjectiveStatusColor(step.status), {
                    Position = UDim2.new(0, 8, 0, stepStatusY),
                })
                round(pill, 999)

                y = y + stepHeight + 6
            end
        end
    end

    refreshAncestorScroller(objectivesListGui)
end

return TabletMissionUI
