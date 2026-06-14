local InputService = game:GetService('UserInputService')
local TextService = game:GetService('TextService')
local CoreGui = game:GetService('CoreGui')
local Teams = game:GetService('Teams')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local Lighting = game:GetService('Lighting')
local RenderStepped = RunService.RenderStepped
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end)

local ScreenGui = Instance.new('ScreenGui')
ProtectGui(ScreenGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = CoreGui

local Toggles = {}
local Options = {}

getgenv().Toggles = Toggles
getgenv().Options = Options

local TweenInfo_Short = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenInfo_Med = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenInfo_Long = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local Library = {
	Registry = {};
	RegistryMap = {};
	HudRegistry = {};
	Signals = {};
	ScreenGui = ScreenGui;
	OpenedFrames = {};
	DependencyBoxes = {};
	KeyPickerList = {};
	Notifications = {};

	FontColor = Color3.fromRGB(220, 222, 228);
	MainColor = Color3.fromRGB(22, 24, 29);
	BackgroundColor = Color3.fromRGB(17, 18, 22);
	AccentColor = Color3.fromRGB(59, 130, 246);
	OutlineColor = Color3.fromRGB(38, 41, 48);
	RiskColor = Color3.fromRGB(239, 68, 68);
	SuccessColor = Color3.fromRGB(34, 197, 94);
	SurfaceColor = Color3.fromRGB(28, 30, 36);
	MutedColor = Color3.fromRGB(130, 134, 144);

	Black = Color3.new(0, 0, 0);
	White = Color3.new(1, 1, 1);

	Font = Enum.Font.GothamMedium;
	FontSize = 13;

	Toggled = false;
	WireframeDrag = false;
	UseBlur = false;
	BlurSize = 15;
	KeybindMode = 'All';
	NotifyOnError = false;

	NotifyConfig = {
		Alignment = 'Right';
		BarSide = 'Left';
		PositionX = 16;
		PositionY = 50;
	};
}

Library.BlurEffect = Instance.new("BlurEffect")
Library.BlurEffect.Name = "LinoriaBlur"
Library.BlurEffect.Size = 0
Library.BlurEffect.Enabled = false
pcall(function() Library.BlurEffect.Parent = Lighting end)

function Library:UpdateBlur()
	if Library.UseBlur then
		if Library.Toggled then
			Library.BlurEffect.Enabled = true
			TweenService:Create(Library.BlurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = Library.BlurSize}):Play()
		end
	else
		local tween = TweenService:Create(Library.BlurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = 0})
		tween:Play()
		task.delay(0.3, function()
			if not Library.UseBlur then
				Library.BlurEffect.Enabled = false
			end
		end)
	end
end

function Library:SetFontSize(Size)
	Library.FontSize = Size
	local function updateDescendants(parent)
		for _, descendant in pairs(parent:GetDescendants()) do
			if descendant:IsA("TextLabel") or descendant:IsA("TextBox") or descendant:IsA("TextButton") then
				local offset = descendant:GetAttribute("FontSizeOffset")
				if offset then
					descendant.TextSize = Size + offset
				end
			end
		end
	end
	updateDescendants(ScreenGui)
	local mobileUI = CoreGui:FindFirstChild("LinoriaMobileUI")
	if mobileUI then
		updateDescendants(mobileUI)
	end
end

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
	RainbowStep = RainbowStep + Delta
	if RainbowStep >= (1 / 60) then
		RainbowStep = 0
		Hue = Hue + (1 / 400)
		if Hue > 1 then
			Hue = 0
		end
		Library.CurrentRainbowHue = Hue
		Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1)
	end
end))

local function GetPlayersString()
	local PlayerList = Players:GetPlayers()
	for i = 1, #PlayerList do
		PlayerList[i] = PlayerList[i].Name
	end
	table.sort(PlayerList, function(str1, str2) return str1 < str2 end)
	return PlayerList
end

local function GetTeamsString()
	local TeamList = Teams:GetTeams()
	for i = 1, #TeamList do
		TeamList[i] = TeamList[i].Name
	end
	table.sort(TeamList, function(str1, str2) return str1 < str2 end)
	return TeamList
end

function Library:SafeCallback(f, ...)
	if not f then return end
	if not Library.NotifyOnError then
		return f(...)
	end
	local success, event = pcall(f, ...)
	if not success then
		local _, i = event:find(":%d+: ")
		if not i then
			return Library:Notify(event)
		end
		return Library:Notify(event:sub(i + 1), 3)
	end
end

function Library:AttemptSave()
	if Library.SaveManager then
		Library.SaveManager:Save()
	end
end

local function AnimateProperty(instance, property, targetValue, tweenInfo)
	local tween = TweenService:Create(instance, tweenInfo or TweenInfo_Med, {[property] = targetValue})
	tween:Play()
	return tween
end

function Library:Create(Class, Properties)
	local _Instance = Class
	if type(Class) == 'string' then
		_Instance = Instance.new(Class)
	end
	for Property, Value in next, Properties do
		_Instance[Property] = Value
	end
	if _Instance:IsA("TextLabel") or _Instance:IsA("TextBox") or _Instance:IsA("TextButton") then
		if Properties.TextSize then
			_Instance:SetAttribute("FontSizeOffset", Properties.TextSize - Library.FontSize)
		else
			_Instance:SetAttribute("FontSizeOffset", 0)
		end
	end
	return _Instance
end

function Library:CreateLabel(Properties, IsHud)
	local _Instance = Library:Create('TextLabel', {
		BackgroundTransparency = 1;
		Font = Library.Font;
		TextColor3 = Library.FontColor;
		TextSize = Library.FontSize + 2;
		TextStrokeTransparency = 0;
	})
	Library:AddToRegistry(_Instance, {
		TextColor3 = 'FontColor';
	}, IsHud)
	return Library:Create(_Instance, Properties)
end

function Library:AddToRegistry(Instance, Properties, IsHud)
	local Idx = #Library.Registry + 1
	local Data = {
		Instance = Instance;
		Properties = Properties;
		Idx = Idx;
	}
	table.insert(Library.Registry, Data)
	Library.RegistryMap[Instance] = Data
	if IsHud then
		table.insert(Library.HudRegistry, Data)
	end
end

function Library:GiveSignal(Signal)
	table.insert(Library.Signals, Signal)
end

function Library:RemoveFromRegistry(Instance)
	local Data = Library.RegistryMap[Instance]
	if Data then
		for Idx = #Library.Registry, 1, -1 do
			if Library.Registry[Idx] == Data then
				table.remove(Library.Registry, Idx)
			end
		end
		for Idx = #Library.HudRegistry, 1, -1 do
			if Library.HudRegistry[Idx] == Data then
				table.remove(Library.HudRegistry, Idx)
			end
		end
		Library.RegistryMap[Instance] = nil
	end
end

function Library:UpdateColorsUsingRegistry()
	for Idx, Object in next, Library.Registry do
		for Property, ColorIdx in next, Object.Properties do
			if type(ColorIdx) == 'string' then
				Object.Instance[Property] = Library[ColorIdx]
			elseif type(ColorIdx) == 'function' then
				Object.Instance[Property] = ColorIdx()
			end
		end
	end
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
	local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
	return Bounds.X, Bounds.Y
end

function Library:GetDarkerColor(Color)
	local H, S, V = Color3.toHSV(Color)
	return Color3.fromHSV(H, S, V / 1.5)
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
	return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB
end

Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)

function Library:MouseIsOverOpenedFrame()
	for Frame, _ in next, Library.OpenedFrames do
		local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
		if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
			and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
			return true
		end
	end
	return false
end

function Library:IsMouseOverFrame(Frame)
	local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
	if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
		and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
		return true
	end
	return false
end

function Library:UpdateDependencyBoxes()
	for _, Depbox in next, Library.DependencyBoxes do
		Depbox:Update()
	end
end

function Library:MakeDraggable(Instance, Cutoff, IsWindow)
	Instance.Active = true
	Instance.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			local StartPos = Instance.Position
			local DragStart = Input.Position
			if (DragStart.Y - Instance.AbsolutePosition.Y) > (Cutoff or 40) then
				return
			end
			local Dragging = true
			local HasMoved = false
			local Wireframe = nil
			local ChangedConn, EndedConn

			ChangedConn = InputService.InputChanged:Connect(function(Change)
				if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
					local Delta = Change.Position - DragStart
					if IsWindow and Library.WireframeDrag then
						if not HasMoved and Delta.Magnitude > 2 then
							HasMoved = true
							Wireframe = Library:Create("Frame", {
								Size = Instance.Size;
								Position = Instance.Position;
								AnchorPoint = Instance.AnchorPoint;
								BackgroundTransparency = 0.85;
								BackgroundColor3 = Library.AccentColor;
								BorderSizePixel = 0;
								Active = false;
								ZIndex = 100000;
								Parent = ScreenGui;
							})
						end
						if HasMoved and Wireframe then
							Wireframe.Position = UDim2.new(
								StartPos.X.Scale, StartPos.X.Offset + Delta.X,
								StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
							)
						end
					else
						Instance.Position = UDim2.new(
							StartPos.X.Scale, StartPos.X.Offset + Delta.X,
							StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
						)
					end
				end
			end)

			EndedConn = InputService.InputEnded:Connect(function(EndInput)
				if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
					Dragging = false
					ChangedConn:Disconnect()
					EndedConn:Disconnect()
					if IsWindow and Library.WireframeDrag and HasMoved and Wireframe then
						Instance.Position = Wireframe.Position
						Wireframe:Destroy()
						Wireframe = nil
					end
				end
			end)
		end
	end)
end

function Library:Unload()
	for Idx = #Library.Signals, 1, -1 do
		local Connection = table.remove(Library.Signals, Idx)
		Connection:Disconnect()
	end
	if Library.OnUnload then
		Library.OnUnload()
	end
	if Library.BlurEffect then
		Library.BlurEffect:Destroy()
	end
	ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
	Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
	if Library.RegistryMap[Instance] then
		Library:RemoveFromRegistry(Instance)
	end
end))

