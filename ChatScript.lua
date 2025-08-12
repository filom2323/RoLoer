--- // СЕРВИСЫ --------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

--- // ЛОКАЛЬНЫЕ ПЕРЕМЕННЫЕ ------------------------------------
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local MenuManager = require(game:GetService("StarterGui"):WaitForChild("MenuManager"))
local ConfirmationDialogModule = require(game:GetService("StarterGui"):WaitForChild("ConfirmationDialogModule"))
-- local InfoPageModule = require(game:GetService("StarterGui"):WaitForChild("InfoPage")) -- Moved and refactored

--- // СОСТОЯНИЕ / ЧАТ-ЛОГИКА ----------------------------------
local chats = {}
local activeChatId = nil
local nextChatId = 1
local isSidebarExpanded = false
local activeLoadingIndicator = nil
local isCanvasModeActive = false
local isInputExpandedByUser = false
local closeOverlay = nil
local MAX_TITLE_LENGTH = 50
local CHAT_BUTTON_TITLE_LIMIT = 12
local infoPageApi = nil -- Declare infoPageApi
local CANVAS_CHUNK_SIZE = 1000 -- Примерное количество символов для одного блока Canvas
local isAiGenerating = false -- New flag to track AI generation state
local LOCAL_MIN_INTERVAL = 2 -- локальный кулдаун на отправку (сек)
local nextLocalSendAllowedAt = 0

--- // Remote-объекты ------------------------------------------
local sendMessageEvent = ReplicatedStorage:WaitForChild("SendMessageToServer", 30)
local receiveMessageEvent = ReplicatedStorage:WaitForChild("ReceiveMessageFromServer", 30)
local getChatHistoryFunction = ReplicatedStorage:WaitForChild("GetChatHistory", 30)
local updateChatMetadataEvent = ReplicatedStorage:WaitForChild("UpdateChatMetadata", 30)
local deleteChatEvent = ReplicatedStorage:WaitForChild("DeleteChat", 30)
local renameChatEvent = ReplicatedStorage:WaitForChild("RenameChat", 30)
local resetAuthDataEvent = ReplicatedStorage:WaitForChild("ResetAuthData", 30)
local getUserInfoFunction = ReplicatedStorage:WaitForChild("GetUserInfo", 30)
local clearAllChatHistoryEvent = ReplicatedStorage:WaitForChild("ClearAllChatHistory", 30)
local cancelGenerationEvent = ReplicatedStorage:WaitForChild("CancelGeneration", 30) -- New RemoteEvent

--- // ОТКЛЮЧАЕМ СТАНДАРТНЫЙ GUI -------------------------------
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	PlayerModule:GetControls():Disable()
end)

--- // ХЕЛПЕРЫ -------------------------------------------------
local function Create(className, props)
	local instance = Instance.new(className)
	for k, v in pairs(props) do instance[k] = v end
	return instance
end

local InfoPageModule = nil
do
	local modScript = game:GetService("StarterGui"):WaitForChild("InfoPage")
	if modScript then
		local success, module = pcall(require, modScript)
		if success and module then
			InfoPageModule = module
		else
			warn("Не удалось загрузить InfoPage модуль.")
		end
	else
		warn("InfoPage модуль не найден.")
	end
end

local function truncateText(text, maxLength)
	if not text then return "" end
	text = text:gsub("%s+", " "):gsub("\n", " "):gsub("\r", " ")
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text > maxLength then
		return text:sub(1, maxLength) .. "..."
	end
	return text
end

local function truncateChatButtonTitle(text, maxLen)
	if not text then return "Новый чат" end
	text = text:gsub("[%s\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if #text > maxLen then
		return text:sub(1, maxLen) .. "..."
	end
	return text
end

local function hasNonWhitespace(text)
	return text ~= nil and text:match("%S") ~= nil
end

local function cleanMessageText(text)
	if not text then return "" end
	-- Remove leading/trailing whitespace
	text = text:gsub("^%s*", ""):gsub("%s*$", "")
	-- Replace multiple newlines with a single newline
	text = text:gsub("\n%s*\n+", "\n")
	-- Replace multiple spaces with a single space
	text = text:gsub("%s+", " ")
	return text
end

--- // ЦВЕТА ----------------------------------------------------
local colors = {
	background = Color3.fromRGB(18, 19, 21),
	sidebar = Color3.fromRGB(25, 26, 28),
	sidebar_button_darker = Color3.fromRGB(44, 47, 51),
	input = Color3.fromRGB(25, 26, 28),
	stroke = Color3.fromRGB(70, 74, 80),
	soft_stroke = Color3.fromRGB(58, 60, 64),
	text = Color3.fromRGB(235, 238, 240),
	text_muted = Color3.fromRGB(160, 164, 170),
	accent = Color3.fromRGB(72, 122, 255),
	accent_soft = Color3.fromRGB(56, 98, 220),
	player_message_bg = Color3.fromRGB(40, 42, 44), -- Более светлый фон для сообщений игрока
	ai_message_bg = Color3.fromRGB(30, 31, 33), -- Более светлый фон для сообщений ИИ
	-- Цвета для планов
	free_plan_color = Color3.fromRGB(34, 197, 94), -- Зеленый для Free
	pro_plan_color = Color3.fromRGB(147, 51, 234), -- Фиолетовый для Pro
	danger = Color3.fromRGB(231, 76, 60), -- Красный для удаления
	cyan = Color3.fromRGB(0, 120, 220), -- Более яркий синий цвет (изменено на более глубокий оттенок)
	active_blue_stroke = Color3.fromRGB(0, 100, 220), -- Slightly lighter blue for active stroke
	muted = Color3.fromRGB(160, 164, 170),
	new_button_background = Color3.fromRGB(32, 33, 36), -- New color for button background
	new_button_hover = Color3.fromRGB(44, 45, 48), -- New color for button hover
}

--- // ЭКРАННЫЙ GUI-КОНТЕЙНЕР ----------------------------------
local screenGui = script.Parent
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false

ConfirmationDialogModule.init() -- Initialize the module
infoPageApi = InfoPageModule.init(screenGui) -- Initialize InfoPage and get API

--- // Tween-константы -----------------------------------------
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local inputTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local expandedSidebarWidth = UDim2.new(0.20, 0, 1, 0)
local collapsedSidebarWidth = UDim2.new(0, 60, 1, 0)
local expandedMainContentPos = UDim2.fromScale(0.20, 0)
local collapsedMainContentPos = UDim2.new(0, 60, 0, 0)
local expandedMainContentSize = UDim2.fromScale(0.80, 1)
local collapsedMainContentSize = UDim2.new(1, -60, 1, 0)

-- Константы для поля ввода
local INPUT_MIN_HEIGHT = 56
local INPUT_LIMIT_HEIGHT = 150
local INPUT_EXPANDED_HEIGHT = 350

--- // ФОН ------------------------------------------------------
Create("Frame", {
	Parent = screenGui,
	Size = UDim2.fromScale(1,1),
	BackgroundColor3 = colors.background,
	BorderSizePixel = 0
})

--- // САЙДБАР --------------------------------------------------
local sidebar = Create("Frame", { Name = "Sidebar", Parent = screenGui, Size = collapsedSidebarWidth, BackgroundColor3 = colors.sidebar, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 10 })
Create("UIStroke", { Parent = sidebar, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1 })
Create("UIPadding", { Parent = sidebar, PaddingTop = UDim.new(0,10), PaddingBottom = UDim.new(0,10), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 5) })
local newChatButton = Create("TextButton", { Name = "NewChatButton", Parent = sidebar, Size = UDim2.new(1,0,0,40), Position = UDim2.new(0, 0, 0, 60), Text = "", AutoButtonColor = false, BackgroundColor3 = colors.new_button_background, BorderSizePixel = 0, ZIndex = 2 })
Create("UICorner", {Parent = newChatButton, CornerRadius = UDim.new(1, 0)})
Create("UIPadding", {Parent = newChatButton, PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10)})
Create("UIStroke", { Parent = newChatButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1 })
local newChatLabel = Create("TextLabel", { Name="Label", Parent=newChatButton, Size=UDim2.new(1,0,1,0), Font=Enum.Font.SourceSansSemibold, Text="Новый чат", TextColor3=colors.active_blue_stroke, TextSize=16, BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, })
newChatButton.MouseEnter:Connect(function() TweenService:Create(newChatButton, TweenInfo.new(0.12), {BackgroundColor3 = colors.new_button_hover}):Play() end)
newChatButton.MouseLeave:Connect(function() TweenService:Create(newChatButton, TweenInfo.new(0.12), {BackgroundColor3 = colors.new_button_background}):Play() end)
local chatHistoryContainer = Create("ScrollingFrame", { Name="ChatHistoryContainer", Parent=sidebar, Size=UDim2.new(1, 5, 1, -190), Position=UDim2.new(0, 0, 0, 110), BackgroundTransparency=1, BorderSizePixel=0, Visible=false, ScrollBarThickness=6, ScrollBarImageColor3=colors.soft_stroke, ZIndex=2, AutomaticCanvasSize = Enum.AutomaticSize.Y })
local chatHistoryLayout = Create("UIListLayout", { Parent=chatHistoryContainer, FillDirection=Enum.FillDirection.Vertical, Padding=UDim.new(0,6) })
Create("UIPadding", { Parent = chatHistoryContainer, PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 4) })

