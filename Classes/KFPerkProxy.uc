class KFPerkProxy extends ReplicationInfo;

var private const int ProgressStatID;
var private const int PerkBuildStatID;

const RANK_1_LEVEL = 5;
const RANK_2_LEVEL = 10;
const RANK_3_LEVEL = 15;
const RANK_4_LEVEL = 20;
const RANK_5_LEVEL = 25;
const UNLOCK_INTERVAL = 5;

var const int SecondaryXPModifier[4];
var localized string PerkName;

struct native PassivePerk
{
    var localized string Title;
    var localized string Description;
    var string IconPath;
};
var array<PassivePerk> Passives;

var localized string SkillCatagories[`MAX_PERK_SKILLS];
var localized string EXPAction1;
var localized string EXPAction2;
var localized string LevelString;

var Texture2D PerkIcon;
var array<string> ColumnOneIcons;
var array<string> ColumnTwoIcons;
var Texture2D InteractIcon;

var array<Texture2D> PrestigeIcons;

var localized string WeaponDroppedMessage;

struct native PerkSkill
{
    var() editconst string Name;
    var() const float Increment;
    var const byte Rank;
    var() const float StartingValue;
    var() const float MaxValue;
    var() const float ModifierValue;
    var() const string IconPath;
    var() bool bActive;
};

var private const float AssistDoshModifier;

var array<PerkSkill> PerkSkills;

var /*protected*/ byte SelectedSkills[`MAX_PERK_SKILLS];