local BaseAddons = {}
do
	local Funcs = {}

	function Funcs:AddColorPicker(Idx, Info)
		local ToggleLabel = self.TextLabel
		assert(Info.Default, 'AddColorPicker: Missing default value.')

		local ColorPicker = {
			Value = Info.Default;
			Transparency = Info.Transparency or 0;
			Type = 'ColorPicker';
			Title = type(Info.Title) == 'string' and Info.Title or 'Color picker';
			Callback = Info.Callback or function(Color) end;
		}

		function ColorPicker:SetHSVFromRGB(Color)
			local H, S, V = Color3.toHSV(Color)
			ColorPicker.Hue = H
			ColorPicker.Sat = S
			ColorPicker.Vib = V
		end

		ColorPicker:SetHSVFromRGB(ColorPicker.Value)

		local DisplayFrame = Library:Create('Frame', {
			BackgroundColor3 = ColorPicker.Value;
			BorderSizePixel = 0;
			Size = UDim2.new(0, 24, 0, 14);
			ZIndex = 6;
			Parent = ToggleLabel;
		})
		Library:Create('UICorner', {
			CornerRadius = UDim.new(0, 3);
			Parent = DisplayFrame;
		})

		local CheckerFrame = Library:Create('ImageLabel', {
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 5;
			Image = 'http://www.roblox.com/asset/?id=12977615774';
			Visible = not not Info.Transparency;
			Parent = DisplayFrame;
		})
		Library:Create('UICorner', {
			CornerRadius = UDim.new(0, 3);
			Parent = CheckerFrame;
		})

		local PickerFrameOuter = Library:Create('Frame', {
			Name = 'Color';
			BackgroundColor3 = Color3.new(1, 1, 1);
			BorderColor3 = Color3.new(0, 0, 0);
			Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
			Size = UDim2.fromOffset(240, Info.Transparency and 286 or 266);
			Visible = false;
			ZIndex = 15;
			Parent = ScreenGui;
		})
		Library:Create('UICorner', {
			CornerRadius = UDim.new(0, 8);
			Parent = PickerFrameOuter;
		})

		DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18)
		end)

		local PickerShadow = Library:Create('ImageLabel', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 15;
			Image = 'http://www.roblox.com/asset/?id=13100794983';
			ImageColor3 = Color3.new(0, 0, 0);
			ScaleType = Enum.ScaleType.Slice;
			SliceCenter = Rect.new(10, 10, 10, 10);
			Parent = PickerFrameOuter;
		})

		local PickerFrameInner = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 16;
			Parent = PickerFrameOuter;
		})
		Library:Create('UICorner', {
			CornerRadius = UDim.new(0, 8);
			Parent = PickerFrameInner;
		})
		Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor' })

		local SatVibMapOuter = Library:Create('Frame', {
			BorderSizePixel = 0;
			Position = UDim2.new(0, 10, 0, 10);
			Size = UDim2.new(0, 200, 0, 200);
			ZIndex = 17;
			Parent = PickerFrameInner;
		})
		Library:Create('UICorner', {
			CornerRadius = UDim.new(0, 6);
			Parent = SatVibMapOuter;
		})

		local SatVibMap = Library:Create('ImageLabel', {
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Image = 'rbxassetid://4155801252';
			Parent = SatVibMapOuter;
			BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);
		})
		Library:Create('UICorner', {
			CornerRadius = UDim.new(0, 6);
			Parent = SatVibMap;
		})

		local CursorOuter = Library:Create('ImageLabel', {
			AnchorPoint = Vector2.new(0.5, 0.5);
			Size = UDim2.new(0, 14, 0, 14);
			BackgroundTransparency = 1;
			Image = 'http://www.roblox.com/asset/?id=10284643478';
			ImageColor3 = Color3.new(0, 0, 0);
			ZIndex = 19;
			Parent = SatVibMap;
		})
		local CursorInner = Library:Create('ImageLabel', {
			Size = UDim2.new(0, 10, 0, 10);
			Position = UDim2.new(0, 2, 0, 2);
			BackgroundTransparency = 1;
			Image = 'http://www.roblox.com/asset/?id=10284643478';
			ImageColor3 = Color3.new(1, 1, 1);
			ZIndex = 20;
			Parent = CursorOuter;
		})

		local HueSelectorOuter = Library:Create('Frame', {
			BorderSizePixel = 0;
			Position = UDim2.new(0, 216, 0, 10);
			Size = UDim2.new(0, 14, 0, 200);
			ZIndex = 17;
			Parent = PickerFrameInner;
		})
		Library:Create('UICorner', {
			CornerRadius = UDim.new(0, 7);
			Parent = HueSelectorOuter;
		})

		local HueSelectorInner = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(1, 1, 1);
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Parent = HueSelectorOuter;
		})
		Library:Create('UICorner', {
			CornerRadius = UDim.new(0, 7);
			Parent = HueSelectorInner;
		})

		local HueCursor = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(1, 1, 1);
			AnchorPoint = Vector2.new(0, 0.5);
			BorderSizePixel = 0;
			Size = UDim2.new(1, 4, 0, 4);
			Position = UDim2.new(-2, 0, ColorPicker.Hue, 0);
			ZIndex = 18;
			Parent = HueSelectorInner;
		})
		Library:Create('UICorner', {
			CornerRadius = UDim.new(0, 2);
			Parent = HueCursor;
		})

		local SequenceTable = {}
		for h = 0, 1, 0.1 do
			table.insert(SequenceTable, ColorSequenceKeypoint.new(h, Color3.fromHSV(h, 1, 1)))
		end
		Library:Create('UIGradient', {
			Color = ColorSequence.new(SequenceTable);
			Rotation = 90;
			Parent = HueSelectorInner;
		})

		local HexBox = Library:Create('Frame', {
			BackgroundColor3 = Library.SurfaceColor;
			BorderSizePixel = 0;
			Position = UDim2.fromOffset(10, 218);
			Size = UDim2.new(0.5, -14, 0, 22);
			ZIndex = 18;
			Parent = PickerFrameInner;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = HexBox; })
		Library:AddToRegistry(HexBox, { BackgroundColor3 = 'SurfaceColor' })

		local HexTextBox = Library:Create('TextBox', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 8, 0, 0);
			Size = UDim2.new(1, -8, 1, 0);
			Font = Library.Font;
			PlaceholderColor3 = Library.MutedColor;
			PlaceholderText = '#FFFFFF';
			Text = '#FFFFFF';
			TextColor3 = Library.FontColor;
			TextSize = Library.FontSize;
			TextStrokeTransparency = 1;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 20;
			Parent = HexBox;
		})

		local RgbBox = Library:Create('Frame', {
			BackgroundColor3 = Library.SurfaceColor;
			BorderSizePixel = 0;
			Position = UDim2.fromOffset(10 + (HexBox.Size.X.Offset) + 8, 218);
			Size = UDim2.new(0.5, -14, 0, 22);
			ZIndex = 18;
			Parent = PickerFrameInner;
		})
		RgbBox:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
			RgbBox.Position = UDim2.fromOffset(10 + HexBox.AbsoluteSize.X + 8, 218)
		end)
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = RgbBox; })
		Library:AddToRegistry(RgbBox, { BackgroundColor3 = 'SurfaceColor' })

		local RgbTextBox = Library:Create('TextBox', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 8, 0, 0);
			Size = UDim2.new(1, -8, 1, 0);
			Font = Library.Font;
			PlaceholderColor3 = Library.MutedColor;
			PlaceholderText = '255, 255, 255';
			Text = '255, 255, 255';
			TextColor3 = Library.FontColor;
			TextSize = Library.FontSize;
			TextStrokeTransparency = 1;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 20;
			Parent = RgbBox;
		})

		local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor

		if Info.Transparency then
			TransparencyBoxOuter = Library:Create('Frame', {
				BorderSizePixel = 0;
				Position = UDim2.fromOffset(10, 248);
				Size = UDim2.new(1, -20, 0, 16);
				ZIndex = 19;
				Parent = PickerFrameInner;
			})
			Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = TransparencyBoxOuter; })

			TransparencyBoxInner = Library:Create('Frame', {
				BackgroundColor3 = ColorPicker.Value;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 1, 0);
				ZIndex = 19;
				Parent = TransparencyBoxOuter;
			})
			Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = TransparencyBoxInner; })
			Library:AddToRegistry(TransparencyBoxInner, { BackgroundColor3 = function() return ColorPicker.Value end })

			Library:Create('ImageLabel', {
				BackgroundTransparency = 1;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 1, 0);
				Image = 'http://www.roblox.com/asset/?id=12978095818';
				ZIndex = 20;
				Parent = TransparencyBoxInner;
			})
			Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = TransparencyBoxInner:FindFirstChildWhichIsA('ImageLabel') })

			TransparencyCursor = Library:Create('Frame', {
				BackgroundColor3 = Color3.new(1, 1, 1);
				AnchorPoint = Vector2.new(0.5, 0);
				BorderSizePixel = 0;
				Size = UDim2.new(0, 3, 1, 0);
				ZIndex = 21;
				Parent = TransparencyBoxInner;
			})
			Library:Create('UICorner', { CornerRadius = UDim.new(0, 1.5); Parent = TransparencyCursor; })
		end

		Library:AddToRegistry(HexBox, { BackgroundColor3 = 'SurfaceColor' })
		Library:AddToRegistry(RgbBox, { BackgroundColor3 = 'SurfaceColor' })

		HexTextBox.FocusLost:Connect(function(enter)
			if enter then
				local success, result = pcall(Color3.fromHex, HexTextBox.Text)
				if success and typeof(result) == 'Color3' then
					ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
				end
			end
			ColorPicker:Display()
		end)

		RgbTextBox.FocusLost:Connect(function(enter)
			if enter then
				local r, g, b = RgbTextBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
				if r and g and b then
					ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
				end
			end
			ColorPicker:Display()
		end)

		local TitleLabel = Library:CreateLabel({
			Size = UDim2.new(1, -20, 0, 14);
			Position = UDim2.fromOffset(10, 248);
			TextXAlignment = Enum.TextXAlignment.Left;
			TextSize = Library.FontSize;
			Text = ColorPicker.Title;
			TextWrapped = false;
			ZIndex = 16;
			Parent = PickerFrameInner;
		})
		if Info.Transparency then
			TitleLabel.Position = UDim2.fromOffset(10, 272)
		end

		local ContextMenu = {}
		do
			ContextMenu.Options = {}
			ContextMenu.Container = Library:Create('Frame', {
				BackgroundColor3 = Library.BackgroundColor;
				BorderSizePixel = 0;
				ZIndex = 14;
				Visible = false;
				Parent = ScreenGui;
			})
			Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = ContextMenu.Container; })

			local MenuShadow = Library:Create('ImageLabel', {
				BackgroundTransparency = 1;
				Size = UDim2.new(1, 0, 1, 0);
				ZIndex = 14;
				Image = 'http://www.roblox.com/asset/?id=13100794983';
				ImageColor3 = Color3.new(0, 0, 0);
				ScaleType = Enum.ScaleType.Slice;
				SliceCenter = Rect.new(10, 10, 10, 10);
				Parent = ContextMenu.Container;
			})

			Library:Create('UIListLayout', {
				Name = 'Layout';
				FillDirection = Enum.FillDirection.Vertical;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Padding = UDim.new(0, 2);
				Parent = ContextMenu.Container;
			})

			local function updateMenuPosition()
				ContextMenu.Container.Position = UDim2.fromOffset(
					(DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 6,
					DisplayFrame.AbsolutePosition.Y
				)
			end
			local function updateMenuSize()
				local menuWidth = 80
				for _, child in next, ContextMenu.Container:GetChildren() do
					if child:IsA('TextLabel') then
						menuWidth = math.max(menuWidth, child.TextBounds.X + 16)
					end
				end
				local children = 0
				for _, child in next, ContextMenu.Container:GetChildren() do
					if child:IsA('TextLabel') then children = children + 1 end
				end
				ContextMenu.Container.Size = UDim2.fromOffset(menuWidth + 8, children * 26 + 6)
			end
			DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
			ContextMenu.Container.ChildAdded:Connect(updateMenuSize)
			task.spawn(updateMenuPosition)
			task.spawn(updateMenuSize)
			Library:AddToRegistry(ContextMenu.Container, { BackgroundColor3 = 'BackgroundColor' })

			function ContextMenu:Show()
				self.Container.Visible = true
			end
			function ContextMenu:Hide()
				self.Container.Visible = false
			end

			function ContextMenu:AddOption(Str, Callback)
				if type(Callback) ~= 'function' then
					Callback = function() end
				end
				local Button = Library:CreateLabel({
					Active = false;
					Size = UDim2.new(1, 0, 0, 24);
					TextSize = Library.FontSize - 1;
					Text = '  ' .. Str;
					ZIndex = 16;
					Parent = self.Container;
					TextXAlignment = Enum.TextXAlignment.Left;
				})
				Button.MouseEnter:Connect(function()
					TweenService:Create(Button, TweenInfo_Short, { TextColor3 = Library.AccentColor }):Play()
				end)
				Button.MouseLeave:Connect(function()
					TweenService:Create(Button, TweenInfo_Short, { TextColor3 = Library.FontColor }):Play()
				end)
				Library:AddToRegistry(Button, { TextColor3 = 'FontColor' })
				Button.InputBegan:Connect(function(Input)
					if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
						return
					end
					Callback()
					self:Hide()
				end)
			end

			ContextMenu:AddOption('Copy color', function()
				Library.ColorClipboard = ColorPicker.Value
				Library:Notify('Copied color!', 2)
			end)
			ContextMenu:AddOption('Paste color', function()
				if not Library.ColorClipboard then
					return Library:Notify('You have not copied a color!', 2)
				end
				ColorPicker:SetValueRGB(Library.ColorClipboard)
			end)
			ContextMenu:AddOption('Copy HEX', function()
				pcall(setclipboard, ColorPicker.Value:ToHex())
				Library:Notify('Copied hex code!', 2)
			end)
			ContextMenu:AddOption('Copy RGB', function()
				pcall(setclipboard, table.concat({
					math.floor(ColorPicker.Value.R * 255),
					math.floor(ColorPicker.Value.G * 255),
					math.floor(ColorPicker.Value.B * 255)
				}, ', '))
				Library:Notify('Copied RGB values!', 2)
			end)
		end
		function ColorPicker:Display()
			ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
			SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)

			DisplayFrame.BackgroundColor3 = ColorPicker.Value
			DisplayFrame.BackgroundTransparency = ColorPicker.Transparency

			if TransparencyBoxInner then
				TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value
				TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0)
			end

			CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0)
			HueCursor.Position = UDim2.new(-2, 0, ColorPicker.Hue, 0)

			HexTextBox.Text = '#' .. ColorPicker.Value:ToHex()
			RgbTextBox.Text = table.concat({
				math.floor(ColorPicker.Value.R * 255),
				math.floor(ColorPicker.Value.G * 255),
				math.floor(ColorPicker.Value.B * 255)
			}, ', ')

			Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value)
			Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value)
		end

		function ColorPicker:OnChanged(Func)
			ColorPicker.Changed = Func
			Func(ColorPicker.Value)
		end

		function ColorPicker:Show()
			for Frame, Val in next, Library.OpenedFrames do
				if Frame.Name == 'Color' then
					Frame.Visible = false
					Library.OpenedFrames[Frame] = nil
				end
			end
			PickerFrameOuter.Visible = true
			Library.OpenedFrames[PickerFrameOuter] = true
		end

		function ColorPicker:Hide()
			PickerFrameOuter.Visible = false
			Library.OpenedFrames[PickerFrameOuter] = nil
		end

		function ColorPicker:SetValue(HSV, Transparency)
			local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])
			ColorPicker.Transparency = Transparency or 0
			ColorPicker:SetHSVFromRGB(Color)
			ColorPicker:Display()
		end

		function ColorPicker:SetValueRGB(Color, Transparency)
			ColorPicker.Transparency = Transparency or 0
			ColorPicker:SetHSVFromRGB(Color)
			ColorPicker:Display()
		end

		SatVibMap.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				local function UpdateColor(PosX, PosY)
					local MinX = SatVibMap.AbsolutePosition.X
					local MaxX = MinX + SatVibMap.AbsoluteSize.X
					local MouseX = math.clamp(PosX, MinX, MaxX)
					local MinY = SatVibMap.AbsolutePosition.Y
					local MaxY = MinY + SatVibMap.AbsoluteSize.Y
					local MouseY = math.clamp(PosY, MinY, MaxY)

					ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX)
					ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY))
					ColorPicker:Display()
				end
				UpdateColor(Input.Position.X, Input.Position.Y)

				local ChangedConn = InputService.InputChanged:Connect(function(Change)
					if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
						UpdateColor(Change.Position.X, Change.Position.Y)
					end
				end)
				local EndedConn
				EndedConn = InputService.InputEnded:Connect(function(EndInput)
					if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
						ChangedConn:Disconnect()
						EndedConn:Disconnect()
						Library:AttemptSave()
					end
				end)
			end
		end)

		HueSelectorInner.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				local function UpdateHue(PosY)
					local MinY = HueSelectorInner.AbsolutePosition.Y
					local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y
					local MouseY = math.clamp(PosY, MinY, MaxY)
					ColorPicker.Hue = (MouseY - MinY) / (MaxY - MinY)
					ColorPicker:Display()
				end
				UpdateHue(Input.Position.Y)

				local ChangedConn = InputService.InputChanged:Connect(function(Change)
					if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
						UpdateHue(Change.Position.Y)
					end
				end)
				local EndedConn
				EndedConn = InputService.InputEnded:Connect(function(EndInput)
					if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
						ChangedConn:Disconnect()
						EndedConn:Disconnect()
						Library:AttemptSave()
					end
				end)
			end
		end)

		DisplayFrame.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
				if PickerFrameOuter.Visible then
					ColorPicker:Hide()
				else
					ContextMenu:Hide()
					ColorPicker:Show()
				end
			elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
				ContextMenu:Show()
				ColorPicker:Hide()
			end
		end)

		if TransparencyBoxInner then
			TransparencyBoxInner.InputBegan:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					local function UpdateAlpha(PosX)
						local MinX = TransparencyBoxInner.AbsolutePosition.X
						local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X
						local MouseX = math.clamp(PosX, MinX, MaxX)
						ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX))
						ColorPicker:Display()
					end
					UpdateAlpha(Input.Position.X)

					local ChangedConn = InputService.InputChanged:Connect(function(Change)
						if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
							UpdateAlpha(Change.Position.X)
						end
					end)
					local EndedConn
					EndedConn = InputService.InputEnded:Connect(function(EndInput)
						if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
							ChangedConn:Disconnect()
							EndedConn:Disconnect()
							Library:AttemptSave()
						end
					end)
				end
			end)
		end

		Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
				local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize
				local DFPos = DisplayFrame.AbsolutePosition
				local DFSize = DisplayFrame.AbsoluteSize

				if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
					or Mouse.Y < DFPos.Y or Mouse.Y > AbsPos.Y + AbsSize.Y then
					if not (Mouse.X >= DFPos.X and Mouse.X <= DFPos.X + DFSize.X
						and Mouse.Y >= DFPos.Y and Mouse.Y <= DFPos.Y + DFSize.Y) then
						ColorPicker:Hide()
					end
				end
				if not Library:IsMouseOverFrame(ContextMenu.Container) then
					ContextMenu:Hide()
				end
			end
			if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
				if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
					ContextMenu:Hide()
				end
			end
		end))

		function ColorPicker:GetTransparency()
			return ColorPicker.Transparency
		end

		function ColorPicker:OnTransparencyChanged(Func)
			ColorPicker.TransparencyChanged = Func
			Func(ColorPicker.Transparency)
		end

		local _OrigDisplay = ColorPicker.Display
		ColorPicker.Display = function(self)
			_OrigDisplay(self)
			Library:SafeCallback(ColorPicker.TransparencyChanged, ColorPicker.Transparency)
		end

		ColorPicker:Display()
		ColorPicker.DisplayFrame = DisplayFrame

		Options[Idx] = ColorPicker
		return self
	end

	function Funcs:AddColorPickerAlpha(Idx, Info)
		Info = Info or {}
		if Info.Transparency == nil then
			Info.Transparency = 0
		end
		return Funcs.AddColorPicker(self, Idx, Info)
	end

	function Funcs:AddKeyPicker(Idx, Info)
		local ParentObj = self
		local ToggleLabel = self.TextLabel
		local Container = self.Container

		assert(Info.Default, 'AddKeyPicker: Missing default value.')

		local KeyPicker = {
			Value = Info.Default;
			Toggled = false;
			Mode = Info.Mode or 'Toggle';
			Type = 'KeyPicker';
			Callback = Info.Callback or function(Value) end;
			ChangedCallback = Info.ChangedCallback or function(New) end;
			SyncToggleState = Info.SyncToggleState or false;
		}
		if KeyPicker.SyncToggleState then
			Info.Modes = { 'Toggle' }
			Info.Mode = 'Toggle'
		end

		local PickOuter = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderSizePixel = 0;
			Size = UDim2.new(0, 50, 0, 15);
			ZIndex = 6;
			Parent = ToggleLabel;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = PickOuter; })

		local PickInner = Library:Create('Frame', {
			BackgroundColor3 = Library.SurfaceColor;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 7;
			Parent = PickOuter;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = PickInner; })
		Library:AddToRegistry(PickInner, { BackgroundColor3 = 'SurfaceColor' })

		local DisplayLabel = Library:CreateLabel({
			Size = UDim2.new(1, 0, 1, 0);
			TextSize = Library.FontSize - 1;
			Text = Info.Default;
			TextWrapped = true;
			ZIndex = 8;
			Parent = PickInner;
		})

		local ModeSelectOuter = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderSizePixel = 0;
			Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
			Size = UDim2.new(0, 60, 0, 45 + 2);
			Visible = false;
			ZIndex = 14;
			Parent = ScreenGui;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = ModeSelectOuter; })

		ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1)
		end)

		local MenuShadow = Library:Create('ImageLabel', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 14;
			Image = 'http://www.roblox.com/asset/?id=13100794983';
			ImageColor3 = Color3.new(0, 0, 0);
			ScaleType = Enum.ScaleType.Slice;
			SliceCenter = Rect.new(10, 10, 10, 10);
			Parent = ModeSelectOuter;
		})

		Library:Create('UIListLayout', {
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Padding = UDim.new(0, 2);
			Parent = ModeSelectOuter;
		})
		Library:AddToRegistry(ModeSelectOuter, { BackgroundColor3 = 'BackgroundColor' })

		local KeybindEntry = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 0, 18);
			Visible = false;
			ZIndex = 110;
			Parent = Library.KeybindContainer;
		})

		local ContainerLabel = Library:CreateLabel({
			Position = UDim2.new(0, 4, 0, 0);
			Size = UDim2.new(1, -8, 1, 0);
			TextSize = Library.FontSize - 1;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 111;
			Parent = KeybindEntry;
		}, true)

		local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' }
		local ModeButtons = {}

		for Idx, Mode in next, Modes do
			local ModeButton = {}
			local Label = Library:CreateLabel({
				Active = false;
				Size = UDim2.new(1, 0, 0, 22);
				TextSize = Library.FontSize - 1;
				Text = '  ' .. Mode;
				ZIndex = 16;
				Parent = ModeSelectOuter;
				TextXAlignment = Enum.TextXAlignment.Left;
			})

			Label.MouseEnter:Connect(function()
				TweenService:Create(Label, TweenInfo_Short, { TextColor3 = Library.AccentColor }):Play()
			end)
			Label.MouseLeave:Connect(function()
				if Label.TextColor3 ~= Library.FontColor then
					TweenService:Create(Label, TweenInfo_Short, { TextColor3 = Library.FontColor }):Play()
				end
			end)

			function ModeButton:Select()
				for _, Button in next, ModeButtons do
					Button:Deselect()
				end
				KeyPicker.Mode = Mode
				Label.TextColor3 = Library.AccentColor
				Library.RegistryMap[Label] = Library.RegistryMap[Label] or { Properties = {} }
				Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor'
				ModeSelectOuter.Visible = false
			end
			function ModeButton:Deselect()
				Label.TextColor3 = Library.FontColor
				Library.RegistryMap[Label] = Library.RegistryMap[Label] or { Properties = {} }
				Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor'
			end

			Label.InputBegan:Connect(function(Input)
				if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
					ModeButton:Select()
					Library:AttemptSave()
				end
			end)
			if Mode == KeyPicker.Mode then
				ModeButton:Select()
			end
			ModeButtons[Mode] = ModeButton
		end

		function KeyPicker:Update()
			if Info.NoUI then return end
			local State = KeyPicker:GetState()
			local displayKey = (KeyPicker.Value == 'None') and '...' or KeyPicker.Value
			ContainerLabel.Text = string.format('[%s] %s (%s)', displayKey, Info.Text, KeyPicker.Mode)

			local kbMode = Library.KeybindMode or 'All'
			if kbMode == 'Active' then
				KeybindEntry.Visible = State == true
			elseif kbMode == 'Toggled' then
				local parentOn = false
				if ParentObj and ParentObj.Type == 'Toggle' then
					parentOn = ParentObj.Value == true
				elseif KeyPicker.SyncToggleState and ParentObj then
					parentOn = ParentObj.Value == true
				else
					parentOn = true
				end
				KeybindEntry.Visible = parentOn
			else
				KeybindEntry.Visible = true
			end

			local targetColor = State and Library.AccentColor or Library.FontColor
			if ContainerLabel.TextColor3 ~= targetColor then
				TweenService:Create(ContainerLabel, TweenInfo_Short, { TextColor3 = targetColor }):Play()
			end
			ContainerLabel.TextColor3 = targetColor

			local YSize = 0
			local XSize = 0
			for _, Frame in next, Library.KeybindContainer:GetChildren() do
				if Frame:IsA('Frame') and Frame.Visible then
					YSize = YSize + 18
					local LabelChild = Frame:FindFirstChildOfClass('TextLabel')
					if LabelChild and (LabelChild.TextBounds.X + 20 > XSize) then
						XSize = LabelChild.TextBounds.X + 20
					end
				end
			end
			Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 20, 210), 0, YSize + 23)
		end
		function KeyPicker:GetState()
			if KeyPicker.Mode == 'Always' then
				return true
			elseif KeyPicker.Mode == 'Hold' then
				if KeyPicker.Value == 'None' then return false end
				local Key = KeyPicker.Value
				if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then
					return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
						or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
						or Key == 'Touch' and true
				else
					return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value])
				end
			else
				return KeyPicker.Toggled
			end
		end

		function KeyPicker:SetValue(Data)
			local Key, Mode = Data[1], Data[2]
			DisplayLabel.Text = Key
			KeyPicker.Value = Key
			if ModeButtons[Mode] then
				ModeButtons[Mode]:Select()
			end
			KeyPicker:Update()
		end

		function KeyPicker:OnClick(Callback)
			KeyPicker.Clicked = Callback
		end

		function KeyPicker:OnChanged(Callback)
			KeyPicker.Changed = Callback
			Callback(KeyPicker.Value)
		end

		if ParentObj.Addons then
			table.insert(ParentObj.Addons, KeyPicker)
			table.insert(Library.KeyPickerList, KeyPicker)
		end

		function KeyPicker:DoClick()
			if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
				ParentObj:SetValue(not ParentObj.Value)
			end
			Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
			Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
		end

		local Picking = false
		PickOuter.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
				Picking = true
				DisplayLabel.Text = ''
				local Break
				local Text = ''
				task.spawn(function()
					while (not Break) do
						if Text == '...' then Text = '' end
						Text = Text .. '.'
						DisplayLabel.Text = Text
						task.wait(0.4)
					end
				end)
				task.wait(0.2)

				local Event
				Event = InputService.InputBegan:Connect(function(Input)
					local Key
					if Input.UserInputType == Enum.UserInputType.Keyboard then
						Key = Input.KeyCode.Name
					elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
						Key = 'MB1'
					elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
						Key = 'MB2'
					elseif Input.UserInputType == Enum.UserInputType.Touch then
						Key = 'Touch'
					end
					Break = true
					Picking = false
					DisplayLabel.Text = Key
					KeyPicker.Value = Key
					Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
					Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)
					Library:AttemptSave()
					Event:Disconnect()
				end)
			elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
				ModeSelectOuter.Visible = true
			end
		end)

		Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
			if (not Picking) then
				if KeyPicker.Mode == 'Toggle' then
					local Key = KeyPicker.Value
					if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then
						if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
						or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2
						or Key == 'Touch' and Input.UserInputType == Enum.UserInputType.Touch then
							KeyPicker.Toggled = not KeyPicker.Toggled
							KeyPicker:DoClick()
						end
					elseif Input.UserInputType == Enum.UserInputType.Keyboard then
						if Input.KeyCode.Name == Key then
							KeyPicker.Toggled = not KeyPicker.Toggled
							KeyPicker:DoClick()
						end
					end
				end
				KeyPicker:Update()
			end
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
				local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize
				if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
					or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
					ModeSelectOuter.Visible = false
				end
			end
		end))

		Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
			if (not Picking) then
				KeyPicker:Update()
			end
		end))

		KeyPicker:Update()
		Options[Idx] = KeyPicker
		return self
	end

	BaseAddons.__index = Funcs
	BaseAddons.__namecall = function(Table, Key, ...)
		return Funcs[Key](...)
	end
