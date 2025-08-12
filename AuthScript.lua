-- СЕРВИСЫ
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- DATASTORE
local authDataStore = DataStoreService:GetDataStore("PlayerAuthStatusV2")

-- REMOTES
local checkAuthStatus = Instance.new("RemoteFunction", ReplicatedStorage)
checkAuthStatus.Name = "CheckAuthStatus"

local setAuthStatus = Instance.new("RemoteFunction", ReplicatedStorage)
setAuthStatus.Name = "SetAuthStatus"

local getUserInfo = Instance.new("RemoteFunction", ReplicatedStorage)
getUserInfo.Name = "GetUserInfo"

local resetAuthData = Instance.new("RemoteEvent", ReplicatedStorage)
resetAuthData.Name = "ResetAuthData"

-- ADMIN
local updateUserPlan = Instance.new("RemoteFunction", ReplicatedStorage)
updateUserPlan.Name = "UpdateUserPlan"

-- СПИСОК АДМИНОВ
local ADMINS = {
	[1] = true, -- System
	[12345678] = true, -- Замените на свой UserId
}

local function generateSessionId()
	return HttpService:GenerateGUID(false)
end

-- Проверка авторизации
checkAuthStatus.OnServerInvoke = function(player)
	local key = tostring(player.UserId)
	local ok, data = pcall(function()
		return authDataStore:GetAsync(key)
	end)
	if ok and data and data.authorized == true then
		return true
	end
	return false
end

-- Получение полной информации
getUserInfo.OnServerInvoke = function(player)
	local key = tostring(player.UserId)
	local ok, data = pcall(function()
		return authDataStore:GetAsync(key)
	end)
	if ok and data and data.authorized == true then
		return {
			authorized = true,
			plan = data.plan or "free", -- Важный фолбек для старых данных
			sessionId = data.sessionId,
			firstLogin = data.firstLogin,
			lastLogin = data.lastLogin,
			clientVersion = data.clientVersion
		}
	end
	return { authorized = false, plan = "none" }
end

-- Установка статуса (вход)
setAuthStatus.OnServerInvoke = function(player, clientVersion)
	local key = tostring(player.UserId)
	local now = os.time()

	local data = {}
	local getOk, oldData = pcall(function()
		return authDataStore:GetAsync(key)
	end)

	if getOk and oldData then
		data = oldData
	end

	data.authorized = true
	data.lastLogin = now
	data.sessionId = generateSessionId()
	data.clientVersion = clientVersion or "unknown"

	if not data.firstLogin then
		data.firstLogin = now
	end
	if not data.plan then
		-- ИЗМЕНЕНИЕ: Теперь по умолчанию "free"
		data.plan = "free" 
	end

	local ok, err = pcall(function()
		authDataStore:SetAsync(key, data)
	end)

	if not ok then
		warn("DataStore error SetAsync: " .. tostring(err))
		return false
	end

	return true
end

-- Обновление плана (только админ)
updateUserPlan.OnServerInvoke = function(player, targetUserId, newPlan)
	if not ADMINS[player.UserId] then return false, "Нет прав доступа" end
	if not targetUserId or not newPlan then return false, "Некорректные параметры" end
	-- ИЗМЕНЕНИЕ: Проверка на "free" и "pro"
	if newPlan ~= "free" and newPlan ~= "pro" then return false, "Некорректный план" end

	local key = tostring(targetUserId)
	local ok, data = pcall(function() return authDataStore:GetAsync(key) end)

	if not ok or not data or data.authorized ~= true then
		return false, "Пользователь не авторизован или не найден"
	end

	data.plan = newPlan
	data.lastUpdate = os.time()

	local saveOk, err = pcall(function() authDataStore:SetAsync(key, data) end)

	if not saveOk then
		warn("Update plan error: " .. tostring(err))
		return false, "Ошибка сохранения"
	end

	return true, "План обновлён"
end

-- Сброс (сам игрок или админ)
resetAuthData.OnServerEvent:Connect(function(player, targetUserId)
	targetUserId = targetUserId or player.UserId
	if player.UserId ~= targetUserId and not ADMINS[player.UserId] then
		warn("Попытка сброса чужих данных от " .. player.Name .. " запрещена.")
		return
	end

	local key = tostring(targetUserId)
	local ok, err = pcall(function() authDataStore:RemoveAsync(key) end)

	if not ok then
		warn("RemoveAsync error: " .. tostring(err))
		return
	end

	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if targetPlayer then
		targetPlayer:Kick("Ваши данные были сброшены администратором или вами. Пожалуйста, перезапустите игру.")
	end
end)


Players.PlayerRemoving:Connect(function(player)
	local key = tostring(player.UserId)
	local ok, data = pcall(function() return authDataStore:GetAsync(key) end)
	if ok and data and data.authorized then
		data.lastLogout = os.time()
		pcall(function() authDataStore:SetAsync(key, data) end)
	end
end)

print("✅ AuthScriptV4 (Free/Pro) загружен и готов к работе.")