local unitscan = UnitscanTurtleHC
local PAGE_SIZE = 7
local MINIMAP_RADIUS = 78
local scan_checkbox
local minimap_button
local minimap_icon

local function update_scan_controls()
	local enabled = unitscan_settings.enabled
	if scan_checkbox then scan_checkbox:SetChecked(enabled and 1 or 0) end
	if minimap_icon then
		local brightness = enabled and 1 or 0.45
		minimap_icon:SetVertexColor(brightness, brightness, brightness)
	end
end

function unitscan.set_scan_enabled(enabled)
	unitscan_settings.enabled = enabled
	if not enabled then
		unitscan.clear_alerts()
		unitscan.stop_flash()
	end
	update_scan_controls()
end

local function label(parent, text, x, y, font)
	local widget = parent:CreateFontString(nil, 'OVERLAY', font or 'GameFontNormal')
	widget:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
	widget:SetText(text)
	return widget
end

local function button(parent, text, x, y, width, on_click)
	local widget = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
	widget:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
	widget:SetWidth(width)
	widget:SetHeight(24)
	widget:SetText(text)
	widget:SetScript('OnClick', on_click)
	return widget
end

local function input(parent, name, x, y, width, limit)
	local widget = CreateFrame('EditBox', name, parent, 'InputBoxTemplate')
	widget:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
	widget:SetWidth(width)
	widget:SetHeight(24)
	widget:SetMaxLetters(limit)
	widget:SetAutoFocus(false)
	widget:SetScript('OnEscapePressed', function() this:ClearFocus() end)
	return widget
end

local function checkbox(parent, text, y, on_click)
	local widget = CreateFrame('CheckButton', nil, parent)
	widget:SetPoint('TOPLEFT', parent, 'TOPLEFT', 18, y)
	widget:SetWidth(26)
	widget:SetHeight(26)
	widget:SetNormalTexture([[Interface\Buttons\UI-CheckBox-Up]])
	widget:SetPushedTexture([[Interface\Buttons\UI-CheckBox-Down]])
	widget:SetHighlightTexture([[Interface\Buttons\UI-CheckBox-Highlight]], 'ADD')
	widget:SetCheckedTexture([[Interface\Buttons\UI-CheckBox-Check]])
	label(parent, text, 50, y - 6)
	widget:SetScript('OnClick', on_click)
	return widget
end

