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

var bool SkillUpdateQueued;
var KFPerk CachedPerk;
var byte CachedSkills[`MAX_PERK_SKILLS];
var const byte UnsetSkills[`MAX_PERK_SKILLS];

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

simulated function PostBeginPlay()
{
    super.PostBeginPlay();

    if (bDeleteMe) return;

    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        SetTimer(1.f, true, nameof(MonitorPerks));
    }
}

simulated event Tick(float DeltaTime)
{
    local int I;
    local bool HasModifiedSkills;

    // TODO: cache PerksMenu
    if (PerksMenu == None) return;

    if (CachedPerk == None)
    {
        CachedPerk = KFPC.CurrentPerk;
        CachedSkills = UnsetSkills;
    }

    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        if (CachedSkills[I] != PerksMenu.SelectedSkillsHolder[I])
        {
            CachedSkills[I] = PerksMenu.SelectedSkillsHolder[I];
            HasModifiedSkills = true;
        }
    }

    if (HasModifiedSkills)
    {
        SaveSkills(CastPerkProxy(KFPC.CurrentPerk));
    }
}

simulated function MonitorPerks()
{
    local KFPlayerController.PerkInfo CurrentPerkInfo;
    local PerkListCacheEntry CacheEntry;
    local int ExpectedPerkLevel, ExpectedPrestigeLevel;
    local int CurrentPerkLevel, CurrentPrestigeLevel;
    local int PerkIndex;
    local bool ShouldUpdateLevels;
    local int I;

    if (!CacheVariables()) return;
    if (KFPC.CurrentPerk == None) return;

    // Cache the original levels
    if (PerkListCache.Length == 0)
    {
        foreach KFPC.PerkList(CurrentPerkInfo)
        {
            CacheEntry.PerkLevel = CurrentPerkInfo.PerkLevel;
            CacheEntry.PrestigeLevel = CurrentPerkInfo.PrestigeLevel;
            PerkListCache.AddItem(CacheEntry);
        }
    }

    // Update all perk levels
    for (I = 0; I < KFPC.PerkList.Length; I++)
    {
        PerkIndex = KFPC.GetPerkIndexFromClass(KFPC.PerkList[I].PerkClass);

        ExpectedPerkLevel = PLMMutator.ClientConfig.GetPerkLevel(PerkListCache[PerkIndex].PerkLevel, KFPC.PerkList[PerkIndex].PerkClass);
        ExpectedPrestigeLevel = PLMMutator.ClientConfig.GetPrestigeLevel(PerkListCache[PerkIndex].PrestigeLevel, KFPC.PerkList[PerkIndex].PerkClass);

        if (KFPC.PerkList[I].PerkClass == KFPC.CurrentPerk.Class)
        {
            CurrentPerkLevel = ExpectedPerkLevel;
            CurrentPrestigeLevel = ExpectedPrestigeLevel;
        }

        if (ExpectedPerkLevel != KFPC.PerkList[PerkIndex].PerkLevel || ExpectedPrestigeLevel != KFPC.PerkList[PerkIndex].PrestigeLevel)
        {
            ShouldUpdateLevels = true;
        }

        KFPC.PerkList[PerkIndex].PerkLevel = ExpectedPerkLevel;
        KFPC.PerkList[PerkIndex].PrestigeLevel = ExpectedPrestigeLevel;
    }

    if (ShouldUpdateLevels) UpdateLevelInfo(CurrentPerkLevel, CurrentPrestigeLevel);
    UpdateSkills(CurrentPerkLevel);
}

simulated function UpdateLevelInfo(int PerkLevel, int PrestigeLevel)
{
    local KFGFxMenu_Perks PerkMenu;

    KFPRIProxy.ActivePerkLevel = PerkLevel;
    KFPRIProxy.ActivePerkPrestigeLevel = PrestigeLevel;

    KFPC.CurrentPerk.SetLevel(PerkLevel);
    KFPC.CurrentPerk.SetPrestigeLevel(PrestigeLevel);

    KFPC.PostTierUnlock(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass);

    PerkMenu = KFGFxMenu_Perks(KFPC.MyGFxManager.CurrentMenu);
    if (PerkMenu != None)
    {
        PerkMenu.UpdateContainers(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass, false);
        PerkMenu.UpdateSkillsHolder(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass);
    }
}

simulated function UpdateSkills(int PerkLevel)
{
    local KFGFxMenu_Perks PerkMenu;
    local KFPerkProxy KFPerkProxy;
    local byte SavedSkills[`MAX_PERK_SKILLS];
    local bool ShouldUpdateSkills;
    local int UnlockedTier;
    local int I;

    if (KFPC.CurrentPerk == None) return;

    KFPerkProxy = CastPerkProxy(KFPC.CurrentPerk);
    if (KFPerkProxy == None) return;

    UnlockedTier = PerkLevel / `MAX_PERK_SKILLS;

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
            if (KFPerkProxy.SelectedSkills[I] != SavedSkills[I] && SavedSkills[I] != 0)
            {
                `Log("[PerkLevelManager] Forcefully setting skill" @ I @ "from config, from" @ KFPerkProxy.SelectedSkills[I] @ "to" @ SavedSkills[I]);
                KFPerkProxy.SelectedSkills[I] = SavedSkills[I];
                SkillUpdateQueued = true;
                ShouldUpdateSkills = true;
            }
        }
    }

    if (ShouldUpdateSkills)
    {
        ServerUpdateSkills(KFPC.CurrentPerk.Class, SavedSkills);

        PerkMenu = KFGFxMenu_Perks(KFPC.MyGFxManager.CurrentMenu);
        if (PerkMenu != None)
        {
            PerkMenu.UpdateSkillsHolder(KFPC.CurrentPerk.Class);
        }
    }

    if (SkillUpdateQueued && PLMMutator.CanUpdateSkills())
    {
        `Log("[PerkLevelManager] Updating skills");
        KFPC.CurrentPerk.UpdateSkills();
        SkillUpdateQueued = false;
    }
}

reliable server function ServerUpdateSkills(class<KFPerk> PerkClass, byte Skills[`MAX_PERK_SKILLS])
{
    PLMMutator.UpdateClientSkills(KFPC, PerkClass, Skills);
}

simulated function SaveSkills(KFPerkProxy KFPerkProxy)
{
    local PerkLevelManagerClientConfig.PerkSkillSelection SkillSelection;
    local int Index;
    local int I;

    `Log("[PerkLevelManager] Saving skill selection for" @ KFPC.CurrentPerk.Class);

    SkillSelection.PerkClass = KFPC.CurrentPerk.Class;
    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        SkillSelection.Skills[I] = KFPerkProxy.SelectedSkills[I];
    }

    Index = PLMMutator.ClientConfig.PerkSkills.Find('PerkClass', KFPC.CurrentPerk.Class);
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
    // This is needed, otherwise client-to-server RPC fails
    bSkipActorPropertyReplication = false;
}