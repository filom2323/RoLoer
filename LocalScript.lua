-- ProfileGui.lua — экран профиля с планами и настройками

-- Сервисы
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Remotes (опционально могут отсутствовать на раннем этапе загрузки)
local GetUserInfo = ReplicatedStorage:FindFirstChild("GetUserInfo")
local UpdateUserPlan = ReplicatedStorage:FindFirstChild("UpdateUserPlan")
local ResetAuthData = ReplicatedStorage:FindFirstChild("ResetAuthData")

local ConfirmationDialogModule = require(game:GetService("StarterGui"):WaitForChild("ConfirmationDialogModule")) -- Updated path

-- Палитра (в тон остальному UI)
local colors = {
	background = Color3.fromRGB(18, 19, 21),
	surface = Color3.fromRGB(25, 26, 28), -- Darker surface for general blocks
	softer = Color3.fromRGB(26, 28, 31), -- For frames within settings tab content
	stroke = Color3.fromRGB(70, 74, 80),
	soft_stroke = Color3.fromRGB(58, 60, 64),
	text = Color3.fromRGB(235, 238, 240),
	muted = Color3.fromRGB(160, 164, 170),
	accent = Color3.fromRGB(0, 100, 220),
	accent_soft = Color3.fromRGB(56, 98, 220),
	buttonText = Color3.fromRGB(255, 255, 255),
	free_plan_color = Color3.fromRGB(34, 197, 94),
	pro_plan_color = Color3.fromRGB(147, 51, 234),
	plan_background_color = Color3.fromRGB(44, 47, 51),
	sidebar = Color3.fromRGB(25, 26, 28),
	sidebar_button_darker = Color3.fromRGB(44, 47, 51),
	input = Color3.fromRGB(25, 26, 28),
	warning = Color3.fromRGB(255, 179, 60),
	danger = Color3.fromRGB(255, 99, 71),
	cyan = Color3.fromRGB(0, 180, 216),
	interactive_color = Color3.fromRGB(29, 31, 33), -- New color for interactive elements and click state
	button_default = Color3.fromRGB(33, 35, 38), -- New color for default button background
	tab_selected_background = Color3.fromRGB(44, 47, 51), -- New color for selected tab background
}

local function Create(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do inst[k] = v end
	return inst
end

local function createSettingRow(parent, title, rightButtonText, rightColor)
	local row = Create("Frame", { Parent = parent, Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = colors.softer, BorderSizePixel = 0 })
	Create("UICorner", { Parent = row, CornerRadius = UDim.new(0, 20) })
	Create("UIStroke", { Parent = row, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3 })
	Create("UIPadding", { Parent = row, PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) })
	local name = Create("TextLabel", { Parent = row, Size = UDim2.new(1, -140, 1, 0), BackgroundTransparency = 1, Text = title, Font = Enum.Font.SourceSansSemibold, TextSize = 18, TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left })
	local action = Create("TextButton", { Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 130, 0, 38), Text = rightButtonText or "Open", Font = Enum.Font.SourceSansSemibold, TextSize = 16, TextColor3 = colors.text, BackgroundColor3 = rightColor or colors.button_default, AutoButtonColor = false }) -- Changed default to colors.button_default
	Create("UICorner", { Parent = action, CornerRadius = UDim.new(0, 18) })
	Create("UIStroke", { Parent = action, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3 })
	return row, action
end

-- Создаём/получаем ScreenGui
local screenGui = script.Parent
if not screenGui or not screenGui:IsA("ScreenGui") then
	screenGui = Instance.new("ScreenGui")
end
screenGui.Name = "ProfileGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false -- показываем сразу после запуска
screenGui.Parent = playerGui
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100

ConfirmationDialogModule.init() -- Initialize the module

-- Полупрозрачный фон
local overlay = Create("Frame", {
	Name = "Overlay",
	Parent = screenGui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = colors.surface, -- Changed to colors.surface
	BackgroundTransparency = 0 -- Reverted to no transparency
})

