-- СЕРВИСЫ
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- REMOTES
local RF_CheckAuth = ReplicatedStorage:WaitForChild("CheckAuthStatus")
local RF_SetAuth = ReplicatedStorage:WaitForChild("SetAuthStatus")
local RF_GetUserInfo = ReplicatedStorage:WaitForChild("GetUserInfo")
local RE_ResetAuthData = ReplicatedStorage:WaitForChild("ResetAuthData")

local ConfirmationDialogModule = require(StarterGui:WaitForChild("ConfirmationDialogModule"))
ConfirmationDialogModule.init()

-- КОНФИГ
local CLIENT_VERSION = "1.0.2"
local colors = {
	background = Color3.fromRGB(20, 21, 23),
	surface = Color3.fromRGB(28, 30, 32),
	input = Color3.fromRGB(25, 26, 28),
	stroke = Color3.fromRGB(70, 74, 80),
	soft_stroke = Color3.fromRGB(58, 60, 64),
	text = Color3.fromRGB(235, 238, 240),
	muted = Color3.fromRGB(160, 164, 170),
	accent = Color3.fromRGB(0, 69, 198), -- Updated to the new blue color
	accent_soft = Color3.fromRGB(56, 98, 220),
	buttonText = Color3.fromRGB(255, 255, 255),
	overlay = Color3.fromRGB(0, 0, 0),
	itemHover = Color3.fromRGB(40, 42, 44),
	itemSelected = Color3.fromRGB(50, 52, 56),
	divider = Color3.fromRGB(50, 52, 56),
	free_plan_color = Color3.fromRGB(34, 197, 94),
	pro_plan_color = Color3.fromRGB(147, 51, 234),
	plan_background_color = Color3.fromRGB(44, 47, 51),
	active_blue_stroke = Color3.fromRGB(0, 100, 220) -- Slightly lighter blue for active/accent elements
}

-- Helper for UI element creation
local function Create(className, props)
	local inst = Instance.new(className)
	for prop, value in pairs(props) do inst[prop] = value end
	return inst
end

-- Find MenuManager
local function findMenuManager()
	for _, container in ipairs(playerGui:GetChildren()) do
		if container:IsA("ScreenGui") then
			local mm = container:FindFirstChild("MenuManager")
			if mm and mm:IsA("ModuleScript") then
				return mm
			end
		end
	end

	for _, container in ipairs(StarterGui:GetChildren()) do
		if container:IsA("ScreenGui") then
			local mm = container:FindFirstChild("MenuManager")
			if mm and mm:IsA("ModuleScript") then
				return mm
			end
		end
	end

	local directFind = StarterGui:FindFirstChild("MenuManager")
	if directFind and directFind:IsA("ModuleScript") then
		return directFind
	end

	return nil
end

local MenuManagerModule = findMenuManager()
local MenuManager = nil
if MenuManagerModule then
	local ok, mod = pcall(require, MenuManagerModule)
	if ok then
		MenuManager = mod
	else
		warn("Ошибка require(MenuManager): ", mod)
	end
else
	warn("MenuManager не найден. Поместите ModuleScript 'MenuManager' в любой ScreenGui внутри StarterGui.")
end

-- UI Setup
local screenGui = script.Parent
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false

-- Background
local background = Create("Frame", {
	Name = "Background",
	Parent = screenGui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = colors.surface
})

-- Top Bar
local topBar = Create("Frame", {
	Name = "TopBar",
	Parent = screenGui,
	Size = UDim2.new(1, 0, 0, 72),
	BackgroundTransparency = 0,
	BackgroundColor3 = colors.surface,
	BorderSizePixel = 0,
	ZIndex = 20
})
Create("UIStroke", {
	Parent = topBar,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Color = colors.stroke,
	Thickness = 1.5
})
Create("UIPadding", {
	Parent = topBar,
	PaddingLeft = UDim.new(0, 20),
	PaddingRight = UDim.new(0, 20)
})

