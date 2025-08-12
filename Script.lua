-- ServerScriptService/ChatServerScript (ИЛИ КАК ОН У ВАС НАЗВАН)
-- ВЕРСИЯ С ИСПРАВЛЕННОЙ ЛОГИКОЙ ОШИБОК ДЛЯ CANVAS

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- URL вашего прокси-сервера на Replit
local PROXY_URL = "https://abd6819b-b069-4b7a-8ed8-f9deefc7970d-00-ftzfmmtd6a85.spock.replit.dev:5000/generate"

local chatDataStore = DataStoreService:GetDataStore("PlayerChatHistories_v2")
local playerChatData = {}
local activeGenerations = {} -- New table to track active AI generation tasks
local rateLimitState = {} -- Анти-спам состояние по игрокам

-- Настройки анти-спама
local MIN_INTERVAL_BETWEEN_MESSAGES = 2 -- сек между любыми двумя отправками
local WINDOW_SECONDS = 60 -- окно для подсчета частоты
local MAX_MESSAGES_PER_WINDOW = 12 -- максимум сообщений за окно

-- // ФУНКЦИЯ ДЛЯ СОЗДАНИЯ ИЛИ ПОЛУЧЕНИЯ УДАЛЕННЫХ СОБЫТИЙ/ФУНКЦИЙ //
local function getOrCreate(className, name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = ReplicatedStorage
		print("Сервер создал недостающий " .. className .. ":", name)
	end
	return remote
end

-- // СОБЫТИЯ И ФУНКЦИИ //
local sendMessageEvent = getOrCreate("RemoteEvent", "SendMessageToServer")
local receiveMessageEvent = getOrCreate("RemoteEvent", "ReceiveMessageFromServer")
local getChatHistoryFunction = getOrCreate("RemoteFunction", "GetChatHistory")
local updateChatMetadataEvent = getOrCreate("RemoteEvent", "UpdateChatMetadata")
local deleteChatEvent = getOrCreate("RemoteEvent", "DeleteChat")
local renameChatEvent = getOrCreate("RemoteEvent", "RenameChat")
local clearAllChatHistoryEvent = getOrCreate("RemoteEvent", "ClearAllChatHistory")
local cancelGenerationEvent = getOrCreate("RemoteEvent", "CancelGeneration")

-- Функция для запроса к прокси, возвращает (ответ, ошибка)
local function getProxyResponseAsync(prompt, isCanvas)
	if PROXY_URL:match("ВАШ-URL-ОТ-REPLIT") then
		return nil, "URL прокси-сервера не настроен в скрипте!"
	end

	local requestBody = { 
		prompt = prompt,
		canvasMode = isCanvas or false 
	}

	local encodedBody = HttpService:JSONEncode(requestBody)

	local success, response = pcall(function()
		return HttpService:PostAsync(PROXY_URL, encodedBody, Enum.HttpContentType.ApplicationJson)
	end)
	if not success then
		warn("Ошибка HTTP-запроса к прокси:", response)
		return nil, "Не удалось связаться с сервером-посредником."
	end

	local decodedSuccess, decodedResponse = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not decodedSuccess then
		warn("Ошибка декодирования JSON ответа от прокси:", response)
		return nil, "Прокси-сервер вернул некорректный ответ."
	end

	if decodedResponse.response then
		return decodedResponse.response, nil -- Успех, возвращаем ответ и nil в качестве ошибки
	elseif decodedResponse.error then
		warn("Ошибка от прокси-сервера:", decodedResponse.error)
		return nil, decodedResponse.error -- Ошибка, возвращаем nil и текст ошибки
	else
		return nil, "Получен неизвестный ответ от прокси-сервера."
	end
end

-- Сохранение данных игрока
local function saveData(pId)
	if playerChatData[pId] then
		local success, err = pcall(function()
			chatDataStore:SetAsync(pId, playerChatData[pId])
		end)
		if not success then
			warn("Не удалось сохранить данные для pId " .. pId .. ": " .. err)
		end
	end
end

-- Функция проверки авторизации (напрямую)
local function checkPlayerAuth(player)
	local pId = tostring(player.UserId)
	local authDataStore = DataStoreService:GetDataStore("PlayerAuthStatusV2")
	local success, data = pcall(function()
		return authDataStore:GetAsync(pId)
	end)
	if success and data and data.authorized then
		return true
	else
		return false
	end
end

-- [[ ИЗМЕНЕНО: Полностью переработана логика обработки ответа от ИИ ]] --
local function onPlayerMessage(player, chatId, message, isCanvasMode)
	print(`Игрок {player.Name} отправил сообщение: "{message}" в чат {chatId}. Режим Canvas: {tostring(isCanvasMode)}`)
	local pId = tostring(player.UserId)
	local playerData = playerChatData[pId]
	local authStatus = checkPlayerAuth(player)

	-- Store active generation task
	activeGenerations[pId] = activeGenerations[pId] or {}
	activeGenerations[pId][chatId] = { cancelled = false }

	if not authStatus then
		warn("Ошибка авторизации для пользователя " .. player.Name)
		receiveMessageEvent:FireClient(player, chatId, {
			chunk = "Ошибка авторизации!\nВы не авторизованы.",
			isFinal = true,
			isCanvas = false
		})
		activeGenerations[pId][chatId] = nil -- Clear generation state
		return
	end
	if not playerData then 
		warn("Не найдены данные для игрока " .. player.Name)
		activeGenerations[pId][chatId] = nil -- Clear generation state
		return 
	end

	-- Анти-спам: проверка частоты отправки
	do
		local now = os.time()
		local state = rateLimitState[pId]
		if not state then
			state = { lastSentAt = 0, timestamps = {} }
			rateLimitState[pId] = state
		end

		-- Проверка минимального интервала
		local since = now - (state.lastSentAt or 0)
		if since < MIN_INTERVAL_BETWEEN_MESSAGES then
			local waitLeft = MIN_INTERVAL_BETWEEN_MESSAGES - since
			receiveMessageEvent:FireClient(player, chatId, {
				isSystem = true,
				text = string.format("Слишком часто. Подождите %d сек.", math.max(1, waitLeft)),
			})
			activeGenerations[pId][chatId] = nil
			return
		end

		-- Очистка старых таймстемпов и проверка окна
		local newTimestamps = {}
		for _, t in ipairs(state.timestamps) do
			if now - t < WINDOW_SECONDS then table.insert(newTimestamps, t) end
		end
		state.timestamps = newTimestamps
		if #state.timestamps >= MAX_MESSAGES_PER_WINDOW then
			local oldest = state.timestamps[1]
			local waitLeft = WINDOW_SECONDS - (now - oldest)
			receiveMessageEvent:FireClient(player, chatId, {
				isSystem = true,
				text = string.format("Превышен лимит %d сообщений/мин. Подождите %d сек.", MAX_MESSAGES_PER_WINDOW, math.max(1, waitLeft)),
			})
			activeGenerations[pId][chatId] = nil
			return
		end

		-- Записываем отправку
		state.lastSentAt = now
		table.insert(state.timestamps, now)
	end

	if not playerData[chatId] then
		playerData[chatId] = { id = chatId, messages = {}, title = message }
	end

	table.insert(playerData[chatId].messages, {type = "Player", text = message, timestamp = os.time()})
	playerData[chatId].timestamp = os.time()

	task.spawn(function()
		-- Check if generation was cancelled before proceeding
		if activeGenerations[pId] and activeGenerations[pId][chatId] and activeGenerations[pId][chatId].cancelled then
			print(`Отменена генерация для игрока {player.Name} в чате {chatId}.`)
			activeGenerations[pId][chatId] = nil -- Clear generation state
			return
		end

		-- Запрашиваем ответ от ИИ
		local fullResponse, err = getProxyResponseAsync(message, isCanvasMode)

		-- Check if generation was cancelled AFTER proxy response
		if activeGenerations[pId] and activeGenerations[pId][chatId] and activeGenerations[pId][chatId].cancelled then
			print(`Отменена генерация для игрока {player.Name} в чате {chatId} после получения ответа от прокси.`)
			activeGenerations[pId][chatId] = nil -- Clear generation state
			return
		end

		-- [[ ГЛАВНОЕ ИСПРАВЛЕНИЕ: Проверяем, была ли ошибка ]] --
		if err then
			-- Если есть ошибка, неважно, какой был режим (Canvas или нет).
			-- Мы сохраняем ее как обычный ответ ИИ и отправляем клиенту как простой текст.
			print(`Произошла ошибка при обработке запроса от {player.Name}: {err}`)

			local errorMessage = err or "Произошла неизвестная ошибка."

			-- Сохраняем как обычное сообщение типа "AI"
			table.insert(playerData[chatId].messages, {type = "AI", text = errorMessage, timestamp = os.time()})
			saveData(pId)

			-- Отправляем клиенту как обычное, НЕ-Canvas сообщение одним куском.
			-- Клиент отобразит это как обычный текст, а не кнопку "Показать Canvas".
			receiveMessageEvent:FireClient(player, chatId, {
				chunk = errorMessage,
				isFinal = true,
				isCanvas = false -- Явно указываем, что это НЕ Canvas
			})
			return -- Завершаем выполнение функции
		end

		-- Если мы дошли сюда, значит ошибки не было (err == nil)
		-- Теперь используем стандартную логику в зависимости от режима
		if isCanvasMode then
			-- РЕЖИМ CANVAS (Успешный ответ)
			print(`Отправляется Canvas ответ для {player.Name}: "{string.sub(fullResponse, 1, 50)}..."`)
			table.insert(playerData[chatId].messages, {type = "AI_Canvas", fullText = fullResponse, timestamp = os.time()})
			saveData(pId)

			-- Check for cancellation before firing client event for canvas
			if activeGenerations[pId] and activeGenerations[pId][chatId] and activeGenerations[pId][chatId].cancelled then
				print(`Отправка Canvas ответа отменена для игрока {player.Name} в чате {chatId}.`)
				activeGenerations[pId][chatId] = nil -- Clear generation state
				return
			end

			receiveMessageEvent:FireClient(player, chatId, {
				isCanvas = true,
				fullText = fullResponse
			})
			activeGenerations[pId][chatId] = nil -- Clear generation state
		else
			-- ОБЫЧНЫЙ РЕЖИМ (Стриминг)
			print(`Отправляется потоковый ответ для {player.Name}: "{string.sub(fullResponse, 1, 50)}..."`)
			table.insert(playerData[chatId].messages, {type = "AI", text = fullResponse, timestamp = os.time()})
			saveData(pId)

			local CHUNK_SIZE = 900
			local totalLength = #fullResponse

			for i = 1, math.ceil(totalLength / CHUNK_SIZE) do
				-- Check for cancellation within the streaming loop
				if activeGenerations[pId] and activeGenerations[pId][chatId] and activeGenerations[pId][chatId].cancelled then
					print(`Потоковая передача ответа отменена для игрока {player.Name} в чате {chatId}.`)
					activeGenerations[pId][chatId] = nil -- Clear generation state
					return
				end

				local s, e = (i - 1) * CHUNK_SIZE + 1, i * CHUNK_SIZE
				local chunk = string.sub(fullResponse, s, e)
				local isFinal = (e >= totalLength)

				receiveMessageEvent:FireClient(player, chatId, {
					chunk = chunk,
					isFinal = isFinal,
					isCanvas = false
				})
				task.wait(0.05)
			end
			activeGenerations[pId][chatId] = nil -- Clear generation state after successful streaming
		end
	end)
end


-- Остальные функции (без изменений)
local function onUpdateMetadata(player,chatId,metadata) local pId=tostring(player.UserId) local d=playerChatData[pId] if d and d[chatId] and metadata then for k,v in pairs(metadata) do d[chatId][k]=v end saveData(pId) end end
local function onRenameChat(player,chatId,newTitle) local pId=tostring(player.UserId) local d=playerChatData[pId] if d and d[chatId] and newTitle and newTitle:gsub("%s*","")~="" then d[chatId].title=newTitle saveData(pId) end end
local function onDeleteChat(player,chatId) 
	local pId=tostring(player.UserId) 
	local d=playerChatData[pId] 
	if d and d[chatId] then 
		d[chatId]=nil 
		saveData(pId) 
		print("DEBUG: Server deleting chat ", chatId, " for ", player.Name)
		deleteChatEvent:FireClient(player, chatId)
	end 
end
local function onClearAllChatHistory(player) 
	local pId=tostring(player.UserId) 
	playerChatData[pId] = {} 
	saveData(pId) 
	print("DEBUG: Server clearing all chat history for ", player.Name) 
	clearAllChatHistoryEvent:FireClient(player) 
end
local function onPlayerAdded(player) local pId=tostring(player.UserId) local s,d=pcall(function() return chatDataStore:GetAsync(pId) end) if s then playerChatData[pId]=d or {} print("Данные чата загружены для",player.Name) else warn("Не удалось загрузить данные чата для "..player.Name..": "..tostring(d)) playerChatData[pId]={} end end
local function onPlayerRemoving(player) local pId=tostring(player.UserId) if playerChatData[pId] then saveData(pId) playerChatData[pId]=nil end end
getChatHistoryFunction.OnServerInvoke=function(player) return playerChatData[tostring(player.UserId)]or{} end

sendMessageEvent.OnServerEvent:Connect(onPlayerMessage)
updateChatMetadataEvent.OnServerEvent:Connect(onUpdateMetadata)
deleteChatEvent.OnServerEvent:Connect(onDeleteChat)
renameChatEvent.OnServerEvent:Connect(onRenameChat)
clearAllChatHistoryEvent.OnServerEvent:Connect(onClearAllChatHistory)
-- Handle cancellation event
cancelGenerationEvent.OnServerEvent:Connect(function(player, chatId)
	local pId = tostring(player.UserId)
	if activeGenerations[pId] and activeGenerations[pId][chatId] then
		activeGenerations[pId][chatId].cancelled = true
		print(`Генерация отменена сервером для игрока {player.Name} в чате {chatId}.`)
	end
end)
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _,p in ipairs(Players:GetPlayers())do task.spawn(onPlayerAdded,p)end
print("Серверный скрипт чата (v10, исправлена логика ошибок Canvas) загружен и готов.")
