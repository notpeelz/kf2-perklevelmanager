class PerkLevelManagerConfig extends Object
    config(PerkLevelManager);

struct LevelOverride
{
    var int Value;
    var int Min;
    var int Max;
};

struct PerkOverride
{
    var class<KFPerk> PerkClass;
    var LevelOverride Override;
};

var config int INIVersion;
var config LevelOverride PerkLevel;
var config LevelOverride PrestigeLevel;
var config array<PerkOverride> PerkLevelOverrides;
var config array<PerkOverride> PrestigeLevelOverrides;

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