local function create_options()
	local panel = CreateFrame('Frame', 'UnitscanTurtleHCOptions', UIParent)
	panel:Hide()
	panel:SetPoint('CENTER', UIParent, 'CENTER',
		tonumber(unitscan_settings.optionsX) or 0, tonumber(unitscan_settings.optionsY) or 0)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:SetWidth(420)
	panel:SetHeight(456)
	panel:SetFrameStrata('DIALOG')
	panel:EnableMouse(true)
	panel:SetBackdrop({
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true, tileSize = 32, edgeSize = 32,
		insets = {left = 10, right = 10, top = 10, bottom = 10},
	})
	local close = CreateFrame('Button', nil, panel, 'UIPanelCloseButton')
	close:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -5, -5)
	tinsert(UISpecialFrames, panel:GetName())

	local settings = CreateFrame('Frame', nil, panel)
	settings:SetAllPoints(panel)
	label(settings, 'UnitScan Turtle-HC', 22, -22, 'GameFontNormalLarge')

	scan_checkbox = checkbox(settings, 'Enable scanning', -52, function()
		unitscan.set_scan_enabled(this:GetChecked() and true or false)
	end)
	local attack_warning = label(settings,
		'Scanning pauses during Auto Shot, wand Shoot, and melee Auto Attack.',
		22, -81, 'GameFontHighlightSmall')
	attack_warning:SetWidth(376)
	attack_warning:SetJustifyH('LEFT')
	attack_warning:SetTextColor(1, 0.82, 0.25)
	local model = checkbox(settings, 'Show character model', -100, function()
		unitscan_settings.showModel = this:GetChecked() and true or false
		if not unitscan_settings.showModel then unitscan.hide_model() end
	end)
	local flash = checkbox(settings, 'Screen flash', -124, function()
		unitscan_settings.flash = this:GetChecked() and true or false
		if not unitscan_settings.flash then unitscan.stop_flash() end
	end)

	local play_sound = checkbox(settings, 'Play warning sound', -148, function()
		unitscan_settings.playSound = this:GetChecked() and true or false
	end)

	label(settings, 'Warning sound (MPQ path, blank = default)', 22, -178)
	local sound = input(settings, 'UnitscanTurtleHCSound', 27, -198, 365, 255)
	label(settings, 'Alert scale (0.5 to 2)', 22, -231)
	local scale = input(settings, 'UnitscanTurtleHCScale', 262, -225, 110, 12)
	label(settings, 'Minimum display time (seconds)', 22, -263)
	local minimum = input(settings, 'UnitscanTurtleHCMinimum', 262, -257, 110, 12)
	label(settings, 'Snooze duration (minutes)', 22, -295)
	local snooze = input(settings, 'UnitscanTurtleHCSnooze', 262, -289, 110, 3)
	local status = label(settings, '', 22, -357, 'GameFontHighlightSmall')

	local function apply()
		local new_scale = tonumber(scale:GetText())
		local new_minimum = tonumber(minimum:GetText())
		if not new_scale or not (new_scale >= 0.5 and new_scale <= 2) then
			status:SetText('Enter an alert scale from 0.5 to 2.')
			return
		end
		if not new_minimum or new_minimum < 0 or new_minimum - new_minimum ~= 0 then
			status:SetText('Enter a non-negative number of seconds.')
			return
		end
		local minutes = tonumber(snooze:GetText())
		if not minutes or minutes < 1 or minutes > 999 or math.floor(minutes) ~= minutes then
			status:SetText('Enter a snooze duration from 1 to 999 minutes.')
			return
		end
		local path = unitscan.trim(sound:GetText())
		if path == '' then path = unitscan.defaults.sound end
		unitscan_settings.sound = path
		unitscan_settings.scale = new_scale
		unitscan_settings.minimum = new_minimum
		unitscan_settings.snoozeMinutes = minutes
		unitscan.anchor:SetScale(new_scale)
		sound:SetText(path)
		sound:ClearFocus()
		scale:ClearFocus()
		minimum:ClearFocus()
		snooze:ClearFocus()
		status:SetText('Settings saved.')
	end

	button(settings, 'Apply', 22, -323, 85, apply)
	sound:SetScript('OnEnterPressed', apply)
	scale:SetScript('OnEnterPressed', apply)
	minimum:SetScript('OnEnterPressed', apply)
	snooze:SetScript('OnEnterPressed', apply)

	local ignored = CreateFrame('Frame', nil, panel)
	ignored:SetAllPoints(panel)
	ignored:Hide()
	label(ignored, 'Ignored Mobs', 22, -22, 'GameFontNormalLarge')
	label(ignored, 'Enter a mob name as it appears in game.', 22, -55, 'GameFontHighlightSmall')
	local name_input = input(ignored, 'UnitscanTurtleHCIgnoreName', 27, -73, 276, 100)
	local page_label = label(ignored, '', 183, -335, 'GameFontHighlightSmall')
	local rows = {}
	local page = 1
	local refresh

	local function remove()
		unitscan_settings.ignored[this.key] = nil
		refresh()
	end

	for i = 1, PAGE_SIZE do
		local y = -111 - (i - 1) * 25
		local name = label(ignored, '', 22, y - 5, 'GameFontHighlight')
		name:SetWidth(280)
		name:SetHeight(16)
		name:SetJustifyH('LEFT')
		rows[i] = {name = name, remove = button(ignored, 'Remove', 318, y, 80, remove)}
	end

	local previous = button(ignored, 'Previous', 105, -328, 72, function()
		page = page - 1
		refresh()
	end)
	local next_page = button(ignored, 'Next', 252, -328, 65, function()
		page = page + 1
		refresh()
	end)
	local empty = label(ignored, 'No ignored mobs.', 22, -121, 'GameFontHighlight')

	refresh = function()
		local keys = {}
		for key in pairs(unitscan_settings.ignored) do tinsert(keys, key) end
		sort(keys)
		local count = table.getn(keys)
		local pages = math.max(1, math.ceil(count / PAGE_SIZE))
		page = math.min(math.max(page, 1), pages)
		page_label:SetText(page .. ' / ' .. pages)
		if page > 1 then previous:Enable() else previous:Disable() end
		if page < pages then next_page:Enable() else next_page:Disable() end
		if count == 0 then empty:Show() else empty:Hide() end
		for i = 1, PAGE_SIZE do
			local row = rows[i]
			local key = keys[(page - 1) * PAGE_SIZE + i]
			row.remove.key = key
			if key then
				row.name:SetText(unitscan_settings.ignored[key])
				row.name:Show()
				row.remove:Show()
			else
				row.name:Hide()
				row.remove:Hide()
			end
		end
	end

	local function add()
		local name = unitscan.trim(name_input:GetText())
		if name == '' then return end
		unitscan.ignore(name)
		name_input:SetText('')
		name_input:ClearFocus()
		refresh()
	end

	button(ignored, 'Add', 318, -73, 80, add)
	name_input:SetScript('OnEnterPressed', add)
	button(ignored, 'Back', 22, -328, 70, function()
		name_input:ClearFocus()
		ignored:Hide()
		settings:Show()
	end)
	button(settings, 'Ignored Mobs', 22, -384, 120, function()
		sound:ClearFocus()
		scale:ClearFocus()
		minimum:ClearFocus()
		snooze:ClearFocus()
		settings:Hide()
		ignored:Show()
		refresh()
	end)

	local add_mob = CreateFrame('Frame', nil, panel)
	add_mob:SetAllPoints(panel)
	add_mob:Hide()
	label(add_mob, 'Add Mob', 22, -22, 'GameFontNormalLarge')
	label(add_mob, 'Mob name', 22, -62)
	local mob_name = input(add_mob, 'UnitscanTurtleHCAddMobName', 27, -82, 365, 100)
	label(add_mob, 'Zone name', 22, -122)
	local zone_name = input(add_mob, 'UnitscanTurtleHCAddMobZone', 27, -142, 365, 100)
	local add_status = label(add_mob, '', 22, -216, 'GameFontHighlightSmall')
	add_status:SetWidth(376)
	add_status:SetJustifyH('LEFT')

	local command_help = label(add_mob,
		'Select a mob and type |cffffffff/unitscan add|r in chat to add it to your current zone.',
		22, -270, 'GameFontHighlightSmall')
	command_help:SetWidth(376)
	command_help:SetJustifyH('LEFT')

	local function save_mob()
		local added, message = unitscan.add_zone_mob(mob_name:GetText(), zone_name:GetText())
		add_status:SetText(message)
		if added then
			mob_name:SetText('')
			mob_name:ClearFocus()
			zone_name:ClearFocus()
		end
	end

	button(add_mob, 'Add', 22, -182, 85, save_mob)
	mob_name:SetScript('OnEnterPressed', save_mob)
	zone_name:SetScript('OnEnterPressed', save_mob)
	button(add_mob, 'Back', 22, -384, 70, function()
		mob_name:ClearFocus()
		zone_name:ClearFocus()
		add_mob:Hide()
		settings:Show()
	end)
	button(settings, 'Add Mob', 150, -384, 100, function()
		sound:ClearFocus()
		scale:ClearFocus()
		minimum:ClearFocus()
		snooze:ClearFocus()
		mob_name:SetText('')
		zone_name:SetText(GetZoneText() or '')
		add_status:SetText('')
		settings:Hide()
		add_mob:Show()
	end)

	local combat_pause = checkbox(settings, 'Pause scanning throughout combat', -414, function()
		unitscan_settings.pauseThroughoutCombat = this:GetChecked() and true or false
	end)

	local title_bar = CreateFrame('Frame', nil, panel)
	title_bar:SetPoint('TOPLEFT', panel, 'TOPLEFT', 14, -12)
	title_bar:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -42, -12)
	title_bar:SetHeight(36)
	title_bar:EnableMouse(true)
	title_bar:RegisterForDrag('LeftButton')

	local moving
	local function save_position()
		if not moving then return end
		moving = nil
		panel:StopMovingOrSizing()
		local x, y = panel:GetCenter()
		local parent_x, parent_y = UIParent:GetCenter()
		if not x or not y or not parent_x or not parent_y then return end

		unitscan_settings.optionsX = x - parent_x
		unitscan_settings.optionsY = y - parent_y
		panel:ClearAllPoints()
		panel:SetPoint('CENTER', UIParent, 'CENTER',
			unitscan_settings.optionsX, unitscan_settings.optionsY)
	end

	title_bar:SetScript('OnDragStart', function()
		moving = true
		panel:StartMoving()
	end)
	title_bar:SetScript('OnDragStop', save_position)
	panel:SetScript('OnHide', save_position)

	panel:SetScript('OnShow', function()
		ignored:Hide()
		add_mob:Hide()
		settings:Show()
		update_scan_controls()
		combat_pause:SetChecked(unitscan_settings.pauseThroughoutCombat and 1 or 0)
		flash:SetChecked(unitscan_settings.flash and 1 or 0)
		play_sound:SetChecked(unitscan_settings.playSound and 1 or 0)
		model:SetChecked(unitscan_settings.showModel and 1 or 0)
		sound:SetText(unitscan_settings.sound)
		scale:SetText(tostring(unitscan_settings.scale))
		minimum:SetText(tostring(unitscan_settings.minimum))
		snooze:SetText(tostring(unitscan_settings.snoozeMinutes))
		status:SetText('')
	end)
	return panel
