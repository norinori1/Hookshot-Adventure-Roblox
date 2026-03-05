local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

print("[HookshotServer] サーバースクリプト開始")

local config = require(ReplicatedStorage:WaitForChild("HookshotConfig"))
print("[HookshotServer] Config読み込み完了")

type HookState = {
	active: boolean,
	lastUseTime: number,
	startedAt: number,
	desiredLength: number,
	anchorPart: BasePart?,
	anchorAttachment: Attachment?,
	forceAttachment: Attachment?,
	vectorForce: VectorForce?,
	heartbeatConn: RBXScriptConnection?,
}

local remotes = ReplicatedStorage:FindFirstChild("HookshotRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "HookshotRemotes"
	remotes.Parent = ReplicatedStorage
end

local requestRemote = remotes:FindFirstChild("Request") :: RemoteEvent?
if not requestRemote then
	requestRemote = Instance.new("RemoteEvent")
	requestRemote.Name = "Request"
	requestRemote.Parent = remotes
end

local stateRemote = remotes:FindFirstChild("State") :: RemoteEvent?
if not stateRemote then
	stateRemote = Instance.new("RemoteEvent")
	stateRemote.Name = "State"
	stateRemote.Parent = remotes
end

local playerStates: {[Player]: HookState} = {}

local function getOrCreateState(player: Player): HookState
	if playerStates[player] then
		return playerStates[player]
	end

	local state: HookState = {
		active = false,
		lastUseTime = -math.huge,
		startedAt = 0,
		desiredLength = 0,
		anchorPart = nil,
		anchorAttachment = nil,
		forceAttachment = nil,
		vectorForce = nil,
		heartbeatConn = nil,
	}

	playerStates[player] = state
	return state
end

local function cleanupHook(player: Player, reason: string?)
	local state = playerStates[player]
	if not state then
		return
	end

	state.active = false

	if state.heartbeatConn then
		state.heartbeatConn:Disconnect()
		state.heartbeatConn = nil
	end

	if state.vectorForce then
		state.vectorForce:Destroy()
		state.vectorForce = nil
	end

	if state.forceAttachment then
		state.forceAttachment:Destroy()
		state.forceAttachment = nil
	end

	if state.anchorAttachment then
		state.anchorAttachment:Destroy()
		state.anchorAttachment = nil
	end

	if state.anchorPart then
		state.anchorPart:Destroy()
		state.anchorPart = nil
	end

	-- フック解除後に浮遊を適用
	if reason ~= "NoHit" and reason ~= "Cooldown" then
		applyFloating(player)
	end

	stateRemote:FireClient(player, "Ended", {
		reason = reason or "Released",
	})
end

local function applyFloating(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return
	end

	-- 浮遊を開始
	print("[HookshotServer] 浮遊開始:", player.Name)

	-- HumanoidのPlatformStandを有効にして重力を無効化
	humanoid.PlatformStand = true

	-- 上向きの力を適用
	local floatForce = Instance.new("VectorForce")
	floatForce.Name = "FloatForce"
	floatForce.RelativeTo = Enum.ActuatorRelativeTo.World
	floatForce.ApplyAtCenterOfMass = true
	floatForce.Force = Vector3.new(0, config.FLOAT_VELOCITY * root.AssemblyMass, 0)
	floatForce.Parent = root

	-- 指定時間後に浮遊を解除
	task.delay(config.FLOAT_DURATION, function()
		if floatForce and floatForce.Parent then
			floatForce:Destroy()
		end

		if humanoid and humanoid.Parent then
			humanoid.PlatformStand = false
		end

		print("[HookshotServer] 浮遊終了:", player.Name)
	end)
end

local function startHook(player: Player, direction: Vector3)
	print("[HookshotServer] startHook 開始:", player.Name)

	local state = getOrCreateState(player)
	local now = os.clock()
	local cooldownRemaining = config.COOLDOWN - (now - state.lastUseTime)

	print("[HookshotServer] クールダウン残り時間:", cooldownRemaining)

	if cooldownRemaining > 0 then
		print("[HookshotServer] クールダウン中")
		stateRemote:FireClient(player, "Cooldown", {
			remaining = cooldownRemaining,
		})
		return
	end

	if state.active then
		print("[HookshotServer] 既にアクティブ、クリーンアップ")
		cleanupHook(player, "Replaced")
	end

	local character = player.Character
	if not character then
		print("[HookshotServer] キャラクターが存在しません")
		return
	end

	print("[HookshotServer] キャラクター存在:", character.Name)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	print("[HookshotServer] Humanoid:", humanoid ~= nil, "Root:", root ~= nil)

	if not humanoid or not root or humanoid.Health <= 0 then
		print("[HookshotServer] HumanoidまたはRootが無効")
		return
	end

	if direction.Magnitude < 0.001 then
		print("[HookshotServer] 方向が小さすぎます")
		return
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	rayParams.IgnoreWater = false

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	print("[HookshotServer] レイキャスト開始:", origin, "方向:", direction.Unit * config.MAX_RANGE)

	local result = Workspace:Raycast(origin, direction.Unit * config.MAX_RANGE, rayParams)

	if not result then
		print("[HookshotServer] ヒットなし")
		stateRemote:FireClient(player, "Ended", {
			reason = "NoHit",
		})
		return
	end

	print("[HookshotServer] ヒット成功:", result.Position, "Instance:", result.Instance.Name)

	local anchorPart = Instance.new("Part")
	anchorPart.Name = "HookshotAnchor"
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CanTouch = false
	anchorPart.Transparency = 1
	anchorPart.Size = Vector3.new(0.2, 0.2, 0.2)
	anchorPart.CFrame = CFrame.new(result.Position)
	anchorPart.Parent = Workspace

	print("[HookshotServer] アンカーパーツ作成:", anchorPart.Position)

	local anchorAttachment = Instance.new("Attachment")
	anchorAttachment.Name = "HookshotAnchorAttachment"
	anchorAttachment.Parent = anchorPart

	local forceAttachment = Instance.new("Attachment")
	forceAttachment.Name = "HookshotForceAttachment"
	forceAttachment.Parent = root

	print("[HookshotServer] Attachment作成完了")

	local vectorForce = Instance.new("VectorForce")
	vectorForce.Name = "HookshotVectorForce"
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.Attachment0 = forceAttachment
	vectorForce.Force = Vector3.zero
	vectorForce.Parent = root

	print("[HookshotServer] VectorForce作成完了")

	state.active = true
	state.lastUseTime = now
	state.startedAt = now
	state.desiredLength = (anchorPart.Position - root.Position).Magnitude
	state.anchorPart = anchorPart
	state.anchorAttachment = anchorAttachment
	state.forceAttachment = forceAttachment
	state.vectorForce = vectorForce

	print("[HookshotServer] ステート設定完了, ロープ長:", state.desiredLength)

	stateRemote:FireClient(player, "Started", {
		anchorPosition = anchorPart.Position,
		cooldown = config.COOLDOWN,
	})

	print("[HookshotServer] クライアントにStarted通知送信")

	state.heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		if not state.active then
			return
		end

		if not character.Parent then
			cleanupHook(player, "CharacterRemoved")
			return
		end

		if humanoid.Health <= 0 then
			cleanupHook(player, "HumanoidDead")
			return
		end

		if os.clock() - state.startedAt > config.MAX_HOOK_TIME then
			cleanupHook(player, "Timeout")
			return
		end

		if not state.anchorPart or not state.vectorForce then
			cleanupHook(player, "InvalidState")
			return
		end

		-- ロープの長さを徐々に短くする
		state.desiredLength = math.max(config.MIN_ROPE_LENGTH, state.desiredLength - config.REEL_SPEED * dt)

		local toAnchor = state.anchorPart.Position - root.Position
		local distance = toAnchor.Magnitude
		if distance < 0.001 then
			state.vectorForce.Force = Vector3.zero
			return
		end

		-- アンカーに近づいたらフックを解除
		if distance <= config.RELEASE_DISTANCE then
			cleanupHook(player, "Reached")
			return
		end

		local dir = toAnchor / distance
		local stretch = math.max(0, distance - state.desiredLength)
		local velocityAlongRope = root.AssemblyLinearVelocity:Dot(dir)

		-- Momentum-Hookshot風の物理計算
		-- 現在の速度を維持しつつ、アンカー方向に加速
		local currentVelocity = root.AssemblyLinearVelocity
		local velocityMagnitude = currentVelocity.Magnitude

		-- ロープが伸びている場合のみ力を適用
		if stretch > 0 then
			-- 速度制限チェック
			if velocityMagnitude > config.MAX_VELOCITY then
				-- 速度が制限を超えた場合、フックを解除
				cleanupHook(player, "MaxVelocity")
				return
			end

			-- バネ力 + 常時引き寄せ
			local springForce = stretch * config.SPRING_STIFFNESS
			local pullForce = config.CONSTANT_PULL

			-- 減衰（ロープ方向の速度を減らす）
			local dampingForce = math.max(0, velocityAlongRope) * config.DAMPING

			-- 合計の加速度
			local accel = springForce + pullForce - dampingForce
			accel = math.max(0, accel)

			-- 運動量を維持しつつ加速（低い値で振動を抑制）
			local momentumBoost = velocityMagnitude * config.MOMENTUM_MULTIPLIER
			accel = accel + momentumBoost

			state.vectorForce.Force = dir * accel * root.AssemblyMass
		else
			-- ロープが張っている状態では、ロープ方向の速度を制限
			if velocityAlongRope > 0 then
				-- ロープ方向に進もうとする速度を打ち消す
				local cancelForce = velocityAlongRope * root.AssemblyMass * 10
				state.vectorForce.Force = -dir * cancelForce
			else
				state.vectorForce.Force = Vector3.zero
			end
		end
	end)
end

requestRemote.OnServerEvent:Connect(function(player: Player, action: string, payload)
	print("[HookshotServer] リクエスト受信:", player.Name, "Action:", action)

	if action == "Release" then
		print("[HookshotServer] リリース要求")
		cleanupHook(player, "Released")
		return
	end

	if action ~= "Fire" then
		print("[HookshotServer] 不明なアクション:", action)
		return
	end

	if typeof(payload) ~= "table" then
		print("[HookshotServer] ペイロードがテーブルではありません")
		return
	end

	local direction = payload.direction
	if typeof(direction) ~= "Vector3" then
		print("[HookshotServer] 方向がVector3ではありません:", typeof(direction))
		return
	end

	print("[HookshotServer] フックショット発射開始:", direction)
	startHook(player, direction)
end)

Players.PlayerRemoving:Connect(function(player)
	print("[HookshotServer] PlayerRemoving:", player.Name)
	cleanupHook(player, "PlayerRemoving")
	playerStates[player] = nil
end)

print("[HookshotServer] サーバースクリプト初期化完了")