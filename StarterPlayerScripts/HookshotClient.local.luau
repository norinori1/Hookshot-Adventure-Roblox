local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

print("[HookshotClient] スクリプト開始")
print("[HookshotClient] プレイヤー:", player.Name)

local config = require(ReplicatedStorage:WaitForChild("HookshotConfig"))
print("[HookshotClient] Config読み込み完了")

local remotes = ReplicatedStorage:WaitForChild("HookshotRemotes")
local requestRemote = remotes:WaitForChild("Request") :: RemoteEvent
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent

print("[HookshotClient] RemoteEvents読み込み完了")
print("[HookshotClient] 入力タイプ:", config.INPUT_TYPE.Name)

local isHooked = false
local cooldownUntil = 0
local anchorPosition: Vector3? = nil

local visualAnchorPart: Part? = nil
local visualRootAttachment: Attachment? = nil
local visualAnchorAttachment: Attachment? = nil
local visualBeam: Beam? = nil

-- プレビュー用
local previewBeam: Beam? = nil
local previewAnchorPart: Part? = nil
local previewAnchorAttachment: Attachment? = nil
local previewRootAttachment: Attachment? = nil
local isAiming = false

local function getRootPart(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function clearVisuals()
	if visualBeam then
		visualBeam:Destroy()
		visualBeam = nil
	end
	if visualAnchorAttachment then
		visualAnchorAttachment:Destroy()
		visualAnchorAttachment = nil
	end
	if visualRootAttachment then
		visualRootAttachment:Destroy()
		visualRootAttachment = nil
	end
	if visualAnchorPart then
		visualAnchorPart:Destroy()
		visualAnchorPart = nil
	end
end

local function clearPreview()
	if previewBeam then
		previewBeam:Destroy()
		previewBeam = nil
	end
	if previewAnchorAttachment then
		previewAnchorAttachment:Destroy()
		previewAnchorAttachment = nil
	end
	if previewRootAttachment then
		previewRootAttachment:Destroy()
		previewRootAttachment = nil
	end
	if previewAnchorPart then
		previewAnchorPart:Destroy()
		previewAnchorPart = nil
	end
end

local function setupPreview(targetPosition: Vector3, isInRange: boolean)
	clearPreview()

	local root = getRootPart()
	if not root then
		return
	end

	local previewColor = isInRange and config.PREVIEW_COLOR_IN_RANGE or config.PREVIEW_COLOR_OUT_OF_RANGE

	previewRootAttachment = Instance.new("Attachment")
	previewRootAttachment.Name = "HookshotPreviewRootAttachment"
	previewRootAttachment.Parent = root

	previewAnchorPart = Instance.new("Part")
	previewAnchorPart.Name = "HookshotPreviewAnchor"
	previewAnchorPart.Anchored = true
	previewAnchorPart.CanCollide = false
	previewAnchorPart.CanTouch = false
	previewAnchorPart.CanQuery = false
	previewAnchorPart.Transparency = 0.5
	previewAnchorPart.Size = Vector3.new(0.8, 0.8, 0.8)
	previewAnchorPart.Color = previewColor
	previewAnchorPart.Material = Enum.Material.Neon
	previewAnchorPart.CFrame = CFrame.new(targetPosition)
	previewAnchorPart.Parent = workspace

	previewAnchorAttachment = Instance.new("Attachment")
	previewAnchorAttachment.Name = "HookshotPreviewAnchorAttachment"
	previewAnchorAttachment.Parent = previewAnchorPart

	previewBeam = Instance.new("Beam")
	previewBeam.Name = "HookshotPreviewBeam"
	previewBeam.Attachment0 = previewRootAttachment
	previewBeam.Attachment1 = previewAnchorAttachment
	previewBeam.Width0 = config.BEAM_WIDTH * 0.6
	previewBeam.Width1 = config.BEAM_WIDTH * 0.6
	previewBeam.FaceCamera = false
	previewBeam.Color = ColorSequence.new(previewColor)
	previewBeam.LightEmission = 0.8
	previewBeam.LightInfluence = 0
	previewBeam.Transparency = NumberSequence.new(0.4)
	previewBeam.Enabled = true
	previewBeam.Parent = root
end

local function updatePreview()
	-- 常にプレビューを表示する設定の場合
	if not config.ALWAYS_SHOW_PREVIEW and not isAiming then
		clearPreview()
		return
	end

	local root = getRootPart()
	if not root then
		clearPreview()
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local mouse = player:GetMouse()
	local origin = camera.CFrame.Position
	local target = mouse and mouse.Hit and mouse.Hit.Position or (origin + camera.CFrame.LookVector * config.MAX_RANGE)
	local direction = (target - origin)

	if direction.Magnitude < 0.001 then
		return
	end

	-- レイキャストでヒット位置を計算
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {player.Character}
	rayParams.IgnoreWater = false

	local result = workspace:Raycast(origin, direction.Unit * config.MAX_RANGE, rayParams)
	local hitPosition = result and result.Position or (origin + direction.Unit * config.MAX_RANGE)
	local isInRange = result ~= nil

	-- プレビューを更新
	if previewAnchorPart then
		previewAnchorPart.CFrame = CFrame.new(hitPosition)
		-- 範囲外の場合は赤色、範囲内の場合は白色
		previewAnchorPart.Color = isInRange and config.PREVIEW_COLOR_IN_RANGE or config.PREVIEW_COLOR_OUT_OF_RANGE
	end

	if not previewBeam then
		setupPreview(hitPosition, isInRange)
	end

	-- ビームの色を更新
	if previewBeam then
		local beamColor = isInRange and config.PREVIEW_COLOR_IN_RANGE or config.PREVIEW_COLOR_OUT_OF_RANGE
		previewBeam.Color = ColorSequence.new(beamColor)
	end
end

local function setupVisuals(targetPosition: Vector3)
	clearVisuals()

	local root = getRootPart()
	if not root then
		return
	end

	visualRootAttachment = Instance.new("Attachment")
	visualRootAttachment.Name = "HookshotVisualRootAttachment"
	visualRootAttachment.Parent = root

	visualAnchorPart = Instance.new("Part")
	visualAnchorPart.Name = "HookshotVisualAnchor"
	visualAnchorPart.Anchored = true
	visualAnchorPart.CanCollide = false
	visualAnchorPart.CanTouch = false
	visualAnchorPart.CanQuery = false
	visualAnchorPart.Transparency = 0.3
	visualAnchorPart.Size = Vector3.new(1.2, 1.2, 1.2)
	visualAnchorPart.Color = config.BEAM_COLOR
	visualAnchorPart.Material = Enum.Material.Neon
	visualAnchorPart.CFrame = CFrame.new(targetPosition)
	visualAnchorPart.Parent = workspace

	visualAnchorAttachment = Instance.new("Attachment")
	visualAnchorAttachment.Name = "HookshotVisualAnchorAttachment"
	visualAnchorAttachment.Parent = visualAnchorPart

	visualBeam = Instance.new("Beam")
	visualBeam.Name = "HookshotBeam"
	visualBeam.Attachment0 = visualRootAttachment
	visualBeam.Attachment1 = visualAnchorAttachment
	visualBeam.Width0 = config.BEAM_WIDTH
	visualBeam.Width1 = config.BEAM_WIDTH
	visualBeam.FaceCamera = false
	visualBeam.Color = ColorSequence.new(config.BEAM_COLOR)
	visualBeam.LightEmission = 1
	visualBeam.LightInfluence = 0
	visualBeam.TextureLength = 2
	visualBeam.TextureMode = Enum.TextureMode.Stretch
	visualBeam.Enabled = true
	visualBeam.Parent = root

	-- デバッグ情報
	print("[Hookshot] ビームを作成しました:")
	print("  - Root Attachment:", visualRootAttachment, "Parent:", visualRootAttachment.Parent)
	print("  - Anchor Attachment:", visualAnchorAttachment, "Parent:", visualAnchorAttachment.Parent)
	print("  - Beam:", visualBeam, "Parent:", visualBeam.Parent)
	print("  - Beam Enabled:", visualBeam.Enabled)
	print("  - Beam Width:", visualBeam.Width0, visualBeam.Width1)
	print("  - Beam Color:", visualBeam.Color)
end

local function requestFire()
	if os.clock() < cooldownUntil then
		print("[HookshotClient] クールダウン中")
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		print("[HookshotClient] カメラが存在しません")
		return
	end

	local mouse = player:GetMouse()
	local origin = camera.CFrame.Position
	local target = mouse and mouse.Hit and mouse.Hit.Position or (origin + camera.CFrame.LookVector * config.MAX_RANGE)
	local direction = (target - origin)

	if direction.Magnitude < 0.001 then
		print("[HookshotClient] 方向が小さすぎます")
		return
	end

	print("[HookshotClient] フックショット発射要求:", direction.Unit)

	requestRemote:FireServer("Fire", {
		direction = direction.Unit,
	})
end

local function requestRelease()
	requestRemote:FireServer("Release")
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	print("[HookshotClient] InputBegan - UserInputType:", input.UserInputType, "gameProcessed:", gameProcessed)

	if gameProcessed then
		print("[HookshotClient] gameProcessedがtrueのため無視")
		return
	end

	if input.UserInputType ~= config.INPUT_TYPE then
		print("[HookshotClient] 入力タイプが一致しません:", input.UserInputType, "期待値:", config.INPUT_TYPE)
		return
	end

	print("[HookshotClient] 正しい入力がされました！")

	if isHooked then
		print("[HookshotClient] 既にフック中、リリース要求")
		requestRelease()
	else
		print("[HookshotClient] フックショット発射")
		isAiming = true
		requestFire()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.UserInputType ~= config.INPUT_TYPE then
		return
	end

	if isAiming and not isHooked then
		isAiming = false
		if not config.ALWAYS_SHOW_PREVIEW then
			clearPreview()
		end
	end
end)