end

local options
function unitscan.toggle_options()
	if not unitscan_settings then return end
	if not options then options = create_options() end
	if options:IsShown() then options:Hide() else options:Show() end
end

local function show_minimap_tooltip()
	GameTooltip:SetOwner(minimap_button, 'ANCHOR_LEFT')
	GameTooltip:AddLine('UnitScan Turtle-HC')
	if unitscan_settings.enabled then
		GameTooltip:AddLine('Scanning enabled', 0.4, 1, 0.4)
	else
		GameTooltip:AddLine('Scanning disabled', 1, 0.45, 0.45)
	end
	GameTooltip:AddLine('Left-click to toggle settings', 1, 1, 1)
	GameTooltip:AddLine('Right-click to toggle scanning', 1, 1, 1)
	GameTooltip:AddLine('Left-drag to move around the minimap', 1, 1, 1)
	GameTooltip:Show()
end

local function position_minimap_button()
	local angle = unitscan_settings.minimapAngle
	local x = math.cos(angle) * MINIMAP_RADIUS
	local y = math.sin(angle) * MINIMAP_RADIUS
	minimap_button:ClearAllPoints()
	minimap_button:SetPoint('CENTER', Minimap, 'CENTER', x, y)
end

local function drag_minimap_button()
	local center_x, center_y = Minimap:GetCenter()
	if not center_x or not center_y then return end
	local cursor_x, cursor_y = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	local x = cursor_x / scale - center_x
	local y = cursor_y / scale - center_y
	local length = math.sqrt(x * x + y * y)
	if length == 0 then return end

	local angle = math.acos(math.min(1, math.max(-1, x / length)))
	unitscan_settings.minimapAngle = y < 0 and -angle or angle
	position_minimap_button()
