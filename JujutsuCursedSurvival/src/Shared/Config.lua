return {
 Title="JUJUTSU: CURSED SURVIVAL", Version="0.1.0-alpha", MaxPlayers=15,
 RoundSeconds=240, Intermission=20, ResultsSeconds=10, SelectionSeconds=5, IntroSeconds=5, SuddenDeathSeconds=25,
 UseOriginalNames=true, -- Original analogues by default; gameplay IDs remain stable.
 DataStoreName="CursedSurvival_v1", SchemaVersion=1, LeaseSeconds=180, AutosaveSeconds=45,
 MaxNPCs=18, MaxDebris=32, ArenaRadius=145, KillY=-30, EnergyRegen=6, StaminaRegen=15,
 SprintDrain=22, NPCThinkSeconds=0.25, WaveSeconds=18, AFKMinimumActions=3, AFKMinimumSeconds=15, DailyCoins=100,
 StudioPersistence=false,
 Products={
  Coins={Id=0,Status="NOT_CONFIGURED",Coins=500,Name="500 монет"},
  Chest={Id=0,Status="NOT_CONFIGURED",Cosmetics={"Azure","Crimson"},Name="Сундук: Azure + Crimson"},
  Finisher={Id=0,Status="NOT_CONFIGURED",Cosmetics={"Eclipse"},Name="Эффект устранения Eclipse"},
  Effects={Id=0,Status="NOT_CONFIGURED",Cosmetics={"Violet"},Name="Violet VFX"},
  Bundle={Id=0,Status="NOT_CONFIGURED",Cosmetics={"Gold","Violet"},Name="Набор Gold + Violet"},
 },
 Passes={
  VIP={Id=0,Name="VIP",Cosmetics={"Gold"}}, Auras={Id=0,Name="Anime Aura Collection",Cosmetics={"Azure","Crimson","Violet"}},
  Spawn={Id=0,Name="Exclusive Spawn FX",Cosmetics={"Eclipse"}}, Emotes={Id=0,Name="Premium Emotes",Emote=true},
  Loadouts={Id=0,Name="Extra Cosmetic Loadouts",Slots=3},
 },
 Cosmetics={
  Azure={Name="AZURE / небесная аура",Price=150,Color={65,198,255}},
  Crimson={Name="CRIMSON / багровая аура",Price=150,Color={255,65,95}},
  Violet={Name="VIOLET / след пустоты",Price=300,Color={168,95,255}},
  Gold={Name="GOLD / золотая аура",Price=500,Color={255,208,90}},
  Eclipse={Name="ECLIPSE / эффект устранения",Price=750,Color={240,225,255}},
 },
 Sounds={}, -- Owned audio IDs only. Empty means silent procedural effects.
}