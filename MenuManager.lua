-- MenuManager (ModuleScript in ChatGui)
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MenuManager = {}

local activeMenu = nil
local inputConnection = nil
local resizeConn = nil

local predefinedMenus = {
	profileMenu = {
		{
			type = "description_item",
			title = "Ваш аккаунт",
			description = function(playerName) return "Пользователь: " .. playerName end
		},
		{ type = "divider" },
		{
			type = "button",
			text = "О профиле",
			callback = function(playerGui)
				local profileGui = playerGui:FindFirstChild("ProfileGui")
				if profileGui then
					profileGui.Enabled = true
				else
					warn("ProfileGui не найден!")
				end
			end
		},
		{ type = "divider" },
		{
			type = "button",
			text = "О нас",
			callback = function(...)
				local currentExtraArgs = {...}
				local infoPageApi = currentExtraArgs[2]
				if infoPageApi and type(infoPageApi.open) == "function" then
					infoPageApi.open()
				else
					warn("InfoPage API не инициализирован или не содержит функцию 'open'!")
				end
			end
		},
		{ type = "divider" },
		{
			type = "button",
			text = "Сбросить аккаунт",
			isDestructive = true,
			callback = function(...)
				local currentExtraArgs = {...}
				local playerGui = currentExtraArgs[1]
				local RE_ResetAuthData = currentExtraArgs[3]
				local player = currentExtraArgs[4]
				local setPlanLabel = currentExtraArgs[5]
				local setupAuthUI = currentExtraArgs[6]
				local ConfirmationDialogModule = require(game:GetService("StarterGui"):WaitForChild("ConfirmationDialogModule"))
				ConfirmationDialogModule.showConfirmation("resetAccountConfirmation", RE_ResetAuthData, player, setPlanLabel, setupAuthUI)
			end
		}
	},
	chatProfileMenu = {
		{
			type = "description_item",
			title = "Ваш аккаунт",
			description = function(playerName) return "Пользователь: " .. playerName end
		},
		{ type = "divider" },
		{
			type = "button",
			text = "Настройки профиля",
			callback = function(playerGui)
				local profileGui = playerGui:FindFirstChild("ProfileGui")
				if profileGui then
					profileGui.Enabled = true
				else
					warn("ProfileGui не найден!")
				end
			end
		},
		{ type = "divider" },
		{
			type = "button",
			text = "О нас",
			callback = function(...)
				local currentExtraArgs = {...}
				local infoPageApi = currentExtraArgs[2]
				if infoPageApi and type(infoPageApi.open) == "function" then
					infoPageApi.open()
				else
					warn("InfoPage API не инициализирован или не содержит функцию 'open'!")
				end
			end
		}
	},
	deleteChatMenu = {
		{
			type = "button",
			text = "Удалить чат",
			isDestructive = true,
			callback = function(ConfirmationDialogModule, deleteChatEvent, chatId)
				ConfirmationDialogModule.showConfirmation("deleteChatConfirmation", deleteChatEvent, chatId)
			end
		}
	}
}

local colorPalettes = {
	dark = {
		background = Color3.fromRGB(28, 30, 33),
		stroke = Color3.fromRGB(70, 74, 80),
		text = Color3.fromRGB(235, 238, 240),
		itemHover = Color3.fromRGB(36, 37, 40),
		itemSelected = Color3.fromRGB(40, 42, 44),
		divider = Color3.fromRGB(58, 60, 64),
		danger = Color3.fromRGB(231, 76, 60),
		muted = Color3.fromRGB(160, 164, 170)
	},
	light = {
		background = Color3.fromRGB(248, 248, 248),
		stroke = Color3.fromRGB(220, 220, 228),
		text = Color3.fromRGB(40, 40, 40),
		itemHover = Color3.fromRGB(235, 235, 240),
		itemSelected = Color3.fromRGB(220, 224, 235),
		divider = Color3.fromRGB(225, 225, 230)
	}
}

local function isInside(gui, position)
	if not gui or not gui:IsA("GuiObject") then return false end
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return position.X >= p.X and position.X <= p.X + s.X
		and position.Y >= p.Y and position.Y <= p.Y + s.Y
end

local function tween(obj, time, props, style, dir)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end

