class PerkLevelManagerReplicationLink extends ReplicationInfo
    dependson(PerkLevelManagerConfig);

struct PerkListCacheEntry
{
    var byte PerkLevel;
    var byte PrestigeLevel;
};

var PerkLevelManagerMutator PLMMutator;

var KFPlayerController KFPC;
var KFPlayerReplicationInfo KFPRI;
var KFPlayerReplicationInfoProxy KFPRIProxy;

var KFPerkProxy KFPerkProxy;

var bool ShouldUpdate;
var bool ShouldUpdateSkills;
var byte PerkLevel;
var byte PrestigeLevel;

var array<PerkLevelManagerConfig.PerkOverride> TempPerkLevelOverrides;
var array<PerkLevelManagerConfig.PerkOverride> TempPrestigeLevelOverrides;
var array<PerkListCacheEntry> PerkListCache;

replication
{
    if (bNetDirty)
        PLMMutator;
}

simulated function PostBeginPlay()
{
    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        SetTimer(1.f, true, nameof(UpdateSkills));
    }
}

function Initialize()
{
    if (WorldInfo.NetMode == NM_DedicatedServer)
    {
        SyncConfig();
    }
}

function SyncConfig()
{
    local PerkLevelManagerConfig.PerkOverride CurrentPerkOverride;

    foreach PLMMutator.PLMConfig.PerkLevelOverrides(CurrentPerkOverride)
    {
        AddLevelPerkOverride(CurrentPerkOverride);
    }

    foreach PLMMutator.PLMConfig.PrestigeLevelOverrides(CurrentPerkOverride)
    {
        AddPrestigePerkOverride(CurrentPerkOverride);
    }
}

