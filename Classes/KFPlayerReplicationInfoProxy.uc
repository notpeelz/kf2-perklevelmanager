class KFPlayerReplicationInfoProxy extends PlayerReplicationInfo;

var float LastQuitTime;
var byte NumTimesReconnected;
var bool bHasSpawnedIn;
var string LastCrateGiftTimestamp;
var int SecondsOfGameplay;
var bool bAllowDoshEarning;

var const array<KFCharacterInfo_Human> CharacterArchetypes;
var const repnotify KFPlayerReplicationInfo.CustomizationInfo RepCustomizationInfo;
var texture CharPortrait;
var repnotify byte VOIPStatus;
var repnotify bool bVOIPRegisteredWithOSS;
var int DamageDealtOnTeam;
var byte NetPerkIndex;
var class<KFPerk> CurrentPerkClass;
var /*private*/ byte ActivePerkLevel;
var /*private*/ byte ActivePerkPrestigeLevel;
var int Assists;
var byte PlayerHealth;
var byte PlayerHealthPercent;
var bool bExtraFireRange;
var bool bSplashActive;
var bool bNukeActive;
var bool bConcussiveActive;
var byte PerkSupplyLevel;

var bool bPerkPrimarySupplyUsed;
var bool bPerkSecondarySupplyUsed;
var bool bVotedToSkipTraderTime;

var EVoiceCommsType CurrentVoiceCommsRequest;
var float VoiceCommsStatusDisplayInterval;
var int VoiceCommsStatusDisplayIntervalCount;
var int VoiceCommsStatusDisplayIntervalMax;

var byte SharedUnlocks;

var repnotify private int CurrentHeadShotEffectID;
var bool bObjectivePlayer;

var private Vector PawnLocationCompressed;
var private Vector LastReplicatedSmoothedLocation;
var bool bShowNonRelevantPlayers;

var KFPlayerController KFPlayerOwner;

var transient bool bWaitingForInventory;
var transient int WaitingForInventoryCharacterIndex;

var bool bCarryingCollectible;