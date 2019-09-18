class PerkLevelManagerClientConfig extends ReplicationInfo
    dependson(PerkLevelManagerConfig);

var PerkLevelManagerMutator PLMMutator;

var PerkLevelManagerConfig.LevelOverride PerkLevel;
var PerkLevelManagerConfig.LevelOverride PrestigeLevel;
var array<PerkLevelManagerConfig.PerkOverride> PerkLevelOverrides;
var array<PerkLevelManagerConfig.PerkOverride> PrestigeLevelOverrides;

replication
{
    if (bNetDirty)
        PerkLevel, PrestigeLevel;
}

function Initialize()
{
    PerkLevel = PLMMutator.ServerConfig.PerkLevel;
    PrestigeLevel = PLMMutator.ServerConfig.PrestigeLevel;
    PerkLevelOverrides = PLMMutator.ServerConfig.PerkLevelOverrides;
    PrestigeLevelOverrides = PLMMutator.ServerConfig.PrestigeLevelOverrides;
}

simulated function int GetPerkLevel(int CurrentValue, class<KFPerk> PerkClass)
{
    local int Value;
    local LevelOverride Override;
    local PerkOverride CurrentPerkOverride;

    Override = PerkLevel;
    foreach PerkLevelOverrides(CurrentPerkOverride)
    {
        if (PerkClass == CurrentPerkOverride.PerkClass)
        {
            Override = CurrentPerkOverride.Override;
        }
    }

    if (Override.Value < 0)
    {
        Value = CurrentValue;

        if (Override.Min >= 0)
        {
            Value = Max(Value, Override.Min);
        }

        if (Override.Max >= 0)
        {
            Value = Min(Value, Override.Max);
        }

        return Value;
    }

    return Override.Value;
}

simulated function int GetPrestigeLevel(int CurrentValue, Class<KFPerk> PerkClass)
{
    local int Value;
    local LevelOverride Override;
    local PerkOverride CurrentPerkOverride;

    Override = PrestigeLevel;
    foreach PrestigeLevelOverrides(CurrentPerkOverride)
    {
        if (PerkClass == CurrentPerkOverride.PerkClass)
        {
            Override = CurrentPerkOverride.Override;
        }
    }

    if (Override.Value < 0)
    {
        Value = CurrentValue;

        if (Override.Min >= 0)
        {
            Value = Max(Value, Override.Min);
        }

        if (Override.Max >= 0)
        {
            Value = Min(Value, Override.Max);
        }

        return Value;
    }

    return Override.Value;
}

defaultproperties
{
    Role = ROLE_Authority;
    RemoteRole = ROLE_SimulatedProxy;
    bAlwaysRelevant = true;
}