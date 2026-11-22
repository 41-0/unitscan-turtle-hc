local unitscan = CreateFrame('Frame', 'UnitscanTurtleHC')
unitscan:SetScript('OnUpdate', function() unitscan.UPDATE() end)
unitscan:SetScript('OnEvent', function() 
	if event == "VARIABLES_LOADED" then
		unitscan.LOAD()
		unitscan.loaded = true
		unitscan.create_minimap_button()
	elseif event == "PLAYER_REGEN_DISABLED" then
		unitscan.incombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		unitscan.incombat = nil
	elseif event == "PLAYER_ENTER_COMBAT" then
		unitscan.melee = true
	elseif event == "PLAYER_LEAVE_COMBAT" then
		unitscan.melee = nil
	elseif event == "START_AUTOREPEAT_SPELL" then
		unitscan.ranged = true
	elseif event == "STOP_AUTOREPEAT_SPELL" then
		unitscan.ranged = nil
	else
		unitscan.load_zonetargets()
	end
end)

unitscan:RegisterEvent'VARIABLES_LOADED'
unitscan:RegisterEvent'MINIMAP_ZONE_CHANGED'
unitscan:RegisterEvent'PLAYER_ENTERING_WORLD'
unitscan:RegisterEvent'PLAYER_REGEN_DISABLED' -- in combat
unitscan:RegisterEvent'PLAYER_REGEN_ENABLED' -- out of combat
unitscan:RegisterEvent'PLAYER_ENTER_COMBAT' -- melee autoattack enabled
unitscan:RegisterEvent'PLAYER_LEAVE_COMBAT' -- melee autoattack disabled
unitscan:RegisterEvent'START_AUTOREPEAT_SPELL' -- ranged autoattack enabled
unitscan:RegisterEvent'STOP_AUTOREPEAT_SPELL' -- ranged autoattack disabled

local BROWN = {.7, .15, .05}
local YELLOW = {1, 1, .15}
local CHECK_INTERVAL = 1

unitscan_targets = {}

local defaults = {
	enabled = true,
	sound = [[Sound\Interface\RaidWarning.wav]],
	scale = 1,
	flash = true,
	minimum = 10,
	pauseInCombat = false,
	showModel = true,
}
unitscan.defaults = defaults

function unitscan.trim(value)
	local _, _, trimmed = strfind(value, '^%s*(.-)%s*$')
	return trimmed
end

local alerts = {}
local alertsByName = {}
local availablePlates = {}

function unitscan.layout_alerts()
	for i, plate in ipairs(alerts) do
		plate:ClearAllPoints()
		plate:SetPoint('BOTTOM', unitscan.anchor, 'BOTTOM', 0, (i - 1) * 70)
	end
end

function unitscan.hide_model()
	unitscan.modelPlate = nil
	unitscan.model:Hide()
end

function unitscan.remove_alert(plate)
	alertsByName[plate.key] = nil
	for i, active in ipairs(alerts) do
		if active == plate then
			table.remove(alerts, i)
			break
		end
	end
	if unitscan.modelPlate == plate then unitscan.hide_model() end
	if plate.moving then unitscan.anchor:StopMovingOrSizing() end
	plate:Hide()
	plate.zoneTargets = nil
	plate.zoneName = nil
	tinsert(availablePlates, plate)
end

function unitscan.clear_alerts()
	while alerts[1] do unitscan.remove_alert(alerts[1]) end
end

function unitscan.stop_flash()
	unitscan.flash.animation:Hide()
	unitscan.flash.animation.t0 = nil
	unitscan.flash:SetAlpha(0)
end

function unitscan.ignore(name)
	name = unitscan.trim(name)
	if name == '' then return end

	local key = strupper(name)
	unitscan_settings.ignored[key] = name
	local plate = alertsByName[key]
	if plate then
		if plate.zoneTargets and plate.zoneTargets == unitscan_zonetargets then
			plate.zoneTargets[plate.zoneName] = true
		end
		unitscan.remove_alert(plate)
		unitscan.layout_alerts()
		if not alerts[1] then unitscan.stop_flash() end
	end