end
local BaseGroupbox = {}
do
	local Funcs = {}

	function Funcs:AddBlank(Size)
		local Groupbox = self
		local Container = Groupbox.Container
		Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 0, Size);
			ZIndex = 1;
			Parent = Container;
		})
	end

	function Funcs:AddRow(Columns)
		local Groupbox = self
		local Container = Groupbox.Container

		local ColumnsCount = type(Columns) == 'number' and math.max(1, Columns) or 2

		local RowOuter = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 0, 0);
			ZIndex = 1;
			Parent = Container;
		})

		Library:Create('UIListLayout', {
			FillDirection = Enum.FillDirection.Horizontal;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Padding = UDim.new(0, 8);
			Parent = RowOuter;
		})

		local Boxes = {}

		for i = 1, ColumnsCount do
			local Box = { Type = 'Groupbox' }

			local BoxContainer = Library:Create('Frame', {
				BackgroundTransparency = 1;
				Size = UDim2.new(1 / ColumnsCount, -((ColumnsCount - 1) * 8) / ColumnsCount, 1, 0);
				ZIndex = 1;
				Parent = RowOuter;
			})

			local BoxLayout = Library:Create('UIListLayout', {
				FillDirection = Enum.FillDirection.Vertical;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Padding = UDim.new(0, 4);
				Parent = BoxContainer;
			})

			Box.Container = BoxContainer
			setmetatable(Box, BaseGroupbox)

			function Box:Resize()
				local maxHeight = 0
				for _, child in next, RowOuter:GetChildren() do
					if child:IsA('Frame') then
						local layout = child:FindFirstChildOfClass('UIListLayout')
						if layout and layout.AbsoluteContentSize.Y > maxHeight then
							maxHeight = layout.AbsoluteContentSize.Y
						end
					end
				end
				RowOuter.Size = UDim2.new(1, 0, 0, maxHeight)
				if Groupbox.Resize then
					Groupbox:Resize()
				end
			end

			BoxLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				Box:Resize()
			end)

			table.insert(Boxes, Box)
		end

		Groupbox:AddBlank(1)
		if Groupbox.Resize then Groupbox:Resize() end

		return unpack(Boxes)
	end

	function Funcs:AddLabel(Text, DoesWrap)
		local Label = {}
		local Groupbox = self
		local Container = Groupbox.Container

		local TextLabel = Library:CreateLabel({
			Size = UDim2.new(1, -8, 0, 15);
			TextSize = Library.FontSize;
			Text = Text;
			TextWrapped = DoesWrap or false;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 5;
			Parent = Container;
		})
		if DoesWrap then
			local Y = select(2, Library:GetTextBounds(Text, Library.Font, Library.FontSize, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
			TextLabel.Size = UDim2.new(1, -8, 0, Y)
		end

		Label.TextLabel = TextLabel
		Label.Container = Container

		function Label:SetText(Text)
			TextLabel.Text = Text
			if DoesWrap then
				local Y = select(2, Library:GetTextBounds(Text, Library.Font, Library.FontSize, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
				TextLabel.Size = UDim2.new(1, -8, 0, Y)
			end
			Groupbox:Resize()
		end

		if (not DoesWrap) then
			setmetatable(Label, BaseAddons)
		end

		Groupbox:AddBlank(5)
		Groupbox:Resize()

		return Label
	end

	function Funcs:AddButton(...)
		local Button = {}

		local function ProcessButtonParams(Class, Obj, ...)
			local Props = select(1, ...)
			if type(Props) == 'table' then
				Obj.Text = Props.Text
				Obj.Func = Props.Func
				Obj.DoubleClick = Props.DoubleClick
				Obj.Tooltip = Props.Tooltip
			else
				Obj.Text = select(1, ...)
				Obj.Func = select(2, ...)
			end
			assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.')
		end

		ProcessButtonParams('Button', Button, ...)

		local Groupbox = self
		local Container = Groupbox.Container

		local function CreateBaseButton(Btn)
			local Outer = Library:Create('Frame', {
				BackgroundColor3 = Library.SurfaceColor;
				BorderSizePixel = 0;
				Size = UDim2.new(1, -8, 0, 28);
				ZIndex = 5;
			})
			Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = Outer; })
			Library:AddToRegistry(Outer, { BackgroundColor3 = 'SurfaceColor' })

			local Label = Library:CreateLabel({
				Size = UDim2.new(1, 0, 1, 0);
				TextSize = Library.FontSize;
				Text = Btn.Text;
				ZIndex = 6;
				Parent = Outer;
			})

			Outer.MouseEnter:Connect(function()
				TweenService:Create(Outer, TweenInfo_Short, { BackgroundColor3 = Library.AccentColor }):Play()
				TweenService:Create(Label, TweenInfo_Short, { TextColor3 = Color3.new(1, 1, 1) }):Play()
			end)
			Outer.MouseLeave:Connect(function()
				TweenService:Create(Outer, TweenInfo_Short, { BackgroundColor3 = Library.SurfaceColor }):Play()
				TweenService:Create(Label, TweenInfo_Short, { TextColor3 = Library.FontColor }):Play()
			end)

			return Outer, Label
		end

		local function InitEvents(Btn)
			local function WaitForEvent(event, timeout, validator)
				local bindable = Instance.new('BindableEvent')
				local connection = event:Once(function(...)
					if type(validator) == 'function' and validator(...) then
						bindable:Fire(true)
					else
						bindable:Fire(false)
					end
				end)
				task.delay(timeout, function()
					connection:Disconnect()
					bindable:Fire(false)
				end)
				return bindable.Event:Wait()
			end

			local function ValidateClick(Input)
				if Library:MouseIsOverOpenedFrame() then return false end
				if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
					return false
				end
				return true
			end

			Btn.Outer.InputBegan:Connect(function(Input)
				if not ValidateClick(Input) then return end
				if Btn.Locked then return end

				if Btn.DoubleClick then
					TweenService:Create(Btn.Label, TweenInfo_Short, { TextColor3 = Library.AccentColor }):Play()
					Btn.Label.Text = 'Are you sure?'
					Btn.Locked = true

					local clicked = WaitForEvent(Btn.Outer.InputBegan, 0.5, ValidateClick)

					TweenService:Create(Btn.Label, TweenInfo_Short, { TextColor3 = Library.FontColor }):Play()
					Btn.Label.Text = Btn.Text
					task.defer(rawset, Btn, 'Locked', false)

					if clicked then
						Library:SafeCallback(Btn.Func)
					end
					return
				end

				Library:SafeCallback(Btn.Func)
			end)
		end

		Button.Outer, Button.Label = CreateBaseButton(Button)
		Button.Outer.Parent = Container

		InitEvents(Button)

		function Button:AddButton(...)
			local SubButton = {}
			ProcessButtonParams('SubButton', SubButton, ...)

			self.Outer.Size = UDim2.new(0.5, -6, 0, 28)
			SubButton.Outer, SubButton.Label = CreateBaseButton(SubButton)

			SubButton.Outer.Position = UDim2.new(1, 4, 0, 0)
			SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
			SubButton.Outer.Parent = self.Outer

			if type(SubButton.Tooltip) == 'string' then
				Library:AddToolTip(SubButton.Tooltip, SubButton.Outer)
			end

			InitEvents(SubButton)
			return SubButton
		end

		if type(Button.Tooltip) == 'string' then
			Library:AddToolTip(Button.Tooltip, Button.Outer)
		end

		Groupbox:AddBlank(6)
		Groupbox:Resize()

		return Button
	end

	function Funcs:AddDivider()
		local Groupbox = self
		local Container = self.Container

		Groupbox:AddBlank(4)
		local Divider = Library:Create('Frame', {
			BackgroundColor3 = Library.OutlineColor;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -8, 0, 1);
			ZIndex = 5;
			Parent = Container;
		})
		Library:AddToRegistry(Divider, { BackgroundColor3 = 'OutlineColor' })
		Groupbox:AddBlank(8)
		Groupbox:Resize()
	end
	function Funcs:AddInput(Idx, Info)
		assert(Info.Text, 'AddInput: Missing `Text` string.')

		local Textbox = {
			Value = Info.Default or '';
			Numeric = Info.Numeric or false;
			Finished = Info.Finished or false;
			Type = 'Input';
			Callback = Info.Callback or function(Value) end;
		}
		local Groupbox = self
		local Container = Groupbox.Container

		local InputLabel = Library:CreateLabel({
			Size = UDim2.new(1, -8, 0, 15);
			TextSize = Library.FontSize;
			Text = Info.Text;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 5;
			Parent = Container;
		})

		Groupbox:AddBlank(2)

		local TextBoxOuter = Library:Create('Frame', {
			BackgroundColor3 = Library.SurfaceColor;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -8, 0, 26);
			ZIndex = 5;
			Parent = Container;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = TextBoxOuter; })
		Library:AddToRegistry(TextBoxOuter, { BackgroundColor3 = 'SurfaceColor' })

		local Box = Library:Create('TextBox', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 8, 0, 0);
			Size = UDim2.new(1, -12, 1, 0);
			Font = Library.Font;
			PlaceholderColor3 = Library.MutedColor;
			PlaceholderText = Info.Placeholder or '';
			Text = Info.Default or '';
			TextColor3 = Library.FontColor;
			TextSize = Library.FontSize;
			TextStrokeTransparency = 1;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 7;
			Parent = TextBoxOuter;
		})

		if type(Info.Tooltip) == 'string' then
			Library:AddToolTip(Info.Tooltip, TextBoxOuter)
		end

		function Textbox:SetValue(Text)
			if Info.MaxLength and #Text > Info.MaxLength then
				Text = Text:sub(1, Info.MaxLength)
			end
			if Textbox.Numeric then
				if (not tonumber(Text)) and Text:len() > 0 then
					Text = Textbox.Value
				end
			end
			Textbox.Value = Text
			Box.Text = Text
			Library:SafeCallback(Textbox.Callback, Textbox.Value)
			Library:SafeCallback(Textbox.Changed, Textbox.Value)
		end

		if Textbox.Finished then
			Box.FocusLost:Connect(function(enter)
				if not enter then return end
				Textbox:SetValue(Box.Text)
				Library:AttemptSave()
			end)
		else
			Box:GetPropertyChangedSignal('Text'):Connect(function()
				Textbox:SetValue(Box.Text)
			end)
		end

		local function Update()
			local PADDING = 2
			local reveal = TextBoxOuter.AbsoluteSize.X - 12
			if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
				Box.Position = UDim2.new(0, PADDING + 8, 0, 0)
			else
				local cursor = Box.CursorPosition
				if cursor ~= -1 then
					local subtext = string.sub(Box.Text, 1, cursor - 1)
					local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X
					local currentCursorPos = Box.Position.X.Offset + width
					if currentCursorPos < PADDING then
						Box.Position = UDim2.fromOffset(PADDING - width, 0)
					elseif currentCursorPos > reveal - PADDING - 1 then
						Box.Position = UDim2.fromOffset(reveal - width - PADDING - 1, 0)
					end
				end
			end
		end

		Box:GetPropertyChangedSignal('Text'):Connect(Update)
		Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
		Box.FocusLost:Connect(Update)
		Box.Focused:Connect(Update)

		Library:AddToRegistry(Box, { TextColor3 = 'FontColor' })

		function Textbox:OnChanged(Func)
			Textbox.Changed = Func
			Func(Textbox.Value)
		end

		Groupbox:AddBlank(6)
		Groupbox:Resize()

		Options[Idx] = Textbox
		return Textbox
	end

	function Funcs:AddToggle(Idx, Info)
		assert(Info.Text, 'AddToggle: Missing `Text` string.')

		local Toggle = {
			Value = Info.Default or false;
			Type = 'Toggle';
			Callback = Info.Callback or function(Value) end;
			Addons = {};
			Risky = Info.Risky;
		}
		local Groupbox = self
		local Container = Groupbox.Container

		local ToggleOuter = Library:Create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderSizePixel = 0;
			Size = UDim2.new(0, 13, 0, 13);
			ZIndex = 5;
			Parent = Container;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = ToggleOuter; })

		local ToggleInner = Library:Create('Frame', {
			BackgroundColor3 = Library.SurfaceColor;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 6;
			Parent = ToggleOuter;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = ToggleInner; })

		local ToggleLabel = Library:CreateLabel({
			Size = UDim2.new(1, -24, 1, 0);
			Position = UDim2.new(0, 19, 0, 0);
			TextSize = Library.FontSize;
			Text = Info.Text;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 6;
			Parent = ToggleOuter;
		})
		ToggleOuter.Size = UDim2.new(1, -8, 0, 15)

		local ToggleRegion = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 8;
			Parent = ToggleOuter;
		})

		if type(Info.Tooltip) == 'string' then
			Library:AddToolTip(Info.Tooltip, ToggleRegion)
		end

		if Toggle.Risky then
			Library:RemoveFromRegistry(ToggleLabel)
			ToggleLabel.TextColor3 = Library.RiskColor
			Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
		end

		function Toggle:Display()
			local targetColor = Toggle.Value and Library.AccentColor or Library.SurfaceColor
			if ToggleInner.BackgroundColor3 ~= targetColor then
				TweenService:Create(ToggleInner, TweenInfo_Short, {
					BackgroundColor3 = targetColor;
				}):Play()
			end
			ToggleInner.BackgroundColor3 = targetColor
		end

		function Toggle:OnChanged(Func)
			Toggle.Changed = Func
			Func(Toggle.Value)
		end

		function Toggle:SetValue(Bool)
			Bool = (not not Bool)
			Toggle.Value = Bool
			Toggle:Display()

			for _, Addon in next, Toggle.Addons do
				if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
					Addon.Toggled = Bool
					Addon:Update()
				end
			end
			Library:SafeCallback(Toggle.Callback, Toggle.Value)
			Library:SafeCallback(Toggle.Changed, Toggle.Value)
			Library:UpdateDependencyBoxes()
		end

		ToggleRegion.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
				Toggle:SetValue(not Toggle.Value)
				Library:AttemptSave()
			end
		end)

		Toggle:Display()
		Groupbox:AddBlank(Info.BlankSize or 6)
		Groupbox:Resize()

		Toggle.TextLabel = ToggleLabel
		Toggle.Container = Container
		setmetatable(Toggle, BaseAddons)

		Toggles[Idx] = Toggle
		Library:UpdateDependencyBoxes()

		return Toggle
	end
	function Funcs:AddSlider(Idx, Info)
		assert(Info.Default, 'AddSlider: Missing default value.')
		assert(Info.Text, 'AddSlider: Missing slider text.')
		assert(Info.Min, 'AddSlider: Missing minimum value.')
		assert(Info.Max, 'AddSlider: Missing maximum value.')
		assert(Info.Rounding, 'AddSlider: Missing rounding value.')

		local Slider = {
			Value = Info.Default;
			Min = Info.Min;
			Max = Info.Max;
			Rounding = Info.Rounding;
			MaxSize = 232;
			Type = 'Slider';
			Callback = Info.Callback or function(Value) end;
		}
		local Groupbox = self
		local Container = Groupbox.Container

		if not Info.Compact then
			Library:CreateLabel({
				Size = UDim2.new(1, -8, 0, 12);
				TextSize = Library.FontSize;
				Text = Info.Text;
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Bottom;
				ZIndex = 5;
				Parent = Container;
			})
			Groupbox:AddBlank(4)
		end

		local SliderOuter = Library:Create('Frame', {
			BackgroundColor3 = Library.SurfaceColor;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -8, 0, 16);
			ZIndex = 5;
			Parent = Container;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = SliderOuter; })
		Library:AddToRegistry(SliderOuter, { BackgroundColor3 = 'SurfaceColor' })

		local Fill = Library:Create('Frame', {
			BackgroundColor3 = Library.AccentColor;
			BorderSizePixel = 0;
			Size = UDim2.new(0, 0, 1, 0);
			ZIndex = 7;
			Parent = SliderOuter;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = Fill; })

		SliderOuter.ClipsDescendants = true

		Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' })

		local DisplayLabel = Library:CreateLabel({
			Size = UDim2.new(1, -8, 1, 0);
			Position = UDim2.new(0, 4, 0, 0);
			TextSize = Library.FontSize;
			Text = 'Infinite';
			ZIndex = 9;
			Parent = SliderOuter;
			TextXAlignment = Enum.TextXAlignment.Center;
		})

		if type(Info.Tooltip) == 'string' then
			Library:AddToolTip(Info.Tooltip, SliderOuter)
		end

		function Slider:Display()
			local Suffix = Info.Suffix or ''
			if Info.Compact then
				DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
			elseif Info.HideMax then
				DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
			else
				DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix)
			end

			local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, SliderOuter.AbsoluteSize.X))
			TweenService:Create(Fill, TweenInfo_Med, { Size = UDim2.new(0, X, 1, 0) }):Play()
		end

		function Slider:OnChanged(Func)
			Slider.Changed = Func
			Func(Slider.Value)
		end

		local function Round(Value)
			if Slider.Rounding == 0 then
				return math.floor(Value)
			end
			return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
		end

		function Slider:GetValueFromXOffset(X)
			return Round(Library:MapValue(X, 0, SliderOuter.AbsoluteSize.X, Slider.Min, Slider.Max))
		end

		function Slider:SetValue(Str)
			local Num = tonumber(Str)
			if not Num then return end
			Num = math.clamp(Num, Slider.Min, Slider.Max)
			Slider.Value = Num
			Slider:Display()
			Library:SafeCallback(Slider.Callback, Slider.Value)
			Library:SafeCallback(Slider.Changed, Slider.Value)
		end

		SliderOuter.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
				local function UpdateSlider(PosX)
					local gPos = SliderOuter.AbsolutePosition.X
					local Diff = PosX - gPos
					local nX = math.clamp(Diff, 0, SliderOuter.AbsoluteSize.X)
					local nValue = Slider:GetValueFromXOffset(nX)
					local OldValue = Slider.Value
					Slider.Value = nValue
					Slider:Display()
					if nValue ~= OldValue then
						Library:SafeCallback(Slider.Callback, Slider.Value)
						Library:SafeCallback(Slider.Changed, Slider.Value)
					end
				end

				UpdateSlider(Input.Position.X)

				local ChangedConn = InputService.InputChanged:Connect(function(Change)
					if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
						UpdateSlider(Change.Position.X)
					end
				end)

				local EndedConn
				EndedConn = InputService.InputEnded:Connect(function(EndInput)
					if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
						ChangedConn:Disconnect()
						EndedConn:Disconnect()
						Library:AttemptSave()
					end
				end)
			end
		end)

		Slider:Display()
		Groupbox:AddBlank(Info.BlankSize or 7)
		Groupbox:Resize()

		Options[Idx] = Slider
		return Slider
	end
	function Funcs:AddDropdown(Idx, Info)
		if Info.SpecialType == 'Player' then
			Info.Values = GetPlayersString()
			Info.AllowNull = true
		elseif Info.SpecialType == 'Team' then
			Info.Values = GetTeamsString()
			Info.AllowNull = true
		end

		assert(Info.Values, 'AddDropdown: Missing dropdown value list.')
		assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

		if (not Info.Text) then
			Info.Compact = true
		end

		local Dropdown = {
			Values = Info.Values;
			Value = Info.Multi and {};
			Multi = Info.Multi;
			Type = 'Dropdown';
			SpecialType = Info.SpecialType;
			Callback = Info.Callback or function(Value) end;
		}

		local Groupbox = self
		local Container = Groupbox.Container

		local RelativeOffset = 0

		if not Info.Compact then
			Library:CreateLabel({
				Size = UDim2.new(1, -8, 0, 12);
				TextSize = Library.FontSize;
				Text = Info.Text;
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Bottom;
				ZIndex = 5;
				Parent = Container;
			})
			Groupbox:AddBlank(3)
		end

		for _, Element in next, Container:GetChildren() do
			if not Element:IsA('UIListLayout') then
				RelativeOffset = RelativeOffset + Element.Size.Y.Offset
			end
		end

		local DropdownOuter = Library:Create('Frame', {
			BackgroundColor3 = Library.SurfaceColor;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -8, 0, 26);
			ZIndex = 5;
			Parent = Container;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = DropdownOuter; })
		Library:AddToRegistry(DropdownOuter, { BackgroundColor3 = 'SurfaceColor' })

		local DropdownArrow = Library:Create('ImageLabel', {
			AnchorPoint = Vector2.new(0, 0.5);
			BackgroundTransparency = 1;
			Position = UDim2.new(1, -18, 0.5, 0);
			Size = UDim2.new(0, 10, 0, 10);
			Image = 'http://www.roblox.com/asset/?id=6031094673';
			ZIndex = 8;
			Parent = DropdownOuter;
		})

		local ItemList = Library:CreateLabel({
			Position = UDim2.new(0, 8, 0, 0);
			Size = UDim2.new(1, -24, 1, 0);
			TextSize = Library.FontSize;
			Text = '--';
			TextXAlignment = Enum.TextXAlignment.Left;
			TextWrapped = true;
			ZIndex = 7;
			Parent = DropdownOuter;
		})

		if type(Info.Tooltip) == 'string' then
			Library:AddToolTip(Info.Tooltip, DropdownOuter)
		end

		local MAX_DROPDOWN_ITEMS = 8
		local ListOuter = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderSizePixel = 0;
			ZIndex = 20;
			Visible = false;
			Parent = ScreenGui;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = ListOuter; })

		ListShadow = Library:Create('ImageLabel', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 20;
			Image = 'http://www.roblox.com/asset/?id=13100794983';
			ImageColor3 = Color3.new(0, 0, 0);
			ScaleType = Enum.ScaleType.Slice;
			SliceCenter = Rect.new(10, 10, 10, 10);
			Parent = ListOuter;
		})
		Library:AddToRegistry(ListOuter, { BackgroundColor3 = 'BackgroundColor' })

		local function RecalculateListPosition()
			ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 2)
		end

		local function RecalculateListSize(YSize)
			ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 24 + 2))
		end

		RecalculateListPosition()
		RecalculateListSize()
		DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition)

		local Scrolling = Library:Create('ScrollingFrame', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			CanvasSize = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 21;
			Parent = ListOuter;
			TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
			BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
			ScrollBarThickness = 2;
			ScrollBarImageColor3 = Library.AccentColor;
		})
		Library:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' })

		Library:Create('UIListLayout', {
			Padding = UDim.new(0, 1);
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = Scrolling;
		})

		function Dropdown:Display()
			local Values = Dropdown.Values
			local Str = ''
			if Info.Multi then
				for Idx, Value in next, Values do
					if Dropdown.Value[Value] then
						Str = Str .. Value .. ', '
					end
				end
				Str = Str:sub(1, #Str - 2)
			else
				Str = Dropdown.Value or ''
			end
			ItemList.Text = (Str == '' and '--' or Str)
		end

		function Dropdown:GetActiveValues()
			if Info.Multi then
				local T = {}
				for Value, Bool in next, Dropdown.Value do
					table.insert(T, Value)
				end
				return T
			else
				return Dropdown.Value and 1 or 0
			end
		end

		function Dropdown:BuildDropdownList()
			local Values = Dropdown.Values
			local Buttons = {}

			for _, Element in next, Scrolling:GetChildren() do
				if not Element:IsA('UIListLayout') then
					Element:Destroy()
				end
			end

			local Count = 0

			for Idx, Value in next, Values do
				local Table = {}
				Count = Count + 1

				local Button = Library:Create('Frame', {
					BackgroundTransparency = 1;
					Size = UDim2.new(1, 0, 0, 22);
					ZIndex = 23;
					Parent = Scrolling;
				})
				Library:AddToRegistry(Button, {})

				local ButtonLabel = Library:CreateLabel({
					Active = false;
					Size = UDim2.new(1, -10, 1, 0);
					Position = UDim2.new(0, 8, 0, 0);
					TextSize = Library.FontSize - 1;
					Text = Value;
					TextXAlignment = Enum.TextXAlignment.Left;
					ZIndex = 25;
					Parent = Button;
				})

				Button.MouseEnter:Connect(function()
					TweenService:Create(ButtonLabel, TweenInfo_Short, { TextColor3 = Library.AccentColor }):Play()
				end)
				Button.MouseLeave:Connect(function()
					if not Table:IsSelected() then
						TweenService:Create(ButtonLabel, TweenInfo_Short, { TextColor3 = Library.FontColor }):Play()
					end
				end)

				local Selected

				if Info.Multi then
					Selected = Dropdown.Value[Value]
				else
					Selected = Dropdown.Value == Value
				end

				function Table:UpdateButton()
					if Info.Multi then
						Selected = Dropdown.Value[Value]
					else
						Selected = Dropdown.Value == Value
					end
					local targetColor = Selected and Library.AccentColor or Library.FontColor
					if ButtonLabel.TextColor3 ~= targetColor then
						TweenService:Create(ButtonLabel, TweenInfo_Short, { TextColor3 = targetColor }):Play()
					end
				end

				function Table:IsSelected()
					return Selected
				end

				ButtonLabel.InputBegan:Connect(function(Input)
					if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
						local Try = not Selected
						if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
						else
							if Info.Multi then
								Selected = Try
								if Selected then
									Dropdown.Value[Value] = true
								else
									Dropdown.Value[Value] = nil
								end
							else
								Selected = Try
								if Selected then
									Dropdown.Value = Value
								else
									Dropdown.Value = nil
								end
								for _, OtherButton in next, Buttons do
									OtherButton:UpdateButton()
								end
							end
							Table:UpdateButton()
							Dropdown:Display()
							Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
							Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
							Library:AttemptSave()
						end
					end
				end)

				Table:UpdateButton()
				Dropdown:Display()

				Buttons[Button] = Table
			end
			Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 22) + 1)

			local Y = math.clamp(Count * 22, 0, MAX_DROPDOWN_ITEMS * 22) + 1
			RecalculateListSize(Y)
		end

		function Dropdown:SetValues(NewValues)
			if NewValues then
				Dropdown.Values = NewValues
			end
			Dropdown:BuildDropdownList()
		end

		function Dropdown:OpenDropdown()
			ListOuter.Visible = true
			Library.OpenedFrames[ListOuter] = true
			TweenService:Create(DropdownArrow, TweenInfo_Short, { Rotation = 180 }):Play()
		end

		function Dropdown:CloseDropdown()
			ListOuter.Visible = false
			Library.OpenedFrames[ListOuter] = nil
			TweenService:Create(DropdownArrow, TweenInfo_Short, { Rotation = 0 }):Play()
		end

		function Dropdown:OnChanged(Func)
			Dropdown.Changed = Func
			Func(Dropdown.Value)
		end

		function Dropdown:SetValue(Val)
			if Dropdown.Multi then
				local nTable = {}
				for Value, Bool in next, Val do
					if table.find(Dropdown.Values, Value) then
						nTable[Value] = true
					end
				end
				Dropdown.Value = nTable
			else
				if (not Val) then
					Dropdown.Value = nil
				elseif table.find(Dropdown.Values, Val) then
					Dropdown.Value = Val
				end
			end
			Dropdown:BuildDropdownList()
			Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
			Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
		end

		DropdownOuter.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
				if ListOuter.Visible then
					Dropdown:CloseDropdown()
				else
					Dropdown:OpenDropdown()
				end
			end
		end)

		InputService.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
				local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize
				if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
					or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
					Dropdown:CloseDropdown()
				end
			end
		end)

		Dropdown:BuildDropdownList()
		Dropdown:Display()

		local Defaults = {}
		if type(Info.Default) == 'string' then
			local Idx = table.find(Dropdown.Values, Info.Default)
			if Idx then table.insert(Defaults, Idx) end
		elseif type(Info.Default) == 'table' then
			for _, Value in next, Info.Default do
				local Idx = table.find(Dropdown.Values, Value)
				if Idx then table.insert(Defaults, Idx) end
			end
		elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
			table.insert(Defaults, Info.Default)
		end

		if next(Defaults) then
			for i = 1, #Defaults do
				local Index = Defaults[i]
				if Info.Multi then
					Dropdown.Value[Dropdown.Values[Index]] = true
				else
					Dropdown.Value = Dropdown.Values[Index]
				end
				if (not Info.Multi) then break end
			end
			Dropdown:BuildDropdownList()
			Dropdown:Display()
		end

		Groupbox:AddBlank(Info.BlankSize or 6)
		Groupbox:Resize()

		Options[Idx] = Dropdown
		return Dropdown
	end
	function Funcs:AddDependencyBox()
		local Depbox = {
			Dependencies = {};
		}

		local Groupbox = self
		local Container = Groupbox.Container

		local Holder = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 0, 0);
			Visible = false;
			Parent = Container;
		})
		local Frame = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			Visible = true;
			Parent = Holder;
		})
		local Layout = Library:Create('UIListLayout', {
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = Frame;
		})

		function Depbox:Resize()
			Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y)
			Groupbox:Resize()
		end

		Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			Depbox:Resize()
		end)
		Holder:GetPropertyChangedSignal('Visible'):Connect(function()
			Depbox:Resize()
		end)

		function Depbox:Update()
			for _, Dependency in next, Depbox.Dependencies do
				local Elem = Dependency[1]
				local Value = Dependency[2]
				if Elem.Type == 'Toggle' and Elem.Value ~= Value then
					Holder.Visible = false
					Depbox:Resize()
					return
				end
			end
			Holder.Visible = true
			Depbox:Resize()
		end

		function Depbox:SetupDependencies(Dependencies)
			for _, Dependency in next, Dependencies do
				assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.')
				assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.')
				assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.')
			end
			Depbox.Dependencies = Dependencies
			Depbox:Update()
		end

		Depbox.Container = Frame
		setmetatable(Depbox, BaseGroupbox)
		table.insert(Library.DependencyBoxes, Depbox)
		return Depbox
	end

	BaseGroupbox.__index = Funcs
	BaseGroupbox.__namecall = function(Table, Key, ...)
		return Funcs[Key](...)
	end
