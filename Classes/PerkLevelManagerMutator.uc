class PerkLevelManagerMutator extends KFMutator;

struct ClientEntry
{
    var KFPlayerReplicationInfoProxy PRIProxy;
    var KFPlayerController KFPC;
    var PerkLevelManagerReplicationLink RepLink;
    var bool ShouldUpdateSkills;
};

var array<ClientEntry> Clients;
var Name GameStateName;
var byte PrestigeLevel;
var byte PerkLevel;

replication
{
    if (bNetDirty)
        GameStateName;
}

simulated function PostBeginPlay()
{
    if (Role == ROLE_Authority)
    {
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

    ExpectedPerkLevel = 5;
    ExpectedPrestigeLevel = 4;
    UnlockedTier = ExpectedPerkLevel / 5;

    foreach Clients(Client)
    {
        if (Client.PRIProxy.ActivePerkLevel != ExpectedPerkLevel || Client.PRIProxy.ActivePerkPrestigeLevel != ExpectedPrestigeLevel)
        {
            `Log("[PerkLevelManager] Client" @ Client.KFPC.PlayerReplicationInfo.PlayerName @ "doesn't match the expected level, updating.");

            Client.RepLink.NotifyChangeLevel(
                Client.PRIProxy.ActivePerkLevel, Client.PRIProxy.ActivePerkPrestigeLevel,
                ExpectedPerkLevel, ExpectedPrestigeLevel
            );

            Client.PRIProxy.ActivePerkLevel = ExpectedPerkLevel;
            Client.PRIProxy.ActivePerkPrestigeLevel = ExpectedPrestigeLevel;
        }

        if (Client.KFPC.CurrentPerk != None)
        {
            Client.KFPC.CurrentPerk.SetLevel(ExpectedPerkLevel);
            Client.KFPC.CurrentPerk.SetPrestigeLevel(ExpectedPrestigeLevel);

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
                Client.KFPC.CurrentPerk.UpdateSkills();
                CLient.ShouldUpdateSkills = false;
            }
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
        NewClient.RepLink = Spawn(class'PerkLevelManager.PerkLevelManagerReplicationLink', NewKFPC);
        NewClient.RepLink.PLMMutator = Self;
        Clients.AddItem(NewClient);
    }

    super.NotifyLogin(NewPlayer);
}

function NotifyLogout(Controller Exiting)
{
    local ClientEntry Client;
    local int I;

    for (I = 0; I < Clients.Length; I++)
    {
        Client = Clients[I];

        if (Client.KFPC == Exiting)
        {
            Clients.Remove(I, 1);
        }
    }

    super.NotifyLogout(Exiting);
}

`ForcedObjectTypecastFunction(KFPlayerReplicationInfoProxy, CastPRIProxy)
`ForcedObjectTypecastFunction(KFPerkProxy, CastPerkProxy)

defaultproperties
{
    Role = ROLE_Authority;
    RemoteRole = ROLE_SimulatedProxy;
    bAlwaysRelevant = true;
}