end

do
	local last_played
	
	function unitscan.play_sound()
		if not last_played or GetTime() - last_played > 10 then
			PlaySoundFile(unitscan_settings.sound)
			last_played = GetTime()
		end
	end
end

function unitscan.load_zonetargets()
	unitscan_zone_targets()
end

do 
	local prevTarget
	local foundTarget
	local _PlaySound = PlaySound
	local _UIErrorsFrame_OnEvent = UIErrorsFrame_OnEvent
	local pass = function() end

	function unitscan.reset()
		prevTarget = nil
		foundTarget = nil
	end

	function unitscan.restoreTarget()
		if foundTarget and (not (prevTarget == foundTarget)) then
			PlaySound = pass
			if prevTarget then
				TargetLastTarget()
			else
				ClearTarget()
			end
			PlaySound = _PlaySound
		end
		unitscan.reset()
	end

	local function check_list(targets, on_found, is_zone, now)
		for name in pairs(targets) do
			local key = strupper(name)
			if not unitscan_settings.ignored[key] and not alertsByName[key] then
				if key == unitscan.target(name) then
					local plate = table.remove(availablePlates) or unitscan.create_plate()
					plate.key = key
					plate.shownAt = now
					plate.zoneTargets = is_zone and targets
					plate.zoneName = is_zone and name
					plate:set_target()
					alertsByName[key] = plate
					tinsert(alerts, plate)
					unitscan.foundTarget = plate:GetText()
					on_found(name)
					unitscan.play_sound()
					if unitscan_settings.flash then unitscan.flash.animation:Play() end
				end
				unitscan.restoreTarget()
			end
		end
	end

	local function refresh_model()
		local newest = alerts[table.getn(alerts)]
		if not unitscan_settings.showModel or not newest or unitscan.modelPlate == newest then
			return
		end
		unitscan.hide_model()
		if newest.key == unitscan.target(newest:GetText()) then
			local model = unitscan.model
			model:ClearAllPoints()
			model:SetPoint('BOTTOM', newest, 'TOP', 0, 10)
			model:reset()
			model:SetUnit('target')
			model:Show()
			unitscan.modelPlate = newest
		end
		unitscan.restoreTarget()
	end

	function unitscan.check_for_targets(now)
		for i = table.getn(alerts), 1, -1 do
			local plate = alerts[i]
			if now - plate.shownAt >= unitscan_settings.minimum then
				local found = plate.key == unitscan.target(plate:GetText())
				unitscan.restoreTarget()
				if not found then unitscan.remove_alert(plate) end
			end
		end

		check_list(unitscan_targets, unitscan.toggle_target, false, now)
		check_list(unitscan_zonetargets or {}, unitscan.toggle_zonetarget, true, now)
		unitscan.layout_alerts()
		refresh_model()
	end

	function unitscan.target(name)
		prevTarget = UnitName("target")
		if not prevTarget or strupper(prevTarget) ~= strupper(name) then
			UIErrorsFrame_OnEvent = pass
			PlaySound = pass
			TargetByName(name, true)
			UIErrorsFrame_OnEvent = _UIErrorsFrame_OnEvent
			PlaySound = _PlaySound
		end

		foundTarget = UnitName("target")
		-- Player target
		if UnitIsPlayer("target") then
			return foundTarget and strupper(foundTarget)
		-- NPC target
		elseif (not UnitIsDead("target")) and UnitCanAttack("target", "player") then
			return foundTarget and strupper(foundTarget)
		end
	end
end