local leftGroup = Create("Frame", {
	Name = "TopBarLeftGroup",
	Parent = topBar,
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 20, 0, 6),
	Size = UDim2.new(0, 420, 1, -12),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 21
})
Create("UIListLayout", {
	Parent = leftGroup,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 10)
})
local appLogoText = Create("TextLabel", {
	Name = "AppLogoText",
	Parent = leftGroup,
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	Text = '<font color="rgb(235,238,240)"><b>Ro</b></font><font color="rgb(0,100,220)"><b>Gemini</b></font>', -- Changed to new RGB
	RichText = true,
	Font = Enum.Font.SourceSansBold,
	TextSize = 20,
	TextColor3 = colors.text,
	TextXAlignment = Enum.TextXAlignment.Left
})

local rightGroup = Create("Frame", {
	Name = "TopBarRightGroup",
	Parent = topBar,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 6),
	Size = UDim2.new(0, 180, 1, -12),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 21
})

local infoOverlayApi = nil

local profileInfoContainer = Create("Frame", {
	Name = "ProfileInfoContainer",
	Parent = rightGroup,
	Size = UDim2.new(0, 180, 1, 0),
	AutomaticSize = Enum.AutomaticSize.None,
	BackgroundTransparency = 1,
	Position = UDim2.new(1, 0, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	LayoutOrder = 1
})

local userInfoFrame = Create("Frame", {
	Name = "UserInfoFrame",
	Parent = profileInfoContainer,
	Size = UDim2.new(0, 120, 1, 0),
	AutomaticSize = Enum.AutomaticSize.None,
	BackgroundTransparency = 1,
	Position = UDim2.new(1, -70, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	ZIndex = 21,
})
Create("UIListLayout", {
	Parent = userInfoFrame,
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 5)
})

local userNameLabel = Create("TextLabel", {
	Name = "UserNameLabel",
	Parent = userInfoFrame,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 20),
	AutomaticSize = Enum.AutomaticSize.None,
	Text = player.Name,
	Font = Enum.Font.SourceSansSemibold,
	TextSize = 20,
	TextColor3 = colors.text,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 21,
})

local planLabel = Create("TextLabel", {
	Name = "PlanLabel",
	Parent = userInfoFrame,
	BackgroundTransparency = 0,
	BackgroundColor3 = colors.plan_background_color,
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.new(0, 0, 0, 20),
	Text = "—",
	Font = Enum.Font.SourceSansBold,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = colors.muted,
	ZIndex = 21,
})
Create("UICorner", { Parent = planLabel, CornerRadius = UDim.new(1, 0) })
Create("UIPadding", { Parent = planLabel, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })

local avatarButton = Create("TextButton", {
	Name = "AvatarButton",
	Parent = profileInfoContainer,
	Size = UDim2.new(0, 50, 0, 50),
	BackgroundColor3 = colors.surface,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 21,
	Position = UDim2.new(1, -10, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
})
Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avatarButton })
Create("UIStroke", {Parent=avatarButton, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=Color3.fromRGB(43, 46, 50), Thickness=1.5})
local avatarImage = Create("ImageLabel", {
	Name = "AvatarImage",
	Parent = avatarButton,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
	ScaleType = Enum.ScaleType.Crop
})
Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avatarImage })
avatarImage.ZIndex = avatarButton.ZIndex + 1

-- Content containers for different UI states
local mainContainer = Create("Frame", {
	Name = "MainContainer",
	Parent = background,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0.9, 0),
	BackgroundTransparency = 1
})

local authContainer = Create("Frame", {
	Name = "AuthContainer",
	Parent = mainContainer,
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false
})
Create("UIPadding", { Parent = authContainer, PaddingTop = UDim.new(0, 36), PaddingBottom = UDim.new(0, 36), PaddingLeft = UDim.new(0, 36), PaddingRight = UDim.new(0, 36) })

local contentRow = Create("Frame", {
	Name = "ContentRow",
	Parent = authContainer,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1
})

local leftCol = Create("Frame", {
	Name = "LeftCol",
	Parent = contentRow,
	Size = UDim2.new(0.5, 0, 1, 0),
	Position = UDim2.new(0, 0, 0, 0),
	AnchorPoint = Vector2.new(0, 0),
	BackgroundTransparency = 1
})
local logoImage = Create("ImageLabel", {
	Name = "LogoImage",
	Parent = leftCol,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.65, 0.5),
	Size = UDim2.new(0, 320, 0, 320),
	BackgroundTransparency = 1,
	Image = "rbxassetid://76215324363391",
	ImageColor3 = colors.active_blue_stroke -- Changed to active_blue_stroke
})

