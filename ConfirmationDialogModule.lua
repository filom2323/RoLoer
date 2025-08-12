local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local module = {}

local themePalettes = {
	dark = {
		sidebar = Color3.fromRGB(28, 30, 33),
		text = Color3.fromRGB(235, 238, 240),
		input = Color3.fromRGB(32, 34, 37),
		soft_stroke = Color3.fromRGB(58, 60, 64),
		danger = Color3.fromRGB(231, 76, 60),
		dialogStroke = Color3.fromRGB(58, 60, 64) -- Серая обводка для темной темы
	},
	light = {
		background = Color3.fromRGB(248, 248, 248),
		sidebar = Color3.fromRGB(248, 248, 248), -- Используем background как sidebar для светлой темы
		text = Color3.fromRGB(40, 40, 40),
		input = Color3.fromRGB(235, 235, 240),
		soft_stroke = Color3.fromRGB(220, 220, 228),
		danger = Color3.fromRGB(231, 76, 60), -- Красный цвет оставим тем же
		dialogStroke = Color3.fromRGB(220, 220, 228) -- Белая обводка для светлой темы
	}
}
local currentColors = themePalettes.dark -- Переменная для активной палитры
local predefinedDialogs = {
	deleteChatConfirmation = {
		title = "Удаление чата",
		message = "Вы уверены, что хотите удалить этот чат? Это действие необратимо.",
		confirmButtonText = "Удалить",
		cancelButtonText = "Отмена",
		theme = "dark", -- Добавлено свойство темы
		onConfirm = function(deleteChatEvent, chatId)
			deleteChatEvent:FireServer(chatId)
		end,
		onCancel = function() end -- Пустая функция, если отмена не требует действий
	},
	clearAllChatHistoryConfirmation = {
		title = "Удалить всю историю чата?",
		message = "Вы уверены, что хотите удалить ВСЮ историю чата? Это действие необратимо.",
		confirmButtonText = "Удалить всё",
		cancelButtonText = "Отмена",
		theme = "dark",
		onConfirm = function(clearAllChatHistoryEvent) -- Now correctly receives the event
			if clearAllChatHistoryEvent and clearAllChatHistoryEvent:IsA("RemoteEvent") then
				clearAllChatHistoryEvent:FireServer()
			else
				warn("ERROR: clearAllChatHistoryEvent is not a RemoteEvent or is nil!")
			end
		end,
		onCancel = function() end
	},
	resetAccountConfirmation = { -- Новая запись
		title = "Сброс данных",
		message = "Вы уверены, что хотите сбросить свои данные? Это приведет к выходу из аккаунта и может потребовать перезапуска игры.",
		confirmButtonText = "Сбросить",
		cancelButtonText = "Отмена",
		theme = "dark",
		onConfirm = function(RE_ResetAuthData_arg, player_arg)
			if RE_ResetAuthData_arg then
				RE_ResetAuthData_arg:FireServer(player_arg.UserId)
			else
				warn("ERROR: RE_ResetAuthData_arg RemoteEvent is nil!")
			end
		end,
		onCancel = function() end
	}
}
local dialogScreenGui = nil -- Новая переменная для ScreenGui, создаваемого модулем
local colors = {
	sidebar = Color3.fromRGB(28, 30, 33),
	text = Color3.fromRGB(235, 238, 240),
	input = Color3.fromRGB(32, 34, 37),
	soft_stroke = Color3.fromRGB(58, 60, 64),
	danger = Color3.fromRGB(231, 76, 60)
}

local confirmationDialog = nil
local confirmationMessage = nil
local confirmationTitle = nil -- Добавил новую переменную для заголовка
local yesButton = nil
local noButton = nil

local currentOnConfirm = nil
local currentOnCancel = nil