function unitscan.LOAD()
	if type(unitscan_settings) ~= 'table' then unitscan_settings = {} end
	for key, value in pairs(defaults) do
		if type(unitscan_settings[key]) ~= type(value) then
			unitscan_settings[key] = value
		end
	end
	if type(unitscan_settings.ignored) ~= 'table' then unitscan_settings.ignored = {} end
	do
		local flash = CreateFrame'Frame'
		unitscan.flash = flash
		flash:Show()
		flash:SetAllPoints()
		flash:SetAlpha(0)
		flash:SetFrameStrata'FULLSCREEN_DIALOG'
		
		local texture = flash:CreateTexture()
		texture:SetBlendMode'ADD'
		texture:SetAllPoints()
		texture:SetTexture[[Interface\FullScreenTextures\LowHealth]]

		flash.animation = CreateFrame'Frame'
		flash.animation:Hide()
		flash.animation:SetScript('OnUpdate', function()
			local t = GetTime() - this.t0
			if t <= .5 then
				flash:SetAlpha(t * 2)
			elseif t <= 1 then
				flash:SetAlpha(1)
			elseif t <= 1.5 then
				flash:SetAlpha(1 - (t - 1) * 2)
			else
				flash:SetAlpha(0)
				this.loops = this.loops - 1
				if this.loops == 0 then
					this.t0 = nil
					this:Hide()
				else
					this.t0 = GetTime()
				end
			end
		end)
		function flash.animation:Play()
			if self.t0 then
				self.loops = 4
			else
				self.t0 = GetTime()
				self.loops = 3
			end
			self:Show()
		end
	end
	
	local anchor = CreateFrame('Frame', 'unitscan_button', UIParent)
	unitscan.anchor = anchor
	anchor:SetPoint('BOTTOM', UIParent, 0, 148)
	anchor:SetWidth(200)
	anchor:SetHeight(42)
	anchor:SetScale(unitscan_settings.scale)
	anchor:SetMovable(true)
	anchor:SetUserPlaced(true)
	anchor:SetClampedToScreen(true)
	anchor:SetFrameStrata('FULLSCREEN_DIALOG')
	do
		local model = CreateFrame('PlayerModel', nil, anchor)
		unitscan.model = model
		model:Hide()
		model:SetWidth(200)
		model:SetHeight(120)
		
		do
			local last_update, delay
			function model:on_update()
				this:SetFacing(this:GetFacing() + (GetTime() - last_update) * math.pi / 4)
				last_update = GetTime()
			end
			
			function model:on_update_model()
				if delay > 0 then
					delay = delay - 1
					return
				end
				
				this:SetScript('OnUpdateModel', nil)
				this:SetScript('OnUpdate', this.on_update)
				this:SetModelScale(1)
				this:SetAlpha(1)	
				last_update = GetTime()
			end
			
			function model:reset()
				self:SetAlpha(0)
				self:SetFacing(0)
				self:SetModelScale(1)
				self:ClearModel()
				self:SetScript('OnUpdate', nil)
				self:SetScript("OnUpdateModel", self.on_update_model)
				delay = 10 -- to prevent scaling bugs
			end
		end
	end
	end