end
do
	Library.NotificationArea = Library:Create('Frame', {
		BackgroundTransparency = 1;
		Position = UDim2.new(0, Library.NotifyConfig.PositionX, 0, Library.NotifyConfig.PositionY);
		Size = UDim2.new(0, 320, 1, -Library.NotifyConfig.PositionY);
		ZIndex = 100;
		Parent = ScreenGui;
	})
	Library.NotifLayout = Library:Create('UIListLayout', {
		Padding = UDim.new(0, 6);
		FillDirection = Enum.FillDirection.Vertical;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = Library.NotificationArea;
	})

	local function Library_UpdateNotifAlignment()
		local cfg = Library.NotifyConfig
		local area = Library.NotificationArea
		local layout = Library.NotifLayout

		area.Position = UDim2.new(0, cfg.PositionX, 0, cfg.PositionY)
		area.Size = UDim2.new(0, 320, 1, -cfg.PositionY)

		local align = cfg.Alignment or 'Left'
		if align == 'Left' then
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			area.AnchorPoint = Vector2.new(0, 0)
		elseif align == 'Right' then
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			area.AnchorPoint = Vector2.new(1, 0)
		elseif align == 'Center' then
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			area.AnchorPoint = Vector2.new(0.5, 0)
		end
	end
	Library.UpdateNotifAlignment = Library_UpdateNotifAlignment
	Library_UpdateNotifAlignment()

	Library.Watermark = Library:Create('Frame', {
		BackgroundColor3 = Library.SurfaceColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 16, 0, -30);
		Size = UDim2.new(0, 213, 0, 26);
		ZIndex = 200;
		Visible = false;
		Parent = ScreenGui;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = Library.Watermark; })

	local WatermarkShadow = Library:Create('ImageLabel', {
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 200;
		Image = 'http://www.roblox.com/asset/?id=13100794983';
		ImageColor3 = Color3.new(0, 0, 0);
		ScaleType = Enum.ScaleType.Slice;
		SliceCenter = Rect.new(10, 10, 10, 10);
		Parent = Library.Watermark;
	})

	local WatermarkInner = Library:Create('Frame', {
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 202;
		Parent = Library.Watermark;
	})

	Library.WatermarkAccent = Library:Create('Frame', {
		BackgroundColor3 = Library.AccentColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 1, -2);
		Size = UDim2.new(1, 0, 0, 2);
		ZIndex = 204;
		Parent = Library.Watermark;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 1); Parent = Library.WatermarkAccent; })
	Library:AddToRegistry(Library.WatermarkAccent, { BackgroundColor3 = 'AccentColor' })

	WatermarkLabel = Library:CreateLabel({
		Position = UDim2.new(0, 10, 0, 0);
		Size = UDim2.new(1, -14, 1, 0);
		TextSize = Library.FontSize;
		TextXAlignment = Enum.TextXAlignment.Left;
		ZIndex = 203;
		Parent = WatermarkInner;
	})
	Library.WatermarkText = WatermarkLabel

	Library:MakeDraggable(Library.Watermark)

	local KeybindOuter = Library:Create('Frame', {
		AnchorPoint = Vector2.new(0, 0.5);
		BorderSizePixel = 0;
		Position = UDim2.new(0, 16, 0.5, 0);
		Size = UDim2.new(0, 210, 0, 20);
		Visible = false;
		ZIndex = 100;
		Parent = ScreenGui;
	})

	local LocalKeybindInner = Library:Create('Frame', {
		BackgroundColor3 = Library.MainColor;
		BorderSizePixel = 0;
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 101;
		Parent = KeybindOuter;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = KeybindOuter; })
	Library:AddToRegistry(LocalKeybindInner, { BackgroundColor3 = 'MainColor' }, true)

	local KeybindShadow = Library:Create('ImageLabel', {
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 100;
		Image = 'http://www.roblox.com/asset/?id=13100794983';
		ImageColor3 = Color3.new(0, 0, 0);
		ScaleType = Enum.ScaleType.Slice;
		SliceCenter = Rect.new(10, 10, 10, 10);
		Parent = KeybindOuter;
	})

	local KColorFrame = Library:Create('Frame', {
		BackgroundColor3 = Library.AccentColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 0, 0);
		Size = UDim2.new(1, 0, 0, 2);
		ZIndex = 102;
		Parent = LocalKeybindInner;
	})
	Library:AddToRegistry(KColorFrame, { BackgroundColor3 = 'AccentColor' }, true)

	local KeybindLabel = Library:CreateLabel({
		Size = UDim2.new(1, -10, 0, 20);
		Position = UDim2.fromOffset(8, 2);
		TextXAlignment = Enum.TextXAlignment.Left;
		Text = 'Keybinds';
		ZIndex = 104;
		Parent = LocalKeybindInner;
	})

	local KeybindContainer = Library:Create('Frame', {
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 1, -24);
		Position = UDim2.new(0, 0, 0, 24);
		ZIndex = 1;
		Parent = LocalKeybindInner;
	})
	Library:Create('UIListLayout', {
		FillDirection = Enum.FillDirection.Vertical;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = KeybindContainer;
	})
	Library:Create('UIPadding', {
		PaddingLeft = UDim.new(0, 8);
		Parent = KeybindContainer;
	})

	Library.KeybindFrame = KeybindOuter
	Library.KeybindContainer = KeybindContainer
	Library:MakeDraggable(KeybindOuter)
