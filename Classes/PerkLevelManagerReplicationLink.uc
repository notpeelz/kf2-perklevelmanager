class PerkLevelManagerReplicationLink extends ReplicationInfo
    dependson(PerkLevelManagerConfig,PerkLevelManagerClientConfig);

struct PerkListCacheEntry
{
    var byte PerkLevel;
    var byte PrestigeLevel;
};

var PerkLevelManagerMutator PLMMutator;
var KFPlayerController KFPC;

var KFPlayerReplicationInfo KFPRI;
var KFPlayerReplicationInfoProxy KFPRIProxy;

var bool ShouldUpdate;
var bool ShouldUpdateSkills;
var byte PerkLevel;
var byte PrestigeLevel;
var KFPerkProxy PreviousPerkProxy;
var class<KFPerk> PreviousPerkClass;

var array<PerkLevelManagerConfig.PerkOverride> TempPerkLevelOverrides;
var array<PerkLevelManagerConfig.PerkOverride> TempPrestigeLevelOverrides;
var array<PerkListCacheEntry> PerkListCache;

replication
{
    if (bNetDirty)
        PLMMutator, KFPC;
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

    foreach PLMMutator.ClientConfig.PerkLevelOverrides(CurrentPerkOverride)
    {
        AddLevelPerkOverride(CurrentPerkOverride);
    }

    foreach PLMMutator.ClientConfig.PrestigeLevelOverrides(CurrentPerkOverride)
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
    if (PLMMutator == None || PLMMutator.ClientConfig == None)
    {
        TempPerkLevelOverrides.AddItem(Override);
        UpdateConfig();
    }
    else
    {
        PLMMutator.ClientConfig.PerkLevelOverrides.AddItem(Override);
    }
}

reliable client function AddPrestigePerkOverride(PerkLevelManagerConfig.PerkOverride Override)
{
    if (PLMMutator == None || PLMMutator.ClientConfig == None)
    {
        TempPrestigeLevelOverrides.AddItem(Override);
        UpdateConfig();
    }
    else
    {
        PLMMutator.ClientConfig.PrestigeLevelOverrides.AddItem(Override);
    }
}

simulated function UpdateConfig()
{
    local PerkLevelManagerConfig.PerkOverride CurrentPerkOverride;

    if (PLMMutator == None || PLMMutator.ClientConfig == None)
    {
        ClearTimer(nameof(UpdateConfig));
        SetTimer(0.01f, false, nameof(UpdateConfig));
        return;
    }

    foreach TempPerkLevelOverrides(CurrentPerkOverride)
    {
        PLMMutator.ClientConfig.PerkLevelOverrides.AddItem(CurrentPerkOverride);
    }

    foreach TempPrestigeLevelOverrides(CurrentPerkOverride)
    {
        PLMMutator.ClientConfig.PrestigeLevelOverrides.AddItem(CurrentPerkOverride);
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
        KFPC.PerkList[PerkIndex].PerkLevel = PLMMutator.ClientConfig.GetPerkLevel(PerkListCache[PerkIndex].PerkLevel, KFPC.PerkList[PerkIndex].PerkClass);
        KFPC.PerkList[PerkIndex].PrestigeLevel = PLMMutator.ClientConfig.GetPrestigeLevel(PerkListCache[PerkIndex].PrestigeLevel, KFPC.PerkList[PerkIndex].PerkClass);
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
    local KFPerkProxy KFPerkProxy;
    local byte SavedSkills[`MAX_PERK_SKILLS];
    local int I;

    if (KFPC.CurrentPerk == None) return;

    UnlockedTier = KFPRIProxy.ActivePerkLevel / `MAX_PERK_SKILLS;

    KFPerkProxy = CastPerkProxy(KFPC.CurrentPerk);
    if (KFPerkProxy == None) return;

    SavePreviousPerkSkills();
    PreviousPerkProxy = KFPerkProxy;
    PreviousPerkClass = KFPC.CurrentPerk.Class;

    GetSavedSkills(KFPC.CurrentPerk.Class, SavedSkills);

    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        if (I >= UnlockedTier)
        {
            if (KFPerkProxy.SelectedSkills[I] != 0) ShouldUpdateSkills = true;
            KFPerkProxy.SelectedSkills[I] = 0;
        }
        else
        {
            KFPerkProxy.SelectedSkills[I] = SavedSkills[I];
        }
    }

    ServerUpdateSkills(KFPC.CurrentPerk.Class, SavedSkills);

    if (ShouldUpdateSkills && PLMMutator.CanUpdateSkills())
    {
        `Log("[PerkLevelManager] Illegal skills detected; updating.");
        KFPC.CurrentPerk.UpdateSkills();
        ShouldUpdateSkills = false;
    }
}

simulated function GetSavedSkills(class<KFPerk> PerkClass, out byte SavedSkills[`MAX_PERK_SKILLS])
{
    local int Index, I;

    Index = PLMMutator.ClientConfig.PerkSkills.Find('PerkClass', PerkClass);
    if (Index != INDEX_NONE)
    {
        for (I = 0; I < `MAX_PERK_SKILLS; I++)
        {
            SavedSkills[I] = PLMMutator.ClientConfig.PerkSkills[Index].Skills[I];
        }
    }
}

simulated function SavePreviousPerkSkills()
{
    local int Index;
    local PerkLevelManagerClientConfig.PerkSkillSelection SkillSelection;
    local int I;

    if (PreviousPerkProxy == None) return;

    `Log("[PerkLevelManager] Saving skill selection for" @ PreviousPerkClass);

    SkillSelection.PerkClass = PreviousPerkClass;

    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        SkillSelection.Skills[I] = PreviousPerkProxy.SelectedSkills[I];
    }

    Index = PLMMutator.ClientConfig.PerkSkills.Find('PerkClass', PreviousPerkClass);
    if (Index != INDEX_NONE)
    {
        PLMMutator.ClientConfig.PerkSkills[Index] = SkillSelection;
    }
    else
    {
        PLMMutator.ClientConfig.PerkSkills.AddItem(SkillSelection);
    }

    PLMMutator.ClientConfig.SaveConfig();
}

reliable server function ServerUpdateSkills(class<KFPerk> PerkClass, byte Skills[`MAX_PERK_SKILLS])
{
    PLMMutator.UpdateClientSkills(KFPC, PerkClass, Skills);
}

simulated event Destroyed()
{
    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        SavePreviousPerkSkills();
    }

    super.Destroyed();
}

simulated function bool CacheVariables()
{
    if (PLMMutator != None && KFPC != None && KFPRI != None && KFPRIProxy != None) return true;

    if (PLMMutator == None) return false;
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
    // This is needed, otherwise the client-to-server RPC fails
    bSkipActorPropertyReplication = false;
}