-- プレビュー更新ループ
RunService.RenderStepped:Connect(function()
	updatePreview()
end)

stateRemote.OnClientEvent:Connect(function(action: string, payload)
	print("[HookshotClient] サーバーからイベント受信:", action)

	if action == "Started" then
		print("[HookshotClient] フックショット開始")
		isHooked = true
		isAiming = false
		clearPreview()
		anchorPosition = payload and payload.anchorPosition or nil
		local cooldown = (payload and payload.cooldown) or config.COOLDOWN
		cooldownUntil = os.clock() + cooldown

		print("[HookshotClient] アンカー位置:", anchorPosition)

		if typeof(anchorPosition) == "Vector3" then
			setupVisuals(anchorPosition)
		end
		return
	end

	if action == "Cooldown" then
		print("[HookshotClient] クールダウン通知")
		local remaining = payload and payload.remaining
		if typeof(remaining) == "number" and remaining > 0 then
			cooldownUntil = math.max(cooldownUntil, os.clock() + remaining)
		end
		return
	end

	if action == "Ended" then
		print("[HookshotClient] フックショット終了, 理由:", payload and payload.reason)
		isHooked = false
		isAiming = false
		anchorPosition = nil
		clearVisuals()
		clearPreview()
	end
end)

player.CharacterAdded:Connect(function(character)
	print("[HookshotClient] CharacterAdded:", character.Name)
	isHooked = false
	isAiming = false
	anchorPosition = nil
	clearVisuals()
	clearPreview()
end)

-- 既にキャラクターが存在する場合
if player.Character then
	print("[HookshotClient] 既存のキャラクター:", player.Character.Name)
end

print("[HookshotClient] スクリプト初期化完了")