reliable client function NotifyChangeLevel(byte CurrentPerkLevel, byte CurrentPrestigeLevel, byte NewPerkLevel, byte NewPrestigeLevel)
{
    `Log("[PerkLevelManager] Updating level from (" $ CurrentPrestigeLevel $ "," @ CurrentPerkLevel $ ") to (" $ NewPrestigeLevel $ "," @ NewPerkLevel $ ")");

    PerkLevel = NewPerkLevel;
    PrestigeLevel = NewPrestigeLevel;

    QueueUpdate();
}

reliable client function AddLevelPerkOverride(PerkLevelManagerConfig.PerkOverride Override)
{
    if (PLMMutator == None)
    {
        TempPerkLevelOverrides.AddItem(Override);
        UpdateConfig();
    }
    else
    {
        PLMMutator.PLMConfig.PerkLevelOverrides.AddItem(Override);
    }
}

reliable client function AddPrestigePerkOverride(PerkLevelManagerConfig.PerkOverride Override)
{
    if (PLMMutator == None || PLMMutator.PLMConfig == None)
    {
        TempPrestigeLevelOverrides.AddItem(Override);
        UpdateConfig();
    }
    else
    {
        PLMMutator.PLMConfig.PrestigeLevelOverrides.AddItem(Override);
    }
}

simulated function UpdateConfig()
{
    local PerkLevelManagerConfig.PerkOverride CurrentPerkOverride;

    if (PLMMutator == None || PLMMutator.PLMConfig == None)
    {
        ClearTimer(nameof(UpdateConfig));
        SetTimer(0.01f, false, nameof(UpdateConfig));
        return;
    }

    foreach TempPerkLevelOverrides(CurrentPerkOverride)
    {
        PLMMutator.PLMConfig.PerkLevelOverrides.AddItem(CurrentPerkOverride);
    }

    foreach TempPrestigeLevelOverrides(CurrentPerkOverride)
    {
        PLMMutator.PLMConfig.PrestigeLevelOverrides.AddItem(CurrentPerkOverride);
    }

    TempPerkLevelOverrides.Length = 0;
    TempPrestigeLevelOverrides.Length = 0;
}

simulated function QueueUpdate()
{
    if (!CacheVariables())
    {
        ClearTimer(nameof(QueueUpdate));
        SetTimer(0.1f, false, nameof(QueueUpdate));
        return;
    }

    KFPRIProxy.ActivePerkLevel = PerkLevel;
    KFPRIProxy.ActivePerkPrestigeLevel = PrestigeLevel;
    ShouldUpdate = true;
}

simulated event Tick(float DeltaTime)
{
    if (WorldInfo.NetMode == NM_DedicatedServer) return;
    if (!CacheVariables()) return;
    if (KFPC.CurrentPerk == None) return;

    if (ShouldUpdate)
    {
        UpdateLevelInfo();
        ShouldUpdate = false;
    }
}

simulated function UpdateLevelInfo()
{
    local KFGFxMenu_Perks PerkMenu;
    local KFPlayerController.PerkInfo CurrentPerkInfo;
    local PerkListCacheEntry CacheEntry;
    local int PerkIndex;
    local int I;

    KFPC.CurrentPerk.SetLevel(PerkLevel);
    KFPC.CurrentPerk.SetPrestigeLevel(PrestigeLevel);

    if (PerkListCache.Length == 0)
    {
        foreach KFPC.PerkList(CurrentPerkInfo)
        {
            CacheEntry.PerkLevel = CurrentPerkInfo.PerkLevel;
            CacheEntry.PrestigeLevel = CurrentPerkInfo.PrestigeLevel;
            PerkListCache.AddItem(CacheEntry);
        }
    }

    for (I = 0; I < KFPC.PerkList.Length; I++)
    {
        PerkIndex = KFPC.GetPerkIndexFromClass(KFPC.PerkList[I].PerkClass);
        KFPC.PerkList[PerkIndex].PerkLevel = PLMMutator.PLMConfig.GetPerkLevel(PerkListCache[PerkIndex].PerkLevel, KFPC.PerkList[PerkIndex].PerkClass);
        KFPC.PerkList[PerkIndex].PrestigeLevel = PLMMutator.PLMConfig.GetPrestigeLevel(PerkListCache[PerkIndex].PrestigeLevel, KFPC.PerkList[PerkIndex].PerkClass);
    }

    KFPC.PostTierUnlock(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass);

    PerkMenu = KFGFxMenu_Perks(KFPC.MyGFxManager.CurrentMenu);
    if (PerkMenu != None)
    {
        PerkMenu.UpdateSkillsHolder(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass);
        PerkMenu.UpdateContainers(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass, false);
    }

    foreach KFPC.PerkList(CurrentPerkInfo)
    {
        CurrentPerkInfo.PerkLevel = PerkLevel;
        CurrentPerkInfo.PrestigeLevel = PrestigeLevel;
    }

    UpdateSkills();
}

simulated function UpdateSkills()
{
    local int UnlockedTier;
    local int I;

    if (KFPC.CurrentPerk == None) return;

    UnlockedTier = KFPRIProxy.ActivePerkLevel / `MAX_PERK_SKILLS;

    KFPerkProxy = CastPerkProxy(KFPC.CurrentPerk);
    if (KFPerkProxy == None) return;

    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        if (I >= UnlockedTier)
        {
            if (KFPerkProxy.SelectedSkills[I] != 0) ShouldUpdateSkills = true;
            KFPerkProxy.SelectedSkills[I] = 0;
        }
    }

    if (ShouldUpdateSkills && PLMMutator.CanUpdateSkills())
    {
        `Log("[PerkLevelManager] Illegal skills detected; updating.");
        KFPC.CurrentPerk.UpdateSkills();
        ShouldUpdateSkills = false;
    }
}

simulated function bool CacheVariables()
{
    local PlayerController PC;

    if (PLMMutator != None && KFPC != None && KFPRI != None && KFPRIProxy != None) return true;

    if (PLMMutator == None) return false;

    PC = GetALocalPlayerController();
    if (PC == None) return false;

    KFPC = KFPlayerController(PC);
    if (KFPC == None) return false;

    KFPRI = KFPlayerReplicationInfo(KFPC.PlayerReplicationInfo);
    if (KFPRI == None) return false;

    KFPRIProxy = CastPRIProxy(KFPRI);
    if (KFPRIProxy == None) return false;

    return true;
}

simulated `ForcedObjectTypecastFunction(KFPlayerReplicationInfoProxy, CastPRIProxy)
simulated `ForcedObjectTypecastFunction(KFPerkProxy, CastPerkProxy)

defaultproperties
{
    bAlwaysRelevant = false;
    bOnlyRelevantToOwner = true;
    Role = ROLE_Authority;
    RemoteRole = ROLE_SimulatedProxy;
}