-- Right bar for tabs
local tabBar = Create("Frame", {
	Name = "TabBar",
	Parent = screenGui,
	AnchorPoint = Vector2.new(0, 0.5), -- Added to vertically center the bar
	Position = UDim2.new(0, 16, 0.5, 0), -- Changed from UDim2.fromScale(0.01, 0.5)
	Size = UDim2.new(0, 200, 0.98, 0), -- Increased width from 166 to 200
	BackgroundColor3 = colors.surface, -- Already colors.surface
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
})
Create("UICorner", { Parent = tabBar, CornerRadius = UDim.new(0, 24) })
Create("UIStroke", { Parent = tabBar, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3, Transparency = 0 }) -- Added UIStroke
Create("UIPadding", { Parent = tabBar, PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) })
Create("UIListLayout", { Parent = tabBar, FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })

-- Tab content container (initially hidden)
local tabContentContainer = Create("ScrollingFrame", {
	Name = "TabContentContainer",
	Parent = screenGui,
	Size = UDim2.new(1, -248, 0.98, 0), -- Adjusted size based on new tabBar width (16 + 200 + 16 = 232, so -232) Changed from UDim2.fromScale(0.78, 0.98) to UDim2.new(1, -248)
	Position = UDim2.new(0, 16 + 200 + 16, 0.5, 0), -- Adjusted position: 16 (left padding) + 200 (tabBar width) + 16 (gap)
	AnchorPoint = Vector2.new(0, 0.5),
	BackgroundColor3 = colors.surface, -- Already colors.surface
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	ScrollBarThickness = 0, -- Make scrollbar invisible
	ScrollBarImageTransparency = 1, -- Make scrollbar image transparent
	CanvasSize = UDim2.new(0,0,0,0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Visible = true, -- Changed to visible by default for now
})
-- Create("UICorner", { Parent = tabContentContainer, CornerRadius = UDim.new(0, 24) })
-- Create("UIStroke", { Parent = tabContentContainer, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3, Transparency = 0 })
Create("UIPadding", { Parent = tabContentContainer, PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 24), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) })
Create("UIListLayout", { Parent = tabContentContainer, FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 16) })

-- Tab Buttons
local profileTabButton = Create("TextButton", {
	Name = "ProfileTabButton",
	Parent = tabBar,
	Size = UDim2.new(1, 0, 0, 48), -- Increased height from 40 to 48
	Text = "Профиль",
	BackgroundColor3 = colors.interactive_color, -- Changed to interactive_color
	TextColor3 = colors.buttonText, -- Changed from Color3.new(1,1,1)
	Font = Enum.Font.SourceSansBold,
	TextSize = 16,
	AutoButtonColor = false,
})
Create("UICorner", { Parent = profileTabButton, CornerRadius = UDim.new(0, 24) }) -- Adjusted CornerRadius
Create("UIStroke", { Parent = profileTabButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3 }) -- Added UIStroke

local settingsTabButton = Create("TextButton", {
	Name = "SettingsTabButton",
	Parent = tabBar,
	Size = UDim2.new(1, 0, 0, 48), -- Increased height from 40 to 48
	Text = "Настройки",
	BackgroundColor3 = colors.button_default, -- Changed to button_default
	TextColor3 = colors.text,
	Font = Enum.Font.SourceSansBold,
	TextSize = 16,
	AutoButtonColor = false,
})
Create("UICorner", { Parent = settingsTabButton, CornerRadius = UDim.new(0, 24) }) -- Adjusted CornerRadius
Create("UIStroke", { Parent = settingsTabButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3 }) -- Added UIStroke

local historyTabButton = Create("TextButton", {
	Name = "HistoryTabButton",
	Parent = tabBar,
	Size = UDim2.new(1, 0, 0, 48), -- Increased height from 40 to 48
	Text = "История",
	BackgroundColor3 = colors.button_default, -- Changed to button_default
	TextColor3 = colors.text,
	Font = Enum.Font.SourceSansBold,
	TextSize = 16,
	AutoButtonColor = false,
})
Create("UICorner", { Parent = historyTabButton, CornerRadius = UDim.new(0, 24) }) -- Adjusted CornerRadius
Create("UIStroke", { Parent = historyTabButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3 }) -- Added UIStroke

