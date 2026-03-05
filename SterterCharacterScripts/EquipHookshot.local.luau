local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent

local hookshotModel = ReplicatedStorage:WaitForChild("GrapplingHook")

-- グラップリングフックを装備する関数
local function equipHookshot()
	local humanoid = character:WaitForChild("Humanoid")
	local rightArm = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	
	if not rightArm then
		return
	end

	-- 既に装備されている場合はスキップ
	if character:FindFirstChild("GrapplingHook") then
		return
	end

	-- モデルをクローン
	local hookshot = hookshotModel:Clone()
	hookshot.Name = "GrapplingHook"
	hookshot.Parent = character

	-- Weldで右腕に取り付け
	local handle = hookshot:FindFirstChild("Handle")
	if handle then
		local weld = Instance.new("WeldConstraint")
		weld.Name = "ArmWeld"
		weld.Part0 = rightArm
		weld.Part1 = handle
		weld.Parent = handle

		-- 位置と回転を調整
		handle.CFrame = rightArm.CFrame * CFrame.new(0.5, 0, 0.5) * CFrame.Angles(math.rad(-90), 0, 0)
	end
end

-- キャラクターがスポーンしたときに装備
if character.Parent then
	equipHookshot()
end

-- フックショット中にアニメーションを追加
local isHooked = false

local remotes = ReplicatedStorage:WaitForChild("HookshotRemotes")
local stateRemote = remotes:WaitForChild("State")

stateRemote.OnClientEvent:Connect(function(action, data)
	if action == "Started" then
		isHooked = true
	elseif action == "Ended" then
		isHooked = false
	end
end)

-- フックショット中にグラップリングフックをアニメーション
RunService.RenderStepped:Connect(function(dt)
	local hookshot = character:FindFirstChild("GrapplingHook")
	if not hookshot then
		return
	end

	local hook = hookshot:FindFirstChild("Hook")
	local motor = hook and hook:FindFirstChild("Motor6D")

	if motor then
		if isHooked then
			-- フックショット中はフックを開く
			motor.C0 = CFrame.new(0, 0, -0.8) * CFrame.Angles(0, 0, math.rad(90))
		else
			-- 通常時はフックを閉じる
			motor.C0 = CFrame.new(0, 0, -0.8) * CFrame.Angles(0, 0, math.rad(45))
		end
	end
end)