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

var bool DelayedUpdateQueued;
var bool SkillUpdateQueued;
var KFGFxMenu_Perks CachedPerksMenu;
var KFPerk CachedPerk;
var KFPerkProxy CachedPerkProxy;
var byte CachedSkills[`MAX_PERK_SKILLS];

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

simulated function DelayedUpdate()
{
    if (KFPC.CurrentPerk != None)
    {
        RestoreSkillsFromConfig(KFPC.CurrentPerk.Class);
    }
    DelayedUpdateQueued = false;
}

simulated function DelayedSave()
{
    SaveSkills(CachedPerkProxy);
}

simulated event Tick(float DeltaTime)
{
    local int I;
    local bool HasModifiedSkills;

    if (WorldInfo.NetMode == NM_DedicatedServer) return;

    // Wait until the PerksMenu is initialized
    if (CachedPerksMenu == None)
    {
        CachedPerksMenu = KFPC.MyGFxManager.PerksMenu;
        if (CachedPerksMenu == None) return;
    }

    if (CachedPerk != KFPC.CurrentPerk)
    {
        CachedPerk = KFPC.CurrentPerk;
        CachedPerkProxy = KFPC.CurrentPerk != None ? CastPerkProxy(KFPC.CurrentPerk) : None;

        ClearTimer(nameof(DelayedSave));
        ClearTimer(nameof(DelayedUpdate));

        DelayedUpdateQueued = true;
        SetTimer(0.2f, false, nameof(DelayedUpdate));
    }

    if (DelayedUpdateQueued) return;

    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        if (CachedSkills[I] != CachedPerksMenu.SelectedSkillsHolder[I])
        {
            CachedSkills[I] = CachedPerksMenu.SelectedSkillsHolder[I];
            HasModifiedSkills = true;
        }
    }

    // Save skill selection if we detect a change, but only if the change wasn't initiated by
    // a perk change.
    if (HasModifiedSkills)
    {
        ClearTimer(nameof(DelayedSave));
        SetTimer(1.f, false, nameof(DelayedSave));
    }
}

simulated function RestoreSkillsFromConfig(class<KFPerk> PerkClass)
{
    local KFGFxMenu_Perks PerksMenu;
    local byte SavedSkills[`MAX_PERK_SKILLS];
    local int PerkIndex, PerkLevel, UnlockedTier;
    local bool ShouldUpdateSkills;
    local int I;

    `Log("[PerkLevelManager] Restoring skills from config for" @ PerkClass);

    PerkIndex = KFPC.GetPerkIndexFromClass(PerkClass);
    PerkLevel = PLMMutator.ClientConfig.GetPerkLevel(PerkListCache[PerkIndex].PerkLevel, PerkClass);
    UnlockedTier = PerkLevel / `MAX_PERK_SKILLS;

    GetSavedSkills(KFPC.CurrentPerk.Class, SavedSkills);
    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        if (I >= UnlockedTier)
        {
            if (CachedPerkProxy.SelectedSkills[I] != 0) ShouldUpdateSkills = true;
            CachedPerkProxy.SelectedSkills[I] = 0;
        }
        else
        {
            CachedSkills[I] = SavedSkills[I];
            if (SavedSkills[I] != 0)
            {
                `Log("[PerkLevelManager] Setting skill" @ I @ "from config to" @ SavedSkills[I]);
                CachedPerkProxy.SelectedSkills[I] = SavedSkills[I];
                CachedPerksMenu.SelectedSkillsHolder[I] = SavedSkills[I];
                SkillUpdateQueued = true;
                ShouldUpdateSkills = true;
            }
        }
    }

    if (ShouldUpdateSkills)
    {
        // Inform the server to update the client's skills
        // NOTE: we can't use the normal function TWI devised for this purpose
        //       as they seem to cause the client to reset the skills they haven't
        //       yet unlocked.
        ServerUpdateSkills(KFPC.CurrentPerk.Class, SavedSkills);

        // Update the skill UI only if we're on the Perks menu
        PerksMenu = KFGFxMenu_Perks(KFPC.MyGFxManager.CurrentMenu);
        if (PerksMenu != None)
        {
            PerksMenu.UpdateSkillsUI(KFPC.CurrentPerk.Class);
        }
    }
}

simulated function MonitorPerks()
{
    local KFPlayerController.PerkInfo CurrentPerkInfo;
    local PerkListCacheEntry CacheEntry;
    local int ExpectedPerkLevel, ExpectedPrestigeLevel;
    local int CurrentPerkLevel, CurrentPrestigeLevel;
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
        ExpectedPerkLevel = PLMMutator.ClientConfig.GetPerkLevel(PerkListCache[I].PerkLevel, KFPC.PerkList[I].PerkClass);
        ExpectedPrestigeLevel = PLMMutator.ClientConfig.GetPrestigeLevel(PerkListCache[I].PrestigeLevel, KFPC.PerkList[I].PerkClass);

        if (KFPC.PerkList[I].PerkClass == KFPC.CurrentPerk.Class)
        {
            CurrentPerkLevel = ExpectedPerkLevel;
            CurrentPrestigeLevel = ExpectedPrestigeLevel;
        }

        if (ExpectedPerkLevel != KFPC.PerkList[I].PerkLevel || ExpectedPrestigeLevel != KFPC.PerkList[I].PrestigeLevel)
        {
            ShouldUpdateLevels = true;
        }

        KFPC.PerkList[I].PerkLevel = ExpectedPerkLevel;
        KFPC.PerkList[I].PrestigeLevel = ExpectedPrestigeLevel;
    }

    // Update levels
    if (ShouldUpdateLevels) UpdateLevelInfo(CurrentPerkLevel, CurrentPrestigeLevel);

    // Update skills
    if (SkillUpdateQueued && PLMMutator.CanUpdateSkills())
    {
        `Log("[PerkLevelManager] Updating skills");
        KFPC.CurrentPerk.UpdateSkills();
        SkillUpdateQueued = false;
    }
}

simulated function UpdateLevelInfo(int PerkLevel, int PrestigeLevel)
{
    local KFGFxMenu_Perks PerksMenu;

    KFPRIProxy.ActivePerkLevel = PerkLevel;
    KFPRIProxy.ActivePerkPrestigeLevel = PrestigeLevel;

    KFPC.CurrentPerk.SetLevel(PerkLevel);
    KFPC.CurrentPerk.SetPrestigeLevel(PrestigeLevel);

    KFPC.PostTierUnlock(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass);

    PerksMenu = KFGFxMenu_Perks(KFPC.MyGFxManager.CurrentMenu);
    if (PerksMenu != None)
    {
        PerksMenu.UpdateContainers(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass, false);
        PerksMenu.UpdateSkillsHolder(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass);
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

    if (KFPC.CurrentPerk == None) return;

    `Log("[PerkLevelManager] Saving skill selection for" @ KFPC.CurrentPerk.Class);

    SkillSelection.PerkClass = KFPC.CurrentPerk.Class;
    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        SkillSelection.Skills[I] = CachedSkills[I];
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