function module.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	-- Удален блок if currentColors, так как setTheme будет управлять цветами

	-- Создаем собственный ScreenGui для диалога
	dialogScreenGui = Instance.new("ScreenGui")
	dialogScreenGui.Name = "ConfirmationDialogScreenGui"
	dialogScreenGui.Parent = playerGui
	dialogScreenGui.DisplayOrder = 999 -- Устанавливаем очень высокий DisplayOrder
	dialogScreenGui.IgnoreGuiInset = true
	dialogScreenGui.ResetOnSpawn = false
	dialogScreenGui.Enabled = true -- Включаем ScreenGui, но сам диалог будет Visible = false

	-- Присваиваем элементы глобальным переменным модуля для доступа из setTheme
	confirmationDialog = Instance.new("Frame")
	confirmationDialog.Name = "ConfirmationDialog"
	confirmationDialog.Parent = dialogScreenGui -- Родитель - наш новый ScreenGui
	confirmationDialog.Size = UDim2.new(0, 400, 0, 160) -- Уменьшил высоту
	confirmationDialog.Position = UDim2.fromScale(0.5, 0.5)
	confirmationDialog.AnchorPoint = Vector2.new(0.5, 0.5)
	confirmationDialog.BorderSizePixel = 0
	confirmationDialog.ZIndex = 100 -- Increased ZIndex to ensure it appears on top
	confirmationDialog.Visible = false

	local corner1 = Instance.new("UICorner")
	corner1.Parent = confirmationDialog
	corner1.CornerRadius = UDim.new(0, 24) -- Еще сильнее скругление

	local padding1 = Instance.new("UIPadding")
	padding1.Parent = confirmationDialog
	padding1.PaddingTop = UDim.new(0, 10)
	padding1.PaddingBottom = UDim.new(0, 10)
	padding1.PaddingLeft = UDim.new(0, 10)
	padding1.PaddingRight = UDim.new(0, 10)

	local stroke1 = Instance.new("UIStroke")
	stroke1.Parent = confirmationDialog
	stroke1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke1.Thickness = 1

	-- Новый TextLabel для заголовка
	confirmationTitle = Instance.new("TextLabel")
	confirmationTitle.Name = "Title"
	confirmationTitle.Parent = confirmationDialog
	confirmationTitle.Size = UDim2.new(1, 0, 0, 24) -- Чуть уменьшил высоту
	confirmationTitle.Position = UDim2.new(0.5, 0, 0, 5) -- Сдвинул чуть выше
	confirmationTitle.AnchorPoint = Vector2.new(0.5, 0)
	confirmationTitle.BackgroundTransparency = 1
	confirmationTitle.Text = "Заголовок"
	confirmationTitle.TextSize = 20
	confirmationTitle.Font = Enum.Font.SourceSansBold
	confirmationTitle.TextXAlignment = Enum.TextXAlignment.Center
	confirmationTitle.TextYAlignment = Enum.TextYAlignment.Center
	confirmationTitle.ZIndex = 101 -- Увеличил ZIndex

	confirmationMessage = Instance.new("TextLabel")
	confirmationMessage.Name = "Message"
	confirmationMessage.Parent = confirmationDialog
	confirmationMessage.Size = UDim2.new(1, 0, 0, 60) -- Уменьшил высоту сообщения
	confirmationMessage.Position = UDim2.new(0.5, 0, 0, 35) -- Сдвинул выше
	confirmationMessage.AnchorPoint = Vector2.new(0.5, 0)
	confirmationMessage.BackgroundTransparency = 1
	confirmationMessage.Text = "Вы уверены?"
	confirmationMessage.TextSize = 16
	confirmationMessage.Font = Enum.Font.SourceSansSemibold
	confirmationMessage.TextWrapped = true
	confirmationMessage.TextXAlignment = Enum.TextXAlignment.Center
	confirmationMessage.TextYAlignment = Enum.TextYAlignment.Center
	confirmationMessage.ZIndex = 101 -- Увеличил ZIndex

	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "ButtonContainer"
	buttonContainer.Parent = confirmationDialog
	buttonContainer.Size = UDim2.new(1, 0, 0, 40) -- Уменьшил высоту для более компактных кнопок
	buttonContainer.Position = UDim2.new(0.5, 0, 1, -10) -- Опустил чуть ниже, чтобы было больше места
	buttonContainer.AnchorPoint = Vector2.new(0.5, 1)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.ZIndex = 101 -- Увеличил ZIndex

	local listLayout = Instance.new("UIListLayout")
	listLayout.Parent = buttonContainer
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 10)

	yesButton = Instance.new("TextButton")
	yesButton.Name = "YesButton"
	yesButton.Parent = buttonContainer
	yesButton.Size = UDim2.new(0.5, -5, 0, 36) -- Уменьшил высоту кнопок
	yesButton.Text = "Да"
	yesButton.Font = Enum.Font.SourceSansBold
	yesButton.TextSize = 16
	yesButton.AutoButtonColor = false
	yesButton.ZIndex = 102 -- Увеличил ZIndex

	local corner2 = Instance.new("UICorner")
	corner2.Parent = yesButton
	corner2.CornerRadius = UDim.new(0, 16) -- Еще сильнее скругление для кнопок

	local stroke2 = Instance.new("UIStroke")
	stroke2.Parent = yesButton
	stroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke2.Thickness = 1

	noButton = Instance.new("TextButton")
	noButton.Name = "NoButton"
	noButton.Parent = buttonContainer
	noButton.Size = UDim2.new(0.5, -5, 0, 36) -- Уменьшил высоту кнопок
	noButton.Text = "Отмена"
	noButton.Font = Enum.Font.SourceSansBold
	noButton.TextSize = 16
	noButton.AutoButtonColor = false
	noButton.ZIndex = 102 -- Увеличил ZIndex

	local corner3 = Instance.new("UICorner")
	corner3.Parent = noButton
	corner3.CornerRadius = UDim.new(0, 16) -- Еще сильнее скругление для кнопок

	local stroke3 = Instance.new("UIStroke")
	stroke3.Parent = noButton
	stroke3.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke3.Thickness = 1

	-- Присвоил ссылки на элементы, чтобы их можно было обновить через setTheme
	module.dialogElements = {
		confirmationDialog = confirmationDialog,
		confirmationTitle = confirmationTitle,
		confirmationMessage = confirmationMessage,
		yesButton = yesButton,
		noButton = noButton,
		yesStroke = stroke2,
		noStroke = stroke3,
	}

	-- Устанавливаем начальную тему
	module.setTheme("dark")

	yesButton.MouseButton1Click:Connect(function()
		confirmationDialog.Visible = false
		-- dialogScreenGui.Enabled = false -- Можно выключить ScreenGui, если он больше не нужен
		if currentOnConfirm then
			currentOnConfirm()
		end
		currentOnConfirm = nil
		currentOnCancel = nil
	end)

	noButton.MouseButton1Click:Connect(function()
		confirmationDialog.Visible = false
		-- dialogScreenGui.Enabled = false -- Можно выключить ScreenGui, если он больше не нужен
		if currentOnCancel then
			currentOnCancel()
		end
		currentOnConfirm = nil
		currentOnCancel = nil
	end)