-- Tab Content Frames
local profileTabContent = Create("Frame", {
	Name = "ProfileTabContent",
	Parent = tabContentContainer,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Visible = true,
	AutomaticSize = Enum.AutomaticSize.Y,
})
Create("UIListLayout", { Parent = profileTabContent, FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 16) })

local settingsTabContent = Create("Frame", {
	Name = "SettingsTabContent",
	Parent = tabContentContainer,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Visible = false,
	AutomaticSize = Enum.AutomaticSize.Y,
})
Create("UIListLayout", { Parent = settingsTabContent, FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 16) })

local historyTabContent = Create("Frame", {
	Name = "HistoryTabContent",
	Parent = tabContentContainer,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Visible = false,
	AutomaticSize = Enum.AutomaticSize.Y,
})
Create("UIListLayout", { Parent = historyTabContent, FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 16) })

-- Tab Switching Logic
local currentTab = profileTabContent

local function switchTab(tabToActivate, buttonToActivate, otherButton, otherTab)
	if currentTab == tabToActivate then return end

	currentTab.Visible = false
	if currentTab == profileTabContent then
		profileTabButton.BackgroundColor3 = colors.button_default -- Changed to button_default
		profileTabButton.TextColor3 = colors.text
	elseif currentTab == settingsTabContent then
		settingsTabButton.BackgroundColor3 = colors.button_default -- Changed to button_default
		settingsTabButton.TextColor3 = colors.text
	elseif currentTab == historyTabContent then
		historyTabButton.BackgroundColor3 = colors.button_default -- Changed to button_default
		historyTabButton.TextColor3 = colors.text
	end

	tabToActivate.Visible = true
	buttonToActivate.BackgroundColor3 = colors.tab_selected_background -- Changed to tab_selected_background
	buttonToActivate.TextColor3 = colors.buttonText
	currentTab = tabToActivate
end

profileTabButton.MouseButton1Click:Connect(function()
	switchTab(profileTabContent, profileTabButton)
end)

settingsTabButton.MouseButton1Click:Connect(function()
	switchTab(settingsTabContent, settingsTabButton)
end)

historyTabButton.MouseButton1Click:Connect(function()
	switchTab(historyTabContent, historyTabButton)
end)

-- Reparent existing UI elements to new tab content frames
-- The following elements should go into profileTabContent:
-- TopRow (avatar, name, plan, close button)
-- Individual Plans title
-- BillingRow
-- PlansRow (Free/Pro cards)
-- The following elements should go into settingsTabContent:
-- Settings title
-- settingsBlock (Privacy Mode Setting)
-- Active Sessions title
-- sessionsBlock (Web/Desktop App sessions)
-- Clear Chat History row
-- Delete Account row

