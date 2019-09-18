class PerkLevelManagerMutator extends KFMutator;

struct ClientEntry
{
    var KFPlayerReplicationInfoProxy PRIProxy;
    var KFPlayerController KFPC;
    var PerkLevelManagerReplicationLink RepLink;
    var bool ShouldUpdateSkills;
};

var PerkLevelManagerConfig ServerConfig;
var PerkLevelManagerClientConfig ClientConfig;
var array<ClientEntry> Clients;
var Name GameStateName;
var byte PrestigeLevel;
var byte PerkLevel;

replication
{
    if (bNetDirty)
        ClientConfig, GameStateName;
}

simulated function PostBeginPlay()
{
    super.PostBeginPlay();

    if (bDeleteMe) return;

    if (Role == ROLE_Authority)
    {
        ServerConfig = new class'PerkLevelManager.PerkLevelManagerConfig';
        ServerConfig.Initialize();

        ClientConfig = Spawn(class'PerkLevelManager.PerkLevelManagerClientConfig', Self);
        ClientConfig.PLMMutator = Self;
        ClientConfig.Initialize();

        SetTimer(1.f, true, nameof(UpdateInfo));

        `Log("[PerkLevelManager] Initialized");
    }
}

function UpdateInfo()
{
    local ClientEntry Client;
    local KFPerkProxy KFPerkProxy;
    local byte ExpectedPerkLevel, ExpectedPrestigeLevel;
    local int UnlockedTier;
    local int I;

    if (MyKFGI != None)
    {
        GameStateName = MYKFGI.GetStateName();
    }

    foreach Clients(Client)
    {
        if (Client.KFPC.CurrentPerk == None || Client.KFPC.bWaitingForClientPerkData) continue;

        ExpectedPerkLevel = ClientConfig.GetPerkLevel(Client.PRIProxy.ActivePerkLevel, Client.KFPC.CurrentPerk.Class);
        ExpectedPrestigeLevel = ClientConfig.GetPrestigeLevel(Client.PRIProxy.ActivePerkPrestigeLevel, Client.KFPC.CurrentPerk.Class);
        UnlockedTier = ExpectedPerkLevel / `MAX_PERK_SKILLS;

        if (Client.PRIProxy.ActivePerkLevel != ExpectedPerkLevel || Client.PRIProxy.ActivePerkPrestigeLevel != ExpectedPrestigeLevel)
        {
            `Log("[PerkLevelManager] Client" @ Client.KFPC.PlayerReplicationInfo.PlayerName @ "doesn't match the expected level; updating levels.");

            Client.RepLink.NotifyChangeLevel(
                Client.PRIProxy.ActivePerkLevel, Client.PRIProxy.ActivePerkPrestigeLevel,
                ExpectedPerkLevel, ExpectedPrestigeLevel
            );

            Client.KFPC.CurrentPerk.SetLevel(ExpectedPerkLevel);
            Client.KFPC.CurrentPerk.SetPrestigeLevel(ExpectedPrestigeLevel);

            Client.PRIProxy.ActivePerkLevel = ExpectedPerkLevel;
            Client.PRIProxy.ActivePerkPrestigeLevel = ExpectedPrestigeLevel;
        }

        KFPerkProxy = CastPerkProxy(Client.KFPC.CurrentPerk);

        if (KFPerkProxy != None)
        {
            for (I = 0; I < `MAX_PERK_SKILLS; I++)
            {
                if (I >= UnlockedTier)
                {
                    if (KFPerkProxy.SelectedSkills[I] != 0) Client.ShouldUpdateSkills = true;
                    KFPerkProxy.SelectedSkills[I] = 0;
                }
            }
        }

        if (Client.ShouldUpdateSkills && CanUpdateSkills())
        {
            `Log("[PerkLevelManager] Client" @ Client.KFPC.PlayerReplicationInfo.PlayerName @ "has illegal skills; updating skills.");
            Client.KFPC.CurrentPerk.UpdateSkills();
            CLient.ShouldUpdateSkills = false;
        }
    }
}

simulated function bool CanUpdateSkills()
{
    return GameStateName == 'TraderOpen' || GameStateName == 'PendingMatch';
}

function NotifyLogin(Controller NewPlayer)
{
    local ClientEntry NewClient;
    local KFPlayerController NewKFPC;

    NewKFPC = KFPlayerController(NewPlayer);
    if (NewKFPC != None)
    {
        NewClient.PRIProxy = CastPRIProxy(NewPlayer.PlayerReplicationInfo);
        NewClient.KFPC = NewKFPC;
        NewClient.RepLink = CreateRepLink(NewKFPC);
        Clients.AddItem(NewClient);
    }

    super.NotifyLogin(NewPlayer);
}

function NotifyLogout(Controller Exiting)
{
    local int ClientIndex;

    ClientIndex = Clients.Find('KFPC', KFPlayerController(Exiting));
    if (ClientIndex != INDEX_NONE)
    {
        Clients.Remove(ClientIndex, 1);
    }

    super.NotifyLogout(Exiting);
}

function PerkLevelManagerReplicationLink CreateRepLink(KFPlayerController KFPC)
{
    local PerkLevelManagerReplicationLink RepLink;

    RepLink = Spawn(class'PerkLevelManager.PerkLevelManagerReplicationLink', KFPC);
    RepLink.PLMMutator = Self;
    RepLink.Initialize();

    return RepLink;
}

`ForcedObjectTypecastFunction(KFPlayerReplicationInfoProxy, CastPRIProxy)
`ForcedObjectTypecastFunction(KFPerkProxy, CastPerkProxy)

defaultproperties
{
    Role = ROLE_Authority;
    RemoteRole = ROLE_SimulatedProxy;
    bAlwaysRelevant = true;
}