function unitscan.create_plate()
	local anchor = unitscan.anchor
	local button = CreateFrame('Button', nil, anchor)
	button:Hide()
	button:SetWidth(200)
	button:SetHeight(42)
	button:RegisterForClicks('LeftButtonUp')
	button:SetScript('OnMouseDown', function()
		if IsControlKeyDown() then
			this.moving = true
			anchor:StartMoving()
		end
	end)
	button:SetScript('OnMouseUp', function()
		if this.moving then anchor:StopMovingOrSizing() end
	end)

	button:SetBackdrop{
		tile = true,
		edgeSize = 16,
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	}
	button:SetBackdropBorderColor(unpack(BROWN))
	button:SetScript('OnEnter', function()
		this:SetBackdropBorderColor(unpack(YELLOW))
	end)
	button:SetScript('OnLeave', function()
		this:SetBackdropBorderColor(unpack(BROWN))
	end)
	button:SetScript('OnClick', function()
		if not this.moving then TargetByName(this:GetText(), true) end
		this.moving = nil
	end)
	function button:set_target()
		self:SetText(UnitName'target')

		self.moving = nil

		self:Show()
		self.glow.animation:Play()
		self.shine.animation:Play()
	end

	do
		local background = button:CreateTexture(nil, 'BACKGROUND')
		background:SetTexture[[Interface\AddOns\unitscan-turtle-hc\UI-Achievement-Parchment-Horizontal]]
		background:SetPoint('BOTTOMLEFT', 3, 3)
		background:SetPoint('TOPRIGHT', -3, -3)
		background:SetTexCoord(0, 1, 0, .25)
	end
	
	do
		local title_background = button:CreateTexture(nil, 'BORDER')
		title_background:SetTexture[[Interface\AddOns\unitscan-turtle-hc\UI-Achievement-Title]]
		title_background:SetPoint('TOPRIGHT', -5, -5)
		title_background:SetPoint('LEFT', 5, 0)
		title_background:SetHeight(18)
		title_background:SetTexCoord(0, .9765625, 0, .3125)
		title_background:SetAlpha(.8)

		local title = button:CreateFontString(nil, 'OVERLAY')
		title:SetFont([[Fonts\FRIZQT__.TTF]], 14)
		title:SetShadowOffset(1, -1)
		title:SetPoint('TOPLEFT', title_background, 0, 0)
		title:SetPoint('RIGHT', title_background)
		button:SetFontString(title)

		local subtitle = button:CreateFontString(nil, 'OVERLAY')
		subtitle:SetFont([[Fonts\FRIZQT__.TTF]], 12)
		subtitle:SetTextColor(0, 0, 0)
		subtitle:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
		subtitle:SetPoint('RIGHT', title )
		subtitle:SetText'Unit Found!'
	end
	

	do
		local close = CreateFrame('Button', nil, button, 'UIPanelCloseButton')
		close:SetPoint('TOPRIGHT', 0, 0)
		close:SetWidth(32)
		close:SetHeight(32)
		close:SetScale(.8)
		close:SetHitRectInsets(8, 8, 8, 8)
		close:SetScript('OnClick', function()
			unitscan.remove_alert(button)
			unitscan.layout_alerts()
		end)
	end

	do
		local ignore = CreateFrame('Button', nil, button, 'UIPanelButtonTemplate')
		ignore:SetPoint('TOP', button, 'BOTTOM', 0, -3)
		ignore:SetWidth(140)
		ignore:SetHeight(22)
		ignore:SetText('Ignore This Mob')
		ignore:SetScript('OnClick', function()
			unitscan.ignore(button:GetText())
		end)
	end
	
	do
		local glow = button:CreateTexture(nil, 'ARTWORK')
		button.glow = glow
		glow:SetPoint('CENTER', button, 'CENTER')
		glow:SetWidth(400 / 300 * button:GetWidth())
		glow:SetHeight(171 / 70 * button:GetHeight())
		glow:SetTexture[[Interface\AddOns\unitscan-turtle-hc\UI-Achievement-Alert-Glow]]
		glow:SetBlendMode'ADD'
		glow:SetTexCoord(0, .78125, 0, .66796875)
		glow:SetAlpha(0)

		glow.animation = CreateFrame'Frame'
		glow.animation:Hide()
		glow.animation:SetScript('OnUpdate', function()
			local t = GetTime() - this.t0
			if t <= .2 then
				glow:SetAlpha(t * 5)
			elseif t <= .7 then
				glow:SetAlpha(1 - (t - .2) * 2)
			else
				glow:SetAlpha(0)
				this:Hide()
			end
		end)
		function glow.animation:Play()
			self.t0 = GetTime()
			self:Show()
		end
	end

	do
		local shine = button:CreateTexture(nil, 'ARTWORK')
		button.shine = shine
		shine:SetPoint('TOPLEFT', button, 0, 8)
		shine:SetWidth(67 / 300 * button:GetWidth())
		shine:SetHeight(1.28 * button:GetHeight())
		shine:SetTexture[[Interface\AddOns\unitscan-turtle-hc\UI-Achievement-Alert-Glow]]
		shine:SetBlendMode'ADD'
		shine:SetTexCoord(.78125, .912109375, 0, .28125)
		shine:SetAlpha(0)
		
		shine.animation = CreateFrame'Frame'
		shine.animation:Hide()
		shine.animation:SetScript('OnUpdate', function()
			local t = GetTime() - this.t0
			if t <= .3 then
				shine:SetPoint('TOPLEFT', button, 0, 8)
			elseif t <= .7 then
				shine:SetPoint('TOPLEFT', button, (t - .3) * 2.5 * this.distance, 8)
			end
			if t <= .3 then
				shine:SetAlpha(0)
			elseif t <= .5 then
				shine:SetAlpha(1)
			elseif t <= .7 then
				shine:SetAlpha(1 - (t - .5) * 5)
			else
				shine:SetAlpha(0)
				this:Hide()
			end
		end)
		function shine.animation:Play()
			self.t0 = GetTime()
			self.distance = button:GetWidth() - shine:GetWidth() + 8
			self:Show()
		end
	end
	return button