--- // ГЛАВНАЯ ОБЛАСТЬ ------------------------------------------
local mainContent = Create("Frame", { Name="MainContent", Parent=screenGui, Position=collapsedMainContentPos, Size=collapsedMainContentSize, BackgroundColor3=colors.background, BorderSizePixel=0 })
Create("UIListLayout", { Parent=mainContent, FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder })
local topBar = Create("Frame", { Name="TopBar", Parent=mainContent, LayoutOrder=1, Size=UDim2.new(1,0,0,50), BackgroundColor3=colors.background, BorderSizePixel=0 })

local bottomButtonsContainer = Create("Frame", {
	Name = "BottomButtonsContainer",
	Parent = sidebar,
	Size = UDim2.new(1, 0, 0, 40), -- Height for the two buttons
	AnchorPoint = Vector2.new(0.5, 1), -- Anchor to bottom-center
	Position = UDim2.new(0.5, 0, 1, -10), -- Position at the bottom with a small offset
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 11, -- Ensure it's above other elements if needed
	Visible = false, -- Initially hidden when sidebar is collapsed
})

Create("UIListLayout", {
	Parent = bottomButtonsContainer,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 10), -- Increased padding between buttons
})

local aboutUsButton = Create("TextButton", {
	Name = "AboutUsButton",
	Parent = bottomButtonsContainer,
	Size = UDim2.new(0.40, 0, 0, 35), -- Made size equal
	Text = "О нас",
	BackgroundColor3 = colors.new_button_background,
	TextColor3 = colors.text, -- Changed to a general text color from the existing theme
	Font = Enum.Font.SourceSansBold,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	AutoButtonColor = false,
})
Create("UICorner", {Parent = aboutUsButton, CornerRadius = UDim.new(0, 16)})
Create("UIPadding", {Parent = aboutUsButton, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
Create("UIStroke", {Parent = aboutUsButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1})
aboutUsButton.MouseEnter:Connect(function() TweenService:Create(aboutUsButton, TweenInfo.new(0.12), {BackgroundColor3 = colors.new_button_hover}):Play() end)
aboutUsButton.MouseLeave:Connect(function() TweenService:Create(aboutUsButton, TweenInfo.new(0.12), {BackgroundColor3 = colors.new_button_background}):Play() end)
aboutUsButton.MouseButton1Click:Connect(function()
	if infoPageApi then
		infoPageApi.open()
		infoPageApi.setTab("О нас", "RoGemini — помощник и собеседник в Roblox. Цель — дать тебе быстрые ответы, вдохновить идеями и упростить рутину.")
	else
		warn("InfoPage API не инициализирован!")
	end
end)

local settingsButton = Create("TextButton", {
	Name = "SettingsButton",
	Parent = bottomButtonsContainer,
	Size = UDim2.new(0.40, 0, 0, 35), -- Made size equal
	Text = "Настройки",
	BackgroundColor3 = colors.new_button_background,
	TextColor3 = colors.accent, -- Changed to an accent color from the existing theme
	Font = Enum.Font.SourceSansBold, -- Changed to bold font
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	AutoButtonColor = false,
})
Create("UICorner", {Parent = settingsButton, CornerRadius = UDim.new(0, 16)})
Create("UIPadding", {Parent = settingsButton, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
Create("UIStroke", {Parent = settingsButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1})
settingsButton.MouseEnter:Connect(function() TweenService:Create(settingsButton, TweenInfo.new(0.12), {BackgroundColor3 = colors.new_button_hover}):Play() end)
settingsButton.MouseLeave:Connect(function() TweenService:Create(settingsButton, TweenInfo.new(0.12), {BackgroundColor3 = colors.new_button_background}):Play() end)
-- settingsButton.MouseButton1Click:Connect(function() -- Add functionality here end)

local profileIcon = Create("ImageButton", { Name = "Icon", Parent = topBar, BackgroundColor3 = colors.sidebar, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 40, 0, 40), AutoButtonColor = false })
Create("UICorner", {Parent=profileIcon, CornerRadius=UDim.new(1,0)})
Create("UIStroke", {Parent=profileIcon, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=Color3.fromRGB(43, 46, 50), Thickness=1.5})
local planPill = Create("TextLabel", {
	Name = "PlanPill", Parent = topBar,
	Size = UDim2.new(0, 0, 0, 18),
	Position = UDim2.new(1, -58, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.fromRGB(33, 35, 38),
	Font = Enum.Font.SourceSansBold,
	Text = "", TextSize = 12,
	TextColor3 = Color3.fromRGB(172, 172, 172),
	TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center
})
Create("UICorner", {Parent = planPill, CornerRadius = UDim.new(1, 0)})
Create("UIPadding", {Parent=planPill, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})
local topBarChatTitle = Create("TextLabel", { Name = "TopBarChatTitle", Parent = topBar, Size = UDim2.new(1, -130, 1, 0), Position = UDim2.new(0, 20, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Font = Enum.Font.SourceSansBold, Text = "", TextColor3 = colors.text, TextSize = 17, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
local contentArea = Create("Frame", { Name="ContentArea", Parent=mainContent, LayoutOrder=2, Size=UDim2.new(1,0,1,-50), BackgroundTransparency=1 })
local welcomeText = Create("TextLabel", { Name="WelcomeText", Parent=contentArea, AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.4), Size=UDim2.fromScale(0.8,0.2), BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Text="Здравствуйте, "..player.Name.."!", TextColor3=colors.active_blue_stroke, TextSize=48, TextWrapped=true })
local watermark = Create("TextLabel", { Name="Watermark", Parent=contentArea, AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.8), Size=UDim2.fromScale(0.8,0.1), BackgroundTransparency=1, Font=Enum.Font.SourceSans, Text="TEST ("..player.Name..")", TextColor3=Color3.fromRGB(150, 150, 150), TextTransparency=0.75, TextSize=24 })
local messageContainer = Create("ScrollingFrame",{ Name="MessageContainer", Parent=contentArea, Position=UDim2.new(0,0,0,0), Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0, CanvasSize=UDim2.new(0,0,0,0), ScrollBarThickness=4, ScrollBarImageColor3=colors.soft_stroke, })
local messageListLayout = Create("UIListLayout",{ Parent=messageContainer, FillDirection=Enum.FillDirection.Vertical, HorizontalAlignment=Enum.HorizontalAlignment.Left, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10) })
Create("UIPadding",{ Parent=messageContainer, PaddingLeft=UDim.new(0.05,0), PaddingRight=UDim.new(0.05,0), PaddingTop=UDim.new(0,30) })
local scrollSpacer = Create("Frame",{ Name="ScrollSpacer", Parent=messageContainer, Size=UDim2.new(1,0,0,100), BackgroundTransparency=1, LayoutOrder=999 })
local inputAreaContainer = Create("Frame",{
	Name="InputAreaContainer", Parent=contentArea, AnchorPoint=Vector2.new(0.5,1),
	Position=UDim2.new(0.5,0,1,-5), Size=UDim2.new(0.8,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
	BackgroundTransparency=1,
})
Create("UIListLayout",{ Parent=inputAreaContainer, FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

local quickMessageContainer = Create("Frame", {
	Name = "QuickMessageContainer",
	Parent = inputAreaContainer,
	LayoutOrder = 0,
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
})
Create("UIListLayout", { Parent = quickMessageContainer, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8) })

local function createQuickMessageButton(text, messageText)
	local button = Create("TextButton", {
		Name = text:gsub(" ", ""):gsub("\n", "").."Button",
		Parent = quickMessageContainer,
		Size = UDim2.new(0, 180, 0, 34),
		Text = text,
		BackgroundColor3 = colors.input,
		TextColor3 = colors.text_muted,
		Font = Enum.Font.SourceSansBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		AutoButtonColor = false,
	})
	Create("UICorner", {Parent = button, CornerRadius = UDim.new(0, 12)})
	Create("UIPadding", {Parent = button, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
	Create("UIStroke", {Parent = button, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1})

	button.MouseEnter:Connect(function() TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = colors.sidebar_button_darker, TextColor3 = colors.text}):Play() end)
	button.MouseLeave:Connect(function() TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = colors.input, TextColor3 = colors.text_muted}):Play() end)
	button.MouseButton1Click:Connect(function()
		print("DEBUG: Quick message button clicked. Attempting to find inputBox...")
		local currentInputBox = inputAreaContainer.InputWrapper.InputFrame.InputScroll.InputBox
		if currentInputBox then
			currentInputBox.Text = messageText
			print("DEBUG: inputBox.Text set to: ", messageText)
			sendMessage()
		else
			warn("ERROR: inputBox not found in UI hierarchy!")
		end
	end)
	return button
end

createQuickMessageButton("How does it work?", "How does it work?")
createQuickMessageButton("What is your purpose?", "What is your purpose?")
createQuickMessageButton("What are your capabilities?", "What are your capabilities?")

local inputWrapper = Create("Frame",{ Name="InputWrapper", Parent=inputAreaContainer, Size=UDim2.new(1,0,0,70), BackgroundTransparency=1, LayoutOrder=1 })
local inputFrame = Create("Frame",{ Name="InputFrame", Parent=inputWrapper, Size=UDim2.new(1,0,1,0), BackgroundColor3=colors.new_button_background, BorderSizePixel=0 })
Create("UICorner",{Parent=inputFrame, CornerRadius=UDim.new(0,24)})
Create("UIListLayout",{ Parent=inputFrame, FillDirection=Enum.FillDirection.Horizontal, VerticalAlignment=Enum.VerticalAlignment.Center, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10) })
Create("UIPadding",{Parent=inputFrame, PaddingLeft=UDim.new(0,15), PaddingRight=UDim.new(0,15), PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,10) })
Create("UIStroke",{Parent=inputFrame, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=colors.soft_stroke, Thickness=1})
local plusButton = Create("TextButton",{ Name="PlusButton", Parent=inputFrame, LayoutOrder=1, Size=UDim2.new(0,32,0,32), BackgroundTransparency=1, Font=Enum.Font.SourceSansBold, Text="+", TextSize=26, TextColor3=colors.text_muted })
local inputScroll = Create("ScrollingFrame",{ Name="InputScroll", Parent=inputFrame, LayoutOrder=2, Size=UDim2.new(1, -42, 1, 0), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4, ScrollBarImageColor3=colors.stroke, ScrollingDirection=Enum.ScrollingDirection.Y, CanvasSize=UDim2.new(1,0,1,0) })
local inputBox = Create("TextBox",{ Name="InputBox", Parent=inputScroll, Size=UDim2.new(1, -42, 1, 0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, BorderSizePixel=0, ClearTextOnFocus=false, Font=Enum.Font.SourceSans, PlaceholderText="Спросить Gemini…", PlaceholderColor3=colors.text_muted, Text="", TextWrapped=true, TextColor3=colors.text, TextSize=18, MultiLine=true, TextXAlignment=Enum.TextXAlignment.Left })
local bottomButtons = Create("Frame",{ Name="BottomButtons", Parent=inputAreaContainer, LayoutOrder=2, Size=UDim2.new(1,0,0,34), BackgroundTransparency=1 })
Create("UIListLayout",{ Parent=bottomButtons, FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Right, VerticalAlignment=Enum.VerticalAlignment.Center, Padding=UDim.new(0,8) })
local canvasButton = Create("TextButton",{ Name="CanvasButton", Parent=bottomButtons, LayoutOrder=1, Size=UDim2.new(0,70,0,30), BackgroundColor3=colors.new_button_background, Font=Enum.Font.SourceSansBold, Text="Canvas", TextSize=14, TextColor3=colors.text_muted, AutoButtonColor = false })
Create("UICorner",{Parent=canvasButton, CornerRadius=UDim.new(1, 0)})
Create("UIStroke",{Parent=canvasButton, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=colors.soft_stroke, Thickness=1})
local sendButton = Create("TextButton",{
	Name="SendButton", Parent=bottomButtons, LayoutOrder=3, Size=UDim2.new(0,30,0,30),
	BackgroundColor3=colors.new_button_background, Text="⏎", Font=Enum.Font.SourceSansBold, TextSize=16,
	TextColor3=colors.text_muted, Visible=false
})
Create("UICorner",{Parent=sendButton, CornerRadius=UDim.new(1,0)})
Create("UIStroke",{Parent=sendButton, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=colors.soft_stroke, Thickness=1})
local disclaimerLabel = Create("TextLabel",{ Name="DisclaimerLabel", Parent=inputAreaContainer, LayoutOrder=3, Size=UDim2.new(1,0,0,15), BackgroundTransparency=1, Font=Enum.Font.SourceSans, Text="Ответы могут быть неточными; проверяйте информацию.", TextColor3=colors.text_muted, TextSize=13, TextXAlignment=Enum.TextXAlignment.Center })
local hintLabel = Create("TextLabel",{ Name="HintLabel", Parent=inputAreaContainer, LayoutOrder=3, Size=UDim2.new(1,0,0,15), BackgroundTransparency=1, Font=Enum.Font.SourceSans, Text="Shift + Enter — перенос строки", TextColor3=colors.text_muted, TextSize=13, TextXAlignment = Enum.TextXAlignment.Center, Visible=false })


--- // CANVAS VIEW И UI-ШАБЛОНЫ
local playerMessageTemplate = Create("Frame",{ Name="PlayerMessageRowFrame", Parent=script, AutomaticSize=Enum.AutomaticSize.Y, Size=UDim2.new(1,0,0,0), BackgroundTransparency=1 })
local messageLabel = Create("TextLabel",{ Name="MessageLabel", Parent=playerMessageTemplate, AutomaticSize=Enum.AutomaticSize.XY, Size=UDim2.new(0,0,0,0), Font=Enum.Font.SourceSans, Text="placeholder", TextWrapped=true, TextColor3=colors.text, TextSize=16, LineHeight=1.4, BackgroundColor3=colors.player_message_bg, BackgroundTransparency=0, TextXAlignment=Enum.TextXAlignment.Right, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0) })
Create("UICorner",{Parent=messageLabel, CornerRadius=UDim.new(0,12)})
Create("UIPadding",{Parent=messageLabel, PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,8), PaddingLeft=UDim.new(0,12), PaddingRight=UDim.new(0,12)})
Create("UISizeConstraint",{Parent=messageLabel, MaxSize=Vector2.new(650,1000)})
local aiMessageTemplate = Create("Frame",{ Name="AiMessageRowFrame", Parent=script, AutomaticSize=Enum.AutomaticSize.Y, Size=UDim2.new(1,0,0,0), BackgroundTransparency=1 })
local aiContainer = Create("Frame",{ Name="AiMessageContainer", Parent=aiMessageTemplate, AutomaticSize=Enum.AutomaticSize.XY, Size=UDim2.new(1,0,0,0), BackgroundTransparency=1 })
Create("UIListLayout",{Parent=aiContainer, FillDirection=Enum.FillDirection.Horizontal, VerticalAlignment=Enum.VerticalAlignment.Top, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8)})
local iconContainer = Create("Frame",{ Name="IconContainer", Parent=aiContainer, Size=UDim2.new(0,26,0,26), BackgroundTransparency=1, LayoutOrder=1 })
local aiIcon = Create("ImageLabel", { Name = "AiIcon", Parent = iconContainer, Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), BackgroundTransparency = 1, Image = "rbxassetid://76215324363391", ImageColor3 = colors.active_blue_stroke })
local aiTextLabel = Create("TextLabel",{ Name="AiTextLabel", Parent=aiContainer, LayoutOrder=2, AutomaticSize=Enum.AutomaticSize.XY, Size=UDim2.new(1,-40,0,0), BackgroundTransparency=0.1, BackgroundColor3 = colors.ai_message_bg, Font=Enum.Font.SourceSans, Text="", TextWrapped=true, LineHeight=1, TextColor3=colors.text, TextSize=16, TextXAlignment=Enum.TextXAlignment.Left })
Create("UISizeConstraint",{Parent=aiTextLabel, MaxSize=Vector2.new(650, math.huge)})
Create("UICorner", {Parent = aiTextLabel, CornerRadius = UDim.new(0, 10)})
Create("UIPadding", {Parent = aiTextLabel, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
local aiCanvasButtonTemplate = Create("Frame",{ Name="AiCanvasButtonRowFrame", Parent=script, AutomaticSize=Enum.AutomaticSize.Y, Size=UDim2.new(1,0,0,0), BackgroundTransparency=1 })
local aiCanvasContainer = Create("Frame",{ Name="AiCanvasButtonContainer", Parent=aiCanvasButtonTemplate, AutomaticSize=Enum.AutomaticSize.XY, Size=UDim2.new(1,0,0,0), BackgroundTransparency=1 })
Create("UIListLayout",{Parent=aiCanvasContainer, FillDirection=Enum.FillDirection.Vertical, HorizontalAlignment=Enum.HorizontalAlignment.Left, Padding=UDim.new(0,8)})
local promptLabel = Create("TextLabel",{ Name="CanvasPromptLabel", Parent=aiCanvasContainer, AutomaticSize=Enum.AutomaticSize.XY, BackgroundTransparency=1, Font=Enum.Font.SourceSans, Text="Ваше сообщение готово.", TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, TextColor3=colors.text, TextSize=16 })
local showCanvasButton = Create("TextButton",{ Name="ShowCanvasButton", Parent=aiCanvasContainer, Size=UDim2.new(0,0,0,35), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3=colors.input, Font=Enum.Font.SourceSansBold, Text="Посмотреть результат", TextColor3=colors.active_blue_stroke, TextSize=14 })
Create("UIPadding", {Parent=showCanvasButton, PaddingLeft=UDim.new(0,15), PaddingRight=UDim.new(0,15)})
Create("UICorner",{Parent=showCanvasButton, CornerRadius=UDim.new(1,0)})
Create("UIStroke",{Parent=showCanvasButton, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=colors.soft_stroke, Thickness=1})
local loadingTemplate = Create("Frame",{ Name="LoadingRowFrame", Parent=script, AutomaticSize=Enum.AutomaticSize.Y, Size=UDim2.new(1,0,0,0), BackgroundTransparency=1 })
local loadingContainer = Create("Frame",{ Name="LoadingContainer", Parent=loadingTemplate, AutomaticSize=Enum.AutomaticSize.X, Size=UDim2.new(1,0,0,36), BackgroundTransparency=1 })
Create("UIListLayout",{Parent=loadingContainer, FillDirection=Enum.FillDirection.Horizontal, VerticalAlignment=Enum.VerticalAlignment.Center, Padding=UDim.new(0,8)})
local animationContainer = Create("Frame",{ Name="AnimationContainer", Parent=loadingContainer, Size=UDim2.new(0,26,0,26), BackgroundTransparency=1, LayoutOrder=1 })
local outerRing = Create("ImageLabel", { Name = "OuterRing", Parent = animationContainer, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://76215324363391", ImageColor3 = colors.accent })
local loadingText = Create("TextLabel",{ Name="LoadingText", Parent=loadingContainer, LayoutOrder=2, Size=UDim2.new(0,200,1,0), BackgroundTransparency=1, Text="думаю над ответом…", TextColor3=colors.text_muted, Font=Enum.Font.SourceSans, TextSize=16, TextXAlignment=Enum.TextXAlignment.Left })
local chatButtonTemplate = Create("TextButton",{ Name="ChatButtonContainer", Parent=script, Size=UDim2.new(1, -6, 0, 40), Text="", AutoButtonColor = false, BackgroundColor3 = colors.sidebar })
Create("UICorner", {Parent = chatButtonTemplate, CornerRadius = UDim.new(0, 10)})
Create("UIPadding", {Parent = chatButtonTemplate, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)})
local chatTitleLabel = Create("TextLabel", { Name="Label", Parent=chatButtonTemplate, Size = UDim2.new(1, -14, 1, 0), Position = UDim2.new(0, 6, 0, 0), RichText = false, BackgroundTransparency=1, Font=Enum.Font.SourceSansSemibold, Text="Новый чат", TextSize=16, TextColor3=colors.text, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, TextTruncate=Enum.TextTruncate.AtEnd })
-- Маленькая синяя метка готовности ответа на кнопке чата (скрыта по умолчанию)
local chatReadyDot = Create("Frame", {
	Name = "ReadyDot",
	Parent = chatButtonTemplate,
	Size = UDim2.new(0, 8, 0, 8),
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	BackgroundColor3 = colors.cyan,
	Visible = false,
	BorderSizePixel = 0,
})
Create("UICorner", { Parent = chatReadyDot, CornerRadius = UDim.new(1, 0) })
local function cleanTitle(s) if not s then return "Новый чат" end; s = s:gsub("[\r\n]+", " "):gsub("%s+", " "); s = s:gsub("^%s+", ""):gsub("%s+$", ""); return s end

--- // ОСНОВНАЯ ЛОГИКА
local function updateAndScroll() task.wait(); local h = messageListLayout.AbsoluteContentSize.Y; messageContainer.CanvasSize = UDim2.new(0,0,0,h); task.wait(); local maxY = messageContainer.CanvasSize.Y.Offset - messageContainer.AbsoluteSize.Y; if maxY > 0 then messageContainer.CanvasPosition = Vector2.new(0,maxY) end end
local function spinElement(indicator) if not indicator or not indicator.rotatingPart then return end; local elementToSpin = indicator.rotatingPart; while not indicator.stop and elementToSpin and elementToSpin.Parent do local tween = TweenService:Create(elementToSpin, TweenInfo.new(1,Enum.EasingStyle.Linear), {Rotation = elementToSpin.Rotation + 360}); tween:Play(); tween.Completed:Wait() end end
local function createLoadingIndicator() local row = loadingTemplate:Clone(); row.Parent = messageContainer; local rotatingElement = row.LoadingContainer.AnimationContainer.OuterRing; return {row = row, rotatingPart = rotatingElement, stop=false} end
local function createPlayerMessage(text) local row = playerMessageTemplate:Clone(); row.MessageLabel.Text = text; row.Parent = messageContainer end
local function createAiMessage(text) local row = aiMessageTemplate:Clone(); row.AiMessageContainer.AiTextLabel.Text = text; row.Parent = messageContainer; return row.AiMessageContainer.AiTextLabel end

-- Системное сообщение (серое, без влияния на синий индикатор)
local function createSystemMessage(text)
	local row = aiMessageTemplate:Clone()
	local label = row.AiMessageContainer.AiTextLabel
	label.Text = text
	label.TextColor3 = colors.text_muted
	label.BackgroundColor3 = Color3.fromRGB(38, 40, 42)
	row.Parent = messageContainer
	return label
end

local function createCanvasMessageBubble(fullText)
	local bubble = aiMessageTemplate:Clone() -- Используем тот же шаблон, что и для AI сообщений
	bubble.Name = "CanvasMessageBubble"
	bubble.AiMessageContainer.AiTextLabel:Destroy() -- Удаляем стандартный TextLabel из шаблона

	-- Создаем новый контейнер для чанков текста внутри пузырька
	local textChunksContainer = Create("Frame", {
		Name = "TextChunksContainer",
		Parent = bubble.AiMessageContainer,
		LayoutOrder = 2,
		Size = UDim2.new(1, -40, 0, 0), -- Ширина как у AiTextLabel
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	Create("UIListLayout", {
		Parent = textChunksContainer,
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 0), -- Отступ между чанками
	})

	local startIndex = 1
	while startIndex <= #fullText do
		local endIndex = math.min(startIndex + CANVAS_CHUNK_SIZE - 1, #fullText)

		-- Try to find a word boundary (space) near the end of the chunk
		local potentialEnd = endIndex
		if endIndex < #fullText then -- Only look for word breaks if it's not the very end of the text
			local space_index = string.find(fullText, "%s", startIndex, endIndex) -- Find first space within chunk
			local last_space_before_end = -1
			for i = startIndex, endIndex do
				if string.sub(fullText, i, i) == " " then
					last_space_before_end = i
				end
			end

			if last_space_before_end ~= -1 and (endIndex - last_space_before_end) < 50 then -- If a space is found and not too far from the chunk end
				endIndex = last_space_before_end
			end
		end

		local chunk = fullText:sub(startIndex, endIndex)

		local chunkLabel = Create("TextLabel", {
			Name = "ChunkLabel",
			Parent = textChunksContainer,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Text = chunk,
			TextWrapped = true,
			LineHeight = 1,
			TextColor3 = colors.text,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left
		})
		Create("UISizeConstraint", {Parent = chunkLabel, MaxSize = Vector2.new(650, math.huge)})

		startIndex = endIndex + 1
	end
	return bubble
end

local function createAndShowCanvasWindow(fullText)
	local newCanvasGui = Create("ScreenGui", { Name = "DynamicCanvasGui", Parent = playerGui, DisplayOrder = 100, IgnoreGuiInset = true, ResetOnSpawn = false })

	local overlay = Create("Frame", { -- Прозрачный фон для блокировки других взаимодействий
		Name = "Overlay",
		Parent = newCanvasGui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.background,
		BackgroundTransparency = 0.8,
	})

	local canvasFrame = Create("Frame", {
		Name = "CanvasFrame",
		Parent = overlay, -- Теперь родитель - оверлей
		Size = UDim2.new(0.8, 0, 0.8, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = colors.sidebar,
		BorderSizePixel = 0
	})
	Create("UICorner", {Parent = canvasFrame, CornerRadius = UDim.new(0.05, 0)})
	Create("UIListLayout", { Parent = canvasFrame, FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder })

	local canvasTopBar = Create("Frame", { Name = "CanvasTopBar", Parent = canvasFrame, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1 })
	local canvasCloseButton = Create("TextButton",{
		Name="CanvasCloseButton", Parent=canvasTopBar, Size=UDim2.new(0,100,0,40),
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0),
		Text="Закрыть", Font=Enum.Font.SourceSansBold, TextSize=16,
		TextColor3=colors.text, BackgroundColor3=colors.input
	})
	Create("UICorner",{Parent=canvasCloseButton, CornerRadius=UDim.new(1, 0)})
	Create("UIStroke",{Parent=canvasCloseButton, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=colors.soft_stroke, Thickness=1})

	-- Content Area for messages
	local canvasContentArea = Create("Frame", { Name = "CanvasContentArea", Parent = canvasFrame, LayoutOrder = 2, Size = UDim2.new(1, 0, 1, -60), BackgroundTransparency = 1 })
	Create("UIPadding", { Parent = canvasContentArea, PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20) })

	local canvasContentScroll = Create("ScrollingFrame",{
		Name="CanvasContentScroll", Parent=canvasContentArea,
		Size=UDim2.fromScale(1,1), BackgroundTransparency=1, BorderSizePixel=0,
		ScrollBarThickness=6, ScrollBarImageColor3 = Color3.fromRGB(15, 15, 15), ScrollBarImageTransparency = 0.5, AutomaticCanvasSize = Enum.AutomaticSize.Y -- Важно для авто-размера
	})
	Create("UIListLayout", { Parent = canvasContentScroll, FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10) })

	-- Добавляем сообщение Canvas в ScrollFrame
	local messageBubble = createCanvasMessageBubble(fullText)
	messageBubble.Parent = canvasContentScroll

	-- Автоматическая прокрутка в конец после загрузки контента
	local function scrollToBottom()
		task.wait(0.1) -- Небольшая задержка, чтобы UI успел обновиться
		local maxY = canvasContentScroll.CanvasSize.Y.Offset - canvasContentScroll.AbsoluteSize.Y
		if maxY > 0 then
			canvasContentScroll.CanvasPosition = Vector2.new(0, maxY)
		end
	end
	task.spawn(scrollToBottom)

	canvasCloseButton.MouseButton1Click:Connect(function()
		newCanvasGui:Destroy()
	end)
end

-- Визуал для CanvasButton
local function updateCanvasButtonVisual()
	local stroke = canvasButton:FindFirstChildOfClass("UIStroke")
	if isCanvasModeActive then
		canvasButton.BackgroundColor3 = colors.input
		canvasButton.TextColor3 = colors.text_muted
		if stroke then stroke.Color = colors.active_blue_stroke end
	else
		canvasButton.BackgroundColor3 = colors.input
		canvasButton.TextColor3 = colors.text_muted
		if stroke then stroke.Color = colors.soft_stroke end
	end
end

-- Плавающая круглая кнопка разворачивания (внутри контейнера ввода)
local expandFloatingButton = Create("TextButton",{
	Name = "ExpandFloatingButton",
	Parent = inputWrapper,
	Size = UDim2.new(0, 28, 0, 28),
	AnchorPoint = Vector2.new(1,0),
	Position = UDim2.new(1, -20, 0, 8),
	BackgroundColor3 = colors.input,
	Text = "↗",
	TextColor3 = colors.accent,
	Font = Enum.Font.SourceSansBold,
	TextSize = 18,
	Visible = false,
	AutoButtonColor = false,
	ZIndex = 5
})
Create("UICorner", {Parent = expandFloatingButton, CornerRadius = UDim.new(1, 0)})
Create("UIStroke", {Parent = expandFloatingButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.soft_stroke, Thickness = 1})
local function createCanvasSummaryButton(messageData) local row = aiCanvasButtonTemplate:Clone(); row.Parent = messageContainer; row.AiCanvasButtonContainer.ShowCanvasButton.MouseButton1Click:Connect(function() createAndShowCanvasWindow(messageData.fullText) end) end
local function updateQuickMessageButtonVisibility()
	local hasText = hasNonWhitespace(inputBox.Text)
	local chat = chats[activeChatId]
	local hasMessages = chat and #chat.messages > 0
	quickMessageContainer.Visible = not hasText and not hasMessages
end

local function updateHints() 
	local hasText = hasNonWhitespace(inputBox.Text);
	disclaimerLabel.Visible = not hasText and not isAiGenerating;
	hintLabel.Visible = hasText and not isAiGenerating;
	sendButton.Visible = hasText or isAiGenerating; 
	sendButton.Text = isAiGenerating and "●" or "⏎";
	sendButton.TextColor3 = isAiGenerating and colors.text or (hasText and colors.active_blue_stroke or colors.text_muted);
	updateQuickMessageButtonVisibility();
end
function updateInputHeight() local inputText = inputBox.Text ~= "" and inputBox.Text or inputBox.PlaceholderText; local size = TextService:GetTextSize(inputText, inputBox.TextSize, inputBox.Font, Vector2.new(inputBox.AbsoluteSize.X, math.huge)); local textHeight = size.Y + 20; local calculatedTargetHeight = math.max(INPUT_MIN_HEIGHT, textHeight); local limitReached = calculatedTargetHeight > INPUT_LIMIT_HEIGHT; local actualTargetHeight, enableScrolling; if limitReached and not isInputExpandedByUser then actualTargetHeight = INPUT_LIMIT_HEIGHT; enableScrolling = true elseif limitReached and isInputExpandedByUser then actualTargetHeight = INPUT_EXPANDED_HEIGHT; enableScrolling = true else actualTargetHeight = calculatedTargetHeight; enableScrolling = false; isInputExpandedByUser = false end; 
	-- Показ/скрытие круговой кнопки и её иконка
	expandFloatingButton.Visible = limitReached
	expandFloatingButton.Text = isInputExpandedByUser and "↖" or "↗"
	TweenService:Create(inputWrapper, inputTweenInfo, {Size = UDim2.new(1, 0, 0, actualTargetHeight)}):Play(); inputScroll.CanvasSize = enableScrolling and UDim2.new(1, 0, 0, size.Y + 10) or UDim2.new(1, 0, 1, 0) end
local collapseSidebar; local expandTrigger; function expandSidebar() if isSidebarExpanded then return end; isSidebarExpanded = true; expandTrigger.Visible = false; TweenService:Create(sidebar, tweenInfo, {Size = expandedSidebarWidth}):Play(); TweenService:Create(mainContent, tweenInfo, {Size = expandedMainContentSize, Position = expandedMainContentPos}):Play(); if not closeOverlay then closeOverlay = Create("TextButton", { Name = "CloseOverlay", Parent = screenGui, Size = UDim2.fromScale(1, 1), Text = "", BackgroundTransparency = 1, ZIndex = 9 }); closeOverlay.MouseButton1Click:Connect(collapseSidebar) end; task.delay(0.22, function() if isSidebarExpanded then chatHistoryContainer.Visible = true; bottomButtonsContainer.Visible = true; end end) end
function collapseSidebar() if not isSidebarExpanded then return end; isSidebarExpanded = false; MenuManager.close(); if closeOverlay then closeOverlay:Destroy(); closeOverlay = nil end; chatHistoryContainer.Visible = false; newChatButton.Visible = true; bottomButtonsContainer.Visible = false; TweenService:Create(sidebar, tweenInfo, {Size = collapsedSidebarWidth}):Play(); TweenService:Create(mainContent, tweenInfo, {Size = collapsedMainContentSize, Position = collapsedMainContentPos}):Play(); task.delay(0.22, function() if not isSidebarExpanded then expandTrigger.Visible = true end end) end
local function updateChatButtons() for id, data in pairs(chats) do if data.sidebarButton and data.sidebarButton.Parent then local chatButton = data.sidebarButton; local chatLabel = chatButton.Label; if id == activeChatId then chatButton.BackgroundColor3 = colors.sidebar_button_darker; chatLabel.TextColor3 = colors.text else chatButton.BackgroundColor3 = colors.sidebar; chatLabel.TextColor3 = colors.text_muted end end end end
local function updateWelcomeVisibility() if not activeChatId or not chats[activeChatId] then welcomeText.Visible = true; return end; local chat = chats[activeChatId]; local empty = #chat.messages == 0; local busy = activeLoadingIndicator or chat.streamingLabel; welcomeText.Visible = empty and not busy end
-- Обновление отображения синей точки для конкретного чата
local function updateChatReadyIndicator(chatId)
	local chat = chats[chatId]
	if not chat then return end
	local button = chat.sidebarButton
	if not button or not button.Parent then return end
	local dot = button:FindFirstChild("ReadyDot")
	if not dot then
		dot = Create("Frame", {
			Name = "ReadyDot",
			Parent = button,
			Size = UDim2.new(0, 8, 0, 8),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			BackgroundColor3 = colors.cyan,
			Visible = false,
			BorderSizePixel = 0,
		})
		Create("UICorner", { Parent = dot, CornerRadius = UDim.new(1, 0) })
	end
	dot.Visible = chat.hasPendingReady == true
end
function displayChat(chatIdentifier) 
	if not chats[chatIdentifier] then 
		warn("WARN: Attempted to display a non-existent chat: ", chatIdentifier)
		-- Optionally, you could try to create a new chat or switch to an existing one
		-- For now, let's just return to prevent errors.
		createNewChat() -- Or display some default empty state
		return 
	end

	if activeLoadingIndicator then activeLoadingIndicator.stop = true; activeLoadingIndicator.ui:Destroy(); activeLoadingIndicator = nil end; for _,child in ipairs(messageContainer:GetChildren()) do if child:IsA("Frame") and child.Name:find("RowFrame") then child:Destroy() end end; if activeChatId and chats[activeChatId] then chats[activeChatId].streamingLabel = nil end; activeChatId = chatIdentifier; local chat = chats[chatIdentifier];
	-- Сбрасываем метку готовности при открытии чата
	if chat.hasPendingReady then chat.hasPendingReady = false; updateChatReadyIndicator(chat.id) end
	local title = chat.title or (chat.messages[1] and chat.messages[1].text) or "Новый чат"; topBarChatTitle.Text = truncateText(title, MAX_TITLE_LENGTH); for _,messageEntry in ipairs(chat.messages) do if messageEntry.type == "Player" then createPlayerMessage(messageEntry.text) elseif messageEntry.type == "AI" then createAiMessage(messageEntry.text) elseif messageEntry.type == "AI_Canvas" then createCanvasSummaryButton(messageEntry) end end; updateWelcomeVisibility(); updateAndScroll(); updateChatButtons(); updateQuickMessageButtonVisibility() end
function createNewChat() local newId = "chat"..nextChatId; nextChatId += 1; chats[newId] = {id=newId, messages={}, isSaved=false, timestamp=os.time(), sidebarButton=nil, streamingLabel=nil}; displayChat(newId) end
local currentChatIdToDelete = nil
local isClearAllChats = false

function createChatHistoryButton(chatData) local rawTitle = chatData.title or (chatData.messages[1] and chatData.messages[1].text) or "Новый чат"; local title = truncateChatButtonTitle(cleanTitle(rawTitle), CHAT_BUTTON_TITLE_LIMIT); if chatData.sidebarButton and chatData.sidebarButton.Parent then chatData.sidebarButton.Label.Text = title; updateChatReadyIndicator(chatData.id); return end; local chatButton = chatButtonTemplate:Clone(); chatButton.Name = chatData.id; chatButton.Parent = chatHistoryContainer; chatButton.Label.Text = title; chatData.sidebarButton = chatButton; -- Обновим индикатор при создании
	local dot = chatButton:FindFirstChild("ReadyDot"); if dot then dot.Visible = chatData.hasPendingReady == true end; chatButton.MouseButton1Click:Connect(function() displayChat(chatData.id) end); chatButton.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton2 then MenuManager.create(chatButton, "deleteChatMenu", screenGui, "dark", ConfirmationDialogModule, deleteChatEvent, chatData.id) end end); chatButton.MouseEnter:Connect(function() if chatData.id ~= activeChatId then TweenService:Create(chatButton, TweenInfo.new(0.1), {BackgroundColor3 = colors.sidebar_button_darker}):Play() end end); chatButton.MouseLeave:Connect(function() if chatData.id ~= activeChatId then TweenService:Create(chatButton, TweenInfo.new(0.1), {BackgroundColor3 = colors.sidebar}):Play() end end); updateChatButtons() end
function sendMessage() 
	if isAiGenerating then return end -- Prevent sending if AI is generating
	local now = os.time()
	if now < nextLocalSendAllowedAt then
		createSystemMessage("Слишком часто. Подождите немного перед отправкой.")
		updateAndScroll()
		return
	end
	local text = cleanMessageText(inputBox.Text); -- Clean the text
	if not hasNonWhitespace(text) then return end;
	local canvasMode = isCanvasModeActive;
	nextLocalSendAllowedAt = now + LOCAL_MIN_INTERVAL
	isAiGenerating = true; -- Set flag to true BEFORE clearing text
	inputBox.Text = ""; 
	updateHints() -- Explicitly update button state immediately
	sendButton.TextColor3 = colors.text_muted; 
	local chat = chats[activeChatId]; 
	if not chat then createNewChat() chat = chats[activeChatId] end;
	if not chat.isSaved then chat.isSaved = true; chat.title = truncateText(cleanTitle(text), MAX_TITLE_LENGTH); topBarChatTitle.Text = chat.title; createChatHistoryButton(chat) end;
	table.insert(chat.messages, {type="Player", text=text}); 
	createPlayerMessage(text); 
	updateAndScroll(); 
	if activeLoadingIndicator then activeLoadingIndicator.stop = true; activeLoadingIndicator.ui:Destroy() end;
	local tempLoadingIndicator = createLoadingIndicator(); 
	activeLoadingIndicator = {ui=tempLoadingIndicator.row, rotatingPart=tempLoadingIndicator.rotatingPart, stop=false}; 
	task.spawn(spinElement, activeLoadingIndicator); 
	updateAndScroll(); 
	updateWelcomeVisibility(); 
	chat.timestamp = os.time(); 
	updateChatMetadataEvent:FireServer(activeChatId, {timestamp = chat.timestamp}); 
	sendMessageEvent:FireServer(activeChatId, text, canvasMode); 
	updateQuickMessageButtonVisibility() 
	updateCanvasButtonVisual() -- Add this line
end
function onReceiveMessage(receivedChatId, messageData)
	-- Гарантируем структуру чата
	if not chats[receivedChatId] then
		chats[receivedChatId] = { id = receivedChatId, messages = {}, isSaved = true, timestamp = os.time(), sidebarButton = nil, streamingLabel = nil }
		createChatHistoryButton(chats[receivedChatId])
	end

	local chat = chats[receivedChatId]
	local isActive = (receivedChatId == activeChatId)

	if isActive then
		-- Поведение для активного чата (оригинальная логика)
		if messageData.isSystem then
			-- Останавливаем возможный индикатор загрузки и сбрасываем генерацию
			if activeLoadingIndicator then
				activeLoadingIndicator.stop = true
				if activeLoadingIndicator.ui.Parent then
					activeLoadingIndicator.ui:Destroy()
				end
				activeLoadingIndicator = nil
			end
			isAiGenerating = false
			updateHints()
			createSystemMessage(messageData.text or "Системное сообщение")
			updateAndScroll()
			return
		end
		if activeLoadingIndicator then
			activeLoadingIndicator.stop = true
			if activeLoadingIndicator.ui.Parent then
				activeLoadingIndicator.ui:Destroy()
			end
			activeLoadingIndicator = nil
		end

		if messageData.isCanvas then
			table.insert(chat.messages, {type="AI_Canvas", fullText=messageData.fullText})
			createCanvasSummaryButton(messageData)
		else
			if not chat.streamingLabel then
				chat.streamingLabel = createAiMessage(messageData.chunk)
				updateWelcomeVisibility()
			else
				chat.streamingLabel.Text ..= messageData.chunk
			end
			if messageData.isFinal then
				table.insert(chat.messages, {type="AI", text=chat.streamingLabel.Text})
				chat.streamingLabel = nil
				isAiGenerating = false
				updateHints()
			end
		end
		updateAndScroll()
		updateQuickMessageButtonVisibility()
	else
		-- Поведение для НЕактивного чата: аккумулируем и ставим метку, когда ответ готов
		if messageData.isSystem then
			-- Добавим системное сообщение в историю чата без синей точки
			table.insert(chat.messages, {type="SYSTEM", text=messageData.text or "Системное сообщение"})
			-- не выставляем hasPendingReady
			return
		end
		if messageData.isCanvas then
			table.insert(chat.messages, {type="AI_Canvas", fullText=messageData.fullText})
			chat.hasPendingReady = true
			updateChatReadyIndicator(receivedChatId)
		else
			if messageData.chunk and type(messageData.chunk) == "string" then
				chat.pendingStreamText = (chat.pendingStreamText or "") .. messageData.chunk
			end
			if messageData.isFinal then
				table.insert(chat.messages, {type="AI", text=chat.pendingStreamText or ""})
				chat.pendingStreamText = nil
				chat.hasPendingReady = true
				updateChatReadyIndicator(receivedChatId)
			end
		end
	end
end
receiveMessageEvent.OnClientEvent:Connect(onReceiveMessage)

local function stopAiGeneration()
	if activeLoadingIndicator then
		activeLoadingIndicator.stop = true
		if activeLoadingIndicator.ui.Parent then
			activeLoadingIndicator.ui:Destroy()
		end
		activeLoadingIndicator = nil
	end
	isAiGenerating = false
	updateHints()
	-- Fire event to server to cancel ongoing generation
	if activeChatId then
		cancelGenerationEvent:FireServer(activeChatId)
	end
end

clearAllChatHistoryEvent.OnClientEvent:Connect(function()
	print("DEBUG: ClearAllChatHistory event received in ChatUI.lua")
	chats = {}
	for _,child in ipairs(chatHistoryContainer:GetChildren()) do
		if child:IsA("TextButton") then
			print("DEBUG: Destroying chat button: ", child.Name)
			child:Destroy()
		end
	end

	-- Explicitly clear message container content
	for _, child in ipairs(messageContainer:GetChildren()) do
		if child:IsA("Frame") and child.Name:find("RowFrame") then
			child:Destroy()
		end
	end

	activeChatId = nil -- Reset active chat
	topBarChatTitle.Text = "Новый чат" -- Reset title
	welcomeText.Visible = true -- Show welcome text

	createNewChat() -- Create a brand new chat
	-- updateWelcomeVisibility() -- This is handled by createNewChat -> displayChat
	updateQuickMessageButtonVisibility()
end)
deleteChatEvent.OnClientEvent:Connect(function(chatIdToDelete)
	print("DEBUG: Client received deleteChatEvent for chat id: ", chatIdToDelete)

	-- Always attempt to destroy the sidebar button if it exists in UI
	local sidebarButton = chatHistoryContainer:FindFirstChild(chatIdToDelete)
	if sidebarButton and sidebarButton:IsA("TextButton") then
		print("DEBUG: Destroying sidebarButton for chat: ", chatIdToDelete)
		sidebarButton:Destroy()
	else
		warn("WARN: sidebarButton not found in UI for chat: ", chatIdToDelete)
	end

	if chats[chatIdToDelete] then
		local wasActive = (activeChatId == chatIdToDelete);
		chats[chatIdToDelete] = nil;
		if wasActive then
			activeChatId = nil;
			local anyRemainingChatId = next(chats);
			if anyRemainingChatId then
				displayChat(anyRemainingChatId)
			else
				createNewChat()
			end
		end
	else
		-- If chat was already nil in 'chats' table, but button was still there (handled above)
		warn("WARN: Chat object was already nil for id: ", chatIdToDelete)
	end
	updateQuickMessageButtonVisibility()
end)

--- // ОБРАБОТЧИКИ СОБЫТИЙ И ИНИЦИАЛИЗАЦИЯ -----------------

local function setSidebarVisibilityByState()
	if isSidebarExpanded then
		chatHistoryContainer.Visible = true;
		newChatLabel.Text = "Новый чат";
	else
		chatHistoryContainer.Visible = false; newChatButton.Visible = true;
	end
end

local function loadAvatar()
	local ok, id = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end)
	if ok and id then profileIcon.Image = id end
end

-- Re-added loadUserInfo function
local function loadUserInfo()
	local ok, userInfo = pcall(function() 
		return getUserInfoFunction:InvokeServer() 
	end)

	if ok and userInfo then
		planPill.Text = userInfo.plan:upper()
		planPill.TextColor3 = userInfo.plan:lower() == "pro" and colors.pro_plan_color or colors.free_plan_color
	else
		warn("Не удалось получить информацию о пользователе. Установлен план по умолчанию.")
		planPill.Text = "—"
		planPill.TextColor3 = colors.muted -- Дефолтный цвет для неизвестных планов
	end
end

local function loadHistory()
	local success, chatHistoryData = pcall(function() return getChatHistoryFunction:InvokeServer() end)
	if not success or not chatHistoryData then createNewChat(); updateWelcomeVisibility(); return end
	chats = chatHistoryData
	local latestChatIdentifier, latestTime = nil, 0
	for chatIdentifier,chat in pairs(chats) do
		chat.streamingLabel = nil
		if type(chat.messages) ~= "table" then chat.messages = {} end
		createChatHistoryButton(chat)
		if chat.timestamp and chat.timestamp > latestTime then
			latestTime, latestChatIdentifier = chat.timestamp, chatIdentifier
		end
		local num = tonumber(chatIdentifier:match("%d+"))
		if num and num >= nextChatId then nextChatId = num + 1 end
	end
	if latestChatIdentifier then displayChat(latestChatIdentifier) else createNewChat() end
	updateWelcomeVisibility()
end

local function setupInputInteractions()
	UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() == inputBox then
			if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
				if isAiGenerating then -- If AI is generating, Enter should stop it
					stopAiGeneration()
				else
					local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
					if not shift then sendMessage() end
				end
			end
		end
	end)
	sendButton.MouseButton1Click:Connect(function()
		if isAiGenerating then
			stopAiGeneration()
		else
			sendMessage()
		end
	end)

	-- Переключение режима Canvas с визуальной подсветкой
	canvasButton.MouseButton1Click:Connect(function()
		isCanvasModeActive = not isCanvasModeActive
		updateCanvasButtonVisual()
	end)
	canvasButton.MouseEnter:Connect(function()
		if not isCanvasModeActive then
			TweenService:Create(canvasButton, TweenInfo.new(0.1), {BackgroundColor3 = colors.sidebar_button_darker}):Play()
		end
	end)
	canvasButton.MouseLeave:Connect(function()
		if not isCanvasModeActive then
			TweenService:Create(canvasButton, TweenInfo.new(0.1), {BackgroundColor3 = colors.input}):Play()
		end
	end)

	-- Hover для плавающей кнопки
	expandFloatingButton.MouseEnter:Connect(function()
		TweenService:Create(expandFloatingButton, TweenInfo.new(0.1), {BackgroundColor3 = colors.sidebar_button_darker}):Play()
	end)
	expandFloatingButton.MouseLeave:Connect(function()
		TweenService:Create(expandFloatingButton, TweenInfo.new(0.1), {BackgroundColor3 = colors.input}):Play()
	end)

	-- Плавающая кнопка Развернуть/Свернуть
	expandFloatingButton.MouseButton1Click:Connect(function()
		isInputExpandedByUser = not isInputExpandedByUser
		updateInputHeight()
	end)
	inputBox:GetPropertyChangedSignal("Text"):Connect(function()
		updateInputHeight(); updateHints()
	end)
	inputAreaContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		scrollSpacer.Size = UDim2.new(1,0,0,inputAreaContainer.AbsoluteSize.Y + 40); updateAndScroll()
	end)