local function setupProfileTab(parentFrame)
	-- Move TopRow
	local topRow = Create("Frame", { Name = "TopRow", Parent = parentFrame, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = colors.surface, BorderSizePixel = 0 })
	Create("UICorner", { Parent = topRow, CornerRadius = UDim.new(0, 24) })
	Create("UIStroke", { Parent = topRow, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3 })
	Create("UIPadding", { Parent = topRow, PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) })
	-- Create("UIListLayout", { Parent = topRow, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8) })

	local avatar = Create("ImageLabel", { Parent = topRow, Size = UDim2.new(0, 56, 0, 56), BackgroundColor3 = colors.softer, BorderSizePixel = 0, Image = "rbxthumb://type=AvatarHeadShot&id=" .. localPlayer.UserId .. "&w=150&h=150", ScaleType = Enum.ScaleType.Crop, Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }) -- Adjusted Position
	Create("UICorner", { Parent = avatar, CornerRadius = UDim.new(0, 28) })

	local nameLabel = Create("TextLabel", { Parent = topRow, Position = UDim2.new(0, 16 + 56 + 16, 0, 20), Size = UDim2.new(1, - (16 + 56 + 16 + 16 + 100), 0, 28), BackgroundTransparency = 1, Font = Enum.Font.SourceSansBold, Text = localPlayer.Name, TextSize = 22, TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left })
	local idLabel = Create("TextLabel", { Parent = topRow, Position = UDim2.new(0, 16 + 56 + 16, 0, 50), Size = UDim2.new(1, - (16 + 56 + 16 + 16 + 100), 0, 18), BackgroundTransparency = 1, Font = Enum.Font.SourceSans, Text = "ID: " .. tostring(localPlayer.UserId), TextSize = 14, TextColor3 = colors.muted, TextXAlignment = Enum.TextXAlignment.Left })

	local planPill = Create("TextLabel", { Parent = topRow, Position = UDim2.new(0, 16 + 56 + 16, 0, 75), Size = UDim2.new(0, 100, 0, 20), BackgroundColor3 = colors.sidebar_button_darker, Font = Enum.Font.SourceSansSemibold, Text = "", TextSize = 12, TextColor3 = colors.buttonText, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
	local uic1 = Create("UICorner", { Parent = planPill, CornerRadius = UDim.new(0, 24) })
	local uip1 = Create("UIPadding", { Parent = planPill, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })

	local dailyLimitPill = Create("TextLabel", { Parent = topRow, Position = UDim2.new(0, 16 + 56 + 16 + 100 + 8, 0, 75), Size = UDim2.new(0, 150, 0, 20), BackgroundColor3 = colors.softer, Font = Enum.Font.SourceSansSemibold, Text = "Лимит: 0/50 в день", TextSize = 12, TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
	local uic2 = Create("UICorner", { Parent = dailyLimitPill, CornerRadius = UDim.new(0, 24) })
	local uip2 = Create("UIPadding", { Parent = dailyLimitPill, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
	Create("UIStroke", { Parent = dailyLimitPill, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1 })

	local closeButton = Create("TextButton", {
		Name = "CloseButton",
		Parent = topRow, 
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.new(0, 100, 0, 30),
		Text = "Закрыть",
		BackgroundColor3 = colors.button_default, -- Changed to button_default
		TextColor3 = colors.text,
		Font = Enum.Font.SourceSansBold,
		TextSize = 16,
		AutoButtonColor = false,
	})
	Create("UICorner", { Parent = closeButton, CornerRadius = UDim.new(0, 18) })
	Create("UIStroke", { Parent = closeButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3 })
	closeButton.MouseButton1Click:Connect(function()
		screenGui.Enabled = false
	end)

	-- Заголовок плана (moved to profileTabContent)
	local plansTitle = Create("TextLabel", { Parent = parentFrame, LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.SourceSansBold, Text = "Индивидуальные планы", TextSize = 24, TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left })

	-- Переключатели оплаты (визуал без логики) (moved to profileTabContent)
	-- local billingRow = Create("Frame", { Parent = parentFrame, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	-- Create("UIListLayout", { Parent = billingRow, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) })
	-- local monthlyBtn = Create("TextButton", { Parent = billingRow, Size = UDim2.new(0, 120, 0, 32), BackgroundColor3 = colors.accent, Text = "MONTHLY", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.SourceSansBold, TextSize = 14, AutoButtonColor = false })
	-- Create("UICorner", { Parent = monthlyBtn, CornerRadius = UDim.new(1, 0) })
	-- Create("UIStroke", { Parent = monthlyBtn, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1 })
	-- Годовую оплату убрали по требованию

	-- Карточки планов: Free / Pro / Ultra (moved to profileTabContent)
	local plansRow = Create("Frame", { Parent = parentFrame, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 350), BackgroundTransparency = 1 })
	Create("UIListLayout", { Parent = plansRow, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, Padding = UDim.new(0, 8) })

	local function createPlanCard(title, priceText, details, accentColor)
		local card = Create("Frame", { Parent = plansRow, Size = UDim2.new(1/2, -12, 1, 0), BackgroundColor3 = colors.surface, BorderSizePixel = 0 }) -- Changed height to 1
		Create("UICorner", { Parent = card, CornerRadius = UDim.new(0, 24) })
		Create("UIStroke", { Parent = card, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3 })
		-- Create("UIPadding", { Parent = card, PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }) -- Removed padding
		-- Create("UIListLayout", { Parent = card, FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }) -- Removed layout

		local titleLabel = Create("TextLabel", { Parent = card, Position = UDim2.new(0, 20, 0, 20), Size = UDim2.new(1, -40, 0, 28), BackgroundTransparency = 1, Font = Enum.Font.SourceSansBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Text = title, TextColor3 = colors.text })
		local priceLabel = Create("TextLabel", { Parent = card, Position = UDim2.new(0, 20, 0, 50), Size = UDim2.new(1, -40, 0, 40), BackgroundTransparency = 1, Font = Enum.Font.SourceSansBold, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, Text = priceText, TextColor3 = colors.text })
		local includes = Create("TextLabel", { Parent = card, Position = UDim2.new(0, 20, 0, 95), Size = UDim2.new(1, -40, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.SourceSansSemibold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Text = "Включает", TextColor3 = colors.muted })
		local body = Create("TextLabel", { Parent = card, Position = UDim2.new(0, 20, 0, 120), Size = UDim2.new(1, -40, 1, -180), BackgroundTransparency = 1, Font = Enum.Font.SourceSans, TextSize = 16, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, Text = details, TextColor3 = colors.text, AutomaticSize = Enum.AutomaticSize.Y })
		local action = Create("TextButton", { Parent = card, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.new(1, -40, 0, 40), BackgroundColor3 = accentColor or colors.interactive_color, TextColor3 = colors.buttonText, TextSize = 16, Font = Enum.Font.SourceSansBold, AutoButtonColor = false, Text = "Выбрать"})
		Create("UICorner", { Parent = action, CornerRadius = UDim.new(0, 18) })
		Create("UIStroke", { Parent = action, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1.3 })
		return card, action, titleLabel
	end

	local freeDetails = "• RoGemini — AI-чат и собеседник\n• Базовое хранение истории диалогов\n• Режим Canvas (основные блоки)\n• Стандартное окно контекста"
	local proDetails = "Все возможности Стандартного плана, плюс:\n• Расширенные лимиты на сообщения и контекст\n• Полная история диалогов\n• Расширенный режим Canvas\n• Фоновые агенты и автоматизация\n• Bugbot и ранний доступ к новым функциям"

	local freeCard, freeAction = createPlanCard("Free", "0 rbx / мес", freeDetails, colors.plan_background_color)
	local proCard, proAction = createPlanCard("Pro", "250 rbx / мес", proDetails, colors.interactive_color)

	local currentPlan = "free"

	local function applyPlanVisual(plan)
		currentPlan = (plan or "free"):lower()
		local freeStroke = freeCard:FindFirstChildOfClass("UIStroke")
		local proStroke = proCard:FindFirstChildOfClass("UIStroke")
		if currentPlan == "pro" then
			planPill.Text = "ПЛАН: PRO"
			planPill.TextColor3 = colors.pro_plan_color

			if proStroke then proStroke.Color = colors.accent end
			if freeStroke then freeStroke.Color = colors.soft_stroke end

			proAction.Text = "Текущий план"
			proAction.Active = false
			proAction.AutoButtonColor = false
			proAction.BackgroundColor3 = colors.interactive_color

			freeAction.Text = "Переключиться"
			freeAction.Active = true
			freeAction.AutoButtonColor = true
			freeAction.BackgroundColor3 = colors.button_default
		else
			planPill.Text = "ПЛАН: FREE"
			planPill.TextColor3 = colors.free_plan_color

			if freeStroke then freeStroke.Color = colors.accent end
			if proStroke then proStroke.Color = colors.soft_stroke end

			freeAction.Text = "Текущий план"
			freeAction.Active = false
			freeAction.AutoButtonColor = false
			freeAction.BackgroundColor3 = colors.interactive_color

			proAction.Text = "Перейти на Pro"
			proAction.Active = true
			proAction.AutoButtonColor = true
			proAction.BackgroundColor3 = colors.button_default
		end
	end

	local function loadUserInfo()
		if not GetUserInfo then return end
		local ok, info = pcall(function()
			return GetUserInfo:InvokeServer()
		end)
		if ok and info then
			applyPlanVisual(info.plan)
		else
			applyPlanVisual("free")
		end
	end

	freeAction.MouseButton1Click:Connect(function()
		applyPlanVisual("free")
	end)

	proAction.MouseButton1Click:Connect(function()
		tryUpdatePlan("pro")
	end)

	task.spawn(loadUserInfo)
end

local function setupSettingsTab(parentFrame)
	-- Раздел настроек (как на скриншоте Settings) (moved to settingsTabContent)
	local settingsTitle = Create("TextLabel", { Parent = parentFrame, LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.SourceSansBold, Text = "Настройки", TextSize = 24, TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left })

	local settingsBlock = Create("Frame", { Parent = parentFrame, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y })
	Create("UIListLayout", { Parent = settingsBlock, FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) })
	local privacyRow, privacyButton = createSettingRow(settingsBlock, "Настройка режима конфиденциальности", "Открыть")

	-- Clear Chat History (новая кнопка) (moved to historyTabContent)

	-- Delete Account (moved to settingsTabContent)
	local deleteRow, resetButton = createSettingRow(parentFrame, "Сброс аккаунта", "Сбросить", colors.interactive_color) -- Changed to interactive_color
	deleteRow.LayoutOrder = 3

	if privacyButton then
		privacyButton.MouseButton1Click:Connect(function()
			-- простая анимация/заглушка
			TweenService:Create(privacyButton, TweenInfo.new(0.1), {BackgroundColor3 = colors.interactive_color}):Play() -- Changed to interactive_color
			task.delay(0.15, function()
				TweenService:Create(privacyButton, TweenInfo.new(0.1), {BackgroundColor3 = colors.button_default}):Play() -- Changed to button_default
			end)
		end)
	end

	resetButton.MouseButton1Click:Connect(function()
		ConfirmationDialogModule.showConfirmation("resetAccountConfirmation", ResetAuthData, localPlayer)
	end)
end

local function setupHistoryTab(parentFrame)
	local activeSessionsTitle = Create("TextLabel", { Parent = parentFrame, LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.SourceSansBold, Text = "История", TextSize = 24, TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left })
	-- local sessionsBlock = Create("Frame", { Parent = parentFrame, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y }) -- Removed
	-- Create("UIListLayout", { Parent = sessionsBlock, FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) }) -- Removed
	-- local webRow, webButton = createSettingRow(sessionsBlock, "Веб — Создано только что", "Отключить") -- Removed
	-- local appRow, appButton = createSettingRow(sessionsBlock, "Приложение на ПК — Создано только что", "Отключить") -- Removed

	local clearHistoryRow, clearHistoryButton = createSettingRow(parentFrame, "Очистить историю чата", "Очистить", colors.button_default) -- Changed to button_default
	clearHistoryRow.LayoutOrder = 2

	clearHistoryButton.MouseButton1Click:Connect(function()
		local clearAllChatHistoryEvent = ReplicatedStorage:FindFirstChild("ClearAllChatHistory")

		if not clearAllChatHistoryEvent then
			warn("ERROR: ClearAllChatHistory RemoteEvent not found!")
			return
		end

		ConfirmationDialogModule.showConfirmation("clearAllChatHistoryConfirmation", clearAllChatHistoryEvent)
	end)
end

-- Загрузка инфо
-- task.spawn(loadUserInfo) -- Removed as loadUserInfo is now local to setupProfileTab

setupProfileTab(profileTabContent)
setupSettingsTab(settingsTabContent)
setupHistoryTab(historyTabContent)

-- Автоскрытие при клике по тёмному фону
-- overlay.InputBegan:Connect(function(input)
--     if input.UserInputType == Enum.UserInputType.MouseButton1 then
--         screenGui.Enabled = false
--     end
-- end)


