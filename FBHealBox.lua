-- ==========================================================================
-- Heal Box Vanilla
--
-- Original: "Heal Box" von Dourd (Argent Dawn EU), UI Overhauled.
-- Portierung auf Vanilla, Client 1.12.1 (optional SuperWoW) sowie
-- Ausbau des Funktionsumfangs 09/2026 durch Mquadrat:
--   * eigenes Kaskadenmenue fuer die Zauber- und Rangwahl
--   * Heilvorhersage fuer Direktheilung, HoT-Restticks und Absorb-Schilde,
--     selbstkorrigierend ueber den Combatlog
--   * HealComm-Sync mit Puppeteer, pfUI, Luna und Co.
--   * Lokalisierung Deutsch / Englisch, im Optionsfenster umschaltbar
--   * v1.4.1: Begleiter (Pets) als eigene Plaketten, Manabalken im
--     Lebensbalken, frei waehlbare Button- und Zeilenabstaende, Testmodus
--     mit Geisterspielern, gespeicherte Plattenposition, Klassenfarben,
--     Buff-Wache (oranger Rahmen bei fehlendem Buff), Reichweiten-Fading,
--     Optionsfenster mit Tabs, Rechtsklick-Zweitzauber, Tot/Geist/Offline-
--     Anzeige, Debuff-Icon mit Stackzahl
--   * v1.4.2: Hook-Schnittstelle fuer Module (FBHealBox_RegisterHook,
--     FBHealBox_AddOptionsTab). Der Raidmodus lebt in FBHealBox_Raid.lua.
--   * v1.4.3: Mana-Ticker-Modul (FBHealBox_Ticker.lua), Smart-Damage-Modul
--     (FBHealBox_Damage.lua, Abrangen von Angriffszaubern), Reiterknoepfe
--     schmaler, damit vier Reiter ins Optionsfenster passen, Smart Healing
--     (automatisches Abrangen je Ziel, standardmaessig aus), Cooldown-Uhr auf den Buttons, roter Rahmen fuer
--     "wer wird angegriffen", HoT- und Schild-Restzeit auf dem jeweiligen
--     Button (inkl. Geschwaechte Seele).
--   * v1.4.4: Leistungsdurchgang ohne Funktionsaenderung: zentrale Button-
--     Zustaende statt 260 Event-Handler, Anzeige-Zwischenspeicher, Aura-Scan
--     je Frame nur einmal, Event-Salven zusammengefasst, Ticker per Event
--     gesteuert, Combatlog-Parser nach Eventklasse. Details im CHANGELOG.
--   * v1.4.4.1: Spells hinzugefügt, Bugfixes
--   * v1.4.4.2: TOC Addonbeschreibung präzisiert, Umstellung Buff-Restlaufzeit von 4/4 Blocks auf 32 Topdown Anzeige (fadeout Effekt)
--   * v1.4.4.3: Klassensperre fuer Krieger, Schurke und Jaeger (Anzeige
--     bleibt aus, Hinweis im Chat, Freischaltung mit /fbp forceload),
--     Smart Healing rangt HoTs aller Klassen nicht mehr ab. 
--     Smart Healing rangt in Heilketten auch ueber Zaubergrenzen
--     ab (Grosse Heilung -> Geringes Heilen), abschaltbar mit /fbp smartcross.
--   * v1.4.5: Blizzards Gruppenfenster ausblendbar (schliesst sich mit dem
--     Anheftmodus gegenseitig aus), Wut, Energie und Fokus im Balken,
--     +Heilung der Ausruestung ueber ClassicAPI in der Vorhersage.
--   * v1.4.5.1: Ruckeln des Manafunkens behoben (Bewegungsschwelle und
--     Zeichentakt), globaler Cooldown dunkelt nicht mehr alle Buttons ab
--     und laeuft stattdessen als Uhr mit (eigene Schwelle FBCD_SHOW_MIN).
--   * v1.4.5.2: Laufende HoTs zaehlen bei Smart Healing nicht mehr als
--     anfliegende Heilung.
--   * v1.4.5.3: Einstellbarer Hintergrund hinter den Balken der Plaketten
--     (Regler "Balkenhintergrund", Standard 0 = wie bisher durchscheinend).
--   * v1.4.6: Leistungsdurchgang ohne Funktionsaenderung: nur geaenderte
--     Einheiten werden neu gezeichnet (FBHealBox_RefreshUnitsByName, Hook
--     "RefreshNames"), Zaubertimer steigen frueher aus.
--
-- Ehre wem Ehre gebuehrt: Aufbau, Namensplaketten und Grundidee stammen
-- aus dem Original.
-- ========================================================================== 

-- Schutz gegen doppeltes Laden (z. B. .toc und .xml binden dieselbe Datei
-- ein). Ein zweiter Durchlauf wuerde alle Frames, Hooks und das
-- Optionsfenster erneut anlegen.
if (FBHealBox_CoreLoaded) then return; end
FBHealBox_CoreLoaded = true;

FBHasSuperWoW = (SUPERWOW_VERSION ~= nil); 
FBClass = UnitClass("player"); 

-- ==========================================================================
-- [ Klassensperre ]
--
-- Das Addon lohnt sich nur fuer Klassen, die heilen oder buffen koennen.
-- Krieger, Schurken und Jaeger haben davon nichts: keine Heilzauber, keine
-- Heilvorhersage, kein Mana-Ticker (Wut und Energie regenerieren anders,
-- der Jaeger heilt niemanden). Bei diesen drei Klassen bleibt die Anzeige
-- nach dem Einloggen aus, es kommt nur ein Hinweis in den Chat. Wer sie
-- trotzdem will, schaltet sie mit /fbp forceload dauerhaft frei (gemerkt
-- je Charakter in HealBox.ForceLoad).
-- ==========================================================================

-- Klassen-Token in Grossbuchstaben ("PRIEST"), wenn der Client eines liefert
FBClassToken = nil;
do
    local _, eng = UnitClass("player");
    if (eng) then FBClassToken = strupper(eng); end
end

-- Rueckfall, wenn der Client kein englisches Token liefert: angezeigter
-- Klassenname. Bewusst in mehreren Sprachen, damit die Sperre auch auf
-- lokalisierten Clients greift.
FBBlockedClasses = {
    ["WARRIOR"] = true,   ["ROGUE"] = true,     ["HUNTER"] = true,
    ["KRIEGER"] = true,   ["SCHURKE"] = true,   ["JAEGER"] = true,
    ["GUERRIER"] = true,  ["VOLEUR"] = true,    ["CHASSEUR"] = true,
    ["GUERRERO"] = true,  ["PICARO"] = true,    ["CAZADOR"] = true,
    ["GUERRIERO"] = true, ["LADRO"] = true,     ["CACCIATORE"] = true,
    -- "Jaeger" und "Picaro" mit Sonderzeichen, je einmal Latin-1 und UTF-8,
    -- gross wie klein: strupper des Clients laesst Umlaute in Ruhe
    ["J\196GER"] = true, ["J\228GER"] = true,
    ["J\195\132GER"] = true, ["J\195\164GER"] = true,
    ["P\205CARO"] = true, ["P\237CARO"] = true,
    ["P\195\141CARO"] = true, ["P\195\173CARO"] = true,
};

function FBHealBox_ClassIsBlocked()
    if (FBClassToken and FBBlockedClasses[FBClassToken]) then return true; end
    if (FBClass and FBBlockedClasses[strupper(FBClass)]) then return true; end
    -- Letzter Rueckfall ohne Namen: Wut und Energie sind nie Manaklassen.
    -- (Der Jaeger hat Mana und wird nur ueber den Namen erkannt.)
    if (not FBClassToken) and (UnitPowerType) then
        local pt = UnitPowerType("player");
        if (pt == 1) or (pt == 3) then return true; end
    end
    return false;
end

FBClassBlocked   = FBHealBox_ClassIsBlocked();
-- Bis die SavedVariables gelesen sind, gilt eine gesperrte Klasse als aus
FBAddonSuppressed = FBClassBlocked;
FBLoadAnnounced   = false;
FBGateAnnounced   = false;

-- Laeuft das Addon gerade im Ruhezustand? (Modul-Abfrage)
function FBHealBox_Suppressed()
    return (FBAddonSuppressed == true);
end

-- [[ Globals ]] -- 
-- Vorgabewerte. Die SavedVariables ersetzen diese Tabelle beim Laden
-- komplett, deshalb setzt FBHealBox_ApplyDefaults() fehlende Schluessel
-- nach dem Laden noch einmal nach.
HealBox = { 
    MaxButtons = 5, 
    Scale = 1.0, 
    AttachMode = 0, 
    Active = 1, 
    SpellChoice = {}, 
    ButtonSpacing = 2,   -- px zwischen den Buttons (1..20)
    RowSpacing = 4,      -- px zwischen den Plaketten (1..20)
    ManaBar = 1,         -- Manabalken im Lebensbalken anzeigen
    BarBG = 0,           -- Deckkraft des Balkenhintergrunds in Prozent
    PowerBar = 0,        -- auch Wut, Energie und Fokus im Balken zeigen
    HideBlizzParty = 0,  -- Blizzards Gruppenfenster verstecken
    HealBonus = 1,       -- +Heilung der Ausruestung in die Vorhersage rechnen
    ShowPets = 1,        -- Begleiter als eigene Plaketten anzeigen
    ClassColors = 1,     -- Namen in Klassenfarbe
    RangeFade = 1,       -- Plakette ausgrauen, wenn ausser Reichweite
    WatchBuff = nil,     -- Zaubername der Buff-Wache (nil = aus)
    SpellChoiceR = {},   -- Rechtsklick-Belegung
    RightClick = 0,      -- Rechtsklick-Zweitzauber (explizit einschalten)
    DebuffIcon = 1,      -- Debuff-Icon neben dem Namen
    LOSIcon = 1,         -- Sichtlinien-Abzeichen
    BuffWatchPets = 0,   -- Buff-Wache auch fuer Begleiter
    SmartRank = 0,       -- Smart Healing (bewusst aus: Overheal kann gewollt sein)
    SmartMargin = 20,    -- Sicherheitsaufschlag in Prozent
    SmartCross = 1,      -- Abrangen auch ueber Zaubergrenzen (/fbp smartcross)
    Cooldowns = 1,       -- Cooldown-Uhr auf den Buttons
    AggroMark = 1,       -- roter Rahmen fuer den Angegriffenen
    SpellTimers = 1,     -- HoT-/Schild-Restzeit auf den Buttons
    BuffIcons = 1,       -- Buff-Icons mit Uhr im Lebensbalken
    PlateLeft = "target",   -- Klick auf die Plakette: target | menu | move | none
    PlateRight = "target",
    ForceLoad = 0,       -- Anzeige auch bei Krieger/Schurke/Jaeger (/fbp forceload)
}; 
-- Anzeigename des Addons. FBADDON_FOLDER muss dem Ordnernamen unter
-- Interface\AddOns entsprechen (dort liegt auch die .toc). Nur dann
-- feuert ADDON_LOADED fuer uns.
FBADDON_NAME   = "Heal Box Vanilla";
FBADDON_FOLDER = "FBHealBox";
HealBoxVersion = "|cFFFFFF00v1.4.6|r"; 

-- ==========================================================================
-- [ Lokalisierung / Localization ]
--
-- Alle sichtbaren Texte liegen in FBLocale. Die aktive Sprache haengt in
-- FBL, abgefragt wird ueber FBT("SCHLUESSEL"). Fehlt ein Schluessel in der
-- gewaehlten Sprache, faellt er auf Englisch zurueck.
--
-- Umgeschaltet wird im Optionsfenster; FBHealBox_ApplyLocale() beschriftet
-- die bereits gebaute Oberflaeche neu, ein /reload ist nicht noetig.
--
-- Hinweis: In den angezeigten Texten bewusst ae/oe/ue/ss statt Umlauten -
-- der 1.12-Client behandelt Umlaute je nach Locale und Schriftart
-- unterschiedlich.
-- ==========================================================================

FBLocale = {};

FBLocale["enUS"] = {
    LANG_NAME     = "English",
    LANGUAGE      = "Language",

    LOADED        = "loaded|r. Minimap button or /fbp config opens the options, /fbp reports the heal prediction.",
    SUPERWOW      = " |cFF55FF55[SuperWoW detected]|r",
    CREDITS       = "|cFFAAAAAAOriginal by Dourd (Argent Dawn EU), ported to Vanilla and extended 09/2026 by Mquadrat|r",

    TT_NO_SPELL   = "|cFFFFFFFFNo spell\n|cFF00FF00Pick a spell in the options window.",
    TT_TARGET     = "Target",
    NOT_IN_GROUP  = " is not in your group.",

    SELECT_SPELL  = "Select spell...",
    BUTTON        = "Button",
    TAB_BUTTONS   = "Buttons",
    TAB_GENERAL   = "General",
    COL_LEFT      = "Left click",
    COL_RIGHT     = "Right click",
    RIGHTCLICK    = "Right-click spell",
    RIGHTCLICK_TIP = "Gives every button a second spell on right click (e.g. Flash Heal left, Greater Heal right). Off by default. When on, a second column appears above and a small icon in the corner of each button shows the right-click spell. Drop a spell with the right mouse button or with Shift held to fill this side.",
    TT_RIGHT      = "Right click",
    TT_BUFF_UNKNOWN = "remaining time unknown (not your cast)",
    DROP_SET      = "Button %d: |cFFFFFFFF%s|r (dragged from the spellbook)",
    DROP_SET_R    = "Button %d, right click: |cFFFFFFFF%s|r (dragged from the spellbook)",
    DROP_UNKNOWN  = "Could not identify the dragged spell.",
    SMARTRANK     = "Smart Healing",
    SMARTRANK_TIP = "Automatically casts the lowest spell rank that covers the target's missing health (minus incoming heals) plus safety margin.\n\n"
        .. "|cFFFFD100Rules:|r\n"
        .. "• Direct heals only (HoTs and shields untouched)\n"
        .. "• A HoT on the target is not counted as incoming\n"
        .. "• Always casts assigned rank below 30 % health\n"
        .. "• Never heals more than the assigned rank\n"
        .. "• Chain spell switching toggled via 'Smartcross'\n"
        .. "• Decisions logged with /fbp debug",
    SMART_MARGIN  = "Safety margin: |cFFFFFFFF%s %%",
    BAR_BG        = "Bar background: |cFFFFFFFF%s %%",
    BAR_BG_OFF    = "clear",
    BAR_BG_FULL   = "solid",
    COOLDOWNS     = "Cooldowns on buttons",
    COOLDOWNS_TIP = "Shows the cooldown sweep on every button (Nature's Swiftness, Inner Focus, Lay on Hands, shield cooldown). The global cooldown runs as a sweep too, so after every cast you see the short wait run out instead of the icons going dark and bright again. Set FBCD_SHOW_MIN to 2 in the code to leave the global cooldown out.",
    AGGRO         = "Mark who is attacked",
    AGGRO_TIP     = "Red border on the plate or cell of the member your hostile target is currently targeting. Checked five times a second.",
    BUFFICONS     = "Buff icons left of the bar",
    BUFFICONS_TIP = "Buffs with a duration that sit on your buttons (Fortitude, Divine Spirit, Fear Ward, ...) appear as small icons on the outer left side of the plate while they are up. Like a minute hand, the icon turns black and white clockwise from twelve o'clock as the time runs out: full colour when fresh, right half grey at half time, three quarters grey at a quarter left. Exact on yourself, counted from your own cast on others; a buff cast by someone else stays fully coloured (time unknown). /fbp buffs shows what is tracked.",
    TIMERS        = "HoT and shield timers",
    TIMERS_TIP    = "Each button shows the remaining seconds of your own HoT or shield of that spell on that unit: green for HoTs, blue for the shield, red for Weakened Soul after the shield. Buffs with a duration are shown as icons in the health bar instead (see Buff icons).",
    DBG_SMARTRANK = "Auto-downrank: %s -> %s (missing %d, expected %d)",
    DROP_HINT     = "Drag spells from the spellbook onto a button. Right mouse button or Shift while dropping fills the right-click side.",
    STATE_DEAD    = "Dead",
    STATE_GHOST   = "Ghost",
    STATE_OFFLINE = "Offline",
    PLATE_LEFT    = "Left click on plate",
    PLATE_RIGHT   = "Right click on plate",
    PLATE_TIP     = "What a click on a name plate (name or health bar) does. Shift + left drag always moves the display, whatever is set here.",
    ACT_TARGET    = "Target",
    ACT_MENU      = "Unit menu",
    ACT_MOVE      = "Move display",
    ACT_NONE      = "Nothing",
    LOSICON       = "Line of sight",
    LOSICON_TIP   = "Shows an eye badge on the left edge of a plate while the unit is out of your line of sight. With the UnitXP client mod this is checked live; without it the addon remembers a 'not in line of sight' error for a few seconds after you tried to heal that unit and clears it as soon as a cast on the unit starts or a heal lands.",
    DEBUFFICON    = "Debuff icon",
    DEBUFFICON_TIP = "Shows the icon of the first debuff your class can remove next to the name, with its stack count. The health bar keeps taking the debuff colour as well.",
    MENU_NO_SPELL = "|cFF999999No spell|r",
    RANK_DEFAULT  = "Default",

    PANEL_SUB     = "Options for %s.\nChoose how many buttons to show\nand which spell each button casts.",
    SHOW_BUTTONS  = "Show |cFFFFFFFF%s|r buttons",
    SCALE         = "Frame scale: |cFFFFFFFF%s",
    SMALL         = "Small",
    LARGE         = "Large",

    BTN_SPACING   = "Button spacing: |cFFFFFFFF%s px",
    ROW_SPACING   = "Row spacing: |cFFFFFFFF%s px",

    ATTACH        = "Default party frames",
    ATTACH_TIP    = "Attaches the heal buttons to Blizzard's default party frames instead of using the addon's own movable name plates.",
    COMM          = "HealComm sync",
    COMM_TIP      = "Broadcasts your heals in the HealComm format so Puppeteer, pfUI, Luna and others can display them, and feeds the heals announced by other healers into your own prediction.",
    MANABAR       = "Mana bar",
    MANABAR_TIP   = "Shows a thin blue mana bar along the bottom edge of the health bar, only for units that actually use mana (no rage, focus or energy).",
    SHOWPETS      = "Show pets",
    SHOWPETS_TIP  = "Adds a plate for every pet in the group (hunter, warlock) directly below its owner, with the same heal buttons.",
    TESTMODE      = "Test mode",
    TESTMODE_TIP  = "Fills the display with ghost players and pets so you can arrange everything without being in a group. Ghosts show health, mana, a shield, incoming healing and a dispellable debuff. Not saved, always off after login.",
    TEST_ON       = "Test mode |cFF00FF00on|r, ghost players active. Buttons do not cast on ghosts.",
    TEST_OFF      = "Test mode |cFFFF0000off|r.",
    TEST_CLICK    = "Test mode: no cast on a ghost player.",
    CLASSCOLORS   = "Class colours",
    CLASSCOLORS_TIP = "Colours the name on each plate in the class colour (Healium style). Pets keep their light-blue name.",
    RANGEFADE     = "Range fading",
    RANGEFADE_TIP = "Fades a whole plate including its buttons to half transparency when the unit is out of range of your first assigned spell (or beyond 28 yards if no spell is assigned).",
    BUFFWATCH     = "Buff watch",
    BUFFWATCH_TIP = "Pick one of your buffs. Every plate whose unit is missing that buff gets an orange border. The group version counts as well (Prayer of Fortitude for Power Word: Fortitude, Gift of the Wild for Mark of the Wild, Greater Blessings, ...).",
    BUFFWATCH_NONE = "none",
    BUFFWATCH_PETS = "Buff watch on pets",
    BUFFWATCH_PETS_TIP = "Also marks pets that are missing the watched buff. Off by default, because pets rarely get Fortitude or Blessings, so their plates would stay orange most of the time.",
    MENU_NO_BUFF  = "|cFF999999No buff watch|r",
    LANG_TIP      = "Switches every text in the addon. Takes effect immediately, no reload required.",

    ABOUT         = "%s %s |cFFAAAAAA(original by Dourd, UI Overhauled)|r\n|cFFAAAAAAPorted to Vanilla and extended 09/2026 by Mquadrat|r",
    MM_TIP        = "Left: options\nHold right: move this button\nShift + left: show/hide the display",

    FBP_WATCHED   = "Spells read from the spellbook:",
    FBP_ACTIVE    = "Currently active:",
    FBP_DIRECT    = "direct",
    FBP_SHIELD    = "shield",
    FBP_LEARNED   = "learned",
    FBP_EVERY     = "every",
    FBP_TICKSOF   = "ticks of",
    FBP_CAST      = "Cast",
    FBP_ON        = "on",
    FBP_OF        = "of",
    FBP_FOR       = "for",
    FBP_SYNC      = "HealComm sync:",
    FBP_STATE_ON  = "on",
    FBP_STATE_OFF = "off",
    FBP_INCOMING  = "Incoming",
    FBP_DEBUG     = "Debug:",
    FBP_RESET     = "Learned values discarded.",
    FBP_COMMANDS  = "Commands: /fbp config (options window), /fbp test (test mode), /fbp buffs (buff diagnostics), /fbp forceload (show for warrior/rogue/hunter), /fbp smartcross (downranking across spells), /fbp healbonus (equipment bonus), /fbp debug, /fbp reset",
    FBP_SMART     = "Smart Healing: %s (safety margin %d %%)",

    DBG_HOT       = "HoT %s on %s: %d per tick, %ds",
    DBG_SHIELD    = "Shield %s on %s: %d absorb, %ds",
    DBG_CAST      = "Cast %s on %s: %d",
    DBG_TICK      = "Tick corrected: %s = %d",
    DBG_HEAL      = "Heal %s = %d (estimate now %d)",
    DBG_ABSORB    = "Absorb %d on %s (%d left)",
    DBG_SMART_HOT = "Smart Healing skipped: %s is a heal over time",
    FBP_SMART_CROSS = "· across spells: %s",
    SMART_CROSS_ON  = "Smart Healing may now switch spell within a heal chain (e.g. Greater Heal to Lesser Heal). |cFF00FF00On|r.",
    SMART_CROSS_OFF = "Smart Healing now stays within the assigned spell and only lowers its rank. |cFFFF0000Cross-spell off|r.",
    SMART_CROSS_NEEDS = "Note: Smart Healing itself is off, so this has no effect yet. Turn it on in the options or with the Smart Healing switch on the Buttons tab.",
    HIDEPARTY     = "Hide Blizzard party frames",
    HIDEPARTY_TIP = "Hides Blizzard's party frames while you are in a group, so only the Heal Box plates remain. Cannot be combined with 'Attach to party frames', because that mode docks the plates onto exactly those frames; whichever one is on greys the other out. Switching it off brings the frames back at once, and so does a class the addon does not load for.",
    POWERBAR      = "Show rage, energy, focus",
    POWERBAR_TIP  = "The thin bar under the health bar normally shows mana and stays hidden for everyone else. With this on, warriors, rogues and pets get their own resource in its usual colour: rage red, energy yellow, focus orange. Needs the mana bar to be on.",
    HEALBONUS_ON  = "Equipment bonus of +%d healing is now included in the prediction. |cFF00FF00On|r.",
    HEALBONUS_OFF = "Equipment bonus is no longer included, spell tooltips count as they are. |cFFFF0000Off|r.",
    HEALBONUS_NA  = "No API delivers a healing bonus. ClassicAPI (or anything else with GetSpellBonusHealing) enables this; without it the learned values from the combat log carry the gear anyway.",
    FBP_HEALBONUS = "Equipment: +%d healing, applied to unlearned ranks: %s",

    CLASS_BLOCKED = "not shown for %s: this addon is made for healing classes. Warriors, rogues and hunters have no heals, no heal prediction and nothing to gain from the mana ticker.",
    CLASS_BLOCKED_HINT = "Type /fbp forceload to show it anyway. The setting is kept for this character.",
    CLASS_FORCED  = "Display forced on for %s (/fbp forceload).",
    CLASS_FORCE_ON = "Display forced |cFF00FF00on|r for this class. Kept for this character.",
    CLASS_FORCE_OFF = "Display |cFFFF0000off|r again for this class. /fbp forceload brings it back.",
    CLASS_FORCE_NA = "Your class uses mana and heals, the display is on anyway. /fbp forceload is only for warriors, rogues and hunters.",
	SMARTCROSS      = "Smartcross",
    SMARTCROSS_TIP  = "Allows Smart Healing to switch spells within a heal chain (e.g. Greater Heal to Lesser Heal, Holy Light to Flash of Light, Healing Wave to Lesser Healing Wave). When off, Smart Healing only downranks within the assigned spell. Only active when Smart Healing is enabled.",	
};

FBLocale["deDE"] = {
    LANG_NAME     = "Deutsch",
    LANGUAGE      = "Sprache",

    LOADED        = "geladen|r. Minimap-Button oder /fbp config oeffnet die Optionen, /fbp zeigt den Stand der Heilvorhersage.",
    SUPERWOW      = " |cFF55FF55[SuperWoW erkannt]|r",
    CREDITS       = "|cFFAAAAAAOriginal von Dourd (Argent Dawn EU), Vanilla-Portierung und Erweiterung 09/2026 von Mquadrat|r",

    TT_NO_SPELL   = "|cFFFFFFFFKein Zauber\n|cFF00FF00Waehle in den Optionen einen Zauber aus.",
    TT_TARGET     = "Ziel",
    NOT_IN_GROUP  = " ist nicht in der Gruppe.",

    SELECT_SPELL  = "Zauber waehlen...",
    BUTTON        = "Button",
    TAB_BUTTONS   = "Buttons",
    TAB_GENERAL   = "Allgemein",
    COL_LEFT      = "Linksklick",
    COL_RIGHT     = "Rechtsklick",
    RIGHTCLICK    = "Rechtsklick-Zauber",
    RIGHTCLICK_TIP = "Gibt jedem Button einen zweiten Zauber per Rechtsklick (z. B. Blitzheilung links, Grosse Heilung rechts). Standardmaessig aus. Eingeschaltet erscheint oben eine zweite Spalte, und ein kleines Icon in der Ecke jedes Buttons zeigt den Rechtsklick-Zauber. Zauber mit rechter Maustaste oder gehaltener Shift-Taste ablegen, um diese Seite zu fuellen.",
    TT_RIGHT      = "Rechtsklick",
    TT_BUFF_UNKNOWN = "Restzeit unbekannt (nicht dein Cast)",
    DROP_SET      = "Button %d: |cFFFFFFFF%s|r (aus dem Zauberbuch gezogen)",
    DROP_SET_R    = "Button %d, Rechtsklick: |cFFFFFFFF%s|r (aus dem Zauberbuch gezogen)",
    DROP_UNKNOWN  = "Der gezogene Zauber liess sich nicht erkennen.",
    SMARTRANK     = "Smart Healing",
    SMARTRANK_TIP = "Wirkt automatisch den niedrigsten Zauberrang, der das fehlende Leben (abzgl. eingehender Heilung) plus Sicherheitsaufschlag deckt.\n\n"
        .. "|cFFFFD100Regeln:|r\n"
        .. "• Nur Direktheilung (HoTs und Schilde unberuehrt)\n"
        .. "• Laufender HoT zaehlt nicht als anfliegende Heilung\n"
        .. "• Unter 30 % Leben immer der belegte Rang\n"
        .. "• Nie mehr Heilung als der belegte Rang\n"
        .. "• Zauberwechsel in Ketten steuert 'Smartcross'\n"
        .. "• Entscheidungen im Chat via /fbp debug",
    SMART_MARGIN  = "Sicherheitsaufschlag: |cFFFFFFFF%s %%",
    BAR_BG        = "Balkenhintergrund: |cFFFFFFFF%s %%",
    BAR_BG_OFF    = "klar",
    BAR_BG_FULL   = "deckend",
    COOLDOWNS     = "Cooldowns auf den Buttons",
    COOLDOWNS_TIP = "Zeigt die Cooldown-Uhr auf jedem Button (Naturschnelligkeit, Innerer Fokus, Handauflegung, Schild-Cooldown). Auch der globale Cooldown laeuft als Uhr mit, nach jedem Zauber siehst du also die kurze Wartezeit ablaufen, statt dass die Symbole dunkel und wieder hell werden. Wer ihn nicht sehen will, setzt FBCD_SHOW_MIN im Code auf 2.",
    AGGRO         = "Angegriffenen markieren",
    AGGRO_TIP     = "Roter Rahmen auf der Plakette oder Zelle des Mitglieds, das dein feindliches Ziel gerade im Ziel hat. Fuenfmal je Sekunde geprueft.",
    BUFFICONS     = "Buff-Icons links am Balken",
    BUFFICONS_TIP = "Buffs mit Laufzeit, die auf deinen Buttons liegen (Seelenstaerke, Goettlicher Willen, Furchtzauberschutz, ...), erscheinen als kleine Icons aussen links neben der Plakette, solange sie wirken. Wie ein Minutenzeiger wird das Icon mit ablaufender Zeit im Uhrzeigersinn ab zwoelf Uhr schwarz-weiss: frisch ganz farbig, bei halber Zeit die rechte Haelfte grau, bei einem Viertel Rest drei Viertel grau. Exakt bei dir selbst, ab deinem eigenen Cast bei anderen; ein fremd gewirkter Buff bleibt ganz farbig (Zeit unbekannt). /fbp buffs zeigt, was verfolgt wird.",
    TIMERS        = "HoT- und Schild-Timer",
    TIMERS_TIP    = "Jeder Button zeigt die Restsekunden deines eigenen HoTs oder Schilds dieses Zaubers auf dieser Einheit: gruen fuer HoTs, blau fuer den Schild, rot fuer Geschwaechte Seele nach dem Schild. Buffs mit Laufzeit erscheinen stattdessen als Icons im Lebensbalken (siehe Buff-Icons).",
    DBG_SMARTRANK = "Abrangen: %s -> %s (fehlend %d, erwartet %d)",
    DROP_HINT     = "Zauber aus dem Zauberbuch auf einen Button ziehen. Rechte Maustaste oder Shift beim Ablegen fuellt die Rechtsklick-Seite.",
    STATE_DEAD    = "Tot",
    STATE_GHOST   = "Geist",
    STATE_OFFLINE = "Offline",
    PLATE_LEFT    = "Linksklick auf Plakette",
    PLATE_RIGHT   = "Rechtsklick auf Plakette",
    PLATE_TIP     = "Was ein Klick auf eine Namensplakette (Name oder Lebensbalken) tut. Shift + Linksklick ziehen verschiebt die Anzeige immer, egal was hier eingestellt ist.",
    ACT_TARGET    = "Anvisieren",
    ACT_MENU      = "Einheitenmenue",
    ACT_MOVE      = "Anzeige verschieben",
    ACT_NONE      = "Nichts",
    LOSICON       = "Sichtlinie",
    LOSICON_TIP   = "Zeigt ein Augen-Abzeichen am linken Rand einer Plakette, solange die Einheit ausserhalb deiner Sichtlinie ist. Mit dem Client-Mod UnitXP wird das live geprueft; ohne ihn merkt sich das Addon die Fehlermeldung 'nicht in Sichtlinie' nach einem Heilversuch fuer ein paar Sekunden und loescht sie, sobald ein Cast auf die Einheit startet oder eine Heilung ankommt.",
    DEBUFFICON    = "Debuff-Icon",
    DEBUFFICON_TIP = "Zeigt das Icon des ersten von deiner Klasse entfernbaren Debuffs neben dem Namen, mit Stackzahl. Der Lebensbalken nimmt zusaetzlich weiterhin die Debuff-Farbe an.",
    MENU_NO_SPELL = "|cFF999999Kein Zauber|r",
    RANK_DEFAULT  = "Standard",

    PANEL_SUB     = "Optionen fuer %s.\nUnten legst du fest, wie viele Buttons erscheinen\nund welcher Zauber auf welchem Button liegt.",
    SHOW_BUTTONS  = "|cFFFFFFFF%s|r Buttons anzeigen",
    SCALE         = "Skalierung: |cFFFFFFFF%s",
    SMALL         = "Klein",
    LARGE         = "Gross",

    BTN_SPACING   = "Button-Abstand: |cFFFFFFFF%s px",
    ROW_SPACING   = "Zeilen-Abstand: |cFFFFFFFF%s px",

    ATTACH        = "Standard-Gruppenfenster",
    ATTACH_TIP    = "Heftet die Heil-Buttons an Blizzards Standard-Gruppenfenster, statt eigene, frei platzierbare Namensplaketten zu verwenden.",
    COMM          = "HealComm-Sync",
    COMM_TIP      = "Sendet deine Heilungen im HealComm-Format an die Gruppe (Puppeteer, pfUI, Luna und Co. zeigen sie an) und uebernimmt umgekehrt die angekuendigten Heilungen anderer Heiler in die eigene Vorhersage.",
    MANABAR       = "Manabalken",
    MANABAR_TIP   = "Zeigt einen schmalen blauen Manabalken am unteren Rand des Lebensbalkens, nur bei Einheiten, die tatsaechlich Mana nutzen (kein Wut, Fokus oder Energie).",
    SHOWPETS      = "Begleiter anzeigen",
    SHOWPETS_TIP  = "Legt fuer jeden Begleiter in der Gruppe (Jaeger, Hexenmeister) eine eigene Plakette direkt unter seinem Besitzer an, mit denselben Heil-Buttons.",
    TESTMODE      = "Testmodus",
    TESTMODE_TIP  = "Fuellt die Anzeige mit Geisterspielern und -begleitern, damit du alles einrichten kannst, ohne in einer Gruppe zu sein. Die Geister zeigen Leben, Mana, einen Schild, eingehende Heilung und einen entfernbaren Debuff. Wird nicht gespeichert, nach dem Login immer aus.",
    TEST_ON       = "Testmodus |cFF00FF00an|r, Geisterspieler aktiv. Buttons casten nicht auf Geister.",
    TEST_OFF      = "Testmodus |cFFFF0000aus|r.",
    TEST_CLICK    = "Testmodus: kein Cast auf einen Geisterspieler.",
    CLASSCOLORS   = "Klassenfarben",
    CLASSCOLORS_TIP = "Faerbt den Namen auf jeder Plakette in der Klassenfarbe (wie Healium). Begleiter behalten ihren hellblauen Namen.",
    RANGEFADE     = "Reichweiten-Fading",
    RANGEFADE_TIP = "Blendet eine ganze Plakette samt Buttons auf halbe Deckkraft ab, wenn die Einheit ausserhalb der Reichweite deines ersten belegten Zaubers ist (ohne belegten Zauber: weiter als 28 Meter).",
    BUFFWATCH     = "Buff-Wache",
    BUFFWATCH_TIP = "Waehle einen deiner Buffs. Jede Plakette, deren Einheit diesen Buff nicht hat, bekommt einen orangen Rahmen. Die Gruppenversion zaehlt mit (Gebet der Seelenstaerke fuer Machtwort: Seelenstaerke, Gabe der Wildnis fuer Mal der Wildnis, Grosse Segen, ...).",
    BUFFWATCH_NONE = "keiner",
    BUFFWATCH_PETS = "Buff-Wache auch fuer Begleiter",
    BUFFWATCH_PETS_TIP = "Markiert auch Begleiter, denen der ueberwachte Buff fehlt. Standardmaessig aus, denn Pets bekommen selten Seelenstaerke oder Segen, ihre Plaketten waeren sonst meist orange.",
    MENU_NO_BUFF  = "|cFF999999Keine Buff-Wache|r",
    LANG_TIP      = "Stellt alle Texte des Addons um. Wirkt sofort, ein /reload ist nicht noetig.",

    ABOUT         = "%s %s |cFFAAAAAA(Original von Dourd, UI Overhauled)|r\n|cFFAAAAAAVanilla-Portierung und Erweiterung 09/2026 von Mquadrat|r",
    MM_TIP        = "Links: Optionen\nRechts halten: Button verschieben\nShift + Links: Anzeige ein/aus",

    FBP_WATCHED   = "Ausgelesene Zauber:",
    FBP_ACTIVE    = "Aktiv:",
    FBP_DIRECT    = "Direkt",
    FBP_SHIELD    = "Schild",
    FBP_LEARNED   = "gelernt",
    FBP_EVERY     = "alle",
    FBP_TICKSOF   = "Ticks a",
    FBP_CAST      = "Cast",
    FBP_ON        = "auf",
    FBP_OF        = "von",
    FBP_FOR       = "fuer",
    FBP_SYNC      = "HealComm-Sync:",
    FBP_STATE_ON  = "an",
    FBP_STATE_OFF = "aus",
    FBP_INCOMING  = "Fremdheilung",
    FBP_DEBUG     = "Debug:",
    FBP_RESET     = "Gelernte Werte verworfen.",
    FBP_COMMANDS  = "Befehle: /fbp config (Optionsfenster), /fbp test (Testmodus), /fbp buffs (Buff-Diagnose), /fbp forceload (Anzeige fuer Krieger/Schurke/Jaeger), /fbp smartcross (Abrangen ueber Zaubergrenzen), /fbp healbonus (Ausruestungsbonus), /fbp debug, /fbp reset",
    FBP_SMART     = "Smart Healing: %s (Sicherheitsaufschlag %d %%)",

    DBG_HOT       = "HoT %s auf %s: %d pro Tick, %ds",
    DBG_SHIELD    = "Schild %s auf %s: %d Absorb, %ds",
    DBG_CAST      = "Cast %s auf %s: %d",
    DBG_TICK      = "Tick korrigiert: %s = %d",
    DBG_HEAL      = "Heilung %s = %d (Schaetzung jetzt %d)",
    DBG_ABSORB    = "Absorb %d auf %s (Rest %d)",
    DBG_SMART_HOT = "Smart Healing uebersprungen: %s ist Heilung ueber Zeit",
    FBP_SMART_CROSS = "· ueber Zaubergrenzen: %s",
    SMART_CROSS_ON  = "Smart Healing darf den Zauber innerhalb einer Heilkette wechseln (z. B. Grosse Heilung zu Geringem Heilen). |cFF00FF00An|r.",
    SMART_CROSS_OFF = "Smart Healing bleibt beim belegten Zauber und senkt nur dessen Rang. |cFFFF0000Kettenwechsel aus|r.",
    SMART_CROSS_NEEDS = "Hinweis: Smart Healing selbst ist aus, das wirkt also noch nicht. Einschalten im Optionsfenster ueber den Schalter Smart Healing im Reiter Buttons.",
    HIDEPARTY     = "Blizzard-Gruppenfenster aus",
    HIDEPARTY_TIP = "Versteckt Blizzards Gruppenfenster, solange du in einer Gruppe bist, sodass nur die Plaketten der Heal Box uebrig bleiben. Nicht zusammen mit 'An Gruppenfenster anheften' nutzbar, weil dieser Modus die Plaketten genau an diese Frames haengt; was gerade an ist, graut das andere aus. Ausschalten holt die Frames sofort zurueck, ebenso eine Klasse, fuer die das Addon nicht laedt.",
    POWERBAR      = "Wut, Energie, Fokus zeigen",
    POWERBAR_TIP  = "Der schmale Streifen unter dem Lebensbalken zeigt normalerweise Mana und bleibt bei allen anderen leer. Eingeschaltet bekommen Krieger, Schurken und Begleiter ihre eigene Ressource in der gewohnten Farbe: Wut rot, Energie gelb, Fokus orange. Setzt den Manabalken voraus.",
    HEALBONUS_ON  = "Ausruestungsbonus von +%d Heilung wird jetzt eingerechnet. |cFF00FF00An|r.",
    HEALBONUS_OFF = "Ausruestungsbonus wird nicht mehr eingerechnet, es zaehlt der nackte Tooltip. |cFFFF0000Aus|r.",
    HEALBONUS_NA  = "Keine API liefert einen Heilbonus. Mit ClassicAPI (oder etwas anderem mit GetSpellBonusHealing) geht das; ohne sie tragen die gelernten Werte aus dem Combatlog die Ausruestung ohnehin mit.",
    FBP_HEALBONUS = "Ausruestung: +%d Heilung, auf ungelernte Raenge angewandt: %s",

    CLASS_BLOCKED = "wird fuer %s nicht angezeigt: Das Addon ist fuer Heilerklassen gemacht. Krieger, Schurken und Jaeger haben keine Heilzauber, keine Heilvorhersage und keinen Nutzen vom Mana-Ticker.",
    CLASS_BLOCKED_HINT = "Mit /fbp forceload trotzdem anzeigen. Die Einstellung bleibt fuer diesen Charakter gespeichert.",
    CLASS_FORCED  = "Anzeige fuer %s erzwungen (/fbp forceload).",
    CLASS_FORCE_ON = "Anzeige fuer diese Klasse |cFF00FF00eingeschaltet|r. Bleibt fuer diesen Charakter gespeichert.",
    CLASS_FORCE_OFF = "Anzeige fuer diese Klasse wieder |cFFFF0000aus|r. Mit /fbp forceload kommt sie zurueck.",
    CLASS_FORCE_NA = "Deine Klasse heilt und hat Mana, die Anzeige laeuft ohnehin. /fbp forceload ist nur fuer Krieger, Schurken und Jaeger.",
	SMARTCROSS      = "Smartcross",
    SMARTCROSS_TIP  = "Erlaubt Smart Healing, innerhalb einer Heilkette auch den Zauber zu wechseln (z. B. Grosse Heilung zu Geringem Heilen, Heiliges Licht zu Blitz des Lichts, Welle der Heilung zu Geringer Welle der Heilung). Deaktiviert bleibt Smart Healing beim belegten Zauber und senkt nur dessen Rang. Nur bei aktivem Smart Healing aktivierbar.",
};

FBL = nil;

-- Client-Sprache als Vorgabe
function FBDetectLocale()
    local loc = GetLocale and GetLocale();
    if (loc == "deDE") then return "deDE"; end
    if (loc == "esES" or loc == "esMX") then return "esES"; end
    if (loc == "frFR") then return "frFR"; end
    if (loc == "itIT") then return "itIT"; end
    return "enUS";
end

-- Textabfrage mit Rueckfall auf Englisch
function FBT(key)
    local t = FBL or FBLocale["enUS"];
    local s = t[key];
    if (s == nil) then s = FBLocale["enUS"][key]; end
    if (s == nil) then return key; end
    return s;
end

function FBSetLocale(code, apply)
    if (not code) or (not FBLocale[code]) then code = "enUS"; end
    FBL = FBLocale[code];
    if (HealBox) then HealBox.Locale = code; end
    if (apply) then FBHealBox_ApplyLocale(); end
end

FBLocale["esES"] = {
    LANG_NAME       = "Español",
    LANGUAGE        = "Idioma",
    LOADED          = "cargado|r. El botón del minimapa o /fbp config abre las opciones, /fbp muestra la predicción de curación.",
    SUPERWOW        = " |cFF55FF55[SuperWoW detectado]|r",
    CREDITS         = "|cFFAAAAAAOriginal de Dourd (Argent Dawn EU), portado a Vanilla y ampliado en 09/2026 por Mquadrat|r",
    TT_NO_SPELL     = "|cFFFFFFFFSin hechizo\n|cFF00FF00Elige un hechizo en la ventana de opciones.",
    TT_TARGET       = "Objetivo",
    NOT_IN_GROUP    = " no está en tu grupo.",
    SELECT_SPELL    = "Elegir hechizo...",
    BUTTON          = "Botón",
    TAB_BUTTONS     = "Botones",
    TAB_GENERAL     = "General",
    COL_LEFT        = "Clic izquierdo",
    COL_RIGHT       = "Clic derecho",
    RIGHTCLICK      = "Hechizo de clic derecho",
    RIGHTCLICK_TIP  = "Da a cada botón un segundo hechizo con el clic derecho (p. ej. Sanación relámpago a la izquierda, Sanación superior a la derecha). Desactivado por defecto. Al activarlo aparece una segunda columna arriba y un pequeño icono en la esquina de cada botón muestra el hechizo del clic derecho. Suelta un hechizo con el botón derecho o con Mayús pulsado para rellenar este lado.",
    TT_RIGHT        = "Clic derecho",
    TT_BUFF_UNKNOWN = "tiempo restante desconocido (no es tu lanzamiento)",
    DROP_SET        = "Botón %d: |cFFFFFFFF%s|r (arrastrado desde el libro de hechizos)",
    DROP_SET_R      = "Botón %d, clic derecho: |cFFFFFFFF%s|r (arrastrado desde el libro de hechizos)",
    DROP_UNKNOWN    = "No se pudo identificar el hechizo arrastrado.",
    SMARTRANK     = "Smart Healing",
    SMARTRANK_TIP = "Lanza automáticamente el rango más bajo que cubra la vida faltante (menos curaciones entrantes) más el margen de seguridad.\n\n"
        .. "|cFFFFD100Reglas:|r\n"
        .. "• Solo curaciones directas (HoTs y escudos intactos)\n"
        .. "• Un HoT activo no cuenta como curación entrante\n"
        .. "• Siempre el rango asignado bajo 30 % de vida\n"
        .. "• Nunca cura más que el rango asignado\n"
        .. "• Cambio de hechizo controlado por 'Smartcross'\n"
        .. "• Registro de decisiones con /fbp debug",
    SMART_MARGIN    = "Margen de seguridad: |cFFFFFFFF%s %%",
    BAR_BG          = "Fondo de la barra: |cFFFFFFFF%s %%",
    BAR_BG_OFF      = "nítido",
    BAR_BG_FULL     = "opaco",
    COOLDOWNS       = "Reutilización en botones",
    COOLDOWNS_TIP   = "Muestra el barrido de reutilización en cada botón (Rapidez de la naturaleza, Enfoque interno, Imposición de manos, reutilización del escudo). La reutilización global también se muestra como barrido, así ves correr la breve espera tras cada lanzamiento en lugar de que los iconos se oscurezcan y se aclaren. Para omitirla, pon FBCD_SHOW_MIN en 2 en el código.",
    AGGRO           = "Marcar al atacado",
    AGGRO_TIP       = "Borde rojo en la placa o celda del miembro al que tu objetivo hostil está apuntando. Se comprueba cinco veces por segundo.",
    BUFFICONS       = "Iconos de beneficios (izq.)",
    BUFFICONS_TIP   = "Los beneficios con duración que están en tus botones (Entereza, Espíritu divino, Custodia contra el miedo, ...) aparecen como pequeños iconos en el lado exterior izquierdo de la placa mientras están activos. Como una aguja de minutos, el icono se vuelve blanco y negro en el sentido de las agujas del reloj desde las doce a medida que se agota el tiempo: todo en color al principio, mitad derecha gris a mitad de tiempo, tres cuartos gris cuando queda un cuarto. Exacto en ti mismo, contado desde tu propio lanzamiento en los demás; un beneficio lanzado por otro se queda en color (tiempo desconocido). /fbp buffs muestra qué se sigue.",
    TIMERS          = "Temporizadores HoT y escudo",
    TIMERS_TIP      = "Cada botón muestra los segundos restantes de tu propio HoT o escudo de ese hechizo en esa unidad: verde para HoT, azul para el escudo, rojo para Alma debilitada tras el escudo. Los beneficios con duración se muestran como iconos en la barra de vida (ver Iconos de beneficios).",
    DBG_SMARTRANK   = "Reducción de rango: %s -> %s (faltan %d, esperado %d)",
    DROP_HINT       = "Arrastra hechizos del libro de hechizos a un botón. El botón derecho o Mayús al soltar rellena el lado del clic derecho.",
    STATE_DEAD      = "Muerto",
    STATE_GHOST     = "Fantasma",
    STATE_OFFLINE   = "Desconectado",
    PLATE_LEFT      = "Clic izquierdo en la placa",
    PLATE_RIGHT     = "Clic derecho en la placa",
    PLATE_TIP       = "Qué hace un clic en una placa de nombre (nombre o barra de vida). Mayús + arrastrar con el izquierdo siempre mueve la pantalla, sea cual sea el ajuste.",
    ACT_TARGET      = "Seleccionar",
    ACT_MENU        = "Menú de unidad",
    ACT_MOVE        = "Mover la pantalla",
    ACT_NONE        = "Nada",
    LOSICON         = "Línea de visión",
    LOSICON_TIP     = "Muestra un ojo en la esquina de la placa mientras la unidad está fuera de tu línea de visión. Con el mod de cliente UnitXP se comprueba en vivo; sin él, el addon recuerda un error de \"fuera de línea de visión\" durante unos segundos tras intentar curar a esa unidad y lo borra en cuanto empieza un lanzamiento sobre ella o llega una curación.",
    DEBUFFICON      = "Icono de perjuicio",
    DEBUFFICON_TIP  = "Muestra el icono del primer perjuicio que tu clase puede quitar junto al nombre, con su número de acumulaciones. La barra de vida sigue tomando además el color del perjuicio.",
    MENU_NO_SPELL   = "|cFF999999Sin hechizo|r",
    RANK_DEFAULT    = "Predeterminado",
    PANEL_SUB       = "Opciones de %s.\nElige cuántos botones mostrar\ny qué hechizo lanza cada botón.",
    SHOW_BUTTONS    = "Mostrar |cFFFFFFFF%s|r botones",
    SCALE           = "Escala del marco: |cFFFFFFFF%s",
    SMALL           = "Pequeño",
    LARGE           = "Grande",
    BTN_SPACING     = "Separación de botones: |cFFFFFFFF%s px",
    ROW_SPACING     = "Separación de filas: |cFFFFFFFF%s px",
    ATTACH          = "Marcos de grupo de Blizzard",
    ATTACH_TIP      = "Ancla los botones de curación a los marcos de grupo predeterminados de Blizzard en lugar de usar las placas móviles propias del addon.",
    COMM            = "Sincronización HealComm",
    COMM_TIP        = "Emite tus curaciones en el formato HealComm para que Puppeteer, pfUI, Luna y otros puedan mostrarlas, e incorpora a tu propia predicción las curaciones anunciadas por otros sanadores.",
    MANABAR         = "Barra de maná",
    MANABAR_TIP     = "Muestra una fina barra de maná azul en el borde inferior de la barra de vida, solo para unidades que usan maná (no ira, enfoque ni energía).",
    SHOWPETS        = "Mostrar mascotas",
    SHOWPETS_TIP    = "Añade una placa para cada mascota del grupo (cazador, brujo) justo debajo de su dueño, con los mismos botones de curación.",
    TESTMODE        = "Modo de prueba",
    TESTMODE_TIP    = "Rellena la pantalla con jugadores y mascotas fantasma para que puedas organizarlo todo sin estar en grupo. Los fantasmas muestran vida, maná, un escudo, curación entrante y un perjuicio disipable. No se guarda, siempre apagado al iniciar sesión.",
    TEST_ON         = "Modo de prueba |cFF00FF00activado|r, jugadores fantasma activos. Los botones no lanzan sobre fantasmas.",
    TEST_OFF        = "Modo de prueba |cFFFF0000desactivado|r.",
    TEST_CLICK      = "Modo de prueba: sin lanzamiento sobre un jugador fantasma.",
    CLASSCOLORS     = "Colores de clase",
    CLASSCOLORS_TIP = "Colorea el nombre de cada placa con el color de clase (estilo Healium). Las mascotas conservan su nombre azul claro.",
    RANGEFADE       = "Atenuación por distancia",
    RANGEFADE_TIP   = "Atenúa toda la placa, botones incluidos, a media transparencia cuando la unidad está fuera del alcance de tu primer hechizo asignado (o a más de 28 metros si no hay hechizo asignado).",
    BUFFWATCH       = "Vigilancia de beneficio",
    BUFFWATCH_TIP   = "Elige uno de tus beneficios. Cada placa cuya unidad carezca de ese beneficio recibe un borde naranja. La versión de grupo también cuenta (Rezo de entereza para Palabra de poder: entereza, Don de lo Salvaje para Marca de lo Salvaje, Bendiciones superiores, ...).",
    BUFFWATCH_NONE  = "ninguno",
    BUFFWATCH_PETS  = "Vigilancia de beneficio: mascotas",
    BUFFWATCH_PETS_TIP = "Marca también las mascotas a las que les falta el beneficio vigilado. Desactivado por defecto, porque las mascotas rara vez reciben Entereza o Bendiciones y sus placas estarían naranjas casi siempre.",
    MENU_NO_BUFF    = "|cFF999999Sin vigilancia de beneficio|r",
    LANG_TIP        = "Cambia todos los textos del addon. Surte efecto de inmediato, sin recargar.",
    ABOUT           = "%s %s |cFFAAAAAA(original de Dourd, UI Overhauled)|r\n|cFFAAAAAAPortado a Vanilla y ampliado en 09/2026 por Mquadrat|r",
    MM_TIP          = "Izquierdo: opciones\nMantener derecho: mover este botón\nMayús + izquierdo: mostrar/ocultar la pantalla",
    FBP_WATCHED     = "Hechizos leídos del libro de hechizos:",
    FBP_ACTIVE      = "Activos ahora:",
    FBP_DIRECT      = "directo",
    FBP_SHIELD      = "escudo",
    FBP_LEARNED     = "aprendido",
    FBP_EVERY       = "cada",
    FBP_TICKSOF     = "pulsos de",
    FBP_CAST        = "Lanzamiento",
    FBP_ON          = "sobre",
    FBP_OF          = "de",
    FBP_FOR         = "por",
    FBP_SYNC        = "Sincronización HealComm:",
    FBP_STATE_ON    = "activada",
    FBP_STATE_OFF   = "desactivada",
    FBP_INCOMING    = "Entrante",
    FBP_DEBUG       = "Depuración:",
    FBP_RESET       = "Valores aprendidos descartados.",
    FBP_COMMANDS    = "Comandos: /fbp config (ventana de opciones), /fbp test (modo de prueba), /fbp buffs (diagnóstico de beneficios), /fbp forceload (mostrar para guerrero/pícaro/cazador), /fbp smartcross (reducción entre hechizos), /fbp healbonus (bono de equipo), /fbp debug, /fbp reset",
    FBP_SMART       = "Smart Healing: %s (margen de seguridad %d %%)",
    DBG_HOT         = "HoT %s sobre %s: %d por pulso, %ds",
    DBG_SHIELD      = "Escudo %s sobre %s: %d absorción, %ds",
    DBG_CAST        = "Lanzamiento %s sobre %s: %d",
    DBG_TICK        = "Pulso corregido: %s = %d",
    DBG_HEAL        = "Curación %s = %d (estimación ahora %d)",
    DBG_ABSORB      = "Absorción %d en %s (quedan %d)",
    DBG_SMART_HOT   = "Smart Healing omitido: %s es curación con el tiempo",
    FBP_SMART_CROSS = "· entre hechizos: %s",
    SMART_CROSS_ON  = "Smart Healing puede cambiar de hechizo dentro de una cadena de curación (p. ej. Curar más y Curar menos). |cFF00FF00Activado|r.",
    SMART_CROSS_OFF = "Smart Healing se queda en el hechizo asignado y solo baja su rango. |cFFFF0000Cambio de hechizo desactivado|r.",
    SMART_CROSS_NEEDS = "Nota: Smart Healing está desactivado, así que esto aún no tiene efecto. Actívalo en la pestaña Botones.",
    HIDEPARTY       = "Ocultar marcos de grupo",
    HIDEPARTY_TIP   = "Oculta los marcos de grupo de Blizzard mientras estás en un grupo, dejando solo las placas de Heal Box. No se puede combinar con 'Anclar a los marcos de grupo', porque ese modo ancla las placas justo en esos marcos; el que esté activo desactiva el otro.",
    POWERBAR        = "Mostrar ira, energía, enfoque",
    POWERBAR_TIP    = "La barra fina bajo la salud muestra normalmente maná y queda vacía para los demás. Activada, guerreros, pícaros y mascotas muestran su recurso en su color habitual: ira roja, energía amarilla, enfoque naranja. Requiere la barra de maná.",
    HEALBONUS_ON    = "El bono de equipo de +%d de sanación ya se incluye en la predicción. |cFF00FF00Activado|r.",
    HEALBONUS_OFF   = "El bono de equipo ya no se incluye, cuenta el tooltip puro. |cFFFF0000Desactivado|r.",
    HEALBONUS_NA    = "Ninguna API ofrece un bono de sanación. ClassicAPI (u otra con GetSpellBonusHealing) lo habilita; sin ella, los valores aprendidos del registro de combate ya incluyen el equipo.",
    FBP_HEALBONUS   = "Equipo: +%d de sanación, aplicado a rangos no aprendidos: %s",

    CLASS_BLOCKED   = "no se muestra para %s: este addon está hecho para clases sanadoras. Guerreros, pícaros y cazadores no tienen curaciones, ni predicción de curación, ni provecho del marcador de maná.",
    CLASS_BLOCKED_HINT = "Escribe /fbp forceload para mostrarlo igualmente. El ajuste se guarda para este personaje.",
    CLASS_FORCED    = "Visualización forzada para %s (/fbp forceload).",
    CLASS_FORCE_ON  = "Visualización |cFF00FF00activada|r para esta clase. Se guarda para este personaje.",
    CLASS_FORCE_OFF = "Visualización de nuevo |cFFFF0000desactivada|r para esta clase. /fbp forceload la devuelve.",
    CLASS_FORCE_NA  = "Tu clase usa maná y cura, la visualización ya está activa. /fbp forceload es solo para guerreros, pícaros y cazadores.",
	SMARTCROSS      = "Smartcross",
    SMARTCROSS_TIP  = "Permite a Smart Healing cambiar de hechizo dentro de una cadena de curación (p. ej. Sanación superior a Sanación inferior). Solo disponible con Smart Healing activo.",
};

FBLocale["frFR"] = {
    LANG_NAME       = "Français",
    LANGUAGE        = "Langue",
    LOADED          = "chargé|r. Le bouton de la minicarte ou /fbp config ouvre les options, /fbp affiche la prédiction de soins.",
    SUPERWOW        = " |cFF55FF55[SuperWoW détecté]|r",
    CREDITS         = "|cFFAAAAAAOriginal de Dourd (Argent Dawn EU), porté sur Vanilla et étendu en 09/2026 par Mquadrat|r",
    TT_NO_SPELL     = "|cFFFFFFFFAucun sort\n|cFF00FF00Choisissez un sort dans la fenêtre des options.",
    TT_TARGET       = "Cible",
    NOT_IN_GROUP    = " n'est pas dans votre groupe.",
    SELECT_SPELL    = "Choisir un sort...",
    BUTTON          = "Bouton",
    TAB_BUTTONS     = "Boutons",
    TAB_GENERAL     = "Général",
    COL_LEFT        = "Clic gauche",
    COL_RIGHT       = "Clic droit",
    RIGHTCLICK      = "Sort du clic droit",
    RIGHTCLICK_TIP  = "Donne à chaque bouton un second sort au clic droit (p. ex. Soins rapides à gauche, Soins supérieurs à droite). Désactivé par défaut. Une fois activé, une seconde colonne apparaît au-dessus et une petite icône dans le coin de chaque bouton montre le sort du clic droit. Déposez un sort avec le bouton droit ou en maintenant Maj pour remplir ce côté.",
    TT_RIGHT        = "Clic droit",
    TT_BUFF_UNKNOWN = "temps restant inconnu (pas votre lancement)",
    DROP_SET        = "Bouton %d : |cFFFFFFFF%s|r (glissé depuis le grimoire)",
    DROP_SET_R      = "Bouton %d, clic droit : |cFFFFFFFF%s|r (glissé depuis le grimoire)",
    DROP_UNKNOWN    = "Impossible d'identifier le sort glissé.",
    SMARTRANK     = "Smart Healing",
    SMARTRANK_TIP = "Lance automatiquement le rang le plus bas couvrant la vie manquante (moins soins en cours) plus la marge de sécurité.\n\n"
        .. "|cFFFFD100Règles :|r\n"
        .. "• Soins directs uniquement (HoTs et boucliers intacts)\n"
        .. "• Un HoT actif ne compte pas comme soin en cours\n"
        .. "• Rang assigné conservé sous 30 % de vie\n"
        .. "• Ne soigne jamais plus que le rang assigné\n"
        .. "• Changement de sort contrôlé par 'Smartcross'\n"
        .. "• Décisions visibles via /fbp debug",
    SMART_MARGIN    = "Marge de sécurité : |cFFFFFFFF%s %%",
    BAR_BG          = "Fond de la barre : |cFFFFFFFF%s %%",
    BAR_BG_OFF      = "clair",
    BAR_BG_FULL     = "opaque",
    COOLDOWNS       = "Recharges sur les boutons",
    COOLDOWNS_TIP   = "Affiche le balayage du temps de recharge sur chaque bouton (Rapidité de la nature, Focalisation intérieure, Imposition des mains, recharge du bouclier). Le temps de recharge global est affiché lui aussi : après chaque incantation vous voyez la courte attente s'écouler au lieu de voir les icônes s'assombrir puis redevenir claires. Pour l'exclure, mettez FBCD_SHOW_MIN à 2 dans le code.",
    AGGRO           = "Marquer la cible attaquée",
    AGGRO_TIP       = "Bordure rouge sur la plaque ou la cellule du membre que votre cible hostile vise actuellement. Vérifié cinq fois par seconde.",
    BUFFICONS       = "Icônes de buffs (gauche)",
    BUFFICONS_TIP   = "Les buffs à durée présents sur vos boutons (Robustesse, Esprit divin, Gardien de peur, ...) apparaissent sous forme de petites icônes sur le côté extérieur gauche de la plaque tant qu'ils sont actifs. Comme une aiguille des minutes, l'icône passe en noir et blanc dans le sens horaire à partir de midi au fur et à mesure que le temps s'écoule : entièrement en couleur au début, moitié droite grise à mi-temps, trois quarts gris quand il reste un quart. Exact sur vous-même, compté depuis votre propre lancement sur les autres ; un buff lancé par quelqu'un d'autre reste en couleur (temps inconnu). /fbp buffs montre ce qui est suivi.",
    TIMERS          = "Minuteurs HoT et bouclier",
    TIMERS_TIP      = "Chaque bouton affiche les secondes restantes de votre propre HoT ou bouclier de ce sort sur cette unité : vert pour les HoT, bleu pour le bouclier, rouge pour Âme affaiblie après le bouclier. Les buffs à durée sont affichés sous forme d'icônes dans la barre de vie (voir Icônes de buffs).",
    DBG_SMARTRANK   = "Rang abaissé : %s -> %s (manque %d, attendu %d)",
    DROP_HINT       = "Glissez des sorts du grimoire sur un bouton. Le bouton droit ou Maj au dépôt remplit le côté du clic droit.",
    STATE_DEAD      = "Mort",
    STATE_GHOST     = "Fantôme",
    STATE_OFFLINE   = "Hors ligne",
    PLATE_LEFT      = "Clic gauche sur la plaque",
    PLATE_RIGHT     = "Clic droit sur la plaque",
    PLATE_TIP       = "Ce que fait un clic sur une plaque (nom ou barre de vie). Maj + glisser avec le bouton gauche déplace toujours l'affichage, quel que soit le réglage.",
    ACT_TARGET      = "Cibler",
    ACT_MENU        = "Menu d'unité",
    ACT_MOVE        = "Déplacer l'affichage",
    ACT_NONE        = "Rien",
    LOSICON         = "Ligne de vue",
    LOSICON_TIP     = "Affiche un œil dans le coin de la plaque tant que l'unité est hors de votre ligne de vue. Avec le mod client UnitXP, c'est vérifié en direct ; sans lui, l'addon mémorise une erreur « hors de la ligne de vue » pendant quelques secondes après une tentative de soin sur cette unité et l'efface dès qu'un lancement sur elle commence ou qu'un soin arrive.",
    DEBUFFICON      = "Icône de debuff",
    DEBUFFICON_TIP  = "Affiche l'icône du premier debuff que votre classe peut dissiper à côté du nom, avec son nombre de charges. La barre de vie prend aussi la couleur du debuff.",
    MENU_NO_SPELL   = "|cFF999999Aucun sort|r",
    RANK_DEFAULT    = "Par défaut",
    PANEL_SUB       = "Options de %s.\nChoisissez combien de boutons afficher\net quel sort chaque bouton lance.",
    SHOW_BUTTONS    = "Afficher |cFFFFFFFF%s|r boutons",
    SCALE           = "Échelle du cadre : |cFFFFFFFF%s",
    SMALL           = "Petit",
    LARGE           = "Grand",
    BTN_SPACING     = "Espacement des boutons : |cFFFFFFFF%s px",
    ROW_SPACING     = "Espacement des lignes : |cFFFFFFFF%s px",
    ATTACH          = "Cadres de groupe Blizzard",
    ATTACH_TIP      = "Attache les boutons de soins aux cadres de groupe par défaut de Blizzard au lieu d'utiliser les plaques déplaçables de l'addon.",
    COMM            = "Synchronisation HealComm",
    COMM_TIP        = "Diffuse vos soins au format HealComm pour que Puppeteer, pfUI, Luna et d'autres puissent les afficher, et intègre à votre propre prédiction les soins annoncés par les autres soigneurs.",
    MANABAR         = "Barre de mana",
    MANABAR_TIP     = "Affiche une fine barre de mana bleue le long du bord inférieur de la barre de vie, uniquement pour les unités qui utilisent du mana (ni rage, ni focalisation, ni énergie).",
    SHOWPETS        = "Afficher les familiers",
    SHOWPETS_TIP    = "Ajoute une plaque pour chaque familier du groupe (chasseur, démoniste) juste sous son maître, avec les mêmes boutons de soins.",
    TESTMODE        = "Mode test",
    TESTMODE_TIP    = "Remplit l'affichage de joueurs et de familiers fantômes pour tout organiser sans être en groupe. Les fantômes montrent la vie, le mana, un bouclier, des soins entrants et un debuff dissipable. Non sauvegardé, toujours désactivé à la connexion.",
    TEST_ON         = "Mode test |cFF00FF00activé|r, joueurs fantômes actifs. Les boutons ne lancent rien sur les fantômes.",
    TEST_OFF        = "Mode test |cFFFF0000désactivé|r.",
    TEST_CLICK      = "Mode test : aucun lancement sur un joueur fantôme.",
    CLASSCOLORS     = "Couleurs de classe",
    CLASSCOLORS_TIP = "Colore le nom de chaque plaque avec la couleur de classe (style Healium). Les familiers gardent leur nom bleu clair.",
    RANGEFADE       = "Estompage hors portée",
    RANGEFADE_TIP   = "Rend toute la plaque, boutons compris, à moitié transparente quand l'unité est hors de portée de votre premier sort assigné (ou au-delà de 28 mètres si aucun sort n'est assigné).",
    BUFFWATCH       = "Surveillance de buff",
    BUFFWATCH_TIP   = "Choisissez l'un de vos buffs. Chaque plaque dont l'unité n'a pas ce buff reçoit une bordure orange. La version de groupe compte aussi (Prière de robustesse pour Mot de pouvoir : Robustesse, Don de la nature pour Marque du fauve, Bénédictions supérieures, ...).",
    BUFFWATCH_NONE  = "aucune",
    BUFFWATCH_PETS  = "Surveillance de buff : familiers",
    BUFFWATCH_PETS_TIP = "Marque aussi les familiers auxquels le buff surveillé manque. Désactivé par défaut, car les familiers reçoivent rarement Robustesse ou des Bénédictions et leurs plaques resteraient orange la plupart du temps.",
    MENU_NO_BUFF    = "|cFF999999Aucune surveillance de buff|r",
    LANG_TIP        = "Change tous les textes de l'addon. Effet immédiat, sans rechargement.",
    ABOUT           = "%s %s |cFFAAAAAA(original de Dourd, UI Overhauled)|r\n|cFFAAAAAAPorté sur Vanilla et étendu en 09/2026 par Mquadrat|r",
    MM_TIP          = "Gauche : options\nMaintenir droit : déplacer ce bouton\nMaj + gauche : afficher/masquer l'affichage",
    FBP_WATCHED     = "Sorts lus dans le grimoire :",
    FBP_ACTIVE      = "Actifs en ce moment :",
    FBP_DIRECT      = "direct",
    FBP_SHIELD      = "bouclier",
    FBP_LEARNED     = "appris",
    FBP_EVERY       = "toutes les",
    FBP_TICKSOF     = "ticks de",
    FBP_CAST        = "Lancement",
    FBP_ON          = "sur",
    FBP_OF          = "sur",
    FBP_FOR         = "pour",
    FBP_SYNC        = "Synchronisation HealComm :",
    FBP_STATE_ON    = "activée",
    FBP_STATE_OFF   = "désactivée",
    FBP_INCOMING    = "Entrant",
    FBP_DEBUG       = "Débogage :",
    FBP_RESET       = "Valeurs apprises effacées.",
    FBP_COMMANDS    = "Commandes : /fbp config (fenêtre des options), /fbp test (mode test), /fbp buffs (diagnostic des buffs), /fbp forceload (afficher pour guerrier/voleur/chasseur), /fbp smartcross (rang abaissé entre sorts), /fbp healbonus (bonus d'équipement), /fbp debug, /fbp reset",
    FBP_SMART       = "Smart Healing : %s (marge de sécurité %d %%)",
    DBG_HOT         = "HoT %s sur %s : %d par tick, %ds",
    DBG_SHIELD      = "Bouclier %s sur %s : %d absorption, %ds",
    DBG_CAST        = "Lancement %s sur %s : %d",
    DBG_TICK        = "Tick corrigé : %s = %d",
    DBG_HEAL        = "Soin %s = %d (estimation maintenant %d)",
    DBG_ABSORB      = "Absorption %d sur %s (reste %d)",
    DBG_SMART_HOT   = "Smart Healing ignoré : %s est un soin sur la durée",
    FBP_SMART_CROSS = "· entre sorts : %s",
    SMART_CROSS_ON  = "Smart Healing peut changer de sort dans une chaîne de soins (p. ex. Soins supérieurs vers Soins inférieurs). |cFF00FF00Activé|r.",
    SMART_CROSS_OFF = "Smart Healing reste sur le sort assigné et n'abaisse que son rang. |cFFFF0000Changement de sort désactivé|r.",
    SMART_CROSS_NEEDS = "Note : Smart Healing lui-même est désactivé, ceci n'a donc pas encore d'effet. Activez-le dans l'onglet Boutons.",
    HIDEPARTY       = "Masquer les cadres de groupe",
    HIDEPARTY_TIP   = "Masque les cadres de groupe de Blizzard tant que vous êtes en groupe, il ne reste que les plaques de Heal Box. Incompatible avec 'Ancrer aux cadres de groupe', car ce mode ancre les plaques précisément sur ces cadres ; celui qui est actif grise l'autre.",
    POWERBAR        = "Afficher rage, énergie, focus",
    POWERBAR_TIP    = "La fine barre sous la santé montre normalement le mana et reste vide pour les autres. Activée, les guerriers, voleurs et familiers affichent leur ressource dans sa couleur habituelle : rage rouge, énergie jaune, focus orange. Nécessite la barre de mana.",
    HEALBONUS_ON    = "Le bonus d'équipement de +%d soins est désormais pris en compte. |cFF00FF00Activé|r.",
    HEALBONUS_OFF   = "Le bonus d'équipement n'est plus pris en compte, seul l'infobulle compte. |cFFFF0000Désactivé|r.",
    HEALBONUS_NA    = "Aucune API ne fournit de bonus aux soins. ClassicAPI (ou autre avec GetSpellBonusHealing) l'active ; sans elle, les valeurs apprises du journal de combat portent déjà l'équipement.",
    FBP_HEALBONUS   = "Équipement : +%d soins, appliqué aux rangs non appris : %s",

    CLASS_BLOCKED   = "non affiché pour %s : cet addon est fait pour les classes soigneuses. Les guerriers, voleurs et chasseurs n'ont pas de soins, pas de prévision de soins et aucun usage du compteur de mana.",
    CLASS_BLOCKED_HINT = "Tapez /fbp forceload pour l'afficher quand même. Le réglage est conservé pour ce personnage.",
    CLASS_FORCED    = "Affichage forcé pour %s (/fbp forceload).",
    CLASS_FORCE_ON  = "Affichage |cFF00FF00activé|r pour cette classe. Conservé pour ce personnage.",
    CLASS_FORCE_OFF = "Affichage de nouveau |cFFFF0000désactivé|r pour cette classe. /fbp forceload le ramène.",
    CLASS_FORCE_NA  = "Votre classe utilise le mana et soigne, l'affichage est déjà actif. /fbp forceload ne sert qu'aux guerriers, voleurs et chasseurs.",
	SMARTCROSS      = "Smartcross",
    SMARTCROSS_TIP  = "Permet à Smart Healing de changer de sort dans une chaîne de soins (p. ex. Soins supérieurs vers Soins inférieurs). Disponible uniquement quand Smart Healing est activé.",
};

FBLocale["itIT"] = {
    LANG_NAME       = "Italiano",
    LANGUAGE        = "Lingua",
    LOADED          = "caricato|r. Il pulsante della minimappa o /fbp config apre le opzioni, /fbp mostra la previsione delle cure.",
    SUPERWOW        = " |cFF55FF55[SuperWoW rilevato]|r",
    CREDITS         = "|cFFAAAAAAOriginale di Dourd (Argent Dawn EU), portato su Vanilla ed esteso nel 09/2026 da Mquadrat|r",
    TT_NO_SPELL     = "|cFFFFFFFFNessun incantesimo\n|cFF00FF00Scegli un incantesimo nella finestra delle opzioni.",
    TT_TARGET       = "Bersaglio",
    NOT_IN_GROUP    = " non è nel tuo gruppo.",
    SELECT_SPELL    = "Scegli incantesimo...",
    BUTTON          = "Pulsante",
    TAB_BUTTONS     = "Pulsanti",
    TAB_GENERAL     = "Generale",
    COL_LEFT        = "Clic sinistro",
    COL_RIGHT       = "Clic destro",
    RIGHTCLICK      = "Incantesimo del clic destro",
    RIGHTCLICK_TIP  = "Dà a ogni pulsante un secondo incantesimo con il clic destro (per es. Cura Rapida a sinistra, Cura Superiore a destra). Disattivato per impostazione predefinita. Quando è attivo compare una seconda colonna in alto e una piccola icona nell'angolo di ogni pulsante mostra l'incantesimo del clic destro. Rilascia un incantesimo con il tasto destro o tenendo premuto Maiusc per riempire questo lato.",
    TT_RIGHT        = "Clic destro",
    TT_BUFF_UNKNOWN = "tempo rimanente sconosciuto (non è un tuo lancio)",
    DROP_SET        = "Pulsante %d: |cFFFFFFFF%s|r (trascinato dal libro degli incantesimi)",
    DROP_SET_R      = "Pulsante %d, clic destro: |cFFFFFFFF%s|r (trascinato dal libro degli incantesimi)",
    DROP_UNKNOWN    = "Impossibile identificare l'incantesimo trascinato.",
    SMARTRANK     = "Smart Healing",
    SMARTRANK_TIP = "Lancia automaticamente il rango più basso la cui cura copre la salute mancante (meno cure in arrivo) più il margine di sicurezza.\n\n"
        .. "|cFFFFD100Regole:|r\n"
        .. "• Solo cure dirette (HoT e scudi non modificati)\n"
        .. "• Un HoT attivo non conta come cura in arrivo\n"
        .. "• Sotto il 30 % di salute lancia sempre il rango assegnato\n"
        .. "• Mai una cura superiore al rango assegnato\n"
        .. "• Cambio incantesimo controllato da 'Smartcross'\n"
        .. "• Decisioni registrate con /fbp debug",
    SMART_MARGIN    = "Margine di sicurezza: |cFFFFFFFF%s %%",
    BAR_BG          = "Sfondo della barra: |cFFFFFFFF%s %%",
    BAR_BG_OFF      = "limpido",
    BAR_BG_FULL     = "opaco",
    COOLDOWNS       = "Recuperi sui pulsanti",
    COOLDOWNS_TIP   = "Mostra l'animazione del tempo di recupero su ogni pulsante (Rapidità della Natura, Concentrazione Interiore, Imposizione delle Mani, recupero dello scudo). Anche il tempo di recupero globale scorre come animazione: dopo ogni lancio vedi scorrere la breve attesa invece di icone che si scuriscono e si riaccendono. Per escluderlo, imposta FBCD_SHOW_MIN a 2 nel codice.",
    AGGRO           = "Segnala chi è attaccato",
    AGGRO_TIP       = "Bordo rosso sulla targhetta o sulla cella del membro che il tuo bersaglio ostile sta puntando. Controllato cinque volte al secondo.",
    BUFFICONS       = "Icone benefici (sinistra)",
    BUFFICONS_TIP   = "I benefici con durata presenti sui tuoi pulsanti (Tempra, Spirito Divino, Protezione dalla Paura, ...) compaiono come piccole icone sul lato esterno sinistro della targhetta finché sono attivi. Come una lancetta dei minuti, l'icona diventa in bianco e nero in senso orario a partire dalle dodici man mano che il tempo scorre: tutta a colori all'inizio, metà destra grigia a metà tempo, tre quarti grigi quando ne resta un quarto. Esatta su te stesso, contata dal tuo lancio sugli altri; un beneficio lanciato da altri resta a colori (tempo sconosciuto). /fbp buffs mostra cosa viene seguito.",
    TIMERS          = "Timer HoT e scudo",
    TIMERS_TIP      = "Ogni pulsante mostra i secondi rimanenti del tuo HoT o scudo di quell'incantesimo su quell'unità: verde per gli HoT, blu per lo scudo, rosso per Anima Indebolita dopo lo scudo. I benefici con durata vengono mostrati come icone nella barra della salute (vedi Icone dei benefici).",
    DBG_SMARTRANK   = "Rango ridotto: %s -> %s (mancano %d, previsti %d)",
    DROP_HINT       = "Trascina gli incantesimi dal libro su un pulsante. Il tasto destro o Maiusc al rilascio riempie il lato del clic destro.",
    STATE_DEAD      = "Morto",
    STATE_GHOST     = "Fantasma",
    STATE_OFFLINE   = "Offline",
    PLATE_LEFT      = "Clic sinistro sulla targhetta",
    PLATE_RIGHT     = "Clic destro sulla targhetta",
    PLATE_TIP       = "Cosa fa un clic su una targhetta (nome o barra della salute). Maiusc + trascinamento con il sinistro sposta sempre la visualizzazione, qualunque sia l'impostazione.",
    ACT_TARGET      = "Seleziona",
    ACT_MENU        = "Menu unità",
    ACT_MOVE        = "Sposta la visualizzazione",
    ACT_NONE        = "Niente",
    LOSICON         = "Linea di vista",
    LOSICON_TIP     = "Mostra un occhio nell'angolo della targhetta finché l'unità è fuori dalla tua linea di vista. Con il mod client UnitXP il controllo è in tempo reale; senza, l'addon ricorda un errore di \"fuori linea di vista\" per qualche secondo dopo un tentativo di cura su quell'unità e lo cancella non appena inizia un lancio su di essa o arriva una cura.",
    DEBUFFICON      = "Icona del malus",
    DEBUFFICON_TIP  = "Mostra l'icona del primo malus che la tua classe può rimuovere accanto al nome, con il numero di accumuli. La barra della salute continua anche a prendere il colore del malus.",
    MENU_NO_SPELL   = "|cFF999999Nessun incantesimo|r",
    RANK_DEFAULT    = "Predefinito",
    PANEL_SUB       = "Opzioni di %s.\nScegli quanti pulsanti mostrare\ne quale incantesimo lancia ogni pulsante.",
    SHOW_BUTTONS    = "Mostra |cFFFFFFFF%s|r pulsanti",
    SCALE           = "Scala della cornice: |cFFFFFFFF%s",
    SMALL           = "Piccola",
    LARGE           = "Grande",
    BTN_SPACING     = "Spaziatura pulsanti: |cFFFFFFFF%s px",
    ROW_SPACING     = "Spaziatura righe: |cFFFFFFFF%s px",
    ATTACH          = "Cornici di gruppo Blizzard",
    ATTACH_TIP      = "Aggancia i pulsanti di cura alle cornici di gruppo predefinite di Blizzard invece di usare le targhette mobili dell'addon.",
    COMM            = "Sincronizzazione HealComm",
    COMM_TIP        = "Trasmette le tue cure nel formato HealComm perché Puppeteer, pfUI, Luna e altri possano mostrarle, e integra nella tua previsione le cure annunciate dagli altri guaritori.",
    MANABAR         = "Barra del mana",
    MANABAR_TIP     = "Mostra una sottile barra blu del mana lungo il bordo inferiore della barra della salute, solo per le unità che usano mana (niente ira, concentrazione o energia).",
    SHOWPETS        = "Mostra famigli",
    SHOWPETS_TIP    = "Aggiunge una targhetta per ogni famiglio del gruppo (cacciatore, stregone) subito sotto il suo padrone, con gli stessi pulsanti di cura.",
    TESTMODE        = "Modalità test",
    TESTMODE_TIP    = "Riempie la visualizzazione con giocatori e famigli fantasma per sistemare tutto senza essere in gruppo. I fantasmi mostrano salute, mana, uno scudo, cure in arrivo e un malus dissolvibile. Non viene salvata, sempre disattivata all'accesso.",
    TEST_ON         = "Modalità test |cFF00FF00attiva|r, giocatori fantasma attivi. I pulsanti non lanciano sui fantasmi.",
    TEST_OFF        = "Modalità test |cFFFF0000disattivata|r.",
    TEST_CLICK      = "Modalità test: nessun lancio su un giocatore fantasma.",
    CLASSCOLORS     = "Colori di classe",
    CLASSCOLORS_TIP = "Colora il nome di ogni targhetta con il colore di classe (stile Healium). I famigli mantengono il nome azzurro.",
    RANGEFADE       = "Dissolvenza fuori portata",
    RANGEFADE_TIP   = "Rende l'intera targhetta, pulsanti compresi, semitrasparente quando l'unità è fuori portata del tuo primo incantesimo assegnato (o oltre 28 metri se nessun incantesimo è assegnato).",
    BUFFWATCH       = "Controllo beneficio",
    BUFFWATCH_TIP   = "Scegli uno dei tuoi benefici. Ogni targhetta la cui unità non ha quel beneficio riceve un bordo arancione. Conta anche la versione di gruppo (Preghiera della Tempra per Parola del Potere: Tempra, Dono della Natura per Marchio della Natura, Benedizioni Superiori, ...).",
    BUFFWATCH_NONE  = "nessuno",
    BUFFWATCH_PETS  = "Controllo beneficio: famigli",
    BUFFWATCH_PETS_TIP = "Segnala anche i famigli a cui manca il beneficio controllato. Disattivato per impostazione predefinita, perché i famigli ricevono raramente Tempra o Benedizioni e le loro targhette resterebbero arancioni quasi sempre.",
    MENU_NO_BUFF    = "|cFF999999Nessun controllo beneficio|r",
    LANG_TIP        = "Cambia tutti i testi dell'addon. Effetto immediato, senza ricaricare.",
    ABOUT           = "%s %s |cFFAAAAAA(originale di Dourd, UI Overhauled)|r\n|cFFAAAAAAPortato su Vanilla ed esteso nel 09/2026 da Mquadrat|r",
    MM_TIP          = "Sinistro: opzioni\nTieni premuto il destro: sposta questo pulsante\nMaiusc + sinistro: mostra/nascondi la visualizzazione",
    FBP_WATCHED     = "Incantesimi letti dal libro:",
    FBP_ACTIVE      = "Attivi ora:",
    FBP_DIRECT      = "diretta",
    FBP_SHIELD      = "scudo",
    FBP_LEARNED     = "appreso",
    FBP_EVERY       = "ogni",
    FBP_TICKSOF     = "tick da",
    FBP_CAST        = "Lancio",
    FBP_ON          = "su",
    FBP_OF          = "di",
    FBP_FOR         = "per",
    FBP_SYNC        = "Sincronizzazione HealComm:",
    FBP_STATE_ON    = "attiva",
    FBP_STATE_OFF   = "disattivata",
    FBP_INCOMING    = "In arrivo",
    FBP_DEBUG       = "Debug:",
    FBP_RESET       = "Valori appresi scartati.",
    FBP_COMMANDS    = "Comandi: /fbp config (finestra opzioni), /fbp test (modalità test), /fbp buffs (diagnostica benefici), /fbp forceload (mostra per guerriero/ladro/cacciatore), /fbp smartcross (riduzione tra incantesimi), /fbp healbonus (bonus equipaggiamento), /fbp debug, /fbp reset",
    FBP_SMART       = "Smart Healing: %s (margine di sicurezza %d %%)",
    DBG_HOT         = "HoT %s su %s: %d per tick, %ds",
    DBG_SHIELD      = "Scudo %s su %s: %d assorbimento, %ds",
    DBG_CAST        = "Lancio %s su %s: %d",
    DBG_TICK        = "Tick corretto: %s = %d",
    DBG_HEAL        = "Cura %s = %d (stima ora %d)",
    DBG_ABSORB      = "Assorbimento %d su %s (restano %d)",
    DBG_SMART_HOT   = "Smart Healing saltato: %s è una cura nel tempo",
    FBP_SMART_CROSS = "· tra incantesimi: %s",
    SMART_CROSS_ON  = "Smart Healing può cambiare incantesimo all'interno di una catena di cure (p. es. da Cura Superiore a Cura Inferiore). |cFF00FF00Attivo|r.",
    SMART_CROSS_OFF = "Smart Healing resta sull'incantesimo assegnato e ne abbassa solo il rango. |cFFFF0000Cambio incantesimo disattivato|r.",
    SMART_CROSS_NEEDS = "Nota: Smart Healing stesso è disattivato, quindi questo non ha ancora effetto. Attivalo nella scheda Pulsanti.",
    HIDEPARTY       = "Nascondi i riquadri gruppo",
    HIDEPARTY_TIP   = "Nasconde i riquadri del gruppo di Blizzard finché sei in gruppo, restano solo le targhette di Heal Box. Non combinabile con 'Aggancia ai riquadri gruppo', perché quella modalità aggancia le targhette proprio a quei riquadri; quella attiva disattiva l'altra.",
    POWERBAR        = "Mostra ira, energia, focus",
    POWERBAR_TIP    = "La barra sottile sotto la salute mostra di norma il mana e resta vuota per gli altri. Attiva, guerrieri, ladri e famigli mostrano la loro risorsa nel colore consueto: ira rossa, energia gialla, focus arancione. Richiede la barra del mana.",
    HEALBONUS_ON    = "Il bonus dell'equipaggiamento di +%d cura viene ora incluso. |cFF00FF00Attivo|r.",
    HEALBONUS_OFF   = "Il bonus dell'equipaggiamento non viene più incluso, conta il tooltip nudo. |cFFFF0000Disattivo|r.",
    HEALBONUS_NA    = "Nessuna API fornisce un bonus alle cure. ClassicAPI (o altro con GetSpellBonusHealing) lo abilita; senza, i valori appresi dal registro di combattimento includono già l'equipaggiamento.",
    FBP_HEALBONUS   = "Equipaggiamento: +%d cura, applicato ai ranghi non appresi: %s",

    CLASS_BLOCKED   = "non mostrato per %s: questo addon è pensato per le classi curatrici. Guerrieri, ladri e cacciatori non hanno cure, né previsione delle cure, né vantaggi dal contatore del mana.",
    CLASS_BLOCKED_HINT = "Scrivi /fbp forceload per mostrarlo comunque. L'impostazione resta salvata per questo personaggio.",
    CLASS_FORCED    = "Visualizzazione forzata per %s (/fbp forceload).",
    CLASS_FORCE_ON  = "Visualizzazione |cFF00FF00attivata|r per questa classe. Resta salvata per questo personaggio.",
    CLASS_FORCE_OFF = "Visualizzazione di nuovo |cFFFF0000disattivata|r per questa classe. /fbp forceload la riporta.",
    CLASS_FORCE_NA  = "La tua classe usa il mana e cura, la visualizzazione è già attiva. /fbp forceload serve solo a guerrieri, ladri e cacciatori.",
	SMARTCROSS      = "Smartcross",
    SMARTCROSS_TIP  = "Permette a Smart Healing di cambiare incantesimo all'interno di una catena di cure (p. es. da Cura Superiore a Cura Inferiore). Disponibile solo con Smart Healing attivo.",
};

FBL = FBLocale[FBDetectLocale()];

-- ==========================================================================
-- [ Hooks fuer Module ]
--
-- Module (z. B. FBHealBox_Raid.lua) haengen sich hier ein, statt den
-- Kern zu aendern. Aufrufpunkte: Defaults, SyncOptions, ApplyLocale,
-- UpdateNames, RefreshAllBars, ButtonsChanged, ActiveToggle, Status, Loaded
-- und Slash (Slash-Hooks geben true zurueck, wenn sie den Befehl verarbeitet
-- haben).
-- ==========================================================================

FBHookRegistry = {};

function FBHealBox_RegisterHook(name, fn)
    if (not FBHookRegistry[name]) then FBHookRegistry[name] = {}; end
    table.insert(FBHookRegistry[name], fn);
end

function FBHealBox_RunHook(name, a1, a2, a3)
    local list = FBHookRegistry[name];
    if (not list) then return false; end
    local handled = false;
    for _, fn in ipairs(list) do
        if (fn(a1, a2, a3)) then handled = true; end
    end
    return handled;
end

LowHP = 0.6; 
VeryLowHP = 0.3; 
NamePlateWidth = 120; 
NamePlateHeight = 28; 

-- Manabalken: "Balken im Balken" am unteren Rand des Lebensbalkens
FBMANA_BAR_HEIGHT = 5;                        -- px
FBMANA_BAR_COLOR  = { 0.15, 0.40, 1.00, 1 };  -- blau
-- Farben je Energieart, wie sie UnitPowerType liefert. Nur Mana faerbt den
-- Balken standardmaessig; die uebrigen erscheinen erst mit HealBox.PowerBar.
FBPOWER_COLORS = {
    [0] = { 0.15, 0.40, 1.00, 1 },   -- Mana, blau
    [1] = { 0.85, 0.20, 0.20, 1 },   -- Wut, rot
    [2] = { 1.00, 0.55, 0.20, 1 },   -- Fokus, orange
    [3] = { 1.00, 0.85, 0.10, 1 },   -- Energie, gelb
};
FBMANA_BG_ALPHA   = 0.35;                     -- dunkler Streifen hinter dem Mana (0 = aus)

-- Grundton des Balkenhintergrunds auf den Plaketten. Wie deckend er liegt,
-- entscheidet HealBox.BarBG (0 bis 100 Prozent, Regler im Reiter Allgemein).
-- Bei 0 bleibt es beim alten Bild: Durch den leeren Teil des Lebensbalkens
-- scheint die Spielwelt durch. Wer wenig Kontrast sieht, dreht ihn hoch und
-- bekommt eine ruhige graue Flaeche, auf der das Gruen des Lebens steht.
FBBAR_BG_COLOR    = { 0.15, 0.15, 0.15 };

-- Begleiter-Plaketten: Namensfarbe, Einrueckung unter dem Besitzer (die
-- Plakette wird um denselben Betrag schmaler, damit die Buttons buendig
-- bleiben) und ein kleines Pfoten-Icon vor dem Namen.
FBPET_NAME_COLOR  = { 0.75, 0.85, 1.00, 1 };
FBPET_INDENT      = 12;
FBPET_ICON        = "Interface\\Icons\\INV_Misc_Foot_Kodo";
FBPET_ICON_SIZE   = 12;

-- Debuff-Icon neben dem Namen
FBDEBUFF_ICON_SIZE = 14;

-- Hoehe der Namensbox: genau eine Zeile (verhindert Umbruch und Verschieben)
FBNAME_HEIGHT = 12;

-- Breite der Namensbox: normal, und wenn rechts daneben das Debuff-Icon steht
-- (rechts davon braucht der Prozenttext etwa 34 px)
FBNAME_WIDTH_FULL = NamePlateWidth - 42;                        -- 78
FBNAME_WIDTH_ICON = NamePlateWidth - 42 - FBDEBUFF_ICON_SIZE - 4; -- 60

-- Sichtlinien-Abzeichen: Icon, Groesse, Position (Anker TOPLEFT an TOPLEFT
-- der Plakette, ragt etwas ueber die Ecke; links aussen sitzen die Buff-Icons)
FBLOS_ICON     = "Interface\\Icons\\Spell_Shadow_MindSteal";   -- das "blinde Auge" (Blenden)
FBLOS_ICON_SIZE = 12;
FBLOS_ICON_X   = -3;
FBLOS_ICON_Y   = 3;
FBLOS_TIMEOUT  = 8;      -- Sek., wie lange eine LoS-Fehlermeldung ohne UnitXP gilt

-- Reichweiten-Fading: Deckkraft einer Plakette ausser Reichweite, Pruefintervall
FBRANGE_ALPHA     = 0.5;
FBRANGE_INTERVAL  = 0.5;   -- Sekunden

-- Rahmenfarbe, wenn der ueberwachte Buff fehlt (Buff-Wache)
FBBUFF_MISSING_COLOR = { 1.0, 0.5, 0.0, 1 };
FBBUFF_NORMAL_COLOR  = { 1.0, 1.0, 1.0, 1 };
-- Rahmenfarbe fuer den Angegriffenen (schlaegt die Buff-Wache)
FBAGGRO_COLOR        = { 1.0, 0.15, 0.15, 1 };

-- Zwei Schwellen, die frueher eine waren, weil sie verschiedene Fragen
-- beantworten:
--
-- FBCD_MIN_DURATION ist die Laenge des globalen Cooldowns. Eine Abklingzeit,
-- die nicht laenger ist, gilt nicht als Grund, einen Button abzudunkeln:
-- waehrend des globalen Cooldowns meldet der Client jeden Zauber als nicht
-- nutzbar, und alle Symbole grau zu faerben sieht aus, als ginge gar nichts.
--
-- FBCD_SHOW_MIN entscheidet, ab welcher Laenge die Uhr laeuft. 0 heisst:
-- jede laufende Abklingzeit wird gezeigt, auch der globale Cooldown. Die Uhr
-- ist die ruhige Anzeige dafuer, sie laeuft weich ab, statt das Symbol
-- schlagartig dunkel und wieder hell zu machen. Wer den globalen Cooldown
-- nicht sehen will, setzt den Wert auf 2.0.
FBCD_MIN_DURATION = 2.0;
FBCD_SHOW_MIN     = 0;

-- Buff-Icons mit Uhr: 8 px, aussen links neben der Plakette (und Zelle),
-- vertikal mittig, von rechts nach links aufgereiht. Die Uhr: vier
-- Quadranten werden im Uhrzeigersinn ab 12 Uhr schwarz-weiss, wie ein
-- Minutenzeiger, der ueber das Icon laeuft (50 % Rest = rechte Haelfte grau).
FBBUFFICON_SIZE = 8;
FBBUFFICON_GAP  = 1;
FBBUFFICON_MAX  = 6;
FBBUFFICON_XOFF = -2;    -- px Abstand des ersten Icons zur linken Plattenkante
FBBUFFICON_GREY = 0.30;  -- Grauton der abgelaufenen Quadranten (falls keine Entsaettigung)
FBBUFFICON_WASH = { 0, 0, 0, 0.45 };   -- dunkle Waesche ueber abgelaufenen Quadranten
FBBUFFICON_ROWS = 2;     -- Icons werden in Zweierstapeln (2 hoch) nach links aufgereiht

-- HoT-/Schild-Timer auf den Buttons
FBTIMER_COLOR_HOT    = { 0.4, 1.0, 0.4 };
FBTIMER_COLOR_SHIELD = { 0.6, 0.8, 1.0 };
FBTIMER_COLOR_WS     = { 1.0, 0.3, 0.3 };
FBTIMER_COLOR_BUFF   = { 1.0, 0.9, 0.4 };
FBWEAKENED_SOUL_SEC  = 15;
FBSHIELD_SPELL       = "Power Word: Shield";

-- Klassenfarben: RAID_CLASS_COLORS des Clients, sonst diese Vorgaben
FBClassColors = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE    = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    DRUID   = { r = 1.00, g = 0.49, b = 0.04 },
};

function FBClassColor(token)
    if (not token) then return nil; end
    if (RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]) then return RAID_CLASS_COLORS[token]; end
    return FBClassColors[token];
end

-- Buff-Wache: welche Buffs der eigenen Klasse zur Auswahl stehen (nur die
-- gelernten erscheinen im Menue) und welche Gruppenversion dasselbe zaehlt.
FBBuffWatchSpells = {
    Priest  = { "Power Word: Fortitude", "Prayer of Fortitude", "Divine Spirit", "Prayer of Spirit",
                "Shadow Protection", "Prayer of Shadow Protection", "Fear Ward", "Renew", "Power Word: Shield", "Inner Fire" },
    Druid   = { "Mark of the Wild", "Gift of the Wild", "Thorns", "Rejuvenation", "Regrowth" },
    Paladin = { "Blessing of Wisdom", "Greater Blessing of Wisdom", "Blessing of Might", "Greater Blessing of Might",
                "Blessing of Kings", "Greater Blessing of Kings", "Blessing of Salvation", "Greater Blessing of Salvation",
                "Blessing of Light", "Greater Blessing of Light", "Blessing of Sanctuary", "Greater Blessing of Sanctuary" },
    Shaman  = { "Earth Shield", "Water Shield" },
};
FBBuffAlternates = {
    ["Power Word: Fortitude"] = "Prayer of Fortitude",   ["Prayer of Fortitude"] = "Power Word: Fortitude",
    ["Divine Spirit"]         = "Prayer of Spirit",      ["Prayer of Spirit"]    = "Divine Spirit",
    ["Shadow Protection"]     = "Prayer of Shadow Protection", ["Prayer of Shadow Protection"] = "Shadow Protection",
    ["Mark of the Wild"]      = "Gift of the Wild",      ["Gift of the Wild"]    = "Mark of the Wild",
    ["Blessing of Wisdom"]    = "Greater Blessing of Wisdom",     ["Greater Blessing of Wisdom"]    = "Blessing of Wisdom",
    ["Blessing of Might"]     = "Greater Blessing of Might",      ["Greater Blessing of Might"]     = "Blessing of Might",
    ["Blessing of Kings"]     = "Greater Blessing of Kings",      ["Greater Blessing of Kings"]     = "Blessing of Kings",
    ["Blessing of Salvation"] = "Greater Blessing of Salvation",  ["Greater Blessing of Salvation"] = "Blessing of Salvation",
    ["Blessing of Light"]     = "Greater Blessing of Light",      ["Greater Blessing of Light"]     = "Blessing of Light",
    ["Blessing of Sanctuary"] = "Greater Blessing of Sanctuary",  ["Greater Blessing of Sanctuary"] = "Blessing of Sanctuary",
};
FBBuffSpells = {};   -- [Name] = { icon = Textur }  (aus dem Zauberbuch)

-- ==========================================================================
-- [ Slots ]
--
-- Zehn Plaketten: 1-5 Spieler (player, party1-4), 6-10 deren Begleiter
-- (pet, partypet1-4). FBPartyFrame[p] ist die Plakette, FBPartyTable[p]
-- ihre Buttons, FBPartyUnit[p] die Unit-ID. Angezeigt wird in der
-- Reihenfolge FBLayoutOrder: jeder Begleiter direkt unter seinem Besitzer.
-- ==========================================================================

FBSlotCount  = 10;
FBPartyUnit  = { "player", "party1", "party2", "party3", "party4",
                 "pet", "partypet1", "partypet2", "partypet3", "partypet4" };
FBSlotIsPet  = { false, false, false, false, false, true, true, true, true, true };
FBLayoutOrder = { 1, 6, 2, 7, 3, 8, 4, 9, 5, 10 };

-- Unit-ID -> Slot (fuer die UNIT_*-Events)
FBUnitSlot = {};
for p = 1, FBSlotCount do FBUnitSlot[FBPartyUnit[p]] = p; end

FBPartyFrame = {}; 
FBPartyTable = {}; 
for p = 1, FBSlotCount do FBPartyTable[p] = {}; end

-- ==========================================================================
-- [ Testmodus: Geisterspieler ]
--
-- Im Testmodus bleibt Slot 1 (der Spieler selbst) echt, alle anderen Slots
-- werden mit Geistern gefuellt, auch wenn gerade eine echte Gruppe da ist.
-- Die Geister atmen: ihre HP schwanken langsam, damit die Farbschwellen,
-- Schild- und Vorhersage-Schichten sichtbar werden. Die Anzeige liest
-- Einheiten ausschliesslich ueber die FBUnit*-Wrapper unten, deshalb muss
-- der restliche Code den Testmodus nicht kennen.
-- Der Testmodus wird bewusst nicht gespeichert.
-- ==========================================================================

FBTestMode = false;

-- hp/mp sind Anteile (0..1), swing ist die Amplitude der HP-Schwankung,
-- debuff = true gibt dem Geist einen von der eigenen Klasse entfernbaren Debuff
-- (Icon debuffTex, debuffCount Stacks), debuffType einen bestimmten Typ
-- (z. B. "Disease"; faerbt nur, wenn die eigene Klasse ihn entfernen kann),
-- state = "dead" | "ghost" | "offline",
-- buffMissing = true laesst die Buff-Wache anschlagen, outOfRange = true faded,
-- los = true zeigt das Sichtlinien-Abzeichen, aggro = true den roten Rahmen,
-- hotLeft/shieldLeft Restsekunden auf Button 1 bzw. 2.
FBTestGhosts = {
    ["party1"]    = { name = "Brynn",  class = "WARRIOR", hpMax = 3400, hp = 0.90, swing = 0.08, hasMana = false, power = 1, mpMax = 100, mp = 0.45, buffMissing = true, state = "dead" },
    ["party2"]    = { name = "Cerys",  class = "WARLOCK", hpMax = 2300, hp = 0.55, swing = 0.10, hasMana = true, mpMax = 3100, mp = 0.65, shield = 450, los = true },
    ["party3"]    = { name = "Dorn",   class = "HUNTER",  hpMax = 2900, hp = 0.30, swing = 0.15, hasMana = true, mpMax = 2400, mp = 0.35, inc = 700, aggro = true, hotLeft = 9, shieldLeft = 21,
                      -- sechs Buffs: Seelenstaerke, Willen, Schattenschutz, Furchtzauberschutz, Mal der Wildnis (fremd, ohne Uhr), Koenige
                      buffs = { { tex = "Interface\\Icons\\Spell_Holy_WordFortitude", left = 540, dur = 1800 },
                                { tex = "Interface\\Icons\\Spell_Holy_DivineSpirit", left = 1500, dur = 1800 },
                                { tex = "Interface\\Icons\\Spell_Shadow_AntiShadow", left = 300, dur = 600 },
                                { tex = "Interface\\Icons\\Spell_Holy_Excorcism", left = 45, dur = 180 },
                                { tex = "Interface\\Icons\\Spell_Nature_Regeneration", dur = 1800 },
                                { tex = "Interface\\Icons\\Spell_Magic_MageArmor", left = 1750, dur = 1800 } } },
    ["party4"]    = { name = "Elowen", class = "DRUID",   hpMax = 2700, hp = 0.95, swing = 0.04, hasMana = true, mpMax = 3600, mp = 0.90, debuff = true, debuffTex = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", debuffCount = 3, outOfRange = true },
    ["pet"]       = { name = "Fang",   hpMax = 1900, hp = 0.75, swing = 0.12, hasMana = false, power = 3, mpMax = 100, mp = 0.80 },
    ["partypet2"] = { name = "Zorbek", hpMax = 1200, hp = 0.60, swing = 0.10, hasMana = true, mpMax = 900, mp = 0.50 },
    ["partypet3"] = { name = "Bramble", hpMax = 2100, hp = 0.40, swing = 0.14, hasMana = false, power = 2, mpMax = 100, mp = 0.60, inc = 300,
                      debuffType = "Disease", debuffTex = "Interface\\Icons\\Spell_Nature_NullifyDisease", debuffCount = 1 },
};

function FBTest_Ghost(unit)
    if (not FBTestMode) or (unit == "player") then return nil; end
    return FBTestGhosts[unit];
end

-- Aktueller HP-Anteil eines Geistes (langsame Sinus-Schwankung)
function FBTest_HPFraction(g, unit)
    local phase = string.len(unit) * 1.7;
    local frac = g.hp + (g.swing or 0) * math.sin((GetTime() * 0.6) + phase);
    if (frac < 0.03) then frac = 0.03; end
    if (frac > 1) then frac = 1; end
    return frac;
end

function FBTest_Set(on)
    FBTestMode = on and true or false;
    if (TestModeCheck) then TestModeCheck:SetChecked(FBTestMode); end
    if (FBTestMode) then
        -- ausgeblendete Anzeige einblenden, sonst sieht man nichts
        if (HealBox.Active ~= 1) then HealBox.Active = 1; end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("TEST_ON"));
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("TEST_OFF"));
    end
    FBUpdateNames();
end

-- [ Unit-Wrapper: echte Einheit oder Geist ] --------------------------------

function FBUnitExists(unit)
    if (FBTestMode and unit ~= "player") then
        return (FBTestGhosts[unit] ~= nil);
    end
    return UnitExists(unit);
end

function FBUnitName(unit)
    local g = FBTest_Ghost(unit);
    if (g) then return g.name; end
    return UnitName(unit);
end

-- liefert hp, hpMax (hpMax nie 0, damit keine Division durch Null entsteht)
function FBUnitHealth(unit)
    local g = FBTest_Ghost(unit);
    if (g) then
        return math.floor(g.hpMax * FBTest_HPFraction(g, unit)), g.hpMax;
    end
    local hp, hpMax = UnitHealth(unit), UnitHealthMax(unit);
    if (not hpMax) or (hpMax <= 0) then hpMax = 1; end
    return (hp or 0), hpMax;
end

-- liefert mp, mpMax, hasMana. hasMana ist nur wahr, wenn die Einheit
-- tatsaechlich Mana nutzt (Powertyp 0). Krieger, Schurken, Druiden in
-- Gestalt und Jaegerbegleiter bekommen keinen Manabalken.
-- Energie einer Einheit: Wert, Maximum, anzeigen?, Energieart (0 = Mana).
-- Ohne HealBox.PowerBar bleibt es beim Mana, Wut, Energie und Fokus liefern
-- dann wie frueher "nichts anzuzeigen" und der Lebensbalken bleibt voll hoch.
function FBUnitMana(unit)
    local g = FBTest_Ghost(unit);
    if (g) then
        if (not g.hasMana) then
            if (HealBox.PowerBar == 1) and (g.power) and (g.mpMax) then
                return math.floor(g.mpMax * (g.mp or 0)), g.mpMax, true, g.power;
            end
            return 0, 0, false, nil;
        end
        return math.floor(g.mpMax * g.mp), g.mpMax, true, 0;
    end
    local ptype = 0;
    if (UnitPowerType) then ptype = UnitPowerType(unit); end
    if (ptype ~= 0) and (HealBox.PowerBar ~= 1) then return 0, 0, false, nil; end
    local mp, mpMax = UnitMana(unit), UnitManaMax(unit);
    if (not mpMax) or (mpMax <= 0) then return 0, 0, false, nil; end
    return (mp or 0), mpMax, true, ptype;
end

-- nil (lebt), "dead", "ghost" oder "offline"
function FBUnitState(unit)
    local g = FBTest_Ghost(unit);
    if (g) then return g.state; end
    if (UnitIsConnected and not UnitIsConnected(unit)) then return "offline"; end
    if (UnitIsGhost and UnitIsGhost(unit)) then return "ghost"; end
    if (UnitIsDead and UnitIsDead(unit)) then return "dead"; end
    return nil;
end

-- Klassen-Token in Grossbuchstaben ("PRIEST"), nil bei Begleitern/unbekannt
function FBUnitClassToken(unit)
    local g = FBTest_Ghost(unit);
    if (g) then return g.class; end
    local loc, eng = UnitClass(unit);
    if (eng) then return strupper(eng); end
    if (loc) then return strupper(loc); end
    return nil;
end
FBDropDown = {}; 
FBDropDownButtonValue = {}; 
FBDropDownButton = {}; 
FBDropDownButtonIcon = {}; 
-- Rechtsklick-Belegung (zweiter Zauber je Button)
FBDropDownButtonR = {}; 
FBDropDownButtonIconR = {}; 
FBActiveSpellIDsR = {}; 
FBSpellBtnsR = {}; 

-- Die drei Laufzeit-Tabellen und die gespeicherte Tabelle einer Seite
function FBChoiceTables(side) 
    if (side == "R") then 
        return FBDropDownButtonR, FBDropDownButtonIconR, FBActiveSpellIDsR, FBSpellBtnsR, HealBox.SpellChoiceR; 
    end 
    return FBDropDownButton, FBDropDownButtonIcon, FBActiveSpellIDs, FBSpellBtns, HealBox.SpellChoice; 
end 

ClassIcon = { 
    Druid = "Interface/Icons/INV_Misc_MonsterClaw_04", 
    Warlock = "Interface/Icons/Spell_Nature_FaerieFire", 
    Hunter = "Interface/Icons/INV_Weapon_Bow_07", 
    Mage = "Interface/Icons/INV_Staff_13", 
    Priest = "Interface/Icons/INV_Staff_30", 
    Warrior = "Interface/Icons/INV_Sword_27", 
    Shaman = "Interface/Icons/Spell_Nature_BloodLust", 
    Paladin = "Interface/Icons/Ability_ThunderBolt", 
    Rogue = "Interface/AddOns/ChatIcons/images/UI-CharacterCreate-Classes_Rogue", 
} 

Spell = { 
    Name = {}, 
    Icon = {}, 
    ID = {}, 
}; 

if (FBClass == "Druid") then  
    -- Heilung
    Spell.Name[1]  = "Healing Touch"; 
    Spell.Name[2]  = "Regrowth"; 
    Spell.Name[3]  = "Rejuvenation"; 
    Spell.Name[4]  = "Swiftmend"; 
    Spell.Name[5]  = "Tranquility"; 
    Spell.Name[6]  = "Lifebloom"; -- TBC / Vanilla+ 
    -- Reinigung
    Spell.Name[7]  = "Abolish Poison"; 
    Spell.Name[8]  = "Cure Poison"; 
    Spell.Name[9]  = "Remove Curse"; 
    -- Buffs & Rezz
    Spell.Name[10] = "Mark of the Wild"; 
    Spell.Name[11] = "Gift of the Wild"; 
    Spell.Name[12] = "Thorns"; 
    Spell.Name[13] = "Innervate"; 
    Spell.Name[14] = "Rebirth"; 
end 

if (FBClass == "Priest") then  
    Spell.Name[1]  = "Lesser Heal"; 
    Spell.Name[2]  = "Heal"; 
    Spell.Name[3]  = "Flash Heal"; 
    Spell.Name[4]  = "Greater Heal"; 
    Spell.Name[5]  = "Renew"; 
    Spell.Name[6]  = "Power Word: Shield"; 
    Spell.Name[7]  = "Prayer of Healing"; 
    Spell.Name[8]  = "Binding Heal";       -- TBC / Vanilla+
    Spell.Name[9]  = "Prayer of Mending";  -- TBC / Vanilla+
    Spell.Name[10] = "Circle of Healing";  -- TBC / Vanilla+
    Spell.Name[11] = "Dispel Magic"; 
    Spell.Name[12] = "Abolish Disease"; 
    Spell.Name[13] = "Cure Disease"; 
    Spell.Name[14] = "Power Word: Fortitude"; 
    Spell.Name[15] = "Prayer of Fortitude"; 
    Spell.Name[16] = "Divine Spirit"; 
    Spell.Name[17] = "Prayer of Spirit"; 
    Spell.Name[18] = "Shadow Protection"; 
    Spell.Name[19] = "Prayer of Shadow Protection"; 
    Spell.Name[20] = "Fear Ward"; 
	Spell.Name[21] = "Inner Fire"; 
    Spell.Name[22] = "Power Infusion"; 
    Spell.Name[23] = "Resurrection"; 
end 

if (FBClass == "Paladin") then 
    Spell.Name[1]  = "Flash of Light"; 
    Spell.Name[2]  = "Holy Light"; 
    Spell.Name[3]  = "Holy Shock"; 
    Spell.Name[4]  = "Lay on Hands"; 
    Spell.Name[5]  = "Cleanse"; 
    Spell.Name[6]  = "Purify"; 
    Spell.Name[7]  = "Blessing of Protection"; 
    Spell.Name[8]  = "Blessing of Freedom"; 
    Spell.Name[9]  = "Blessing of Sacrifice"; 
    Spell.Name[10] = "Redemption"; 
    Spell.Name[11] = "Divine Intervention"; 
    Spell.Name[12] = "Blessing of Wisdom"; 
    Spell.Name[13] = "Blessing of Might"; 
    Spell.Name[14] = "Blessing of Kings"; 
    Spell.Name[15] = "Blessing of Salvation"; 
    Spell.Name[16] = "Blessing of Light"; 
    Spell.Name[17] = "Blessing of Sanctuary"; 
    Spell.Name[18] = "Greater Blessing of Wisdom"; 
    Spell.Name[19] = "Greater Blessing of Might"; 
    Spell.Name[20] = "Greater Blessing of Kings"; 
    Spell.Name[21] = "Greater Blessing of Salvation"; 
    Spell.Name[22] = "Greater Blessing of Light"; 
    Spell.Name[23] = "Greater Blessing of Sanctuary"; 
end 

if (FBClass == "Shaman") then 
    Spell.Name[1]  = "Lesser Healing Wave"; 
    Spell.Name[2]  = "Healing Wave"; 
    Spell.Name[3]  = "Chain Heal"; 
    Spell.Name[4]  = "Earth Shield";  -- TBC / Vanilla+
    Spell.Name[5]  = "Water Shield";  -- TBC / Vanilla+
    Spell.Name[6]  = "Cure Poison"; 
    Spell.Name[7]  = "Cure Disease"; 
    Spell.Name[8]  = "Purge"; 
    Spell.Name[9]  = "Ancestral Spirit"; 
    Spell.Name[10] = "Water Walking"; 
    Spell.Name[11] = "Water Breathing"; 
end 

if (FBClass == "Mage") then
    Spell.Name[1] = "Remove Lesser Curse";
    Spell.Name[2] = "Arcane Intellect";
    Spell.Name[3] = "Arcane Brilliance";
    Spell.Name[4] = "Dampen Magic";
    Spell.Name[5] = "Amplify Magic";
end

if (FBClass == "Warlock") then
    Spell.Name[1] = "Unending Breath";
    Spell.Name[2] = "Detect Invisibility";
    Spell.Name[3] = "Detect Lesser Invisibility";
    Spell.Name[4] = "Detect Greater Invisibility";
end

MaxButtonCount = 10; 

-- Speichert alle verfügbaren Zauber und Ränge 
FBPlayerSpells = {}; 
FBActiveSpellIDs = {}; 
FBSpellBtns = {}; 

-- Begruessung im Chat. Laeuft erst, wenn die Einstellungen gelesen sind
-- (Sprache und Klassensperre stehen dann fest), und nur einmal.
function FBHealBox_Announce()
    if (FBLoadAnnounced) then return; end
    FBLoadAnnounced = true;
    local swowTag = "";
    if (FBHasSuperWoW) then
        swowTag = FBT("SUPERWOW");
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME.."|r  "..HealBoxVersion.." : |cFF00FF00"..FBT("LOADED")..swowTag);
    DEFAULT_CHAT_FRAME:AddMessage(FBT("CREDITS"));
    if (FBClassBlocked) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..format(FBT("CLASS_FORCED"), FBClass or "?"));
    end
    FBHealBox_RunHook("Loaded");   -- Module melden sich im Chat
end

-- Anzeige samt Optionsfenster, Minimap-Button und Modulen stilllegen
function FBHealBox_HideAll()
    if (FBHealBox1) then FBHealBox1:Hide(); end
    for p = 1, FBSlotCount do
        if (FBPartyFrame[p]) then FBPartyFrame[p]:Hide(); end
    end
    if (panel) then panel:Hide(); end
    if (MMButton) then MMButton:Hide(); end
    FBHealBox_ApplyBlizzParty();   -- Blizzards Gruppenfenster zurueckgeben
    FBHealBox_RunHook("Suppress");
end

-- Darf die Anzeige laufen? Gesperrte Klasse nur mit /fbp forceload.
function FBHealBox_ClassAllowed()
    if (not FBClassBlocked) then return true; end
    if (HealBox and HealBox.ForceLoad == 1) then return true; end
    return false;
end

-- Klassensperre auswerten. Rueckgabe: true = Addon darf laufen.
-- Wird in ADDON_LOADED und VARIABLES_LOADED aufgerufen, weil je nach Client
-- erst das zweite Ereignis die gespeicherten Werte mitbringt.
function FBHealBox_ApplyClassGate()
    if (FBHealBox_ClassAllowed()) then
        FBAddonSuppressed = false;
        return true;
    end
    FBAddonSuppressed = true;
    FBHealBox_HideAll();
    if (not FBGateAnnounced) then
        FBGateAnnounced = true;
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME.."|r  "..HealBoxVersion..": |cFFFF8000"
            ..format(FBT("CLASS_BLOCKED"), FBClass or "?").."|r");
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAA"..FBT("CLASS_BLOCKED_HINT").."|r");
    end
    return false;
end

-- Volle Einrichtung der Anzeige (nach dem Laden und nach /fbp forceload)
function FBHealBox_StartUp()
    FBSetLocale(HealBox.Locale, 1);
    FBHealBox_Announce();
    FBLoadSpellData();
    FBHealBoxButtons();
    FBHealBox_SyncOptions();
    HealBoxAttachMode(HealBox.AttachMode);
    FBHealBox_ApplyButtonSpacing();
    FBHealBox_ApplyBarBGAll();
    FBHealBox_ApplyBlizzParty();
    if (MMButton) then MMButton:Show(); end
    FBUpdateNames();
end

function FBHealBox_OnLoad() 
    this:RegisterEvent("ADDON_LOADED"); 
    this:RegisterEvent("PARTY_MEMBERS_CHANGED"); 
    this:RegisterEvent("PLAYER_ENTERING_WORLD"); 
    this:RegisterEvent("SPELLS_CHANGED"); 
    this:RegisterEvent("UNIT_HEALTH"); 
    this:RegisterEvent("UNIT_MAXHEALTH"); 
    this:RegisterEvent("SPELL_UPDATE_COOLDOWN"); 
    this:RegisterEvent("SPELL_UPDATE_USABLE"); 
    this:RegisterEvent("VARIABLES_LOADED"); 
    this:RegisterEvent("UNIT_AURA"); 
    -- Begleiter kommen und gehen (Beschwoerung, Wegschicken, Tod)
    this:RegisterEvent("UNIT_PET"); 
    this:RegisterEvent("UNIT_NAME_UPDATE"); 
    -- Manabalken
    this:RegisterEvent("UNIT_MANA"); 
    this:RegisterEvent("UNIT_MAXMANA"); 
    this:RegisterEvent("UNIT_DISPLAYPOWER"); 
    this:RegisterEvent("UNIT_INVENTORY_CHANGED"); 
end 

-- Fehlende Schluessel in den geladenen SavedVariables nachziehen
function FBHealBox_ApplyDefaults()
    if (not HealBox) then HealBox = {}; end
    if (not HealBox.SpellChoice) then HealBox.SpellChoice = {}; end
    if (HealBox.MaxButtons == nil) then HealBox.MaxButtons = 5; end
    if (HealBox.Scale == nil) then HealBox.Scale = 1.0; end
    if (HealBox.AttachMode == nil) then HealBox.AttachMode = 0; end
    if (HealBox.Active == nil) then HealBox.Active = 1; end
    if (HealBox.HealComm == nil) then HealBox.HealComm = 1; end
    if (HealBox.Locale == nil) then HealBox.Locale = FBDetectLocale(); end
    if (HealBox.ButtonSpacing == nil) then HealBox.ButtonSpacing = 2; end
    if (HealBox.RowSpacing == nil) then HealBox.RowSpacing = 4; end
    if (HealBox.ManaBar == nil) then HealBox.ManaBar = 1; end
    if (HealBox.BarBG == nil) then HealBox.BarBG = 0; end
    if (HealBox.BarBG < 0) then HealBox.BarBG = 0; end
    if (HealBox.BarBG > 100) then HealBox.BarBG = 100; end
    if (HealBox.PowerBar == nil) then HealBox.PowerBar = 0; end
    if (HealBox.HideBlizzParty == nil) then HealBox.HideBlizzParty = 0; end
    if (HealBox.HealBonus == nil) then HealBox.HealBonus = 1; end
    if (HealBox.ShowPets == nil) then HealBox.ShowPets = 1; end
    if (HealBox.ClassColors == nil) then HealBox.ClassColors = 1; end
    if (HealBox.RangeFade == nil) then HealBox.RangeFade = 1; end
    if (not HealBox.SpellChoiceR) then HealBox.SpellChoiceR = {}; end
    if (HealBox.RightClick == nil) then HealBox.RightClick = 0; end
    if (HealBox.DebuffIcon == nil) then HealBox.DebuffIcon = 1; end
    if (HealBox.LOSIcon == nil) then HealBox.LOSIcon = 1; end
    if (HealBox.BuffWatchPets == nil) then HealBox.BuffWatchPets = 0; end
    if (HealBox.SmartRank == nil) then HealBox.SmartRank = 0; end
    if (HealBox.SmartMargin == nil) then HealBox.SmartMargin = 20; end
    if (HealBox.SmartCross == nil) then HealBox.SmartCross = 1; end
    if (HealBox.Cooldowns == nil) then HealBox.Cooldowns = 1; end
    if (HealBox.AggroMark == nil) then HealBox.AggroMark = 1; end
    if (HealBox.SpellTimers == nil) then HealBox.SpellTimers = 1; end
    if (HealBox.BuffIcons == nil) then HealBox.BuffIcons = 1; end
    if (HealBox.ForceLoad == nil) then HealBox.ForceLoad = 0; end
    if (not FBPlateActionName[HealBox.PlateLeft or ""]) then HealBox.PlateLeft = "target"; end
    if (not FBPlateActionName[HealBox.PlateRight or ""]) then HealBox.PlateRight = "target"; end
    FBHealBox_RunHook("Defaults");
end

-- Optionsfenster an die gespeicherten Werte angleichen
function FBHealBox_SyncOptions()
    if (MaxButtonSlider) then MaxButtonSlider:SetValue(HealBox.MaxButtons); end
    if (ScaleSlider) then ScaleSlider:SetValue(HealBox.Scale); end
    if (ButtonSpacingSlider) then ButtonSpacingSlider:SetValue(HealBox.ButtonSpacing); end
    if (RowSpacingSlider) then RowSpacingSlider:SetValue(HealBox.RowSpacing); end
    if (AttachModeCheck) then AttachModeCheck:SetChecked(HealBox.AttachMode == 1); end
    if (HealCommCheck) then HealCommCheck:SetChecked(HealBox.HealComm == 1); end
    if (ManaBarCheck) then ManaBarCheck:SetChecked(HealBox.ManaBar == 1); end
    if (PowerBarCheck) then PowerBarCheck:SetChecked(HealBox.PowerBar == 1); end
    if (BarBGSlider) then BarBGSlider:SetValue(HealBox.BarBG or 0); FBUpdateBarBGSliderText(); end
    if (HidePartyCheck) then HidePartyCheck:SetChecked(HealBox.HideBlizzParty == 1); end
    if (ShowPetsCheck) then ShowPetsCheck:SetChecked(HealBox.ShowPets == 1); end
    if (TestModeCheck) then TestModeCheck:SetChecked(FBTestMode); end
    if (ClassColorsCheck) then ClassColorsCheck:SetChecked(HealBox.ClassColors == 1); end
    if (RangeFadeCheck) then RangeFadeCheck:SetChecked(HealBox.RangeFade == 1); end
    if (DebuffIconCheck) then DebuffIconCheck:SetChecked(HealBox.DebuffIcon == 1); end
    if (LOSIconCheck) then LOSIconCheck:SetChecked(HealBox.LOSIcon == 1); end
    if (BuffWatchPetsCheck) then BuffWatchPetsCheck:SetChecked(HealBox.BuffWatchPets == 1); end
    if (RightClickCheck) then RightClickCheck:SetChecked(HealBox.RightClick == 1); end
    if (SmartRankCheck) then SmartRankCheck:SetChecked(HealBox.SmartRank == 1); end
    if (SmartCrossCheck) then SmartCrossCheck:SetChecked(HealBox.SmartCross == 1); end
    if (SmartMarginSlider) then SmartMarginSlider:SetValue(HealBox.SmartMargin); end
    if (CooldownsCheck) then CooldownsCheck:SetChecked(HealBox.Cooldowns == 1); end
    if (AggroMarkCheck) then AggroMarkCheck:SetChecked(HealBox.AggroMark == 1); end
    if (SpellTimersCheck) then SpellTimersCheck:SetChecked(HealBox.SpellTimers == 1); end
    if (BuffIconsCheck) then BuffIconsCheck:SetChecked(HealBox.BuffIcons == 1); end
    FBHealBox_UpdateBuffWatchLabel();
    FBHealBox_UpdatePlateActionLabels();
    FBHealBox_ApplyRightClickLayout();
    FBHealBox_UpdateSmartCrossState();
    FBHealBox_UpdatePartyExclusion();
    FBHealBox_RunHook("SyncOptions");
end

function FBHealBox_UpdateSmartCrossState()
    if (not SmartCrossCheck) then return; end
    if (HealBox.SmartRank == 1) then
        SmartCrossCheck:Enable();
        if (SmartCrossCheck.Text) then
            -- Gold wie bei allen anderen Schaltern (GameFontNormal)
            SmartCrossCheck.Text:SetTextColor(1, 0.82, 0, 1);
        end
    else
        SmartCrossCheck:Disable();
        if (SmartCrossCheck.Text) then
            SmartCrossCheck.Text:SetTextColor(0.5, 0.5, 0.5, 1);
        end
    end
end

-- Anheftmodus und das Verstecken der Blizzard-Frames schliessen sich aus:
-- was gerade nicht geht, wird gesperrt und ausgegraut.
function FBHealBox_UpdatePartyExclusion()
    local pairsList = {
        { box = AttachModeCheck, blocked = (HealBox.HideBlizzParty == 1) },
        { box = HidePartyCheck,  blocked = (HealBox.AttachMode == 1) },
    };
    for _, e in ipairs(pairsList) do
        if (e.box) then
            if (e.blocked) then
                e.box:Disable();
                if (e.box.Text) then e.box.Text:SetTextColor(0.5, 0.5, 0.5, 1); end
            else
                e.box:Enable();
                if (e.box.Text) then e.box.Text:SetTextColor(1, 0.82, 0, 1); end
            end
        end
    end
end

function FBUnitGUID(unit) 
    if (FBHasSuperWoW and UnitExists(unit)) then 
        local exists, guid = UnitExists(unit); 
        return guid; 
    end 
    return nil; 
end 

-- [ Zauberbuch scannen und Ränge sammeln ] -- 
function FBLoadSpellData() 
    FBPlayerSpells = {}; 
    FBBuffSpells = {}; 
    -- Zauber, die per Drag & Drop belegt wurden, koennen ausserhalb der
    -- Klassenliste liegen: ihre Namen aus der gespeicherten Belegung mitnehmen
    local extra = {}; 
    for _, tbl in ipairs({ HealBox.SpellChoice or {}, HealBox.SpellChoiceR or {} }) do 
        for _, cast in pairs(tbl) do 
            if (type(cast) == "string") then 
                local base = FBPredict_SplitCast(cast); 
                if (base) then extra[base] = true; end 
            end 
        end 
    end 
    local i = 1; 
    while true do 
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL); 
        if not spellName then break; end 
        local isHealBoxSpell = (extra[spellName] == true); 
        for _, v in ipairs(Spell.Name) do 
            if v == spellName then  
                isHealBoxSpell = true;  
                break;  
            end 
        end 
        -- Buff-Wache: Textur des Zaubers merken (rangunabhaengig) und als Addon-Zauber erfassen
        for _, v in ipairs(FBBuffWatchSpells[FBClass] or {}) do 
            if (v == spellName) then 
                FBBuffSpells[spellName] = { icon = GetSpellTexture(i, BOOKTYPE_SPELL) }; 
                isHealBoxSpell = true; 
                break; 
            end 
        end
        
        if isHealBoxSpell then 
            if not FBPlayerSpells[spellName] then 
                FBPlayerSpells[spellName] = {}; 
            end 
            local icon = GetSpellTexture(i, BOOKTYPE_SPELL); 
            table.insert(FBPlayerSpells[spellName], { rank = spellRank, id = i, icon = icon }); 
        end 
        i = i + 1; 
    end 
    
    -- Tooltips auswerten: welche dieser Zauber sind HoTs bzw. Absorb-Schilde?
    FBPredict_BuildWatch();
    FBSpellNameCache = {};
    FBSpellCastCache = {};
    FBHealBox_InvalidateRangeSpell();
    FBHealBox_ProbeAPIs();
    -- Doppelt gezaehlte Absorb-Lernwerte (Versionen vor 1.4.2) verwerfen
    FBPredict_SanitizeMemory();
    -- Watch ist neu: vorhandene Buffs sofort einlesen
    FBPredict_ScanAllUnits();

    if (not HealBox.SpellChoiceR) then HealBox.SpellChoiceR = {}; end 
    for _, side in ipairs({ "L", "R" }) do 
        local _, _, _, _, savedTable = FBChoiceTables(side); 
        for btnIndex = 1, MaxButtonCount, 1 do 
            local saved = savedTable[btnIndex]; 
            if type(saved) == "number" then 
                savedTable[btnIndex] = nil; 
                saved = nil; 
            end 
            FBApplySpellChoice(btnIndex, saved, side); 
        end 
    end 
end 

-- side = "L" (Standard) oder "R" (Rechtsklick)
function FBApplySpellChoice(i, castString, side)
    if type(castString) == "number" then return; end
    FBHealBox_InvalidateRangeSpell();   -- Belegung geaendert
    local names, icons, ids, fields = FBChoiceTables(side);
    
    names[i] = castString;
    icons[i] = "Interface\\Icons\\INV_Misc_QuestionMark";
    ids[i] = nil;
    
    if castString then
        for baseName, ranks in pairs(FBPlayerSpells) do
            for _, spellData in ipairs(ranks) do
                local cmpString = baseName;
                if spellData.rank and spellData.rank ~= "" then
                    cmpString = baseName .. "(" .. spellData.rank .. ")";
                end
                if cmpString == castString then
                    icons[i] = spellData.icon;
                    ids[i] = spellData.id;
                    break;
                end
            end
        end
    end

    if fields[i] then
        if castString and icons[i] then
            fields[i].text:SetText(castString);
            fields[i].icon:SetTexture(icons[i]);
        else
            fields[i].text:SetText(FBT("SELECT_SPELL"));
            fields[i].icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
        end
        fields[i].icon:Show();
    end
end

-- ==========================================================================
-- [ FB Cascading Menu: eigenes Menuesystem fuer Vanilla 1.12 / Lua 5.0 ]
--
-- Warum kein UIDropDownMenu mehr?
--   * 1.12 loest Level-2 ueber UIDROPDOWNMENU_OPEN_MENU (ein STRING) auf und
--     ruft dort ToggleDropDownMenu(level+1, ...) ohne Frame-Referenz auf ->
--     bei Custom-Frames im displayMode "MENU" bricht die Kette regelmaessig.
--   * UIDropDownMenuButton_OnEnter ruft bei JEDEM Eintrag ohne hasArrow
--     CloseDropDownMenus(level+1) -> das Untermenue stirbt, sobald die Maus
--     ueber einen Nachbareintrag wandert.
--   * info.func + keepShownOnClick erzeugt zwangsweise Haken + Check-Sound.
--
-- Dieses Menue: Hover oeffnet, nichts schliesst es ausser Auswahl / anderes
-- Untermenue / Klick daneben. Icon links, Text linksbuendig, kein Sound.
-- ==========================================================================

FBMENU_MAX_LEVELS  = 2;     -- Anzahl Menue-Ebenen
FBMENU_BTN_HEIGHT  = 17;    -- Zeilenhoehe
FBMENU_ICON_SIZE   = 16;    -- Icon-Kantenlaenge
FBMENU_TEXT_GAP    = 6;     -- Abstand Icon -> Text
FBMENU_PAD         = 8;     -- Innenabstand der Liste
FBMENU_ARROW_SPACE = 18;    -- Platz fuer den Pfeil rechts
FBMENU_MOUSE_PAD   = 14;    -- Toleranzzone: Bruecke zwischen L1 und L2
FBMENU_GRACE_TIME  = 3.0;   -- Sek. ausserhalb -> Auto-Close (999 = aus)

FBMenuList           = {};  -- [level] = Frame
FBMenuActiveButtonID = 1;   -- welcher Options-Slot wird gerade belegt
FBMenuActiveSide     = "L"; -- "L" = Linksklick-Feld, "R" = Rechtsklick-Feld
FBMenuOpenSubValue   = nil; -- welcher Zauber haengt gerade im Untermenue
FBMenuOutTimer       = 0;

-- Treiber fuer den Auto-Close (OnUpdate laeuft nur solange sichtbar)
FBMenuDriver = CreateFrame("Frame", "FBMenuDriver", UIParent);
FBMenuDriver:Hide();
FBMenuDriver:SetScript("OnUpdate", function()
    FBMenu_OnUpdate(arg1);
end);

-- Unsichtbarer Klickfaenger hinter dem Menue (Klick daneben schliesst)
FBMenuCloser = CreateFrame("Button", "FBMenuCloser", UIParent);
FBMenuCloser:SetAllPoints(UIParent);
FBMenuCloser:SetFrameStrata("FULLSCREEN");
FBMenuCloser:EnableMouse(true);
FBMenuCloser:RegisterForClicks("LeftButtonUp", "RightButtonUp");
FBMenuCloser:SetScript("OnClick", function() FBMenu_CloseAll(); end);
FBMenuCloser:Hide();

-- [ Hilfsfunktionen ] ------------------------------------------------------

function FBMenu_MouseOver(frame)
    if (not frame) or (not frame:IsVisible()) then return false; end
    local left = frame:GetLeft();
    if (not left) then return false; end
    local scale = frame:GetEffectiveScale();
    local x, y = GetCursorPosition();
    x = x / scale;
    y = y / scale;
    local pad = FBMENU_MOUSE_PAD;
    return (x >= left - pad) and (x <= frame:GetRight() + pad)
       and (y >= frame:GetBottom() - pad) and (y <= frame:GetTop() + pad);
end

function FBMenu_GetList(level)
    if (FBMenuList[level]) then return FBMenuList[level]; end

    local f = CreateFrame("Frame", "FBMenuList"..level, UIParent);
    f:SetFrameStrata("FULLSCREEN_DIALOG");
    f:SetFrameLevel(10 + level * 5);
    f:SetToplevel(true);
    f:EnableMouse(true);
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    });
    f:SetBackdropColor(0, 0, 0, 0.92);
    f.buttons = {};
    f:Hide();

    FBMenuList[level] = f;
    return f;
end

function FBMenu_GetButton(list, index)
    if (list.buttons[index]) then return list.buttons[index]; end

    local yOff = -FBMENU_PAD - ((index - 1) * FBMENU_BTN_HEIGHT);
    local b = CreateFrame("Button", list:GetName().."Button"..index, list);
    b:SetHeight(FBMENU_BTN_HEIGHT);
    b:SetPoint("TOPLEFT",  list, "TOPLEFT",   FBMENU_PAD, yOff);
    b:SetPoint("TOPRIGHT", list, "TOPRIGHT", -FBMENU_PAD, yOff);

    b.icon = b:CreateTexture(nil, "ARTWORK");
    b.icon:SetWidth(FBMENU_ICON_SIZE);
    b.icon:SetHeight(FBMENU_ICON_SIZE);
    b.icon:SetPoint("LEFT", b, "LEFT", 0, 0);
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93);

    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    b.text:SetPoint("LEFT", b, "LEFT", FBMENU_ICON_SIZE + FBMENU_TEXT_GAP, 0);
    b.text:SetJustifyH("LEFT");

    b.arrow = b:CreateTexture(nil, "ARTWORK");
    b.arrow:SetWidth(16);
    b.arrow:SetHeight(16);
    b.arrow:SetPoint("RIGHT", b, "RIGHT", 2, 0);
    b.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow");
    b.arrow:Hide();

    b.hl = b:CreateTexture(nil, "HIGHLIGHT");
    b.hl:SetAllPoints(b);
    b.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
    b.hl:SetBlendMode("ADD");

    b:RegisterForClicks("LeftButtonUp");
    b:SetScript("OnEnter", function() FBMenu_ButtonOnEnter(); end);
    b:SetScript("OnClick", function() FBMenu_ButtonOnClick(); end);

    list.buttons[index] = b;
    return b;
end

-- [ Menue-Ebene aufbauen und anzeigen ] ------------------------------------
-- entries = Array aus { text, icon, hasArrow, submenu, value, spellID, func, isTitle }
-- anchor  = Level 1: der Options-Button;  Level >1: der Eintrag mit dem Pfeil

function FBMenu_ShowLevel(level, entries, anchor)
    local list  = FBMenu_GetList(level);
    local count = table.getn(entries);
    if (count == 0) then list:Hide(); return; end

    local maxText  = 0;
    local anyArrow = false;

    for i = 1, count do
        local e = entries[i];
        local b = FBMenu_GetButton(list, i);
        b.entry = e;
        b.level = level;

        b.text:SetText(e.text);
        if (e.isTitle) then
            b.text:SetTextColor(1, 0.82, 0);
            b.hl:SetAlpha(0);
        else
            b.text:SetTextColor(1, 1, 1);
            b.hl:SetAlpha(1);
        end

        if (e.icon) then
            b.icon:SetTexture(e.icon);
            b.icon:Show();
        else
            b.icon:Hide();
        end

        if (e.hasArrow) then
            b.arrow:Show();
            anyArrow = true;
        else
            b.arrow:Hide();
        end

        b:Show();

        local w = b.text:GetStringWidth();
        if (w > maxText) then maxText = w; end
    end

    -- ueberzaehlige Buttons aus einem frueheren Aufruf verstecken
    local j = count + 1;
    while (list.buttons[j]) do
        list.buttons[j]:Hide();
        j = j + 1;
    end

    local width = (FBMENU_PAD * 2) + FBMENU_ICON_SIZE + FBMENU_TEXT_GAP + maxText;
    if (anyArrow) then width = width + FBMENU_ARROW_SPACE; end
    if (width < 130) then width = 130; end
    list:SetWidth(width);
    list:SetHeight((FBMENU_PAD * 2) + (count * FBMENU_BTN_HEIGHT));

    list:ClearAllPoints();
    if (level == 1) then
        list:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2);
    else
        -- 2px Ueberlappung mit der Elternliste: kein Loch, das die Maus verliert
        list:SetPoint("TOPLEFT", anchor, "TOPRIGHT", FBMENU_PAD - 2, FBMENU_PAD);
    end
    list:Show();

    -- Ragt es rechts aus dem Bildschirm? Dann nach links klappen.
    if (level > 1) and list:GetRight() and (list:GetRight() > UIParent:GetRight()) then
        list:ClearAllPoints();
        list:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -(FBMENU_PAD - 2), FBMENU_PAD);
    end
end

-- [ Maus-Handler ] ---------------------------------------------------------

function FBMenu_ButtonOnEnter()
    local e = this.entry;
    if (not e) or e.isTitle then return; end

    if (e.hasArrow) then
        -- Hover oeffnet das Untermenue (nur neu bauen, wenn ein anderer Zauber)
        if (FBMenuOpenSubValue ~= e.submenu) then
            FBMenuOpenSubValue = e.submenu;
            FBMenu_ShowLevel(this.level + 1, FBMenu_BuildRankEntries(e.submenu), this);
        end
    end
    -- Eintraege OHNE Pfeil lassen ein offenes Untermenue absichtlich stehen.
    -- (Blizzards Original wuerde hier CloseDropDownMenus() feuern.)
end

function FBMenu_ButtonOnClick()
    local e = this.entry;
    if (not e) or e.isTitle then return; end

    if (e.hasArrow) then
        FBMenuOpenSubValue = e.submenu;
        FBMenu_ShowLevel(this.level + 1, FBMenu_BuildRankEntries(e.submenu), this);
        return;
    end

    if (e.func) then e.func(e); end
end

function FBMenu_OnUpdate(elapsed)
    if (not elapsed) then return; end

    local over = false;
    for lvl = 1, FBMENU_MAX_LEVELS do
        if (FBMenu_MouseOver(FBMenuList[lvl])) then
            over = true;
            break;
        end
    end

    if (over) then
        FBMenuOutTimer = 0;
    else
        FBMenuOutTimer = FBMenuOutTimer + elapsed;
        if (FBMenuOutTimer > FBMENU_GRACE_TIME) then
            FBMenu_CloseAll();
        end
    end
end

-- [ Oeffnen / Schliessen ] -------------------------------------------------

function FBMenu_IsOpen()
    return (FBMenuList[1] and FBMenuList[1]:IsVisible());
end

function FBMenu_CloseAll()
    for lvl = 1, FBMENU_MAX_LEVELS do
        if (FBMenuList[lvl]) then FBMenuList[lvl]:Hide(); end
    end
    FBMenuOpenSubValue = nil;
    FBMenuOutTimer = 0;
    FBMenuDriver:Hide();
    FBMenuCloser:Hide();
end

-- Beliebige Eintragsliste als Menue oeffnen (Zauberwahl, Sprachwahl, ...)
function FBMenu_OpenMenu(entries, anchorFrame)
    FBMenu_CloseAll();
    FBMenu_ShowLevel(1, entries, anchorFrame);
    FBMenuOutTimer = 0;
    FBMenuCloser:Show();
    FBMenuDriver:Show();
end

function FBMenu_OpenSpellMenu(btnIndex, anchorFrame, side)
    side = side or "L";
    -- gleiches Feld nochmal geklickt -> zu
    if (FBMenu_IsOpen() and FBMenuActiveButtonID == btnIndex and FBMenuActiveSide == side) then
        FBMenu_CloseAll();
        return;
    end

    FBMenuActiveButtonID = btnIndex;
    FBMenuActiveSide     = side;
    FBMenu_OpenMenu(FBMenu_BuildSpellEntries(), anchorFrame);
end

-- Sprachumschaltung im Optionsfenster
function FBMenu_OpenLanguageMenu(anchorFrame)
    if (FBMenu_IsOpen()) then
        FBMenu_CloseAll();
        return;
    end

    local entries = {};
    local codes = { "deDE", "enUS", "esES", "frFR", "itIT" };
    for _, code in ipairs(codes) do
        local e = {};
        e.text = FBLocale[code].LANG_NAME;
        e.code = code;
        e.func = function(entry)
            FBSetLocale(entry.code, true);
            FBMenu_CloseAll();
        end
        table.insert(entries, e);
    end
    FBMenu_OpenMenu(entries, anchorFrame);
end

-- Buff-Wache: Auswahl eines gelernten Buffs (oder keiner)
function FBMenu_OpenBuffMenu(anchorFrame)
    if (FBMenu_IsOpen()) then
        FBMenu_CloseAll();
        return;
    end

    local entries = {};
    local none = {};
    none.text = FBT("MENU_NO_BUFF");
    none.icon = "Interface\\Icons\\INV_Misc_QuestionMark";
    none.func = function()
        FBHealBox_SetWatchBuff(nil);
        FBMenu_CloseAll();
    end
    table.insert(entries, none);

    for _, spellName in ipairs(FBBuffWatchSpells[FBClass] or {}) do
        local sd = FBBuffSpells[spellName];
        if (sd) then
            local e = {};
            e.text  = spellName;
            e.icon  = sd.icon;
            e.value = spellName;
            e.func  = function(entry)
                FBHealBox_SetWatchBuff(entry.value);
                FBMenu_CloseAll();
            end
            table.insert(entries, e);
        end
    end
    FBMenu_OpenMenu(entries, anchorFrame);
end

-- Klickaktion der Plakette waehlen (side = "L" / "R")
function FBMenu_OpenPlateActionMenu(anchorFrame, side)
    if (FBMenu_IsOpen()) then
        FBMenu_CloseAll();
        return;
    end
    local entries = {};
    for _, action in ipairs(FBPlateActionOrder) do
        local e = {};
        e.text   = FBT(FBPlateActionName[action]);
        e.action = action;
        e.func   = function(entry)
            if (side == "R") then HealBox.PlateRight = entry.action; else HealBox.PlateLeft = entry.action; end
            FBHealBox_UpdatePlateActionLabels();
            FBMenu_CloseAll();
        end
        table.insert(entries, e);
    end
    FBMenu_OpenMenu(entries, anchorFrame);
end

-- [ Inhalte ] --------------------------------------------------------------

function FBMenu_MakeCastString(spellName, rank)
    if (rank and rank ~= "") then
        return spellName.."("..rank..")";
    end
    return spellName;
end

function FBMenu_BuildSpellEntries()
    local entries = {};

    local clear = {};
    clear.text = FBT("MENU_NO_SPELL");
    clear.icon = "Interface\\Icons\\INV_Misc_QuestionMark";
    clear.func = FBMenu_ClearSpell;
    table.insert(entries, clear);

    for _, spellName in ipairs(Spell.Name) do
        local ranks = FBPlayerSpells[spellName];
        if (ranks) then
            local numRanks = table.getn(ranks);
            local e = {};
            e.text = spellName;
            e.icon = ranks[1].icon;

            if (numRanks > 1) then
                e.hasArrow = true;
                e.submenu  = spellName;
            else
                e.value   = FBMenu_MakeCastString(spellName, ranks[1].rank);
                e.spellID = ranks[1].id;
                e.func    = FBMenu_SelectSpell;
            end

            table.insert(entries, e);
        end
    end

    return entries;
end

function FBMenu_BuildRankEntries(spellName)
    local entries = {};
    local ranks = FBPlayerSpells[spellName];
    if (not ranks) then return entries; end

    local title = {};
    title.text    = spellName;
    title.isTitle = true;
    title.icon    = ranks[1].icon;
    table.insert(entries, title);

    for _, sd in ipairs(ranks) do
        local e = {};
        e.text = sd.rank;
        if (not e.text) or (e.text == "") then e.text = FBT("RANK_DEFAULT"); end
        e.icon    = sd.icon;
        e.value   = FBMenu_MakeCastString(spellName, sd.rank);
        e.spellID = sd.id;
        e.func    = FBMenu_SelectSpell;
        table.insert(entries, e);
    end

    return entries;
end

function FBMenu_SelectSpell(entry)
    local btnID = FBMenuActiveButtonID;
    local _, _, _, _, savedTable = FBChoiceTables(FBMenuActiveSide);
    savedTable[btnID] = entry.value;
    FBApplySpellChoice(btnID, entry.value, FBMenuActiveSide);
    FBHealBoxButtonsChanged();
    FBMenu_CloseAll();
end

function FBMenu_ClearSpell()
    local btnID = FBMenuActiveButtonID;
    local _, _, _, _, savedTable = FBChoiceTables(FBMenuActiveSide);
    savedTable[btnID] = nil;
    FBApplySpellChoice(btnID, nil, FBMenuActiveSide);
    FBHealBoxButtonsChanged();
    FBMenu_CloseAll();
end

function FBHealBox_OnEvent(event, arg1) 
    -- Die beiden Ladeereignisse zuerst: hier faellt die Entscheidung, ob das
    -- Addon fuer diese Klasse ueberhaupt anzeigt.
    if (((event == "ADDON_LOADED") and (arg1 == FBADDON_FOLDER)) or (event == "VARIABLES_LOADED")) then 
        FBHealBox_ApplyDefaults(); 
        FBSetLocale(HealBox.Locale, 1); 
        if (not FBHealBox_ApplyClassGate()) then return; end 
        FBHealBox_StartUp(); 
        return; 
    end 
    
    -- Krieger, Schurke, Jaeger ohne /fbp forceload: nichts weiter tun
    if (FBAddonSuppressed) then return; end 
    
    if (event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED") then 
        FBLoadSpellData(); 
        FBHealBoxButtons(); 
        if (FBRegisterMinimapButtonWithMBB) then 
            FBRegisterMinimapButtonWithMBB(); 
        end 
        FBHealBox_UpdateBuffWatchLabel(); 
        if (event == "PLAYER_ENTERING_WORLD") then FBUpdateNames(); end 
        FBHealBox_RefreshAllBars(); 
    end 
    
    
    -- Button-Farben und Cooldowns: ein zentraler Durchgang statt 260 Handler.
    -- Mehrere dieser Events je Frame (jede Manaaenderung feuert USABLE)
    -- werden im naechsten OnUpdate zu einem Durchgang zusammengefasst.
    if (event == "SPELL_UPDATE_USABLE") then 
        FBBtnStatesDirty = "SPELL_UPDATE_USABLE"; 
    elseif (event == "SPELL_UPDATE_COOLDOWN") then 
        if (FBBtnStatesDirty ~= "SPELL_UPDATE_USABLE") then FBBtnStatesDirty = "SPELL_UPDATE_COOLDOWN"; end 
    end 
    
    -- Gruppe oder Begleiter geaendert -> Plaketten neu belegen und anordnen.
    -- Salven (mehrere Events je Frame beim Zonen) werden auf einen Durchlauf
    -- im naechsten Frame zusammengefasst.
    if (event == "PARTY_MEMBERS_CHANGED" or event == "UNIT_PET") then 
        FBNamesDirty = true; 
        FBBlizzPartyDirty = true;   -- neue Mitglieder gleich mit verstecken
    end 
    
    -- Ausruestung gewechselt: gemerkten +Heilung-Wert verwerfen
    if (event == "UNIT_INVENTORY_CHANGED") and (arg1 == "player") then 
        FBHealBox_InvalidateHealBonus(); 
    end 
    
    if (event == "UNIT_NAME_UPDATE") then 
        local p = FBUnitSlot[arg1]; 
        if (p and FBPartyFrame[p] and not FBTestMode) then 
            FBPartyFrame[p].NameText:SetText(strupper(UnitName(arg1) or "")); 
        end 
    end 
    
    -- Alle UNIT_*-Events laufen ueber die Slot-Tabelle: ein Handler fuer
    -- Spieler und Begleiter, Leben und Mana. Im Testmodus sind die Geister
    -- vom Echtzeit-Update abgekoppelt (das erledigt FBPredict_OnUpdate).
    if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_AURA"
        or event == "UNIT_MANA" or event == "UNIT_MAXMANA" or event == "UNIT_DISPLAYPOWER") then 
        local p = FBUnitSlot[arg1]; 
        if (p and FBPartyFrame[p]) then 
            FBHealBox_UpdateUnit(arg1, FBPartyFrame[p], (event == "UNIT_AURA")); 
            if (event == "UNIT_AURA") then FBHealBox_CheckWatchBuff(arg1, FBPartyFrame[p]); end 
        end 
    end 
end 

-- Alle drei Balken in dieselbe Ebene legen und stabil stapeln:
-- HP deckend oben, darunter der Schild-Anteil, ganz unten die Heilvorhersage.
-- Der Manabalken liegt als oberste Schicht ueber dem unteren Rand des HP-Balkens.
function FBHealBox_SetBarStrata(f, strata)
    if (not f) or (not f.HealthBar) then return; end
    f.IncHealBar:SetFrameStrata(strata);
    f.ShieldBar:SetFrameStrata(strata);
    f.HealthBar:SetFrameStrata(strata);
    f.ManaBar:SetFrameStrata(strata);
    f.IncHealBar:SetFrameLevel(1);
    f.ShieldBar:SetFrameLevel(2);
    f.HealthBar:SetFrameLevel(3);
    f.ManaBar:SetFrameLevel(4);
end

-- Balkenhintergrund einer Plakette setzen. 0 Prozent heisst: gar keine
-- Textur, damit nichts gezeichnet wird, was man ohnehin nicht sieht.
function FBHealBox_ApplyBarBG(f)
    if (not f) or (not f.BarBG) then return; end
    local a = (HealBox.BarBG or 0) / 100;
    if (a <= 0) then f.BarBG:Hide(); return; end
    f.BarBG:SetTexture(FBBAR_BG_COLOR[1], FBBAR_BG_COLOR[2], FBBAR_BG_COLOR[3], a);
    f.BarBG:Show();
end

function FBHealBox_ApplyBarBGAll()
    for p = 1, FBSlotCount do
        FBHealBox_ApplyBarBG(FBPartyFrame[p]);
    end
end

-- Alle Balken einer Plakette ein-/ausblenden (Party-Frame-Modus blendet aus)
function FBHealBox_SetPlateVisible(f, visible)
    if (not f) or (not f.HealthBar) then return; end
    f.plateHidden = (not visible);
    if (visible) then
        f.NameText:Show(); f.HPText:Show();
        if (f.isPet and f.PetIcon) then f.PetIcon:Show(); end
        f.HealthBar:Show(); f.ShieldBar:Show(); f.IncHealBar:Show();
        -- ManaBar entscheidet FBHealBox_UpdateMana je nach Powertyp
    else
        f.NameText:Hide(); f.HPText:Hide();
        if (f.isPet and f.PetIcon) then f.PetIcon:Hide(); end
        f.HealthBar:Hide(); f.ShieldBar:Hide(); f.IncHealBar:Hide(); f.ManaBar:Hide();
        f.DebuffIcon:Hide(); f.DebuffCount:Hide(); f.LOSIcon:Hide();
        if (f.buffIcons) then for _, ic in ipairs(f.buffIcons) do ic:Hide(); end end
    end
end

-- ==========================================================================
-- [ Klick auf die Plakette ]
--
-- Links- und Rechtsklick auf Name/Lebensbalken sind belegbar (Optionen,
-- Reiter Allgemein): target = anvisieren, menu = Blizzards Einheitenmenue,
-- move = Anzeige ziehen, none = nichts. Shift + Linksklick ziehen verschiebt
-- die Anzeige immer.
-- ==========================================================================

FBPlateActionOrder = { "target", "menu", "move", "none" };
FBPlateActionName  = { target = "ACT_TARGET", menu = "ACT_MENU", move = "ACT_MOVE", none = "ACT_NONE" };
FBHealBoxDragging  = false;

function FBHealBox_PlateAction(mouseButton)
    if (mouseButton == "RightButton") then return HealBox.PlateRight or "target"; end
    return HealBox.PlateLeft or "target";
end

-- Blizzards Dropdown zur Einheit (fuer das Einheitenmenue), sonst nil
function FBHealBox_UnitDropDown(unit)
    if (unit == "player") then return PlayerFrameDropDown; end
    local _, _, n = string.find(unit, "^party(%d)$");
    if (n) then return getglobal("PartyMemberFrame"..n.."DropDown"); end
    if (unit == "pet") then return PetFrameDropDown; end
    return nil;
end

function FBHealBox_RunPlateAction(f, action)
    local unit = f.unit;
    if (not unit) or (action == "none") or (action == "move") then return; end
    if (FBTest_Ghost(unit)) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("TEST_CLICK"));
        return;
    end
    if (not UnitExists(unit)) then return; end

    if (action == "menu") then
        local dd = FBHealBox_UnitDropDown(unit);
        if (dd and ToggleDropDownMenu) then
            ToggleDropDownMenu(1, nil, dd, "cursor");
            return;
        end
        -- kein Menue fuer diese Einheit (Gruppen-Begleiter): anvisieren
    end
    TargetUnit(unit);
end

function FBHealBox_PlateMouseDown(f)
    local action = FBHealBox_PlateAction(arg1);
    if (HealBox.AttachMode ~= 1) and (action == "move" or (arg1 == "LeftButton" and IsShiftKeyDown())) then
        FBHealBoxDragging = true;
        FBHealBox1:StartMoving();
    end
end

function FBHealBox_PlateMouseUp(f)
    if (FBHealBoxDragging) then
        FBHealBoxDragging = false;
        FBHealBox1:StopMovingOrSizing();
        FBHealBox_SavePosition();
        return;
    end
    FBHealBox_RunPlateAction(f, FBHealBox_PlateAction(arg1));
end

-- [ Plattenposition merken ] ------------------------------------------------
-- Gespeichert wird die linke obere Ecke in Bildschirmpixeln (skalierungs-
-- unabhaengig), damit ein Wechsel der Skalierung die Platte nicht verschiebt.

function FBHealBox_SavePosition()
    if (not FBHealBox1) or (HealBox.AttachMode == 1) then return; end
    local left, top = FBHealBox1:GetLeft(), FBHealBox1:GetTop();
    if (not left) or (not top) then return; end
    local s = FBHealBox1:GetEffectiveScale();
    HealBox.PosX = left * s;
    HealBox.PosY = top * s;
end

function FBHealBox_RestorePosition()
    if (not FBHealBox1) then return; end
    FBHealBox1:ClearAllPoints();
    if (HealBox.PosX and HealBox.PosY) then
        local s = FBHealBox1:GetEffectiveScale();
        FBHealBox1:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", HealBox.PosX / s, HealBox.PosY / s);
    else
        FBHealBox1:SetPoint("LEFT", WorldFrame, "LEFT", 100, 22);
    end
end

function FBHealBoxCreateFrame(FrameName,ParentFrame,FrameTexture,FrameWidth,FrameHeight,FrameAlpha,Unit,isPet) 
    local f = CreateFrame("Frame", FrameName, ParentFrame); 
    f:SetFrameStrata("MEDIUM"); 
    icon = f:CreateTexture(nil, "BACKGROUND"); 
    icon:SetAllPoints(); 
    f:SetBackdrop({bgFile = nil, edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 10, insets = { left = 4, right = 4, top = 4, bottom = 4 }}); 
    f.unit  = Unit; 
    f.isPet = isPet; 
    -- Begleiter: eingerueckt und um die Einrueckung schmaler
    f.indent = 0; 
    if (isPet) then f.indent = FBPET_INDENT; end 
    f.plateW = FrameWidth - f.indent; 
    local barW = f.plateW - 5; 
    -- Breite der Namensbox ohne / mit Debuff-Icon (Pets: minus Pfoten-Icon)
    local nameX = 4; 
    if (isPet) then nameX = 4 + FBPET_ICON_SIZE + 3; end 
    f.nameWidthFull = FBNAME_WIDTH_FULL - f.indent - (nameX - 4); 
    f.nameWidthIcon = FBNAME_WIDTH_ICON - f.indent - (nameX - 4); 
    
    f:SetAlpha(FrameAlpha); 
    f:SetHeight(FrameHeight); 
    f:SetWidth(f.plateW); 
    
    if (isPet) then 
        f.PetIcon = f:CreateTexture(nil, "OVERLAY"); 
        f.PetIcon:SetWidth(FBPET_ICON_SIZE); 
        f.PetIcon:SetHeight(FBPET_ICON_SIZE); 
        f.PetIcon:SetPoint("LEFT", f, "LEFT", 4, 0); 
        f.PetIcon:SetTexture(FBPET_ICON); 
        f.PetIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93); 
    end 
    
    -- Name: linksbuendig, volle Breite. Nur solange ein Debuff-Icon zu sehen
    -- ist, wird die Box schmaler (FBHealBox_UpdateDebuffIcon).
    f.NameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); 
    -- Fest vertikal zentriert mit Einzeilen-Hoehe: so kann ein internes
    -- Umbrechen des Textfelds den Namen nicht nach unten schieben.
    f.NameText:SetPoint("LEFT", f, "LEFT", nameX, 0); 
    f.nameX = nameX; 
    f.NameText:SetHeight(FBNAME_HEIGHT); 
    f.NameText:SetJustifyH("LEFT"); 
    f.NameText:SetJustifyV("MIDDLE"); 
    f.NameText:SetText(""); 
    if (isPet) then 
        f.NameText:SetTextColor(FBPET_NAME_COLOR[1], FBPET_NAME_COLOR[2], FBPET_NAME_COLOR[3], FBPET_NAME_COLOR[4]); 
    else 
        f.NameText:SetTextColor(1, 1, 1, 1); 
    end 
    f.NameText:SetWidth(f.nameWidthFull); 
    
    -- Debuff-Icon rechts neben dem Namen, mit Stackzahl
    f.DebuffIcon = f:CreateTexture(nil, "OVERLAY"); 
    f.DebuffIcon:SetWidth(FBDEBUFF_ICON_SIZE); 
    f.DebuffIcon:SetHeight(FBDEBUFF_ICON_SIZE); 
    f.DebuffIcon:SetPoint("LEFT", f, "LEFT", nameX + f.nameWidthIcon + 3, 0); 
    f.DebuffIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93); 
    f.DebuffIcon:Hide(); 
    f.DebuffCount = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); 
    f.DebuffCount:SetPoint("BOTTOMRIGHT", f.DebuffIcon, "BOTTOMRIGHT", 3, -2); 
    f.DebuffCount:SetText(""); 
    f.DebuffCount:Hide(); 
    
    -- Sichtlinien-Abzeichen am linken Rand
    f.LOSIcon = f:CreateTexture(nil, "OVERLAY"); 
    f.LOSIcon:SetWidth(FBLOS_ICON_SIZE); 
    f.LOSIcon:SetHeight(FBLOS_ICON_SIZE); 
    f.LOSIcon:SetPoint("TOPLEFT", f, "TOPLEFT", FBLOS_ICON_X, FBLOS_ICON_Y); 
    f.LOSIcon:SetTexture(FBLOS_ICON); 
    f.LOSIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93); 
    f.LOSIcon:Hide(); 
    
    f.HPText = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalYellow"); 
    f.HPText:SetPoint("RIGHT", -5, 0); 
    f.HPText:SetText("100%"); 
    f.HPText:SetTextColor(1, 1, 1, 1); 
    
    f.HealthBar = CreateFrame("STATUSBAR", nil, f, "TextStatusBar");
    f.HealthBar:SetWidth(barW);
    f.HealthBar:SetHeight(NamePlateHeight - 5);
    f.HealthBar:SetPoint("TOPLEFT", 2, -3);
    f.HealthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
    f.HealthBar:SetMinMaxValues(0, UnitHealthMax(Unit));
    f.HealthBar:SetValue(UnitHealth(Unit));
    f.HealthBar:SetStatusBarColor(0, 1, 0, 1);
    f.HealthBar:Show();

    -- Absorb-Schild als halbtransparentes "Pseudoleben" hinter dem HP-Balken
    f.ShieldBar = CreateFrame("STATUSBAR", nil, f, "TextStatusBar");
    f.ShieldBar:SetWidth(barW);
    f.ShieldBar:SetHeight(NamePlateHeight - 5);
    f.ShieldBar:SetPoint("TOPLEFT", 2, -3);
    f.ShieldBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
    f.ShieldBar:SetMinMaxValues(0, UnitHealthMax(Unit));
    f.ShieldBar:SetValue(UnitHealth(Unit));
    f.ShieldBar:SetStatusBarColor(0.6, 0.8, 1.0, 0.5);
    f.ShieldBar:Show();

    -- Eingehende Heilung (Direktheilung + HoT-Restticks)
    f.IncHealBar = CreateFrame("STATUSBAR", nil, f, "TextStatusBar");
    f.IncHealBar:SetWidth(barW);
    f.IncHealBar:SetHeight(NamePlateHeight - 5);
    f.IncHealBar:SetPoint("TOPLEFT", 2, -3);
    f.IncHealBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
    f.IncHealBar:SetMinMaxValues(0, UnitHealthMax(Unit));
    f.IncHealBar:SetValue(UnitHealth(Unit));
    f.IncHealBar:SetStatusBarColor(0.4, 1, 0.4, 0.5);
    f.IncHealBar:Show();

    -- Fester Hintergrund hinter allen Balken. Er haengt bewusst an der
    -- untersten Bar: so liegt er unter Heilvorhersage, Schild, Leben und
    -- Mana, und er wird zusammen mit ihnen ein- und ausgeblendet.
    f.BarBG = f.IncHealBar:CreateTexture(nil, "BACKGROUND");
    f.BarBG:SetAllPoints(f.IncHealBar);
    f.BarBG:Hide();

    -- Manabalken: FBMANA_BAR_HEIGHT px am unteren Rand des Lebensbalkens,
    -- "Balken im Balken". Nur sichtbar bei Einheiten mit Mana.
    f.ManaBar = CreateFrame("STATUSBAR", nil, f, "TextStatusBar");
    f.ManaBar:SetWidth(barW);
    f.ManaBar:SetHeight(FBMANA_BAR_HEIGHT);
    f.ManaBar:SetPoint("BOTTOMLEFT", f.HealthBar, "BOTTOMLEFT", 0, 0);
    f.ManaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
    f.ManaBar:SetMinMaxValues(0, 1);
    f.ManaBar:SetValue(0);
    f.ManaBar:SetStatusBarColor(FBMANA_BAR_COLOR[1], FBMANA_BAR_COLOR[2], FBMANA_BAR_COLOR[3], FBMANA_BAR_COLOR[4]);
    -- dunkler Streifen dahinter, damit fehlendes Mana lesbar bleibt
    f.ManaBar.bg = f.ManaBar:CreateTexture(nil, "BACKGROUND");
    f.ManaBar.bg:SetAllPoints(f.ManaBar);
    f.ManaBar.bg:SetTexture(0, 0, 0, FBMANA_BG_ALPHA);
    f.ManaBar:Hide();

    -- Reihenfolge: Mana ganz oben, HP deckend, darunter Schild, darunter Heilvorhersage
    FBHealBox_SetBarStrata(f, "LOW");
    
    f:SetMovable(true); 
    f:EnableMouse(true); 
    f:SetScript("OnMouseDown", function() FBHealBox_PlateMouseDown(f); end); 
    f:SetScript("OnMouseUp", function() FBHealBox_PlateMouseUp(f); end); 
    
    return f; 
end 

-- ==========================================================================
-- [ Drag & Drop aus dem Zauberbuch ]
--
-- 1.12 kennt kein GetCursorInfo(). Das Zauberbuch ruft beim Ziehen
-- PickupSpell(id, book) auf; ein Vor-Hook merkt sich diese beiden Werte.
-- Loslassen auf einem Heil-Button (OnReceiveDrag oder Klick mit Zauber am
-- Cursor) belegt den Button: Linksklick-Feld, bei aktiviertem Rechtsklick-
-- Zauber und rechter Maustaste das Rechtsklick-Feld. Auch die Felder im
-- Optionsfenster nehmen Zauber an.
-- ==========================================================================

FBDragSpell = nil;   -- { id, book } des zuletzt aufgenommenen Zaubers

function FBHealBox_HookSpellPickup()
    if (FBHealBox_PickupHooked) then return; end
    FBHealBox_PickupHooked = true;
    if (PickupSpell) then
        local origPickup = PickupSpell;
        PickupSpell = function(id, book)
            FBDragSpell = { id = id, book = book or BOOKTYPE_SPELL };
            origPickup(id, book);
        end
    end
    if (ClearCursor) then
        local origClear = ClearCursor;
        ClearCursor = function()
            FBDragSpell = nil;
            origClear();
        end
    end
end

-- Zauber am Cursor: name, rank, id, book oder nil
function FBHealBox_CursorSpell()
    if (not FBDragSpell) then return nil; end
    if (CursorHasSpell and not CursorHasSpell()) then
        FBDragSpell = nil;
        return nil;
    end
    local name, rank = GetSpellName(FBDragSpell.id, FBDragSpell.book);
    if (not name) then return nil; end
    return name, rank, FBDragSpell.id, FBDragSpell.book;
end

-- Zauber vom Cursor auf Button btnIndex legen. side = "L" oder "R".
-- true, wenn etwas belegt wurde.
function FBHealBox_DropSpell(btnIndex, side)
    if (not btnIndex) then return false; end
    local name, rank, id, book = FBHealBox_CursorSpell();
    if (not name) then
        if (FBDragSpell) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("DROP_UNKNOWN"));
        end
        return false;
    end
    side = side or "L";
    if (side == "R" and HealBox.RightClick ~= 1) then side = "L"; end

    -- Zauber in die Rangliste aufnehmen, falls er nicht aus der Klassenliste stammt
    if (not FBPlayerSpells[name]) then FBPlayerSpells[name] = {}; end
    local known = false;
    for _, sd in ipairs(FBPlayerSpells[name]) do
        if (sd.rank == rank) then known = true; break; end
    end
    if (not known) then
        table.insert(FBPlayerSpells[name], { rank = rank, id = id, icon = GetSpellTexture(id, book) });
    end

    local castString = name;
    if (rank and rank ~= "") then castString = name.."("..rank..")"; end

    local _, _, _, _, savedTable = FBChoiceTables(side);
    savedTable[btnIndex] = castString;
    FBApplySpellChoice(btnIndex, castString, side);
    FBPredict_BuildWatch();
    FBHealBoxButtonsChanged();

    local key = "DROP_SET";
    if (side == "R") then key = "DROP_SET_R"; end
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..format(FBT(key), btnIndex, castString));

    FBDragSpell = nil;
    if (ClearCursor) then ClearCursor(); end
    return true;
end

-- ==========================================================================
-- [ Automatisches Abrangen ]
--
-- Niedrigsten Rang des Zaubers waehlen, dessen erwartete Heilung das
-- fehlende Leben des Ziels (abzueglich schon eingehender Heilung) plus
-- Sicherheitsaufschlag deckt. Nie ueber dem belegten Rang, nur fuer
-- Direktheilungen, im Notfall (unter VeryLowHP) immer der belegte Rang.
-- Erwartete Heilung: gelernter Wert, sonst Tooltip-Mittelwert.
-- ==========================================================================

-- Heilung ueber Zeit, alle Klassen. Smart Healing laesst diese Zauber in
-- Ruhe: Ein HoT heilt ueber viele Sekunden verteilt, das im Moment des
-- Klicks fehlende Leben sagt also nichts darueber aus, welcher Rang passt.
-- Ein abgerangtes Erneuerung tickt die volle Laufzeit zu schwach, und der
-- Nachschlag laesst sich nicht mehr aufholen. Gemischte Zauber (Nachwachsen:
-- Sofortheilung plus HoT) zaehlen ebenfalls als HoT.
-- Ergaenzt wird die Liste zur Laufzeit aus dem Tooltip (info.hot), aus der
-- Zauberwache und aus laufenden HoTs, deshalb greift die Ausnahme auch bei
-- Zaubern, die hier nicht stehen (z. B. auf lokalisierten Clients).
FBHoTSpells = {
    -- Priester
    ["Renew"] = true,
    -- Druide
    ["Rejuvenation"] = true, ["Regrowth"] = true, ["Tranquility"] = true,
    ["Lifebloom"] = true, ["Wild Growth"] = true,
    -- Schamane
    ["Riptide"] = true, ["Earth Shield"] = true, ["Healing Stream Totem"] = true,
    -- deutsche Zaubernamen (Umlaute als Bytefolge, damit die Datei auf jedem
    -- Client passt: einmal UTF-8, einmal Latin-1)
    ["Erneuerung"] = true, ["Nachwachsen"] = true, ["Gelassenheit"] = true,
    ["Wildwuchs"] = true, ["Springflut"] = true, ["Erdschild"] = true,
    ["Verj\195\188ngung"] = true, ["Verj\252ngung"] = true,
    ["Lebensbl\195\188te"] = true, ["Lebensbl\252te"] = true,
};

-- Ist das ein Zauber mit Heilung ueber Zeit?
function FBHealBox_IsHoT(base, ranks)
    if (not base) then return false; end
    if (FBHoTSpells[base]) then return true; end
    -- aus dem Zauberbuch gelesen: irgendein Rang hat einen HoT-Anteil
    local w = FBPredictWatch and FBPredictWatch[base];
    if (w and w.hasHoT) then return true; end
    if (ranks) then
        for _, sd in ipairs(ranks) do
            local info = FBPredict_GetSpellInfo(sd.id, base);
            if (info and info.hot) then return true; end
        end
    end
    -- laeuft gerade als HoT auf irgendjemandem (aus dem Combatlog gelernt)
    for _, spells in pairs(FBHoTs) do
        if (spells[base]) then return true; end
    end
    return false;
end

-- ==========================================================================
-- [ Heilketten ]
--
-- Welche Zauber gelten als "derselbe Heilzauber, nur kleiner"? Innerhalb
-- einer Kette darf Smart Healing die Zaubergrenze ueberschreiten: Grosse
-- Heilung (Rang 2) kann als Geringes Heilen (Rang 3) rausgehen, wenn das
-- reicht. Nur Einzelziel-Direktheilungen gehoeren hinein. Draussen bleiben
-- Gruppenheilungen (Gebet der Heilung, Kettenheilung), HoTs, Schilde und
-- Zauber mit Abklingzeit (Heiliger Schock, Handauflegung, Verjuengungs-
-- zauber), die man nicht ungefragt verbraten will.
--
-- Die Liste ist flach: Zaubernamen sind zwischen den Klassen eindeutig,
-- eine Klassenzuordnung braucht es also nicht. Ketten mit nur einem Eintrag
-- stehen der Uebersicht halber trotzdem drin.
-- ==========================================================================

FBHealChains = {
    -- Priester
    { "Lesser Heal", "Heal", "Greater Heal" },
    -- Paladin
    { "Flash of Light", "Holy Light" },
    -- Schamane
    { "Lesser Healing Wave", "Healing Wave" },
    -- Druide (Nachwachsen ist ein HoT und bleibt draussen)
    { "Healing Touch" },
    -- deutsche Zaubernamen, einmal Latin-1 und einmal UTF-8 fuer die
    -- Sonderzeichen (\223 = ss-Ligatur, \252 = u-Umlaut)
    { "Geringes Heilen", "Heilen", "Gro\223e Heilung", "Gro\195\159e Heilung" },
    { "Blitz des Lichts", "Heiliges Licht" },
    { "Geringe Welle der Heilung", "Welle der Heilung" },
    { "Heilende Ber\252hrung", "Heilende Ber\195\188hrung" },
};

-- [Zaubername] = seine Kette
FBHealChainOf = {};
for _, chain in ipairs(FBHealChains) do
    for _, n in ipairs(chain) do
        if (not FBHealChainOf[n]) then FBHealChainOf[n] = chain; end
    end
end

-- Erwartete Heilung eines Rangs, oder nil, wenn der Zauber fuer Smart
-- Healing nicht in Frage kommt: kein Heilbetrag, Schild, HoT-Anteil, Buff
-- oder kein Heiltext im Tooltip. Gelernter Wert schlaegt den Tooltip.
function FBHealBox_DirectAmount(spellName, sd)
    if (not sd) then return nil; end
    local info = FBPredict_GetSpellInfo(sd.id, spellName);
    if (not info) or (not info.direct) or info.shield or info.hot or (not info.isHeal) then return nil; end
    return FBPredict_ExpectedDirect(spellName, sd.rank, info, sd.id);
end

-- Alle Zauber, die als kleinere Ausgabe von base gelten (base immer dabei)
function FBHealBox_HealFamily(base)
    if (HealBox.SmartCross ~= 1) then return { base }; end
    return FBHealChainOf[base] or { base };
end

function FBHealBox_SmartRank(castString, unit)
    if (HealBox.SmartRank ~= 1) or (not castString) then return castString; end
    local base, rank = FBPredict_SplitCast(castString);
    if (not rank) then return castString; end
    local ranks = FBPlayerSpells[base];
    if (not ranks) then return castString; end

    -- HoTs aller Klassen bleiben unangetastet
    if (FBHealBox_IsHoT(base, ranks)) then
        if (FBPredictDebug) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..format(FBT("DBG_SMART_HOT"), castString));
        end
        return castString;
    end
    if (not FBUnitExists(unit)) or FBTest_Ghost(unit) then return castString; end

    local hp, hpMax = FBUnitHealth(unit);
    if (hpMax <= 0) or ((hp / hpMax) <= VeryLowHP) then return castString; end
    local name = FBUnitName(unit);
    -- Anfliegende Heilung wird abgezogen, aber nur die, die gleich ankommt:
    -- Direktheilungen und ueber HealComm gemeldete Zauber landen in ein bis
    -- drei Sekunden. Laufende HoTs zaehlen bewusst nicht mit. Ein Erneuerung
    -- verteilt seine Heilung ueber fuenfzehn Sekunden, die volle Summe als
    -- gegeben anzunehmen liesse den Fehlbetrag winzig aussehen: Aus einem
    -- Heilen Rang 4 wuerde ein Geringes Heilen, obwohl das Ziel jetzt Leben
    -- braucht und nicht in einer Viertelminute. Auf dem Balken wird der HoT
    -- selbstverstaendlich weiter angezeigt, er geht nur nicht in die
    -- Rangwahl ein.
    local incoming = FBGetDirectHeal(name) + FBGetCommHeal(name);
    local deficit = hpMax - hp - incoming;
    if (deficit < 0) then deficit = 0; end
    local need = deficit * (1 + (HealBox.SmartMargin or 20) / 100);

    -- Der belegte Rang ist Obergrenze und Rueckfall zugleich
    local assignedSD = nil;
    for _, sd in ipairs(ranks) do
        if (sd.rank == rank) then assignedSD = sd; end
    end
    local cap = FBHealBox_DirectAmount(base, assignedSD);
    if (not cap) then return castString; end

    -- Kleinsten Kandidaten suchen, der den Bedarf deckt und nicht mehr
    -- heilt als der belegte Rang. Gleichstand behaelt den belegten Zauber.
    local bestSD, bestName, bestAmount = assignedSD, base, cap;
    for _, spellName in ipairs(FBHealBox_HealFamily(base)) do
        local list = FBPlayerSpells[spellName];
        if (list) and ((spellName == base) or (not FBHealBox_IsHoT(spellName, list))) then
            for _, sd in ipairs(list) do
                local amount = FBHealBox_DirectAmount(spellName, sd);
                if (amount) and (amount >= need) and (amount < bestAmount) then
                    bestSD, bestName, bestAmount = sd, spellName, amount;
                end
            end
        end
    end

    if (bestSD == assignedSD) then return castString; end
    local chosen = bestName;
    if (bestSD.rank and bestSD.rank ~= "") then chosen = bestName.."("..bestSD.rank..")"; end
    if (chosen == castString) then return castString; end
    if (FBPredictDebug) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..format(FBT("DBG_SMARTRANK"),
            castString, chosen, math.floor(deficit), math.floor(bestAmount)));
    end
    return chosen;
end

-- Zauber castString auf das Ziel des Buttons wirken (Links- oder Rechtsklick)
function FBHealBox_CastOn(button, castString)
    if (not castString) then return; end
    local castTarget = button.TargetUnit or "player";

    -- Geisterspieler: nichts casten, nur Hinweis
    if (FBTest_Ghost(castTarget)) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("TEST_CLICK"));
        return;
    end

    if (castTarget == "player") then
        castString = FBHealBox_SmartRank(castString, "player");
        -- Ziel VOR dem Cast merken: SPELLCAST_START feuert sofort
        FBPredict_NoteCast(castString, UnitName("player"));
        CastSpellByName(castString, 1);
        return;
    end

    if (not UnitExists(castTarget)) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000"..FBADDON_NAME..":|r "..castTarget..FBT("NOT_IN_GROUP"));
        return;
    end

    castString = FBHealBox_SmartRank(castString, castTarget);

    if (SUPERWOW_VERSION or SUPERWOW_STRING) then
        FBPredict_NoteCast(castString, UnitName(castTarget));
        CastSpellByName(castString, castTarget);
    else
        local hadTarget = UnitExists("target");
        local targetWasSame = false;
        if (hadTarget and UnitIsUnit) then
            targetWasSame = UnitIsUnit("target", castTarget);
        end
        if (not targetWasSame) then TargetUnit(castTarget); end
        FBPredict_NoteCast(castString, UnitName(castTarget));
        CastSpellByName(castString);
        if (not targetWasSame) then
            if (hadTarget) then TargetLastTarget(); else ClearTarget(); end
        end
    end
end

function FBHealBoxCreateButton(FBButtonName, FBParentFrame, xoffset, yoffset, texture, tooltiptext, targetUnit, spellID) 
    if (not FBButtonName) or (FBButtonName == "") then 
        FBButtonName = nil;   -- namenlos statt "Button"..random(): keine Kollisionen mit fremden Globals
    end 
    
    local button = CreateFrame("Button", FBButtonName, FBParentFrame); 
    button:SetPoint("LEFT", FBParentFrame, "RIGHT", xoffset, yoffset); 
    
    button.icon = button:CreateTexture(nil, "BACKGROUND"); 
    button.icon:SetAllPoints(); 
    
    -- Cooldown-Uhr (Blizzards Modell, wie auf den Aktionsleisten)
    button.cooldown = CreateFrame("Model", nil, button, "CooldownFrameTemplate"); 
    button.cooldown:SetAllPoints(button); 
    button.cooldown:Hide(); 
    
    -- HoT-/Schild-Restzeit
    button.timer = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); 
    button.timer:SetPoint("TOP", button, "TOP", 0, -1); 
    button.timer:Hide(); 
    
    -- Eck-Icon fuer den Rechtsklick-Zauber (nur sichtbar, wenn belegt und aktiviert)
    button.subIcon = button:CreateTexture(nil, "OVERLAY"); 
    button.subIcon:SetWidth(12); 
    button.subIcon:SetHeight(12); 
    button.subIcon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1); 
    button.subIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93); 
    button.subIcon:Hide(); 
    
    local highlight = button:CreateTexture(nil, "HIGHLIGHT"); 
    highlight:SetAllPoints(); 
    highlight:SetBlendMode("ADD"); 
    highlight:SetTexture("Interface/Buttons/ButtonHilight-Square"); 
    
    button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress"); 
    
    if (texture) then 
        button.icon:SetTexture(texture); 
    else 
        button.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark"); 
    end 
    
    button:EnableMouse(1); 
    button:SetHeight(28); 
    button:SetWidth(28); 
    button.TargetUnit = targetUnit; 
    button.spellName = tooltiptext; 
    button.id = spellID; 
    
    button:SetScript("OnEnter", function() 
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT", -30, 5); 
        if (button.spellName == nil or button.id == nil) then  
            GameTooltip:SetText(FBT("TT_NO_SPELL")); 
        else 
            GameTooltip_SetDefaultAnchor(GameTooltip, this); 
            GameTooltip:SetSpell(this.id, SpellBookFrame.bookType); 
            local tname = FBUnitName(this.TargetUnit) or "?"; 
            GameTooltip:AddLine(FBADDON_NAME.." "..FBT("TT_TARGET")..": |cFF00FF00"..tname, 1, 1, 1); 
        end 
        if (button.spellNameR) then 
            GameTooltip:AddLine(FBT("TT_RIGHT")..": |cFFFFFFFF"..button.spellNameR, 0.6, 0.8, 1); 
        end 
        GameTooltip:Show(); 
    end); 
    
    button:SetScript("OnLeave", function() 
        GameTooltip:Hide(); 
    end); 
    
    -- Beide Maustasten: Rechtsklick wird fuer Drag & Drop immer gebraucht,
    -- fuer den Rechtsklick-Zauber prueft OnClick die Option selbst
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp"); 
    
    button:SetScript("OnClick", function()
        -- Zauber am Cursor: belegen statt casten (rechts oder Shift = Rechtsklick-Seite)
        if (FBDragSpell and button.btnIndex) then
            local side = "L";
            if (arg1 == "RightButton" or IsShiftKeyDown()) then side = "R"; end
            if (FBHealBox_DropSpell(button.btnIndex, side)) then return; end
        end
        local castString = button.spellName;
        if (arg1 == "RightButton") then
            -- Rechtsklick-Zauber nur, wenn die Option an ist
            if (HealBox.RightClick ~= 1) then return; end
            castString = button.spellNameR;
        end
        FBHealBox_CastOn(button, castString);
    end);
    button:SetScript("OnReceiveDrag", function()
        if (button.btnIndex) then
            local side = "L";
            if (IsShiftKeyDown()) then side = "R"; end
            FBHealBox_DropSpell(button.btnIndex, side);
        end
    end);
    
    -- Kein eigener Event-Handler je Button mehr: der Kern aktualisiert alle
    -- sichtbaren Buttons zentral in FBHealBox_UpdateButtonStates (ein
    -- IsUsableSpell/GetSpellCooldown je Zauber statt je Button).
    return button; 
end 

function FBHealBoxSetup() 
    local bg = "Interface/DialogFrame/UI-DialogBox-Background"; 
    -- Spieler-Plaketten FBHealBox1..5, Begleiter-Plaketten FBHealBoxPet1..5.
    -- Alle haengen an FBHealBox1: die wird verschoben, der Rest folgt.
    FBHealBox1 = FBHealBoxCreateFrame("FBHealBox1", UIParent, bg, NamePlateWidth, NamePlateHeight, 1, "player", false); 
    FBPartyFrame[1] = FBHealBox1; 
    for p = 2, FBSlotCount do 
        local name; 
        if (FBSlotIsPet[p]) then name = "FBHealBoxPet"..(p - 5); else name = "FBHealBox"..p; end 
        FBPartyFrame[p] = FBHealBoxCreateFrame(name, FBHealBox1, bg, NamePlateWidth, NamePlateHeight, 1, FBPartyUnit[p], FBSlotIsPet[p]); 
    end 
    FBHealBox2 = FBPartyFrame[2]; FBHealBox3 = FBPartyFrame[3]; 
    FBHealBox4 = FBPartyFrame[4]; FBHealBox5 = FBPartyFrame[5]; 
    FBHealBoxPet1 = FBPartyFrame[6]; FBHealBoxPet2 = FBPartyFrame[7]; FBHealBoxPet3 = FBPartyFrame[8]; 
    FBHealBoxPet4 = FBPartyFrame[9]; FBHealBoxPet5 = FBPartyFrame[10]; 
    HealBoxAttachMode(HealBox.AttachMode);  
end 

function FBHealBox_RefreshAllBars() 
    if (not FBHealBox1) or (not FBHealBox1.ShieldBar) then return; end
    for p = 1, FBSlotCount do 
        local unit = FBPartyUnit[p]; 
        if (FBUnitExists(unit)) then FBHealBox_UpdateUnit(unit, FBPartyFrame[p]); end 
    end 
    FBHealBox_RunHook("RefreshAllBars"); 
end 

-- Nur die Plaketten auffrischen, deren Einheit in der Namensliste steht.
--
-- Der 0,2-Sekunden-Takt setzte frueher ein einziges Dirty-Flag: Lief
-- irgendwo ein HoT-Tick ab, wurde alles neu gezeichnet, im Vierzigerraid
-- also vierzig Zellen, obwohl sich bei genau einer Einheit etwas geaendert
-- hatte. Jetzt sammelt der Takt die betroffenen Namen ein und nur die werden
-- angefasst. Die Schleife selbst bleibt, sie kostet nur einen Tabellen-
-- zugriff je Plakette; teuer war immer die Aktualisierung dahinter.
function FBHealBox_RefreshUnitsByName(names)
    if (not FBHealBox1) or (not FBHealBox1.ShieldBar) or (not names) then return; end
    for p = 1, FBSlotCount do
        local unit = FBPartyUnit[p];
        if (FBUnitExists(unit)) then
            local n = FBUnitName(unit);
            if (n and names[n]) then FBHealBox_UpdateUnit(unit, FBPartyFrame[p]); end
        end
    end
    FBHealBox_RunHook("RefreshNames", names);
end 

-- Ist dieser Slot gerade anzuzeigen? (Begleiter nur mit ShowPets)
function FBSlotActive(p) 
    if (p == 1) then return true; end 
    if (FBSlotIsPet[p] and HealBox.ShowPets ~= 1) then return false; end 
    return FBUnitExists(FBPartyUnit[p]); 
end 

-- Plaketten senkrecht anordnen: in FBLayoutOrder (Besitzer, darunter sein
-- Begleiter), nur sichtbare Plaketten zaehlen, Abstand = HealBox.RowSpacing.
-- Im Party-Frame-Modus haengen die Slots an Blizzards Frames, dann nichts tun.
function FBHealBox_Layout() 
    if (not FBHealBox1) or (HealBox.AttachMode == 1) then return; end 
    local gap = HealBox.RowSpacing or 4; 
    local prev = FBHealBox1; 
    for _, p in ipairs(FBLayoutOrder) do 
        if (p ~= 1) then 
            local f = FBPartyFrame[p]; 
            f:ClearAllPoints(); 
            -- Begleiter ruecken ein, der naechste Spieler rueckt wieder aus
            local xShift = (f.indent or 0) - (prev.indent or 0); 
            f:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", xShift, -gap); 
            if (f:IsShown()) then prev = f; end 
        end 
    end 
end 

-- Alle vorhandenen Einheiten einmal aktiv nach Buffs scannen: nach /reload
-- oder Gruppenwechsel kommt sonst kein UNIT_AURA, bis sich etwas aendert.
function FBPredict_ScanAllUnits() 
    if (not FBPredict_ScanUnit) or FBTestMode then return; end 
    for p = 1, FBSlotCount do 
        local unit = FBPartyUnit[p]; 
        if (UnitExists(unit)) then FBPredict_ScanUnit(unit); end 
    end 
end 

function FBUpdateNames() 
    if (not FBHealBox1) then return; end 
    if (FBAddonSuppressed) then FBHealBox_HideAll(); return; end 
    for p = 1, FBSlotCount do 
        local f = FBPartyFrame[p]; 
        f:Hide(); 
        -- Einheit kann gewechselt haben: Zwischenspeicher der Anzeige leeren
        f.dispelKnown = nil; f.lastText = nil; f.lastMax = nil; f.colorKey = nil; f.manaShown = nil; 
        f.vHp = nil; f.vShield = nil; f.vInc = nil; f.vMp = nil; 
    end 
    
    if (HealBox.Active == 1) then FBHealBox1:Show(); end 
    FBHealBox1.NameText:SetText(strupper(FBUnitName("player") or "")); 
    FBHealBox_ApplyNameColor("player", FBHealBox1); 
    
    for p = 2, FBSlotCount do 
        local f = FBPartyFrame[p]; 
        if (FBSlotActive(p)) then 
            f.NameText:SetText(strupper(FBUnitName(FBPartyUnit[p]) or "")); 
            FBHealBox_ApplyNameColor(FBPartyUnit[p], f); 
            f:Show(); 
        end 
    end 
    
    FBHealBox_Layout(); 
    FBPredict_ScanAllUnits(); 
    FBHealBox_CheckAllWatchBuffs(); 
    FBHealBox_CheckRangeAll(); 
    FBHealBox_CheckLOSAll(); 
    FBHealBox_RefreshAllBars(); 
    FBHealBox_RunHook("UpdateNames"); 
    FBHealBox_UpdateButtonStates("SPELL_UPDATE_USABLE"); 
end 

-- Name in Klassenfarbe (Spieler) bzw. Pet-Farbe (Begleiter)
function FBHealBox_ApplyNameColor(unit, f) 
    if (not f) or (not f.NameText) then return; end 
    if (f.isPet) then 
        f.NameText:SetTextColor(FBPET_NAME_COLOR[1], FBPET_NAME_COLOR[2], FBPET_NAME_COLOR[3], FBPET_NAME_COLOR[4]); 
        return; 
    end 
    local c = nil; 
    if (HealBox.ClassColors == 1) then c = FBClassColor(FBUnitClassToken(unit)); end 
    if (c) then 
        f.NameText:SetTextColor(c.r, c.g, c.b, 1); 
    else 
        f.NameText:SetTextColor(1, 1, 1, 1); 
    end 
end 

-- Alle Namen neu einfaerben (Schalter umgelegt)
function FBHealBox_ApplyAllNameColors() 
    for p = 1, FBSlotCount do 
        if (FBPartyFrame[p]) then FBHealBox_ApplyNameColor(FBPartyUnit[p], FBPartyFrame[p]); end 
    end 
end 

-- ==========================================================================
-- [ Buff-Wache ]
--
-- Fehlt der gewaehlte Buff (oder seine Gruppenversion), wird der Rahmen der
-- Plakette orange. Geprueft wird bei UNIT_AURA und nach Gruppenwechseln:
-- zuerst schnell ueber die Buff-Textur (Zauberbuch-Icon), und nur wenn die
-- nicht passt ueber den Buff-Namen aus dem Tooltip. So faellt auch die
-- Gruppenversion eines anderen Heilers auf, deren Textur wir nicht kennen.
-- ==========================================================================

function FBHealBox_SetWatchBuff(spellName) 
    HealBox.WatchBuff = spellName; 
    FBHealBox_UpdateBuffWatchLabel(); 
    FBHealBox_CheckAllWatchBuffs(); 
end 

function FBHealBox_UpdateBuffWatchLabel() 
    if (not FBBuffWatchBtn) then return; end 
    local shown = HealBox.WatchBuff or FBT("BUFFWATCH_NONE"); 
    FBBuffWatchBtn.text:SetText(FBT("BUFFWATCH") .. ": |cFFFFFFFF" .. shown); 
    local sd = HealBox.WatchBuff and FBBuffSpells[HealBox.WatchBuff]; 
    if (sd and sd.icon) then 
        FBBuffWatchBtn.icon:SetTexture(sd.icon); 
    else 
        FBBuffWatchBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); 
    end 
end 

function FBHealBox_UpdatePlateActionLabels() 
    if (FBPlateLeftBtn) then 
        FBPlateLeftBtn.text:SetText(FBT("PLATE_LEFT") .. ": |cFFFFFFFF" .. FBT(FBPlateActionName[HealBox.PlateLeft or "target"])); 
    end 
    if (FBPlateRightBtn) then 
        FBPlateRightBtn.text:SetText(FBT("PLATE_RIGHT") .. ": |cFFFFFFFF" .. FBT(FBPlateActionName[HealBox.PlateRight or "target"])); 
    end 
end 

-- Buff-Texturen einer Einheit, je Frame nur einmal gelesen: Vorhersage-Scan
-- und Buff-Wache brauchen dieselbe Liste im selben Event.
-- Grossschreibung von Texturpfaden einmal merken. Die Pfade wiederholen sich
-- staendig, strupper legt sonst bei jedem Aufruf einen neuen String an, der
-- gleich wieder Muell ist. Die Tabelle bleibt klein: es gibt nur so viele
-- Eintraege wie unterschiedliche Buff-Texturen.
FBTexUpperMemo = {};
function FBHealBox_UpperTex(tex)
    if (not tex) then return nil; end
    local u = FBTexUpperMemo[tex];
    if (not u) then u = strupper(tex); FBTexUpperMemo[tex] = u; end
    return u;
end

FBBuffScanMemo = {};   -- [unit] = { t, tex = {}, list = {}, n }
function FBHealBox_UnitBuffs(unit)
    local now = GetTime();
    local m = FBBuffScanMemo[unit];
    if (m and m.t == now) then return m.tex, m.list, m.n; end
    if (not m) then m = { tex = {}, list = {}, n = 0 }; FBBuffScanMemo[unit] = m; end
    for k in pairs(m.tex) do m.tex[k] = nil; end
    local i = 1;
    while (i <= 32) do
        local tex = UnitBuff(unit, i);
        if (not tex) then break; end
        tex = FBHealBox_UpperTex(tex);
        m.tex[tex] = true;
        m.list[i] = tex;
        i = i + 1;
    end
    m.n = i - 1;
    m.t = now;
    return m.tex, m.list, m.n;
end

-- Buffname je Textur, einmal per Tooltip gelesen und dann gemerkt: erspart
-- bis zu 32 Tooltip-Scans je UNIT_AURA bei Einheiten ohne den Buff.
FBBuffNameByTex = {};

-- Name eines Buffs ueber den Scan-Tooltip lesen
function FBHealBox_BuffName(unit, index) 
    if (not FBPredictTip) or (not FBPredictTip.SetUnitBuff) then return nil; end 
    FBPredictTip:SetOwner(UIParent, "ANCHOR_NONE"); 
    FBPredictTip:ClearLines(); 
    FBPredictTip:SetUnitBuff(unit, index); 
    local fs = getglobal("FBHealBoxScanTipTextLeft1"); 
    if (fs) then return fs:GetText(); end 
    return nil; 
end 

-- true, wenn die Einheit den ueberwachten Buff (oder die Gruppenversion) traegt
function FBHealBox_HasWatchBuff(unit) 
    local want = HealBox.WatchBuff; 
    if (not want) then return true; end 
    local g = FBTest_Ghost(unit); 
    if (g) then return (not g.buffMissing); end 
    
    local alt = FBBuffAlternates[want]; 
    local wantTex = FBBuffSpells[want] and strupper(FBBuffSpells[want].icon or ""); 
    local altTex  = alt and FBBuffSpells[alt] and strupper(FBBuffSpells[alt].icon or ""); 
    
    local texSet, list, n = FBHealBox_UnitBuffs(unit); 
    if (wantTex and texSet[wantTex]) then return true; end 
    if (altTex and texSet[altTex]) then return true; end 
    -- Textur nicht dabei: Namen pruefen (faengt fremde Gruppenversionen).
    -- Je Textur nur einmal per Tooltip, danach aus dem Speicher.
    for i = 1, n do 
        local tex = list[i]; 
        local name = FBBuffNameByTex[tex]; 
        if (name == nil) then 
            name = FBHealBox_BuffName(unit, i) or false; 
            FBBuffNameByTex[tex] = name; 
        end 
        if (name and (name == want or name == alt)) then return true; end 
    end 
    return false; 
end 

function FBHealBox_CheckWatchBuff(unit, f) 
    if (not f) or (not f.SetBackdropBorderColor) then return; end 
    local missing = false; 
    -- Begleiter nur, wenn ausdruecklich eingeschaltet
    local skipPet = (f.isPet and HealBox.BuffWatchPets ~= 1); 
    if (HealBox.WatchBuff and FBUnitExists(unit) and not f.plateHidden and not skipPet) then 
        missing = (not FBHealBox_HasWatchBuff(unit)); 
    end 
    if (f.buffMissing ~= missing) then 
        f.buffMissing = missing; 
        FBHealBox_ApplyBorder(f); 
    end 
end 

-- Rahmenfarbe einer Plakette: Angegriffener (rot) vor Buff-Wache (orange) vor normal
function FBHealBox_ApplyBorder(f) 
    if (not f) or (not f.SetBackdropBorderColor) then return; end 
    local c = FBBUFF_NORMAL_COLOR; 
    if (f.buffMissing) then c = FBBUFF_MISSING_COLOR; end 
    if (f.underAttack) then c = FBAGGRO_COLOR; end 
    f:SetBackdropBorderColor(c[1], c[2], c[3], c[4]); 
end 

-- ==========================================================================
-- [ Wer wird angegriffen ]
--
-- Hat dein Ziel ein feindliches Ziel im Ziel, bekommt dessen Plakette einen
-- roten Rahmen. Laeuft im 0.2-s-Takt der Vorhersage. Module haengen sich
-- ueber den Hook "Aggro" an (Raid-Zellen).
-- ==========================================================================

-- Unit-ID des Angegriffenen ("targettarget") oder nil
function FBHealBox_AggroUnit() 
    if (HealBox.AggroMark ~= 1) then return nil; end 
    if (not UnitExists("target")) or (not UnitExists("targettarget")) then return nil; end 
    if (UnitCanAttack and not UnitCanAttack("player", "target")) then return nil; end 
    return "targettarget"; 
end 

function FBHealBox_UnitIsAggro(unit, tt) 
    if (not tt) or (not unit) then return false; end 
    if (UnitIsUnit) then 
        local r = UnitIsUnit(tt, unit); 
        return (r == 1) or (r == true); 
    end 
    return (UnitName(tt) == UnitName(unit)); 
end 

FBAggroAny = false;   -- ist irgendwo ein roter Rahmen gesetzt?

-- Name des Angegriffenen je Tick einmal lesen; UnitIsUnit nur noch zur
-- Bestaetigung bei Namensgleichheit (statt je Plakette und Zelle)
FBAggroName = nil;

function FBHealBox_UnitIsAggroFast(unit, unitName, tt) 
    if (not tt) or (not unitName) then return false; end 
    if (FBAggroName ~= unitName) then return false; end 
    return FBHealBox_UnitIsAggro(unit, tt); 
end 

function FBHealBox_CheckAggroAll() 
    local tt = FBHealBox_AggroUnit(); 
    -- Kein feindliches Ziel und nichts markiert: nichts zu tun (haeufigster Fall)
    if (not tt) and (not FBAggroAny) and (not FBTestMode) then return; end 
    FBAggroName = tt and UnitName(tt); 
    local any = false; 
    for p = 1, FBSlotCount do 
        local f = FBPartyFrame[p]; 
        if (f) then 
            local flag = false; 
            local unit = FBPartyUnit[p]; 
            local g = FBTest_Ghost(unit); 
            if (HealBox.AggroMark == 1 and f:IsShown()) then 
                if (g) then flag = (g.aggro == true); 
                elseif (tt and FBUnitExists(unit)) then flag = FBHealBox_UnitIsAggroFast(unit, FBUnitName(unit), tt); end 
            end 
            if (f.underAttack ~= flag) then 
                f.underAttack = flag; 
                FBHealBox_ApplyBorder(f); 
            end 
            if (flag) then any = true; end 
        end 
    end 
    -- Module (Raid-Zellen) melden ueber den Rueckgabewert, ob sie noch markieren
    if (FBHealBox_RunHook("Aggro", tt)) then any = true; end 
    FBAggroAny = any; 
end 

-- ==========================================================================
-- [ HoT- und Schild-Timer auf den Buttons ]
--
-- Der Button eines Zaubers zeigt fuer seine Einheit die Restsekunden des
-- eigenen HoTs bzw. Schilds dieses Zaubers; nach dem Schild die Geschwaechte
-- Seele (15 s ab Anlegen) in Rot. Nur eigene Effekte, weil nur die verfolgt
-- werden. Module: Hook "SpellTimers".
-- ==========================================================================

-- Text und Farbe fuer einen Button, oder nil. base ist der Zaubername ohne
-- Rang (einmal in ButtonsChanged berechnet, nicht je Tick).
function FBHealBox_SpellTimerFor(base, unitName, now, g, btnIndex) 
    if (g) then 
        if (btnIndex == 1 and g.hotLeft) then return tostring(g.hotLeft), FBTIMER_COLOR_HOT; end 
        if (btnIndex == 2 and g.shieldLeft) then return tostring(g.shieldLeft), FBTIMER_COLOR_SHIELD; end 
        return nil; 
    end 
    if (not base) or (not unitName) then return nil; end 
    local hots = FBHoTs[unitName]; 
    local e = hots and hots[base]; 
    if (e and e.expires > now) then 
        return tostring(math.ceil(e.expires - now)), FBTIMER_COLOR_HOT; 
    end 
    local sh = FBShields[unitName]; 
    if (sh and sh.spell == base) then 
        if (sh.expires > now and (sh.max - sh.absorbed) > 0) then 
            return tostring(math.ceil(sh.expires - now)), FBTIMER_COLOR_SHIELD; 
        end 
        if (base == FBSHIELD_SPELL and sh.duration) then 
            local applied = sh.expires - sh.duration; 
            local left = applied + FBWEAKENED_SOUL_SEC - now; 
            if (left > 0) then return tostring(math.ceil(left)), FBTIMER_COLOR_WS; end 
        end 
    end 
    return nil; 
end 

function FBHealBox_FormatTimer(secs) 
    if (secs >= 60) then return math.ceil(secs / 60) .. "m"; end 
    return tostring(math.ceil(secs)); 
end 

function FBHealBox_SetButtonTimer(b, text, color) 
    if (not b) or (not b.timer) then return; end 
    if (text) then 
        if (b.timerText ~= text) then b.timerText = text; b.timer:SetText(text); end 
        if (b.timerColor ~= color) then b.timerColor = color; b.timer:SetTextColor(color[1], color[2], color[3], 1); end 
        if (not b.timerOn) then b.timerOn = true; b.timer:Show(); end 
    elseif (b.timerOn) then 
        b.timerOn = false; b.timerText = nil; 
        b.timer:Hide(); 
    end 
end 

function FBHealBox_UpdateSpellTimers() 
    local now = GetTime(); 
    local on = (HealBox.SpellTimers == 1); 
    -- Laeuft ueberhaupt ein eigener HoT oder Schild? Wenn nicht, gibt es auf
    -- den Plaketten nichts anzuzeigen, und die Schleife braucht nur noch dort
    -- hineinzuschauen, wo noch ein Timer wegzuraeumen ist. Spart bei Klassen
    -- ohne HoT und zwischen den Kaempfen zehn Namensabfragen fuenfmal je
    -- Sekunde. next() ist wahr, sobald die Tabelle einen Eintrag hat; leere
    -- Untertabellen raeumt der Takt in FBPredict_OnUpdate weg.
    local tracked = FBTestMode or (next(FBHoTs) ~= nil) or (next(FBShields) ~= nil); 
    for p = 1, FBSlotCount do 
        local f = FBPartyFrame[p]; 
        local unit = FBPartyUnit[p]; 
        if (f and FBPartyTable[p] and (tracked or f.timersShown)) then 
            local shown = on and f:IsShown() and FBUnitExists(unit); 
            local name = shown and FBUnitName(unit); 
            local g = shown and FBTest_Ghost(unit); 
            -- Ohne eigenen HoT oder Schild auf dieser Einheit gibt es nichts
            -- anzuzeigen: dann nur einmal alle Timer ausblenden und weiter.
            local active = shown and (g or FBHoTs[name] or FBShields[name]); 
            if (active) then 
                f.timersShown = true; 
                for i = 1, MaxButtonCount do 
                    local b = FBPartyTable[p][i]; 
                    if (b) then 
                        if (b:IsShown()) then 
                            local text, color = FBHealBox_SpellTimerFor(b.spellBase, name, now, g, i); 
                            if (not text and b.spellBaseR) then 
                                text, color = FBHealBox_SpellTimerFor(b.spellBaseR, name, now, nil, i); 
                            end 
                            FBHealBox_SetButtonTimer(b, text, color); 
                        else 
                            FBHealBox_SetButtonTimer(b, nil); 
                        end 
                    end 
                end 
            elseif (f.timersShown) then 
                f.timersShown = false; 
                for i = 1, MaxButtonCount do FBHealBox_SetButtonTimer(FBPartyTable[p][i], nil); end 
            end 
        end 
    end 
    FBHealBox_RunHook("SpellTimers", now); 
end 

-- ==========================================================================
-- [ Cooldown-Uhr ]
-- ==========================================================================

-- Cooldown eines Buttons frisch setzen (nach Umbelegung)
function FBHealBox_UpdateButtonCooldown(b) 
    if (not b) or (not b.cooldown) or (not CooldownFrame_SetTimer) then return; end 
    b.cdKey = nil; 
    if (not b.id) then 
        CooldownFrame_SetTimer(b.cooldown, 0, 0, 0); 
        b.cdKey = "off"; 
        return; 
    end 
    FBBtnPass = FBBtnPass + 1; 
    FBHealBox_UpdateButtonState(b, "SPELL_UPDATE_COOLDOWN"); 
end 

function FBHealBox_UpdateAllCooldowns() 
    FBBtnPass = FBBtnPass + 1; 
    for p = 1, FBSlotCount do 
        for i = 1, MaxButtonCount do 
            local b = FBPartyTable[p] and FBPartyTable[p][i]; 
            if (b) then b.cdKey = nil; FBHealBox_UpdateButtonState(b, "SPELL_UPDATE_COOLDOWN"); end 
        end 
    end 
    FBHealBox_RunHook("Cooldowns"); 
end 

function FBHealBox_CheckAllWatchBuffs() 
    for p = 1, FBSlotCount do 
        if (FBPartyFrame[p]) then FBHealBox_CheckWatchBuff(FBPartyUnit[p], FBPartyFrame[p]); end 
    end 
end 

-- ==========================================================================
-- [ Sichtlinie ]
--
-- Die 1.12-API kennt keine LoS-Abfrage. Zwei Wege:
--  1) UnitXP SP3 (Client-Mod): UnitXP("inSight", "player", unit), live.
--  2) Sonst merkt sich das Addon die Fehlermeldung SPELL_FAILED_LINE_OF_SIGHT
--     fuer das Ziel des letzten Heilversuchs (FBLOS_TIMEOUT Sekunden) und
--     loescht sie, sobald ein Cast auf die Einheit startet oder eine eigene
--     Heilung dort ankommt.
-- ==========================================================================

FBLOSFlags = {};   -- [Name] = Ablaufzeit der Markierung (Fallback-Weg)

function FBLOS_HasUnitXP()
    return (UnitXP ~= nil);
end

-- UnitXP sicher abfragen: true / false, nil wenn nicht verfuegbar
-- Ein Durchlauf hat geworfen, obwohl die Form sich vorher bewaehrt hatte.
-- Dann gehen alle drei Abfragen wieder in den geschuetzten Einzelaufruf: der
-- faengt den Fehler ab, liefert nil und der Rueckfallweg greift wie frueher.
-- Das Addon heilt sich also selbst, statt dauerhaft Fehler zu werfen.
function FBHealBox_ApiFailed()
    FBAPI_RangeDirect = false;
    FBAPI_DistDirect  = false;
    FBAPI_SightDirect = false;
end

-- Wie bei der Reichweite: der erste Aufruf geschuetzt, danach direkt.
FBAPI_SightDirect = false;
function FBLOS_QueryUnitXP(unit)
    if (not UnitXP) then return nil; end
    if (FBAPI_SightDirect) then return UnitXP("inSight", "player", unit); end
    local ok, res = pcall(UnitXP, "inSight", "player", unit);
    if (not ok) then return nil; end
    FBAPI_SightDirect = true;
    return res;
end

-- true, wenn die Einheit als ausserhalb der Sichtlinie gilt
function FBUnitLOSBlocked(unit)
    if (unit == "player") then return false; end
    local g = FBTest_Ghost(unit);
    if (g) then return (g.los == true); end
    if (not UnitExists(unit)) then return false; end

    local live = FBLOS_QueryUnitXP(unit);
    if (live ~= nil) then return (not live); end

    local name = UnitName(unit);
    local until_ = name and FBLOSFlags[name];
    if (until_ and GetTime() < until_) then return true; end
    if (until_) then FBLOSFlags[name] = nil; end
    return false;
end

-- Fehlermeldung "nicht in Sichtlinie": Ziel des letzten Heilversuchs markieren
function FBLOS_OnError(msg)
    if (not msg) then return; end
    local losText = SPELL_FAILED_LINE_OF_SIGHT or "Target not in line of sight";
    if (msg ~= losText) then return; end
    local name = FBPredict_ResolveTarget();
    if (not name) then return; end
    FBLOSFlags[name] = GetTime() + FBLOS_TIMEOUT;
    FBHealBox_CheckLOSAll();
end

function FBLOS_Clear(name)
    if (name and FBLOSFlags[name]) then
        FBLOSFlags[name] = nil;
        FBHealBox_CheckLOSAll();
    end
end

function FBHealBox_CheckLOSAll()
    if (not pcall(FBHealBox_CheckLOSSweep)) then FBHealBox_ApiFailed(); end
end

function FBHealBox_CheckLOSSweep()
    for p = 1, FBSlotCount do
        local f = FBPartyFrame[p];
        if (f and f.LOSIcon) then
            local blocked = false;
            if (HealBox.LOSIcon == 1 and f:IsShown() and not f.plateHidden) then
                blocked = FBUnitLOSBlocked(FBPartyUnit[p]);
            end
            if (f.losBlocked ~= blocked) then
                f.losBlocked = blocked;
                if (blocked) then f.LOSIcon:Show(); else f.LOSIcon:Hide(); end
            end
        end
    end
end

-- ==========================================================================
-- [ API-Fähigkeiten des Clients ]
--
-- IsSpellInRange und IsUsableSpell gibt es erst seit TBC (2.0). Der
-- 1.12-Client hat sie nicht; ein Aufruf bricht mit "attempt to call global"
-- ab. Diese Wrapper nutzen sie, wenn vorhanden (SuperWoW-artige Clients),
-- und fallen sonst auf 1.12-Mittel zurueck:
--   Reichweite: UnitXP("distanceBetween") gegen die Tooltip-Reichweite
--               ("40 yd range"), sonst CheckInteractDistance (28 m). Was
--               jenseits von 28 m nicht entscheidbar ist, gilt als unbekannt
--               (kein Rot), nicht als ausser Reichweite.
--   Nutzbarkeit: Manapreis aus dem Tooltip ("175 Mana") gegen das eigene Mana.
-- ==========================================================================

-- Signaturen unterscheiden sich je Client: 2.0 kennt (id, "spell", unit),
-- der Turtle-Client (name_oder_id, unit). Beim Einstieg wird mit pcall
-- ausprobiert, welche Form der Client versteht; keine -> 1.12-Rueckfall.
FBAPI_SpellRange  = false;   -- wird in FBHealBox_ProbeAPIs gesetzt
FBAPI_RangeForm   = nil;     -- 3 = (id, "spell", unit), 2 = (name, unit)
FBAPI_UsableSpell = false;
FBAPI_UsableForm  = nil;     -- 2 = (id, "spell"), 1 = (name)
FBAPI_Probed      = false;
FBSpellRangeCache = {};   -- [bookID] = Reichweite in Metern oder false
FBSpellCostCache  = {};   -- [bookID] = Manapreis oder false
FBSpellNameCache  = {};   -- [bookID] = Zaubername (fuer die Namensformen)

function FBHealBox_SpellNameOf(id)
    local n = FBSpellNameCache[id];
    if (n) then return n; end
    n = GetSpellName(id, BOOKTYPE_SPELL) or "";
    FBSpellNameCache[id] = n;
    return n;
end

-- Einmalig pruefen, welche Reichweiten-/Nutzbarkeitsfunktionen der Client
-- in welcher Form anbietet. Braucht ein gefuelltes Zauberbuch (Index 1).
function FBHealBox_ProbeAPIs()
    FBAPI_Probed = true;
    FBAPI_SpellRange = false; FBAPI_RangeForm = nil;
    FBAPI_UsableSpell = false; FBAPI_UsableForm = nil;
    -- Direktaufruf erst wieder erlauben, wenn eine Form sich bewaehrt hat
    FBAPI_RangeDirect = false; FBAPI_DistDirect = false; FBAPI_SightDirect = false;
    FBHealBox_ProbeHealBonus();
    if (type(IsSpellInRange) == "function") then
        local ok = pcall(IsSpellInRange, 1, BOOKTYPE_SPELL, "player");
        if (ok) then
            FBAPI_SpellRange = true; FBAPI_RangeForm = 3;
        else
            ok = pcall(IsSpellInRange, FBHealBox_SpellNameOf(1), "player");
            if (ok) then FBAPI_SpellRange = true; FBAPI_RangeForm = 2; end
        end
    end
    if (type(IsUsableSpell) == "function") then
        local ok = pcall(IsUsableSpell, 1, BOOKTYPE_SPELL);
        if (ok) then
            FBAPI_UsableSpell = true; FBAPI_UsableForm = 2;
        else
            ok = pcall(IsUsableSpell, FBHealBox_SpellNameOf(1));
            if (ok) then FBAPI_UsableSpell = true; FBAPI_UsableForm = 1; end
        end
    end
end

-- ==========================================================================
-- [ +Heilung aus der Ausruestung ]
--
-- Vanilla-Tooltips zeigen den Heilbonus der Ausruestung nicht, der Tooltip
-- eines Zaubers nennt also immer den nackten Grundwert. Gelernte Werte aus
-- dem Combatlog enthalten den Bonus dagegen von selbst, deshalb greift die
-- Rechnung hier nur bei Raengen, die noch nie gewirkt wurden.
--
-- Den Bonus liefert eine Zusatz-API, wenn eine da ist (ClassicAPI bringt
-- GetSpellBonusHealing mit). Gewichtet wird er wie in Vanilla ueblich mit
-- Zauberzeit geteilt durch 3,5, gedeckelt bei 3,5 Sekunden; Instants rechnen
-- mit 1,5 Sekunden. Ohne API bleibt der Bonus 0 und alles laeuft wie bisher.
-- ==========================================================================

FBAPI_HealBonusFn = nil;    -- gefundene Funktion oder nil
FBSpellCastCache  = {};     -- [bookID] = Zauberzeit in Sekunden oder false

function FBHealBox_ProbeHealBonus()
    FBAPI_HealBonusFn = nil;
    FBHealBonusValue = nil;
    local names = { "GetSpellBonusHealing", "GetSpellBonusHeal", "GetHealingBonus" };
    for _, n in ipairs(names) do
        local fn = getglobal(n);
        if (type(fn) == "function") then
            local ok, v = pcall(fn);
            if (ok) and (type(v) == "number") then FBAPI_HealBonusFn = fn; return; end
        end
    end
    -- ClassicAPI legt seine Nachbauten je nach Fassung in eine eigene Tabelle
    if (type(ClassicAPI) == "table") then
        local t = ClassicAPI.API or ClassicAPI;
        for _, n in ipairs(names) do
            local fn = t[n];
            if (type(fn) == "function") then
                local ok, v = pcall(fn);
                if (ok) and (type(v) == "number") then FBAPI_HealBonusFn = fn; return; end
            end
        end
    end
end

-- Aktueller +Heilung-Wert oder 0.
--
-- Der Wert aendert sich nur beim Ausruestungswechsel, wird aber bei einem
-- Smart-Healing-Klick fuer jeden Kandidaten gebraucht (mit Heilketten bis zu
-- fuenfzehn). Deshalb einmal lesen und merken; UNIT_INVENTORY_CHANGED und
-- der Zauberbuch-Neuaufbau werfen den Wert weg.
FBHealBonusValue = nil;

function FBHealBox_InvalidateHealBonus()
    FBHealBonusValue = nil;
end

function FBHealBox_HealingBonus()
    if (not FBAPI_Probed) then FBHealBox_ProbeAPIs(); end
    if (HealBox.HealBonus ~= 1) or (not FBAPI_HealBonusFn) then return 0; end
    if (FBHealBonusValue ~= nil) then return FBHealBonusValue; end
    local v;
    local ok, res = pcall(FBAPI_HealBonusFn);
    if (ok) and (type(res) == "number") and (res > 0) then v = res; else v = 0; end
    FBHealBonusValue = v;
    return v;
end

-- Zauberzeit aus dem Tooltip. Sie steht rechts in der zweiten Zeile
-- ("2.5 sec cast"), Instants stehen dort als "Instant cast". 0 = Instant.
function FBHealBox_SpellCastSeconds(id)
    if (not id) then return nil; end
    local c = FBSpellCastCache[id];
    if (c ~= nil) then return c or nil; end
    -- Regelfall ist der Treffer oben: FBPredict_TooltipText fuellt den
    -- Zwischenspeicher beim Auslesen der Zauberdaten mit. Hierher kommt nur,
    -- wer noch nie durch die Tooltip-Auswertung gelaufen ist.
    FBPredictTip:SetOwner(UIParent, "ANCHOR_NONE");
    FBPredictTip:ClearLines();
    FBPredictTip:SetSpell(id, BOOKTYPE_SPELL);
    local secs = nil;
    for i = 1, 6 do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = getglobal("FBHealBoxScanTipText"..side..i);
            if (fs and fs:IsShown()) then
                local t = fs:GetText();
                if (t) then
                    local _, _, v = string.find(t, "([%d%.]+)%s+[Ss]ec%s+cast");
                    if (v) then secs = tonumber(v); end
                    if (not secs) and string.find(t, "[Ii]nstant") then secs = 0; end
                end
            end
        end
    end
    FBSpellCastCache[id] = secs or false;
    return secs;
end

-- Anteil des +Heilung-Werts, der auf diesen Zauber entfaellt
function FBHealBox_HealBonusFor(bookID)
    local bonus = FBHealBox_HealingBonus();
    if (bonus <= 0) then return 0; end
    local secs = FBHealBox_SpellCastSeconds(bookID);
    if (not secs) then secs = 2.5; end    -- Zauberzeit unlesbar: mittlerer Wert
    if (secs <= 0) then secs = 1.5; end   -- Instants rechnen mit 1,5 Sekunden
    if (secs > 3.5) then secs = 3.5; end
    return bonus * (secs / 3.5);
end

-- Erwartete Sofortheilung eines Rangs: gelernter Wert, sonst Tooltip plus
-- anteiliger Ausruestungsbonus
function FBPredict_ExpectedDirect(spellName, rank, info, bookID)
    local learned = FBPredict_Remembered("direct", spellName, rank);
    if (learned) then return learned; end
    if (not info) or (not info.direct) then return nil; end
    return info.direct + FBHealBox_HealBonusFor(bookID);
end

-- Reichweite eines Zaubers aus dem Tooltip (Meter) oder nil
function FBHealBox_SpellRangeYards(id)
    local c = FBSpellRangeCache[id];
    if (c ~= nil) then return c or nil; end
    local txt = FBPredict_TooltipText and FBPredict_TooltipText(id) or "";
    local _, _, yd = string.find(txt, "(%d+)%s+[Yy]d");
    if (not yd) then _, _, yd = string.find(txt, "(%d+)%s+[Mm]eter"); end
    c = yd and tonumber(yd) or false;
    FBSpellRangeCache[id] = c;
    return c or nil;
end

-- Manapreis eines Zaubers aus dem Tooltip oder nil (Prozentkosten: nil)
function FBHealBox_SpellManaCost(id)
    local c = FBSpellCostCache[id];
    if (c ~= nil) then return c or nil; end
    local txt = FBPredict_TooltipText and FBPredict_TooltipText(id) or "";
    local _, _, cost = string.find(txt, "(%d+)%s+Mana");
    c = cost and tonumber(cost) or false;
    FBSpellCostCache[id] = c;
    return c or nil;
end

-- 1 = in Reichweite, 0 = ausserhalb, nil = nicht entscheidbar
function FBHealBox_SpellInRange(id, unit)
    if (not id) or (not unit) then return nil; end
    if (not FBAPI_Probed) then FBHealBox_ProbeAPIs(); end
    if (FBAPI_SpellRange) then
        local ok, r;
        -- Der erste Aufruf je Form laeuft geschuetzt. Danach ist bewiesen,
        -- dass der Client sie versteht, und pcall faellt weg: im Vierzigerraid
        -- waren das 80 geschuetzte Aufrufe je Sekunde nur fuer die Reichweite.
        if (FBAPI_RangeDirect) then
            ok = true;
            if (FBAPI_RangeForm == 3) then
                r = IsSpellInRange(id, BOOKTYPE_SPELL, unit);
            else
                r = IsSpellInRange(FBHealBox_SpellNameOf(id), unit);
            end
        elseif (FBAPI_RangeForm == 3) then
            ok, r = pcall(IsSpellInRange, id, BOOKTYPE_SPELL, unit);
        else
            ok, r = pcall(IsSpellInRange, FBHealBox_SpellNameOf(id), unit);
        end
        if (ok) then
            FBAPI_RangeDirect = true;
            if (r == 1 or r == true) then return 1; end
            if (r == 0 or r == false) then return 0; end
            return nil;
        end
        -- Client wirft doch: Funktion abschalten, Rueckfall nutzen
        FBAPI_SpellRange = false;
    end
    local range = FBHealBox_SpellRangeYards(id);
    if (UnitXP and range) then
        local ok, d;
        if (FBAPI_DistDirect) then
            ok = true; d = UnitXP("distanceBetween", "player", unit);
        else
            ok, d = pcall(UnitXP, "distanceBetween", "player", unit);
        end
        if (ok and type(d) == "number") then
            FBAPI_DistDirect = true;
            if (d <= range) then return 1; else return 0; end
        end
    end
    if (CheckInteractDistance) then
        if (CheckInteractDistance(unit, 4)) then return 1; end      -- naeher als 28 m
        if (range and range <= 28) then return 0; end               -- Nahzauber: sicher ausserhalb
        return nil;                                                  -- 28 bis 40 m: unbekannt
    end
    return nil;
end

-- isUsable, noMana (wie IsUsableSpell)
function FBHealBox_SpellUsable(id)
    if (not id) then return 1, nil; end
    if (not FBAPI_Probed) then FBHealBox_ProbeAPIs(); end
    if (FBAPI_UsableSpell) then
        local ok, u, nm;
        if (FBAPI_UsableForm == 2) then
            ok, u, nm = pcall(IsUsableSpell, id, BOOKTYPE_SPELL);
        else
            ok, u, nm = pcall(IsUsableSpell, FBHealBox_SpellNameOf(id));
        end
        if (ok) then return u, nm; end
        FBAPI_UsableSpell = false;
    end
    local cost = FBHealBox_SpellManaCost(id);
    if (cost) then
        local mp = UnitMana("player") or 0;
        if (UnitPowerType and UnitPowerType("player") == 0 and mp < cost) then return nil, 1; end
    end
    return 1, nil;
end

-- ==========================================================================
-- [ Reichweiten-Fading ]
--
-- Reichweite ist kein Event, also alle FBRANGE_INTERVAL Sekunden pruefen:
-- IsSpellInRange mit dem ersten belegten Button-Zauber; ohne Zauber
-- CheckInteractDistance(4) = 28 Meter. Ausser Reichweite -> ganze Plakette
-- samt Buttons auf FBRANGE_ALPHA.
-- ==========================================================================

FBRangeAccum = 0; 

-- Erster belegter Button: Zauber fuer die Reichweitenpruefung. Wird je
-- Einheit und Durchlauf gebraucht, im Vierzigerraid also hundertfach je
-- Sekunde, aendert sich aber nur beim Umbelegen. Also merken.
FBRangeSpellCached = nil;   -- false = keiner belegt, nil = neu suchen

function FBHealBox_InvalidateRangeSpell()
    FBRangeSpellCached = nil;
end

function FBHealBox_RangeSpellID() 
    if (FBRangeSpellCached ~= nil) then return FBRangeSpellCached or nil; end
    local found = false;
    for i = 1, MaxButtonCount do 
        if (FBActiveSpellIDs[i]) then found = FBActiveSpellIDs[i]; break; end 
    end 
    FBRangeSpellCached = found;
    return found or nil; 
end 

function FBHealBox_UnitInRange(unit) 
    if (unit == "player") then return true; end 
    local g = FBTest_Ghost(unit); 
    if (g) then return (not g.outOfRange); end 
    if (not UnitExists(unit)) then return true; end 
    local id = FBHealBox_RangeSpellID(); 
    if (id) then 
        local r = FBHealBox_SpellInRange(id, unit); 
        if (r == 0) then return false; end 
        if (r == 1) then return true; end 
    end 
    if (CheckInteractDistance) then 
        return (CheckInteractDistance(unit, 4) ~= nil); 
    end 
    return true; 
end 

-- Der Durchlauf selbst laeuft geschuetzt: ein pcall je Durchlauf statt eines
-- je Einheit. Das kostet praktisch nichts und haelt einen spaeten Fehler aus
-- den Reichweiten-Abfragen trotzdem vom Frame fern.
function FBHealBox_CheckRangeAll()
    if (not pcall(FBHealBox_CheckRangeSweep)) then FBHealBox_ApiFailed(); end
end

function FBHealBox_CheckRangeSweep() 
    for p = 1, FBSlotCount do 
        local f = FBPartyFrame[p]; 
        if (f) then 
            local faded = false; 
            if (HealBox.RangeFade == 1 and f:IsShown()) then 
                faded = (not FBHealBox_UnitInRange(FBPartyUnit[p])); 
            end 
            if (f.rangeFaded ~= faded) then 
                f.rangeFaded = faded; 
                if (faded) then f:SetAlpha(FBRANGE_ALPHA); else f:SetAlpha(1); end 
            end 
        end 
    end 
end 

-- Beschriftet die bereits gebaute Oberflaeche neu. Wird beim Bauen des
-- Optionsfensters, beim Laden der gespeicherten Sprache und bei jedem
-- Sprachwechsel aufgerufen. Ein /reload ist nie noetig.
function FBHealBox_ApplyLocale()
    if (MMButton) then MMButton.tooltipText = FBT("MM_TIP"); end
    if (not panel) then return; end

    panel.TitleText:SetText(FBADDON_NAME .. " " .. HealBoxVersion);
    panel.TitleSubText:SetText(format(FBT("PANEL_SUB"), FBADDON_NAME));
    panel.AboutText:SetText(format(FBT("ABOUT"), FBADDON_NAME, HealBoxVersion));

    for i = 1, MaxButtonCount, 1 do
        local b = FBSpellBtns[i];
        if (b) then
            if (b.label) then b.label:SetText(FBT("BUTTON") .. " " .. i); end
            -- belegte Buttons zeigen den Zaubernamen, der bleibt wie er ist
            if (not FBDropDownButton[i]) then b.text:SetText(FBT("SELECT_SPELL")); end
        end
        local r = FBSpellBtnsR[i];
        if (r and not FBDropDownButtonR[i]) then r.text:SetText(FBT("SELECT_SPELL")); end
    end
    if (panel.tabButtons) then
        for i, btn in ipairs(panel.tabButtons) do
            btn.text:SetText(FBT(panel.tabLabelKeys[i] or ""));
        end
    end
    if (panel.colLeft) then
        panel.colLeft:SetText(FBT("COL_LEFT"));
        panel.colRight:SetText(FBT("COL_RIGHT"));
    end

    FBUpdateButtonSliderText();
    FBUpdateScaleSliderText();
    FBUpdateSpacingSliderText();
    if (ScaleSlider) then
        getglobal(ScaleSlider:GetName() .. "Low"):SetText(FBT("SMALL"));
        getglobal(ScaleSlider:GetName() .. "High"):SetText(FBT("LARGE"));
    end

    if (AttachModeCheck) then
        AttachModeCheck.Text:SetText(FBT("ATTACH"));
        AttachModeCheck.tooltipText = FBT("ATTACH_TIP");
    end
    if (HealCommCheck) then
        HealCommCheck.Text:SetText(FBT("COMM"));
        HealCommCheck.tooltipText = FBT("COMM_TIP");
    end
    if (ManaBarCheck) then
        ManaBarCheck.Text:SetText(FBT("MANABAR"));
        ManaBarCheck.tooltipText = FBT("MANABAR_TIP");
    end
    if (ShowPetsCheck) then
        ShowPetsCheck.Text:SetText(FBT("SHOWPETS"));
        ShowPetsCheck.tooltipText = FBT("SHOWPETS_TIP");
    end
    if (TestModeCheck) then
        TestModeCheck.Text:SetText(FBT("TESTMODE"));
        TestModeCheck.tooltipText = FBT("TESTMODE_TIP");
    end
    if (ClassColorsCheck) then
        ClassColorsCheck.Text:SetText(FBT("CLASSCOLORS"));
        ClassColorsCheck.tooltipText = FBT("CLASSCOLORS_TIP");
    end
    if (RangeFadeCheck) then
        RangeFadeCheck.Text:SetText(FBT("RANGEFADE"));
        RangeFadeCheck.tooltipText = FBT("RANGEFADE_TIP");
    end
    if (DebuffIconCheck) then
        DebuffIconCheck.Text:SetText(FBT("DEBUFFICON"));
        DebuffIconCheck.tooltipText = FBT("DEBUFFICON_TIP");
    end
    if (LOSIconCheck) then
        LOSIconCheck.Text:SetText(FBT("LOSICON"));
        LOSIconCheck.tooltipText = FBT("LOSICON_TIP");
    end
    if (BuffWatchPetsCheck) then
        BuffWatchPetsCheck.Text:SetText(FBT("BUFFWATCH_PETS"));
        BuffWatchPetsCheck.tooltipText = FBT("BUFFWATCH_PETS_TIP");
    end
    if (RightClickCheck) then
        RightClickCheck.Text:SetText(FBT("RIGHTCLICK"));
        RightClickCheck.tooltipText = FBT("RIGHTCLICK_TIP");
    end
    if (SmartRankCheck) then
        SmartRankCheck.Text:SetText(FBT("SMARTRANK"));
        SmartRankCheck.tooltipText = FBT("SMARTRANK_TIP");
    end
    if (SmartCrossCheck) then
        SmartCrossCheck.Text:SetText(FBT("SMARTCROSS"));
        SmartCrossCheck.tooltipText = FBT("SMARTCROSS_TIP");
    end
    if (HidePartyCheck) then
        HidePartyCheck.Text:SetText(FBT("HIDEPARTY"));
        HidePartyCheck.tooltipText = FBT("HIDEPARTY_TIP");
    end
    if (PowerBarCheck) then
        PowerBarCheck.Text:SetText(FBT("POWERBAR"));
        PowerBarCheck.tooltipText = FBT("POWERBAR_TIP");
    end
    if (BarBGSlider) then
        getglobal(BarBGSlider:GetName() .. "Low"):SetText(FBT("BAR_BG_OFF"));
        getglobal(BarBGSlider:GetName() .. "High"):SetText(FBT("BAR_BG_FULL"));
        FBUpdateBarBGSliderText();
    end
    FBHealBox_UpdatePartyExclusion();
    FBUpdateSmartMarginText();
    FBHealBox_UpdateSmartCrossState();
    if (CooldownsCheck) then
        CooldownsCheck.Text:SetText(FBT("COOLDOWNS"));
        CooldownsCheck.tooltipText = FBT("COOLDOWNS_TIP");
    end
    if (AggroMarkCheck) then
        AggroMarkCheck.Text:SetText(FBT("AGGRO"));
        AggroMarkCheck.tooltipText = FBT("AGGRO_TIP");
    end
    if (SpellTimersCheck) then
        SpellTimersCheck.Text:SetText(FBT("TIMERS"));
        SpellTimersCheck.tooltipText = FBT("TIMERS_TIP");
    end
    if (BuffIconsCheck) then
        BuffIconsCheck.Text:SetText(FBT("BUFFICONS"));
        BuffIconsCheck.tooltipText = FBT("BUFFICONS_TIP");
    end
    FBHealBox_UpdateBuffWatchLabel();
    FBHealBox_UpdatePlateActionLabels();
    if (FBLangBtn) then
        FBLangBtn.text:SetText(FBT("LANGUAGE") .. ": |cFFFFFFFF" .. FBT("LANG_NAME"));
    end
    FBHealBox_RunHook("ApplyLocale");
end

-- [ Options-Fenster ] -- 
--
-- Zwei Reiter: "Buttons" (Belegung der zehn Buttons, Anzahl, Rechtsklick)
-- und "Allgemein" (Skalierung, Abstaende, Schalter, Sprache, Buff-Wache).
-- Jeder Reiter ist ein eigener Frame in Panelgroesse; die Koordinaten der
-- Steuerelemente beziehen sich damit weiterhin auf die linke obere Ecke.

FBOPT_TAB_Y      = -92;    -- Hoehe der Reiterleiste
FBOPT_TAB_W      = 100;    -- Breite eines Reiterknopfs
FBOPT_CHECK_TEXT_W = 170;  -- Breite der Schalterbeschriftungen (zwei Spalten je Reiter)
FBOPT_TAB_PITCH  = 104;    -- Abstand von Knopf zu Knopf (vier passen nebeneinander)
FBOPT_CONTENT_Y  = -128;   -- erste Inhaltszeile unter der Reiterleiste

-- Auswahlknopf mit Icon und Text (Zauberfelder, Sprache, Buff-Wache)
function FBHealBox_CreatePickButton(name, parent, x, y, width, height, iconSize)
    local btn = CreateFrame("Button", name, parent);
    btn:SetWidth(width);
    btn:SetHeight(height);
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
    btn:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    });
    btn:SetBackdropColor(0, 0, 0, 0.8);
    btn:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);

    btn.icon = btn:CreateTexture(nil, "ARTWORK");
    btn.icon:SetWidth(iconSize or 20);
    btn.icon:SetHeight(iconSize or 20);
    btn.icon:SetPoint("LEFT", 4, 0);
    btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0);
    btn.text:SetPoint("RIGHT", -6, 0);
    btn.text:SetJustifyH("LEFT");

    local hl = btn:CreateTexture(nil, "HIGHLIGHT");
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
    hl:SetBlendMode("ADD");
    hl:SetAllPoints(btn);
    return btn;
end

-- Reiter-Knopf
function FBHealBox_CreateTabButton(name, parent, x, index)
    local t = CreateFrame("Button", name, parent);
    t:SetWidth(FBOPT_TAB_W);
    t:SetHeight(24);
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, FBOPT_TAB_Y);
    t:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    });
    t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    t.text:SetPoint("CENTER", 0, 0);
    t.index = index;
    t:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn");
        FBHealBox_ShowTab(this.index);
    end);
    return t;
end

-- Neuen Reiter anlegen (auch fuer Module). Liefert den Inhalts-Frame, der
-- die Panelgroesse hat; Koordinaten wie im Panel, Inhalt ab FBOPT_CONTENT_Y.
function FBHealBox_AddOptionsTab(labelKey)
    if (not panel) or (not panel.tabs) then return nil; end
    local i = table.getn(panel.tabs) + 1;
    local tab = CreateFrame("Frame", "HealBoxOptionsTab"..i, panel);
    tab:SetAllPoints(panel);
    tab:Hide();
    panel.tabs[i] = tab;
    panel.tabLabelKeys[i] = labelKey;
    panel.tabButtons[i] = FBHealBox_CreateTabButton("HealBoxOptionsTabButton"..i, panel, 25 + (i - 1) * FBOPT_TAB_PITCH, i);
    panel.tabButtons[i].text:SetText(FBT(labelKey));
    if (panel.activeTab) then FBHealBox_ShowTab(panel.activeTab); end
    return tab;
end

-- Inhalts-Frame eines vorhandenen Reiters (fuer Module, die sich einen
-- Reiter teilen). nil, wenn es ihn nicht gibt.
function FBHealBox_FindOptionsTab(labelKey)
    if (not panel) or (not panel.tabs) then return nil; end
    for i, key in ipairs(panel.tabLabelKeys) do
        if (key == labelKey) then return panel.tabs[i]; end
    end
    return nil;
end

function FBHealBox_ShowTab(index)
    if (not panel) or (not panel.tabs) then return; end
    FBMenu_CloseAll();
    panel.activeTab = index;
    for i, tab in ipairs(panel.tabs) do
        local btn = panel.tabButtons[i];
        if (i == index) then
            tab:Show();
            btn:SetBackdropColor(0.15, 0.12, 0.02, 0.9);
            btn:SetBackdropBorderColor(1, 0.82, 0, 1);
            btn.text:SetTextColor(1, 0.82, 0, 1);
        else
            tab:Hide();
            btn:SetBackdropColor(0, 0, 0, 0.8);
            btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1);
            btn.text:SetTextColor(0.7, 0.7, 0.7, 1);
        end
    end
end

-- Rechtsklick an/aus: zweite Spalte und Spaltenkoepfe im Buttons-Reiter
function FBHealBox_ApplyRightClickLayout()
    if (not panel) or (not panel.colLeft) then return; end
    local on = (HealBox.RightClick == 1);
    for i = 1, MaxButtonCount do
        if (FBSpellBtnsR[i]) then
            if (on) then FBSpellBtnsR[i]:Show(); else FBSpellBtnsR[i]:Hide(); end
        end
    end
end

function FBHealBoxCreateAddonOptionFrame() 
    panel = CreateFrame("FRAME", "HealBoxOptionsFrame", UIParent); 
    panel.name = FBADDON_NAME; 
    panel:SetWidth(460); 
    panel:SetHeight(600); 
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0); 
    panel:SetFrameStrata("DIALOG"); 
    panel:SetBackdrop({ 
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background", 
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border", 
        tile = true, tileSize = 32, edgeSize = 32, 
        insets = { left = 11, right = 12, top = 12, bottom = 11 } 
    }); 
    panel:SetMovable(true); 
    panel:EnableMouse(true); 
    panel:RegisterForDrag("LeftButton"); 
    panel:SetScript("OnDragStart", function() panel:StartMoving(); end); 
    panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing(); end); 
    -- Beim Schliessen (X, ESC, /fbp config) immer auch das Kaskadenmenue zu
    panel:SetScript("OnHide", function() FBMenu_CloseAll(); end); 
    panel:Hide(); 
    -- ESC schliesst das Fenster. Zwei Wege, weil nicht jeder Client die
    -- UISpecialFrames-Liste auswertet:
    --  1) Eintrag in UISpecialFrames (Blizzards offizieller Weg)
    --  2) Vor-Hook auf ToggleGameMenu, das die ESC-Taste immer aufruft
    if (UISpecialFrames) then 
        table.insert(UISpecialFrames, "HealBoxOptionsFrame"); 
    end 
    FBHealBox_HookEscape(); 
    FBHealBox_HookSpellPickup(); 
    
    panel.CloseButton = CreateFrame("Button", "HealBoxOptionsFrameClose", panel, "UIPanelCloseButton"); 
    panel.CloseButton:SetPoint("TOPRIGHT", -5, -5); 
    panel.CloseButton:SetScript("OnClick", function() panel:Hide(); end); 
    
    panel.TitleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); 
    panel.TitleText:SetPoint("TOPLEFT", 25, -18); 
    panel.TitleText:SetText(FBADDON_NAME .. " " .. HealBoxVersion); 
    
    panel.TitleSubText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); 
    panel.TitleSubText:SetPoint("TOPLEFT", 25, -38); 
    panel.TitleSubText:SetJustifyH("LEFT"); 
    panel.TitleSubText:SetText(format(FBT("PANEL_SUB"), FBADDON_NAME)); 
    panel.TitleSubText:SetTextColor(1, 1, 1, 1); 
    
    -- Klassen-Icon samt Name muss oberhalb der Reiterleiste (FBOPT_TAB_Y)
    -- bleiben: Icon 52 px, Name direkt darunter, Unterkante bei etwa -84
    local classIcon = CreateFrame("Frame", nil, panel); 
    classIcon:SetPoint("TOPRIGHT", -25, -16); 
    classIcon:SetWidth(52); 
    classIcon:SetHeight(52); 
    classIcon.tex = classIcon:CreateTexture(nil, "BACKGROUND"); 
    classIcon.tex:SetAllPoints(); 
    classIcon.tex:SetTexture(ClassIcon[FBClass]); 
    classIcon.text = classIcon:CreateFontString(nil, "OVERLAY", "GameFontNormal"); 
    classIcon.text:SetText(strupper(FBClass)); 
    classIcon.text:SetPoint("TOP", classIcon, "BOTTOM", 0, -2); 
    classIcon.text:SetTextColor(1, 1, 0.2, 1); 
    
    -- [ Reiter ] ------------------------------------------------------------
    panel.tabs = {}; 
    panel.tabButtons = {}; 
    panel.tabLabelKeys = {}; 
    local tabButtons = FBHealBox_AddOptionsTab("TAB_BUTTONS"); 
    local tabGeneral = FBHealBox_AddOptionsTab("TAB_GENERAL"); 
    
    -- Trennlinie unter den Reitern
    panel.tabLine = panel:CreateTexture(nil, "ARTWORK"); 
    panel.tabLine:SetTexture(1, 0.82, 0, 0.35); 
    panel.tabLine:SetHeight(1); 
    panel.tabLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, FBOPT_TAB_Y - 26); 
    panel.tabLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -25, FBOPT_TAB_Y - 26); 
    
    -- ======================================================================
    -- Reiter 1: Button-Belegung
    --   Oben Smart Healing und Sicherheitsaufschlag, dann Spaltenkoepfe,
    --   je Button eine Zeile: Label | Linksklick-Feld | Rechtsklick-Feld,
    --   darunter Buttonzahl und Rechtsklick-Schalter.
    -- ======================================================================
    local rowH   = 30;    -- Zeilenabstand (Felder 28 px hoch, 2 px Luft)
    local fieldH = 28; 
    local xLabel = 30; 
    local xLeft  = 92; 
    local xRight = 268; 
    local fieldW = 170; 
    
    -- Smart Healing mit Sicherheitsaufschlag (oben)
    SmartRankCheck = FBHealBox_CreateCheck("FBHealBoxSmartRankCheck", tabButtons, 34, FBOPT_CONTENT_Y, "SMARTRANK", "SMARTRANK_TIP", function() 
        HealBox.SmartRank = SmartRankCheck:GetChecked() and 1 or 0; 
        FBHealBox_UpdateSmartCrossState();
    end); 
    SmartRankCheck:SetChecked(nil); 
    
    SmartCrossCheck = FBHealBox_CreateCheck("FBHealBoxSmartCrossCheck", tabButtons, 48, FBOPT_CONTENT_Y - 24, "SMARTCROSS", "SMARTCROSS_TIP", function()
        HealBox.SmartCross = SmartCrossCheck:GetChecked() and 1 or 0;
    end);
    SmartCrossCheck:SetChecked(nil);

    SmartMarginSlider = CreateFrame("Slider", "FBSmartMarginSlider", tabButtons, "OptionsSliderTemplate"); 
    SmartMarginSlider:SetWidth(fieldW); 
    SmartMarginSlider:SetHeight(16); 
    SmartMarginSlider:SetPoint("TOPLEFT", xRight, FBOPT_CONTENT_Y - 20); 
    SmartMarginSlider:SetMinMaxValues(0, 50); 
    SmartMarginSlider:SetValueStep(5); 
    SmartMarginSlider:SetValue(HealBox.SmartMargin or 20); 
    SmartMarginSlider.Text = SmartMarginSlider:CreateFontString(nil, "BACKGROUND", "GameFontNormal"); 
    SmartMarginSlider.Text:SetPoint("CENTER", 0, 15); 
    getglobal(SmartMarginSlider:GetName() .. "Low"):SetText("0"); 
    getglobal(SmartMarginSlider:GetName() .. "High"):SetText("50"); 
    SmartMarginSlider:SetScript("OnValueChanged", function() 
        HealBox.SmartMargin = math.floor(SmartMarginSlider:GetValue() + 0.5); 
        FBUpdateSmartMarginText(); 
    end); 
    FBUpdateSmartMarginText(); 
    
    -- Spaltenkoepfe und Zeilen
    local yHead = FBOPT_CONTENT_Y - 56; 
    local y0    = yHead - 16;
    
    panel.colLeft = tabButtons:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); 
    panel.colLeft:SetPoint("TOPLEFT", tabButtons, "TOPLEFT", xLeft + 4, yHead); 
    panel.colLeft:SetText(FBT("COL_LEFT")); 
    -- Der Spaltenkopf der rechten Spalte ist der Schalter selbst (unten);
    -- dieser Text bleibt als Platzhalter verborgen.
    panel.colRight = tabButtons:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); 
    panel.colRight:SetPoint("TOPLEFT", tabButtons, "TOPLEFT", xRight + 4, yHead); 
    panel.colRight:SetText(FBT("COL_RIGHT")); 
    panel.colRight:Hide(); 
    
    -- Rechtsklick-Zweitzauber: Schalter als Kopf der rechten Spalte,
    -- bewusst nur hier einschaltbar, Standard aus
    RightClickCheck = FBHealBox_CreateCheck("FBHealBoxRightClickCheck", tabButtons, xRight - 6, yHead + 9, "RIGHTCLICK", "RIGHTCLICK_TIP", function() 
        HealBox.RightClick = RightClickCheck:GetChecked() and 1 or 0; 
        FBHealBox_ApplyRightClickLayout(); 
        FBHealBoxButtonsChanged(); 
    end); 
    RightClickCheck:SetChecked(nil); 
    
    for i = 1, MaxButtonCount do 
        local yPos = y0 - ((i - 1) * rowH); 
        local btnIndex = i; 
        
        local btn = FBHealBox_CreatePickButton("FBHealBoxBtn"..i, tabButtons, xLeft, yPos, fieldW, fieldH, 20); 
        btn.text:SetText(FBT("SELECT_SPELL")); 
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); 
        btn.label:SetPoint("RIGHT", btn, "LEFT", -8, 0); 
        btn.label:SetJustifyH("RIGHT"); 
        btn.label:SetText(FBT("BUTTON") .. " " .. i); 
        btn:SetScript("OnClick", function() 
            if (FBDragSpell and FBHealBox_DropSpell(btnIndex, "L")) then return; end 
            PlaySound("igMainMenuOptionCheckBoxOn"); 
            FBMenu_OpenSpellMenu(btnIndex, btn, "L"); 
        end); 
        btn:SetScript("OnReceiveDrag", function() 
            local side = "L"; 
            if (IsShiftKeyDown()) then side = "R"; end 
            FBHealBox_DropSpell(btnIndex, side); 
        end); 
        FBSpellBtns[i] = btn; 
        
        local btnR = FBHealBox_CreatePickButton("FBHealBoxBtnR"..i, tabButtons, xRight, yPos, fieldW, fieldH, 20); 
        btnR.text:SetText(FBT("SELECT_SPELL")); 
        btnR:SetScript("OnClick", function() 
            if (FBDragSpell and FBHealBox_DropSpell(btnIndex, "R")) then return; end 
            PlaySound("igMainMenuOptionCheckBoxOn"); 
            FBMenu_OpenSpellMenu(btnIndex, btnR, "R"); 
        end); 
        btnR:SetScript("OnReceiveDrag", function() FBHealBox_DropSpell(btnIndex, "R"); end); 
        btnR:Hide(); 
        FBSpellBtnsR[i] = btnR; 
    end 
    
    local yBelow = y0 - (MaxButtonCount * rowH) - 26;   -- unter der letzten Zeile
    
    -- Buttonzahl: ueber die volle Breite beider Feldspalten, buendig mit den Feldern
    MaxButtonSlider = CreateFrame("Slider", "MaxButtonSlider", tabButtons, "OptionsSliderTemplate"); 
    MaxButtonSlider:SetWidth(xRight + fieldW - xLeft); 
    MaxButtonSlider:SetHeight(16); 
    MaxButtonSlider:SetPoint("TOPLEFT", xLeft, yBelow); 
    MaxButtonSlider:SetMinMaxValues(0, MaxButtonCount); 
    MaxButtonSlider:SetValueStep(1); 
    MaxButtonSlider:SetValue(HealBox.MaxButtons); 
    MaxButtonSlider.Text = MaxButtonSlider:CreateFontString(nil, "BACKGROUND", "GameFontNormal"); 
    MaxButtonSlider.Text:SetPoint("CENTER", 0, 15); 
    FBUpdateButtonSliderText(); 
    getglobal(MaxButtonSlider:GetName() .. "Low"):SetText("0"); 
    getglobal(MaxButtonSlider:GetName() .. "High"):SetText(tostring(MaxButtonCount)); 
    MaxButtonSlider:SetScript("OnValueChanged", MaxButtonSlider_Update); 
    
    -- ======================================================================
    -- Reiter 2: Allgemeine Einstellungen
    -- ======================================================================
    local gy = FBOPT_CONTENT_Y - 22; 
    
    ScaleSlider = CreateFrame("Slider", "ScaleSlider", tabGeneral, "OptionsSliderTemplate"); 
    ScaleSlider:SetWidth(128); 
    ScaleSlider:SetHeight(16); 
    ScaleSlider:SetPoint("TOPLEFT", 75, gy); 
    ScaleSlider:SetMinMaxValues(0.6, 1.5); 
    ScaleSlider:SetValueStep(0.1); 
    ScaleSlider:SetValue(HealBox.Scale); 
    ScaleSlider.Text = ScaleSlider:CreateFontString(nil, "BACKGROUND", "GameFontNormal"); 
    ScaleSlider.Text:SetPoint("CENTER", 0, 15); 
    FBUpdateScaleSliderText(); 
    getglobal(ScaleSlider:GetName() .. "Low"):SetText(FBT("SMALL")); 
    getglobal(ScaleSlider:GetName() .. "High"):SetText(FBT("LARGE")); 
    ScaleSlider:SetScript("OnValueChanged", function() 
        HealBox.Scale = ScaleSlider:GetValue(); 
        HealBoxScale(FBHealBox1, HealBox.Scale); 
        FBUpdateScaleSliderText(); 
    end); 
    
    -- Abstand der Buttons zueinander (0..20 px)
    ButtonSpacingSlider = CreateFrame("Slider", "FBButtonSpacingSlider", tabGeneral, "OptionsSliderTemplate"); 
    ButtonSpacingSlider:SetWidth(128); 
    ButtonSpacingSlider:SetHeight(16); 
    ButtonSpacingSlider:SetPoint("TOPLEFT", 260, gy); 
    ButtonSpacingSlider:SetMinMaxValues(0, 20); 
    ButtonSpacingSlider:SetValueStep(1); 
    ButtonSpacingSlider:SetValue(HealBox.ButtonSpacing or 2); 
    ButtonSpacingSlider.Text = ButtonSpacingSlider:CreateFontString(nil, "BACKGROUND", "GameFontNormal"); 
    ButtonSpacingSlider.Text:SetPoint("CENTER", 0, 15); 
    getglobal(ButtonSpacingSlider:GetName() .. "Low"):SetText("0"); 
    getglobal(ButtonSpacingSlider:GetName() .. "High"):SetText("20"); 
    ButtonSpacingSlider:SetScript("OnValueChanged", function() 
        HealBox.ButtonSpacing = math.floor(ButtonSpacingSlider:GetValue() + 0.5); 
        FBUpdateSpacingSliderText(); 
        FBHealBox_ApplyButtonSpacing(); 
    end); 
    
    -- Abstand der Plaketten zueinander (0..20 px)
    RowSpacingSlider = CreateFrame("Slider", "FBRowSpacingSlider", tabGeneral, "OptionsSliderTemplate"); 
    RowSpacingSlider:SetWidth(128); 
    RowSpacingSlider:SetHeight(16); 
    RowSpacingSlider:SetPoint("TOPLEFT", 75, gy - 50); 
    RowSpacingSlider:SetMinMaxValues(0, 20); 
    RowSpacingSlider:SetValueStep(1); 
    RowSpacingSlider:SetValue(HealBox.RowSpacing or 4); 
    RowSpacingSlider.Text = RowSpacingSlider:CreateFontString(nil, "BACKGROUND", "GameFontNormal"); 
    RowSpacingSlider.Text:SetPoint("CENTER", 0, 15); 
    getglobal(RowSpacingSlider:GetName() .. "Low"):SetText("0"); 
    getglobal(RowSpacingSlider:GetName() .. "High"):SetText("20"); 
    RowSpacingSlider:SetScript("OnValueChanged", function() 
        HealBox.RowSpacing = math.floor(RowSpacingSlider:GetValue() + 0.5); 
        FBUpdateSpacingSliderText(); 
        FBHealBox_Layout(); 
    end); 
    -- Deckkraft des Balkenhintergrunds (0..100 %)
    BarBGSlider = CreateFrame("Slider", "FBBarBGSlider", tabGeneral, "OptionsSliderTemplate"); 
    BarBGSlider:SetWidth(128); 
    BarBGSlider:SetHeight(16); 
    BarBGSlider:SetPoint("TOPLEFT", 260, gy - 50); 
    BarBGSlider:SetMinMaxValues(0, 100); 
    BarBGSlider:SetValueStep(5); 
    BarBGSlider:SetValue(HealBox.BarBG or 0); 
    BarBGSlider.Text = BarBGSlider:CreateFontString(nil, "BACKGROUND", "GameFontNormal"); 
    BarBGSlider.Text:SetPoint("CENTER", 0, 15); 
    getglobal(BarBGSlider:GetName() .. "Low"):SetText(FBT("BAR_BG_OFF")); 
    getglobal(BarBGSlider:GetName() .. "High"):SetText(FBT("BAR_BG_FULL")); 
    BarBGSlider:SetScript("OnValueChanged", function() 
        HealBox.BarBG = math.floor(BarBGSlider:GetValue() + 0.5); 
        FBUpdateBarBGSliderText(); 
        FBHealBox_ApplyBarBGAll(); 
    end); 
    
    FBUpdateSpacingSliderText(); 
    FBUpdateBarBGSliderText(); 
    
    -- [ Schalter ] ----------------------------------------------------------
    local cy = gy - 95; 
    AttachModeCheck = FBHealBox_CreateCheck("$parentCheckButton", tabGeneral, 40, cy, "ATTACH", "ATTACH_TIP", function() 
        HealBox.AttachMode = AttachModeCheck:GetChecked() and 1 or 0; 
        -- Anheften und Verstecken schliessen sich aus
        if (HealBox.AttachMode == 1) then HealBox.HideBlizzParty = 0; end 
        if (HidePartyCheck) then HidePartyCheck:SetChecked(HealBox.HideBlizzParty == 1); end 
        FBHealBox_UpdatePartyExclusion(); 
        HealBoxAttachMode(HealBox.AttachMode); 
        FBUpdateNames(); 
    end); 
    
    HealCommCheck = FBHealBox_CreateCheck("FBHealBoxHealCommCheck", tabGeneral, 250, cy, "COMM", "COMM_TIP", function() 
        HealBox.HealComm = HealCommCheck:GetChecked() and 1 or 0; 
        if (HealBox.HealComm == 0) then 
            FBCommHeals = {}; 
            FBHealBox_RefreshAllBars(); 
        end 
    end); 
    HealCommCheck:SetChecked(1); 
    
    ManaBarCheck = FBHealBox_CreateCheck("FBHealBoxManaBarCheck", tabGeneral, 40, cy - 30, "MANABAR", "MANABAR_TIP", function() 
        HealBox.ManaBar = ManaBarCheck:GetChecked() and 1 or 0; 
        FBHealBox_RefreshAllBars(); 
    end); 
    ManaBarCheck:SetChecked(1); 
    
    ShowPetsCheck = FBHealBox_CreateCheck("FBHealBoxShowPetsCheck", tabGeneral, 250, cy - 30, "SHOWPETS", "SHOWPETS_TIP", function() 
        HealBox.ShowPets = ShowPetsCheck:GetChecked() and 1 or 0; 
        FBUpdateNames(); 
    end); 
    ShowPetsCheck:SetChecked(1); 
    
    ClassColorsCheck = FBHealBox_CreateCheck("FBHealBoxClassColorsCheck", tabGeneral, 40, cy - 60, "CLASSCOLORS", "CLASSCOLORS_TIP", function() 
        HealBox.ClassColors = ClassColorsCheck:GetChecked() and 1 or 0; 
        FBHealBox_ApplyAllNameColors(); 
    end); 
    ClassColorsCheck:SetChecked(1); 
    
    RangeFadeCheck = FBHealBox_CreateCheck("FBHealBoxRangeFadeCheck", tabGeneral, 250, cy - 60, "RANGEFADE", "RANGEFADE_TIP", function() 
        HealBox.RangeFade = RangeFadeCheck:GetChecked() and 1 or 0; 
        FBHealBox_CheckRangeAll(); 
    end); 
    RangeFadeCheck:SetChecked(1); 
    
    DebuffIconCheck = FBHealBox_CreateCheck("FBHealBoxDebuffIconCheck", tabGeneral, 40, cy - 90, "DEBUFFICON", "DEBUFFICON_TIP", function() 
        HealBox.DebuffIcon = DebuffIconCheck:GetChecked() and 1 or 0; 
        FBHealBox_InvalidateUnitCaches(); 
        FBHealBox_RefreshAllBars(); 
    end); 
    DebuffIconCheck:SetChecked(1); 
    
    LOSIconCheck = FBHealBox_CreateCheck("FBHealBoxLOSIconCheck", tabGeneral, 250, cy - 90, "LOSICON", "LOSICON_TIP", function() 
        HealBox.LOSIcon = LOSIconCheck:GetChecked() and 1 or 0; 
        FBHealBox_CheckLOSAll(); 
    end); 
    LOSIconCheck:SetChecked(1); 
    
    TestModeCheck = FBHealBox_CreateCheck("FBHealBoxTestModeCheck", tabGeneral, 40, cy - 120, "TESTMODE", "TESTMODE_TIP", function() 
        FBTest_Set(TestModeCheck:GetChecked()); 
    end); 
    TestModeCheck:SetChecked(nil); 
    
    BuffWatchPetsCheck = FBHealBox_CreateCheck("FBHealBoxBuffWatchPetsCheck", tabGeneral, 250, cy - 120, "BUFFWATCH_PETS", "BUFFWATCH_PETS_TIP", function() 
        HealBox.BuffWatchPets = BuffWatchPetsCheck:GetChecked() and 1 or 0; 
        FBHealBox_CheckAllWatchBuffs(); 
    end); 
    BuffWatchPetsCheck:SetChecked(nil); 
    
    AggroMarkCheck = FBHealBox_CreateCheck("FBHealBoxAggroMarkCheck", tabGeneral, 40, cy - 150, "AGGRO", "AGGRO_TIP", function() 
        HealBox.AggroMark = AggroMarkCheck:GetChecked() and 1 or 0; 
        FBHealBox_CheckAggroAll(); 
    end); 
    AggroMarkCheck:SetChecked(1); 
    
    SpellTimersCheck = FBHealBox_CreateCheck("FBHealBoxSpellTimersCheck", tabGeneral, 250, cy - 150, "TIMERS", "TIMERS_TIP", function() 
        HealBox.SpellTimers = SpellTimersCheck:GetChecked() and 1 or 0; 
        FBHealBox_UpdateSpellTimers(); 
    end); 
    SpellTimersCheck:SetChecked(1); 
    
    CooldownsCheck = FBHealBox_CreateCheck("FBHealBoxCooldownsCheck", tabGeneral, 40, cy - 180, "COOLDOWNS", "COOLDOWNS_TIP", function() 
        HealBox.Cooldowns = CooldownsCheck:GetChecked() and 1 or 0; 
        FBHealBox_UpdateAllCooldowns(); 
    end); 
    CooldownsCheck:SetChecked(1); 
    
    BuffIconsCheck = FBHealBox_CreateCheck("FBHealBoxBuffIconsCheck", tabGeneral, 250, cy - 180, "BUFFICONS", "BUFFICONS_TIP", function() 
        HealBox.BuffIcons = BuffIconsCheck:GetChecked() and 1 or 0; 
        FBHealBox_UpdateAllBuffIcons(); 
    end); 
    BuffIconsCheck:SetChecked(1); 
    
    HidePartyCheck = FBHealBox_CreateCheck("FBHealBoxHidePartyCheck", tabGeneral, 40, cy - 210, "HIDEPARTY", "HIDEPARTY_TIP", function() 
        HealBox.HideBlizzParty = HidePartyCheck:GetChecked() and 1 or 0; 
        if (HealBox.HideBlizzParty == 1) then 
            HealBox.AttachMode = 0; 
            if (AttachModeCheck) then AttachModeCheck:SetChecked(nil); end 
            HealBoxAttachMode(0); 
            FBUpdateNames(); 
        end 
        FBHealBox_UpdatePartyExclusion(); 
        FBHealBox_ApplyBlizzParty(); 
    end); 
    HidePartyCheck:SetChecked(nil); 
    
    PowerBarCheck = FBHealBox_CreateCheck("FBHealBoxPowerBarCheck", tabGeneral, 250, cy - 210, "POWERBAR", "POWERBAR_TIP", function() 
        HealBox.PowerBar = PowerBarCheck:GetChecked() and 1 or 0; 
        FBHealBox_InvalidateUnitCaches(); 
        FBHealBox_RefreshAllBars(); 
        FBHealBox_RunHook("SyncOptions"); 
    end); 
    PowerBarCheck:SetChecked(nil); 
    
    -- [ Sprache und Buff-Wache ] -------------------------------------------
    local py = cy - 245; 
    FBLangBtn = FBHealBox_CreatePickButton("FBHealBoxLangBtn", tabGeneral, 35, py, 180, 26, 18); 
    FBLangBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01"); 
    FBLangBtn:SetScript("OnEnter", function() 
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); 
        GameTooltip:SetText(FBT("LANGUAGE")); 
        GameTooltip:AddLine(FBT("LANG_TIP"), 1, 1, 1, true); 
        GameTooltip:Show(); 
    end); 
    FBLangBtn:SetScript("OnLeave", function() GameTooltip:Hide(); end); 
    FBLangBtn:SetScript("OnClick", function() 
        PlaySound("igMainMenuOptionCheckBoxOn"); 
        FBMenu_OpenLanguageMenu(FBLangBtn); 
    end); 
    
    FBBuffWatchBtn = FBHealBox_CreatePickButton("FBHealBoxBuffWatchBtn", tabGeneral, 245, py, 180, 26, 18); 
    FBBuffWatchBtn:SetScript("OnEnter", function() 
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); 
        GameTooltip:SetText(FBT("BUFFWATCH")); 
        GameTooltip:AddLine(FBT("BUFFWATCH_TIP"), 1, 1, 1, true); 
        GameTooltip:Show(); 
    end); 
    FBBuffWatchBtn:SetScript("OnLeave", function() GameTooltip:Hide(); end); 
    FBBuffWatchBtn:SetScript("OnClick", function() 
        PlaySound("igMainMenuOptionCheckBoxOn"); 
        FBMenu_OpenBuffMenu(FBBuffWatchBtn); 
    end); 
    FBHealBox_UpdateBuffWatchLabel(); 
    
    -- [ Klick auf die Plakette ] --------------------------------------------
    FBPlateLeftBtn = FBHealBox_CreatePickButton("FBHealBoxPlateLeftBtn", tabGeneral, 35, py - 36, 180, 26, 18); 
    FBPlateLeftBtn.icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot"); 
    FBPlateLeftBtn.side = "L"; 
    FBPlateRightBtn = FBHealBox_CreatePickButton("FBHealBoxPlateRightBtn", tabGeneral, 245, py - 36, 180, 26, 18); 
    FBPlateRightBtn.icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot"); 
    FBPlateRightBtn.side = "R"; 
    for _, pb in ipairs({ FBPlateLeftBtn, FBPlateRightBtn }) do 
        pb:SetScript("OnEnter", function() 
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); 
            if (this.side == "R") then GameTooltip:SetText(FBT("PLATE_RIGHT")); else GameTooltip:SetText(FBT("PLATE_LEFT")); end 
            GameTooltip:AddLine(FBT("PLATE_TIP"), 1, 1, 1, true); 
            GameTooltip:Show(); 
        end); 
        pb:SetScript("OnLeave", function() GameTooltip:Hide(); end); 
        pb:SetScript("OnClick", function() 
            PlaySound("igMainMenuOptionCheckBoxOn"); 
            FBMenu_OpenPlateActionMenu(this, this.side); 
        end); 
    end 
    FBHealBox_UpdatePlateActionLabels(); 
    
    panel.AboutText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"); 
    panel.AboutText:SetPoint("BOTTOM", panel, "BOTTOM", 0, 14); 
    panel.AboutText:SetWidth(400); 
    panel.AboutText:SetJustifyH("CENTER"); 
    panel.AboutText:SetText(format(FBT("ABOUT"), FBADDON_NAME, HealBoxVersion)); 

    FBHealBox_ShowTab(1); 
    FBHealBox_ApplyRightClickLayout(); 
    FBHealBox_ApplyLocale(); 
end 

-- ESC: ToggleGameMenu abfangen, solange das Optionsfenster offen ist.
-- Ist das Spielmenue selbst offen (ESC darueber gedrueckt), bleibt alles
-- beim Original; sonst schliesst ESC zuerst unser Fenster und verpufft.
-- Das Original liegt in einem lokalen Upvalue (nie in einer globalen
-- Variablen, die ein zweiter Ladevorgang ueberschreiben koennte), der
-- Hook wird hoechstens einmal gesetzt, und der Aufruf ist bewusst kein
-- Tail-Call (return f()), weil Lua 5.0 im 1.12-Client damit Probleme hat.
function FBHealBox_HookEscape() 
    if (FBHealBox_EscHooked) or (not ToggleGameMenu) then return; end 
    FBHealBox_EscHooked = true; 
    local origToggleGameMenu = ToggleGameMenu; 
    ToggleGameMenu = function(clicked) 
        local gameMenuOpen = (GameMenuFrame and GameMenuFrame:IsVisible()); 
        if (panel and panel:IsVisible() and not gameMenuOpen) then 
            panel:Hide(); 
            return; 
        end 
        origToggleGameMenu(clicked); 
    end 
end 

-- Optionsfenster auf/zu (Minimap-Button, /fbp config)
function FBHealBox_ToggleOptions() 
    if (not panel) then return; end 
    if (panel:IsVisible()) then 
        panel:Hide(); 
    else 
        panel:Show(); 
    end 
end 

-- Optionsschalter mit Beschriftung und Tooltip (fuenfmal gebraucht)
function FBHealBox_CreateCheck(name, parent, x, y, labelKey, tipKey, onClick) 
    local c = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate"); 
    c:SetPoint("TOPLEFT", x, y); 
    c.Text = c:CreateFontString(nil, "BACKGROUND", "GameFontNormal"); 
    c.Text:SetPoint("LEFT", c, "RIGHT", 4, 1); 
    -- feste Breite und eine Zeile: lange Uebersetzungen enden mit "...", der
    -- volle Text steht im Tooltip
    c.Text:SetWidth(FBOPT_CHECK_TEXT_W); 
    c.Text:SetHeight(14); 
    c.Text:SetJustifyH("LEFT"); 
    c.Text:SetText(FBT(labelKey)); 
    c.labelKey = labelKey; 
    c.tooltipText = FBT(tipKey); 
    c:SetScript("OnEnter", function() 
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); 
        GameTooltip:SetText(FBT(this.labelKey)); 
        GameTooltip:AddLine(this.tooltipText, 1, 1, 1, true); 
        GameTooltip:Show(); 
    end); 
    c:SetScript("OnLeave", function() GameTooltip:Hide(); end); 
    c:SetScript("OnClick", onClick); 
    return c; 
end 

-- [ Namensplaketten Buttons ] -- 

-- Buttons werden genau einmal angelegt und danach nur noch umbelegt.
-- (Frueher wurden sie bei jedem SPELLS_CHANGED neu erzeugt.)
function FBHealBoxButtons() 
    for p = 1, FBSlotCount do 
        local unit = FBPartyUnit[p]; 
        local parentFrame = FBPartyFrame[p]; 
        if (parentFrame) then 
            local prevButton = nil; 
            for i = 1, MaxButtonCount do 
                if (not FBPartyTable[p][i]) then 
                    local anchor = prevButton or parentFrame; 
                    local name = "FBHealBoxSlot"..p.."Btn"..i; 
                    FBPartyTable[p][i] = FBHealBoxCreateButton(name, anchor, HealBox.ButtonSpacing or 2, 0, 
                        FBDropDownButtonIcon[i], FBDropDownButton[i], unit, FBActiveSpellIDs[i]); 
                    FBPartyTable[p][i].btnIndex = i; 
                end 
                prevButton = FBPartyTable[p][i]; 
            end 
        end 
    end 
    FBHealBox_ApplyButtonSpacing(); 
    FBHealBoxButtonsChanged(); 
end 

function FBHealBoxButtonsChanged() 
    FBHealBox_InvalidateRangeSpell(); 
    local rightOn = (HealBox.RightClick == 1); 
    for p = 1, FBSlotCount do 
        local unit = FBPartyUnit[p]; 
        for i = 1, MaxButtonCount do 
            local b = FBPartyTable[p][i]; 
            if (b) then 
                b:Hide(); 
                b.TargetUnit = unit; 
                b.spellName = FBDropDownButton[i]; 
                b.id = FBActiveSpellIDs[i]; 
                if (FBDropDownButtonIcon[i]) then 
                    b.icon:SetTexture(FBDropDownButtonIcon[i]); 
                else 
                    b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); 
                end 
                -- Rechtsklick: nur wenn in den Optionen eingeschaltet
                if (rightOn) then 
                    b.spellNameR = FBDropDownButtonR[i]; 
                    b.idR = FBActiveSpellIDsR[i]; 
                else 
                    b.spellNameR = nil; 
                    b.idR = nil; 
                end 
                if (b.subIcon) then 
                    if (b.spellNameR and FBDropDownButtonIconR[i]) then 
                        b.subIcon:SetTexture(FBDropDownButtonIconR[i]); 
                        b.subIcon:Show(); 
                    else 
                        b.subIcon:Hide(); 
                    end 
                end 
                if (i <= (HealBox.MaxButtons or 0)) then b:Show(); end 
                b.cdKey = nil; 
                b.colorState = nil; 
                -- Basisnamen fuer die Timer einmal berechnen statt je Tick
                if (b.spellName) then b.spellBase = FBPredict_SplitCast(b.spellName); else b.spellBase = nil; end 
                if (b.spellNameR) then b.spellBaseR = FBPredict_SplitCast(b.spellNameR); else b.spellBaseR = nil; end 
            end 
        end 
    end 
    FBHealBox_RunHook("ButtonsChanged"); 
    FBHealBox_UpdateButtonStates("SPELL_UPDATE_USABLE"); 
end 

-- Buttons neu verketten: erster Button haengt an der Plakette, jeder weitere
-- am vorherigen, jeweils mit HealBox.ButtonSpacing Pixeln Luft.
function FBHealBox_ApplyButtonSpacing() 
    local gap = HealBox.ButtonSpacing or 2; 
    for p = 1, FBSlotCount do 
        local prev = FBPartyFrame[p]; 
        for i = 1, MaxButtonCount do 
            local b = FBPartyTable[p][i]; 
            if (b and prev) then 
                b:ClearAllPoints(); 
                b:SetPoint("LEFT", prev, "RIGHT", gap, 0); 
                prev = b; 
            end 
        end 
    end 
end 

-- Sliderbeschriftungen: eigene Funktionen, damit der Sprachwechsel sie neu setzen kann
function FBUpdateButtonSliderText()
    if (MaxButtonSlider and MaxButtonSlider.Text) then
        MaxButtonSlider.Text:SetText(format(FBT("SHOW_BUTTONS"), MaxButtonSlider:GetValue()));
    end
end

function FBUpdateScaleSliderText()
    if (ScaleSlider and ScaleSlider.Text) then
        ScaleSlider.Text:SetText(format(FBT("SCALE"), format("%.1f", ScaleSlider:GetValue())));
    end
end

function FBUpdateSmartMarginText()
    if (SmartMarginSlider and SmartMarginSlider.Text) then
        SmartMarginSlider.Text:SetText(format(FBT("SMART_MARGIN"), math.floor(SmartMarginSlider:GetValue() + 0.5)));
    end
end

function FBUpdateBarBGSliderText()
    if (BarBGSlider and BarBGSlider.Text) then
        BarBGSlider.Text:SetText(format(FBT("BAR_BG"), math.floor(BarBGSlider:GetValue() + 0.5)));
    end
end

function FBUpdateSpacingSliderText()
    if (ButtonSpacingSlider and ButtonSpacingSlider.Text) then
        ButtonSpacingSlider.Text:SetText(format(FBT("BTN_SPACING"), math.floor(ButtonSpacingSlider:GetValue() + 0.5)));
    end
    if (RowSpacingSlider and RowSpacingSlider.Text) then
        RowSpacingSlider.Text:SetText(format(FBT("ROW_SPACING"), math.floor(RowSpacingSlider:GetValue() + 0.5)));
    end
end

function MaxButtonSlider_Update() 
    FBUpdateButtonSliderText(); 
    HealBox.MaxButtons = MaxButtonSlider:GetValue(); 
    FBHealBoxButtonsChanged(); 
end 

function CreateMiniMapButton() 
    local button = CreateFrame("Button", "FBHealMiniMap", Minimap); 
    button:SetFrameStrata("MEDIUM"); 
    button:SetFrameLevel(8); 
    button:SetWidth(31); 
    button:SetHeight(31); 
    button:EnableMouse(1); 
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp"); 
    button:RegisterForDrag("RightButton"); 
    
    button.icon = button:CreateTexture("FBHealMiniMapIcon", "BACKGROUND"); 
    button.icon:SetWidth(17); 
    button.icon:SetHeight(17); 
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6); 
    button.icon:SetTexture("Interface/Icons/Spell_Holy_GreaterHeal"); 
    button.icon:SetTexCoord(0.075, 0.925, 0.075, 0.925); 
    
    button.border = button:CreateTexture("FBHealMiniMapBorder", "OVERLAY"); 
    button.border:SetWidth(53); 
    button.border:SetHeight(53); 
    button.border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0); 
    button.border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder"); 
    
    button:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight", "ADD"); 
    button.tooltipTitle = FBADDON_NAME; 
    button.tooltipText = FBT("MM_TIP"); 
    
    local mmAngle = math.rad(225); 
    button:SetPoint("TOPLEFT", "Minimap", "TOPLEFT", 52-(80*cos(mmAngle)), (80*sin(mmAngle))-52); 
    button:Show(); 
    
    button:SetScript("OnEnter", function() 
        GameTooltip:SetOwner(this, "ANCHOR_LEFT"); 
        GameTooltip:SetText(this.tooltipTitle); 
        GameTooltip:AddLine(this.tooltipText, 1, 1, 1); 
        GameTooltip:Show(); 
    end); 
    
    button:SetScript("OnLeave", function() 
        GameTooltip:Hide(); 
    end); 
    
    button:SetMovable(true); 
    button:SetScript("OnMouseDown", function() 
        if (arg1 == "RightButton") then this:StartMoving(); end 
    end); 
    
    button:SetScript("OnMouseUp", function() 
        if (arg1 == "RightButton") then this:StopMovingOrSizing(); end 
    end); 
    
    button:SetScript("OnClick", function() 
        if (arg1 == "LeftButton") then 
            if (IsShiftKeyDown()) then 
                HealBox.Active = 1 - HealBox.Active; 
                if (HealBox.Active == 1) then FBHealBox1:Show(); else FBHealBox1:Hide(); end 
                FBHealBox_RunHook("ActiveToggle"); 
            else 
                FBHealBox_ToggleOptions(); 
            end 
        end 
    end); 
    return button; 
end 

function FBGetSpellID(spell, rank, debug) 
    local i = 1; 
    local spellID; 
    local highestRank; 
    while true do 
        local spellName = GetSpellName(i, SpellBookFrame.bookType); 
        if (not spellName) then break; end 
        if (spellName == spell) then 
            spellID = i; 
            highestRank = spellRank; 
        end 
        i = i + 1; 
        if (i > 300) then break; end 
    end            
    return spellID, highestRank; 
end 

-- ==========================================================================
-- [ Button-Zustaende zentral ]
--
-- Frueher hatte jeder der bis zu 260 Buttons einen eigenen Event-Handler
-- fuer SPELL_UPDATE_USABLE/COOLDOWN (der zudem "this"/"event" als Parameter
-- deklarierte und damit die 1.12-Globals verdeckte, also nie etwas tat).
-- Jetzt laeuft ein Durchgang ueber die sichtbaren Buttons; Nutzbarkeit und
-- Cooldown werden je Zauber-ID nur einmal abgefragt, die Reichweite je
-- Button (haengt vom Ziel ab). Farben werden nur gesetzt, wenn sich der
-- Zustand aendert.
-- ==========================================================================

FBBtnUsableCache = {};   -- [id] = { pass, st }   st = "ok" | "mana" | "no"
FBBtnCdCache     = {};   -- [id] = { pass, start, duration, enable }
FBBtnPass        = 0;    -- Durchgangszaehler: Eintraege eines aelteren Durchgangs gelten als leer

function FBHealBox_ButtonUsable(id)
    local e = FBBtnUsableCache[id];
    if (e and e.pass == FBBtnPass) then return e.st; end
    if (not e) then e = {}; FBBtnUsableCache[id] = e; end
    local isUsable, noMana = FBHealBox_SpellUsable(id);
    -- Waehrend des globalen Cooldowns meldet der Client jeden Zauber als
    -- nicht nutzbar. Ungefiltert wuerden nach jedem gewirkten Zauber
    -- saemtliche Buttons anderthalb Sekunden lang dunkel, was aussieht, als
    -- waere gar nichts mehr verfuegbar. Laeuft eine Abklingzeit, die nicht
    -- laenger als der globale Cooldown ist, zaehlt sie deshalb nicht als
    -- Grund. Echte Abklingzeiten bleiben unberuehrt, die zeigt die Uhr.
    if (not isUsable) and (not noMana) then
        local cd = FBHealBox_ButtonCooldown(id);
        if (cd[1] > 0) and (cd[2] > 0) and (cd[2] <= FBCD_MIN_DURATION) then
            isUsable = 1;
        end
    end
    if (isUsable) then e.st = "ok"; elseif (noMana) then e.st = "mana"; else e.st = "no"; end
    e.pass = FBBtnPass;
    return e.st;
end

function FBHealBox_ButtonCooldown(id)
    local cd = FBBtnCdCache[id];
    if (cd and cd.pass == FBBtnPass) then return cd; end
    if (not cd) then cd = {}; FBBtnCdCache[id] = cd; end
    local start, duration, enable = GetSpellCooldown(id, BOOKTYPE_SPELL);
    cd[1] = start or 0; cd[2] = duration or 0; cd[3] = enable or 0;
    cd.pass = FBBtnPass;
    return cd;
end

-- Einen sichtbaren Button nachfuehren. Nutzbarkeit/Reichweite nur bei USABLE.
function FBHealBox_UpdateButtonState(b, event)
    if (not b) or (not b.id) then return; end
    if (b.cooldown and CooldownFrame_SetTimer) then
        local key = "off";
        local cd = nil;
        if (HealBox.Cooldowns == 1) then
            cd = FBHealBox_ButtonCooldown(b.id);
            if (cd[1] > 0) and (cd[2] > FBCD_SHOW_MIN) then key = cd[1].."|"..cd[2]; end
        end
        if (b.cdKey ~= key) then
            b.cdKey = key;
            if (key == "off") then CooldownFrame_SetTimer(b.cooldown, 0, 0, 0);
            else CooldownFrame_SetTimer(b.cooldown, cd[1], cd[2], cd[3]); end
        end
    end
    if (event ~= "SPELL_UPDATE_USABLE") then return; end
    local st = FBHealBox_ButtonUsable(b.id);
    local inRange = FBHealBox_SpellInRange(b.id, b.TargetUnit);
    if (inRange == 0) then st = "range"; end
    if (b.colorState == st) then return; end
    b.colorState = st;
    if (st == "ok") then b.icon:SetVertexColor(1.0, 1.0, 1.0);
    elseif (st == "mana") then b.icon:SetVertexColor(0.5, 0.5, 1.0);
    elseif (st == "range") then b.icon:SetVertexColor(1.0, 0.3, 0.3);
    else b.icon:SetVertexColor(0.3, 0.3, 0.3); end
end

-- Alle sichtbaren Buttons (Plaketten; Module ueber Hook "ButtonStates")
function FBHealBox_UpdateButtonStates(event)
    if (HealBox.Active == 0) then return; end
    FBBtnPass = FBBtnPass + 1;
    local maxB = HealBox.MaxButtons or 0;
    for p = 1, FBSlotCount do
        local f = FBPartyFrame[p];
        if (f and f:IsShown() and FBPartyTable[p]) then
            for i = 1, maxB do
                local b = FBPartyTable[p][i];
                if (b and b:IsShown()) then FBHealBox_UpdateButtonState(b, event); end
            end
        end
    end
    FBHealBox_RunHook("ButtonStates", event);
end

-- Kompatibilitaet fuer aeltere Aufrufer
function HealBoxButton_OnEvent(this, event, arg1)
    if (HealBox.Active == 0) then return 0; end
    FBBtnPass = FBBtnPass + 1;
    FBHealBox_UpdateButtonState(this, event);
end 

function HealBoxScale(this, scale) 
    this:SetScale(scale); 
end 

-- Blizzard-Frame, an das ein Slot im Party-Frame-Modus gehaengt wird
function FBHealBox_BlizzAnchor(p) 
    if (p >= 2 and p <= 5) then return getglobal("PartyMemberFrame"..(p - 1)), 119, 6; end 
    if (p == 6) then return PetFrame, 4, 0; end 
    if (p >= 7) then return getglobal("PartyMemberFrame"..(p - 6).."PetFrame"), 4, 0; end 
    return nil; 
end 

-- ==========================================================================
-- [ Blizzards Gruppenfenster ]
--
-- Der Anheftmodus haengt die Plaketten genau an PartyMemberFrame1 bis 4.
-- Beides gleichzeitig ergibt keinen Sinn, deshalb sperren sich die zwei
-- Optionen im Optionsfenster gegenseitig, und diese Pruefung hier ist der
-- Sicherheitsgurt fuer alte gespeicherte Werte. Im Ruhezustand der
-- Klassensperre gibt das Addon die Frames ebenfalls wieder frei.
-- ==========================================================================

function FBHealBox_HideBlizzPartyActive()
    if (FBAddonSuppressed) then return false; end
    if (HealBox.AttachMode == 1) then return false; end
    return (HealBox.HideBlizzParty == 1);
end

function FBHealBox_ApplyBlizzParty()
    local hide = FBHealBox_HideBlizzPartyActive();
    for i = 1, 4 do
        local f = getglobal("PartyMemberFrame"..i);
        if (f) then
            -- Blizzard zeigt die Frames bei jeder Gruppenaenderung neu an,
            -- deshalb einmalig OnShow abfangen statt nur einmal zu verstecken
            if (not f.fbShowHooked) then
                f.fbShowHooked = true;
                f.fbOldOnShow = f:GetScript("OnShow");
                f:SetScript("OnShow", function()
                    if (this.fbOldOnShow) then this.fbOldOnShow(); end
                    if (FBHealBox_HideBlizzPartyActive()) then this:Hide(); end
                end);
            end
            if (hide) then
                f:Hide();
            elseif (UnitExists("party"..i)) then
                f:Show();
            end
        end
    end
end

function HealBoxAttachMode(mode) 
    if (not FBHealBox1) then return; end 
    
    if (mode == 1) then 
        -- Eigene Plaketten weg: Slots 2-10 werden 1x1 Pixel gross und
        -- haengen unsichtbar an Blizzards Frames, nur die Buttons bleiben.
        FBHealBox1:SetScale(1); 
        for p = 2, FBSlotCount do 
            local f = FBPartyFrame[p]; 
            local anchor, xoff, yoff = FBHealBox_BlizzAnchor(p); 
            f:ClearAllPoints(); 
            if (anchor) then 
                if (p >= 6) then 
                    f:SetPoint("LEFT", anchor, "RIGHT", xoff, yoff); 
                else 
                    f:SetPoint("LEFT", anchor, "LEFT", xoff, yoff); 
                end 
            else 
                f:SetPoint("LEFT", FBHealBox1, "LEFT", 0, 0); 
            end 
            f:SetBackdropColor(0, 0, 0, 0.8); 
            f:SetWidth(1); 
            f:SetHeight(1); 
            FBHealBox_SetPlateVisible(f, false); 
            f:SetBackdropBorderColor(FBBUFF_NORMAL_COLOR[1], FBBUFF_NORMAL_COLOR[2], FBBUFF_NORMAL_COLOR[3], FBBUFF_NORMAL_COLOR[4]); 
            f.buffMissing = false; 
            f:SetFrameStrata("LOW"); 
            f:Hide(); 
        end 
    else 
        FBHealBox1:SetScale(HealBox.Scale or 1); 
        FBHealBox_RestorePosition(); 
        FBHealBox1:SetBackdropColor(0, 0, 0, 0.8); 
        FBHealBox_SetPlateVisible(FBHealBox1, true); 
        FBHealBox1:Hide(); 
        
        for p = 2, FBSlotCount do 
            local f = FBPartyFrame[p]; 
            f:SetBackdropColor(0, 0, 0, 0.8); 
            f:SetWidth(f.plateW or NamePlateWidth); 
            f:SetHeight(NamePlateHeight); 
            FBHealBox_SetPlateVisible(f, true); 
            FBHealBox_SetBarStrata(f, "BACKGROUND"); 
            f:Hide(); 
        end 
        FBHealBox_Layout(); 
    end 
    FBHealBox_ApplyBlizzParty(); 
end 

-- ==========================================================================
-- [ FB Heal Prediction :  Direktheilung + HoT-Ticks + Absorb-Schilde ]
--
-- Ersetzt FBHealCommLite komplett. Ein Tooltip-Parser, ein Lernspeicher,
-- ein Balken-Update statt zwei Systemen, die sich gegenseitig ins
-- Gehege kommen.
--
--  1) Direktheilung (Flash Heal, Greater Heal, Healing Wave, ...)
--     SPELLCAST_START liefert Zaubername UND Castdauer, unabhaengig
--     davon, ob der Cast vom HealBox-Button, der Aktionsleiste oder aus
--     einem Makro kommt. Kein Hook auf CastSpellByName noetig.
--     Instants brauchen keine Vorhersage: die Heilung ist da, bevor ein
--     Balken sie anzeigen koennte.
--
--  2) HoT-Vorhersage (Renew, Rejuvenation, Regrowth-Anteil, ...)
--     UnitBuff() liefert fuer fremde Einheiten keine Restlaufzeit, also
--     fuehren wir selbst Buch: Cast vormerken -> UNIT_AURA bestaetigt die
--     Anwendung ueber die Buff-Textur -> Restticks aus
--     (Ablauf - GetTime()) / Intervall. Faellt der Buff weg, ist die
--     Anzeige sofort weg.
--
--  3) Schild-Vorhersage (Power Word: Shield, ...)
--     Maximaler Absorb aus dem Tooltip, Verbrauch aus dem Combatlog
--     ("(123 absorbed)").
--
--  Selbstkorrektur: Tooltips liefern in 1.12 nur Basiswerte ohne
--  +Heilung. Der Combatlog liefert die Wahrheit: jeder beobachtete
--  Tick, jede angekommene Direktheilung und jeder Absorb ueber dem
--  Tooltip-Wert schaerft die Schaetzung nach und wird pro Zauber+Rang
--  in den SavedVariables gemerkt. Crits werden dabei ignoriert (sie
--  wuerden die Vorhersage dauerhaft aufblasen).
--
--  Debug:  /fbp        Status + ausgelesene Tooltip-Werte
--          /fbp debug  Live-Ausgabe an/aus
--          /fbp reset  Gelernte Werte verwerfen
-- ==========================================================================

FBPREDICT_TICK_DEFAULT = 3;     -- Standard-Tickintervall in Sekunden
FBPREDICT_THROTTLE     = 0.2;   -- Update-Rate der Vorhersage
FBPREDICT_CONFIRM_TIME = 3.0;   -- Wartezeit auf Aura-Bestaetigung nach Cast
FBPREDICT_TARGET_TIME  = 2.0;   -- wie lange ein gemerktes Cast-Ziel gilt
FBPredictDebug = false;

-- Zauber mit abweichendem Tickintervall
FBPredictTickInterval = {
    ["Lifebloom"] = 1,
};

FBHoTs    = {};          -- [Name] = { [Zauber] = {rank, perTick, interval, expires} }
FBShields = {};          -- [Name] = { spell, rank, max, absorbed, expires }
FBBuffTimers = {};       -- [Name] = { [Zauber] = { expires } }  Buffs mit Laufzeit (eigene Casts, eigene Buffs)
FBBuffPresent = {};      -- [Name] = { [Zauber] = true }  Buff (Textur) ist auf der Einheit
FBPredictDirect = nil;   -- laufender Direktcast { target, spell, rank, amount, finish }

FBPredictWatch      = {};    -- [Zauber] = { tex, bookID, rank, hasDirect, hasHoT, hasShield }
FBPredictInfo       = {};    -- Cache: [bookID] = Tooltip-Auswertung
FBPredictPending    = nil;   -- eigener Cast, wartet auf Aura-Bestaetigung
FBPredictCastTarget = nil;   -- exaktes Ziel des letzten Button-Casts
FBPredictCastTime   = 0;
FBPredictAccum      = 0;

-- alle Slots inkl. Begleiter. HoTs und Schilde auf Pets werden genauso verfolgt
FBPredictUnits = {};
for _, u in ipairs(FBPartyUnit) do FBPredictUnits[u] = 1; end

-- [ Tooltip-Scanner ] ------------------------------------------------------

FBPredictTip = CreateFrame("GameTooltip", "FBHealBoxScanTip", nil, "GameTooltipTemplate");
FBPredictTip:SetOwner(UIParent, "ANCHOR_NONE");

function FBPredict_TooltipText(bookID)
    if (not bookID) then return ""; end
    FBPredictTip:SetOwner(UIParent, "ANCHOR_NONE");
    FBPredictTip:ClearLines();
    FBPredictTip:SetSpell(bookID, BOOKTYPE_SPELL);

    local txt = "";
    local secs = nil;
    local i = 1;
    while (i <= 30) do
        local fs = getglobal("FBHealBoxScanTipTextLeft"..i);
        if (not fs or not fs:IsShown()) then break; end
        local line = fs:GetText();
        if (line) then txt = txt.." "..line; end
        -- Die Zauberzeit steht rechts ("2.5 sec cast", "Instant cast"). Sie
        -- kommt bewusst nicht in txt: eine Zahl wie 2.5 wuerde die Muster
        -- fuer Schilddauer und Heilbetrag durcheinanderbringen. Hier wird sie
        -- nur nebenbei gelesen, solange der Tooltip ohnehin steht, und
        -- gemerkt. Der Ausruestungsbonus braucht dann keinen eigenen Scan.
        if (secs == nil) then
            local rs = getglobal("FBHealBoxScanTipTextRight"..i);
            if (rs and rs:IsShown()) then
                local rline = rs:GetText();
                if (rline) then
                    local _, _, v = string.find(rline, "([%d%.]+)%s+[Ss]ec%s+cast");
                    if (v) then secs = tonumber(v); end
                    if (secs == nil) and string.find(rline, "[Ii]nstant") then secs = 0; end
                end
            end
        end
        i = i + 1;
    end
    if (FBSpellCastCache[bookID] == nil) then
        FBSpellCastCache[bookID] = secs or false;
    end
    return txt;
end

function FBPredict_Find1(txt, patterns)
    for _, p in ipairs(patterns) do
        local _, _, a = string.find(txt, p);
        if (a) then return a; end
    end
    return nil;
end

function FBPredict_Find2(txt, patterns)
    for _, p in ipairs(patterns) do
        local _, _, a, b = string.find(txt, p);
        if (a and b) then return a, b; end
    end
    return nil;
end

-- Wertet den Zauberbuch-Tooltip aus. Ein Zauber kann mehrere Anteile
-- haben (Regrowth: Sofortheilung UND HoT), deshalb keine Entweder-Oder-
-- Klassifizierung, sondern drei unabhaengige Felder.
-- Ist das Wort hinter einer Zahl eine Zeiteinheit? ("sec", "min", "hr", ...)
function FBPredict_IsTimeUnit(word)
    if (not word) then return false; end
    word = string.lower(word);
    return (string.find(word, "^sec") or string.find(word, "^min") or string.find(word, "^hr")
            or string.find(word, "^hour") or string.find(word, "^sek") or string.find(word, "^std")
            or string.find(word, "^s$")) ~= nil;
end

-- Laufzeit eines Buffs in Sekunden ("for 30 min", "Lasts 3 min", "1 hr",
-- "for 15 sec") oder nil. Die groesste gefundene Angabe gewinnt, damit
-- nicht eine Zauberzeit ("1.5 sec cast") erwischt wird.
function FBPredict_FindBuffDuration(txt)
    if (not txt) then return nil; end
    local best = nil;
    for n, unit in string.gfind(txt, "(%d+)%s+(%a+)") do
        local u = string.lower(unit);
        local secs = nil;
        if (string.find(u, "^min")) then secs = tonumber(n) * 60;
        elseif (string.find(u, "^hr") or string.find(u, "^hour") or string.find(u, "^std")) then secs = tonumber(n) * 3600;
        elseif (string.find(u, "^sec") or string.find(u, "^sek")) then secs = tonumber(n); end
        if (secs and ((not best) or secs > best)) then best = secs; end
    end
    return best;
end

-- "X to Y" ohne Zeiteinheit dahinter -> X, Y (Zahlen) oder nil
function FBPredict_FindAmountRange(txt)
    if (not txt) then return nil; end
    local pos = 1;
    while true do
        local s, e, lo, hi, tail = string.find(txt, "(%d+)%s+to%s+(%d+)%s*(%a*)", pos);
        if (not s) then return nil; end
        if (not FBPredict_IsTimeUnit(tail)) then return tonumber(lo), tonumber(hi); end
        pos = e + 1;
    end
end

-- "for X" ohne Zeiteinheit dahinter -> X (Zahl) oder nil
function FBPredict_FindAmountSingle(txt)
    if (not txt) then return nil; end
    local pos = 1;
    while true do
        local s, e, n, tail = string.find(txt, "for%s+(%d+)%s*(%a*)", pos);
        if (not s) then return nil; end
        if (not FBPredict_IsTimeUnit(tail)) then return tonumber(n); end
        pos = e + 1;
    end
end

function FBPredict_GetSpellInfo(bookID, spellName)
    if (not bookID) then return nil; end
    if (FBPredictInfo[bookID] ~= nil) then
        if (FBPredictInfo[bookID] == false) then return nil; end
        return FBPredictInfo[bookID];
    end

    local txt  = FBPredict_TooltipText(bookID);
    local info = { direct = nil, hot = nil, shield = nil };
    local found = false;

    -- --- Absorb-Schild ---
    local absorb = FBPredict_Find1(txt, {
        "absorbing%s+(%d+)",
        "absorbs%s+(%d+)%s+damage",
    });
    if (absorb) then
        -- "Lasts 30 sec" bevorzugen; sonst die groesste Sekundenangabe,
        -- damit nicht die Zauberzeit ("1.5 sec cast") erwischt wird.
        local dur = FBPredict_Find1(txt, { "[Ll]asts%s+(%d+)%s+sec" });
        if (not dur) then
            local best = 0;
            for n in string.gfind(txt, "(%d+)%s+sec") do
                if (tonumber(n) > best) then best = tonumber(n); end
            end
            if (best > 0) then dur = best; end
        end
        info.shield = { amount = tonumber(absorb), duration = tonumber(dur) or 30 };
        found = true;
    end

    -- --- Heilung ueber Zeit ---
    local total, dur = FBPredict_Find2(txt, {
        "(%d+)%s+damage%s+over%s+(%d+)%s+sec",
        "(%d+)%s+over%s+(%d+)%s+sec",
        "for%s+(%d+)[^%d]-over%s+(%d+)%s+sec",
    });
    if (not total) then
        -- Notfall: letzte Zahl vor "over X sec" nehmen
        local s, _, d = string.find(txt, "over%s+(%d+)%s+sec");
        if (s) then
            local head = string.sub(txt, 1, s);
            local last = nil;
            for n in string.gfind(head, "(%d+)") do last = n; end
            if (last) then total = last; dur = d; end
        end
    end
    if (total and dur) then
        local interval = FBPredictTickInterval[spellName] or FBPREDICT_TICK_DEFAULT;
        local ticks = math.floor((tonumber(dur) / interval) + 0.5);
        if (ticks < 1) then ticks = 1; end
        info.hot = {
            total    = tonumber(total),
            duration = tonumber(dur),
            interval = interval,
            ticks    = ticks,
            perTick  = tonumber(total) / ticks,
        };
        found = true;
    end

    -- --- Sofortheilung ---
    -- "for 887 to 1033"  ->  Mittelwert. Zeitangaben ("for 30 min",
    -- "for 15 sec", "2 to 3 sec") sind keine Heilbetraege.
    local lo, hi = FBPredict_FindAmountRange(txt);
    if (lo and hi) then
        info.direct = (lo + hi) / 2;
        found = true;
    else
        -- Einzelwert, aber nicht den HoT-Betrag doppelt zaehlen
        local one = FBPredict_FindAmountSingle(txt);
        if (one) and ((not info.hot) or (one ~= info.hot.total)) then
            info.direct = one;
            found = true;
        end
    end
    -- Heilt der Zauber ueberhaupt? (Buffs wie Seelenstaerke haben Zahlen,
    -- aber kein "heal" im Text; Smart Healing verlangt das.)
    info.isHeal = (string.find(txt, "[Hh]eal") ~= nil);

    -- --- Buff mit Laufzeit (Seelenstaerke "for 30 min", Furchtzauberschutz
    -- "Lasts 3 min", Inneres Feuer "10 min"): nur, wenn es kein HoT, kein
    -- Schild und keine Heilung ist. Liefert die Restlaufzeit auf dem Button.
    if (not info.hot) and (not info.shield) and (not info.isHeal) then
        local secs = FBPredict_FindBuffDuration(txt);
        if (secs and secs >= 30) then
            info.buff = { duration = secs };
            found = true;
        end
    end

    if (found) then
        FBPredictInfo[bookID] = info;
        return info;
    end
    FBPredictInfo[bookID] = false;
    return nil;
end

-- Nach jedem Zauberbuch-Scan: was koennen die gelernten Zauber ueberhaupt?
FBPredictWatchBuffOrder = {};   -- Buff-Zauber alphabetisch (fuer die Icon-Reihenfolge)

function FBPredict_BuildWatch()
    FBPredictWatch = {};
    FBPredictInfo  = {};
    FBPredictWatchBuffOrder = {};

    for spellName, ranks in pairs(FBPlayerSpells) do
        local top  = ranks[table.getn(ranks)];
        local info = FBPredict_GetSpellInfo(top.id, spellName);
        if (info) then
            local alt = FBBuffAlternates[spellName];
            local altTex = alt and FBBuffSpells[alt] and strupper(FBBuffSpells[alt].icon or "");
            FBPredictWatch[spellName] = {
                tex       = strupper(top.icon or ""),
                altTex    = altTex,
                bookID    = top.id,
                rank      = top.rank,
                hasDirect = (info.direct ~= nil),
                hasHoT    = (info.hot ~= nil),
                hasShield = (info.shield ~= nil),
                hasBuff   = (info.buff ~= nil),
                buffSecs  = info.buff and info.buff.duration,
                icon      = top.icon,
            };
            if (info.buff) then table.insert(FBPredictWatchBuffOrder, spellName); end
        end
    end
    table.sort(FBPredictWatchBuffOrder);
end

-- Buff per eigenem Button auf ein Ziel neu gewirkt, das ihn schon traegt:
-- ein Refresh loest kein Aura-Event aus, also gilt der erfolgreiche Cast
-- (SPELLCAST_STOP) als Bestaetigung und stellt die Uhr auf voll.
function FBPredict_ConfirmBuffRefresh()
    local p = FBPredictPending;
    if (not p) or (not p.spell) or (not p.target) then return; end
    local w = FBPredictWatch[p.spell];
    if (not w) or (not w.hasBuff) then return; end
    if (p.target == UnitName("player")) then return; end   -- eigene Buffs liest die Buff-API
    if (FBBuffPresent[p.target] and FBBuffPresent[p.target][p.spell]) then
        FBPredict_StartBuff(p.target, p.spell, w.buffSecs);
        FBPredictPending = nil;
    end
end

-- Buff-Laufzeit auf einer Einheit vermerken
function FBPredict_StartBuff(unitName, spellName, secs)
    if (not unitName) or (not spellName) or (not secs) then return; end
    if (not FBBuffTimers[unitName]) then FBBuffTimers[unitName] = {}; end
    local t = FBBuffTimers[unitName][spellName];
    if (t) then t.expires = GetTime() + secs; else FBBuffTimers[unitName][spellName] = { expires = GetTime() + secs }; end
    FBBuffIconsDirty = true;
end

-- Restlaufzeiten aller eigenen Buffs, [TEXTUR] = Sekunden.
--
-- Frueher lief je gesuchtem Buff eine eigene Schleife ueber die gesamte
-- Buffliste. Bei sechs Wachen und dreissig Buffs waren das rund 200 Aufrufe
-- je Sekunde. Jetzt wird die Liste einmal je Frame gelesen und alle Wachen
-- bedienen sich daraus; der Zeitstempel arbeitet wie bei FBHealBox_UnitBuffs.
FBPlayerBuffLeft  = {};
FBPlayerBuffStamp = nil;

function FBPredict_ScanPlayerBuffTimes()
    local now = GetTime();
    if (FBPlayerBuffStamp == now) then return FBPlayerBuffLeft; end
    FBPlayerBuffStamp = now;
    for k in pairs(FBPlayerBuffLeft) do FBPlayerBuffLeft[k] = nil; end
    if (not GetPlayerBuff) or (not GetPlayerBuffTexture) or (not GetPlayerBuffTimeLeft) then
        return FBPlayerBuffLeft;
    end
    local i = 0;
    while true do
        local id = GetPlayerBuff(i, "HELPFUL");
        if (not id) or (id < 0) then break; end
        local t = GetPlayerBuffTexture(id);
        if (t) then
            local left = GetPlayerBuffTimeLeft(id);
            if (left and left > 0) then
                local up = FBHealBox_UpperTex(t);
                -- gleiche Textur mehrfach (etwa gestapelte Buffs): laengste Zeit
                if (not FBPlayerBuffLeft[up]) or (left > FBPlayerBuffLeft[up]) then
                    FBPlayerBuffLeft[up] = left;
                end
            end
        end
        i = i + 1;
    end
    return FBPlayerBuffLeft;
end

-- Restlaufzeit eines eigenen Buffs (Textur, gross geschrieben) oder nil
function FBPredict_PlayerBuffTimeLeft(tex)
    if (not tex) then return nil; end
    return FBPredict_ScanPlayerBuffTimes()[tex];
end

-- [ Lernspeicher (wandert in die SavedVariables) ] --------------------------

FBPREDICT_ABSORB_MAX_FACTOR = 1.5;

-- Unplausible Absorb-Lernwerte verwerfen (etwa doppelt gezaehlte aus
-- aelteren Versionen). Laeuft nach dem Einlesen der Zauber.
function FBPredict_SanitizeMemory()
    if (not HealBox) or (not HealBox.PredictMemory) then return; end
    local drop = {};
    for key, value in pairs(HealBox.PredictMemory) do
        local _, _, spell, rank = string.find(key, "^absorb|([^|]+)|(.*)$");
        if (spell) then
            local bookID = FBPredict_FindBookID(spell, rank);
            local info = bookID and FBPredict_GetSpellInfo(bookID, spell);
            if (info and info.shield and value > info.shield.amount * FBPREDICT_ABSORB_MAX_FACTOR) then
                table.insert(drop, key);
            end
        end
    end
    for _, key in ipairs(drop) do
        HealBox.PredictMemory[key] = nil;
        if (FBPredictDebug) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r memory dropped: "..key);
        end
    end
end

function FBPredict_MemKey(kind, spell, rank)
    return kind.."|"..spell.."|"..(rank or "");
end

function FBPredict_Remembered(kind, spell, rank)
    if (not HealBox) or (not HealBox.PredictMemory) then return nil; end
    return HealBox.PredictMemory[FBPredict_MemKey(kind, spell, rank)];
end

function FBPredict_Remember(kind, spell, rank, value)
    if (not HealBox) then return; end
    if (not HealBox.PredictMemory) then HealBox.PredictMemory = {}; end
    HealBox.PredictMemory[FBPredict_MemKey(kind, spell, rank)] = value;
end

-- [ Tracking starten ] -----------------------------------------------------

function FBPredict_FindBookID(spellName, rank)
    local ranks = FBPlayerSpells[spellName];
    if (not ranks) then return nil; end
    for _, sd in ipairs(ranks) do
        if (sd.rank == rank) then return sd.id; end
    end
    return ranks[table.getn(ranks)].id;
end

-- rankKnown = true nur, wenn der Rang aus einem eigenen Button-Cast stammt.
-- Nur dann darf der beobachtete Wert dauerhaft gemerkt werden, sonst
-- wuerde ein Rang-3-Cast von der Aktionsleiste die Schaetzung fuer den
-- Maximalrang verderben.
function FBPredict_StartHoT(unitName, spellName, rank, bookID, rankKnown)
    local info = FBPredict_GetSpellInfo(bookID, spellName);
    if (not info) or (not info.hot) then return false; end

    local perTick = FBPredict_Remembered("tick", spellName, rank) or info.hot.perTick;
    if (not FBHoTs[unitName]) then FBHoTs[unitName] = {}; end
    FBHoTs[unitName][spellName] = {
        rank      = rank,
        rankKnown = rankKnown,
        perTick  = perTick,
        interval = info.hot.interval,
        expires  = GetTime() + info.hot.duration,
    };

    if (FBPredictDebug) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[FBP]|r "..format(FBT("DBG_HOT"),
            spellName, unitName, math.floor(perTick), info.hot.duration));
    end

    -- Nur gesicherte eigene Casts funken. Ein per Aura entdeckter HoT
    -- koennte auch von einem anderen Heiler stammen. Der erste eigene
    -- Combatlog-Tick holt das unten nach.
    if (rankKnown) then
        FBHoTs[unitName][spellName].commSent = true;
        FBComm_SendHoT(spellName, unitName, info.hot.duration);
    end
    return true;
end

function FBPredict_StartShield(unitName, spellName, rank, bookID, rankKnown)
    local info = FBPredict_GetSpellInfo(bookID, spellName);
    if (not info) or (not info.shield) then return false; end

    -- Gelernter Wert nur, wenn er plausibel ist (hoechstens das
    -- FBPREDICT_ABSORB_MAX_FACTOR-fache des Tooltips); sonst Tooltip.
    local amount = FBPredict_Remembered("absorb", spellName, rank);
    if (not amount) or (amount > info.shield.amount * FBPREDICT_ABSORB_MAX_FACTOR) then
        amount = info.shield.amount;
    end
    FBShields[unitName] = {
        spell     = spellName,
        rank      = rank,
        rankKnown = rankKnown,
        tooltip  = info.shield.amount,
        duration = info.shield.duration,
        max      = amount,
        absorbed = 0,
        expires  = GetTime() + info.shield.duration,
    };

    if (FBPredictDebug) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[FBP]|r "..format(FBT("DBG_SHIELD"),
            spellName, unitName, math.floor(amount), info.shield.duration));
    end
    return true;
end

-- [ Abfrage durch die Balken ] ---------------------------------------------

function FBPredict_TicksLeft(e, now)
    local left = e.expires - now;
    if (left <= 0) then return 0; end
    return math.ceil((left / e.interval) - 0.05);
end

-- Summe aller noch ausstehenden HoT-Ticks
function FBGetHoTHeal(unitName)
    if (not unitName) then return 0; end
    local t = FBHoTs[unitName];
    if (not t) then return 0; end

    local now = GetTime();
    local sum = 0;
    for _, e in pairs(t) do
        local n = FBPredict_TicksLeft(e, now);
        if (n > 0) then sum = sum + (n * e.perTick); end
    end
    return sum;
end

-- Laufender Direktcast auf diese Einheit
function FBGetDirectHeal(unitName)
    local d = FBPredictDirect;
    if (not d) or (not unitName) then return 0; end
    if (d.target ~= unitName) then return 0; end
    if (GetTime() > d.finish) then return 0; end
    return d.amount;
end

-- Verbleibender Absorb
function FBGetShield(unitName)
    if (not unitName) then return 0; end
    local s = FBShields[unitName];
    if (not s) then return 0; end
    if (GetTime() > s.expires) then return 0; end

    local rem = s.max - s.absorbed;
    if (rem < 0) then rem = 0; end
    return rem;
end

-- [ Eigenen Cast vormerken (aus dem HealBox-Button) ] -----------------------

function FBPredict_SplitCast(castString)
    local _, _, base, rank = string.find(castString, "^(.+)%((.+)%)$");
    if (base) then return base, rank; end
    return castString, nil;
end

-- WICHTIG: direkt VOR CastSpellByName aufrufen, denn SPELLCAST_START feuert
-- sofort und braucht das Ziel bereits.
function FBPredict_NoteCast(castString, targetName)
    if (not castString) or (not targetName) then return; end

    FBPredictCastTarget = targetName;
    FBPredictCastTime   = GetTime();

    local base, rank = FBPredict_SplitCast(castString);
    if (not FBPredictWatch[base]) then return; end

    FBPredictPending = {
        spell  = base,
        rank   = rank,
        target = targetName,
        bookID = FBPredict_FindBookID(base, rank),
        t      = GetTime(),
    };
end

function FBPredict_ResolveTarget()
    if (FBPredictCastTarget and (GetTime() - FBPredictCastTime) <= FBPREDICT_TARGET_TIME) then
        return FBPredictCastTarget;
    end
    if (UnitExists("target") and UnitIsFriend("player", "target")) then
        return UnitName("target");
    end
    return UnitName("player");
end

-- [ Direktheilung: SPELLCAST_* ] -------------------------------------------

function FBPredict_CastStart(spellName, castMs)
    if (not spellName) then return; end
    local w = FBPredictWatch[spellName];
    if (not w) or (not w.hasDirect) then return; end

    local rank      = w.rank;
    local bookID    = w.bookID;
    local rankKnown = false;
    if (FBPredictPending and FBPredictPending.spell == spellName) then
        rank      = FBPredictPending.rank or rank;
        bookID    = FBPredictPending.bookID or bookID;
        rankKnown = true;
    end

    local info = FBPredict_GetSpellInfo(bookID, spellName);
    if (not info) or (not info.direct) then return; end

    local amount = FBPredict_ExpectedDirect(spellName, rank, info, bookID) or info.direct;
    FBLOS_Clear(FBPredict_ResolveTarget());   -- Cast laeuft an: Sichtlinie ist da

    FBPredictDirect = {
        target    = FBPredict_ResolveTarget(),
        spell     = spellName,
        rank      = rank,
        rankKnown = rankKnown,
        amount    = amount,
        finish = GetTime() + ((castMs or 0) / 1000) + 0.3,
    };

    if (FBPredictDebug) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[FBP]|r "..format(FBT("DBG_CAST"),
            spellName, FBPredictDirect.target, math.floor(amount)));
    end

    -- an andere Heiler funken (Puppeteer & Co. lesen mit)
    FBComm_SendHealStart(spellName, FBPredictDirect.target, amount, castMs);

    FBHealBox_RefreshAllBars();
end

function FBPredict_CastEnd()
    if (FBPredictDirect) then
        FBPredictDirect = nil;
        FBHealBox_RefreshAllBars();
    end
end

-- [ Aura-Scan: Anwendung bestaetigen, Wegfall erkennen ] --------------------

function FBPredict_ScanUnit(unit)
    if (not unit) or (not FBPredictUnits[unit]) then return; end
    if (not UnitExists(unit)) then return; end

    local name = UnitName(unit);
    if (not name) then return; end

    -- Raid-Einheiten: nur scannen, wenn etwas davon abhaengt (eigener Cast
    -- wartet, HoT/Schild wird verfolgt, oder die Zelle ist zu sehen). Sonst
    -- kosten 40 Raider mit staendig wechselnden Auren nur CPU.
    if (string.sub(unit, 1, 4) == "raid") then
        local needed = (FBPredictPending and FBPredictPending.target == name)
            or FBHoTs[name] or FBShields[name];
        if (not needed) then
            local c = FBRaidUnitCell and FBRaidUnitCell[unit];
            if (not c) or (not c:IsShown()) then return; end
        end
    end

    local textures = FBHealBox_UnitBuffs(unit);

    local dirty = false;

    -- 1) Eigener Cast wartet auf Bestaetigung? Der hat Vorrang, damit auch
    --    ein Refresh (Nachcasten) die Uhr neu stellt.
    if (FBPredictPending and FBPredictPending.target == name) then
        local w = FBPredictWatch[FBPredictPending.spell];
        if (w and (textures[w.tex] or (w.altTex and textures[w.altTex]))) then
            if (w.hasHoT) then
                dirty = FBPredict_StartHoT(name, FBPredictPending.spell,
                            FBPredictPending.rank, FBPredictPending.bookID, true) or dirty;
            end
            if (w.hasShield) then
                dirty = FBPredict_StartShield(name, FBPredictPending.spell,
                            FBPredictPending.rank, FBPredictPending.bookID, true) or dirty;
            end
            if (w.hasBuff) then
                FBPredict_StartBuff(name, FBPredictPending.spell, w.buffSecs);
            end
            FBPredictPending = nil;
        end
    end

    -- Buff-Laufzeiten: beim Spieler exakt aus der Spielerbuff-API, bei
    -- anderen nur eigene Casts (oben); weg ist weg. Praesenz merken, damit
    -- die Plakette auch fremde Buffs (ohne Uhr) zeigen kann.
    if (not FBBuffPresent[name]) then FBBuffPresent[name] = {}; end
    for spellName, w in pairs(FBPredictWatch) do
        if (w.hasBuff) then
            local present = textures[w.tex] or (w.altTex and textures[w.altTex]);
            if (FBBuffPresent[name][spellName] ~= present) then FBBuffIconsDirty = true; end
            FBBuffPresent[name][spellName] = present;
            local tracked = FBBuffTimers[name] and FBBuffTimers[name][spellName];
            if (present and unit == "player") then
                local left = FBPredict_PlayerBuffTimeLeft(w.tex) or (w.altTex and FBPredict_PlayerBuffTimeLeft(w.altTex));
                if (left) then FBPredict_StartBuff(name, spellName, left); end
            elseif (tracked and not present) then
                FBBuffTimers[name][spellName] = nil;
            end
        end
    end

    -- 2) Generischer Abgleich: Buff da / Buff weg
    for spellName, w in pairs(FBPredictWatch) do
        local present = textures[w.tex];

        if (w.hasHoT) then
            local tracked = FBHoTs[name] and FBHoTs[name][spellName];
            if (present and not tracked) then
                -- z.B. von der Aktionsleiste: hoechster bekannter Rang,
                -- der erste Combatlog-Tick korrigiert den Wert ohnehin
                dirty = FBPredict_StartHoT(name, spellName, w.rank, w.bookID) or dirty;
            elseif (tracked and not present) then
                FBHoTs[name][spellName] = nil;
                dirty = true;
            end
        end

        if (w.hasShield) then
            local tracked = FBShields[name];
            if (present and ((not tracked) or tracked.spell ~= spellName)) then
                dirty = FBPredict_StartShield(name, spellName, w.rank, w.bookID) or dirty;
            elseif (tracked and tracked.spell == spellName and not present) then
                -- Schild gebrochen (vor Ablauf) -> Maximum nach oben lernen
                if (tracked.rankKnown and GetTime() < tracked.expires
                    and tracked.absorbed > tracked.max) then
                    FBPredict_Remember("absorb", tracked.spell, tracked.rank, tracked.absorbed);
                end
                FBShields[name] = nil;
                dirty = true;
            end
        end
    end

    if (dirty) then FBHealBox_RefreshAllBars(); end
end

-- [ Combatlog ] ------------------------------------------------------------

function FBPredict_ToPattern(gs, anchor)
    if (not gs) then return nil; end
    local p = string.gsub(gs, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1");
    p = string.gsub(p, "%%s", "(.+)");
    p = string.gsub(p, "%%d", "(%%d+)");
    if (anchor) then return "^"..p.."$"; end
    return p;
end

-- Feststehendes Wortstueck aus einer Client-Vorlage schneiden: alles vor dem
-- ersten Platzhalter faellt weg, alles ab dem naechsten ebenfalls, uebrig
-- bleibt ein Stueck reiner Text fuer den billigen Vortest. Bei "Your %s heals
-- %s for %d." ist das " heals ". Klappt das nicht, greift der Rueckfall.
function FBPredict_PlainPart(template, fallback)
    if (not template) or (type(template) ~= "string") then return fallback; end
    local s1, e1 = string.find(template, "%%%a");
    if (not s1) then return fallback; end
    local rest = string.sub(template, e1 + 1);
    local s2 = string.find(rest, "%%%a");
    if (s2) then rest = string.sub(rest, 1, s2 - 1); end
    -- Satzzeichen am Ende stoeren nicht, zu kurze Stuecke taugen aber nichts
    if (string.len(rest) < 4) then return fallback; end
    return rest;
end

function FBPredict_InitPatterns()
    -- "%s gains %d health from your %s."
    FBPredictPatHoTOther = FBPredict_ToPattern(PERIODICAURAHEALOTHERSELF, true)
                        or "^(.+) gains (%d+) health from your (.+)%.$";
    -- "You gain %d health from your %s."
    FBPredictPatHoTSelf  = FBPredict_ToPattern(PERIODICAURAHEALSELFSELF, true)
                        or "^You gain (%d+) health from your (.+)%.$";
    -- "Your %s heals %s for %d."   (Crits haben eine eigene Formulierung und
    --  laufen deshalb ins Leere, genau so gewollt)
    FBPredictPatHealOther = FBPredict_ToPattern(HEALEDSELFOTHER, true)
                        or "^Your (.+) heals (.+) for (%d+)%.$";
    -- "Your %s heals you for %d."
    FBPredictPatHealSelf  = FBPredict_ToPattern(HEALEDSELFSELF, true)
                        or "^Your (.+) heals you for (%d+)%.$";
    -- " (%d absorbed)"
    FBPredictPatAbsorb    = FBPredict_ToPattern(ABSORB_TRAILER, false)
                        or "%((%d+) absorbed%)";
    -- Vortests: " heals " und " health from your ".
    -- Beim Tick wird bewusst die Selbst-Vorlage genommen: "You gain ..." und
    -- "%s gains ..." unterscheiden sich im Verb, das Stueck dahinter ist in
    -- beiden gleich. Ein aus der Fremd-Vorlage geschnittenes " gains " wuerde
    -- die eigenen Ticks aussperren.
    FBPRED_WORD_HEAL = FBPredict_PlainPart(HEALEDSELFOTHER, " heals ");
    FBPRED_WORD_TICK = FBPredict_PlainPart(PERIODICAURAHEALSELFSELF, " health from your ");
end

-- Events, bei denen das Opfer immer der Spieler selbst ist
FBPredictSelfDamage = {
    ["CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS"]   = 1,
    ["CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"]  = 1,
    ["CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"]     = 1,
    ["CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF"]    = 1,
};

function FBPredict_ResolveVictim(event, msg)
    if (FBPredictSelfDamage[event]) then return UnitName("player"); end

    for name, _ in pairs(FBShields) do
        if (string.find(msg, name, 1, true)) then return name; end
    end

    if (string.find(msg, " you", 1, true) or string.find(msg, "You ", 1, true)) then
        return UnitName("player");
    end
    return nil;
end

function FBPredict_OnTick(unitName, amount, spellName)
    if (not unitName) or (not amount) or (not spellName) then return; end
    FBLOS_Clear(unitName);
    local t = FBHoTs[unitName];
    if (not t) or (not t[spellName]) then return; end

    local e = t[spellName];

    -- "... from your Renew" beweist: der HoT ist von uns. Falls er ueber
    -- die Aktionsleiste kam und noch nicht gefunkt wurde, jetzt nachholen.
    if (not e.commSent) then
        e.commSent = true;
        FBComm_SendHoT(spellName, unitName, e.expires - GetTime());
    end

    if (amount > 0 and e.perTick ~= amount) then
        e.perTick = amount;
        if (e.rankKnown) then
            FBPredict_Remember("tick", spellName, e.rank, amount);
        end
        if (FBPredictDebug) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[FBP]|r "..format(FBT("DBG_TICK"),
                spellName, amount));
        end
    end
    FBHealBox_RefreshAllBars();
end

function FBPredict_OnDirectHeal(spellName, targetName, amount)
    if (not spellName) or (not amount) then return; end
    FBLOS_Clear(targetName);
    local w = FBPredictWatch[spellName];
    if (not w) then return; end   -- faengt auch die Crit-Formulierung ab

    -- Nur lernen, wenn der gecastete Rang gesichert ist (Button-Cast).
    -- Ein Downrank von der Aktionsleiste wuerde sonst dem Maximalrang
    -- zugeschrieben und die Vorhersage nach unten ziehen.
    if (FBPredictDirect and FBPredictDirect.spell == spellName and FBPredictDirect.rankKnown) then
        local rank = FBPredictDirect.rank;
        -- Heilungen streuen innerhalb einer Spanne -> sanft einpendeln
        local old = FBPredict_Remembered("direct", spellName, rank);
        local value = amount;
        if (old) then value = (old + amount) / 2; end
        FBPredict_Remember("direct", spellName, rank, value);

        if (FBPredictDebug) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[FBP]|r "..format(FBT("DBG_HEAL"),
                spellName, amount, math.floor(value)));
        end
    end

    if (FBPredictDirect and FBPredictDirect.target == targetName) then
        FBPredictDirect = nil;
    end
    FBHealBox_RefreshAllBars();
end

function FBPredict_OnAbsorb(unitName, amount)
    local s = FBShields[unitName];
    if (not s) or (not amount) then return; end

    s.absorbed = s.absorbed + amount;
    if (s.absorbed > s.max) then
        -- mehr absorbiert als der Tooltip hergibt (+Heilung) -> anheben.
        -- Dauerhaft gemerkt wird nur ein plausibler Wert: PW:S skaliert in
        -- Vanilla mit rund 10 % der Heilkraft, mehr als das
        -- FBPREDICT_ABSORB_MAX_FACTOR-fache des Tooltips ist ein Zaehlfehler.
        s.max = s.absorbed;
        if (s.rankKnown and s.tooltip and s.max <= s.tooltip * FBPREDICT_ABSORB_MAX_FACTOR) then
            FBPredict_Remember("absorb", s.spell, s.rank, s.max);
        end
    end

    if (FBPredictDebug) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[FBP]|r "..format(FBT("DBG_ABSORB"),
            amount, unitName, math.floor(s.max - s.absorbed)));
    end
    FBHealBox_RefreshAllBars();
end

-- Eventklasse je Eventname einmal bestimmen: Heil-/Tick-Zeilen kommen nur
-- ueber *_BUFF(S)-Events, Absorb-Zeilen nur ueber Treffer-Events. So laufen
-- je Zeile hoechstens die passenden Muster statt aller fuenf.
FBPredictEventClass = {};
function FBPredict_EventClass(event)
    local c = FBPredictEventClass[event];
    if (c) then return c; end
    if (string.find(event, "_BUFF")) then c = "heal"; else c = "hit"; end
    FBPredictEventClass[event] = c;
    return c;
end

function FBPredict_ParseCombat(event, msg)
    if (not msg) then return; end

    if (FBPredict_EventClass(event) == "hit") then
        -- Absorb-Anteil: "... hits Bob for 120. (80 absorbed)" (billiger Vortest)
        if (string.find(msg, "absorbed", 1, true)) then
            local _, _, abs = string.find(msg, FBPredictPatAbsorb);
            if (abs) then
                local victim = FBPredict_ResolveVictim(event, msg);
                if (victim) then FBPredict_OnAbsorb(victim, tonumber(abs)); end
            end
        end
        return;
    end

    -- Vor den verankerten Mustern ein billiger Textvergleich (viertes
    -- Argument true = einfache Suche ohne Musterlogik). Fremde Heilungen und
    -- fremde Ticks fallen so nach einem Vergleich raus statt nach vier
    -- Musterlaeufen; im Raid sind das die meisten Meldungen.
    if (string.find(msg, FBPRED_WORD_HEAL, 1, true)) then
        -- Direktheilung auf jemand anderen: "Your Flash Heal heals Bob for 1240."
        local _, _, spell, who, amt = string.find(msg, FBPredictPatHealOther);
        if (spell and who and amt) then
            FBPredict_OnDirectHeal(spell, who, tonumber(amt));
            return;
        end

        -- Direktheilung auf mich: "Your Flash Heal heals you for 1240."
        local _, _, spell2, amt2 = string.find(msg, FBPredictPatHealSelf);
        if (spell2 and amt2) then
            FBPredict_OnDirectHeal(spell2, UnitName("player"), tonumber(amt2));
            return;
        end
    end

    if (string.find(msg, FBPRED_WORD_TICK, 1, true)) then
        -- HoT-Tick auf jemand anderen: "Bob gains 194 health from your Renew."
        local _, _, who3, amt3, spell3 = string.find(msg, FBPredictPatHoTOther);
        if (who3 and amt3 and spell3) then
            FBPredict_OnTick(who3, tonumber(amt3), spell3);
            return;
        end

        -- HoT-Tick auf mich: "You gain 194 health from your Renew."
        local _, _, amt4, spell4 = string.find(msg, FBPredictPatHoTSelf);
        if (amt4 and spell4) then
            FBPredict_OnTick(UnitName("player"), tonumber(amt4), spell4);
            return;
        end
    end
end

-- [ Event-Frame ] ----------------------------------------------------------

FBPredictEvents = {
    "UNIT_AURA",
    "PLAYER_AURAS_CHANGED",   -- eigene Buffs: 1.12 feuert hierfuer kein UNIT_AURA("player")
    "CHAT_MSG_ADDON",
    "UI_ERROR_MESSAGE",      -- Sichtlinien-Fehler
    -- eigener Cast
    "SPELLCAST_START",
    "SPELLCAST_STOP",
    "SPELLCAST_FAILED",
    "SPELLCAST_INTERRUPTED",
    "SPELLCAST_DELAYED",
    -- angekommene Heilung + HoT-Ticks
    "CHAT_MSG_SPELL_SELF_BUFF",
    "CHAT_MSG_SPELL_PARTY_BUFF",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
    "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
    -- Schaden mit Absorb-Anteil
    "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS",
    "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS",
    "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS",
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF",
};

FBPredictFrame = CreateFrame("Frame", "FBHealBoxPredict", UIParent);
for _, ev in ipairs(FBPredictEvents) do
    pcall(function() FBPredictFrame:RegisterEvent(ev); end);
end

FBPredictFrame:SetScript("OnEvent", function()
    if (FBAddonSuppressed) then return; end
    if (event == "UNIT_AURA") then
        FBPredict_ScanUnit(arg1);

    elseif (event == "PLAYER_AURAS_CHANGED") then
        FBPredict_ScanUnit("player");

    elseif (event == "CHAT_MSG_ADDON") then
        FBComm_OnMessage(arg1, arg2, arg3, arg4);

    elseif (event == "UI_ERROR_MESSAGE") then
        FBLOS_OnError(arg1);

    elseif (event == "SPELLCAST_START") then
        FBPredict_CastStart(arg1, tonumber(arg2));

    elseif (event == "SPELLCAST_STOP") then
        -- Erfolgreich beendet: HealComm-Empfaenger lassen den Eintrag
        -- selbst auslaufen, hier wird bewusst kein Healstop gefunkt.
        FBPredict_ConfirmBuffRefresh();
        FBPredict_CastEnd();

    elseif (event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED") then
        if (FBPredictDirect) then FBComm_SendHealStop(); end
        FBPredict_CastEnd();

    elseif (event == "SPELLCAST_DELAYED") then
        if (FBPredictDirect and arg1) then
            FBPredictDirect.finish = FBPredictDirect.finish + (tonumber(arg1) / 1000);
            FBComm_SendHealDelay(arg1);
        end

    else
        FBPredict_ParseCombat(event, arg1);
    end
end);

FBPredictFrame:SetScript("OnUpdate", function()
    if (FBAddonSuppressed) then return; end
    FBPredict_OnUpdate(arg1);
end);

FBNamesDirty = false;
FBBlizzPartyDirty = false;
FBDirtyNames = {};        -- im Takt betroffene Einheitennamen (wiederverwendet)
FBFullRefreshAccum = 0;   -- Sekunden seit dem letzten vollen Durchlauf
FBBtnStatesDirty = nil;
FBBuffIconsDirty = true;
FBBuffIconsAccum = 0;

function FBPredict_OnUpdate(elapsed)
    -- Aufgeschobene Gruppen-Aktualisierung (Event-Salven zusammengefasst)
    if (FBNamesDirty) then
        FBNamesDirty = false;
        FBUpdateNames();
    end
    -- Blizzards Gruppenfenster im selben Sammelpunkt, statt bei jedem
    -- einzelnen Ereignis einer Salve
    if (FBBlizzPartyDirty) then
        FBBlizzPartyDirty = false;
        FBHealBox_ApplyBlizzParty();
    end
    -- Aufgeschobene Button-Zustaende (USABLE schlaegt COOLDOWN, da es beides tut)
    if (FBBtnStatesDirty) then
        local ev = FBBtnStatesDirty;
        FBBtnStatesDirty = nil;
        FBHealBox_UpdateButtonStates(ev);
    end

    -- Reichweiten-Fading laeuft im eigenen Takt mit
    FBRangeAccum = FBRangeAccum + (elapsed or 0);
    if (FBRangeAccum >= FBRANGE_INTERVAL) then
        FBRangeAccum = 0;
        FBHealBox_CheckRangeAll();
        FBHealBox_CheckLOSAll();
    end

    FBPredictAccum = FBPredictAccum + (elapsed or 0);
    if (FBPredictAccum < FBPREDICT_THROTTLE) then return; end
    FBPredictAccum = 0;

    -- Angegriffenen markieren, Button-Timer und Buff-Icons nachfuehren (0.2-s-Takt).
    -- Die Uhr-Quadranten aendern sich langsam: Buff-Icons nur bei Aenderung
    -- (Scan hat etwas gemeldet) oder einmal je Sekunde.
    FBHealBox_CheckAggroAll();
    FBHealBox_UpdateSpellTimers();
    FBPredict_RefreshPlayerBuffs(FBPREDICT_THROTTLE);
    FBBuffIconsAccum = FBBuffIconsAccum + FBPREDICT_THROTTLE;
    if (FBBuffIconsDirty or FBBuffIconsAccum >= 1.0 or FBTestMode) then
        FBBuffIconsDirty = false;
        FBBuffIconsAccum = 0;
        FBHealBox_UpdateAllBuffIcons();
    end

    local now   = GetTime();
    local dirty = false;
    local full  = false;

    -- Betroffene Einheiten einsammeln statt pauschal alles neu zu zeichnen.
    -- Die Tabelle wird wiederverwendet und nur geleert, damit je Durchlauf
    -- keine neue entsteht.
    local names = FBDirtyNames;
    for k in pairs(names) do names[k] = nil; end

    for uname, spells in pairs(FBHoTs) do
        local anyLeft = false;
        for spellName, e in pairs(spells) do
            if (now >= e.expires) then
                spells[spellName] = nil;
                names[uname] = true;
                dirty = true;
            else
                anyLeft = true;
                local n = FBPredict_TicksLeft(e, now);
                if (n ~= e.lastTicks) then
                    e.lastTicks = n;
                    names[uname] = true;
                    dirty = true;
                end
            end
        end
        -- leere Untertabelle wegraeumen: andernorts wird FBHoTs[name] als
        -- "laeuft da ein HoT?" gelesen, und eine leere Tabelle ist wahr
        if (not anyLeft) then FBHoTs[uname] = nil; end
    end

    for name, s in pairs(FBShields) do
        if (now >= s.expires) then
            FBShields[name] = nil;
            names[name] = true;
            dirty = true;
        end
    end

    for uname, casters in pairs(FBCommHeals) do
        local anyLeft = false;
        for caster, info in pairs(casters) do
            if (now >= info.expires) then
                casters[caster] = nil;
                names[uname] = true;
                dirty = true;
            else
                anyLeft = true;
            end
        end
        if (not anyLeft) then FBCommHeals[uname] = nil; end
    end

    if (FBPredictDirect and now > FBPredictDirect.finish) then
        if (FBPredictDirect.target) then names[FBPredictDirect.target] = true; end
        FBPredictDirect = nil;
        dirty = true;
    end

    if (FBPredictPending and (now - FBPredictPending.t) > FBPREDICT_CONFIRM_TIME) then
        FBPredictPending = nil;
    end

    -- Testmodus: die Geister atmen, da muss alles mit
    if (FBTestMode) then dirty = true; full = true; end

    -- Sicherheitsnetz: hoechstens einmal je Sekunde doch der volle Durchlauf,
    -- falls ein Name einmal zu keiner Plakette passt. Kostet gegenueber
    -- frueher immer noch nur einen Bruchteil, weil es vorher mehrmals je
    -- Sekunde passierte.
    if (dirty) then
        FBFullRefreshAccum = FBFullRefreshAccum + FBPREDICT_THROTTLE;
        if (FBFullRefreshAccum >= 1.0) then
            FBFullRefreshAccum = 0;
            full = true;
        end
    end

    if (full) then
        FBHealBox_RefreshAllBars();
    elseif (dirty) then
        FBHealBox_RefreshUnitsByName(names);
    end
end

FBPredict_InitPatterns();

-- ==========================================================================
-- [ HealComm-Protokoll ]  Interop mit Puppeteer, pfUI, Luna, CT_RaidAssist ...
--
-- HealComm-1.0 (Ace2) funkt reinen Klartext ueber SendAddonMessage mit dem
-- Prefix "HealComm". Wir sprechen dieselbe Sprache, ohne die Bibliothek
-- einzubinden:
--
--   Heal/<Ziel>/<Betrag>/<Castzeit ms>/     Direktheilung startet
--   Healstop                                Cast abgebrochen
--   Healdelay/<ms>/                         Pushback
--   GrpHeal/<Betrag>/<ms>/<Z1>/<Z2>/...     Gruppenheilung (Prayer of Healing)
--   GrpHealstop  /  GrpHealdelay/<ms>/
--   Renew|Reju|Regr/<Ziel>/<Dauer sec>/     HoT angewendet
--
-- Empfaenger ignorieren die eigenen Nachrichten (Absender == man selbst),
-- und HealComm legt eingehende Heilungen pro Caster ab. Doppelt gesendete
-- Nachrichten (z.B. wenn parallel noch ein echtes HealComm laeuft)
-- ueberschreiben denselben Eintrag statt sich zu addieren.
--
-- Die Betraege sind unsere selbstkorrigierten Werte aus dem Combatlog,
-- also inkl. +Heilung und Talenten. Kein ItemBonusLib noetig.
-- ==========================================================================

FBCOMM_PREFIX   = "HealComm";
FBCommHeals     = {};      -- [Ziel] = { [Caster] = { amount, expires } }
FBCommSentGroup = false;   -- war der zuletzt gesendete Cast ein Gruppenheal?

FBCommHoTCode = {
    ["Renew"]        = "Renew",
    ["Rejuvenation"] = "Reju",
    ["Regrowth"]     = "Regr",
};

FBCommGroupHeal = {
    ["Prayer of Healing"] = 1,
};

function FBComm_Enabled()
    return (HealBox and HealBox.HealComm and HealBox.HealComm ~= 0);
end

function FBComm_Send(msg)
    if (not FBComm_Enabled()) then return; end

    local n = GetNumRaidMembers();
    if (n and n > 0) then
        SendAddonMessage(FBCOMM_PREFIX, msg, "RAID");
    else
        n = GetNumPartyMembers();
        if (n and n > 0) then
            SendAddonMessage(FBCOMM_PREFIX, msg, "PARTY");
        else
            return;  -- allein: niemand da, der zuhoert
        end
    end

    if (FBPredictDebug) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF88CCFF[FBP>]|r "..msg);
    end
end

-- [ Senden ] ---------------------------------------------------------------

function FBComm_SendHealStart(spellName, target, amount, castMs)
    if (not FBComm_Enabled()) or (not target) then return; end

    amount = math.floor(amount or 0);
    castMs = math.floor(castMs or 0);
    if (amount <= 0) then return; end

    if (FBCommGroupHeal[spellName]) then
        -- Gruppenheilung: alle Ziele in Reichweite mitschicken
        local names = UnitName("player").."/";
        for i = 1, 4 do
            local u = "party"..i;
            if (UnitExists(u) and CheckInteractDistance(u, 4)) then
                names = names..UnitName(u).."/";
            end
        end
        FBCommSentGroup = true;
        FBComm_Send("GrpHeal/"..amount.."/"..castMs.."/"..names);
    else
        FBCommSentGroup = false;
        FBComm_Send("Heal/"..target.."/"..amount.."/"..castMs.."/");
    end
end

function FBComm_SendHealStop()
    if (FBCommSentGroup) then
        FBComm_Send("GrpHealstop");
    else
        FBComm_Send("Healstop");
    end
end

function FBComm_SendHealDelay(ms)
    ms = tonumber(ms);
    if (not ms) then return; end
    if (FBCommSentGroup) then
        FBComm_Send("GrpHealdelay/"..math.floor(ms).."/");
    else
        FBComm_Send("Healdelay/"..math.floor(ms).."/");
    end
end

function FBComm_SendHoT(spellName, target, duration)
    local code = FBCommHoTCode[spellName];
    if (not code) or (not target) or (not duration) then return; end
    if (duration < 1) then return; end
    FBComm_Send(code.."/"..target.."/"..math.floor(duration).."/");
end

-- [ Empfangen ] ------------------------------------------------------------

function FBComm_Split(str)
    local t = {};
    for w in string.gfind(str, "([^/]+)") do
        table.insert(t, w);
    end
    return t;
end

-- Ein Caster hat immer nur einen Heilzauber unterwegs
function FBComm_ClearCaster(caster)
    for _, casters in pairs(FBCommHeals) do
        if (casters[caster]) then casters[caster] = nil; end
    end
end

function FBComm_DelayCaster(caster, ms)
    local add = (tonumber(ms) or 0) / 1000;
    for _, casters in pairs(FBCommHeals) do
        if (casters[caster]) then
            casters[caster].expires = casters[caster].expires + add;
        end
    end
end

function FBComm_OnMessage(prefix, msg, channel, sender)
    if (prefix ~= FBCOMM_PREFIX) or (not msg) or (not sender) then return; end
    if (sender == UnitName("player")) then return; end   -- eigene Nachrichten ignorieren
    if (not FBComm_Enabled()) then return; end

    local p     = FBComm_Split(msg);
    local cmd   = p[1];
    local now   = GetTime();
    local dirty = false;

    if (cmd == "Heal" and p[2] and p[3] and p[4]) then
        FBComm_ClearCaster(sender);
        if (not FBCommHeals[p[2]]) then FBCommHeals[p[2]] = {}; end
        FBCommHeals[p[2]][sender] = {
            amount  = tonumber(p[3]) or 0,
            expires = now + ((tonumber(p[4]) or 0) / 1000),
        };
        dirty = true;

    elseif (cmd == "GrpHeal" and p[2] and p[3]) then
        FBComm_ClearCaster(sender);
        local amount  = tonumber(p[2]) or 0;
        local expires = now + ((tonumber(p[3]) or 0) / 1000);
        local i = 4;
        while (p[i]) do
            if (not FBCommHeals[p[i]]) then FBCommHeals[p[i]] = {}; end
            FBCommHeals[p[i]][sender] = { amount = amount, expires = expires };
            i = i + 1;
        end
        dirty = true;

    elseif (cmd == "Healstop" or cmd == "GrpHealstop") then
        FBComm_ClearCaster(sender);
        dirty = true;

    elseif ((cmd == "Healdelay" or cmd == "GrpHealdelay") and p[2]) then
        FBComm_DelayCaster(sender, p[2]);
        dirty = true;
    end
    -- HoT-Nachrichten (Renew/Reju/Regr) tragen nur Laufzeiten, keine
    -- Betraege. HealComm selbst zaehlt sie ebenfalls nicht zur
    -- eingehenden Heilung. Wir ignorieren sie deshalb hier.

    if (dirty) then FBHealBox_RefreshAllBars(); end
end

-- Eingehende Heilung anderer Heiler auf diese Einheit
function FBGetCommHeal(unitName)
    if (not unitName) then return 0; end
    local casters = FBCommHeals[unitName];
    if (not casters) then return 0; end

    local now = GetTime();
    local sum = 0;
    for _, info in pairs(casters) do
        if (info.expires > now) then sum = sum + info.amount; end
    end
    return sum;
end

-- [ Debug-Kommando ] -------------------------------------------------------

SLASH_FBHEALPREDICT1 = "/fbp";
SlashCmdList["FBHEALPREDICT"] = function(msg)
    -- Anzeige bei Krieger/Schurke/Jaeger dauerhaft ein- oder ausschalten.
    -- Steht vor allem anderen, damit der Befehl auch im Ruhezustand geht.
    if (msg == "forceload") then
        if (not FBClassBlocked) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("CLASS_FORCE_NA"));
            return;
        end
        if (HealBox.ForceLoad == 1) then
            HealBox.ForceLoad = 0;
            -- Die Sperrmeldung kam beim Einloggen schon, hier reicht die
            -- Rueckmeldung des Befehls
            FBGateAnnounced = true;
            FBHealBox_ApplyClassGate();
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("CLASS_FORCE_OFF"));
        else
            HealBox.ForceLoad = 1;
            FBGateAnnounced = false;
            FBHealBox_ApplyClassGate();
            FBHealBox_StartUp();
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("CLASS_FORCE_ON"));
        end
        return;
    end

    -- Im Ruhezustand bleibt es beim Hinweis: nichts ist aufgebaut,
    -- Optionsfenster und Diagnose waeren leer.
    if (FBAddonSuppressed) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "
            ..format(FBT("CLASS_BLOCKED"), FBClass or "?"));
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAA"..FBT("CLASS_BLOCKED_HINT").."|r");
        return;
    end

    -- Module zuerst (z. B. /fbp raid)
    if (FBHealBox_RunHook("Slash", msg)) then return; end

    if (msg == "debug") then
        FBPredictDebug = not FBPredictDebug;
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..FBT("FBP_DEBUG").." "..tostring(FBPredictDebug));
        return;
    end

    if (msg == "reset") then
        if (HealBox) then HealBox.PredictMemory = {}; end
        FBPredictInfo = {};
        FBPredict_BuildWatch();
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..FBT("FBP_RESET"));
        return;
    end

    if (msg == "test") then
        FBTest_Set(not FBTestMode);
        return;
    end

    -- Ausruestungsbonus in der Vorhersage an/aus
    if (msg == "healbonus" or msg == "bonus") then
        if (not FBAPI_Probed) then FBHealBox_ProbeAPIs(); end
        if (not FBAPI_HealBonusFn) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("HEALBONUS_NA"));
            return;
        end
        if (HealBox.HealBonus == 1) then HealBox.HealBonus = 0; else HealBox.HealBonus = 1; end
        local key = "HEALBONUS_OFF";
        if (HealBox.HealBonus == 1) then key = "HEALBONUS_ON"; end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "
            ..format(FBT(key), math.floor(FBHealBox_HealingBonus() + 0.5)));
        return;
    end

    -- Abrangen ueber Zaubergrenzen (Heilketten) an/aus
    if (msg == "smartcross" or msg == "cross") then
        if (HealBox.SmartCross == 1) then HealBox.SmartCross = 0; else HealBox.SmartCross = 1; end
        local key = "SMART_CROSS_OFF";
        if (HealBox.SmartCross == 1) then key = "SMART_CROSS_ON"; end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT(key));
        if (HealBox.SmartRank ~= 1) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAAA"..FBT("SMART_CROSS_NEEDS").."|r");
        end
        if (SmartCrossCheck) then SmartCrossCheck:SetChecked(HealBox.SmartCross == 1); end
        return;
    end

    if (msg == "config" or msg == "options" or msg == "opt") then
        FBHealBox_ToggleOptions();
        return;
    end

    if (msg == "buffs") then
        -- Diagnose: ueberwachte Buffs und ihr Zustand auf dem Spieler
        local me = UnitName("player");
        local any = false;
        for spellName, w in pairs(FBPredictWatch) do
            if (w.hasBuff) then
                any = true;
                local present = FBBuffPresent[me] and FBBuffPresent[me][spellName];
                local bt = FBBuffTimers[me] and FBBuffTimers[me][spellName];
                local left = "-";
                if (bt) then left = math.floor(bt.expires - GetTime()).."s"; end
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r buff "..spellName.." ("..(w.buffSecs or 0).."s) tex="..tostring(w.tex)
                    .." present="..tostring(present ~= nil and present or false).." left="..left);
            end
        end
        if (not any) then DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r no buff spells on the buttons (assign e.g. Power Word: Fortitude)"); end
        if (FBHealBox1 and FBHealBox1.buffIcons) then
            for k, ic in ipairs(FBHealBox1.buffIcons) do
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r icon "..k..": shown="..tostring(ic:IsShown() and true or false)
                    .." name="..tostring(ic.buffName).." left="..tostring(ic.buffLeft and math.floor(ic.buffLeft))
                    .." grey="..tostring(ic.greyCount).." q1shown="..tostring(ic.qTex and ic.qTex:IsShown() and true or false)
                    .." desat="..tostring(ic.qTex and ic.qTex.fbDesat));
            end
        end
        local i = 1;
        while (i <= 32) do
            local tex = UnitBuff("player", i);
            if (not tex) then break; end
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r player buff "..i..": "..tex);
            i = i + 1;
        end
        return;
    end

    if (not FBAPI_Probed) then FBHealBox_ProbeAPIs(); end
    if (FBAPI_HealBonusFn) then
        local state = FBT("FBP_STATE_OFF");
        if (HealBox.HealBonus == 1) then state = FBT("FBP_STATE_ON"); end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..format(FBT("FBP_HEALBONUS"),
            math.floor(FBHealBox_HealingBonus() + 0.5), state));
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..FBT("FBP_WATCHED"));
    for spellName, w in pairs(FBPredictWatch) do
        local info = FBPredict_GetSpellInfo(w.bookID, spellName);
        if (info) then
            local parts = "";
            if (info.direct) then
                local learned = FBPredict_Remembered("direct", spellName, w.rank);
                parts = parts.." "..FBT("FBP_DIRECT").."="..math.floor(info.direct);
                if (learned) then
                    parts = parts.."("..FBT("FBP_LEARNED").." "..math.floor(learned)..")";
                end
            end
            if (info.hot) then
                parts = parts.." HoT="..math.floor(info.hot.perTick).."x"..info.hot.ticks
                        .." "..FBT("FBP_EVERY").." "..info.hot.interval.."s";
            end
            if (info.shield) then
                parts = parts.." "..FBT("FBP_SHIELD").."="..info.shield.amount
                        .."/"..info.shield.duration.."s";
            end
            DEFAULT_CHAT_FRAME:AddMessage("   "..spellName.." ("..tostring(w.rank)..")"..parts);
        end
    end

    local now = GetTime();
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..FBT("FBP_ACTIVE"));
    if (FBPredictDirect) then
        DEFAULT_CHAT_FRAME:AddMessage("   "..FBT("FBP_CAST").." "..FBPredictDirect.spell
            .." "..FBT("FBP_ON").." "..FBPredictDirect.target..": "
            ..math.floor(FBPredictDirect.amount));
    end
    for name, spells in pairs(FBHoTs) do
        for spellName, e in pairs(spells) do
            DEFAULT_CHAT_FRAME:AddMessage("   HoT "..name.." / "..spellName..": "
                ..FBPredict_TicksLeft(e, now).." "..FBT("FBP_TICKSOF").." "
                ..math.floor(e.perTick));
        end
    end
    for name, s in pairs(FBShields) do
        DEFAULT_CHAT_FRAME:AddMessage("   "..FBT("FBP_SHIELD").." "..name.." / "..s.spell
            ..": "..math.floor(s.max - s.absorbed).." "..FBT("FBP_OF").." "
            ..math.floor(s.max));
    end

    if (FBLOS_HasUnitXP()) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r LoS: UnitXP");
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r LoS: UI_ERROR_MESSAGE ("..FBLOS_TIMEOUT.."s)");
    end
    local rangeApi = "CheckInteractDistance (28m)";
    if (FBAPI_SpellRange) then rangeApi = "IsSpellInRange ("..tostring(FBAPI_RangeForm).." args)"; elseif (UnitXP) then rangeApi = "UnitXP distance + tooltip"; end
    local usableApi = "tooltip mana cost";
    if (FBAPI_UsableSpell) then usableApi = "IsUsableSpell ("..tostring(FBAPI_UsableForm).." args)"; end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r Range: "..rangeApi..", usable: "..usableApi);

    local state = FBT("FBP_STATE_OFF");
    if (FBComm_Enabled()) then state = FBT("FBP_STATE_ON"); end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..FBT("FBP_SYNC").." "..state);
    for target, casters in pairs(FBCommHeals) do
        for caster, info in pairs(casters) do
            if (info.expires > now) then
                DEFAULT_CHAT_FRAME:AddMessage("   "..FBT("FBP_INCOMING").." "..caster
                    .." -> "..target..": "..math.floor(info.amount));
            end
        end
    end
    local smart = FBT("FBP_STATE_OFF");
    if (HealBox.SmartRank == 1) then smart = FBT("FBP_STATE_ON"); end
    local cross = FBT("FBP_STATE_OFF");
    if (HealBox.SmartCross == 1) then cross = FBT("FBP_STATE_ON"); end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..format(FBT("FBP_SMART"), smart, HealBox.SmartMargin or 20)
        .." "..format(FBT("FBP_SMART_CROSS"), cross));
    FBHealBox_RunHook("Status");
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..FBT("FBP_COMMANDS"));
end

-- Dispel-Farben je Klasse (einmal gebaut, nicht pro Update)
FBDispelColors = {};
if (FBClass == "Priest") then
    FBDispelColors["Magic"]   = {0.2, 0.6, 1, 1};
    FBDispelColors["Disease"] = {0.6, 0.4, 0, 1};
elseif (FBClass == "Paladin") then
    FBDispelColors["Magic"]   = {0.2, 0.6, 1, 1};
    FBDispelColors["Poison"]  = {0, 0.6, 0, 1};
    FBDispelColors["Disease"] = {0.6, 0.4, 0, 1};
elseif (FBClass == "Shaman") then
    FBDispelColors["Poison"]  = {0, 0.6, 0, 1};
    FBDispelColors["Disease"] = {0.6, 0.4, 0, 1};
elseif (FBClass == "Druid") then
    FBDispelColors["Curse"]   = {0.6, 0, 1, 1};
    FBDispelColors["Poison"]  = {0, 0.6, 0, 1};
end

FBDISPEL_ORDER = { "Magic", "Poison", "Disease", "Curse" };

-- Erster von der eigenen Klasse entfernbarer Debuff: Typ, Textur, Stacks (sonst nil)
function FBHealBox_DispelType(unit)
    local g = FBTest_Ghost(unit);
    if (g) then
        -- Geist mit festem Debuff-Typ (nur, wenn die eigene Klasse ihn entfernt)
        if (g.debuffType) then
            if (FBDispelColors[g.debuffType]) then return g.debuffType, g.debuffTex, g.debuffCount; end
            return nil;
        end
        -- Geist mit Debuff: irgendein Typ, den die eigene Klasse entfernen kann
        if (g.debuff) then
            for _, dtype in ipairs(FBDISPEL_ORDER) do
                if (FBDispelColors[dtype]) then return dtype, g.debuffTex, g.debuffCount; end
            end
        end
        return nil;
    end
    for i = 1, 16 do
        local texture, count, debuffType = UnitDebuff(unit, i);
        if (not texture) then break; end
        if (debuffType and FBDispelColors[debuffType]) then return debuffType, texture, count; end
    end
    return nil;
end

-- Debuff-Icon samt Stackzahl setzen oder verstecken
function FBHealBox_UpdateDebuffIcon(frame, texture, count)
    if (not frame.DebuffIcon) then return; end
    if (texture and HealBox.DebuffIcon == 1 and not frame.plateHidden) then
        frame.debuffShown = true;
        FBHealBox_ApplyNameWidth(frame);
        frame.DebuffIcon:SetTexture(texture);
        frame.DebuffIcon:Show();
        if (count and tonumber(count) and tonumber(count) > 1) then
            frame.DebuffCount:SetText(tostring(count));
            frame.DebuffCount:Show();
        else
            frame.DebuffCount:Hide();
        end
    else
        frame.debuffShown = false;
        FBHealBox_ApplyNameWidth(frame);
        frame.DebuffIcon:Hide();
        frame.DebuffCount:Hide();
    end
end

-- Namensbreite: Grundbreite (mit/ohne Debuff-Icon) minus Platz der Buff-Icons
function FBHealBox_ApplyNameWidth(frame)
    if (not frame) or (not frame.NameText) then return; end
    local w = frame.nameWidthFull or FBNAME_WIDTH_FULL;
    if (frame.debuffShown) then w = frame.nameWidthIcon or FBNAME_WIDTH_ICON; end
    if (w < 16) then w = 16; end
    frame.NameText:SetWidth(w);
end

-- ==========================================================================
-- [ Buff-Icons mit Uhr im Lebensbalken ]
--
-- Buffs mit Laufzeit von den Buttons (Seelenstaerke, Willen, ...), die auf
-- der Einheit liegen, als kleine Icons links vom Prozenttext. Restzeit
-- bekannt (eigener Cast, eigene Buffs): Cooldown-Uhr laeuft; unbekannt
-- (fremder Cast): Icon ohne Uhr. Der Name macht Platz.
-- ==========================================================================

FBBUFFICON_STEPS = 32;

-- Icon Nr. k anlegen, aussen links neben der Plakette, in Zweierstapeln:
-- Icon 1 oben an der Kante, Icon 2 darunter, Icon 3 oben in der naechsten
-- Spalte links usw. Farbiges Icon plus vier schwarz-weisse Quadranten.
function FBHealBox_GetBuffIcon(frame, k, size, rows)
    if (not frame.buffIcons) then frame.buffIcons = {}; end
    if (frame.buffIcons[k]) then return frame.buffIcons[k]; end
    size = size or FBBUFFICON_SIZE;
    rows = rows or FBBUFFICON_ROWS;
    local ic = CreateFrame("Frame", nil, frame);
    ic:SetWidth(size);
    ic:SetHeight(size);
    local col  = math.floor((k - 1) / rows);
    local row  = math.mod(k - 1, rows);
    local stackH = rows * size + (rows - 1) * FBBUFFICON_GAP;
    local x = FBBUFFICON_XOFF - col * (size + FBBUFFICON_GAP);
    local y = stackH / 2 - row * (size + FBBUFFICON_GAP);   -- Oberkante der Zeile relativ zur Mitte
    ic:SetPoint("TOPRIGHT", frame, "LEFT", x, y);
    if (ic.SetFrameLevel and frame.GetFrameLevel) then ic:SetFrameLevel((frame:GetFrameLevel() or 0) + 5); end
    ic.tex = ic:CreateTexture(nil, "ARTWORK");
    ic.tex:SetAllPoints(ic);
    ic.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93);
    -- Die grauen Quadranten liegen auf einem eigenen Kind-Frame eine Ebene
    -- ueber dem Icon: Frame-Ebenen zeichnet der 1.12-Client verlaesslich in
    -- Reihenfolge, Textur-Layer innerhalb eines Frames nicht in jedem Fall.
    ic.grey = CreateFrame("Frame", nil, ic);
    ic.grey:SetAllPoints(ic);
    if (ic.grey.SetFrameLevel and frame.GetFrameLevel) then ic.grey:SetFrameLevel((ic:GetFrameLevel() or 0) + 1); end

    -- Schwarz-weißes Icon-Overlay (wächst von oben nach unten)
    ic.qTex = ic.grey:CreateTexture(nil, "ARTWORK");
    ic.qTex:SetPoint("TOPLEFT", ic, "TOPLEFT", 0, 0);
    ic.qTex:SetPoint("TOPRIGHT", ic, "TOPRIGHT", 0, 0);
    ic.qTex:SetHeight(0);
    ic.qTex:Hide();

    -- Dunkle Schattierung über dem abgelaufenen Bereich
    ic.wTex = ic.grey:CreateTexture(nil, "OVERLAY");
    ic.wTex:SetPoint("TOPLEFT", ic, "TOPLEFT", 0, 0);
    ic.wTex:SetPoint("TOPRIGHT", ic, "TOPRIGHT", 0, 0);
    ic.wTex:SetTexture(FBBUFFICON_WASH[1], FBBUFFICON_WASH[2], FBBUFFICON_WASH[3], FBBUFFICON_WASH[4]);
    ic.wTex:SetHeight(0);
    ic.wTex:Hide();

    -- Tooltip: Buffname und Restzeit (auch zur Diagnose)
    ic:EnableMouse(true);
    ic:SetScript("OnEnter", function()
        if (not this.buffName) then return; end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
        GameTooltip:SetText(this.buffName);
        local left = this.buffLeft;
        if (left) then
            GameTooltip:AddLine(FBHealBox_FormatTimer(left), 1, 1, 1);
        else
            GameTooltip:AddLine(FBT("TT_BUFF_UNKNOWN"), 0.7, 0.7, 0.7);
        end
        GameTooltip:Show();
    end);
    ic:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    ic:Hide();
    frame.buffIcons[k] = ic;
    return ic;
end

-- Quadrant schwarz-weiss machen: Entsaettigung (wenn der Client sie kann),
-- sonst Grauton. Muss nach jedem SetTexture erneut gesetzt werden.
function FBHealBox_GreyTexture(t)
    local desat = nil;
    if (t.SetDesaturated) then desat = t:SetDesaturated(1); end
    t.fbDesat = desat;
    if (desat) then
        t:SetVertexColor(0.55, 0.55, 0.55, 1);
    else
        t:SetVertexColor(FBBUFFICON_GREY, FBBUFFICON_GREY, FBBUFFICON_GREY, 1);
    end
end

function FBHealBox_SetBuffIconProgress(ic, remaining)
    local grey = 0;
    if (remaining) then
        if (remaining < 0) then remaining = 0; end
        if (remaining > 1) then remaining = 1; end
        grey = math.floor((1 - remaining) * FBBUFFICON_STEPS + 0.5);
        if (grey > FBBUFFICON_STEPS) then grey = FBBUFFICON_STEPS; end
    end

    if (ic.greyCount == grey) then return; end
    ic.greyCount = grey;

    if (grey == 0) then
        if (ic.qTex) then ic.qTex:Hide(); end
        if (ic.wTex) then ic.wTex:Hide(); end
    else
        local size = ic:GetHeight() or FBBUFFICON_SIZE;
        local frac = grey / FBBUFFICON_STEPS;
        local h = size * frac;

        if (ic.qTex) then
            ic.qTex:SetHeight(h);
            -- Standard-Icon-Beschnitt (0.07 bis 0.93) anteilig anpassen:
            local vBottom = 0.07 + (0.93 - 0.07) * frac;
            ic.qTex:SetTexCoord(0.07, 0.93, 0.07, vBottom);
            ic.qTex:Show();
        end
        if (ic.wTex) then
            ic.wTex:SetHeight(h);
            ic.wTex:Show();
        end
    end
end

-- Zu zeigende Buffs einer Einheit in die Arbeits-Tabelle out schreiben
-- (wiederverwendet, keine neuen Tabellen je Tick). Liefert die Anzahl.
-- Reihenfolge: FBPredictWatchBuffOrder (einmal in BuildWatch sortiert).
function FBHealBox_BuffIconList(unitName, g, out)
    local n = 0;
    if (g) then
        if (not g.buffs) then return 0; end
        for _, b in ipairs(g.buffs) do
            n = n + 1;
            local e = out[n] or {}; out[n] = e;
            e.tex = b.tex; e.expires = b.left and (GetTime() + b.left); e.duration = b.dur; e.name = "Test";
        end
        return n;
    end
    if (not unitName) then return 0; end
    local present = FBBuffPresent[unitName];
    if (not present) then return 0; end
    local timers = FBBuffTimers[unitName];
    for _, spellName in ipairs(FBPredictWatchBuffOrder) do
        if (present[spellName]) then
            local w = FBPredictWatch[spellName];
            local bt = timers and timers[spellName];
            n = n + 1;
            local e = out[n] or {}; out[n] = e;
            e.tex = w.icon; e.expires = bt and bt.expires; e.duration = w.buffSecs; e.name = spellName;
        end
    end
    return n;
end

-- Icons einer Plakette (oder Raid-Zelle) nachfuehren. Liefert die Anzahl.
-- size, rows, maxIcons: Icongroesse, Stapelhoehe und Hoechstzahl (Plaketten:
-- 8 px, 2 hoch, 6; Raid-Zellen: 6 px, 3 hoch, 12).
function FBHealBox_UpdateBuffIcons(frame, unitName, g, size, rows, maxIcons)
    if (not frame) or (not frame.HPText) then return 0; end
    maxIcons = maxIcons or FBBUFFICON_MAX;
    if (not frame.buffList) then frame.buffList = {}; end
    local list = frame.buffList;
    local count = 0;
    if (HealBox.BuffIcons == 1 and not frame.plateHidden) then
        count = FBHealBox_BuffIconList(unitName, g, list);
    end
    -- nichts zu tun, wenn weder etwas angezeigt wird noch angezeigt war
    if (count == 0 and (frame.buffIconCount or 0) == 0) then return 0; end
    local now = GetTime();
    local n = 0;
    for k = 1, maxIcons do
        local b = nil;
        if (k <= count) then b = list[k]; end
        local ic = (frame.buffIcons and frame.buffIcons[k]) or (b and FBHealBox_GetBuffIcon(frame, k, size, rows));
        if (ic) then
            if (b and b.tex) then
                n = n + 1;
                if (ic.lastTex ~= b.tex) then
                    ic.lastTex = b.tex;
                    ic.tex:SetTexture(b.tex);
                    if (ic.qTex) then
                        ic.qTex:SetTexture(b.tex);
                        FBHealBox_GreyTexture(ic.qTex);
                    end
                    ic.greyCount = nil;
                end

                local remaining = nil;
                ic.buffName = b.name;
                ic.buffLeft = nil;
                if (b.expires and b.duration and b.duration > 0) then
                    remaining = (b.expires - now) / b.duration;
                    ic.buffLeft = b.expires - now;
                end
                FBHealBox_SetBuffIconProgress(ic, remaining);
                ic:Show();
            else
                ic:Hide();
                ic.lastTex = nil;
                ic.greyCount = nil;
            end
        end
    end
    frame.buffIconCount = n;
    return n;
end

-- Eigene Buffs regelmaessig neu aus der Buff-API lesen: Ein Neucast auf
-- einen noch laufenden Buff (Refresh) loest im 1.12-Client kein Aura-Event
-- aus, die Restzeit springt aber trotzdem auf voll.
FBBuffRefreshAccum = 0;
function FBPredict_RefreshPlayerBuffs(elapsed)
    FBBuffRefreshAccum = FBBuffRefreshAccum + (elapsed or 0);
    if (FBBuffRefreshAccum < 1.0) then return; end
    FBBuffRefreshAccum = 0;
    local me = UnitName("player");
    if (not me) or (not FBBuffPresent[me]) then return; end
    local timers = FBBuffTimers[me];
    for _, spellName in ipairs(FBPredictWatchBuffOrder) do
        if (FBBuffPresent[me][spellName]) then
            local w = FBPredictWatch[spellName];
            local left = FBPredict_PlayerBuffTimeLeft(w.tex);
            if (left) then
                -- nur uebernehmen, wenn die API mehr als eine Sekunde von der
                -- eigenen Uhr abweicht (Refresh); sonst kein Dirty-Flag
                local t = timers and timers[spellName];
                if (not t) or (math.abs((t.expires - GetTime()) - left) > 1.0) then
                    FBPredict_StartBuff(me, spellName, left);
                end
            end
        end
    end
end

function FBHealBox_UpdateAllBuffIcons()
    for p = 1, FBSlotCount do
        local f = FBPartyFrame[p];
        local unit = FBPartyUnit[p];
        if (f) then
            if (f:IsShown() and FBUnitExists(unit)) then
                FBHealBox_UpdateBuffIcons(f, FBUnitName(unit), FBTest_Ghost(unit), FBBUFFICON_SIZE);
            else
                FBHealBox_UpdateBuffIcons(f, nil, nil, FBBUFFICON_SIZE);
            end
        end
    end
    FBHealBox_RunHook("BuffIcons");
end

-- Balkenfarbe der Energieart anpassen. Der Zwischenspeicher am Rahmen
-- verhindert, dass die Farbe bei jedem Durchlauf neu gesetzt wird.
function FBHealBox_SetPowerColor(bar, cache, ptype)
    if (not bar) then return; end
    local t = ptype or 0;
    if (cache) and (cache.powerType == t) then return; end
    if (cache) then cache.powerType = t; end
    local c = FBPOWER_COLORS[t] or FBMANA_BAR_COLOR;
    bar:SetStatusBarColor(c[1], c[2], c[3], c[4]);
end

-- Manabalken: nur wenn eingeschaltet, die Plakette sichtbar ist und die
-- Einheit tatsaechlich Mana nutzt. Sonst weg, dann ist der Lebensbalken
-- wieder auf voller Hoehe zu sehen.
function FBHealBox_UpdateMana(unit, frame)
    if (not frame.ManaBar) then return; end
    local mp, mpMax, hasMana, ptype = 0, 0, false, nil;
    if (HealBox.ManaBar == 1) and (not frame.plateHidden) then
        mp, mpMax, hasMana, ptype = FBUnitMana(unit);
    end
    if (not hasMana) then
        if (frame.manaShown ~= false) then frame.manaShown = false; frame.ManaBar:Hide(); end
        return;
    end
    FBHealBox_SetPowerColor(frame.ManaBar, frame, ptype);
    if (frame.lastMpMax ~= mpMax) then
        frame.lastMpMax = mpMax;
        frame.ManaBar:SetMinMaxValues(0, mpMax);
    end
    if (frame.vMp ~= mp) then frame.vMp = mp; frame.ManaBar:SetValue(mp); end
    if (frame.manaShown ~= true) then frame.manaShown = true; frame.ManaBar:Show(); end
end

-- Anzeige-Zwischenspeicher aller Plaketten leeren (nach Optionswechsel)
function FBHealBox_InvalidateUnitCaches()
    for p = 1, FBSlotCount do
        local f = FBPartyFrame[p];
        if (f) then f.dispelKnown = nil; f.lastText = nil; f.lastMax = nil; f.colorKey = nil; f.manaShown = nil; f.lastMpMax = nil; f.powerType = nil; f.vHp = nil; f.vShield = nil; f.vInc = nil; f.vMp = nil; end
    end
end

-- Balkenfarbe nur setzen, wenn sie sich aendert (Schluessel merken)
function FBHealBox_SetBarColor(frame, key, r, g, b, a)
    if (frame.colorKey == key) then return; end
    frame.colorKey = key;
    frame.HealthBar:SetStatusBarColor(r, g, b, a);
end

-- Werte der drei Balken nur setzen, wenn sie sich geaendert haben
function FBHealBox_SetBarValues(frame, hp, shieldTop, incTop)
    if (frame.vHp ~= hp) then frame.vHp = hp; frame.HealthBar:SetValue(hp); end
    if (frame.vShield ~= shieldTop) then frame.vShield = shieldTop; frame.ShieldBar:SetValue(shieldTop); end
    if (frame.vInc ~= incTop) then frame.vInc = incTop; frame.IncHealBar:SetValue(incTop); end
end

-- Maximalwerte der drei Balken nur bei geaendertem hpMax setzen
function FBHealBox_SetBarMax(frame, hpMax)
    if (frame.lastMax == hpMax) then return; end
    frame.lastMax = hpMax;
    frame.HealthBar:SetMinMaxValues(0, hpMax);
    frame.ShieldBar:SetMinMaxValues(0, hpMax);
    frame.IncHealBar:SetMinMaxValues(0, hpMax);
end

-- auraChanged: true bei UNIT_AURA. Nur dann wird der Debuff neu gesucht
-- (UnitDebuff-Scan); UNIT_HEALTH und der Vorhersage-Tick nutzen den Cache.
function FBHealBox_UpdateUnit(unit, frame, auraChanged) 
    if (not frame) or (not frame.HealthBar) then return; end 
    if (not FBUnitExists(unit)) then return; end 
    
    local hp, hpMax = FBUnitHealth(unit); 
    local hpPercent = hp / hpMax; 
    local state = FBUnitState(unit); 
    
    -- Tot / Geist / Offline: Text statt Prozent, Balken leer, grau, kein Mana
    if (state) then 
        local label = "STATE_DEAD"; 
        if (state == "ghost") then label = "STATE_GHOST"; end 
        if (state == "offline") then label = "STATE_OFFLINE"; end 
        if (frame.lastText ~= label) then 
            frame.lastText = label; 
            frame.HPText:SetText(FBT(label)); 
        end 
        FBHealBox_SetBarMax(frame, hpMax); 
        FBHealBox_SetBarValues(frame, 0, 0, 0); 
        FBHealBox_SetBarColor(frame, "state", 0.5, 0.5, 0.5, 1); 
        if (frame.manaShown ~= false) then frame.manaShown = false; frame.ManaBar:Hide(); end 
        FBHealBox_UpdateDebuffIcon(frame, nil, nil); 
        return; 
    end 
    
    local pct = math.floor(hpPercent * 100); 
    if (frame.lastText ~= pct) then 
        frame.lastText = pct; 
        frame.HPText:SetText(pct.."%"); 
    end 
    FBHealBox_SetBarMax(frame, hpMax); 
    
    local name = FBUnitName(unit);
    local g    = FBTest_Ghost(unit);

    -- Eigener Direktcast + eigene HoT-Restticks + Heilung anderer Heiler
    local incHeal, shield;
    if (g) then
        incHeal = g.inc or 0;
        shield  = g.shield or 0;
    else
        incHeal = FBGetDirectHeal(name) + FBGetHoTHeal(name) + FBGetCommHeal(name);
        shield  = FBGetShield(name);
    end

    -- Absorb-Schild als Pseudoleben direkt hinter den aktuellen HP,
    -- Heilvorhersage dahinter; Werte nur setzen, wenn sie sich aendern
    local shieldTop = hp + shield;
    if (shieldTop > hpMax) then shieldTop = hpMax; end
    local incTop = shieldTop + incHeal;
    if (incTop > hpMax) then incTop = hpMax; end
    FBHealBox_SetBarValues(frame, hp, shieldTop, incTop);

    -- Manabalken (Balken im Balken)
    FBHealBox_UpdateMana(unit, frame);
    
    -- Farbe: entfernbarer Debuff schlaegt den HP-Stand; dazu Icon + Stacks.
    -- Debuffs aendern sich nur mit UNIT_AURA, sonst gilt der letzte Befund.
    if (auraChanged or (not frame.dispelKnown) or g) then
        frame.dispelType, frame.dispelTex, frame.dispelCount = FBHealBox_DispelType(unit);
        frame.dispelKnown = true;
        FBHealBox_UpdateDebuffIcon(frame, frame.dispelTex, frame.dispelCount);
    end
    local dtype = frame.dispelType;
    if (dtype) then
        local c = FBDispelColors[dtype];
        FBHealBox_SetBarColor(frame, dtype, c[1], c[2], c[3], c[4]);
    elseif (hpPercent > LowHP) then  
        FBHealBox_SetBarColor(frame, "green", 0, 1, 0, 1); 
    elseif (hpPercent > VeryLowHP) then  
        FBHealBox_SetBarColor(frame, "yellow", 1, 0.9, 0, 1); 
    else  
        FBHealBox_SetBarColor(frame, "red", 1, 0, 0, 1); 
    end 
end 

MMButton = CreateMiniMapButton(); 
FBHealBoxSetup(); 

-- Gesperrte Klasse: alles bleibt aus, bis ADDON_LOADED / VARIABLES_LOADED
-- die gespeicherte Einstellung geprueft hat. So blitzt die Anzeige beim
-- Einloggen nicht kurz auf.
if (FBAddonSuppressed) then
    FBHealBox_HideAll();
end

FBHealBoxCreateAddonOptionFrame();