end

local last_check = GetTime()

function unitscan.UPDATE()
	if not unitscan.loaded or not unitscan_settings.enabled then return end
	if unitscan_settings.pauseInCombat and (unitscan.incombat or unitscan.melee or unitscan.ranged) then
		return
	end

	local now = GetTime()
	if now - last_check < CHECK_INTERVAL then return end
	last_check = now
	if unitscan.reloadtimer and now >= unitscan.reloadtimer then
		unitscan.reloadtimer = nil
		unitscan.load_zonetargets()
	end
	unitscan.check_for_targets(now)
end

function unitscan.print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE .. '<unitscan> ' .. msg)
	end
end

function unitscan.sorted_targets()
	local sorted_targets = {}
	for key in pairs(unitscan_targets) do
		tinsert(sorted_targets, key)
	end
	sort(sorted_targets, function(key1, key2) return key1 < key2 end)
	return sorted_targets
end

function unitscan.sorted_zonetargets()
	local sorted_targets = {}
	for key in pairs(unitscan_zonetargets or {}) do
		tinsert(sorted_targets, key)
	end
	sort(sorted_targets, function(key1, key2) return key1 < key2 end)
	return sorted_targets
end

function unitscan.toggle_target(name)
	local key = strupper(name)
	if unitscan_targets[key] then
		unitscan_targets[key] = nil
		unitscan.print('- ' .. key)
	elseif key ~= '' then
		unitscan_targets[key] = true
		unitscan.print('+ ' .. key)
	end
end

function unitscan.toggle_zonetarget(name)
	local key = name
	if unitscan_zonetargets[key] then
		unitscan.print(key .. ' was found!')
		unitscan_zonetargets[key] = nil
		unitscan.reloadtimer = GetTime() + 90
	end
end
	
SLASH_UNITSCAN1 = '/unitscan'
function SlashCmdList.UNITSCAN(parameter)
	local _, _, name = strfind(parameter, '^%s*(.-)%s*$')
	
	if strlower(name) == 'options' then
		unitscan.toggle_options()
	elseif name == '' then
		unitscan.print("Added targets:")
		for _, key in ipairs(unitscan.sorted_targets()) do
			unitscan.print(key)
		end
		-- zone targets
		unitscan.print("Zone targets:")
		for _, key in ipairs(unitscan.sorted_zonetargets()) do
			unitscan.print(key)
		end
	else
		unitscan.toggle_target(name)
	end
end

SLASH_UNITSCANTARGET1 = '/unitscantarget'
function SlashCmdList.UNITSCANTARGET()
	if unitscan.foundTarget and not unitscan_settings.ignored[strupper(unitscan.foundTarget)] then
		TargetByName(unitscan.foundTarget, true)
	end
end