local function appear(frame)
	frame.Visible = true

	local texts, images = {}, {}
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			texts[#texts+1] = d
			d.TextTransparency = 1
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			images[#images+1] = d
			d.ImageTransparency = 1
		end
	end

	local scale = Instance.new("UIScale")
	scale.Scale = 0.985
	scale.Parent = frame

	frame.BackgroundTransparency = 0

	local openTime = 0.14
	tween(scale, openTime, {Scale = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, d in ipairs(texts) do tween(d, openTime, {TextTransparency = 0}) end
	for _, d in ipairs(images) do tween(d, openTime, {ImageTransparency = 0}) end

	task.delay(openTime + 0.02, function()
		if scale and scale.Parent then scale:Destroy() end
	end)
end

local function disappear(frame, onDone)
	if not frame or not frame.Parent then
		if onDone then onDone() end
		return
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = frame

	local closeTime = 0.12
	tween(scale, closeTime, {Scale = 0.985}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			tween(d, closeTime, {TextTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			tween(d, closeTime, {ImageTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end

	task.delay(closeTime, function()
		if scale and scale.Parent then scale:Destroy() end
		if onDone then onDone() end
	end)
end

local function createItemTemplate(colors, height)
	local item = Instance.new("TextButton")
	item.Name = "MenuItem"
	item.Size = UDim2.new(1, 0, 0, height)
	item.BackgroundColor3 = colors.background
	item.Text = ""
	item.AutoButtonColor = false
	item.BorderSizePixel = 0
	item.ClipsDescendants = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = item

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = item

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.Gotham
	label.TextColor3 = colors.text
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.BackgroundTransparency = 1
	label.Parent = item

	local itemPadding = Instance.new("UIPadding")
	itemPadding.PaddingTop = UDim.new(0, 5)
	itemPadding.PaddingBottom = UDim.new(0, 5)
	itemPadding.Parent = item

	local hoverTime = 0.07
	item.MouseEnter:Connect(function()
		tween(item, hoverTime, {BackgroundColor3 = colors.itemHover})
	end)
	item.MouseLeave:Connect(function()
		tween(item, hoverTime, {BackgroundColor3 = colors.background})
	end)
	item.MouseButton1Down:Connect(function()
		tween(item, 0.06, {BackgroundColor3 = colors.itemSelected})
	end)
	item.MouseButton1Up:Connect(function()
		tween(item, 0.06, {BackgroundColor3 = colors.itemHover})
	end)

	return item
end

local function createDivider(colors)
	local div = Instance.new("Frame")
	div.Name = "Divider"
	div.Size = UDim2.new(1, 0, 0, 1)
	div.BackgroundColor3 = colors.divider
	div.BorderSizePixel = 0
	return div
end

local function createDescriptionItemTemplate(colors, height)
	local item = Instance.new("Frame")
	item.Name = "DescriptionItem"
	item.Size = UDim2.new(1, 0, 0, height)
	item.BackgroundColor3 = colors.background
	item.BorderSizePixel = 0
	item.ClipsDescendants = true

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = item

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.Position = UDim2.new(0, 0, 0, 5)
	titleLabel.AnchorPoint = Vector2.new(0, 0)
	titleLabel.Font = Enum.Font.SourceSansSemibold
	titleLabel.TextColor3 = colors.text
	titleLabel.TextSize = 16
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = item

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Name = "DescriptionLabel"
	descriptionLabel.Size = UDim2.new(1, 0, 0, 16)
	descriptionLabel.Position = UDim2.new(0, 0, 0, 25)
	descriptionLabel.AnchorPoint = Vector2.new(0, 0)
	descriptionLabel.Font = Enum.Font.SourceSans
	descriptionLabel.TextColor3 = colors.muted
	descriptionLabel.TextSize = 13
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Center
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Parent = item

	return item
end

local SCREEN_EDGE_MARGIN = 20
local TOP_SCREEN_MARGIN = 25
local BOTTOM_SAFE_MARGIN = 10
local VERTICAL_OFFSET_FROM_ANCHOR = 8

local function computeMenuPosition(anchorObject, menuFrame, parentGui, width)
	local aPos, aSize = anchorObject.AbsolutePosition, anchorObject.AbsoluteSize
	local pSize = parentGui.AbsoluteSize
	local mWidth = width
	local mHeight = menuFrame.AbsoluteSize.Y

	local x = aPos.X + aSize.X - mWidth
	x = math.max(SCREEN_EDGE_MARGIN, x)
	x = math.min(x, pSize.X - mWidth - SCREEN_EDGE_MARGIN)

	local y_down = aPos.Y + aSize.Y + VERTICAL_OFFSET_FROM_ANCHOR
	local y_up = aPos.Y - mHeight - VERTICAL_OFFSET_FROM_ANCHOR

	local final_y = y_down
	if final_y < TOP_SCREEN_MARGIN then
		final_y = TOP_SCREEN_MARGIN
	end

	if final_y + mHeight > pSize.Y - BOTTOM_SAFE_MARGIN then
		final_y = y_up
		if final_y < TOP_SCREEN_MARGIN then
			final_y = TOP_SCREEN_MARGIN
		end
		if final_y + mHeight > pSize.Y - BOTTOM_SAFE_MARGIN then
			final_y = math.max(TOP_SCREEN_MARGIN, pSize.Y - mHeight - BOTTOM_SAFE_MARGIN)
		end
	end

	return UDim2.new(0, x, 0, final_y)
end

function MenuManager.create(anchorObject, menuId, parentGui, theme, ...)
	MenuManager.close()

	local menuItems = predefinedMenus[menuId]
	if not menuItems then
		warn("Menu with ID '" .. menuId .. "' not found in predefinedMenus.")
		return
	end

	local colors = colorPalettes[theme or "dark"] or colorPalettes.dark

	local extraArgs = {...}
	local playerName = extraArgs[#extraArgs]

	local MENU_WIDTH = 180
	local ITEM_HEIGHT = 35
	local PADDING = 10
	local GAP = 5

	local menuFrame = Instance.new("Frame")
	menuFrame.Name = "DropdownMenu"
	menuFrame.Size = UDim2.new(0, MENU_WIDTH, 0, 0)
	menuFrame.AutomaticSize = Enum.AutomaticSize.Y
	menuFrame.BackgroundColor3 = colors.background
	menuFrame.BorderSizePixel = 0
	menuFrame.Active = true
	menuFrame.ZIndex = 200
	menuFrame.ClipsDescendants = true
	menuFrame.Visible = false
	menuFrame.Parent = parentGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = menuFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.stroke
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = menuFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.Padding = UDim.new(0, 3)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = menuFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 5)
	padding.PaddingRight = UDim.new(0, 5)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = menuFrame

	for i, itemData in ipairs(menuItems) do
		if itemData.type == "divider" then
			local dWrap = Instance.new("Frame")
			dWrap.Name = "DividerWrap"
			dWrap.Size = UDim2.new(1, 0, 0, 9)
			dWrap.BackgroundTransparency = 1
			dWrap.LayoutOrder = i
			dWrap.Parent = menuFrame

			local div = createDivider(colors)
			div.Position = UDim2.new(0, 0, 0.5, 0)
			div.AnchorPoint = Vector2.new(0, 0.5)
			div.Parent = dWrap
		elseif itemData.type == "button" then
			local newItem = createItemTemplate(colors, ITEM_HEIGHT)
			newItem.LayoutOrder = i
			newItem.Parent = menuFrame
			newItem.ZIndex = 201

			local label = newItem:FindFirstChild("Label")
			if label then
				label.Text = itemData.text or ("Item " .. i)
				label.ZIndex = 202
			end

			if itemData.callback and not itemData.disabled then
				newItem.MouseButton1Click:Connect(function()
					itemData.callback(unpack(extraArgs))
					MenuManager.close()
				end)
			end

			if itemData.disabled then
				newItem.Active = false
				newItem.AutoButtonColor = false
				if label then
					label.TextColor3 = Color3.fromRGB(160, 160, 160)
				end
			elseif itemData.isDestructive then
				newItem.BackgroundColor3 = colors.background
				if label then
					label.TextColor3 = colors.danger
				end
				newItem.MouseEnter:Connect(function()
					tween(newItem, 0.07, {BackgroundColor3 = Color3.fromRGB(60, 30, 30)})
				end)
				newItem.MouseLeave:Connect(function()
					tween(newItem, 0.07, {BackgroundColor3 = colors.background})
				end)
				newItem.MouseButton1Down:Connect(function()
					tween(newItem, 0.06, {BackgroundColor3 = Color3.fromRGB(80, 40, 40)})
				end)
				newItem.MouseButton1Up:Connect(function()
					tween(newItem, 0.06, {BackgroundColor3 = Color3.fromRGB(60, 30, 30)})
				end)
			end
		elseif itemData.type == "description_item" then
			local newItem = createDescriptionItemTemplate(colors, ITEM_HEIGHT + 10)
			newItem.LayoutOrder = i
			newItem.Parent = menuFrame
			newItem.ZIndex = 201

			local titleLabel = newItem:FindFirstChild("TitleLabel")
			local descriptionLabel = newItem:FindFirstChild("DescriptionLabel")

			if titleLabel then
				titleLabel.Text = itemData.title or ""
				titleLabel.ZIndex = 202
			end
			if descriptionLabel then
				if type(itemData.description) == "function" then
					descriptionLabel.Text = itemData.description(playerName)
				else
					descriptionLabel.Text = itemData.description or ""
				end
				descriptionLabel.ZIndex = 202
			end
			newItem.Active = false
			newItem.BackgroundColor3 = colors.background
		end
	end

	RunService.Heartbeat:Wait()
	menuFrame.Position = computeMenuPosition(anchorObject, menuFrame, parentGui, MENU_WIDTH)

	appear(menuFrame)

	activeMenu = menuFrame

	inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if activeMenu and not isInside(activeMenu, input.Position) then
				MenuManager.close()
			end
		elseif input.KeyCode == Enum.KeyCode.Escape then
			MenuManager.close()
		end
	end)

	if parentGui and parentGui:IsA("GuiObject") then
		resizeConn = parentGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if activeMenu and activeMenu.Parent then
				activeMenu.Position = computeMenuPosition(anchorObject, activeMenu, parentGui, MENU_WIDTH)
			end
		end)
	end

	return menuFrame
end

function MenuManager.close()
	if inputConnection then inputConnection:Disconnect() inputConnection = nil end
	if resizeConn then resizeConn:Disconnect() resizeConn = nil end

	if activeMenu then
		local f = activeMenu
		activeMenu = nil
		disappear(f, function()
			if f and f.Parent then f:Destroy() end
		end)
	end
end

function MenuManager.isMenuOpen()
	return activeMenu ~= nil
end

return MenuManager