end
function Library:SetKeybindMode(Mode)
	assert(Mode == 'All' or Mode == 'Active' or Mode == 'Toggled',
		"SetKeybindMode: Mode must be 'All', 'Active', or 'Toggled'")
	Library.KeybindMode = Mode
	Library:RefreshKeybinds()
end

function Library:RefreshKeybinds()
	for _, kp in ipairs(Library.KeyPickerList) do
		if not kp.NoUI then
			pcall(function() kp:Update() end)
		end
	end
end

function Library:SetWatermarkVisibility(Bool)
	Library.Watermark.Visible = Bool
end

function Library:SetWatermark(Text)
	local X, Y = Library:GetTextBounds(Text, Library.Font, Library.FontSize)
	Library.Watermark.Size = UDim2.new(0, X + 24, 0, (Y * 1.5) + 6)
	Library:SetWatermarkVisibility(true)
	Library.WatermarkText.Text = Text
end

function Library:Notify(Text, Time)
	local cfg = Library.NotifyConfig
	local barSide = cfg.BarSide or 'Left'
	local align = cfg.Alignment or 'Left'

	local XSize, YSize = Library:GetTextBounds(Text, Library.Font, Library.FontSize)
	YSize = math.max(YSize + 12, 36)

	local outerAnchor = Vector2.new(0, 0)
	if align == 'Center' then
		outerAnchor = Vector2.new(0.5, 0)
	elseif align == 'Right' then
		outerAnchor = Vector2.new(1, 0)
	end

	local NotifyOuter = Library:Create('Frame', {
		BackgroundColor3 = Library.SurfaceColor;
		BorderSizePixel = 0;
		AnchorPoint = outerAnchor;
		Position = (align == 'Center') and UDim2.new(0.5, 0, 0, 0)
			or (align == 'Right' and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0));
		Size = UDim2.new(0, 0, 0, YSize);
		ClipsDescendants = true;
		ZIndex = 100;
		Parent = Library.NotificationArea;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = NotifyOuter; })

	local AccentBar = Library:Create('Frame', {
		BackgroundColor3 = Library.AccentColor;
		BorderSizePixel = 0;
		ZIndex = 104;
		Parent = NotifyOuter;
	})
	if barSide == 'Left' then
		AccentBar.Position = UDim2.new(0, 0, 0, 0)
		AccentBar.Size = UDim2.new(0, 3, 1, 0)
	elseif barSide == 'Right' then
		AccentBar.Position = UDim2.new(1, -3, 0, 0)
		AccentBar.Size = UDim2.new(0, 3, 1, 0)
	elseif barSide == 'Top' then
		AccentBar.Position = UDim2.new(0, 0, 0, 0)
		AccentBar.Size = UDim2.new(1, 0, 0, 2)
	elseif barSide == 'Bottom' then
		AccentBar.Position = UDim2.new(0, 0, 1, -2)
		AccentBar.Size = UDim2.new(1, 0, 0, 2)
	end
	Library:AddToRegistry(AccentBar, { BackgroundColor3 = 'AccentColor' }, true)

	local NotifyLabel = Library:CreateLabel({
		Position = UDim2.new(0, 12, 0, 0);
		Size = UDim2.new(1, -20, 1, 0);
		Text = Text;
		TextXAlignment = (align == 'Center') and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left;
		TextSize = Library.FontSize;
		ZIndex = 103;
		Parent = NotifyOuter;
	})

	local finalWidth = math.min(XSize + 24 + 8, 320)

	task.spawn(function()
		TweenService:Create(NotifyOuter, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, finalWidth, 0, YSize)
		}):Play()

		task.wait(Time or 5)

		TweenService:Create(NotifyOuter, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, YSize)
		}):Play()
		task.wait(0.3)
		NotifyOuter:Destroy()
	end)
