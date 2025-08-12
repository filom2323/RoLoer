-- InfoPage.lua
-- Модуль создаёт и управляет инфо-окном (О нас / Предоставляем / Безопасность / Сообщить о проблеме)

local InfoPage = {}

local function Create(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do inst[k] = v end
	return inst
end

local colors = {
	background = Color3.fromRGB(18, 19, 21),
	surface = Color3.fromRGB(28, 30, 33),
	softer = Color3.fromRGB(32, 34, 37),
	stroke = Color3.fromRGB(70, 74, 80),
	soft_stroke = Color3.fromRGB(58, 60, 64),
	text = Color3.fromRGB(235, 238, 240),
	muted = Color3.fromRGB(160, 164, 170),
	accent = Color3.fromRGB(0, 100, 220), -- Updated to match new blue
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

-- init(screenGui, aboutButton?) -> api
function InfoPage.init(screenGui, aboutButton)
	-- Overlay и панель
	local infoPageFrame = Create("Frame", {
		Name = "InfoPage",
		Parent = screenGui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.overlay,
		BackgroundTransparency = 0.7, -- Изменено
		ZIndex = 70,
		Visible = false
	})

	local infoPanel = Create("Frame", {
		Name = "InfoPanel",
		Parent = infoPageFrame,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), -- Изменено: на весь экран
		BackgroundColor3 = colors.surface
	})
	Create("UICorner", { Parent = infoPanel, CornerRadius = UDim.new(0, 24) })
	Create("UIStroke", { Parent = infoPanel, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.stroke, Thickness = 1.5 })

	Create("UIPadding", {
		Parent = infoPanel,
		PaddingTop = UDim.new(0, 40),
		PaddingBottom = UDim.new(0, 40),
		PaddingLeft = UDim.new(0, 40),
		PaddingRight = UDim.new(0, 40)
	})

	-- Ряд с сайдбаром и контентом
	local tabsRow = Create("Frame", {
		Name = "TabsRow",
		Parent = infoPanel,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1
	})

	local sidebarWidth = 280
	local contentPadding = 20

	local tabsSidebar = Create("Frame", {
		Name = "TabsSidebar",
		Parent = tabsRow,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, sidebarWidth, 1, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = colors.softer
	})
	Create("UICorner", { Parent = tabsSidebar, CornerRadius = UDim.new(0, 16) })
	Create("UIStroke", { Parent = tabsSidebar, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.stroke, Thickness = 1.5 })
	Create("UIPadding", { Parent = tabsSidebar, PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })

	local buttonHeight = 48
	local buttonPadding = 10
	local yOffset = 12 -- Начальный отступ сверху (равен PaddingTop)

	local function createTabButton(text)
		local btn = Create("TextButton", {
			Parent = tabsSidebar,
			Position = UDim2.new(0, 0, 0, yOffset),
			Size = UDim2.new(1, 0, 0, buttonHeight),
			BackgroundColor3 = colors.softer,
			Text = text,
			Font = Enum.Font.SourceSansSemibold,
			TextSize = 18,
			TextColor3 = colors.muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			AutoButtonColor = false
		})
		Create("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 12) })

		yOffset = yOffset + buttonHeight + buttonPadding

		return btn
	end

	local aboutTabBtn = createTabButton("О нас")
	local offerTabBtn = createTabButton("Что мы предоставляем")
	local safetyTabBtn = createTabButton("Безопасность")
	local reportTabBtn = createTabButton("Сообщить о проблеме")
	-- local announcementsTabBtn = createTabButton("Объявления")

	local tabContent = Create("Frame", {
		Name = "TabContent",
		Parent = tabsRow,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, sidebarWidth + contentPadding, 0, 0),
		Size = UDim2.new(1, -(sidebarWidth + contentPadding), 1, 0),
		BackgroundTransparency = 1
	})

	local titleHeight = 50
	local bodyOffset = 60

	local tabTitle = Create("TextLabel", {
		Name = "TabTitle",
		Parent = tabContent,
		Size = UDim2.new(1, 0, 0, titleHeight),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSansBold,
		TextSize = 30,
		TextColor3 = colors.text,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	local tabBody = Create("TextLabel", {
		Name = "TabBody",
		Parent = tabContent,
		Position = UDim2.new(0, 0, 0, bodyOffset),
		Size = UDim2.new(1, 0, 1, -bodyOffset),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		TextSize = 18,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = colors.muted
	})

	local function setTab(title, body)
		tabTitle.Text = title
		tabBody.Text = body
	end

	aboutTabBtn.MouseButton1Click:Connect(function()
		setTab("О нас", "RoGemini — помощник и собеседник в Roblox. Цель — дать тебе быстрые ответы, вдохновить идеями и упростить рутину.")
		-- 		announcementsFullScreen.Visible = false
		infoPanel.Visible = true
	end)
	offerTabBtn.MouseButton1Click:Connect(function()
		setTab("Что мы предоставляем", "• Чат с искусственным интеллектом\n• История диалогов\n• Режим Canvas для структурированных ответов\n• Ежедневные улучшения интерфейса")
		-- 		announcementsFullScreen.Visible = false
		infoPanel.Visible = true
	end)
	safetyTabBtn.MouseButton1Click:Connect(function()
		setTab("Безопасность", "Мы уважаем приватность. Не публикуем личные данные. Вы можете сбросить аккаунт в любой момент через меню профиля.")
		-- 		announcementsFullScreen.Visible = false
		infoPanel.Visible = true
	end)
	reportTabBtn.MouseButton1Click:Connect(function()
		setTab("Сообщить о проблеме", "Опишите проблему максимально детально. Мы постараемся решить её как можно быстрее.")
		-- 		announcementsFullScreen.Visible = false
		infoPanel.Visible = true
	end)

	-- Объявления (перенесено из StartupGui)
	-- local announcementsShadow = Create("Frame", {
	-- 	Name = "AnnouncementsShadow",
	-- 	Parent = infoOverlay,
	-- 	Size = UDim2.fromScale(1, 1),
	-- 	BackgroundColor3 = colors.overlay,
	-- 	BackgroundTransparency = 0.7,
	-- 	Visible = false,
	-- 	ZIndex = 60
	-- })
	-- local announcementsPopup = Create("Frame", {
	-- 	Name = "AnnouncementsPopup",
	-- 	Parent = infoOverlay,
	-- 	Size = UDim2.new(0, 640, 0, 360),
	-- 	AnchorPoint = Vector2.new(0.5, 0.5),
	-- 	Position = UDim2.new(0.5, 0, 0.5, 0),
	-- 	BackgroundColor3 = colors.surface,
	-- 	BackgroundTransparency = 0,
	-- 	Visible = false,
	-- 	ZIndex = 61
	-- })
	-- Create("UICorner", { CornerRadius = UDim.new(0, 24), Parent = announcementsPopup })
	-- Create("UIStroke", { Parent = announcementsPopup, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.stroke, Thickness = 1.5 })

	-- local backButton = Create("TextButton", {
	-- 	Name = "BackButton",
	-- 	Parent = announcementsPopup,
	-- 	Size = UDim2.new(0, 120, 0, 40),
	-- 	Position = UDim2.new(0, 16, 0, 16),
	-- 	BackgroundColor3 = colors.softer,
	-- 	Text = "Назад",
	-- 	Font = Enum.Font.SourceSansSemibold,
	-- 	TextColor3 = colors.text,
	-- 	TextSize = 18,
	-- 	AutoButtonColor = false
	-- })
	-- Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = backButton })
	-- Create("UIStroke", { Parent = backButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.stroke, Thickness = 1.5 })

	-- local announceTitle = Create("TextLabel", {
	-- 	Name = "AnnounceTitle",
	-- 	Parent = announcementsPopup,
	-- 	Text = "Последнее обновление",
	-- 	Font = Enum.Font.SourceSansBold,
	-- 	TextSize = 30,
	-- 	TextColor3 = colors.accent,
	-- 	BackgroundTransparency = 1,
	-- 	Size = UDim2.new(1, -32, 0, 32),
	-- 	Position = UDim2.new(0, 16, 0, 70),
	-- 	ZIndex = 62,
	-- 	TextXAlignment = Enum.TextXAlignment.Left
	-- })

	-- local announceText = Create("TextLabel", {
	-- 	Name = "AnnounceText",
	-- 	Parent = announcementsPopup,
	-- 	Text = "БЕТА-ВЕРСИЯ\n\nСледите за обновлениями! Проект улучшается каждый день, появляются новые функции и исправляются ошибки.\n\nСпасибо, что тестируете и поддерживаете развитие!",
	-- 	Font = Enum.Font.SourceSans,
	-- 	TextSize = 20,
	-- 	TextColor3 = colors.text,
	-- 	BackgroundTransparency = 1,
	-- 	Size = UDim2.new(1, -32, 1, -120),
	-- 	Position = UDim2.new(0, 16, 0, 110),
	-- 	ZIndex = 62,
	-- 	TextWrapped = true,
	-- 	TextYAlignment = Enum.TextYAlignment.Top
	-- })

	-- Кнопка закрытия (поднята выше)
	local infoClose = Create("TextButton", {
		Name = "InfoClose",
		Parent = infoPanel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 10),
		Size = UDim2.new(0, 100, 0, 40),
		BackgroundColor3 = colors.softer,
		Text = "Закрыть",
		TextColor3 = colors.text,
		Font = Enum.Font.SourceSansSemibold,
		TextSize = 16,
		AutoButtonColor = false
	})
	Create("UICorner", { Parent = infoClose, CornerRadius = UDim.new(0, 20) })
	Create("UIStroke", { Parent = infoClose, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.stroke, Thickness = 1.5 })
	infoClose.MouseButton1Click:Connect(function()
		infoPageFrame.Visible = false
	end)

	local announcementsOpenButton = Create("TextButton", {
		Name = "AnnouncementsOpenButton",
		Parent = infoPanel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -130, 0, 10),
		Size = UDim2.new(0, 120, 0, 40),
		BackgroundColor3 = colors.active_blue_stroke, -- Changed to active_blue_stroke
		Text = "Объявления",
		TextColor3 = colors.buttonText,
		Font = Enum.Font.SourceSansSemibold,
		TextSize = 16,
		AutoButtonColor = false
	})
	Create("UICorner", { Parent = announcementsOpenButton, CornerRadius = UDim.new(0, 20) })

	-- Логика показа/скрытия объявлений
	-- local function showAnnouncements()
	-- 	infoPanel.Visible = false
	-- 	announcementsShadow.Visible = true
	-- 	announcementsPopup.Visible = true
	-- end
	--
	-- local function hideAnnouncements()
	-- 	infoPanel.Visible = true
	-- 	announcementsPopup.Visible = false
	-- 	announcementsShadow.Visible = false
	-- end
	--
	-- announcementsTabBtn.MouseButton1Click:Connect(showAnnouncements)
	-- backButton.MouseButton1Click:Connect(hideAnnouncements)
	-- announcementsShadow.InputBegan:Connect(function(input)
	-- 	if input.UserInputType == Enum.UserInputType.MouseButton1 then hideAnnouncements() end
	-- end)

	-- Объявления (полноэкранный режим)
	local announcementsFullScreen = Create("Frame", {
		Name = "AnnouncementsFullScreen",
		Parent = infoPageFrame,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.surface,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 75 -- Higher ZIndex to be on top of infoPanel
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 24), Parent = announcementsFullScreen })
	Create("UIStroke", { Parent = announcementsFullScreen, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.stroke, Thickness = 1.5 })

	Create("UIPadding", {
		Parent = announcementsFullScreen,
		PaddingTop = UDim.new(0, 40),
		PaddingBottom = UDim.new(0, 40),
		PaddingLeft = UDim.new(0, 40),
		PaddingRight = UDim.new(0, 40)
	})

	local fullScreenTitle = Create("TextLabel", {
		Name = "FullScreenTitle",
		Parent = announcementsFullScreen,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSansBold,
		TextSize = 30,
		TextColor3 = colors.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Объявления"
	})

	local fullScreenBody = Create("TextLabel", {
		Name = "FullScreenBody",
		Parent = announcementsFullScreen,
		Position = UDim2.new(0, 0, 0, 60),
		Size = UDim2.new(1, 0, 1, -120),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		TextSize = 18,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = colors.muted,
		Text = "БЕТА-ВЕРСИЯ\n\nСледите за обновлениями! Проект улучшается каждый день, появляются новые функции и исправляются ошибки.\n\nСпасибо, что тестируете и поддерживаете развитие!"
	})

	local fullScreenCloseButton = Create("TextButton", {
		Name = "FullScreenCloseButton",
		Parent = announcementsFullScreen,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.new(0, 120, 0, 40),
		BackgroundColor3 = colors.softer,
		Text = "Закрыть",
		TextColor3 = colors.text,
		Font = Enum.Font.SourceSansSemibold,
		TextSize = 16,
		AutoButtonColor = false
	})
	Create("UICorner", { Parent = fullScreenCloseButton, CornerRadius = UDim.new(0, 20) })
	Create("UIStroke", { Parent = fullScreenCloseButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.stroke, Thickness = 1.5 })

	local function showAnnouncementsFullScreen()
		infoPanel.Visible = false -- Hide main info overlay
		announcementsFullScreen.Visible = true
	end

	local function hideAnnouncementsFullScreen()
		infoPanel.Visible = true -- Show main info overlay
		announcementsFullScreen.Visible = false
	end

	announcementsOpenButton.MouseButton1Click:Connect(showAnnouncementsFullScreen)
	fullScreenCloseButton.MouseButton1Click:Connect(hideAnnouncementsFullScreen)

	-- Значение по умолчанию
	setTab("О нас", "RoGemini — помощник и собеседник в Roblox. Цель — дать тебе быстрые ответы, вдохновить идеями и упростить рутину.")

	-- Опциональная привязка кнопки из топбара
	if aboutButton then
		aboutButton.MouseButton1Click:Connect(function()
			infoPageFrame.Visible = true
		end)
	end

	local api = {
		overlay = infoPageFrame,
		open = function()
			infoPageFrame.Visible = true
			infoPanel.Visible = true
			announcementsFullScreen.Visible = false
		end,
		close = function() infoPageFrame.Visible = false end,
		setTab = setTab,
		showAnnouncements = showAnnouncementsFullScreen -- Добавляем в API
	}

	return api
end

return InfoPage