local meetTitle = Create("TextLabel", {
	Name = "MeetTitle",
	Parent = leftCol,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 120),
	Position = UDim2.new(0.5, 0, 0.2, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Text = '<font color="rgb(235,238,240)"><b>Ro</b></font><font color="rgb(0,100,220)"><b>Gemini</b></font>', -- Changed to new RGB
	RichText = true,
	Font = Enum.Font.SourceSansBold,
	TextColor3 = colors.text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 80
})

local subTitle = Create("TextLabel", {
	Name = "SubTitle",
	Parent = leftCol,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 90),
	Position = UDim2.new(0.5, 0, 0.4, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Text = "Твой лучший собеседник и помощник в мире Roblox. Привет! Я твой новый помощник в Roblox, созданный для того, чтобы сделать твой опыт игры более увлекательным и продуктивным. Я могу помочь тебе с широким кругом задач, от поиска информации до автоматизации игровых процессов. Я постоянно учусь и развиваюсь, чтобы быть еще полезнее. Начни общаться со мной прямо сейчас и открой для себя новые возможности в мире Roblox!",
	Font = Enum.Font.SourceSans,
	TextColor3 = colors.muted,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 20
})

local buttonsRow = Create("Frame", {
	Name = "ButtonsRow",
	Parent = leftCol,
	Size = UDim2.new(1, 0, 0, 70),
	Position = UDim2.new(0.5, 0, 0.7, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1
})
Create("UIListLayout", {
	Parent = buttonsRow,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 20)
})

local authActionButton = Create("TextButton", {
	Name = "AuthActionButton",
	Parent = buttonsRow,
	Size = UDim2.new(0, 280, 0, 60),
	BackgroundColor3 = colors.accent,
	Font = Enum.Font.SourceSansBold,
	TextColor3 = colors.buttonText,
	TextSize = 22,
	Text = "Начать",
	AutoButtonColor = false
})
Create("UICorner", { CornerRadius = UDim.new(0, 30), Parent = authActionButton })

local moreButton = Create("TextButton", {
	Name = "MoreButton",
	Parent = buttonsRow,
	Size = UDim2.new(0, 220, 0, 60),
	BackgroundTransparency = 1,
	Font = Enum.Font.SourceSansSemibold,
	TextColor3 = colors.accent,
	TextSize = 18,
	Text = "Узнать больше",
	AutoButtonColor = false
})
Create("UICorner", { CornerRadius = UDim.new(0, 30), Parent = moreButton })

-- Инициализация InfoPage ПОСЛЕ создания moreButton, чтобы избежать ошибки обращения к несуществующей переменной
do
	local modScript = StarterGui:WaitForChild("InfoPage")
	if modScript then
		local ok, mod = pcall(require, modScript)
		if ok and mod and type(mod.init) == "function" then
			infoOverlayApi = mod.init(screenGui, moreButton) -- Передаем moreButton
		else
			warn("Не удалось инициализировать InfoPage из модуля")
			infoOverlayApi = { open = function() end, close = function() end, setTab = function() end, showAnnouncements = function() end }
		end
	else
		warn("InfoPage модуль не найден.")
		infoOverlayApi = { open = function() end, close = function() end, setTab = function() end, showAnnouncements = function() end }
	end
end

