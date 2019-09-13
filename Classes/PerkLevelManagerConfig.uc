class PerkLevelManagerConfig extends Actor
    config(PerkLevelManager);

struct LevelOverride
{
    var int Value;
    var int Min;
    var int Max;
};

struct PerkOverride
{
    var Class<KFPerk> PerkClass;
    var LevelOverride Override;
};

var config int INIVersion;
var config LevelOverride PerkLevel;
var config LevelOverride PrestigeLevel;
var config array<PerkOverride> PerkLevelOverrides;
var config array<PerkOverride> PrestigeLevelOverrides;

replication
{
    if (bNetDirty)
        PerkLevel, PrestigeLevel;
}

function Initialize()
{
    if (INIVersion == 0)
    {
        INIVersion = 1;
        
        PerkLevel.Value = 25;
        PerkLevel.Min = -1;
        PerkLevel.Max = -1;

        PrestigeLevel.Value = -1;
        PrestigeLevel.Min = -1;
        PrestigeLevel.Max = -1;

        SaveConfig();
    }
}

simulated function int GetPerkLevel(int CurrentValue, Class<KFPerk> PerkClass)
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