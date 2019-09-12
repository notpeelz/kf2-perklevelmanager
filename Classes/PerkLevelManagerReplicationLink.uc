class PerkLevelManagerReplicationLink extends ReplicationInfo;

var PerkLevelManagerMutator PLMMutator;

var KFPlayerController KFPC;
var KFPlayerReplicationInfo KFPRI;
var KFPlayerReplicationInfoProxy KFPRIProxy;

var KFPerkProxy KFPerkProxy;

var bool ShouldUpdate;
var bool ShouldUpdateSkills;
var byte PerkLevel;
var byte PrestigeLevel;

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

reliable client function NotifyChangeLevel(byte CurrentPerkLevel, byte CurrentPrestigeLevel, byte NewPerkLevel, byte NewPrestigeLevel)
{
    `Log("[PerkLevelManager] Updating to (" $ NewPrestigeLevel $ "," @ NewPerkLevel $ ")");

    PerkLevel = NewPerkLevel;
    PrestigeLevel = NewPrestigeLevel;

    QueueUpdate();
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
    if (WorldInfo.NetMode != NM_DedicatedServer)
    {
        if (CacheVariables())
        {
            if (KFPC.MyGFxHUD.PlayerStatusContainer == None || KFPC.CurrentPerk == None) return;

            if (ShouldUpdate)
            {
                UpdateLevelInfo();
                ShouldUpdate = false;
            }
        }
    }

    super.tick(DeltaTime);
}

simulated function UpdateLevelInfo()
{
    local KFGFxMenu_Perks PerkMenu;
    local KFPlayerController.PerkInfo PerkInfo;
    local int I;

    if (!CacheVariables()) return;

    for (I = 0; I < KFPC.PerkList.Length; I++)
    {
        KFPC.PerkList[KFPC.GetPerkIndexFromClass(KFPC.PerkList[I].PerkClass)].PerkLevel = PerkLevel;
        KFPC.PerkList[KFPC.GetPerkIndexFromClass(KFPC.PerkList[I].PerkClass)].PrestigeLevel = PrestigeLevel;
    }

    KFPC.PostTierUnlock(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass);

    PerkMenu = KFGFxMenu_Perks(KFPC.MyGFxManager.CurrentMenu);
    if (PerkMenu != None)
    {
        PerkMenu.UpdateSkillsHolder(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass);
        PerkMenu.UpdateContainers(KFPC.PerkList[KFPC.SavedPerkIndex].PerkClass, false);
    }

    foreach KFPC.PerkList(PerkInfo)
    {
        PerkInfo.PerkLevel = PerkLevel;
        PerkInfo.PrestigeLevel = PrestigeLevel;
    }

    UpdateSkills();
}

simulated function UpdateSkills()
{
    local int UnlockedTier;
    local bool CanUpdateSkills;
    local int I;

    KFPC.CurrentPerk.SetLevel(PerkLevel);
    KFPC.CurrentPerk.SetPrestigeLevel(PrestigeLevel);

    UnlockedTier = PerkLevel / 5;

    KFPerkProxy = CastPerkProxy(KFPC.CurrentPerk);
    if (KFPerkProxy == None) return;

    CanUpdateSkills = PLMMutator.CanUpdateSkills();

    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        if (I >= UnlockedTier)
        {
            if (KFPerkProxy.SelectedSkills[I] != 0) ShouldUpdateSkills = true;
            KFPerkProxy.SelectedSkills[I] = 0;
        }
    }

    if (ShouldUpdateSkills && CanUpdateSkills)
    {
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

`ForcedObjectTypecastFunction(KFPlayerReplicationInfoProxy, CastPRIProxy)
`ForcedObjectTypecastFunction(KFPerkProxy, CastPerkProxy)

defaultproperties
{
    bAlwaysRelevant = false;
    bOnlyRelevantToOwner = true;
    Role = ROLE_Authority;
    RemoteRole = ROLE_SimulatedProxy;
}