end

function module.showConfirmation(dialogId, ...)
	if not confirmationDialog then
		warn("ConfirmationDialogModule not initialized. Call init() first.")
		return
	end

	local dialogConfig = predefinedDialogs[dialogId]
	if not dialogConfig then
		warn("Dialog with ID '" .. dialogId .. "' not found in predefinedDialogs.")
		return
	end

	local message = dialogConfig.message or "Вы уверены?"
	local title = dialogConfig.title or "Подтверждение"
	local confirmButtonText = dialogConfig.confirmButtonText or "Да"
	local cancelButtonText = dialogConfig.cancelButtonText or "Отмена"
	local themeName = dialogConfig.theme or "dark" -- Получаем тему из конфига или используем по умолчанию

	local onConfirmCallback = dialogConfig.onConfirm
	local onCancelCallback = dialogConfig.onCancel
	local extraArgs = {...}

	module.setTheme(themeName) -- Применяем тему перед настройкой текста и отображением

	confirmationTitle.Text = title
	confirmationMessage.Text = message
	yesButton.Text = confirmButtonText
	noButton.Text = cancelButtonText

	currentOnConfirm = function()
		if onConfirmCallback then
			onConfirmCallback(unpack(extraArgs))
		end
	end
	currentOnCancel = function()
		if onCancelCallback then
			onCancelCallback(unpack(extraArgs))
		end
	end
	confirmationDialog.Visible = true
end

function module.setTheme(themeName)
	local theme = themePalettes[themeName]
	if not theme then
		warn("Theme '" .. themeName .. "' not found.")
		return
	end
	currentColors = theme

	if module.dialogElements then -- Проверяем, что элементы уже созданы
		local elements = module.dialogElements
		elements.confirmationDialog.BackgroundColor3 = theme.sidebar -- Используем sidebar как фон диалога
		elements.confirmationTitle.TextColor3 = theme.text
		elements.confirmationMessage.TextColor3 = theme.text
		elements.yesButton.BackgroundColor3 = theme.input
		elements.yesButton.TextColor3 = theme.text -- Белый текст для кнопки "Да" в светлой теме
		elements.noButton.BackgroundColor3 = theme.input
		elements.noButton.TextColor3 = theme.text
		elements.yesStroke.Color = theme.soft_stroke
		elements.noStroke.Color = theme.soft_stroke
		elements.confirmationDialog.UIStroke.Color = theme.dialogStroke -- Устанавливаем обводку диалога
	end
end

return module
