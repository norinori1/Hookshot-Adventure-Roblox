local HookshotConfig = {
	-- 操作
	INPUT_KEY = Enum.KeyCode.Q,

	-- 基本パラメータ
	MAX_RANGE = 150,
	COOLDOWN = 3,
	MAX_HOOK_TIME = 6,

	-- ロープ挙動（Apex風の引っ張り＋スイング寄り）
	MIN_ROPE_LENGTH = 5,
	REEL_SPEED = 50,
	SPRING_STIFFNESS = 60, -- 加速度ベース
	DAMPING = 12, -- ロープ方向の速度を減衰
	CONSTANT_PULL = 20, -- 常時引き寄せ
	RELEASE_DISTANCE = 3,

	-- 見た目
	BEAM_WIDTH = 0.4,
	BEAM_COLOR = Color3.fromRGB(255, 200, 50),
}

return HookshotConfig