end

function unitscan.create_minimap_button()
	if minimap_button or not Minimap then return end

	local widget = CreateFrame('Button', 'UnitscanTurtleHCMinimapButton', Minimap)
	minimap_button = widget
	widget:SetWidth(31)
	widget:SetHeight(31)
	position_minimap_button()
	widget:SetFrameStrata('MEDIUM')
	widget:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	widget:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]], 'ADD')
	widget:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	widget:RegisterForDrag('LeftButton')

	minimap_icon = widget:CreateTexture(nil, 'ARTWORK')
	minimap_icon:SetWidth(19)
	minimap_icon:SetHeight(19)
	minimap_icon:SetPoint('CENTER', widget, 'CENTER', -2, 0)
	minimap_icon:SetTexture([[Interface\Icons\Ability_Hunter_SniperShot]])
	minimap_icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local border = widget:CreateTexture(nil, 'OVERLAY')
	border:SetWidth(53)
	border:SetHeight(53)
	border:SetPoint('TOPLEFT', widget, 'TOPLEFT', -2, 0)
	border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])

	local dragged
	widget:SetScript('OnMouseDown', function()
		if arg1 == 'LeftButton' then dragged = nil end
	end)
	widget:SetScript('OnDragStart', function()
		dragged = true
		GameTooltip:Hide()
		widget:SetScript('OnUpdate', drag_minimap_button)
	end)
	widget:SetScript('OnDragStop', function()
		drag_minimap_button()
		widget:SetScript('OnUpdate', nil)
	end)
	widget:SetScript('OnHide', function()
		widget:SetScript('OnUpdate', nil)
	end)
	widget:SetScript('OnEnter', show_minimap_tooltip)
	widget:SetScript('OnLeave', function() GameTooltip:Hide() end)
	widget:SetScript('OnClick', function()
		if arg1 == 'RightButton' then
			unitscan.set_scan_enabled(not unitscan_settings.enabled)
			show_minimap_tooltip()
		elseif arg1 == 'LeftButton' and not dragged then
			unitscan.toggle_options()
		end
	end)
	update_scan_controls()
end
