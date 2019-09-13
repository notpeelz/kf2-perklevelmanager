class PerkLevelManagerConfig extends Object
    config(PerkLevelManager);

struct LevelOverride
{
    var int Value;
    var int Min;
    var int Max;
};

var config int INIVersion;
var config LevelOverride PerkLevel;
var config LevelOverride PrestigeLevel;

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

function int GetPerkLevel(int CurrentValue)
{
    local int Value;

    if (PerkLevel.Value < 0)
    {
        Value = CurrentValue;

        if (PerkLevel.Min >= 0)
        {
            Value = Max(Value, PerkLevel.Min);
        }

        if (PerkLevel.Max >= 0)
        {
            Value = Min(Value, PerkLevel.Max);
        }

        return Value;
    }

    return PerkLevel.Value;
}

function int GetPrestigeLevel(int CurrentValue)
{
    local int Value;

    if (PrestigeLevel.Value < 0)
    {
        Value = CurrentValue;

        if (PrestigeLevel.Min >= 0)
        {
            Value = Max(Value, PrestigeLevel.Min);
        }

        if (PrestigeLevel.Max >= 0)
        {
            Value = Min(Value, PrestigeLevel.Max);
        }

        return Value;
    }

    return PrestigeLevel.Value;
}