end

local function setupSidebarTriggers()
	expandTrigger = Create("TextButton",{ Name="ExpandTrigger", Parent=sidebar, Text="", BackgroundTransparency=1, Size=UDim2.new(1, 8, 1, 0), Position=UDim2.new(-0.06, 0, 0, 0), ZIndex=11, Visible=true })
	expandTrigger.MouseButton1Click:Connect(expandSidebar)
	newChatButton.MouseButton1Click:Connect(function()
		if isSidebarExpanded then
			createNewChat()
		else
			expandSidebar(); task.delay(0.22, function() createNewChat() end)
		end
	end)
end

-- ИЗМЕНЕНИЕ: Логика для кнопки профиля
profileIcon.MouseEnter:Connect(function()
	TweenService:Create(profileIcon, TweenInfo.new(0.12), {BackgroundColor3 = colors.sidebar_button_darker}):Play()
end)
profileIcon.MouseLeave:Connect(function()
	TweenService:Create(profileIcon, TweenInfo.new(0.12), {BackgroundColor3 = colors.sidebar}):Play()
end)

profileIcon.MouseButton1Click:Connect(function()
	if MenuManager.isMenuOpen and MenuManager.isMenuOpen() then
		MenuManager.close()
		return
	end

	-- Создаем выпадающее меню с помощью вашего менеджера
	MenuManager.create(profileIcon, "chatProfileMenu", screenGui, "dark", playerGui, infoPageApi, player.Name) -- Передаем playerGui и player.Name
end)

-- Инициализация
loadHistory()
updateInputHeight()
updateHints()
setupInputInteractions()
setupSidebarTriggers()
setSidebarVisibilityByState()

-- Запускаем загрузку аватара и информации о пользователе в отдельных потоках
task.spawn(loadAvatar)
task.spawn(loadUserInfo) -- Re-added call to loadUserInfo

print("✅ ChatGui: Добавлено выпадающее меню для профиля.")
