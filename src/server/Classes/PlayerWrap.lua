local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local Classes = script.Parent
local Libraries = Classes.Parent.Libraries

local Calculations = require(Classes.Calculations)
local PurchaseHandler = require(Classes.PurchaseHandler)
local ReplicaService = require(Libraries.ReplicaService)

local PlayerProfileClassToken = ReplicaService.NewClassToken("PlayerProfile")

local PlayerWrap = {}
PlayerWrap.__index = PlayerWrap

local InstanceToWrap = {}

function GetAnimationInstanceByName(AnimationName)
    local AnimationInstance = Assets.Animations:FindFirstChild(AnimationName)

    if not AnimationInstance then
        return
    end

    return AnimationInstance
end

function PlayerWrap.new(Instance, ...)
    local self = setmetatable({}, PlayerWrap)
    InstanceToWrap[Instance] = self
    
    return self:Constructor(Instance, ...) or self
end

function PlayerWrap.get(Instance)
    return InstanceToWrap[Instance]
end

function PlayerWrap:PlayAnimation(AnimationName)
    local Character = self.Instance.Character

    if not Character then
        return
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local Animator = Humanoid:WaitForChild("Animator")

    local HitAnimation = GetAnimationInstanceByName(AnimationName)

    if not HitAnimation then
        return
    end

    local AnimationTrack = Animator:LoadAnimation(HitAnimation)

    AnimationTrack:Play()
end

function PlayerWrap:Constructor(Instance, Profile)
    self.Instance = Instance
    self.Profile = Profile

    self.Replica = ReplicaService.NewReplica({
        ClassToken = PlayerProfileClassToken,
        Replication = Instance,
        Data = Profile.Data
    })

    local function ConvertToClass(FieldName, ClassName)
        self[FieldName] = {}

        local ClassModule = Classes:FindFirstChild(ClassName, true)
        local Class = require(ClassModule)

        for i,v in pairs(Profile.Data[FieldName]) do
            local NewTool = Class.new(self, v)
            table.insert(self[FieldName], NewTool)
        end
    end

    ConvertToClass("Backpacks", "BaseBackpack")
    ConvertToClass("Tools", "BaseTool")

    self.Calculations = Calculations.new(self)
    self.PurchaseHandler = PurchaseHandler.new(self)
end

function PlayerWrap:GetEquippedBackpack()
    return self.Backpacks[self.Profile.Data.EquippedBackpack]
end

function PlayerWrap:GetEquippedTool()
    return self.Tools[self.Profile.Data.EquippedTool]
end

function PlayerWrap:Initialize()
    local Profile = self.Profile

    local function InitializeEquipped(Field, ListName)
        local Index = Profile.Data[Field]
        local IsIndexValid = #self[ListName] <= Index

        if not Index or not IsIndexValid then
            return 1
        end

        self[ListName][Index]:Initialize()
    end

    local WasEquipped = false

    local function Equip()
        WasEquipped = true

        InitializeEquipped("EquippedTool", "Tools")
        InitializeEquipped("EquippedBackpack", "Backpacks")
    end

    self.Instance.CharacterAdded:Connect(Equip)
    task.delay(3,function()
        if not WasEquipped then
            Equip()
        end
    end)
end

function PlayerWrap:SyncWithProfile()
    local ProfileData = self.Profile.Data

    local function ConvertFromClass(FieldName)
        local Table = {}
        for i,v in pairs(self[FieldName]) do
            table.insert(Table, v:GetInfo())
        end
    end

    ProfileData.Tools = ConvertFromClass("Tools")
    ProfileData.Backpacks = ConvertFromClass("Backpacks")
end

function PlayerWrap:AutoDataPushAsync(Delay)
    self.StopPushing = false

    local Coroutine = coroutine.wrap(function()
        while not self.StopPushing do
            task.wait(Delay)
            self:SyncWithProfile()
        end
    end)

    Coroutine()
end

function PlayerWrap:StopPushing()
    self.StopPushing = true
end

return PlayerWrap