local rightCol = Create("Frame", {
	Name = "RightCol",
	Parent = contentRow,
	Size = UDim2.new(0.5, 0, 1, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	AnchorPoint = Vector2.new(0, 0),
	BackgroundTransparency = 1
})

logoImage.Parent = rightCol

local welcomeContainer = Create("Frame", {
	Name = "WelcomeContainer",
	Parent = mainContainer,
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.new(0, 0, 0, 0),
	BackgroundTransparency = 1,
	Visible = false
})

local authDetailsContainer = Create("Frame", {
	Name = "AuthDetailsContainer",
	Parent = mainContainer,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false
})
Create("UIPadding", {
	Parent = authDetailsContainer,
	PaddingTop = UDim.new(0, 50),
	PaddingBottom = UDim.new(0, 50),
	PaddingLeft = UDim.new(0, 50),
	PaddingRight = UDim.new(0, 50)
})

local authDetailsTitle = Create("TextLabel", {
	Name = "AuthDetailsTitle",
	Parent = authDetailsContainer,
	Size = UDim2.new(1, 0, 0, 60),
	Position = UDim2.new(0.5, 0, 0.15, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Text = "Подтвердите Авторизацию",
	Font = Enum.Font.SourceSansBold,
	TextSize = 40,
	TextColor3 = colors.text,
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Center
})

local authDetailsText = Create("TextLabel", {
	Name = "AuthDetailsText",
	Parent = authDetailsContainer,
	Size = UDim2.new(1, -100, 0, 180),
	Position = UDim2.new(0.5, 0, 0.4, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Text = "Мы будем использовать ваш ID аккаунта для хранения вашей подписки, покупок и данных, таких как сообщения, чаты, настройки и память. Это необходимо для обеспечения полноценного функционала RoGemini. Ваши личные данные не будут опубликованы и будут храниться в безопасности.",
	Font = Enum.Font.SourceSans,
	TextSize = 20,
	TextColor3 = colors.muted,
	BackgroundTransparency = 1,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center
})

local authDetailsButtonsRow = Create("Frame", {
	Name = "AuthDetailsButtonsRow",
	Parent = authDetailsContainer,
	Size = UDim2.new(1, 0, 0, 70),
	Position = UDim2.new(0.5, 0, 0.7, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1
})

local authorizeButton = Create("TextButton", {
	Name = "AuthorizeButton",
	Parent = authDetailsButtonsRow,
	Size = UDim2.new(0, 240, 0, 60),
	Position = UDim2.new(0.5, -120, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = colors.accent,
	Text = "Авторизироваться",
	Font = Enum.Font.SourceSansBold,
	TextColor3 = colors.buttonText,
	TextSize = 22,
	AutoButtonColor = false
})
Create("UICorner", { CornerRadius = UDim.new(0, 30), Parent = authorizeButton })

local termsButton = Create("TextButton", {
	Name = "TermsButton",
	Parent = authDetailsButtonsRow,
	Size = UDim2.new(0, 200, 0, 60),
	Position = UDim2.new(0.5, 120, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Font = Enum.Font.SourceSansSemibold,
	TextColor3 = colors.accent,
	TextSize = 18,
	Text = "О условиях",
	AutoButtonColor = false
})
Create("UICorner", { CornerRadius = UDim.new(0, 30), Parent = termsButton })
Create("UIStroke", { Parent = termsButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.active_blue_stroke, Thickness = 1.5 }) -- Changed to active_blue_stroke

local logoRoGeminiText = Create("TextLabel", {
	Name = "LogoRoGeminiText",
	Parent = welcomeContainer,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 100),
	Position = UDim2.new(0.5, 0, 0.3, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Text = '<font color="rgb(235,238,240)"><b>Ro</b></font><font color="rgb(0,100,220)"><b>Gemini</b></font><font color="rgb(235,238,240)"><b> рад тебя видеть!</b></font>', -- Changed to new RGB
	RichText = true,
	Font = Enum.Font.SourceSansBold,
	TextSize = 72,
	TextColor3 = colors.text,
	TextXAlignment = Enum.TextXAlignment.Center
})

local textWelcome = Create("TextLabel", {
	Name = "TextWelcome",
	Parent = welcomeContainer,
	Text = "С возвращением, " .. player.Name .. "!",
	Font = Enum.Font.SourceSans,
	TextColor3 = colors.muted,
	TextSize = 36,
	TextWrapped = true,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 60),
	Position = UDim2.new(0.5, 0, 0.45, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	TextXAlignment = Enum.TextXAlignment.Center
})

local actionButton = Create("TextButton", {
	Name = "ActionButton",
	Parent = welcomeContainer,
	Size = UDim2.new(0, 300, 0, 70),
	Position = UDim2.new(0.5, 0, 0.7, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = colors.accent,
	Font = Enum.Font.SourceSansBold,
	TextColor3 = colors.buttonText,
	TextSize = 24,
	Text = "Продолжить",
	AutoButtonColor = false
})
Create("UICorner", { CornerRadius = UDim.new(0, 35), Parent = actionButton })

local tweenInfo = TweenInfo.new(0.0, Enum.EasingStyle.Linear)

local function setPlanLabel(plan)
	if plan and plan ~= "none" then
		planLabel.Text = plan:upper()
		if plan:lower() == "pro" then
			planLabel.TextColor3 = colors.pro_plan_color
		elseif plan:lower() == "free" then
			planLabel.TextColor3 = Color3.fromRGB(190, 195, 200) -- Цвет для Free плана, если отличается от standard_plan_color
		else
			planLabel.TextColor3 = colors.muted -- Дефолтный цвет для неизвестных планов
		end
	else
		planLabel.Text = "—"
		planLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	end
end

local function fadeOutAndStart()
	local chatGui = playerGui:FindFirstChild("ChatGui")
	if chatGui then chatGui.Enabled = true else warn("ChatGui не найден!") end

	local backgroundTween = TweenService:Create(background, tweenInfo, {BackgroundTransparency = 1})
	for _, child in pairs(background:GetDescendants()) do
		if child:IsA("GuiObject") then
			local goal = {}
			if child:IsA("Frame") then goal.BackgroundTransparency = 1 end
			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then goal.TextTransparency = 1 end
			if child:IsA("UIStroke") then goal.Transparency = 1 end
			if next(goal) then TweenService:Create(child, tweenInfo, goal):Play() end
		end
	end
	backgroundTween:Play()
	backgroundTween.Completed:Wait()
	screenGui.Enabled = false
end

local function setupAuthUI()
	authContainer.Visible = true
	welcomeContainer.Visible = false
	topBar.Visible = false
end

local function setupWelcomeUI()
	welcomeContainer.Visible = true
	authContainer.Visible = false
	textWelcome.Text = "Добро пожаловать обратно, " .. player.Name .. "!"
	for _, el in ipairs({logoRoGeminiText, textWelcome, actionButton}) do
		if el:IsA("TextLabel") then el.TextTransparency = 1 end
		if el:IsA("TextButton") then el.BackgroundTransparency = 1; el.TextTransparency = 1 end
	end
	logoRoGeminiText.TextTransparency = 0
	textWelcome.TextTransparency = 0
	actionButton.BackgroundTransparency = 0
	actionButton.TextTransparency = 0
	topBar.Visible = true
	local btn = screenGui:FindFirstChild("TopBar"):FindFirstChild("TopBarRightGroup"):FindFirstChild("AboutButton")
	if btn then btn.Visible = true end
end

local function openAvatarMenu()
	if not MenuManager then
		warn("MenuManager не найден — фолбек: прямой сброс")
		ConfirmationDialogModule.showConfirmation("resetAccountConfirmation", RE_ResetAuthData, player, setPlanLabel, setupAuthUI)
		return
	end

	if MenuManager.isMenuOpen and MenuManager.isMenuOpen() then
		MenuManager.close()
		return
	end

	MenuManager.create(avatarButton, "profileMenu", screenGui, "dark", playerGui, infoOverlayApi, RE_ResetAuthData, player, setPlanLabel, setupAuthUI, player.Name)
end

avatarButton.MouseButton1Click:Connect(openAvatarMenu)

authActionButton.MouseButton1Click:Connect(function()
	local ok, result = pcall(function() return RF_SetAuth:InvokeServer(CLIENT_VERSION) end)
	if ok and result == true then
		-- Успешная авторизация, переключаем на приветствие
		setupWelcomeUI()
	else
		warn("Ошибка авторизации: ", result)
		-- Можно добавить всплывающее окно об ошибке
	end
end)

moreButton.MouseButton1Click:Connect(function()
	if infoOverlayApi then
		infoOverlayApi.open()
		infoOverlayApi.setTab("О нас", "RoGemini — помощник и собеседник в Roblox. Цель — дать тебе быстрые ответы, вдохновить идеями и упростить рутину.")
	else
		warn("InfoPage API не инициализирован!")
	end
end)

actionButton.MouseButton1Click:Connect(fadeOutAndStart)

-- Initialization
topBar.Visible = true
rightGroup.Visible = true
setPlanLabel("none")

task.spawn(function()
	local authorized = false
	local ok, result = pcall(function() return RF_CheckAuth:InvokeServer() end)
	if ok and result == true then authorized = true end

	if authorized then
		local infoOk, info = pcall(function() return RF_GetUserInfo:InvokeServer() end)
		if infoOk and info then setPlanLabel(info.plan) else setPlanLabel("free") end
		welcomeContainer.Visible = true
		setupWelcomeUI()
	else
		setupAuthUI()
	end
end)