end

function Library:AddToolTip(InfoStr, HoverInstance)
	local X, Y = Library:GetTextBounds(InfoStr, Library.Font, Library.FontSize)
	local Tooltip = Library:Create('Frame', {
		BackgroundColor3 = Library.BackgroundColor;
		BorderSizePixel = 0;
		Size = UDim2.fromOffset(X + 16, Y + 8);
		ZIndex = 100;
		Parent = Library.ScreenGui;
		Visible = false;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = Tooltip; })

	local TooltipShadow = Library:Create('ImageLabel', {
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 100;
		Image = 'http://www.roblox.com/asset/?id=13100794983';
		ImageColor3 = Color3.new(0, 0, 0);
		ScaleType = Enum.ScaleType.Slice;
		SliceCenter = Rect.new(10, 10, 10, 10);
		Parent = Tooltip;
	})

	local Label = Library:CreateLabel({
		Position = UDim2.fromOffset(8, 4);
		Size = UDim2.fromOffset(X, Y);
		TextSize = Library.FontSize - 1;
		Text = InfoStr;
		TextColor3 = Library.FontColor;
		TextXAlignment = Enum.TextXAlignment.Left;
		ZIndex = Tooltip.ZIndex + 1;
		Parent = Tooltip;
	})
	Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'BackgroundColor' })

	local IsHovering = false

	HoverInstance.MouseEnter:Connect(function()
		if Library:MouseIsOverOpenedFrame() then return end
		IsHovering = true
		Tooltip.Position = UDim2.fromOffset(Mouse.X + 16, Mouse.Y + 12)
		Tooltip.Visible = true
		while IsHovering do
			RunService.Heartbeat:Wait()
			Tooltip.Position = UDim2.fromOffset(Mouse.X + 16, Mouse.Y + 12)
		end
	end)

	HoverInstance.MouseLeave:Connect(function()
		IsHovering = false
		Tooltip.Visible = false
	end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
	HighlightInstance.MouseEnter:Connect(function()
		local Reg = Library.RegistryMap[Instance]
		for Property, ColorIdx in next, Properties do
			Instance[Property] = Library[ColorIdx] or ColorIdx
			if Reg and Reg.Properties[Property] then
				Reg.Properties[Property] = ColorIdx
			end
		end
	end)

	HighlightInstance.MouseLeave:Connect(function()
		local Reg = Library.RegistryMap[Instance]
		for Property, ColorIdx in next, PropertiesDefault do
			Instance[Property] = Library[ColorIdx] or ColorIdx
			if Reg and Reg.Properties[Property] then
				Reg.Properties[Property] = ColorIdx
			end
		end
	end)
end
function Library:CreateWindow(...)
	local Arguments = { ... }
	local Config = { AnchorPoint = Vector2.zero }

	if type(...) == 'table' then
		Config = ...
	else
		Config.Title = Arguments[1]
		Config.AutoShow = Arguments[2] or false
	end

	if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
	if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
	if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

	if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(600, 620) end
	if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(200, 50) end

	if InputService.TouchEnabled then
		local vp = workspace.CurrentCamera.ViewportSize
		local maxWidth = math.min(Config.Size.X.Offset, vp.X - 20)
		local maxHeight = math.min(Config.Size.Y.Offset, vp.Y - 60)
		Config.Size = UDim2.fromOffset(maxWidth, maxHeight)
	end

	if Config.Center then
		Config.AnchorPoint = Vector2.new(0.5, 0.5)
		Config.Position = UDim2.fromScale(0.5, 0.5)
	end

	local Window = { Tabs = {} }

	local Outer = Library:Create('Frame', {
		AnchorPoint = Config.AnchorPoint;
		BackgroundColor3 = Color3.new(0, 0, 0);
		BorderSizePixel = 0;
		Position = Config.Position;
		Size = Config.Size;
		Visible = false;
		ZIndex = 1;
		Parent = ScreenGui;
	})
	Library:MakeDraggable(Outer, 32, true)

	Window.BaseFrame = Outer

	local Inner = Library:Create('Frame', {
		Name = "Inner";
		BackgroundColor3 = Library.MainColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 0, 0);
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 1;
		Parent = Outer;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 8); Parent = Outer; })
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 8); Parent = Inner; })
	Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor' })

	local TitleBar = Library:Create('Frame', {
		BackgroundColor3 = Library.BackgroundColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 0, 0);
		Size = UDim2.new(1, 0, 0, 32);
		ZIndex = 2;
		Parent = Inner;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 8); Parent = TitleBar; })
	Library:AddToRegistry(TitleBar, { BackgroundColor3 = 'BackgroundColor' })

	local TitleAccent = Library:Create('Frame', {
		BackgroundColor3 = Library.AccentColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 1, -2);
		Size = UDim2.new(1, 0, 0, 2);
		ZIndex = 3;
		Parent = TitleBar;
	})
	Library:AddToRegistry(TitleAccent, { BackgroundColor3 = 'AccentColor' })

	local WindowLabel = Library:CreateLabel({
		Position = UDim2.new(0, 12, 0, 0);
		Size = UDim2.new(1, -24, 1, 0);
		Text = Config.Title or '';
		RichText = true;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextSize = Library.FontSize + 2;
		ZIndex = 3;
		Parent = TitleBar;
	})

	local MapNameLabel = Library:CreateLabel({
		AnchorPoint = Vector2.new(1, 0);
		Position = UDim2.new(1, -12, 0, 0);
		Size = UDim2.new(0, 200, 1, 0);
		Text = 'Loading...';
		TextColor3 = Library.MutedColor;
		TextXAlignment = Enum.TextXAlignment.Right;
		TextSize = Library.FontSize - 1;
		ZIndex = 3;
		Parent = TitleBar;
	})
	Library:AddToRegistry(MapNameLabel, { TextColor3 = 'MutedColor' })

	task.spawn(function()
		local success, info = pcall(function()
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		end)
		if success and info and info.Name then
			MapNameLabel.Text = info.Name
		else
			MapNameLabel.Text = ''
		end
	end)

	local TabBarOuter = Library:Create('Frame', {
		BackgroundColor3 = Library.BackgroundColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 8, 0, 36);
		Size = UDim2.new(1, -16, 0, 29);
		ZIndex = 1;
		Parent = Inner;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = TabBarOuter; })
	Library:AddToRegistry(TabBarOuter, { BackgroundColor3 = 'BackgroundColor' })

	local TabArea = Library:Create('Frame', {
		BackgroundTransparency = 1;
		Position = UDim2.new(0, 4, 0, 4);
		Size = UDim2.new(1, -8, 1, -8);
		ZIndex = 1;
		Parent = TabBarOuter;
	})

	local TabListLayout = Library:Create('UIListLayout', {
		Padding = UDim.new(0, Config.TabPadding);
		FillDirection = Enum.FillDirection.Horizontal;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = TabArea;
	})

	local MainSectionOuter = Library:Create('Frame', {
		BackgroundColor3 = Library.BackgroundColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 8, 0, 70);
		Size = UDim2.new(1, -16, 1, -78);
		ZIndex = 1;
		Parent = Inner;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = MainSectionOuter; })
	Library:AddToRegistry(MainSectionOuter, { BackgroundColor3 = 'BackgroundColor' })

	local MainSectionInner = Library:Create('Frame', {
		BackgroundColor3 = Library.BackgroundColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 0, 0);
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 1;
		Parent = MainSectionOuter;
	})

	local TabContainer = Library:Create('Frame', {
		BackgroundColor3 = Library.SurfaceColor;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 4, 0, 4);
		Size = UDim2.new(1, -8, 1, -8);
		ZIndex = 2;
		Parent = MainSectionInner;
	})
	Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = TabContainer; })
	Library:AddToRegistry(TabContainer, { BackgroundColor3 = 'SurfaceColor' })

	function Window:SetWindowTitle(Title)
		TweenService:Create(WindowLabel, TweenInfo_Short, { TextTransparency = 1 }):Play()
		task.delay(0.15, function()
			WindowLabel.Text = Title
			TweenService:Create(WindowLabel, TweenInfo_Short, { TextTransparency = 0 }):Play()
		end)
	end

	function Window:AddTab(Name)
		local Tab = {
			Groupboxes = {};
			Tabboxes = {};
		}

		local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, Library.FontSize + 2)

		local TabButton = Library:Create('Frame', {
			BackgroundColor3 = Library.BackgroundColor;
			BorderSizePixel = 0;
			Size = UDim2.new(0, TabButtonWidth + 16, 1, 0);
			ZIndex = 1;
			Parent = TabArea;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = TabButton; })
		Library:AddToRegistry(TabButton, { BackgroundColor3 = 'BackgroundColor' })

		local TabButtonLabel = Library:CreateLabel({
			Position = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 1, 0);
			Text = Name;
			TextSize = Library.FontSize;
			ZIndex = 2;
			Parent = TabButton;
		})

		local TabIndicator = Library:Create('Frame', {
			BackgroundColor3 = Library.AccentColor;
			BorderSizePixel = 0;
			Position = UDim2.new(0, 2, 0, 0);
			Size = UDim2.new(1, -4, 0, 2);
			Visible = false;
			ZIndex = 4;
			Parent = TabButton;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 1); Parent = TabIndicator; })
		Library:AddToRegistry(TabIndicator, { BackgroundColor3 = 'AccentColor' })

		local Blocker = Library:Create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(0, 0, 0, 0);
			Visible = false;
			Parent = TabButton;
		})

		local TabFrame = Library:Create('Frame', {
			Name = 'TabFrame';
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 1, 0);
			Visible = false;
			ZIndex = 2;
			Parent = TabContainer;
		})

		local LeftSide = Library:Create('ScrollingFrame', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new(0, 4, 0, 4);
			Size = UDim2.new(0.5, -6, 1, -8);
			CanvasSize = UDim2.new(0, 0, 0, 0);
			BottomImage = '';
			TopImage = '';
			ScrollBarThickness = 0;
			ZIndex = 2;
			Parent = TabFrame;
		})

		local RightSide = Library:Create('ScrollingFrame', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new(0.5, 2, 0, 4);
			Size = UDim2.new(0.5, -6, 1, -8);
			CanvasSize = UDim2.new(0, 0, 0, 0);
			BottomImage = '';
			TopImage = '';
			ScrollBarThickness = 0;
			ZIndex = 2;
			Parent = TabFrame;
		})

		Library:Create('UIListLayout', {
			Padding = UDim.new(0, 8);
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			HorizontalAlignment = Enum.HorizontalAlignment.Center;
			Parent = LeftSide;
		})
		Library:Create('UIListLayout', {
			Padding = UDim.new(0, 8);
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			HorizontalAlignment = Enum.HorizontalAlignment.Center;
			Parent = RightSide;
		})

		for _, Side in next, { LeftSide, RightSide } do
			Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y)
			end)
		end

		function Tab:ShowTab()
			for _, Tab in next, Window.Tabs do
				Tab:HideTab()
			end
			Blocker.BackgroundTransparency = 0
			TweenService:Create(TabButton, TweenInfo_Med, { BackgroundColor3 = Library.SurfaceColor }):Play()
			TabButton.BackgroundColor3 = Library.SurfaceColor
			Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'SurfaceColor'
			TabFrame.Visible = true
			TabIndicator.Visible = true
		end

		function Tab:HideTab()
			Blocker.BackgroundTransparency = 1
			TweenService:Create(TabButton, TweenInfo_Med, { BackgroundColor3 = Library.BackgroundColor }):Play()
			TabButton.BackgroundColor3 = Library.BackgroundColor
			Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor'
			TabFrame.Visible = false
			TabIndicator.Visible = false
		end

		function Tab:SetLayoutOrder(Position)
			TabButton.LayoutOrder = Position
			TabListLayout:ApplyLayout()
		end
		function Tab:AddGroupbox(Info)
			local Groupbox = {}

			local BoxOuter = Library:Create('Frame', {
				BackgroundColor3 = Library.BackgroundColor;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 0, 507 + 6);
				ZIndex = 2;
				Parent = Info.Side == 1 and LeftSide or RightSide;
			})
			Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = BoxOuter; })
			Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor' })

			local BoxInner = Library:Create('Frame', {
				BackgroundColor3 = Library.BackgroundColor;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 1, 0);
				Position = UDim2.new(0, 0, 0, 0);
				ZIndex = 4;
				Parent = BoxOuter;
			})

			local Highlight = Library:Create('Frame', {
				BackgroundColor3 = Library.AccentColor;
				BorderSizePixel = 0;
				Position = UDim2.new(0, 0, 0, 0);
				Size = UDim2.new(1, 0, 0, 2);
				ZIndex = 5;
				Parent = BoxInner;
			})
			Library:Create('UICorner', { CornerRadius = UDim.new(0, 1); Parent = Highlight; })
			Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor' })

			local GroupboxLabel = Library:CreateLabel({
				Size = UDim2.new(1, -8, 0, 20);
				Position = UDim2.new(0, 8, 0, 6);
				TextSize = Library.FontSize + 1;
				Text = Info.Name;
				TextXAlignment = Enum.TextXAlignment.Left;
				ZIndex = 5;
				Parent = BoxInner;
			})

			local Container = Library:Create('Frame', {
				BackgroundTransparency = 1;
				Position = UDim2.new(0, 8, 0, 28);
				Size = UDim2.new(1, -16, 1, -32);
				ZIndex = 1;
				Parent = BoxInner;
			})

			Library:Create('UIListLayout', {
				FillDirection = Enum.FillDirection.Vertical;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = Container;
			})

			function Groupbox:Resize()
				local Size = 0
				for _, Element in next, Groupbox.Container:GetChildren() do
					if (not Element:IsA('UIListLayout')) and Element.Visible then
						Size = Size + Element.Size.Y.Offset
					end
				end
				BoxOuter.Size = UDim2.new(1, 0, 0, 32 + Size + 4)
			end

			Groupbox.Container = Container
			setmetatable(Groupbox, BaseGroupbox)
			Groupbox:AddBlank(4)
			Groupbox:Resize()

			Tab.Groupboxes[Info.Name] = Groupbox
			return Groupbox
		end

		function Tab:AddLeftGroupbox(Name)
			return Tab:AddGroupbox({ Side = 1; Name = Name })
		end

		function Tab:AddRightGroupbox(Name)
			return Tab:AddGroupbox({ Side = 2; Name = Name })
		end

		function Tab:AddTabbox(Info)
			local Tabbox = { Tabs = {} }

			local BoxOuter = Library:Create('Frame', {
				BackgroundColor3 = Library.BackgroundColor;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 0, 0);
				ZIndex = 2;
				Parent = Info.Side == 1 and LeftSide or RightSide;
			})
			Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = BoxOuter; })
			Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor' })

			local BoxInner = Library:Create('Frame', {
				BackgroundColor3 = Library.BackgroundColor;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 1, 0);
				Position = UDim2.new(0, 0, 0, 0);
				ZIndex = 4;
				Parent = BoxOuter;
			})

			local TabboxButtons = Library:Create('Frame', {
				BackgroundTransparency = 1;
				Position = UDim2.new(0, 8, 0, 6);
				Size = UDim2.new(1, -16, 0, 22);
				ZIndex = 5;
				Parent = BoxInner;
			})
			Library:Create('UIListLayout', {
				FillDirection = Enum.FillDirection.Horizontal;
				HorizontalAlignment = Enum.HorizontalAlignment.Left;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Padding = UDim.new(0, 4);
				Parent = TabboxButtons;
			})

			function Tabbox:AddTab(Name)
				local Tab = {}

				local Button = Library:Create('Frame', {
					BackgroundColor3 = Library.SurfaceColor;
					BorderSizePixel = 0;
					Size = UDim2.new(0.5, 0, 1, 0);
					ZIndex = 6;
					Parent = TabboxButtons;
				})
				Library:Create('UICorner', { CornerRadius = UDim.new(0, 3); Parent = Button; })
				Library:AddToRegistry(Button, { BackgroundColor3 = 'SurfaceColor' })

				local TabHighlight = Library:Create('Frame', {
					BackgroundColor3 = Library.AccentColor;
					BorderSizePixel = 0;
					Position = UDim2.new(0, 0, 1, -2);
					Size = UDim2.new(1, 0, 0, 2);
					Visible = false;
					ZIndex = 10;
					Parent = Button;
				})
				Library:Create('UICorner', { CornerRadius = UDim.new(0, 1); Parent = TabHighlight; })
				Library:AddToRegistry(TabHighlight, { BackgroundColor3 = 'AccentColor' })

				local ButtonLabel = Library:CreateLabel({
					Size = UDim2.new(1, 0, 1, 0);
					TextSize = Library.FontSize;
					Text = Name;
					TextXAlignment = Enum.TextXAlignment.Center;
					ZIndex = 7;
					Parent = Button;
				})

				local Block = Library:Create('Frame', {
					BackgroundColor3 = Library.BackgroundColor;
					BorderSizePixel = 0;
					Position = UDim2.new(0, 0, 1, 0);
					Size = UDim2.new(1, 0, 0, 2);
					Visible = false;
					ZIndex = 9;
					Parent = Button;
				})
				Library:AddToRegistry(Block, { BackgroundColor3 = 'BackgroundColor' })

				local Container = Library:Create('Frame', {
					BackgroundTransparency = 1;
					Position = UDim2.new(0, 8, 0, 36);
					Size = UDim2.new(1, -16, 1, -40);
					Visible = false;
					ZIndex = 1;
					Parent = BoxInner;
				})

				Library:Create('UIListLayout', {
					FillDirection = Enum.FillDirection.Vertical;
					SortOrder = Enum.SortOrder.LayoutOrder;
					Parent = Container;
				})

				function Tab:Show()
					for _, T in next, Tabbox.Tabs do
						T:Hide()
					end
					Container.Visible = true
					Block.Visible = true
					TabHighlight.Visible = true
					TweenService:Create(Button, TweenInfo_Short, { BackgroundColor3 = Library.BackgroundColor }):Play()
					Button.BackgroundColor3 = Library.BackgroundColor
					Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor'
					Tab:Resize()
				end

				function Tab:Hide()
					Container.Visible = false
					Block.Visible = false
					TabHighlight.Visible = false
					TweenService:Create(Button, TweenInfo_Short, { BackgroundColor3 = Library.SurfaceColor }):Play()
					Button.BackgroundColor3 = Library.SurfaceColor
					Library.RegistryMap[Button].Properties.BackgroundColor3 = 'SurfaceColor'
				end

				function Tab:Resize()
					local TabCount = 0
					for _, T in next, Tabbox.Tabs do
						TabCount = TabCount + 1
					end
					for _, Btn in next, TabboxButtons:GetChildren() do
						if not Btn:IsA('UIListLayout') then
							Btn.Size = UDim2.new(1 / TabCount, 0, 1, 0)
						end
					end
					if (not Container.Visible) then return end
					local Size = 0
					for _, Element in next, Tab.Container:GetChildren() do
						if (not Element:IsA('UIListLayout')) and Element.Visible then
							Size = Size + Element.Size.Y.Offset
						end
					end
					BoxOuter.Size = UDim2.new(1, 0, 0, 40 + Size + 4)
				end

				Button.InputBegan:Connect(function(Input)
					if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
						Tab:Show()
						Tab:Resize()
					end
				end)

				Tab.Container = Container
				Tabbox.Tabs[Name] = Tab
				setmetatable(Tab, BaseGroupbox)
				Tab:AddBlank(3)
				Tab:Resize()

				if #TabboxButtons:GetChildren() == 1 then
					Tab:Show()
				end

				return Tab
			end

			Tab.Tabboxes[Info.Name or ''] = Tabbox
			return Tabbox
		end
		function Tab:AddLeftTabbox(Name)
			return Tab:AddTabbox({ Name = Name, Side = 1 })
		end

		function Tab:AddRightTabbox(Name)
			return Tab:AddTabbox({ Name = Name, Side = 2 })
		end

		TabButton.InputBegan:Connect(function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
				Tab:ShowTab()
			end
		end)

		if #TabContainer:GetChildren() == 1 then
			Tab:ShowTab()
		end

		Window.Tabs[Name] = Tab
		return Tab
	end

	local ModalElement = Library:Create('TextButton', {
		BackgroundTransparency = 1;
		Size = UDim2.new(0, 0, 0, 0);
		Visible = true;
		Text = '';
		Modal = false;
		Parent = ScreenGui;
	})

	function Library:Toggle()
		Library.Toggled = not Library.Toggled
		ModalElement.Modal = Library.Toggled
		Outer.Visible = Library.Toggled

		if Library.Toggled then
			Outer.Visible = true
			Outer.BackgroundTransparency = 1
			TweenService:Create(Outer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0
			}):Play()
		end

		Outer.Visible = Library.Toggled

		if Library.Toggled then
			task.spawn(function()
				local State = InputService.MouseIconEnabled

				local Cursor = Drawing.new('Triangle')
				Cursor.Thickness = 1
				Cursor.Filled = true
				Cursor.Visible = true

				local CursorOutline = Drawing.new('Triangle')
				CursorOutline.Thickness = 1
				CursorOutline.Filled = false
				CursorOutline.Color = Color3.new(0, 0, 0)
				CursorOutline.Visible = true

				while Library.Toggled and ScreenGui.Parent do
					InputService.MouseIconEnabled = false

					local mPos = InputService:GetMouseLocation()

					Cursor.Color = Library.AccentColor

					Cursor.PointA = Vector2.new(mPos.X, mPos.Y)
					Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6)
					Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16)
					CursorOutline.PointA = Cursor.PointA
					CursorOutline.PointB = Cursor.PointB
					CursorOutline.PointC = Cursor.PointC

					RenderStepped:Wait()
				end

				InputService.MouseIconEnabled = State
				Cursor:Remove()
				CursorOutline:Remove()
			end)
		end

		if Library.UseBlur then
			Library:UpdateBlur()
		else
			Library.BlurEffect.Size = 0
			Library.BlurEffect.Enabled = false
		end
	end

	Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
		if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
			if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
				task.spawn(Library.Toggle)
			end
		elseif type(Library.ToggleKeybind) == 'string' then
			if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind then
				task.spawn(Library.Toggle)
			end
		elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
			task.spawn(Library.Toggle)
		end
	end))

	if Config.AutoShow then
		task.spawn(Library.Toggle)
	end

	Window.Holder = Outer
	return Window
