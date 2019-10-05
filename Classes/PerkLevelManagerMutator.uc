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
    local int ClientIndex, I;

    if (MyKFGI != None)
    {
        GameStateName = MYKFGI.GetStateName();
    }

    for (ClientIndex = 0; ClientIndex < Clients.Length; ClientIndex++)
    {
        Client = Clients[ClientIndex];

        if (Client.KFPC.CurrentPerk == None || Client.KFPC.bWaitingForClientPerkData) continue;

        ExpectedPerkLevel = ClientConfig.GetPerkLevel(Client.PRIProxy.ActivePerkLevel, Client.KFPC.CurrentPerk.Class);
        ExpectedPrestigeLevel = ClientConfig.GetPrestigeLevel(Client.PRIProxy.ActivePerkPrestigeLevel, Client.KFPC.CurrentPerk.Class);
        UnlockedTier = ExpectedPerkLevel / `MAX_PERK_SKILLS;

        if (Client.PRIProxy.ActivePerkLevel != ExpectedPerkLevel || Client.PRIProxy.ActivePerkPrestigeLevel != ExpectedPrestigeLevel)
        {
            `Log("[PerkLevelManager] Updating client" @ Client.KFPC.PlayerReplicationInfo.PlayerName @ "from (" $ Client.PRIProxy.ActivePerkPrestigeLevel $ "," @ Client.PRIProxy.ActivePerkLevel $ ") to (" $ ExpectedPrestigeLevel $ "," @ ExpectedPerkLevel $ ")");

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
                    if (KFPerkProxy.SelectedSkills[I] != 0) Clients[ClientIndex].ShouldUpdateSkills = true;
                    KFPerkProxy.SelectedSkills[I] = 0;
                }
            }
        }

        if (Clients[ClientIndex].ShouldUpdateSkills && CanUpdateSkills())
        {
            `Log("[PerkLevelManager] Updating skills for client" @ Client.KFPC.PlayerReplicationInfo.PlayerName);
            Client.KFPC.CurrentPerk.UpdateSkills();
            Clients[ClientIndex].ShouldUpdateSkills = false;
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
    RepLink.KFPC = KFPC;
    RepLink.Initialize();

    return RepLink;
}

function UpdateClientSkills(KFPlayerController KFPC, class<KFPerk> PerkClass, byte Skills[`MAX_PERK_SKILLS])
{
    local KFPerkProxy KFPerkProxy;
    local int ClientIndex, I;

    ClientIndex = Clients.Find('KFPC', KFPC);
    if (ClientIndex == INDEX_NONE)
    {
        `Warn("[PerkLevelManager] UpdateClientSkills :: Attempted updating client skills of an unregistered KFPC (???)");
        return;
    }

    if (Clients[ClientIndex].KFPC.CurrentPerk == None || Clients[ClientIndex].KFPC.CurrentPerk.Class != PerkClass)
    {
        `Warn(
            "[PerkLevelManager] UpdateClientSkills :: Failed updating client skills; perk mismatch, expected:"
            @ PerkClass
            $ ", Actual:"
            @ (Clients[ClientIndex].KFPC.CurrentPerk == None ? "None" : string(Clients[ClientIndex].KFPC.CurrentPerk.Class))
        );
        return;
    }

    KFPerkProxy = CastPerkProxy(Clients[ClientIndex].KFPC.CurrentPerk);

    if (KFPerkProxy == None)
    {
        `Warn("[PerkLevelManager] UpdateClientSkills :: Failed casting perk proxy");
        return;
    }

    for (I = 0; I < `MAX_PERK_SKILLS; I++)
    {
        KFPerkProxy.SelectedSkills[I] = Skills[I];
    }

    `Log("[PerkLevelManager] UpdateClientSkills :: Queuing skills update for client" @ Clients[ClientIndex].KFPC.PlayerReplicationInfo.PlayerName);
    Clients[ClientIndex].ShouldUpdateSkills = true;
}

`ForcedObjectTypecastFunction(KFPlayerReplicationInfoProxy, CastPRIProxy)
`ForcedObjectTypecastFunction(KFPerkProxy, CastPerkProxy)

defaultproperties
{
    Role = ROLE_Authority;
    RemoteRole = ROLE_SimulatedProxy;
    bAlwaysRelevant = true;
}