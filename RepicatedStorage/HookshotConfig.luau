local HookshotConfig = {
	-- 操作
	INPUT_TYPE = Enum.UserInputType.MouseButton1, -- マウス左クリック

	-- 基本パラメータ
	MAX_RANGE = 150,
	COOLDOWN = 2,
	MAX_HOOK_TIME = 8,

	-- ロープ挙動（Momentum-Hookshot風）
	MIN_ROPE_LENGTH = 3,
	REEL_SPEED = 80, -- 引き寄せ速度
	SPRING_STIFFNESS = 80, -- バネの強さ
	DAMPING = 15, -- 減衰（高いほど振動しにくい）
	CONSTANT_PULL = 30, -- 常時引き寄せる力
	RELEASE_DISTANCE = 8, -- アンカーにこの距離まで近づいたらフック解除

	-- 運動量維持
	MOMENTUM_MULTIPLIER = 0.5, -- 現在の速度を維持しつつ加速（低いほど振動しにくい）
	MAX_VELOCITY = 100, -- 最大速度制限

	-- 見た目
	BEAM_WIDTH = 0.3,
	BEAM_COLOR = Color3.fromRGB(255, 200, 50),
	
	-- プレビュー設定
	PREVIEW_COLOR_IN_RANGE = Color3.fromRGB(255, 255, 255),
	PREVIEW_COLOR_OUT_OF_RANGE = Color3.fromRGB(255, 50, 50),
	ALWAYS_SHOW_PREVIEW = true, -- 常にプレビューを表示

	-- フック解除後の浮遊
	FLOAT_DURATION = 3, -- 浮遊時間（秒）
	FLOAT_VELOCITY = 10, -- 浮遊速度
}

return HookshotConfig