end
local function OnPlayerChange()
	local PlayerList = GetPlayersString()
	for _, Value in next, Options do
		if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
			Value:SetValues(PlayerList)
		end
	end
end

Players.PlayerAdded:Connect(OnPlayerChange)
Players.PlayerRemoving:Connect(OnPlayerChange)

if InputService.TouchEnabled then
	local MobileGui = Instance.new("ScreenGui")
	MobileGui.Name = "LinoriaMobileUI"
	MobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	ProtectGui(MobileGui)
	MobileGui.Parent = CoreGui

	local BTN_W, BTN_H = 88, 30
	local BTN_GAP = 40

	local function CreateMobileButton(name, text, startPos)
		local Outer = Library:Create('Frame', {
			Name = name .. "Outer";
			BackgroundColor3 = Library.SurfaceColor;
			BorderSizePixel = 0;
			Position = startPos;
			Size = UDim2.new(0, BTN_W, 0, BTN_H);
			ZIndex = 300;
			Parent = MobileGui;
			Active = true;
		})
		Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = Outer; })
		Library:AddToRegistry(Outer, { BackgroundColor3 = 'SurfaceColor' })

		local Btn = Library:Create('TextButton', {
			Name = name .. "Btn";
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			Font = Enum.Font.Code;
			Text = text;
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextSize = Library.FontSize - 1;
			ZIndex = 304;
			Parent = Outer;
			Active = true;
		})

		return Outer, Btn
	end

	local ToggleOuter, ToggleBtn = CreateMobileButton("Toggle", "Toggle UI", UDim2.new(0, 10, 0, 10))
	local LockOuter, LockBtn = CreateMobileButton("Lock", "Unlock UI", UDim2.new(0, 10, 0, 10 + BTN_H + (BTN_GAP - BTN_H)))

	local IsUnlocked = false

	local function BindMobileButtonAction(Btn, Outer, ClickAction)
		local dragging = false
		local dragInput = nil
		local dragStart = nil
		local startPos = nil
		local hasMoved = false

		Btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				hasMoved = false
				dragStart = input.Position
				startPos = Outer.Position
				dragInput = input

				local connection
				connection = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						connection:Disconnect()
						if not hasMoved then
							ClickAction()
						end
					end
				end)
			end
		end)

		InputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				local delta = input.Position - dragStart
				if delta.Magnitude > 3 then
					hasMoved = true
				end
				if IsUnlocked and hasMoved then
					Outer.Position = UDim2.new(
						startPos.X.Scale, startPos.X.Offset + delta.X,
						startPos.Y.Scale, startPos.Y.Offset + delta.Y
					)
				end
			end
		end)
	end

	BindMobileButtonAction(ToggleBtn, ToggleOuter, function()
		Library:Toggle()
	end)

	BindMobileButtonAction(LockBtn, LockOuter, function()
		IsUnlocked = not IsUnlocked
		LockBtn.Text = IsUnlocked and "Lock UI" or "Unlock UI"
		LockBtn.TextColor3 = IsUnlocked
			and Library.AccentColor
			or Color3.fromRGB(255, 255, 255)
	end)

	local _origUpdate = Library.UpdateColorsUsingRegistry
	Library.UpdateColorsUsingRegistry = function(self)
		_origUpdate(self)
	end
end

getgenv().Library = Library
return Library
