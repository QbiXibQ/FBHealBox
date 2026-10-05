# Heal Box Vanilla

ADDON DOCUMENTATION · VERSION 1.4.5.3 · World of Warcraft CLIENT 1.12.1

Party, pet and self heal display with quick-cast buttons for healers. One name plate with a health bar per group slot, plus one for every pet in the group directly below its owner, and next to it up to ten freely assignable spell buttons. A thin mana bar sits inside the health bar for everyone who actually uses mana. On top of that a complete heal prediction (direct heals, remaining HoT ticks and absorb shields) that corrects itself from the combat log and shares its numbers with other healers in the HealComm format. The interface is available in **English and German**, switchable in the options window.

**The short version:** click the minimap button (or type `/fbp config`) → options window → pick a spell for each button → done. Everything else happens on its own. `/fbp` tells you at any time what the prediction currently believes. **New in 1.4.1:** tick *Test mode* to fill the display with ghost players and arrange everything without a group.

<img width="784" height="483" alt="Screenshot 2026-09-09 080144" src="https://github.com/user-attachments/assets/e2bcef5e-b193-4ef9-88fc-1f828167fcfb" />

<img width="956" height="847" alt="Screenshot 2026-09-05 210241" src="https://github.com/user-attachments/assets/d7508232-eb56-47ef-8f7e-c39ab0c2b434" />

<img width="845" height="1105" alt="grafik" src="https://github.com/user-attachments/assets/fef5d825-0c5c-4710-8994-b51e4712ceb2" />

\---

## Installation

Download zip, unpack into your Addons folder.

The folder under `Interface\AddOns` is called **`FBHealBox`** and holds seven files:

|File|Contents|
|-|-|
|`FBHealBox.toc`|Metadata, load order, saved variables|
|`FBHealBox.lua`|The core: party and pet display, prediction, HealComm, options|
|`FBHealBox_Raid.lua`|The raid mode module (see [Raid mode](#raid-mode)). Remove it from the `.toc` and the core runs exactly as in 1.4.1|
|`FBHealBox_Ticker.lua`|The mana ticker module (see [Mana ticker](#mana-ticker)), also removable|
|`FBHealBox_Damage.lua`|The Smart Damage module (see [Smart Damage](#smart-damage)), also removable|
|`FBHealBox.xml`|Only the event frame that calls `FBHealBox_OnLoad` and `FBHealBox_OnEvent`|
|`CHANGELOG.md`|What changed in which version|

The folder name must match the name of the `.toc` file, otherwise the addon never starts. If you want to rename the folder, also change the `FBADDON_FOLDER` constant near the top of `FBHealBox.lua`, because the `ADDON_LOADED` check depends on it. The display name lives separately in `FBADDON_NAME` and can be changed freely.

**Optional: SuperWoW.** When detected, the addon prints `[SuperWoW detected]` at login and casts directly on the group member without touching your current target. Without SuperWoW it briefly switches target for the cast and restores the previous one afterwards.

**No libraries required.** No Ace, no HealComm, no RosterLib. The addon speaks the HealComm protocol directly, see [HealComm sync](#healcomm-sync).

---

## Which classes it loads for

The addon is built for healing and buffing. **Warriors, rogues and hunters** get nothing out of it: no heals, no heal prediction, and a mana ticker that either has no mana to watch (rage, energy) or nobody to heal (hunter). Logging in on one of those three classes therefore leaves everything switched off. No plates, no raid grid, no minimap button, no options window, and no event handling either, so the addon costs nothing while it sleeps. Instead two lines appear in the chat: what happened and how to change it.

**Show it anyway:** type `/fbp forceload`. The display starts immediately, no `/reload` needed, and the setting is remembered for that character (`HealBox.ForceLoad`). The same command switches it back off. On every other class `/fbp forceload` just says it is not needed.

While the addon sleeps, all other `/fbp` commands answer with the same hint, because nothing has been built that they could report on.

Detection uses the client's English class token (`WARRIOR`, `ROGUE`, `HUNTER`) and falls back to the displayed class name in five languages, so it also works on localized clients.

---

## The display

Ten name plates in two families. `FBHealBox1` is always the player, `FBHealBox2` through `FBHealBox5` are `party1` through `party4`. `FBHealBoxPet1` through `FBHealBoxPet5` are the matching pets (`pet`, `partypet1` through `partypet4`). Each shows name, health percentage and a layered bar. **To move them:** hold **Shift** and drag any plate with the left mouse button, the others are anchored to it and follow. The position is saved per character and survives a reload; changing the scale does not move the plate.

Plates are stacked in the order **owner, then that owner's pet**: you, your pet, party1, party1's pet, and so on. Slots without a unit collapse, so a group with a single hunter shows six plates, not ten. The gap between plates is the *Row spacing* option.

### Clicking a plate

A **left click** on a name or health bar targets that unit; so does a **right click**. Both are configurable on the *General* tab (*Left click on plate* / *Right click on plate*): **Target**, **Unit menu** (Blizzard's own unit menu with whisper, invite, promote, leave, for players and your own pet; group pets fall back to targeting), **Move display** (drag without holding Shift) or **Nothing**. Shift + left drag always moves the display, whatever is set. In test mode clicks on ghosts only print a note.

### Who is being attacked

If your current hostile target is targeting a group member, that member's plate (and raid cell) gets a **red border**, refreshed five times a second from `targettarget`. Red takes precedence over the orange buff-watch border. Option *Mark who is attacked*.

### Line of sight

While a unit is out of your line of sight an **eye badge** (`FBLOS_ICON`, the Blind icon) sits on the top-left corner of its plate. Vanilla has no API for this, so two paths are used: with the **UnitXP SP3** client mod installed the addon asks `UnitXP("inSight", "player", unit)` every half second, live and exact. Without it, the addon watches for the *not in line of sight* error after one of your heals and marks the unit you tried to heal for `FBLOS_TIMEOUT` (8) seconds; the mark is cleared as soon as a cast on that unit starts or one of your heals or HoT ticks lands on it. `/fbp` reports which path is active. Option *Line of sight*; badge position via `FBLOS_ICON_X/Y`.

### Pets

Every pet in the group gets its own plate with the full set of spell buttons: heal the hunter's cat or the warlock's voidwalker with one click, exactly like a player. Pet plates appear and disappear with `UNIT_PET` (summon, dismiss, death). Three things tell them apart: they are **indented** by `FBPET_INDENT` (12) px under their owner and narrower by the same amount so the buttons stay aligned, a **paw icon** (`FBPET_ICON`) sits in front of the name, and the name is **light blue**. Hunter pets run on focus and warlock pets on mana, so only the latter get a mana bar. The *Show pets* option hides the whole family.

### Bar layers

Four status bars sit exactly on top of each other, ordered by fixed frame levels (`FBHealBox_SetBarStrata`). Mana is the topmost strip, then health, opaque; the shield below it, the heal prediction at the bottom:

|Layer|Colour|Meaning|
|-|-|-|
|Mana|blue, 5 px along the bottom edge|Current mana, a bar inside the bar. Only for units whose power type is mana|
|Health|green / yellow / red, opaque|Current HP. Green above 60 %, yellow 30 to 60 %, red below|
|Shield|light blue, 50 %|Remaining absorb, directly behind the current HP|
|Prediction|light green, 50 %|Incoming healing, behind the shield segment|

Everything is clipped at the end of the bar: a shield exceeding maximum HP stays invisible and the scale stays true to the unit's health.

### Mana bar

The mana bar is `FBMANA_BAR_HEIGHT` (5) pixels high and lies on the bottom edge of the health bar. Where mana is missing a darker translucent strip shows through (`FBMANA_BG_ALPHA`, 0.35, set to 0 for none). It only appears when the unit's **power type is mana** (`UnitPowerType() == 0`): warriors, rogues, hunter pets and druids in cat or bear form get no strip, and the health bar is visible at full height. The bar follows `UNIT_MANA`, `UNIT_MAXMANA` and `UNIT_DISPLAYPOWER`. The *Mana bar* option switches it off entirely.

With *Show rage, energy, focus* ticked the strip is no longer reserved for mana: every unit gets its own resource in its usual colour, taken from `FBPOWER_COLORS` (mana blue, rage red, focus orange, energy yellow). Druids switching form change colour with `UNIT_DISPLAYPOWER` like any other power change. Off by default, because for a healer an empty strip on a warrior is information too: there is nothing there you could refill.

### Dispel colouring

If someone carries a debuff **your** class can remove, their health bar takes the debuff colour instead of the HP colour:

|Class|Types detected|
|-|-|
|Priest|Magic (blue), Disease (brown)|
|Paladin|Magic, Poison (green), Disease|
|Shaman|Poison, Disease|
|Druid|Curse (purple), Poison|

The thresholds for the HP colours are `LowHP` (0.6) and `VeryLowHP` (0.3) near the top of the file.

---

## The spell buttons

Up to ten buttons sit next to each plate, each showing its spell's icon. A **left click** casts that spell on exactly this group member, no matter who you currently have targeted.

**Assigning by drag and drop.** Open the spellbook, drag a spell and drop it on any heal button, on a raid mini button, or on a field in the *Buttons* tab; that button number takes the spell on every plate. With the right-click spell enabled, dropping with the right mouse button, or with Shift held while dropping, fills the right-click side. Spells outside the class list (Dispel Magic, say) are accepted too and keep their icon after a reload. Vanilla has no `GetCursorInfo()`, so the addon remembers what `PickupSpell` last put on the cursor.

**Right-click spell (optional).** Each button can carry a second spell for **right click** (Flash Heal left, Greater Heal right, say), which doubles the density without adding buttons. This is off by default and is enabled only through the switch on the *Buttons* tab. When on, a second column appears in the assignment and a small icon in the bottom-right corner of every button shows its right-click spell; the tooltip lists it as well. Switching it off keeps the assignments, it just stops the buttons from reacting to right click.

**Smart Healing (off by default).** With *Smart Healing* on, a click casts the lowest rank of the assigned spell whose expected heal covers the target's missing health, minus healing already on the way, plus the *Safety margin* (default 20 %). Expected heals come from the learned values of the prediction where available, otherwise from the tooltip average. It never goes above the rank you assigned, applies to direct heals only, and below 30 % health it always casts the assigned rank. **Heal over time spells are never downranked**, whatever the class: Renew, Rejuvenation, Regrowth, Tranquility, Lifebloom, Wild Growth, Riptide and Earth Shield always go out at the rank you assigned. A HoT spreads its healing over many seconds, so the health missing at the moment of the click says nothing about which rank fits, and a downranked HoT keeps ticking too weakly for its whole duration. Mixed spells such as Regrowth count as HoTs as well. Shields and buffs such as Fortitude are likewise cast as assigned, and a spell only qualifies at all if its tooltip describes a heal.

**A running HoT does not count as incoming healing.** Only what lands right away is subtracted: direct heals and spells reported over HealComm, so one to three seconds out. The healing still owed by a ticking Renew stays out of it. Counting it in full would make the deficit look tiny and turn a Heal rank 4 into a Lesser Heal, although the target needs health now and not in a quarter of a minute. The HoT is still shown on the bar, it just does not take part in the rank decision.

**Heal chains (new in 1.4.4.3).** Downranking is not limited to the assigned spell. Within a *heal chain* the spell itself may change, so a click on Greater Heal can go out as Lesser Heal rank 3 when that covers the deficit. The chains hold the single-target direct heals of one class:

|Class|Chain|
|-|-|
|Priest|Lesser Heal · Heal · Greater Heal|
|Paladin|Flash of Light · Holy Light|
|Shaman|Lesser Healing Wave · Healing Wave|
|Druid|Healing Touch (Regrowth is a HoT and stays out)|

Everything in the chain is a candidate, and the one with the smallest expected heal that still covers the need wins. Nothing that heals more than the rank you assigned is ever picked, so the button never gets stronger, only cheaper. Note that this can change the cast time: for a small deficit a Greater Heal click may become Lesser Heal, and a Holy Light click may become Flash of Light. Group heals (Prayer of Healing, Chain Heal), HoTs, shields and cooldown spells (Holy Shock, Lay on Hands) are never part of a chain.

The *Smartcross* switch on the *Buttons* tab turns chain switching off and on, `/fbp smartcross` does the same from chat. With it off, Smart Healing stays on the assigned spell and only lowers its rank, the way it worked before 1.4.4.3. The chains live in `FBHealChains` near the Smart Healing code and can be edited freely; spells you do not want swapped simply come out of the list. Downsides: the estimate ignores crits, and with burst damage or when you want to overheal on purpose (a tank before a big hit) the lower rank can fall short. Leave it off whenever overhealing is what you want. `/fbp debug` prints every decision, `/fbp` shows the state.

**Cooldowns.** Every button shows the usual cooldown sweep for its spell, the global cooldown included: after every cast you watch the short wait run out on all buttons, the way the action bars do it.

What the global cooldown must never do is darken the icons. While it runs, the client reports every spell as unusable, so taken literally all buttons would go grey for a second and a half and then snap back to bright after every single cast. That is why the two are handled by separate thresholds: `FBCD_SHOW_MIN` (0) decides from which length the sweep runs, `FBCD_MIN_DURATION` (2) the length up to which a cooldown is not treated as a reason to darken a button. Setting `FBCD_SHOW_MIN` to 2 leaves the global cooldown out of the display again. Option *Cooldowns on buttons*.

**HoT and shield timers.** The button of a spell shows, for its unit, the remaining seconds of your own HoT (green) or shield (blue) of that spell. When Power Word: Shield is used up, the same button shows Weakened Soul in red until the target can be shielded again. The left-click spell is checked first, then the right-click spell. Only your own effects are tracked. Option *HoT and shield timers*.

**Buff icons left of the bar.** Buffs with a duration that sit on your buttons (Fortitude, Divine Spirit, Fear Ward, Inner Fire, left or right click) appear as small 8 px icons on the **outer left side** of the plate while the buff is up, stacked two high: the first at the top next to the plate, the second below it, the third at the top of the next column to the left, and so on. The icon visually tracks remaining time in **32 vertical steps** (`FBBUFFICON_STEPS = 32`): as time runs out, the icon turns black and white and shades darker from top to bottom. Fresh buff: fully coloured. Half time left: top half grey. A quarter left: top three quarters grey. This 32-step vertical wipe provides much higher visual precision (e.g. updating approximately every 56 seconds for a 30-minute buff instead of every 7.5 minutes) while saving performance by using a single dynamically cropped desaturated overlay (`ic.qTex`) and dark wash (`ic.wTex`). Hovering an icon shows the buff name and the remaining time. The remaining time is exact on yourself (buff API, re-read on every `PLAYER_AURAS_CHANGED` and once a second in between, because a refresh of a running buff fires no event; a recast therefore resets the clock) and counted from your own cast on others; a buff cast by someone else stays fully coloured (time unknown). Up to six icons per plate (`FBBUFFICON_MAX`). Option *Buff icons left of the bar*, on by default. Raid cells show the same duration icons outside their left edge at 6 px in a 3 by 4 grid (twelve slots, columns filling from the cell outward), and the grid reserves the room for them between the groups. After a `/reload` or a group change the addon scans all units once, so existing buffs show up without waiting for an aura event. `/fbp buffs` lists the tracked buffs and their state on you.

**Dead, ghost, offline.** Instead of `0 %` the bar shows *Dead*, *Ghost* or *Offline*, empty and grey, with no mana strip.

**Debuff icon.** When a unit carries a debuff your class can remove, its icon appears right of the name with the stack count (from 2 up). The health bar takes the debuff colour as before.

The icon tints to show the state:

|Icon|State|
|-|-|
|Normal|Spell is castable|
|Bluish|Not enough mana|
|Dark grey|Not castable (cooldown, missing requirement)|
|Reddish|Target out of range|

Hovering shows the full spell tooltip plus the line *Heal Box Vanilla Target: `<name>`*, so it is always clear who this button serves.

---

## Raid mode

Raid mode is an addon within the addon: it lives in its own file `FBHealBox_Raid.lua`, hooks into the core only through `FBHealBox_RegisterHook` and `FBHealBox_AddOptionsTab`, and is on by default. It does nothing until it is needed: the grid appears on its own once you are in a raid with **at least 11 players** (*Raid view from N players*, adjustable from 2 to 40); smaller raids keep the party display, which shows your own subgroup. The *Raid mode* switch is only an emergency off. Everything described above keeps working unchanged.

**Installing the module:** `FBHealBox_Raid.lua` must sit next to `FBHealBox.lua`, the `.toc` must list it (the shipped `.toc` does), and the game client must be **restarted** once. A `/reload` does not pick up files newly added to a `.toc`. When the module is active, the login lines in the chat include *Raid mode module loaded*, and the options window shows a third tab.

### What it shows

Once the raid reaches the threshold, a compact **grid** appears: one **cell** per member, grouped in **blocks of five** by raid group, the blocks arranged in rows. Each cell (70 by 22 px by default) shows the name in class colour, the health bar with the same shield and incoming-heal layers as the party plates, a 3 px mana strip for mana users, the HP percentage or the missing health, dispel colouring, *Dead* / *Ghost* / *Offline* text, range fading, the line-of-sight eye and the orange buff-watch border. To the right of every cell sit up to four **mini buttons** that cast the spells of Button 1 to N from the *Buttons* tab, right-click spells included. A click on the cell itself does what *Left click on plate* / *Right click on plate* says (target by default; the unit menu comes from Blizzard's raid frame).

Group blocks are laid out with *Groups per row* (default 4): a 40-player raid is two rows of four blocks, about 570 by 270 px with two buttons per cell and the buff-icon strip. **Empty groups take no space**, so a 20-player raid is a single row. The whole grid scales independently of the party plates and remembers its position.

While the grid is shown the five party plates are hidden (option *Hide party plates in raid*), so the screen is never filled twice.

### Tab *Raid mode*

|Setting|Effect|
|-|-|
|Raid mode|Master switch (emergency off). On by default|
|Raid view from N players|Threshold for switching from the party display to the grid. Default 11, that is more than 10 players|
|Hide party plates in raid|Hide the party display while the grid is up. On|
|Group headers|Group number above each block. On|
|Mana strip|3 px mana bar in the cell. On|
|Hide empty groups|Groups without members collapse. On|
|Title bar|Thin bar above the grid to drag it by. Without it, Shift + drag any cell. On|
|Show buffs|Buff icons with clock left of each cell. Off: no icons and no reserved strip, the groups move closer together. On|
|HP text|none, percent or deficit (missing health as a negative number)|
|Raid test|Fills the grid with 20 or 40 ghosts: dead, offline, ghost, magic and disease debuffs, out of range, out of sight, missing buff, shield, incoming heal and buff icons (every third ghost, ghost 12 with twelve) are all represented. Not saved|
|Groups per row|1 to 8. Default 4|
|Raid scale|0.5 to 1.5|
|Cell width / height|50 to 120 px / 14 to 32 px|
|Buttons per unit|0 to 4 mini buttons. Default 2|
|Button size|12 to 28 px|
|Cell spacing / Group spacing|0 to 10 px / 0 to 20 px|

All raid settings live in `HealBox.Raid`. `/fbp raidtest 20`, `/fbp raidtest 40` and `/fbp raidtest off` switch the raid test from the chat line; `/fbp` reports the raid state.

### How it hooks in

The core exposes `FBHealBox_RegisterHook(name, fn)` and runs the hooks at fixed points: `Defaults`, `SyncOptions`, `ApplyLocale`, `UpdateNames`, `RefreshAllBars`, `ButtonsChanged`, `ActiveToggle`, `Status`, `Slash`, `Loaded`, `Aggro`, `SpellTimers` and `Cooldowns`. `FBHealBox_AddOptionsTab(labelKey)` adds a tab to the options window. The raid module registers its roster refresh on `UpdateNames`, its cell refresh on `RefreshAllBars` (so the heal prediction reaches raid cells for free), and its slash commands on `Slash`. Raid units are added to `FBPredictUnits`, which lets HoT and shield confirmation via `UNIT_AURA` work for `raid1` to `raid40`. Pets are not shown in raid mode.

---

## Mana ticker

The mana ticker lives in its own module `FBHealBox_Ticker.lua` and is on by default. A **spark** travels across the mana strip of your own plate (and of your own cell in the raid grid) every 2 seconds, in step with the server's mana regeneration tick. When you spend mana the spark turns **orange** and runs the five-second rule down; it reaches the end exactly when spirit regeneration resumes, which is the first tick after the five seconds, not the five seconds themselves. Casting right after the spark reaches the end wastes no regeneration.

### How it works

There is no API for this in 1.12, so the module watches `UNIT_MANA` for the player. Mana going down starts the five-second rule. Mana going up is a tick candidate: the first one sets the 2 s grid, every later one that lands within *Tick tolerance* of the expected time re-synchronises it. Candidates outside the tolerance (Mana Spring pulses, Innervate) are ignored; only after three misses in a row is a new grid accepted. Jumps of at least 300 mana and more than four times the learned tick size (potions, runes) never count. With full mana no ticks arrive, so the grid runs on silently and the spark stays hidden until mana is missing again; it re-synchronises on the next real tick. The spark needs the mana strip (option *Mana bar*) and disappears in bear or cat form.

### Tab *Extras*, section *Mana ticker*

|Setting|Effect|
|-|-|
|Mana ticker|Master switch. On by default|
|Five-second rule|Show the orange phase after spending mana. On|
|Tick tolerance|0.1 to 0.6 s. Raise it if ticks are being missed|
|Tick offset|0.0 to 0.5 s. Runs the spark earlier to compensate latency if it arrives late compared to your mana jumps|
|Spark width|1 to 4 px|

`/fbp ticker` toggles the ticker; `/fbp` reports whether the grid is synced, the time to the next tick and a running five-second rule. Settings live in `HealBox.Ticker`. The ticker shares the *Extras* tab with Smart Damage.

---

## Smart Damage

Rank selection for **attack spells on any action bar**, in its own module `FBHealBox_Damage.lua`, **off by default**. When you press Smite rank 4 on a Bongos or Blizzard bar (or its key binding) and rank 2 would still kill the target, rank 2 is cast instead. Never above the rank on the bar.

### How it works

Every bar and key binding ends in `UseAction(slot)`. The module hooks that function, reads the spell and rank in the slot from a tooltip scan, and decides. Damage per rank is the **minimum** damage from the spell's tooltip ("86 to 98 Holy damage"), raised by the smallest full hit you have actually landed with that rank (crits and partial resists are not counted). A rank qualifies if its minimum damage covers the target's remaining health plus the *Safety margin* (default 20 %). Macros with `/cast` are not affected.

The target's remaining health comes from the first source that answers:

|Source|When|Accuracy|
|-|-|-|
|Server|`UnitHealthMax("target")` is not 100, i.e. the server sends real values (Turtle WoW and others)|exact|
|MobHealth3|`MobHealth3:GetUnitHealth()` knows the mob|as good as that addon|
|MobInfo-2|`MobHealth_GetTargetCurHP()` knows the mob|as good as that addon|
|Own estimate|The addon has fought this mob type (name and level) before|see below|

**Own estimate.** On percent-only servers the addon learns *health points per percent* for each mob type: it adds up the damage it can see in the combat log (yours, your party's, pets') and divides by the drop in the target's percentage, but only once the drop reaches 3 % to keep the 1 % rounding out of it. Of all measurements the **highest** is kept, because damage from raid members outside your party is invisible and would otherwise pull the estimate down; erring high only costs a slightly bigger rank. The remaining health is then the upper edge of the current percent times that value. The estimate is saved per character in `HealBox.MobHP` and improves with every fight; until a type has been measured, Smart Damage leaves that target alone.

### Section *Smart Damage* on the *Extras* tab

|Setting|Effect|
|-|-|
|Smart Damage|Master switch. Off by default|
|Safety margin|0 to 50 %, default 20. Covers partial resists and estimate error|
|Target health source|Live line: which of the four sources answers for your current target|
|Spells|The attack spells found in your spellbook with their rank count|

Spells per class: Priest Smite, Holy Fire, Mind Blast; Druid Wrath, Starfire, Moonfire; Shaman Lightning Bolt, Chain Lightning, Earth/Flame/Frost Shock; Paladin Holy Shock, Hammer of Wrath, Exorcism, Holy Wrath; Mage Fireball, Frostbolt, Fire Blast, Scorch, Pyroblast; Warlock Shadow Bolt, Searing Pain, Immolate, Soul Fire, Conflagrate; Hunter Arcane Shot, Aimed Shot (list `FBDamageSpells`). `/fbp damage` toggles, `/fbp debug` logs every decision with the health source used. Note for hunters: the addon does not load for that class, so Smart Damage only runs after `/fbp forceload`, see [Which classes it loads for](#which-classes-it-loads-for).

---

## Options window

Opened through the **minimap button**:

|Input|Effect|
|-|-|
|Left click|Toggle the options window|
|Shift + left click|Show/hide the entire display|
|Hold right and drag|Move the minimap button|

The window has two tabs.

### Tab *Buttons*

**Button 1 to 10**: one row each with the *Left click* field (icon and spell name). Clicking a field opens the spell menu (see below). The assignment is saved per character.

**Right-click spell**: enables the second spell per button and reveals the *Right click* column next to the left one. Off by default.

**Show N buttons**: how many of the ten buttons actually appear (0 to 10). Assigned but hidden buttons keep their spell.

**Smart Healing / Safety margin**: see [The buttons](#the-buttons). Off by default; margin 0 to 50 %, default 20.

**Smartcross**: enables downranking across spells within a heal chain. Grayed out and disabled when Smart Healing is off; on by default.

### Tab *General*

**Frame scale**: scales the plates from 0.6 to 1.5. Has no effect in party-frame mode.

**Button spacing**: gap between the spell buttons (and between plate and first button), 0 to 20 px. Default 2.

**Row spacing**: vertical gap between the plates, 0 to 20 px. Default 4. Together with button spacing this lets you pack the whole display much tighter.

**Default party frames**: instead of the addon's own plates, the buttons attach to Blizzard's default party frames (`PartyMemberFrameN`); pet buttons attach to `PetFrame` and `PartyMemberFrameNPetFrame`. The addon's name plates and bars are hidden; the heal prediction keeps working invisibly.

**Bar background**: how solid the area behind the bars is, 0 to 100 per cent in steps of 5. Default 0, which is the old look: where health is missing, the game world shows through the plate. Turn it up and a quiet dark grey surface (`FBBAR_BG_COLOR`) sits behind the bars, so the green of the health bar stands on a fixed background instead of on grass, sky or stone. At 100 the plate is opaque. Suggested by a user who found the see-through bar hard to read, and it is worth a try for anyone playing on a bright screen or in a cluttered zone.

**Mana bar**: shows or hides the mana strip inside the health bar. On by default.

**Hide Blizzard party frames**: hides `PartyMemberFrame1` to `4` while you are in a group, so only the Heal Box plates remain. Off by default. This and *Default party frames* can never both be on, because the attach mode docks the plates onto exactly those frames; whichever one is ticked greys the other out. Switching it off brings the frames back immediately, and a class the addon does not load for gets them back too.

**Show rage, energy, focus**: the mana strip normally stays empty for anyone without mana. With this on, warriors, rogues and pets show their own resource in the usual colour (rage red, energy yellow, focus orange, table `FBPOWER_COLORS`). Needs the mana bar to be on. Off by default.

**Show pets**: shows or hides all pet plates. On by default.

**Debuff icon**: shows or hides the debuff icon with stack count next to the name. On by default.

**Line of sight**: shows or hides the eye badge for units out of line of sight (see [Line of sight](#line-of-sight)). On by default.

**Mark who is attacked**, **HoT and shield timers**, **Cooldowns on buttons**, **Buff icons left of the bar**: the indicators described under [The buttons](#the-buttons) and [Who is being attacked](#who-is-being-attacked). All on by default.

**Left click on plate / Right click on plate**: what a click on a name plate does: Target (default), Unit menu, Move display, Nothing. See [Clicking a plate](#clicking-a-plate).

**Test mode**: fills slots 2 to 10 with ghost players and pets so you can arrange the display without a group (see [Test mode](#test-mode)). Not saved; always off after login.

**Class colours**: colours the name on each plate in the class colour (`RAID_CLASS_COLORS` of the client, with a built-in fallback table). Pets keep their light-blue name. On by default.

**Range fading**: fades a whole plate including its buttons to 50 % (`FBRANGE_ALPHA`) when the unit is out of range. Range is checked every half second (`FBRANGE_INTERVAL`) with `IsSpellInRange` on your first assigned button spell; with no spell assigned, `CheckInteractDistance(4)`, that is 28 yards, is used. On by default.

**Buff watch**: a button that opens the cascading menu with your class buffs (Fortitude, Divine Spirit, Mark of the Wild, Blessings, Thorns, Earth Shield, …; only learned ones are listed). Every plate whose unit is **missing** that buff gets an **orange border**. The group version counts too (Prayer of Fortitude for Power Word: Fortitude, Gift of the Wild for Mark of the Wild, Greater Blessings for Blessings), even when cast by another healer: the check first compares buff textures with your spellbook icons and, only if that fails, reads the buff names from a tooltip scan. Checked on `UNIT_AURA` and after every group change, so nothing runs per frame. Pick *No buff watch* to switch it off. Saved as `WatchBuff`. Pets are left out unless *Buff watch on pets* is ticked.

**Buff watch on pets**: also marks pets missing the watched buff. Off by default.

**HealComm sync**: exchanges heal information with the group, see [HealComm sync](#healcomm-sync). On by default.

**Language / Sprache**: switches between English and German. The button opens the same cascading menu as the spell picker. The change takes effect **immediately**: `FBHealBox_ApplyLocale()` relabels the already-built interface, no `/reload` needed. On first start `GetLocale()` decides: German clients start in German, everything else in English. The choice is saved per character.

**To move the window:** drag its frame. Close it with the X in the top right, with **Escape**, or with `/fbp config`. Escape is caught by a hook on `ToggleGameMenu` (in addition to `UISpecialFrames`), so it works on clients that do not honour that list; when Blizzard's game menu is open, Escape closes that first as usual.

---

## Test mode

Tick *Test mode* in the options, or type `/fbp test`. Your own plate stays real; every other slot is filled with a ghost: four players and three pets, so you see the full layout including pets under their owners. If you happen to be in a real group, the ghosts replace it for as long as test mode is on.

The ghosts are built to show every visual state at once:

|Ghost|Shows|
|-|-|
|Brynn|warrior: **dead**, no mana bar, **missing buff** (orange border when a buff watch is set)|
|Cerys|warlock: mana bar, an **absorb shield** segment and the **line-of-sight** badge|
|Dorn|hunter: low health (red) with **incoming healing** behind it|
|Elowen|druid: a **dispellable debuff** (the health bar takes the dispel colour of your class) and **out of range** (faded)|
|Fang, Zorbek, Bramble|pets: a focus pet without mana bar, a mana pet with one, and a pet with incoming healing and a **disease** debuff|

Their health drifts slowly up and down so you can watch the yellow and red thresholds come and go. Dorn also carries the red attacked border, sample timers on buttons 1 and 2 and **six buff icons** with different remaining times (one without a clock). Spell buttons on ghosts do nothing except print a short note; tooltips work. The ghost table is `FBTestGhosts` near the top of the file; names, values and which extras each ghost carries can be edited freely.

Test mode is meant for the addon's own plates; in party-frame mode the ghosts sit at Blizzard's (hidden) frames and are of little use.

---

## The spell menu

A custom cascading menu, not `UIDropDownMenu`: the 1.12 implementation of the latter closes submenus as soon as the mouse brushes a neighbouring entry, and forces check marks and a click sound.

* **Level 1** lists every learned spell of your class from the spell list, each with its icon.
* **An arrow on the right** means multiple ranks exist. The submenu opens **on hover**, overlaps the parent list by two pixels and has a 14-pixel tolerance zone around it so the mouse never loses it on the way over.
* **Open stays open**: only picking a rank, opening another submenu, or clicking outside closes it. After three seconds without the mouse nearby an emergency timer fires (`FBMENU_GRACE_TIME`, set it to 999 to disable).
* **No spell** at the top clears the button again.

The selection is stored as the cast string `Spell(Rank N)`, exactly the form `CastSpellByName` expects, and the reason the prediction knows the precise rank.

---

## Heal prediction

The heart of the addon. Three independent sources feed the bars.

### Direct heals

`SPELLCAST_START` provides the spell name and the cast time in milliseconds, regardless of whether the cast came from a Heal Box button, the action bar or a macro. No hook on `CastSpellByName` is required. The preview disappears on `SPELLCAST_STOP`, `_FAILED` and `_INTERRUPTED`; pushback (`SPELLCAST_DELAYED`) extends it.

Instants deliberately get **no** prediction: the healing has landed before a bar could show it.

### Heal over time

`UnitBuff()` reports no remaining duration for other units, so the addon keeps its own books:

1. The button registers the cast including target and rank.
2. `UNIT_AURA` confirms the application by comparing the **buff texture** with the spellbook icon (locale independent, no tooltip scan per event).
3. What is shown is `remaining ticks × healing per tick`, with the remaining ticks derived from `(expiry − GetTime()) / interval`. The bar therefore counts down tick by tick.
4. If the buff disappears early (dispel, death, overwritten), the display is gone immediately.

HoTs cast from the action bar are recognised as well, then with the highest known rank; the first combat log tick straightens the value out.

The tick interval cannot be read from the tooltip in Vanilla and therefore lives in `FBPredictTickInterval` (3 seconds by default, Lifebloom 1).

### Equipment bonus

Vanilla spell tooltips show the naked base value, the healing bonus from your gear is not in there. Learned values from the combat log carry it automatically, so the gap only exists for ranks you have never cast. If an API supplies the bonus, the addon closes that gap: the value is weighted the vanilla way, cast time divided by 3.5 and capped at 3.5 seconds, instants counting as 1.5. A 3 second Greater Heal with +700 healing therefore starts out 600 higher than its tooltip, a 1.5 second Flash Heal 300.

`GetSpellBonusHealing` is what the addon looks for, plus `GetSpellBonusHeal` and `GetHealingBonus`, first as a global and then inside a `ClassicAPI` table. **ClassicAPI** provides it; without any such API the bonus stays 0 and nothing changes. `/fbp` reports the value found and whether it is being applied, `/fbp healbonus` turns it off. The first learned value for a rank always wins over the estimate.

### Absorb shields

Maximum absorb from the spellbook tooltip, consumption from the combat log (`(123 absorbed)`). For `\*_VS_SELF_*` events the victim is the player, otherwise the message is searched for one of the currently shielded names.

If you absorb more than the tooltip allows (heal gear), the maximum is corrected **upwards** and remembered. That correction is one-directional and therefore safe: more than possible cannot have been absorbed.

Fully absorbed hits report no number in Vanilla. The remaining value then stands until the buff drops and the display is cleared. Likewise absorbs on group members only count as far as the combat log shows them at all; the aura check catches the drift at the end.

### Self-correction and learned values

Tooltips in 1.12 only provide base values **without** +healing, and there is no API for spell power. The combat log, on the other hand, tells the truth:

|Observation|Effect|
|-|-|
|`… gains 194 health from your Renew.`|Sets the real healing per tick for all remaining ticks|
|`Your Flash Heal heals Bob for 1240.`|Settles the estimate in (50/50 averaging)|
|`(342 absorbed)` above the maximum|Raises the assumed shield value|

All of it lands per spell **and rank** in `HealBox.PredictMemory` and survives logout.

Two safeguards keep that memory clean. **Crits are not learned**: the crit wording makes the spell name come through the pattern as "Flash Heal critically", which is in no watch list. And learning only happens with a **confirmed rank**, that is on casts through the Heal Box buttons; otherwise a rank 3 cast from the action bar would be attributed to the maximum rank and drag the prediction down. The live display still corrects itself either way; only the persistent memory is protected.

What a spell can do is decided by its own tooltip, and a spell may be several things at once. Regrowth, for instance, provides an instant portion *and* a HoT, and is treated as both.

---

## HealComm sync

HealComm-1.0 broadcasts plain text through `SendAddonMessage` with the prefix `HealComm`. Heal Box Vanilla speaks that protocol directly, without embedding the library. Puppeteer, pfUI, Luna Unit Frames, CT_RaidAssist and everything else HealComm-aware therefore see your announced heals, and you see theirs.

|Message|Meaning|
|-|-|
|`Heal/<target>/<amount>/<cast time ms>/`|Direct heal starts|
|`Healstop`|Cast interrupted|
|`Healdelay/<ms>/`|Pushback|
|`GrpHeal/<amount>/<ms>/<t1>/<t2>/…`|Group heal (Prayer of Healing)|
|`GrpHealstop` · `GrpHealdelay/<ms>/`|Same for group heals|
|`Renew` · `Reju` · `Regr` `/<target>/<duration>/`|HoT applied|

Messages go to the raid, otherwise to the party, otherwise nowhere. The amounts are the self-corrected combat log values, so arguably more accurate than what a real HealComm estimates with ItemBonusLib.

A few details: on a successful cast end **no** `Healstop` is sent; HealComm receivers expire the entry themselves at cast time. Prayer of Healing correctly goes out as `GrpHeal` with every target in range. And a HoT cast from the action bar is reported after the fact on the first own combat log tick, with the duration still remaining, because only "… from **your** Renew" proves that it is yours.

On receive, your own messages are filtered by sender name, and since HealComm stores incoming heals per caster nothing can double up, not even when a real HealComm is broadcasting alongside. HoT messages carry only durations and no amounts; HealComm does not count them in its own `getHeal`, and neither does this addon.

**The protocol knows nothing about absorb shields**: those stay local.

---

## Slash commands

|Command|Effect|
|-|-|
|`/fbp`|Status report: every tooltip value read per spell (direct, HoT and shield portion, learned values in parentheses), all currently running predictions, the state of the HealComm sync and the incoming heals received|
|`/fbp debug`|Toggles live output. Reports every detected cast, every correction, every absorb and every message sent (`[FBP>]`)|
|`/fbp reset`|Discards all learned values and re-reads the tooltips|
|`/fbp test`|Toggles test mode (same as the checkbox)|
|`/fbp config`|Opens or closes the options window (same as the minimap button)|
|`/fbp buffs`|Lists the tracked buff spells, their presence and remaining time on you, and your raw buff textures|
|`/fbp forceload`|Warrior, rogue and hunter only: shows the addon anyway, or hides it again. Saved per character|
|`/fbp smartcross`|Smart Healing: downranking across spells within a heal chain on/off (on by default)|
|`/fbp healbonus`|Counts the equipment healing bonus into the prediction, on/off. Only works when an API supplies the bonus|
|`/fbp raid`|Toggles raid mode|
|`/fbp raidtest 20` · `40` · `off`|Raid test with 20 or 40 ghosts, or off|
|`/fbp ticker`|Toggles the mana ticker|
|`/fbp damage`|Toggles Smart Damage|

`/fbp` is the first place to look when something is not displayed: if a spell is not listed there, the tooltip parser did not recognise it; the display is not at fault.

---

## Saved settings

Everything lives in the `HealBox` table, saved **per character**:

|Key|Contents|
|-|-|
|`SpellChoice[1..10]`|Cast string per button, e.g. `Renew(Rank 10)`|
|`MaxButtons`|How many buttons are shown|
|`Scale`|Scale of the plates|
|`AttachMode`|0 = own plates, 1 = default party frames|
|`Active`|Display on/off (shift + left click on the minimap)|
|`ForceLoad`|1 = show for warrior, rogue and hunter as well, 0 = off (default). Set with `/fbp forceload`|
|`HealComm`|1 = sync on, 0 = off|
|`Locale`|`deDE`, `enUS`, `esES`, `frFR` or `itIT`|
|`ButtonSpacing`|Gap between the buttons in px (0 to 20)|
|`RowSpacing`|Gap between the plates in px (0 to 20)|
|`ManaBar`|1 = mana strip on, 0 = off|
|`BarBG`|Opacity of the bar background in per cent, 0 to 100. 0 (default) keeps the see-through look|
|`ShowPets`|1 = pet plates on, 0 = off|
|`SpellChoiceR[1..10]`|Cast string per button for right click|
|`RightClick`|1 = right-click spell on, 0 = off (default)|
|`DebuffIcon`|1 = debuff icon on, 0 = off|
|`LOSIcon`|1 = line-of-sight badge on, 0 = off|
|`PlateLeft` · `PlateRight`|Click action on a plate: `target`, `menu`, `move` or `none`|
|`SmartRank` · `SmartMargin`|Smart Healing on/off (default off) and safety margin in percent|
|`SmartCross`|1 = downranking may switch spell within a heal chain (default), 0 = stay on the assigned spell. Set in the options or with `/fbp smartcross`|
|`PowerBar`|1 = the bar also shows rage, energy and focus, 0 = mana only (default)|
|`HideBlizzParty`|1 = Blizzard's party frames stay hidden, 0 = untouched (default). Never active together with `AttachMode`|
|`HealBonus`|1 = equipment healing bonus counts towards unlearned ranks (default), 0 = plain tooltip values. `/fbp healbonus`|
|`Cooldowns` · `AggroMark` · `SpellTimers` · `BuffIcons`|Cooldown sweep, red border for the attacked member, HoT/shield timers, buff icons left of the bar|
|`ClassColors`|1 = names in class colour, 0 = white|
|`RangeFade`|1 = fade plates out of range, 0 = off|
|`WatchBuff`|Spell name of the buff watch, or nil|
|`BuffWatchPets`|1 = buff watch also on pets, 0 = players only (default)|
|`PosX` · `PosY`|Top-left corner of the player plate in screen pixels|
|`Ticker`|Sub-table with the mana ticker settings (see [Mana ticker](#mana-ticker))|
|`Damage`|Sub-table with the Smart Damage settings; `MobHP` and `DmgMemory` hold the learned mob health and minimum damage values (see [Smart Damage](#smart-damage))|
|`Raid`|Sub-table with every raid-mode setting (see [Raid mode](#raid-mode)), including `PosX` / `PosY` of the grid|
|`PredictMemory`|Learned heal values per spell and rank|

Missing keys, for example in an old `HealBox` table from 1.4, are filled in by `FBHealBox_ApplyDefaults()` on load. Test mode is deliberately **not** saved.

---

## Configuration in code

Every knob is a global at the top of its own section and can be changed without touching the logic.

|Constant|Default|Effect|
|-|-|-|
|`LowHP` · `VeryLowHP`|0.6 · 0.3|Thresholds for yellow and red|
|`NamePlateWidth` · `NamePlateHeight`|120 · 28|Size of one plate|
|`FBMANA_BAR_HEIGHT`|5|Height of the mana strip in px|
|`FBMANA_BAR_COLOR`|`{0.15, 0.4, 1, 1}`|Colour of the mana strip|
|`FBMANA_BG_ALPHA`|0.35|Dark strip behind missing mana (0 = off)|
|`FBBAR_BG_COLOR`|0.15 · 0.15 · 0.15|Shade of the bar background; how solid it sits is the `BarBG` option|
|`FBPET_NAME_COLOR`|`{0.75, 0.85, 1, 1}`|Name colour on pet plates|
|`FBPET_INDENT`|12|Indent (and width reduction) of pet plates|
|`FBPET_ICON` · `FBPET_ICON_SIZE`|footprint · 12|Paw icon in front of pet names|
|`FBDEBUFF_ICON_SIZE`|14|Edge length of the debuff icon|
|`FBLOS_ICON` · `FBLOS_ICON_SIZE`|Blind icon · 12|Line-of-sight badge|
|`FBLOS_ICON_X` · `FBLOS_ICON_Y`|-3 · 3|Badge offset from the plate's top-left corner|
|`FBLOS_TIMEOUT`|8|Seconds a line-of-sight error stays marked without UnitXP|
|`FBNAME_WIDTH_FULL` · `FBNAME_WIDTH_ICON`|78 · 60|Width of the name box without / with a visible debuff icon|
|`FBRANGE_ALPHA` · `FBRANGE_INTERVAL`|0.5 · 0.5|Faded opacity and check interval of the range fading|
|`FBBUFF_MISSING_COLOR`|`{1, 0.5, 0, 1}`|Border colour when the watched buff is missing|
|`FBAGGRO_COLOR`|`{1, 0.15, 0.15, 1}`|Border colour for the attacked member|
|`FBCD_MIN_DURATION`|2|Length of the global cooldown: a cooldown up to this length does not darken a button|
|`FBCD_SHOW_MIN`|0|From which length the cooldown sweep runs. 0 shows every cooldown including the global one, 2 leaves it out|
|`FBTIMER_COLOR_HOT` · `_SHIELD` · `_WS`|green · blue · red|Timer colours on the buttons|
|`FBBUFFICON_SIZE` · `FBBUFFICON_GAP` · `FBBUFFICON_MAX` · `FBBUFFICON_XOFF`|8 · 1 · 6 · -2|Buff icons left of the plate|
|`FBBUFFICON_STEPS` · `FBBUFFICON_GREY`|32 · 0.30|Duration progress steps (32) and grey tint when client cannot desaturate|
|`FBNAME_HEIGHT`|12|Height of the name box (one line, vertically centred)|
|`FBWEAKENED_SOUL_SEC`|15|Length of Weakened Soul|
|`FBClassColors`|(table)|Fallback class colours if the client has no `RAID_CLASS_COLORS`|
|`FBBuffWatchSpells` · `FBBuffAlternates`|(table)|Buffs offered per class, and which group version counts as the same|
|`FBPartyUnit` · `FBLayoutOrder`|(table)|The ten slots and their display order|
|`FBTestGhosts`|(table)|Names and values of the test-mode ghosts|
|`MaxButtonCount`|10|Maximum number of buttons|
|`FBMENU_BTN_HEIGHT` · `FBMENU_ICON_SIZE`|17 · 16|Row height and icon size in the menu|
|`FBMENU_MOUSE_PAD`|14|Tolerance zone around the menus|
|`FBMENU_GRACE_TIME`|3.0|Menu auto-close (999 = off)|
|`FBPREDICT_TICK_DEFAULT`|3|Default tick interval for HoTs|
|`FBPREDICT_THROTTLE`|0.2|Update rate of the prediction|
|`FBRAID_TICK` · `FBRAID_TICK_SLICES`|0.5 · 4|Full sweep for raid range and line of sight, and how many ticks it is spread over|
|`FBTICK_GEOM_STEP`|0.25|How often the ticker re-reads the bar size (the spark itself is drawn every frame)|
|`FBPREDICT_CONFIRM_TIME`|3.0|Time to wait for the aura confirmation|
|`FBPREDICT_TARGET_TIME`|2.0|Lifetime of the remembered cast target|
|`FBPredictTickInterval`|`{Lifebloom = 1}`|Deviating tick intervals|
|`FBCommGroupHeal`|`{Prayer of Healing}`|What is broadcast as `GrpHeal`|
|`FBPOWER_COLORS`|blue · red · orange · yellow|Bar colour per resource (mana, rage, focus, energy)|
|`FBHealChains`|(table)|Which spells count as the same heal, only smaller. Smart Healing may switch spell inside a chain|
|`FBHoTSpells`|(table)|Heal over time spells that Smart Healing never downranks|
|`FBBlockedClasses`|`WARRIOR`, `ROGUE`, `HUNTER`|Classes the addon does not load for without `/fbp forceload`|
|`FBLocale`|`enUS`, `deDE`, `esES`, `frFR`, `itIT`|Every visible string, per language|

---

## Function reference

### Display and frames

|Function|Purpose|
|-|-|
|`FBHealBox_OnLoad()`|Event registration|
|`FBHealBox_OnEvent(event, arg1)`|Central event dispatch; also decides the class gate on `ADDON_LOADED` / `VARIABLES_LOADED`|
|`FBHealBox_ClassIsBlocked()` · `FBHealBox_ClassAllowed()`|Is this a warrior, rogue or hunter, and may the display run anyway (`ForceLoad`)?|
|`FBHealBox_ApplyClassGate()` · `FBHealBox_Suppressed()`|Applies the class gate and reports the sleeping state to the modules|
|`FBHealBox_HideAll()` · `FBHealBox_StartUp()` · `FBHealBox_Announce()`|Puts everything to sleep, wakes everything up, prints the startup message once|
|`FBHealBoxSetup()`|Creates the ten plates (five players, five pets)|
|`FBHealBoxCreateFrame(…)`|Builds one plate including its four bars|
|`FBHealBox_SetBarStrata(f, strata)`|Stacks mana / health / shield / prediction|
|`FBHealBox_SetPlateVisible(f, visible)`|Shows or hides all bars of a plate (party-frame mode)|
|`FBHealBox_UpdateUnit(unit, frame)`|Writes HP, shield, prediction, mana and dispel colour into a plate|
|`FBHealBox_UpdateMana(unit, frame)`|The mana strip: shown only for mana users|
|`FBHealBox_DispelType(unit)`|First debuff your class can remove: type, texture, stacks, or nil|
|`FBHealBox_UpdateDebuffIcon(frame, tex, count)`|Debuff icon and stack count|
|`FBHealBox_CastOn(button, castString)`|Casts a button's spell (left or right) on its target|
|`FBHealBox_DropSpell(btnIndex, side)` · `FBHealBox_CursorSpell()`|Drag and drop from the spellbook|
|`FBHealBox_SmartRank(castString, unit)`|Picks the rank to cast|
|`FBHealBox_IsHoT(base, ranks)`|Heal over time? List of names plus tooltip, spell watch and running HoTs. Smart Healing skips these|
|`FBHealBox_HealFamily(base)` · `FBHealBox_DirectAmount(spell, sd)`|The heal chain a spell belongs to; the expected heal of one rank, or nil if the spell is not eligible|
|`FBPredict_ExpectedDirect(spell, rank, info, id)`|Expected direct heal: learned value, otherwise tooltip plus the share of the equipment bonus|
|`FBHealBox_ProbeHealBonus()` · `FBHealBox_HealingBonus()` · `FBHealBox_HealBonusFor(id)`|Finds an API for the healing bonus, reads it, and weights it by cast time|
|`FBHealBox_SpellCastSeconds(id)`|Cast time from the tooltip (0 = instant), cached per spellbook slot|
|`FBHealBox_ApplyBlizzParty()` · `FBHealBox_HideBlizzPartyActive()`|Hides or restores Blizzard's party frames, including the lock against the attach mode|
|`FBHealBox_SetPowerColor(bar, cache, ptype)`|Colours a resource bar for mana, rage, focus or energy|
|`FBHealBox_ApplyBarBG(f)` · `FBHealBox_ApplyBarBGAll()`|Sets the background behind a plate's bars from the `BarBG` option|
|`FBPredict_ScanPlayerBuffTimes()`|Reads all of your own buff timers once per frame into a texture-to-seconds map|
|`FBHealBox_ApiFailed()`|Puts range, distance and line of sight back to the protected single call after a sweep threw|
|`FBHealBox_UpperTex(tex)`|Upper-cased texture path, remembered, so `strupper` does not allocate per call|
|`FBHealBox_CheckAggroAll()` · `FBHealBox_ApplyBorder(f)`|Red border for the attacked member; border precedence|
|`FBHealBox_UpdateSpellTimers()` · `FBHealBox_SpellTimerFor(...)`|HoT/shield timers on buttons|
|`FBHealBox_UpdateButtonCooldown(b)` · `FBHealBox_UpdateAllCooldowns()`|Cooldown sweep|
|`FBHealBox_ShowTab(n)` · `FBHealBox_ApplyRightClickLayout()`|Options tabs; show/hide the right-click column|
|`FBHealBox_PlateMouseDown(f)` · `FBHealBox_PlateMouseUp(f)` · `FBHealBox_RunPlateAction(f, action)`|Click and drag on a plate|
|`FBHealBox_RefreshAllBars()`|Updates all ten|
|`FBUpdateNames()`|Names and visibility after a group or pet change, then re-layout|
|`FBSlotActive(p)`|Is slot p to be shown right now?|
|`FBHealBox_Layout()`|Stacks the visible plates (owner, then pet) with `RowSpacing`|
|`FBHealBox_ApplyButtonSpacing()`|Re-chains all buttons with `ButtonSpacing`|
|`FBHealBox_SavePosition()` · `FBHealBox_RestorePosition()`|Plate position in the saved variables|
|`FBHealBox_ApplyDefaults()` · `FBHealBox_SyncOptions()`|Fill missing settings; align the options window with them|
|`FBHealBox_ApplyNameColor(unit, f)` · `FBHealBox_ApplyAllNameColors()`|Name in class colour / pet colour|
|`FBHealBox_SetWatchBuff(name)` · `FBHealBox_HasWatchBuff(unit)` · `FBHealBox_CheckWatchBuff(unit, f)`|Buff watch: select, test one unit, colour the border|
|`FBHealBox_UnitInRange(unit)` · `FBHealBox_CheckRangeAll()`|Range fading|
|`FBUnitLOSBlocked(unit)` · `FBLOS_OnError(msg)` · `FBLOS_Clear(name)` · `FBHealBox_CheckLOSAll()`|Line of sight (UnitXP or error-message fallback)|
|`FBMenu_OpenBuffMenu(anchor)`|The buff picker (same cascading menu)|
|`HealBoxAttachMode(mode)`|Switch between own plates ↔ default party frames|
|`HealBoxScale(this, scale)`|Scaling|

### Units and test mode

The display never calls `UnitExists`, `UnitName`, `UnitHealth` or `UnitMana` directly. It goes through these wrappers, which answer from `FBTestGhosts` while test mode is on and from the real API otherwise:

|Function|Returns|
|-|-|
|`FBUnitExists(unit)`|true / false|
|`FBUnitName(unit)`|Name|
|`FBUnitHealth(unit)`|`hp, hpMax` (hpMax is never 0)|
|`FBUnitMana(unit)`|`mp, mpMax, hasMana`; hasMana only for power type mana|
|`FBUnitClassToken(unit)`|`"PRIEST"`, `"WARRIOR"`, … or nil for pets|
|`FBUnitState(unit)`|nil, `"dead"`, `"ghost"` or `"offline"`|
|`FBChoiceTables(side)`|Runtime and saved tables of the left (`"L"`) or right (`"R"`) assignment|
|`FBTest_Ghost(unit)`|The ghost record, or nil|
|`FBTest_Set(on)`|Switch test mode|

### Buttons and spell data

|Function|Purpose|
|-|-|
|`FBHealBoxCreateButton(…)`|One spell button including cast logic and tooltip|
|`FBHealBoxButtons()`|Rebuilds all buttons|
|`FBHealBoxButtonsChanged()`|Refreshes icons and assignment without rebuilding|
|`FBLoadSpellData()`|Scans the spellbook, collects all ranks|
|`FBApplySpellChoice(i, castString)`|Assigns a spell to a button|
|`HealBoxButton_OnEvent(…)`|Tints the icon by mana, cooldown and range|

### Spell menu

|Function|Purpose|
|-|-|
|`FBMenu_OpenMenu(entries, anchor)`|Opens any entry list as a menu|
|`FBMenu_OpenSpellMenu(btnIndex, anchor, side)`|Opens the menu for one options field (`side` = `"L"` or `"R"`)|
|`FBMenu_OpenLanguageMenu(anchor)`|The language picker|
|`FBMenu_ShowLevel(level, entries, anchor)`|Builds and positions one menu level|
|`FBMenu_BuildSpellEntries()`|Level 1: all learned spells|
|`FBMenu_BuildRankEntries(spellName)`|Level 2: all ranks of one spell|
|`FBMenu_SelectSpell(entry)` · `FBMenu_ClearSpell()`|Apply a selection, or clear the button|
|`FBMenu_CloseAll()` · `FBMenu_IsOpen()`|Close the menu, query its state|

### Prediction: queries

The four functions that feed the bars. All of them expect a **player name**, not a unit ID:

|Function|Returns|
|-|-|
|`FBGetDirectHeal(name)`|Amount of your running direct cast|
|`FBGetHoTHeal(name)`|Sum of all your outstanding HoT ticks|
|`FBGetShield(name)`|Remaining absorb|
|`FBGetCommHeal(name)`|Healing announced by other healers|

### Prediction: internals

|Function|Purpose|
|-|-|
|`FBPredict_GetSpellInfo(bookID, name)`|Parses the spellbook tooltip (direct / HoT / shield)|
|`FBPredict_BuildWatch()`|Builds the watch list after every spellbook scan|
|`FBPredict_NoteCast(castString, target)`|Registers target and rank **before** the cast|
|`FBPredict_CastStart(spell, castMs)` · `FBPredict_CastEnd()`|Start and end a direct heal|
|`FBPredict_ScanUnit(unit)`|Aura check: confirm application, detect removal|
|`FBPredict_StartHoT(…)` · `FBPredict_StartShield(…)`|Arm the tracking|
|`FBPredict_ParseCombat(event, msg)`|Combat log evaluation|
|`FBPredict_OnTick(…)` · `FBPredict_OnDirectHeal(…)` · `FBPredict_OnAbsorb(…)`|The three correction paths|
|`FBPredict_Remember(…)` · `FBPredict_Remembered(…)`|Write and read the learned values|
|`FBPredict_TicksLeft(e, now)`|Remaining ticks of a HoT|

### HealComm

|Function|Purpose|
|-|-|
|`FBComm_Enabled()`|Is the sync switched on?|
|`FBComm_Send(msg)`|Raw send to raid or party|
|`FBComm_SendHealStart(…)`|`Heal` or `GrpHeal`|
|`FBComm_SendHealStop()` · `FBComm_SendHealDelay(ms)`|Interrupt and pushback|
|`FBComm_SendHoT(spell, target, dur)`|`Renew` / `Reju` / `Regr`|
|`FBComm_OnMessage(prefix, msg, channel, sender)`|Receive and evaluate|

### Localization

|Function|Purpose|
|-|-|
|`FBT(key)`|Looks up a string in the active language, falls back to English|
|`FBSetLocale(code, apply)`|Switches language and optionally relabels the interface|
|`FBDetectLocale()`|Default language from `GetLocale()`|
|`FBHealBox_ApplyLocale()`|Relabels the already-built interface|

---

## Troubleshooting

**Nothing shows up at all after login.** Check the chat for the orange line naming your class: on a warrior, rogue or hunter the addon stays asleep on purpose. `/fbp forceload` shows it anyway, see [Which classes it loads for](#which-classes-it-loads-for).

**Smart Healing does not downrank a spell.** Heal over time spells are excluded on purpose, and so are shields, buffs and any spell whose tooltip does not describe a heal. If it downranks but never leaves the assigned spell, the spell is not in any heal chain, or `/fbp smartcross` is off. Below 30 % health the assigned rank is always used. `/fbp debug` prints the reason for every decision.

**A spell does not appear in the menu.** It is not in your class's spell list (`Spell.Name` near the top of the file), or not learned yet. The list can be extended freely.

**Learned absorb values are capped.** A remembered absorb larger than 1.5 times the tooltip value is treated as a counting error and dropped on load (`FBPredict_SanitizeMemory`); values from versions before 1.4.2 that were doubled by the old double load clean themselves up this way.

**No prediction for a particular spell.** Run `/fbp`: if the spell is not among the spells read, the tooltip parser did not recognise it. Wording can differ on custom servers; the patterns all sit in `FBPredict_GetSpellInfo`.

**Combat log corrections do not take.** The patterns are built from the client's global strings (`PERIODICAURAHEALOTHERSELF`, `HEALEDSELFOTHER`, `ABSORB_TRAILER`) and otherwise fall back to English defaults. `/fbp debug` shows whether corrections arrive.

**Values are too low.** Before the first observed heal only the tooltip base value without +healing is available. A single cast through the buttons is enough to settle it.

**The HealComm sync seems dead.** It only sends in a party or raid; alone nothing happens. `/fbp` shows the switch state, `/fbp debug` every outgoing message.

**Numbers are off after a gear change.** They correct themselves on the next cast; `/fbp reset` forces a fresh start.

---

## Class spells

The preset lists, freely extensible in `Spell.Name`:

|Class|Spells|
|-|-|
|Priest|Renew · Flash Heal · Lesser Heal · Heal · Greater Heal · Binding Heal · Prayer of Healing · Prayer of Mending · Circle of Healing · Power Word: Shield · Abolish Disease · Cure Disease · Dispel Magic · Power Word: Fortitude · Prayer of Fortitude · Divine Spirit · Prayer of Spirit · Shadow Protection · Prayer of Shadow Protection · Fear Ward · Power Infusion · Resurrection|
|Druid|Healing Touch · Regrowth · Rejuvenation · Swiftmend · Tranquility · Lifebloom · Abolish Poison · Cure Poison · Remove Curse · Mark of the Wild · Gift of the Wild · Thorns · Innervate · Rebirth|
|Shaman|Lesser Healing Wave · Healing Wave · Chain Heal · Earth Shield · Water Shield · Cure Poison · Cure Disease · Purge · Ancestral Spirit · Water Walking · Water Breathing|
|Paladin|Flash of Light · Holy Light · Holy Shock · Lay on Hands · Cleanse · Purify · Blessing of Protection · Blessing of Freedom · Blessing of Sacrifice · Redemption · Divine Intervention · Blessing of Wisdom / Might / Kings / Salvation / Light / Sanctuary · Greater Blessing of Wisdom / Might / Kings / Salvation / Light / Sanctuary|
|Mage|Remove Lesser Curse · Arcane Intellect · Arcane Brilliance · Dampen Magic · Amplify Magic|
|Warlock|Unending Breath · Detect Invisibility · Detect Lesser / Greater Invisibility|

Entries that do not exist do no harm: if the spellbook scan does not find them, they are quietly skipped.

---

## Credits

**Original: Heal Box by Dourd** (Argent Dawn EU), UI Overhauled. The core idea, the layout with name plates and quick-cast buttons and the original options window are his. Without that groundwork this addon would not exist. Credit where credit is due.

**Ported to Vanilla and extended 09/2026: Mquadrat.** Ported to client 1.12.1 with optional SuperWoW support, plus:

* a custom cascading menu for spell and rank selection, because `UIDropDownMenu` provides no usable submenus in 1.12
* heal prediction for direct heals, remaining HoT ticks and absorb shields, self-correcting from the combat log
* HealComm sync with Puppeteer, pfUI, Luna and others, without any Ace libraries
* English, German, Spanish, French and Italian localization, switchable in game
* 1.4.5.3: adjustable background behind the plate bars, so the game world no longer shows through where health is missing; see CHANGELOG
* 1.4.5.2: a running HoT no longer counts as incoming healing when Smart Healing picks a rank; see CHANGELOG
* 1.4.5.1: mana ticker spark no longer stutters (movement threshold and redraw step), and the global cooldown no longer darkens every button but is shown as a sweep instead (own threshold `FBCD_SHOW_MIN`); see CHANGELOG
* 1.4.5: Blizzard's party frames can be hidden (mutually exclusive with the attach mode), rage, energy and focus in the resource bar, and the equipment healing bonus via ClassicAPI in the prediction, plus a performance pass without functional change (player buffs read once per frame, staggered raid range and line-of-sight sweeps, fewer protected calls, no throwaway strings in the raid health text); see CHANGELOG
* 1.4.4.3: class gate for warriors, rogues and hunters (display stays off, chat hint, `/fbp forceload` to override) and Smart Healing no longer downranks heal over time spells of any class. Smart Healing downranks across spells inside a heal chain (Greater Heal to Lesser Heal, Holy Light to Flash of Light), `/fbp smartcross` turns it off; see CHANGELOG
* 1.4.4.2: 32-step buff icon duration display (replacing the 4-quadrant clock with a 32-stage vertical wipe) and syntax/diagnostic bugfixes; see CHANGELOG
* 1.4.4.1: buff tracking & tooltip scanning fix (Divine Spirit clock icon), expanded class spell lists with blessings, buffs, utility and rez spells, group buff alternate tracking; see CHANGELOG
* 1.4.4: performance pass without functional change (central button states, display caches, shared aura scans, coalesced event bursts); see CHANGELOG
* 1.4.3: mana ticker module (2 s regeneration tick and five-second rule as a spark in the mana bar), Smart Damage module (rank selection for attack spells on any action bar), Smart Healing (auto-downrank, off by default), cooldown sweep on buttons, red border for the attacked member, HoT/shield timers on buttons
* 1.4.2: raid mode as a separate module (`FBHealBox_Raid.lua`) with a compact 20/40 grid, mini buttons, own options tab and raid test; hook interface in the core
* 1.4.1: pet plates, mana bar inside the health bar, adjustable button and row spacing, test mode with ghost players, saved plate position, class colours, buff watch, range fading, tabbed options, right-click spell, dead/ghost/offline text, debuff icon. See CHANGELOG.md.

---

Heal Box Vanilla v1.4.5.3 · original by Dourd, UI Overhauled · ported to Vanilla and extended 09/2026 by Mquadrat

_______________________________________________________________________
GERMAN

# Heal Box Vanilla

ADDON DOKUMENTATION · VERSION 1.4.5.3 · World of Warcraft CLIENT 1.12.1

Party-, Begleiter- und Selbst-Heilanzeige mit Schnellzugriff-Buttons für Heiler. Für jeden Gruppenplatz eine Namensplakette mit Lebensbalken, dazu eine für jeden Begleiter in der Gruppe direkt unter seinem Besitzer, daneben bis zu zehn frei belegbare Zauber-Buttons. Ein schmaler Manabalken liegt im Lebensbalken, bei allen, die tatsächlich Mana nutzen. Dazu eine vollständige Heilvorhersage (Direktheilung, HoT-Restticks und Absorb-Schilde), die sich über den Combatlog selbst korrigiert und ihre Werte im HealComm-Format mit anderen Heilern teilt. Die Oberfläche gibt es auf **Deutsch und Englisch**, umschaltbar im Optionsfenster.

**Kurzfassung für Ungeduldige:** Minimap-Button anklicken (oder `/fbp config`) → Optionsfenster → für jeden Button einen Zauber wählen → fertig. Alles Weitere passiert von allein. `/fbp` zeigt jederzeit, was die Vorhersage gerade denkt. **Neu in 1.4.1:** *Testmodus* anhaken, dann füllt sich die Anzeige mit Geisterspielern und du kannst alles ohne Gruppe einrichten.

---

## Installation

Der Ordner unter `Interface\AddOns` heißt **`FBHealBox`** und enthält sieben Dateien:

|Datei|Inhalt|
|-|-|
|`FBHealBox.toc`|Metadaten, Ladereihenfolge, SavedVariables|
|`FBHealBox.lua`|Der Kern: Gruppen- und Begleiteranzeige, Vorhersage, HealComm, Optionen|
|`FBHealBox_Raid.lua`|Das Raidmodus-Modul (siehe [Raidmodus](#raidmodus)). Aus der `.toc` entfernt, läuft der Kern genau wie in 1.4.1|
|`FBHealBox_Ticker.lua`|Das Mana-Ticker-Modul (siehe [Mana-Ticker](#mana-ticker)), ebenfalls entfernbar|
|`FBHealBox_Damage.lua`|Das Smart-Damage-Modul (siehe [Smart Damage](#smart-damage)), ebenfalls entfernbar|
|`FBHealBox.xml`|Nur der Event-Frame, der `FBHealBox_OnLoad` und `FBHealBox_OnEvent` aufruft|
|`CHANGELOG.md`|Was sich in welcher Version geaendert hat|

Der Ordnername muss zum Dateinamen der `.toc` passen, sonst startet das Addon nicht. Willst du den Ordner umbenennen, ändere in `FBHealBox.lua` zusätzlich die Konstante `FBADDON_FOLDER` am Dateianfang, denn daran hängt der `ADDON_LOADED`-Abgleich. Der Anzeigename steht getrennt davon in `FBADDON_NAME` und darf frei geändert werden.

**Optional: SuperWoW.** Wird es erkannt, meldet das Addon beim Login `[SuperWoW erkannt]` und castet direkt auf das Gruppenmitglied, ohne dein aktuelles Ziel anzufassen. Ohne SuperWoW wechselt das Addon für den Cast kurz das Ziel und stellt das alte danach wieder her.

**Keine Bibliotheken nötig.** Kein Ace, kein HealComm, kein RosterLib. Das Addon spricht das HealComm-Protokoll direkt, siehe [HealComm-Sync](#healcomm-sync).

---

## Für welche Klassen es lädt

Das Addon ist fürs Heilen und Buffen gebaut. **Krieger, Schurken und Jäger** haben nichts davon: keine Heilzauber, keine Heilvorhersage, und ein Mana-Ticker, der entweder kein Mana zu beobachten hat (Wut, Energie) oder niemanden zu heilen (Jäger). Wer sich mit einer dieser drei Klassen einloggt, bekommt deshalb gar nichts zu sehen. Keine Plaketten, kein Raid-Raster, kein Minimap-Button, kein Optionsfenster, und auch keine Event-Verarbeitung, das Addon kostet im Ruhezustand also nichts. Stattdessen stehen zwei Zeilen im Chat: was passiert ist und wie man es ändert.

**Trotzdem anzeigen:** `/fbp forceload` eintippen. Die Anzeige startet sofort, ohne `/reload`, und die Einstellung bleibt für diesen Charakter gespeichert (`HealBox.ForceLoad`). Derselbe Befehl schaltet sie wieder aus. Bei jeder anderen Klasse antwortet `/fbp forceload` nur, dass es nicht nötig ist.

Solange das Addon ruht, antworten alle anderen `/fbp`-Befehle mit demselben Hinweis, denn es ist nichts aufgebaut, worüber sie berichten könnten.

Erkannt wird über das englische Klassen-Token des Clients (`WARRIOR`, `ROGUE`, `HUNTER`), mit Rückfall auf den angezeigten Klassennamen in fünf Sprachen, damit die Sperre auch auf lokalisierten Clients greift.

---

## Die Anzeige

Zehn Namensplaketten in zwei Familien. `FBHealBox1` ist immer der Spieler selbst, `FBHealBox2` bis `FBHealBox5` sind `party1` bis `party4`. `FBHealBoxPet1` bis `FBHealBoxPet5` sind die zugehörigen Begleiter (`pet`, `partypet1` bis `partypet4`). Jede zeigt Name, Lebensprozent und einen mehrschichtigen Balken. **Verschieben:** mit gehaltener **Shift**-Taste eine beliebige Plakette mit der linken Maustaste ziehen, die anderen hängen daran und folgen. Die Position wird pro Charakter gespeichert und übersteht den Reload; ein Wechsel der Skalierung verschiebt die Platte nicht.

Gestapelt wird in der Reihenfolge **Besitzer, darunter sein Begleiter**: du, dein Pet, party1, das Pet von party1 und so weiter. Leere Plätze fallen weg: Eine Gruppe mit einem einzigen Jäger zeigt sechs Plaketten, nicht zehn. Der Abstand zwischen den Plaketten ist die Option *Zeilen-Abstand*.

### Klick auf eine Plakette

Ein **Linksklick** auf Name oder Lebensbalken visiert die Einheit an; ein **Rechtsklick** ebenfalls. Beides ist im Reiter *Allgemein* belegbar (*Linksklick auf Plakette* / *Rechtsklick auf Plakette*): **Anvisieren**, **Einheitenmenü** (Blizzards eigenes Menü mit Flüstern, Einladen, Befördern, Verlassen, für Spieler und den eigenen Begleiter; Gruppen-Begleiter fallen auf Anvisieren zurück), **Anzeige verschieben** (Ziehen ohne Shift) oder **Nichts**. Shift + Linksklick ziehen verschiebt die Anzeige immer, egal was eingestellt ist. Im Testmodus geben Klicks auf Geister nur eine Chatmeldung.

### Wer wird angegriffen

Hat dein aktuelles feindliches Ziel ein Gruppenmitglied im Ziel, bekommt dessen Plakette (und Raid-Zelle) einen **roten Rahmen**, fünfmal je Sekunde aus `targettarget` aufgefrischt. Rot hat Vorrang vor dem orangen Buff-Wache-Rahmen. Option *Angegriffenen markieren*.

### Sichtlinie

Solange eine Einheit außerhalb deiner Sichtlinie ist, sitzt ein **Augen-Abzeichen** (`FBLOS_ICON`, das Blenden-Icon) auf der linken oberen Ecke ihrer Plakette. Vanilla hat dafür keine API, deshalb zwei Wege: Ist der Client-Mod **UnitXP SP3** installiert, fragt das Addon alle halbe Sekunde `UnitXP("inSight", "player", unit)` ab, live und exakt. Ohne ihn achtet das Addon auf die Fehlermeldung *nicht in Sichtlinie* nach einer eigenen Heilung und markiert die Einheit, die du heilen wolltest, für `FBLOS_TIMEOUT` (8) Sekunden; die Markierung verschwindet, sobald ein Cast auf sie startet oder eine eigene Heilung bzw. ein HoT-Tick dort ankommt. `/fbp` zeigt, welcher Weg aktiv ist. Option *Sichtlinie*; Position des Abzeichens über `FBLOS_ICON_X/Y`.

### Begleiter

Jeder Begleiter in der Gruppe bekommt eine eigene Plakette mit dem vollen Satz Zauber-Buttons: die Katze des Jägers oder den Leerwandler des Hexers heilt man mit einem Klick, genau wie einen Spieler. Pet-Plaketten kommen und gehen mit `UNIT_PET` (Beschwören, Wegschicken, Tod). Drei Merkmale unterscheiden sie: Sie sind unter ihrem Besitzer um `FBPET_INDENT` (12) px **eingerückt** und um denselben Betrag schmaler, damit die Buttons bündig bleiben, ein **Pfoten-Icon** (`FBPET_ICON`) steht vor dem Namen, und der Name ist **hellblau**. Jägerbegleiter laufen auf Fokus, Hexerbegleiter auf Mana; nur letztere bekommen einen Manabalken. Die Option *Begleiter anzeigen* blendet die ganze Familie aus.

### Balkenaufbau

Vier Statusbalken liegen deckungsgleich übereinander, geregelt über feste Ebenen (`FBHealBox_SetBarStrata`). Ganz oben der schmale Manastreifen, dann der Lebensbalken, deckend; darunter der Schild, ganz unten die Heilvorhersage:

|Schicht|Farbe|Bedeutung|
|-|-|-|
|Mana|blau, 5 px am unteren Rand|Aktuelles Mana, Balken im Balken. Nur bei Einheiten mit Powertyp Mana|
|Leben|grün / gelb / rot, deckend|Aktuelle HP. Grün über 60 %, gelb 30 bis 60 %, rot darunter|
|Schild|hellblau, 50 %|Verbleibender Absorb, direkt hinter den aktuellen HP|
|Vorhersage|hellgrün, 50 %|Eingehende Heilung, hinter dem Schild-Anteil|

Alles wird am Balkenende abgeschnitten: Ein Schild über der Maximal-HP bleibt unsichtbar, die Skala bleibt maßstabsgetreu.

### Manabalken

Der Manabalken ist `FBMANA_BAR_HEIGHT` (5) Pixel hoch und liegt auf der Unterkante des Lebensbalkens. Wo Mana fehlt, scheint ein dunkler, halbtransparenter Streifen durch (`FBMANA_BG_ALPHA`, 0.35, auf 0 setzen, wenn unerwünscht). Er erscheint nur, wenn der **Powertyp der Einheit Mana** ist (`UnitPowerType() == 0`): Krieger, Schurken, Jägerbegleiter und Druiden in Katzen- oder Bärengestalt bekommen keinen Streifen, der Lebensbalken ist dann auf voller Höhe zu sehen. Der Balken folgt `UNIT_MANA`, `UNIT_MAXMANA` und `UNIT_DISPLAYPOWER`. Die Option *Manabalken* schaltet ihn ganz ab.

Mit *Wut, Energie, Fokus zeigen* ist der Streifen nicht mehr dem Mana vorbehalten: Jede Einheit bekommt ihre eigene Ressource in der gewohnten Farbe aus `FBPOWER_COLORS` (Mana blau, Wut rot, Fokus orange, Energie gelb). Druiden, die die Gestalt wechseln, wechseln über `UNIT_DISPLAYPOWER` die Farbe mit, wie bei jeder anderen Änderung des Powertyps. Standardmäßig aus, denn für einen Heiler ist ein leerer Streifen beim Krieger auch eine Information: Da ist nichts, was du auffüllen könntest.

### Dispel-Färbung

Hat jemand einen Debuff, den **deine** Klasse entfernen kann, färbt sich sein Lebensbalken in der Debuff-Farbe statt nach HP-Stand:

|Klasse|Erkannte Typen|
|-|-|
|Priester|Magie (blau), Krankheit (braun)|
|Paladin|Magie, Gift (grün), Krankheit|
|Schamane|Gift, Krankheit|
|Druide|Fluch (violett), Gift|

Die Schwellwerte für die HP-Farben stehen als `LowHP` (0.6) und `VeryLowHP` (0.3) am Dateianfang.

---

## Die Zauber-Buttons

Rechts neben jeder Plakette liegen bis zu zehn Buttons, jeder mit dem Icon seines Zaubers. Ein **Linksklick** wirkt den Zauber auf genau dieses Gruppenmitglied, unabhängig davon, wen du gerade im Ziel hast.

**Belegen per Drag & Drop.** Zauberbuch öffnen, einen Zauber ziehen und auf einen beliebigen Heil-Button, einen Raid-Mini-Button oder ein Feld im Reiter *Buttons* fallen lassen; diese Buttonnummer übernimmt den Zauber auf allen Plaketten. Ist der Rechtsklick-Zauber aktiv, füllt ein Ablegen mit der rechten Maustaste oder mit gehaltener Shift-Taste die Rechtsklick-Seite. Auch Zauber außerhalb der Klassenliste (etwa Magie bannen) werden angenommen und behalten ihr Icon über einen Reload. Vanilla hat kein `GetCursorInfo()`, deshalb merkt sich das Addon, was `PickupSpell` zuletzt an den Cursor gehängt hat.

**Rechtsklick-Zauber (optional).** Jeder Button kann einen zweiten Zauber für **Rechtsklick** tragen (etwa Blitzheilung links, Große Heilung rechts), was die Anzeige verdichtet, ohne Buttons hinzuzufügen. Das ist standardmäßig aus und wird ausschließlich über den Schalter im Reiter *Buttons* eingeschaltet. Eingeschaltet erscheint eine zweite Spalte in der Belegung, und ein kleines Icon unten rechts auf jedem Button zeigt seinen Rechtsklick-Zauber; der Tooltip nennt ihn ebenfalls. Ausschalten behält die Belegung, die Buttons reagieren nur nicht mehr auf Rechtsklick.

**Smart Healing (standardmäßig aus).** Mit *Smart Healing* wirkt ein Klick den niedrigsten Rang des belegten Zaubers, dessen erwartete Heilung das fehlende Leben des Ziels abzüglich schon eingehender Heilung plus *Sicherheitsaufschlag* (Standard 20 %) deckt. Die erwartete Heilung stammt aus den gelernten Werten der Vorhersage, wo vorhanden, sonst aus dem Tooltip-Mittelwert. Nie über dem belegten Rang, nur für Direktheilungen, und unter 30 % Leben immer der belegte Rang. **Zauber mit Heilung über Zeit werden nie abgerangt**, egal welcher Klasse: Erneuerung, Verjüngung, Nachwachsen, Gelassenheit, Lebensblüte, Wildwuchs, Springflut und Erdschild gehen immer im belegten Rang raus. Ein HoT verteilt seine Heilung über viele Sekunden, das im Moment des Klicks fehlende Leben sagt also nichts darüber aus, welcher Rang passt, und ein abgerangter HoT tickt die volle Laufzeit zu schwach. Gemischte Zauber wie Nachwachsen zählen ebenfalls als HoT. Schilde und Buffs wie Seelenstärke gehen genauso wie belegt raus, und ein Zauber kommt überhaupt nur in Frage, wenn sein Tooltip eine Heilung beschreibt.

**Ein laufender HoT zählt nicht als eingehende Heilung.** Abgezogen wird nur, was gleich ankommt: Direktheilungen und über HealComm gemeldete Zauber, also ein bis drei Sekunden. Die offene Restheilung eines tickenden Erneuerung bleibt außen vor. Sie voll anzurechnen ließe den Fehlbetrag winzig aussehen und machte aus einem Heilen Rang 4 ein Geringes Heilen, obwohl das Ziel jetzt Leben braucht und nicht in einer Viertelminute. Auf dem Balken wird der HoT weiterhin angezeigt, er geht nur nicht in die Rangwahl ein.

**Heilketten (neu in 1.4.4.3).** Abgerangt wird nicht nur innerhalb des belegten Zaubers. Innerhalb einer *Heilkette* darf auch der Zauber selbst wechseln, ein Klick auf Große Heilung kann also als Geringes Heilen Rang 3 rausgehen, wenn das den Fehlbetrag deckt. Die Ketten enthalten die Einzelziel-Direktheilungen einer Klasse:

|Klasse|Kette|
|-|-|
|Priester|Geringes Heilen · Heilen · Große Heilung|
|Paladin|Blitz des Lichts · Heiliges Licht|
|Schamane|Geringe Welle der Heilung · Welle der Heilung|
|Druide|Heilende Berührung (Nachwachsen ist ein HoT und bleibt draußen)|

Alles in der Kette ist Kandidat, gewonnen hat der mit der kleinsten erwarteten Heilung, die den Bedarf noch deckt. Nie gewählt wird etwas, das mehr heilt als der belegte Rang, der Button wird also nie stärker, nur billiger. Das kann die Zauberzeit ändern: Bei kleinem Fehlbetrag wird aus einem Klick auf Große Heilung ein Geringes Heilen, aus Heiligem Licht ein Blitz des Lichts. Gruppenheilungen (Gebet der Heilung, Kettenheilung), HoTs, Schilde und Zauber mit Abklingzeit (Heiliger Schock, Handauflegung) sind nie Teil einer Kette.

Der Schalter *Smartcross* im Reiter *Buttons* schaltet den Kettenwechsel aus und wieder ein, `/fbp smartcross` tut dasselbe aus dem Chat. Aus bleibt Smart Healing beim belegten Zauber und senkt nur dessen Rang, so wie es vor 1.4.4.3 war. Die Ketten stehen in `FBHealChains` direkt beim Smart-Healing-Code und lassen sich frei bearbeiten; Zauber, die nicht getauscht werden sollen, fliegen einfach aus der Liste. Nachteile: Die Schätzung kennt keine Crits, und bei Schadensspitzen oder gewolltem Überheilen (Tank vor einem großen Treffer) kann der kleinere Rang zu wenig sein. Aus lassen, wann immer Overheal gewollt ist. `/fbp debug` zeigt jede Entscheidung, `/fbp` den Zustand.

**Cooldowns.** Jeder Button zeigt die gewohnte Cooldown-Uhr seines Zaubers, den globalen Cooldown eingeschlossen: Nach jedem Zauber läuft die kurze Wartezeit auf allen Buttons ab, so wie es die Aktionsleisten machen.

Was der globale Cooldown auf keinen Fall tun darf, ist die Symbole abdunkeln. Solange er läuft, meldet der Client jeden Zauber als nicht nutzbar, wörtlich genommen würden also nach jedem einzelnen Zauber alle Buttons anderthalb Sekunden grau und dann schlagartig wieder hell. Deshalb sind es zwei getrennte Schwellen: `FBCD_SHOW_MIN` (0) entscheidet, ab welcher Länge die Uhr läuft, `FBCD_MIN_DURATION` (2) die Länge, bis zu der eine Abklingzeit nicht als Grund zum Abdunkeln gilt. Wer `FBCD_SHOW_MIN` auf 2 setzt, hat den globalen Cooldown wieder aus der Anzeige. Option *Cooldowns auf den Buttons*.

**HoT- und Schild-Timer.** Der Button eines Zaubers zeigt für seine Einheit die Restsekunden deines eigenen HoTs (grün) oder Schilds (blau) dieses Zaubers. Ist Machtwort: Schild verbraucht, zeigt derselbe Button rot die Geschwächte Seele, bis das Ziel wieder schildbar ist. Geprüft wird zuerst der Linksklick-Zauber, dann der Rechtsklick-Zauber. Nur eigene Effekte werden verfolgt. Option *HoT- und Schild-Timer*.

**Buff-Icons links am Balken.** Buffs mit Laufzeit, die auf deinen Buttons liegen (Seelenstärke, Göttlicher Willen, Furchtzauberschutz, Inneres Feuer, links oder rechts), erscheinen als kleine 8-px-Icons **außen links** neben der Plakette, solange der Buff wirkt, in Zweierstapeln: das erste oben an der Platte, das zweite darunter, das dritte oben in der nächsten Spalte links, und so weiter. Die Restlaufzeit wird visuell in **32 feinen Stufen** (`FBBUFFICON_STEPS = 32`) dargestellt: Mit ablaufender Zeit wird das Icon von oben nach unten schrittweise schwarz-weiß entsättigt und abgedunkelt. Frischer Buff: ganz farbig. Halbe Zeit übrig: obere Hälfte grau. Ein Viertel übrig: obere drei Viertel grau. Diese 32-Stufen-Darstellung bietet eine deutlich höhere Präzision (bei einem 30-Minuten-Buff aktualisiert sich die Anzeige ca. alle 56 Sekunden statt nur alle 7,5 Minuten) und spart gleichzeitig Ressourcen durch den Einsatz einer einzelnen dynamisch beschnittenen Overlay-Textur (`ic.qTex`) und Abdunklung (`ic.wTex`). Mouseover auf ein Icon zeigt Buffname und Restzeit. Die Restzeit ist bei dir selbst exakt (Buff-API, bei jedem `PLAYER_AURAS_CHANGED` und dazwischen einmal je Sekunde neu gelesen, weil ein Refresh eines laufenden Buffs kein Event feuert; ein Neucast stellt die Uhr also zurück) und wird bei anderen ab deinem eigenen Cast gezählt; ein fremd gewirkter Buff bleibt ganz farbig (Zeit unbekannt). Bis zu sechs Icons je Plakette (`FBBUFFICON_MAX`). Option *Buff-Icons links am Balken*, standardmäßig an. Die Raid-Zellen zeigen dieselben Icons außen an ihrer linken Kante mit 6 px in einem 3-mal-4-Raster (zwölf Plätze, Spalten füllen sich von der Zelle nach außen), das Raster hält zwischen den Gruppen Platz dafür frei. Nach einem `/reload` oder Gruppenwechsel scannt das Addon alle Einheiten einmal aktiv, damit vorhandene Buffs sofort erscheinen und nicht erst beim nächsten Aura-Event. `/fbp buffs` listet die verfolgten Buffs und ihren Zustand auf dir.

**Tot, Geist, Offline.** Statt `0 %` zeigt der Balken *Tot*, *Geist* oder *Offline*, leer und grau, ohne Manastreifen.

**Debuff-Icon.** Trägt eine Einheit einen Debuff, den deine Klasse entfernen kann, erscheint sein Icon rechts neben dem Namen mit Stackzahl (ab 2). Der Lebensbalken nimmt wie bisher die Debuff-Farbe an.

Der Icon-Rand färbt sich mit:

|Icon|Zustand|
|-|-|
|Normal|Zauber wirkbar|
|Bläulich|Nicht genug Mana|
|Dunkelgrau|Nicht wirkbar (Cooldown, Voraussetzung fehlt)|
|Rötlich|Ziel außer Reichweite|

Beim Überfahren erscheint der komplette Zaubertooltip plus die Zeile *Heal Box Vanilla Ziel: `<Name>`*, damit klar ist, wen dieser Button bedient.

---

## Raidmodus

Der Raidmodus ist ein Addon im Addon: Er lebt in der eigenen Datei `FBHealBox_Raid.lua`, hängt sich nur über `FBHealBox_RegisterHook` und `FBHealBox_AddOptionsTab` in den Kern ein und ist standardmäßig an. Er tut nichts, bis er gebraucht wird: Das Raster erscheint von selbst, sobald du in einem Schlachtzug mit **mindestens 11 Spielern** bist (*Raid-Ansicht ab N Spielern*, einstellbar von 2 bis 40); kleinere Raids behalten die Gruppenanzeige, die deine eigene Untergruppe zeigt. Der Schalter *Raidmodus* ist nur ein Notaus. Alles oben Beschriebene funktioniert unverändert weiter.

**Modul installieren:** `FBHealBox_Raid.lua` muss neben `FBHealBox.lua` liegen, die `.toc` muss sie auflisten (die mitgelieferte tut das), und der Spielclient muss einmal **neu gestartet** werden. Ein `/reload` übernimmt keine neu in eine `.toc` eingetragenen Dateien. Ist das Modul aktiv, steht beim Login *Raidmodus-Modul geladen* im Chat, und das Optionsfenster zeigt einen dritten Reiter.

### Was er zeigt

Erreicht der Raid die Schwelle, erscheint ein kompaktes **Raster**: eine **Zelle** je Mitglied, in **Fünferblöcken** nach Gruppe geordnet, die Blöcke in Zeilen. Jede Zelle (standardmäßig 70 mal 22 px) zeigt den Namen in Klassenfarbe, den Lebensbalken mit denselben Schild- und Vorhersage-Schichten wie die Plaketten, einen 3 px hohen Manastreifen bei Mana-Nutzern, die Lebensprozente oder die fehlenden Lebenspunkte, die Dispel-Färbung, *Tot* / *Geist* / *Offline*, das Reichweiten-Fading, das Sichtlinien-Auge und den orangen Buff-Wache-Rahmen. Rechts an jeder Zelle sitzen bis zu vier **Mini-Buttons**, die die Zauber von Button 1 bis N aus dem Reiter *Buttons* wirken, Rechtsklick-Zauber inklusive. Ein Klick auf die Zelle selbst tut, was *Linksklick auf Plakette* / *Rechtsklick auf Plakette* vorgibt (Standard Anvisieren; das Einheitenmenü kommt aus Blizzards Raid-Fenster).

Die Gruppenblöcke stehen mit *Gruppen je Zeile* (Standard 4) im Raster: Ein 40er-Raid sind zwei Zeilen zu vier Blöcken, etwa 570 mal 270 px bei zwei Buttons je Zelle und dem Streifen für die Buff-Icons. **Leere Gruppen brauchen keinen Platz**, ein 20er-Raid ist also eine einzige Zeile. Das ganze Raster skaliert unabhängig von den Plaketten und merkt sich seine Position.

Solange das Raster zu sehen ist, werden die fünf Gruppenplaketten ausgeblendet (Option *Gruppenplaketten im Raid ausblenden*), damit der Bildschirm nie doppelt belegt ist.

### Reiter *Raidmodus*

|Einstellung|Wirkung|
|-|-|
|Raidmodus|Hauptschalter (Notaus). Standardmäßig an|
|Raid-Ansicht ab N Spielern|Schwelle für den Wechsel von der Gruppenanzeige zum Raster. Standard 11, also mehr als 10 Spieler|
|Gruppenplaketten im Raid ausblenden|Gruppenanzeige verstecken, solange das Raster steht. An|
|Gruppenköpfe|Gruppennummer über jedem Block. An|
|Manastreifen|3 px Manabalken in der Zelle. An|
|Leere Gruppen ausblenden|Gruppen ohne Mitglieder fallen weg. An|
|Titelleiste|Schmale Leiste über dem Raster zum Ziehen. Ohne sie: Shift + eine beliebige Zelle ziehen. An|
|Buffs anzeigen|Buff-Icons mit Uhr links an jeder Zelle. Aus: keine Icons und kein reservierter Streifen, die Gruppen rücken enger zusammen. An|
|HP-Text|keiner, Prozent oder Defizit (fehlende Lebenspunkte als negative Zahl)|
|Raid-Test|Füllt das Raster mit 20 oder 40 Geistern: tot, offline, Geist, Magie- und Krankheits-Debuff, außer Reichweite, außer Sicht, fehlender Buff, Schild, eingehende Heilung und Buff-Icons (jeder dritte Geist, Geist 12 mit zwölf) sind alle vertreten. Wird nicht gespeichert|
|Gruppen je Zeile|1 bis 8. Standard 4|
|Raid-Skalierung|0.5 bis 1.5|
|Zellenbreite / -höhe|50 bis 120 px / 14 bis 32 px|
|Buttons je Einheit|0 bis 4 Mini-Buttons. Standard 2|
|Buttongröße|12 bis 28 px|
|Zellenabstand / Gruppenabstand|0 bis 10 px / 0 bis 20 px|

Alle Raid-Einstellungen liegen in `HealBox.Raid`. `/fbp raidtest 20`, `/fbp raidtest 40` und `/fbp raidtest off` schalten den Raid-Test aus der Chatzeile; `/fbp` meldet den Raid-Zustand.

### Wie er andockt

Der Kern bietet `FBHealBox_RegisterHook(name, fn)` und ruft die Hooks an festen Stellen: `Defaults`, `SyncOptions`, `ApplyLocale`, `UpdateNames`, `RefreshAllBars`, `ButtonsChanged`, `ActiveToggle`, `Status`, `Slash`, `Loaded`, `Aggro`, `SpellTimers` und `Cooldowns`. `FBHealBox_AddOptionsTab(labelKey)` legt einen Reiter im Optionsfenster an. Das Raid-Modul hängt sein Roster-Update an `UpdateNames`, sein Zellen-Update an `RefreshAllBars` (so erreicht die Heilvorhersage die Raid-Zellen ohne Zusatzaufwand) und seine Slash-Befehle an `Slash`. Die Raid-Einheiten werden in `FBPredictUnits` eingetragen, damit die HoT- und Schild-Bestätigung über `UNIT_AURA` auch für `raid1` bis `raid40` greift. Begleiter werden im Raidmodus nicht angezeigt.

---

## Mana-Ticker

Der Mana-Ticker lebt im eigenen Modul `FBHealBox_Ticker.lua` und ist standardmäßig an. Ein **Funke** wandert alle 2 Sekunden über den Manastreifen deiner eigenen Plakette (und deiner eigenen Zelle im Raid-Raster), im Takt des Regenerationsticks des Servers. Gibst du Mana aus, wird der Funke **orange** und läuft die Fünf-Sekunden-Regel herunter; er erreicht das Ende genau dann, wenn die Willenskraft-Regeneration wieder einsetzt, also am ersten Tick nach den fünf Sekunden, nicht nach den fünf Sekunden selbst. Wer direkt nach dem Funken am Ende castet, verschenkt keine Regeneration.

### Wie er arbeitet

In 1.12 gibt es dafür keine API, deshalb beobachtet das Modul `UNIT_MANA` für den Spieler. Sinkendes Mana startet die Fünf-Sekunden-Regel. Steigendes Mana ist ein Tick-Kandidat: Der erste setzt das 2-s-Raster, jeder spätere, der innerhalb der *Tick-Toleranz* um den erwarteten Zeitpunkt liegt, synchronisiert es neu. Kandidaten außerhalb der Toleranz (Manaquelle-Pulse, Anregen) werden ignoriert; erst nach drei Fehlschlägen in Folge gilt ein neues Raster. Sprünge ab 300 Mana und mehr als dem Vierfachen der gelernten Tickgröße (Tränke, Runen) zählen nie. Bei vollem Mana kommen keine Ticks, das Raster läuft dann still weiter und der Funke bleibt ausgeblendet, bis wieder Mana fehlt; am nächsten echten Tick synchronisiert er sich neu. Der Funke braucht den Manastreifen (Option *Manabalken*) und verschwindet in Bären- oder Katzengestalt.

### Reiter *Extras*, Abschnitt *Mana-Ticker*

|Einstellung|Wirkung|
|-|-|
|Mana-Ticker|Hauptschalter. Standardmäßig an|
|Fünf-Sekunden-Regel|Orange Phase nach Manaverbrauch anzeigen. An|
|Tick-Toleranz|0.1 bis 0.6 s. Erhöhen, wenn Ticks verpasst werden|
|Tick-Vorlauf|0.0 bis 0.5 s. Lässt den Funken früher loslaufen, um Latenz auszugleichen, falls er später ankommt als deine Manasprünge|
|Funkenbreite|1 bis 4 px|

`/fbp ticker` schaltet den Ticker um; `/fbp` meldet, ob das Raster synchron ist, die Zeit bis zum nächsten Tick und eine laufende Fünf-Sekunden-Regel. Einstellungen liegen in `HealBox.Ticker`. Der Ticker teilt sich den Reiter *Extras* mit Smart Damage.

---

## Smart Damage

Rangwahl für **Angriffszauber auf jeder Aktionsleiste**, im eigenen Modul `FBHealBox_Damage.lua`, **standardmäßig aus**. Drückst du Göttliche Pein Rang 4 auf einer Bongos- oder Blizzard-Leiste (oder deren Tastenkürzel) und Rang 2 würde das Ziel noch töten, wird Rang 2 gewirkt. Nie über dem Rang auf der Leiste.

### Wie es arbeitet

Jede Leiste und jedes Tastenkürzel endet in `UseAction(slot)`. Das Modul hängt sich davor, liest Zauber und Rang im Slot per Tooltip-Scan und entscheidet. Der Schaden je Rang ist der **Mindestschaden** aus dem Tooltip („86 to 98 Holy damage"), angehoben durch den kleinsten Volltreffer, den du mit diesem Rang tatsächlich gelandet hast (Crits und Teilwiderstände zählen nicht). Ein Rang kommt in Frage, wenn sein Mindestschaden das Restleben des Ziels plus *Sicherheitsaufschlag* (Standard 20 %) deckt. Makros mit `/cast` bleiben unberührt.

Das Restleben des Ziels liefert die erste Quelle, die antwortet:

|Quelle|Wann|Genauigkeit|
|-|-|-|
|Server|`UnitHealthMax("target")` ist nicht 100, der Server sendet also echte Werte (Turtle WoW und andere)|exakt|
|MobHealth3|`MobHealth3:GetUnitHealth()` kennt den Mob|so gut wie dieses Addon|
|MobInfo-2|`MobHealth_GetTargetCurHP()` kennt den Mob|so gut wie dieses Addon|
|Eigene Schätzung|Das Addon hat diesen Mobtyp (Name und Stufe) schon einmal bekämpft|siehe unten|

**Eigene Schätzung.** Auf reinen Prozent-Servern lernt das Addon je Mobtyp die *Lebenspunkte je Prozent*: Es summiert den Schaden, den es im Combatlog sieht (deinen, den deiner Gruppe, den der Begleiter), und teilt durch den Prozentabfall des Ziels, aber erst ab 3 % Abfall, damit die Rundung auf ganze Prozent nicht stört. Von allen Messungen bleibt die **höchste**, weil Schaden von Raidmitgliedern außerhalb deiner Gruppe unsichtbar ist und die Schätzung sonst nach unten zöge; ein zu hoher Wert kostet nur einen etwas größeren Rang. Das Restleben ist dann die Obergrenze des aktuellen Prozentwerts mal diesem Faktor. Die Schätzung wird je Charakter in `HealBox.MobHP` gespeichert und wird mit jedem Kampf besser; bis ein Typ vermessen ist, lässt Smart Damage dieses Ziel in Ruhe.

### Abschnitt *Smart Damage* im Reiter *Extras*

|Einstellung|Wirkung|
|-|-|
|Smart Damage|Hauptschalter. Standardmäßig aus|
|Sicherheitsaufschlag|0 bis 50 %, Standard 20. Deckt Teilwiderstände und Schätzfehler|
|Lebensquelle des Ziels|Livezeile: welche der vier Quellen für dein aktuelles Ziel antwortet|
|Zauber|Die im Zauberbuch gefundenen Angriffszauber mit Rangzahl|

Zauber je Klasse: Priester Göttliche Pein, Heiliges Feuer, Gedankenschlag; Druide Zorn, Sternenfeuer, Mondfeuer; Schamane Blitzschlag, Kettenblitzschlag, Erd-/Flammen-/Frostschock; Paladin Heiliger Schock, Hammer des Zorns, Exorzismus, Heiliger Zorn; Magier Feuerball, Frostblitz, Feuerschlag, Versengen, Pyroschlag; Hexenmeister Schattenblitz, Sengender Schmerz, Feuerbrand, Seelenfeuer, Feuersbrunst; Jäger Arkaner Schuss, Gezielter Schuss (Liste `FBDamageSpells`). `/fbp damage` schaltet um, `/fbp debug` protokolliert jede Entscheidung mit der genutzten Lebensquelle. Hinweis für Jäger: Für diese Klasse lädt das Addon nicht, Smart Damage läuft also erst nach `/fbp forceload`, siehe [Für welche Klassen es lädt](#für-welche-klassen-es-lädt).

---

## Optionsfenster

Zu öffnen über den **Minimap-Button**:

|Bedienung|Wirkung|
|-|-|
|Linksklick|Optionsfenster auf/zu|
|Shift + Linksklick|Gesamte Anzeige ein-/ausblenden|
|Rechts halten und ziehen|Minimap-Button verschieben|

Das Fenster hat zwei Reiter.

### Reiter *Buttons*

**Button 1 bis 10**: je eine Zeile mit dem Feld *Linksklick* (Icon und Zaubername). Klick auf ein Feld öffnet das Zauber-Menü (siehe unten). Die Belegung wird pro Charakter gespeichert.

**Rechtsklick-Zauber**: schaltet den zweiten Zauber je Button ein und blendet die Spalte *Rechtsklick* neben der linken ein. Standardmäßig aus.

**N Buttons anzeigen**: wie viele der zehn Buttons tatsächlich erscheinen (0 bis 10). Belegte, aber ausgeblendete Buttons behalten ihre Zuordnung.

**Smart Healing / Sicherheitsaufschlag**: siehe [Die Buttons](#die-buttons). Standardmäßig aus; Aufschlag 0 bis 50 %, Standard 20.

**Smartcross**: erlaubt Smart Healing das Wechseln des Zaubers innerhalb einer Heilkette. Ausgegraut und gesperrt, wenn Smart Healing deaktiviert ist; standardmäßig an.

### Reiter *Allgemein*

**Skalierung**: Skalierung der Plaketten von 0.6 bis 1.5. Wirkt nicht im Party-Frame-Modus.

**Button-Abstand**: Luft zwischen den Zauber-Buttons (und zwischen Plakette und erstem Button), 0 bis 20 px. Standard 2.

**Zeilen-Abstand**: senkrechter Abstand der Plaketten zueinander, 0 bis 20 px. Standard 4. Zusammen mit dem Button-Abstand lässt sich die ganze Anzeige damit deutlich kompakter schieben.

**Standard-Gruppenfenster**: statt eigener Plaketten hängen die Buttons an Blizzards Standard-Gruppenfenstern (`PartyMemberFrameN`); die Pet-Buttons an `PetFrame` bzw. `PartyMemberFrameNPetFrame`. Die eigenen Namensplaketten und Balken werden dabei ausgeblendet; die Heilvorhersage arbeitet unsichtbar weiter.

**Balkenhintergrund**: wie deckend die Fläche hinter den Balken liegt, 0 bis 100 Prozent in Fünferschritten. Standard 0, also das bisherige Bild: Wo Leben fehlt, scheint die Spielwelt durch die Plakette. Hochgedreht liegt eine ruhige dunkelgraue Fläche hinter den Balken (`FBBAR_BG_COLOR`), das Grün des Lebensbalkens steht dann auf festem Grund statt auf Gras, Himmel oder Stein. Bei 100 ist die Plakette undurchsichtig. Angeregt von einem Nutzer, dem der durchscheinende Balken schlecht lesbar war, und einen Versuch wert für alle mit hellem Bildschirm oder unruhiger Umgebung.

**Manabalken**: Manastreifen im Lebensbalken an/aus. Standardmäßig an.

**Blizzard-Gruppenfenster aus**: versteckt `PartyMemberFrame1` bis `4`, solange du in einer Gruppe bist, sodass nur die Plaketten der Heal Box übrig bleiben. Standardmäßig aus. Diese Option und *Standard-Gruppenfenster* können nie beide an sein, weil der Anheftmodus die Plaketten genau an diese Frames hängt; was angehakt ist, graut das andere aus. Ausschalten holt die Frames sofort zurück, und eine Klasse, für die das Addon nicht lädt, bekommt sie ebenfalls zurück.

**Wut, Energie, Fokus zeigen**: der Manastreifen bleibt normalerweise leer bei allen ohne Mana. Eingeschaltet zeigen Krieger, Schurken und Begleiter ihre eigene Ressource in der gewohnten Farbe (Wut rot, Energie gelb, Fokus orange, Tabelle `FBPOWER_COLORS`). Setzt den Manabalken voraus. Standardmäßig aus.

**Begleiter anzeigen**: alle Pet-Plaketten an/aus. Standardmäßig an.

**Debuff-Icon**: Debuff-Icon mit Stackzahl neben dem Namen an/aus. Standardmäßig an.

**Sichtlinie**: Augen-Abzeichen für Einheiten außerhalb der Sichtlinie an/aus (siehe [Sichtlinie](#sichtlinie)). Standardmäßig an.

**Angegriffenen markieren**, **HoT- und Schild-Timer**, **Cooldowns auf den Buttons**, **Buff-Icons links am Balken**: die Anzeigen aus [Die Buttons](#die-buttons) und [Wer wird angegriffen](#wer-wird-angegriffen). Alle standardmäßig an.

**Linksklick auf Plakette / Rechtsklick auf Plakette**: was ein Klick auf eine Plakette tut: Anvisieren (Standard), Einheitenmenü, Anzeige verschieben, Nichts. Siehe [Klick auf eine Plakette](#klick-auf-eine-plakette).

**Testmodus**: füllt die Plätze 2 bis 10 mit Geisterspielern und -begleitern, damit du die Anzeige ohne Gruppe einrichten kannst (siehe [Testmodus](#testmodus)). Wird nicht gespeichert; nach dem Login immer aus.

**Klassenfarben**: färbt den Namen auf jeder Plakette in der Klassenfarbe (`RAID_CLASS_COLORS` des Clients, mit eingebauter Ersatztabelle). Begleiter behalten ihren hellblauen Namen. Standardmäßig an.

**Reichweiten-Fading**: blendet eine ganze Plakette samt Buttons auf 50 % ab (`FBRANGE_ALPHA`), wenn die Einheit außer Reichweite ist. Geprüft wird alle halbe Sekunde (`FBRANGE_INTERVAL`) per `IsSpellInRange` mit dem ersten belegten Button-Zauber; ohne belegten Zauber zählt `CheckInteractDistance(4)`, also 28 Meter. Standardmäßig an.

**Buff-Wache**: ein Knopf, der das Kaskadenmenü mit deinen Klassenbuffs öffnet (Seelenstärke, Göttlicher Willen, Mal der Wildnis, Segen, Dornen, Erdschild, …; nur gelernte erscheinen). Jede Plakette, deren Einheit diesen Buff **nicht** trägt, bekommt einen **orangen Rahmen**. Die Gruppenversion zählt mit (Gebet der Seelenstärke für Machtwort: Seelenstärke, Gabe der Wildnis für Mal der Wildnis, Große Segen für Segen), auch wenn ein anderer Heiler sie gewirkt hat: Die Prüfung vergleicht zuerst die Buff-Texturen mit deinen Zauberbuch-Icons und liest erst, wenn das nicht passt, die Buff-Namen per Tooltip-Scan. Geprüft wird bei `UNIT_AURA` und nach jedem Gruppenwechsel, nichts läuft pro Frame. *Keine Buff-Wache* schaltet sie ab. Gespeichert als `WatchBuff`. Begleiter bleiben außen vor, solange *Buff-Wache auch für Begleiter* nicht gesetzt ist.

**Buff-Wache auch für Begleiter**: markiert auch Pets, denen der überwachte Buff fehlt. Standardmäßig aus.

**HealComm-Sync**: Austausch der Heilinformationen mit der Gruppe, siehe [HealComm-Sync](#healcomm-sync). Standardmäßig an.

**Sprache / Language**: schaltet zwischen Deutsch und Englisch um. Der Knopf öffnet dasselbe Kaskadenmenü wie die Zauberwahl. Die Umstellung wirkt **sofort**: `FBHealBox_ApplyLocale()` beschriftet die bereits gebaute Oberfläche neu, ein `/reload` ist nicht nötig. Beim ersten Start entscheidet `GetLocale()`: deutsche Clients starten auf Deutsch, alle anderen auf Englisch. Die Wahl wird pro Charakter gespeichert.

**Fenster verschieben:** am Rahmen ziehen. Schließen über das X oben rechts, mit **Escape** oder per `/fbp config`. Escape wird über einen Hook auf `ToggleGameMenu` abgefangen (zusätzlich zu `UISpecialFrames`), damit es auch auf Clients funktioniert, die diese Liste nicht auswerten; ist Blizzards Spielmenü offen, schließt Escape wie gewohnt zuerst dieses.

## Testmodus

*Testmodus* in den Optionen anhaken oder `/fbp test` eingeben. Die eigene Plakette bleibt echt, jeder andere Platz wird mit einem Geist gefüllt: vier Spieler und drei Begleiter, damit das komplette Layout samt Pets unter ihren Besitzern zu sehen ist. Bist du gerade in einer echten Gruppe, ersetzen die Geister sie, solange der Testmodus an ist.

Die Geister sind so gebaut, dass jeder Anzeigezustand gleichzeitig zu sehen ist:

|Geist|Zeigt|
|-|-|
|Brynn|Krieger: **tot**, kein Manabalken, **fehlender Buff** (oranger Rahmen, sobald eine Buff-Wache gesetzt ist)|
|Cerys|Hexenmeister: Manabalken, einen **Absorb-Schild**-Anteil und das **Sichtlinien**-Abzeichen|
|Dorn|Jäger: wenig Leben (rot) mit **eingehender Heilung** dahinter|
|Elowen|Druide: einen **entfernbaren Debuff** (der Lebensbalken nimmt die Dispel-Farbe deiner Klasse an) und **außer Reichweite** (abgeblendet)|
|Fang, Zorbek, Bramble|Begleiter: ein Fokus-Pet ohne Manabalken, ein Mana-Pet mit, ein Pet mit eingehender Heilung und **Krankheits**-Debuff|

Ihre HP wandern langsam auf und ab, damit man die gelbe und rote Schwelle kommen und gehen sieht. Dorn trägt zusätzlich den roten Angriffsrahmen, Beispiel-Timer auf den Buttons 1 und 2 und **sechs Buff-Icons** mit unterschiedlicher Restzeit (eines ohne Uhr). Zauber-Buttons auf Geistern tun nichts außer einer kurzen Chatmeldung; Tooltips funktionieren. Die Geistertabelle heißt `FBTestGhosts` und steht am Dateianfang; Namen, Werte und Extras lassen sich frei ändern.

Der Testmodus ist für die eigenen Plaketten gedacht; im Party-Frame-Modus sitzen die Geister an Blizzards (ausgeblendeten) Frames und nützen wenig.

---

## Das Zauber-Menü

Ein eigenes Kaskadenmenü, kein `UIDropDownMenu`: Dessen 1.12er Implementierung schließt Untermenüs, sobald die Maus einen Nachbareintrag streift, und erzwingt Haken und Klickgeräusch.

* **Ebene 1** listet alle gelernten Zauber deiner Klasse aus der Zauberliste, jeweils mit Icon.
* **Pfeil rechts** = mehrere Ränge vorhanden. Das Untermenü öffnet **beim Überfahren**, überlappt die Elternliste um zwei Pixel und hat ringsum eine Toleranzzone von 14 Pixeln, damit die Maus auf dem Weg nichts verliert.
* **Offen bleibt offen**: Nur die Auswahl eines Rangs, das Aufklappen eines anderen Untermenüs oder ein Klick daneben schließt es. Nach drei Sekunden ohne Maus in der Nähe greift eine Notbremse (`FBMENU_GRACE_TIME`, auf 999 setzen deaktiviert sie).
* **Kein Zauber** ganz oben leert den Button wieder.

Ausgewählt wird als Cast-String `Zauber(Rank N)`, genau die Form, die `CastSpellByName` erwartet, und die Basis dafür, dass die Vorhersage den exakten Rang kennt.

---

## Heilvorhersage

Der Kern des Addons. Drei unabhängige Quellen speisen die Balken.

### Direktheilung

`SPELLCAST_START` liefert Zaubernamen und Castdauer in Millisekunden, unabhängig davon, ob der Cast vom HealBox-Button, der Aktionsleiste oder aus einem Makro kommt. Es braucht dafür keinen Hook auf `CastSpellByName`. Die Vorschau verschwindet bei `SPELLCAST_STOP`, `_FAILED` und `_INTERRUPTED`, Pushback (`SPELLCAST_DELAYED`) verlängert sie.

Instants bekommen bewusst **keine** Vorhersage: Die Heilung ist da, bevor ein Balken sie zeigen könnte.

### Heilung über Zeit

`UnitBuff()` liefert für fremde Einheiten keine Restlaufzeit, das Addon führt deshalb selbst Buch:

1. Der Button meldet den Cast samt Ziel und Rang vor.
2. `UNIT_AURA` bestätigt die Anwendung über den **Buff-Textur-Vergleich** mit dem Zauberbuch-Icon (locale-unabhängig, kein Tooltip-Scan pro Event).
3. Angezeigt wird `Restticks × Heilung pro Tick`, wobei die Restticks aus `(Ablauf − GetTime()) / Intervall` fallen. Der Balken zählt damit Tick für Tick herunter.
4. Fällt der Buff vorzeitig weg (Dispel, Tod, Überschrieben), ist die Anzeige sofort weg.

HoTs von der Aktionsleiste werden ebenfalls erkannt, dann mit dem höchsten bekannten Rang; der erste Combatlog-Tick zieht den Wert gerade.

Das Tickintervall ist in Vanilla nicht aus dem Tooltip lesbar und steht deshalb in `FBPredictTickInterval` (Standard 3 Sekunden, Lifebloom 1).

### Ausrüstungsbonus

Vanilla-Tooltips zeigen den nackten Grundwert, der Heilbonus deiner Ausrüstung steht nicht darin. Gelernte Werte aus dem Combatlog tragen ihn von selbst, die Lücke gibt es also nur bei Rängen, die du nie gewirkt hast. Liefert eine API den Bonus, schließt das Addon diese Lücke: Der Wert wird wie in Vanilla üblich mit Zauberzeit geteilt durch 3,5 gewichtet und bei 3,5 Sekunden gedeckelt, Instants zählen als 1,5. Eine Große Heilung mit 3 Sekunden Zauberzeit startet bei +700 Heilung also 600 über ihrem Tooltip, eine Blitzheilung mit 1,5 Sekunden 300.

Gesucht wird `GetSpellBonusHealing`, dazu `GetSpellBonusHeal` und `GetHealingBonus`, erst als globale Funktion, dann in einer `ClassicAPI`-Tabelle. **ClassicAPI** bringt das mit; ohne eine solche API bleibt der Bonus 0 und es ändert sich nichts. `/fbp` nennt den gefundenen Wert und ob er angewandt wird, `/fbp healbonus` schaltet ihn ab. Der erste gelernte Wert eines Rangs schlägt die Schätzung immer.

### Absorb-Schilde

Maximaler Absorb aus dem Zauberbuch-Tooltip, Verbrauch aus dem Combatlog (`(123 absorbed)`). Bei `\*_VS_SELF_*`-Events ist das Opfer der Spieler, sonst wird unter den aktuell beschildeten Namen gesucht.

Absorbierst du mehr, als der Tooltip hergibt (Heal-Gear), wird das Maximum **nach oben** korrigiert und gemerkt. Diese Korrektur ist einseitig und damit sicher: Mehr als möglich kann nicht absorbiert worden sein.

Vollständig absorbierte Treffer melden in Vanilla keine Zahl. Der Restwert bleibt dann stehen, bis der Buff fällt und die Anzeige gelöscht wird. Ebenso zählen Absorbs an Gruppenmitgliedern nur, soweit der Combatlog sie überhaupt zeigt; der Aura-Abgleich fängt die Abweichung am Ende wieder ein.

### Selbstkorrektur und Lernspeicher

Tooltips liefern in 1.12 nur Basiswerte **ohne** +Heilung, und eine API für Zaubermacht gibt es nicht. Der Combatlog liefert dagegen die Wahrheit:

|Beobachtung|Wirkung|
|-|-|
|`… gains 194 health from your Renew.`|Setzt die echte Heilung pro Tick für alle Restticks|
|`Your Flash Heal heals Bob for 1240.`|Pendelt die Schätzung ein (50/50-Mittelung)|
|`(342 absorbed)` über dem Maximum|Hebt den angenommenen Schildwert an|

Alles davon landet pro Zauber **und Rang** in `HealBox.PredictMemory` und übersteht den Logout.

Zwei Schutzregeln halten den Speicher sauber. **Crits werden nicht gelernt**: die Crit-Formulierung lässt den Zaubernamen als „Flash Heal critically" durchs Muster fallen, und der steht in keiner Watchlist. Und gelernt wird nur bei **gesichertem Rang**, also bei Casts über die HealBox-Buttons; sonst würde ein Rang-3-Cast von der Aktionsleiste dem Maximalrang zugeschrieben und die Vorhersage nach unten ziehen. Die laufende Anzeige korrigiert sich trotzdem immer, geschützt ist nur der dauerhafte Speicher.

Welcher Zauber was kann, entscheidet der Tooltip selbst; ein Zauber darf mehreres sein. Regrowth etwa liefert Sofortheilung *und* HoT und wird auch so behandelt.

---

## HealComm-Sync

HealComm-1.0 funkt reinen Klartext über `SendAddonMessage` mit dem Prefix `HealComm`. Heal Box Vanilla spricht dieses Protokoll direkt, ohne die Bibliothek einzubinden. Damit sehen Puppeteer, pfUI, Luna Unit Frames, CT_RaidAssist und alles andere HealComm-fähige deine angekündigten Heilungen, und du siehst umgekehrt ihre.

|Nachricht|Bedeutung|
|-|-|
|`Heal/<Ziel>/<Betrag>/<Castzeit ms>/`|Direktheilung startet|
|`Healstop`|Cast abgebrochen|
|`Healdelay/<ms>/`|Pushback|
|`GrpHeal/<Betrag>/<ms>/<Z1>/<Z2>/…`|Gruppenheilung (Prayer of Healing)|
|`GrpHealstop` · `GrpHealdelay/<ms>/`|dito für Gruppenheilung|
|`Renew` · `Reju` · `Regr` `/<Ziel>/<Dauer>/`|HoT angewendet|

Gesendet wird ins Raid, sonst in die Gruppe, sonst gar nicht. Die Beträge sind die selbstkorrigierten Combatlog-Werte, also eher genauer als das, was ein echtes HealComm mit ItemBonusLib schätzt.

Ein paar Feinheiten: Bei erfolgreichem Castende geht **kein** `Healstop` raus; HealComm-Empfänger lassen den Eintrag selbst zur Castzeit auslaufen. Prayer of Healing geht korrekt als `GrpHeal` mit allen Zielen in Reichweite raus. Und ein HoT von der Aktionsleiste wird beim ersten eigenen Combatlog-Tick nachgemeldet, mit der dann noch verbleibenden Laufzeit, denn erst „… from **your** Renew" beweist, dass er von dir stammt.

Beim Empfang werden eigene Nachrichten über den Absendernamen gefiltert, und da HealComm eingehende Heilungen pro Caster ablegt, kann sich nichts doppeln, selbst wenn parallel noch ein echtes HealComm mitfunkt. HoT-Nachrichten tragen nur Laufzeiten und keine Beträge; HealComm zählt sie im eigenen `getHeal` nicht mit, hier passiert dasselbe.

**Absorb-Schilde kennt das Protokoll nicht**: die bleiben lokal.

---

## Slash-Befehle

|Befehl|Wirkung|
|-|-|
|`/fbp`|Statusbericht: alle ausgelesenen Tooltip-Werte je Zauber (Direkt-, HoT- und Schildanteil, gelernte Werte in Klammern), alle gerade laufenden Vorhersagen, der Zustand des HealComm-Sync und die empfangenen Fremdheilungen|
|`/fbp debug`|Live-Ausgabe an/aus. Meldet jeden erkannten Cast, jede Korrektur, jeden Absorb und jede gefunkte Nachricht (`[FBP>]`)|
|`/fbp reset`|Verwirft alle gelernten Werte und liest die Tooltips neu ein|
|`/fbp test`|Testmodus an/aus (wie der Haken in den Optionen)|
|`/fbp config`|Optionsfenster auf/zu (wie der Minimap-Button)|
|`/fbp buffs`|Listet die verfolgten Buff-Zauber, ihre Präsenz und Restzeit auf dir sowie deine rohen Buff-Texturen|
|`/fbp forceload`|Nur für Krieger, Schurke und Jäger: zeigt das Addon trotzdem an oder blendet es wieder aus. Pro Charakter gespeichert|
|`/fbp smartcross`|Smart Healing: Abrangen über Zaubergrenzen innerhalb einer Heilkette an/aus (Standard an)|
|`/fbp healbonus`|Rechnet den Heilbonus der Ausrüstung in die Vorhersage, an/aus. Wirkt nur, wenn eine API den Bonus liefert|
|`/fbp raid`|Raidmodus an/aus|
|`/fbp raidtest 20` · `40` · `off`|Raid-Test mit 20 oder 40 Geistern, oder aus|
|`/fbp ticker`|Mana-Ticker an/aus|
|`/fbp damage`|Smart Damage an/aus|

`/fbp` ist die erste Anlaufstelle, wenn etwas nicht angezeigt wird: Steht ein Zauber dort nicht drin, hat der Tooltip-Parser ihn nicht erkannt und nicht die Anzeige versagt.

---

## Gespeicherte Einstellungen

Alles liegt in der Tabelle `HealBox`, gespeichert **pro Charakter**:

|Schlüssel|Inhalt|
|-|-|
|`SpellChoice[1..10]`|Cast-String je Button, z. B. `Renew(Rank 10)`|
|`MaxButtons`|Wie viele Buttons angezeigt werden|
|`Scale`|Skalierung der Plaketten|
|`AttachMode`|0 = eigene Plaketten, 1 = Standard-Gruppenfenster|
|`Active`|Anzeige ein/aus (Shift + Linksklick auf die Minimap)|
|`ForceLoad`|1 = Anzeige auch für Krieger, Schurke und Jäger, 0 = aus (Standard). Wird mit `/fbp forceload` gesetzt|
|`HealComm`|1 = Sync an, 0 = aus|
|`Locale`|`deDE`, `enUS`, `esES`, `frFR` oder `itIT`|
|`ButtonSpacing`|Abstand der Buttons in px (0 bis 20)|
|`RowSpacing`|Abstand der Plaketten in px (0 bis 20)|
|`ManaBar`|1 = Manastreifen an, 0 = aus|
|`BarBG`|Deckkraft des Balkenhintergrunds in Prozent, 0 bis 100. 0 (Standard) behält das durchscheinende Bild|
|`ShowPets`|1 = Pet-Plaketten an, 0 = aus|
|`SpellChoiceR[1..10]`|Cast-String je Button für Rechtsklick|
|`RightClick`|1 = Rechtsklick-Zauber an, 0 = aus (Standard)|
|`DebuffIcon`|1 = Debuff-Icon an, 0 = aus|
|`LOSIcon`|1 = Sichtlinien-Abzeichen an, 0 = aus|
|`PlateLeft` · `PlateRight`|Klickaktion auf einer Plakette: `target`, `menu`, `move` oder `none`|
|`SmartRank` · `SmartMargin`|Smart Healing an/aus (Standard aus) und Sicherheitsaufschlag in Prozent|
|`SmartCross`|1 = Abrangen darf den Zauber innerhalb einer Heilkette wechseln (Standard), 0 = beim belegten Zauber bleiben. In den Optionen oder mit `/fbp smartcross` schaltbar|
|`PowerBar`|1 = der Balken zeigt auch Wut, Energie und Fokus, 0 = nur Mana (Standard)|
|`HideBlizzParty`|1 = Blizzards Gruppenfenster bleiben versteckt, 0 = unangetastet (Standard). Nie zusammen mit `AttachMode` aktiv|
|`HealBonus`|1 = Heilbonus der Ausrüstung zählt bei ungelernten Rängen (Standard), 0 = nackte Tooltipwerte. `/fbp healbonus`|
|`Cooldowns` · `AggroMark` · `SpellTimers` · `BuffIcons`|Cooldown-Uhr, roter Rahmen für den Angegriffenen, HoT/Schild-Timer, Buff-Icons links am Balken|
|`ClassColors`|1 = Namen in Klassenfarbe, 0 = weiß|
|`RangeFade`|1 = Plaketten außer Reichweite abblenden, 0 = aus|
|`WatchBuff`|Zaubername der Buff-Wache oder nil|
|`BuffWatchPets`|1 = Buff-Wache auch für Pets, 0 = nur Spieler (Standard)|
|`PosX` · `PosY`|Linke obere Ecke der Spielerplakette in Bildschirmpixeln|
|`Ticker`|Untertabelle mit den Mana-Ticker-Einstellungen (siehe [Mana-Ticker](#mana-ticker))|
|`Damage`|Untertabelle mit den Smart-Damage-Einstellungen; `MobHP` und `DmgMemory` halten gelernte Mob-Leben und Mindestschäden (siehe [Smart Damage](#smart-damage))|
|`Raid`|Untertabelle mit allen Raidmodus-Einstellungen (siehe [Raidmodus](#raidmodus)), einschließlich `PosX` / `PosY` des Rasters|
|`PredictMemory`|Gelernte Heilwerte je Zauber und Rang|

Fehlende Schlüssel, etwa in einer alten `HealBox`-Tabelle aus 1.4, zieht `FBHealBox_ApplyDefaults()` beim Laden nach. Der Testmodus wird bewusst **nicht** gespeichert.

## Konfiguration im Code

Alle Stellschrauben stehen als Globals oben in ihrem jeweiligen Abschnitt und lassen sich ohne Eingriff in die Logik ändern.

|Konstante|Standard|Wirkung|
|-|-|-|
|`LowHP` · `VeryLowHP`|0.6 · 0.3|Schwellen für gelb und rot|
|`NamePlateWidth` · `NamePlateHeight`|120 · 28|Größe einer Plakette|
|`FBMANA_BAR_HEIGHT`|5|Höhe des Manastreifens in px|
|`FBMANA_BAR_COLOR`|`{0.15, 0.4, 1, 1}`|Farbe des Manastreifens|
|`FBMANA_BG_ALPHA`|0.35|Dunkler Streifen hinter fehlendem Mana (0 = aus)|
|`FBBAR_BG_COLOR`|0.15 · 0.15 · 0.15|Grundton des Balkenhintergrunds; wie deckend er liegt, regelt die Option `BarBG`|
|`FBPET_NAME_COLOR`|`{0.75, 0.85, 1, 1}`|Namensfarbe auf Pet-Plaketten|
|`FBPET_INDENT`|12|Einrückung (und Verschmälerung) der Pet-Plaketten|
|`FBPET_ICON` · `FBPET_ICON_SIZE`|Fußabdruck · 12|Pfoten-Icon vor Pet-Namen|
|`FBDEBUFF_ICON_SIZE`|14|Kantenlänge des Debuff-Icons|
|`FBLOS_ICON` · `FBLOS_ICON_SIZE`|Blenden-Icon · 12|Sichtlinien-Abzeichen|
|`FBLOS_ICON_X` · `FBLOS_ICON_Y`|-3 · 3|Versatz des Abzeichens von der linken oberen Plattenecke|
|`FBLOS_TIMEOUT`|8|Sekunden, die ein Sichtlinien-Fehler ohne UnitXP markiert bleibt|
|`FBNAME_WIDTH_FULL` · `FBNAME_WIDTH_ICON`|78 · 60|Breite der Namensbox ohne / mit sichtbarem Debuff-Icon|
|`FBRANGE_ALPHA` · `FBRANGE_INTERVAL`|0.5 · 0.5|Deckkraft und Prüfintervall des Reichweiten-Fadings|
|`FBBUFF_MISSING_COLOR`|`{1, 0.5, 0, 1}`|Rahmenfarbe bei fehlendem Wache-Buff|
|`FBAGGRO_COLOR`|`{1, 0.15, 0.15, 1}`|Rahmenfarbe für den Angegriffenen|
|`FBCD_MIN_DURATION`|2|Länge des globalen Cooldowns: Eine Abklingzeit bis zu dieser Länge dunkelt keinen Button ab|
|`FBCD_SHOW_MIN`|0|Ab welcher Länge die Cooldown-Uhr läuft. 0 zeigt jede Abklingzeit samt globalem Cooldown, 2 lässt ihn weg|
|`FBTIMER_COLOR_HOT` · `_SHIELD` · `_WS`|grün · blau · rot|Timerfarben auf den Buttons|
|`FBBUFFICON_SIZE` · `FBBUFFICON_GAP` · `FBBUFFICON_MAX` · `FBBUFFICON_XOFF`|8 · 1 · 6 · -2|Buff-Icons links neben der Plakette|
|`FBBUFFICON_STEPS` · `FBBUFFICON_GREY`|32 · 0.30|Anzahl Ablaufstufen (32) und Grauton, falls Client nicht entsättigen kann|
|`FBNAME_HEIGHT`|12|Höhe der Namensbox (eine Zeile, vertikal zentriert)|
|`FBWEAKENED_SOUL_SEC`|15|Dauer der Geschwächten Seele|
|`FBClassColors`|(Tabelle)|Ersatz-Klassenfarben, falls der Client kein `RAID_CLASS_COLORS` hat|
|`FBBuffWatchSpells` · `FBBuffAlternates`|(Tabelle)|Angebotene Buffs je Klasse und welche Gruppenversion als gleich zählt|
|`FBPartyUnit` · `FBLayoutOrder`|(Tabelle)|Die zehn Plätze und ihre Anzeigereihenfolge|
|`FBTestGhosts`|(Tabelle)|Namen und Werte der Geister im Testmodus|
|`MaxButtonCount`|10|Maximale Buttonzahl|
|`FBMENU_BTN_HEIGHT` · `FBMENU_ICON_SIZE`|17 · 16|Zeilenhöhe und Icon-Größe im Menü|
|`FBMENU_MOUSE_PAD`|14|Toleranzzone um die Menüs|
|`FBMENU_GRACE_TIME`|3.0|Auto-Close des Menüs (999 = aus)|
|`FBPREDICT_TICK_DEFAULT`|3|Standard-Tickintervall für HoTs|
|`FBPREDICT_THROTTLE`|0.2|Update-Rate der Vorhersage|
|`FBRAID_TICK` · `FBRAID_TICK_SLICES`|0.5 · 4|Voller Durchlauf für Reichweite und Sichtlinie im Raid, und auf wie viele Ticks er verteilt wird|
|`FBTICK_GEOM_STEP`|0.25|Wie oft der Ticker die Balkenmaße nachliest (der Funke selbst wird in jedem Frame gezeichnet)|
|`FBPREDICT_CONFIRM_TIME`|3.0|Wartezeit auf die Aura-Bestätigung|
|`FBPREDICT_TARGET_TIME`|2.0|Gültigkeit des gemerkten Cast-Ziels|
|`FBPredictTickInterval`|`{Lifebloom = 1}`|Abweichende Tickintervalle|
|`FBCommGroupHeal`|`{Prayer of Healing}`|Was als `GrpHeal` gefunkt wird|
|`FBPOWER_COLORS`|blau · rot · orange · gelb|Balkenfarbe je Ressource (Mana, Wut, Fokus, Energie)|
|`FBHealChains`|(Tabelle)|Welche Zauber als derselbe Heilzauber in klein gelten. Innerhalb einer Kette darf Smart Healing den Zauber wechseln|
|`FBHoTSpells`|(Tabelle)|Zauber mit Heilung über Zeit, die Smart Healing nie abrangt|
|`FBBlockedClasses`|`WARRIOR`, `ROGUE`, `HUNTER`|Klassen, für die das Addon ohne `/fbp forceload` nicht lädt|

---

## Funktionsreferenz

### Anzeige und Rahmen

|Funktion|Zweck|
|-|-|
|`FBHealBox_OnLoad()`|Event-Registrierung|
|`FBHealBox_OnEvent(event, arg1)`|Zentrale Ereignisverteilung; entscheidet bei `ADDON_LOADED` / `VARIABLES_LOADED` auch über die Klassensperre|
|`FBHealBox_ClassIsBlocked()` · `FBHealBox_ClassAllowed()`|Krieger, Schurke oder Jäger? Und darf die Anzeige trotzdem laufen (`ForceLoad`)?|
|`FBHealBox_ApplyClassGate()` · `FBHealBox_Suppressed()`|Wendet die Klassensperre an und meldet den Ruhezustand an die Module|
|`FBHealBox_HideAll()` · `FBHealBox_StartUp()` · `FBHealBox_Announce()`|Legt alles schlafen, weckt alles auf, gibt die Startmeldung genau einmal aus|
|`FBHealBoxSetup()`|Legt die zehn Plaketten an (fünf Spieler, fünf Begleiter)|
|`FBHealBoxCreateFrame(…)`|Baut eine Plakette samt der vier Balken|
|`FBHealBox_SetBarStrata(f, strata)`|Stapelt Mana / Leben / Schild / Vorhersage|
|`FBHealBox_SetPlateVisible(f, visible)`|Blendet alle Balken einer Plakette ein/aus (Party-Frame-Modus)|
|`FBHealBox_UpdateUnit(unit, frame)`|Schreibt HP, Schild, Vorhersage, Mana und Dispel-Farbe in eine Plakette|
|`FBHealBox_UpdateMana(unit, frame)`|Der Manastreifen: nur bei Mana-Nutzern sichtbar|
|`FBHealBox_DispelType(unit)`|Erster von der eigenen Klasse entfernbarer Debuff: Typ, Textur, Stacks, sonst nil|
|`FBHealBox_UpdateDebuffIcon(frame, tex, count)`|Debuff-Icon und Stackzahl|
|`FBHealBox_CastOn(button, castString)`|Wirkt den Zauber eines Buttons (links oder rechts) auf sein Ziel|
|`FBHealBox_DropSpell(btnIndex, side)` · `FBHealBox_CursorSpell()`|Drag & Drop aus dem Zauberbuch|
|`FBHealBox_SmartRank(castString, unit)`|Wählt den zu wirkenden Rang|
|`FBHealBox_IsHoT(base, ranks)`|Heilung über Zeit? Namensliste plus Tooltip, Zauberwache und laufende HoTs. Smart Healing lässt diese aus|
|`FBHealBox_HealFamily(base)` · `FBHealBox_DirectAmount(spell, sd)`|Die Heilkette eines Zaubers; die erwartete Heilung eines Rangs, oder nil, wenn der Zauber nicht in Frage kommt|
|`FBPredict_ExpectedDirect(spell, rank, info, id)`|Erwartete Sofortheilung: gelernter Wert, sonst Tooltip plus Anteil am Ausrüstungsbonus|
|`FBHealBox_ProbeHealBonus()` · `FBHealBox_HealingBonus()` · `FBHealBox_HealBonusFor(id)`|Sucht eine API für den Heilbonus, liest sie aus und gewichtet nach Zauberzeit|
|`FBHealBox_SpellCastSeconds(id)`|Zauberzeit aus dem Tooltip (0 = Instant), je Zauberbuchplatz gemerkt|
|`FBHealBox_ApplyBlizzParty()` · `FBHealBox_HideBlizzPartyActive()`|Versteckt Blizzards Gruppenfenster oder gibt sie zurück, samt Sperre gegen den Anheftmodus|
|`FBHealBox_SetPowerColor(bar, cache, ptype)`|Färbt einen Ressourcenbalken für Mana, Wut, Fokus oder Energie|
|`FBHealBox_ApplyBarBG(f)` · `FBHealBox_ApplyBarBGAll()`|Setzt den Hintergrund hinter den Balken einer Plakette nach der Option `BarBG`|
|`FBPredict_ScanPlayerBuffTimes()`|Liest alle eigenen Bufflaufzeiten einmal je Frame in eine Tabelle Textur nach Sekunden|
|`FBHealBox_ApiFailed()`|Stellt Reichweite, Abstand und Sichtlinie auf den geschützten Einzelaufruf zurück, wenn ein Durchlauf geworfen hat|
|`FBHealBox_UpperTex(tex)`|Groß geschriebener Texturpfad, gemerkt, damit `strupper` nicht je Aufruf zuteilt|
|`FBHealBox_CheckAggroAll()` · `FBHealBox_ApplyBorder(f)`|Roter Rahmen für den Angegriffenen; Rahmen-Vorrang|
|`FBHealBox_UpdateSpellTimers()` · `FBHealBox_SpellTimerFor(...)`|HoT/Schild-Timer auf Buttons|
|`FBHealBox_UpdateButtonCooldown(b)` · `FBHealBox_UpdateAllCooldowns()`|Cooldown-Uhr|
|`FBHealBox_ShowTab(n)` · `FBHealBox_ApplyRightClickLayout()`|Options-Reiter; Rechtsklick-Spalte ein-/ausblenden|
|`FBHealBox_PlateMouseDown(f)` · `FBHealBox_PlateMouseUp(f)` · `FBHealBox_RunPlateAction(f, action)`|Klick und Ziehen auf einer Plakette|
|`FBHealBox_RefreshAllBars()`|Aktualisiert alle zehn|
|`FBUpdateNames()`|Namen und Sichtbarkeit nach Gruppen- oder Pet-Wechsel, danach neu anordnen|
|`FBSlotActive(p)`|Ist Platz p gerade anzuzeigen?|
|`FBHealBox_Layout()`|Stapelt die sichtbaren Plaketten (Besitzer, dann Pet) mit `RowSpacing`|
|`FBHealBox_ApplyButtonSpacing()`|Verkettet alle Buttons neu mit `ButtonSpacing`|
|`FBHealBox_SavePosition()` · `FBHealBox_RestorePosition()`|Plattenposition in den SavedVariables|
|`FBHealBox_ApplyDefaults()` · `FBHealBox_SyncOptions()`|Fehlende Einstellungen nachziehen; Optionsfenster daran angleichen|
|`FBHealBox_ApplyNameColor(unit, f)` · `FBHealBox_ApplyAllNameColors()`|Name in Klassen- bzw. Pet-Farbe|
|`FBHealBox_SetWatchBuff(name)` · `FBHealBox_HasWatchBuff(unit)` · `FBHealBox_CheckWatchBuff(unit, f)`|Buff-Wache: wählen, eine Einheit prüfen, Rahmen färben|
|`FBHealBox_UnitInRange(unit)` · `FBHealBox_CheckRangeAll()`|Reichweiten-Fading|
|`FBUnitLOSBlocked(unit)` · `FBLOS_OnError(msg)` · `FBLOS_Clear(name)` · `FBHealBox_CheckLOSAll()`|Sichtlinie (UnitXP oder Fehlermeldungs-Fallback)|
|`FBMenu_OpenBuffMenu(anchor)`|Die Buff-Auswahl (dasselbe Kaskadenmenü)|
|`HealBoxAttachMode(mode)`|Umschaltung eigene Plaketten ↔ Standard-Gruppenfenster|
|`HealBoxScale(this, scale)`|Skalierung|

### Einheiten und Testmodus

Die Anzeige ruft `UnitExists`, `UnitName`, `UnitHealth` und `UnitMana` nie direkt auf, sondern geht über diese Wrapper. Im Testmodus antworten sie aus `FBTestGhosts`, sonst aus der echten API:

|Funktion|Liefert|
|-|-|
|`FBUnitExists(unit)`|true / false|
|`FBUnitName(unit)`|Name|
|`FBUnitHealth(unit)`|`hp, hpMax` (hpMax ist nie 0)|
|`FBUnitMana(unit)`|`mp, mpMax, hasMana`; hasMana nur bei Powertyp Mana|
|`FBUnitClassToken(unit)`|`"PRIEST"`, `"WARRIOR"`, … oder nil bei Begleitern|
|`FBUnitState(unit)`|nil, `"dead"`, `"ghost"` oder `"offline"`|
|`FBChoiceTables(side)`|Laufzeit- und Speichertabellen der linken (`"L"`) oder rechten (`"R"`) Belegung|
|`FBTest_Ghost(unit)`|Den Geist-Datensatz oder nil|
|`FBTest_Set(on)`|Testmodus umschalten|

### Buttons und Zauberdaten

|Funktion|Zweck|
|-|-|
|`FBHealBoxCreateButton(…)`|Ein Zauber-Button samt Cast-Logik und Tooltip|
|`FBHealBoxButtons()`|Baut alle Buttons neu auf|
|`FBHealBoxButtonsChanged()`|Aktualisiert Icons und Zuordnung ohne Neubau|
|`FBLoadSpellData()`|Scannt das Zauberbuch, sammelt alle Ränge|
|`FBApplySpellChoice(i, castString)`|Weist einem Button einen Zauber zu|
|`HealBoxButton_OnEvent(…)`|Färbt das Icon nach Mana, Cooldown und Reichweite|

### Zauber-Menü

|Funktion|Zweck|
|-|-|
|`FBMenu_OpenSpellMenu(btnIndex, anchor, side)`|Öffnet das Menü für ein Optionsfeld (`side` = `"L"` oder `"R"`)|
|`FBMenu_ShowLevel(level, entries, anchor)`|Baut und positioniert eine Menü-Ebene|
|`FBMenu_BuildSpellEntries()`|Ebene 1: alle gelernten Zauber|
|`FBMenu_BuildRankEntries(spellName)`|Ebene 2: alle Ränge eines Zaubers|
|`FBMenu_SelectSpell(entry)` · `FBMenu_ClearSpell()`|Auswahl übernehmen bzw. Button leeren|
|`FBMenu_CloseAll()` · `FBMenu_IsOpen()`|Menü schließen, Zustand abfragen|

### Vorhersage: Abfrage

Die vier Funktionen, die die Balken speisen. Alle erwarten einen **Spielernamen**, keine Unit-ID:

|Funktion|Liefert|
|-|-|
|`FBGetDirectHeal(name)`|Betrag des laufenden eigenen Direktcasts|
|`FBGetHoTHeal(name)`|Summe aller noch ausstehenden eigenen HoT-Ticks|
|`FBGetShield(name)`|Verbleibender Absorb|
|`FBGetCommHeal(name)`|Angekündigte Heilung anderer Heiler|

### Vorhersage: Innenleben

|Funktion|Zweck|
|-|-|
|`FBPredict_GetSpellInfo(bookID, name)`|Wertet den Zauberbuch-Tooltip aus (Direkt / HoT / Schild)|
|`FBPredict_BuildWatch()`|Baut die Watchlist nach jedem Zauberbuch-Scan|
|`FBPredict_NoteCast(castString, target)`|Merkt Ziel und Rang **vor** dem Cast vor|
|`FBPredict_CastStart(spell, castMs)` · `FBPredict_CastEnd()`|Direktheilung starten und beenden|
|`FBPredict_ScanUnit(unit)`|Aura-Abgleich: Anwendung bestätigen, Wegfall erkennen|
|`FBPredict_StartHoT(…)` · `FBPredict_StartShield(…)`|Tracking scharfschalten|
|`FBPredict_ParseCombat(event, msg)`|Combatlog-Auswertung|
|`FBPredict_OnTick(…)` · `FBPredict_OnDirectHeal(…)` · `FBPredict_OnAbsorb(…)`|Die drei Korrekturpfade|
|`FBPredict_Remember(…)` · `FBPredict_Remembered(…)`|Lernspeicher schreiben und lesen|
|`FBPredict_TicksLeft(e, now)`|Restticks eines HoT|

### HealComm

|Funktion|Zweck|
|-|-|
|`FBComm_Enabled()`|Ist der Sync eingeschaltet?|
|`FBComm_Send(msg)`|Rohversand ins Raid bzw. in die Gruppe|
|`FBComm_SendHealStart(…)`|`Heal` bzw. `GrpHeal`|
|`FBComm_SendHealStop()` · `FBComm_SendHealDelay(ms)`|Abbruch und Pushback|
|`FBComm_SendHoT(spell, target, dur)`|`Renew` / `Reju` / `Regr`|
|`FBComm_OnMessage(prefix, msg, channel, sender)`|Empfang und Auswertung|

---

## Fehlersuche

**Nach dem Einloggen ist gar nichts zu sehen.** Im Chat steht eine orange Zeile mit deiner Klasse: Bei Krieger, Schurke und Jäger schläft das Addon mit Absicht. `/fbp forceload` zeigt es trotzdem an, siehe [Für welche Klassen es lädt](#für-welche-klassen-es-lädt).

**Smart Healing rangt einen Zauber nicht ab.** Zauber mit Heilung über Zeit sind bewusst ausgenommen, ebenso Schilde, Buffs und alles, dessen Tooltip keine Heilung beschreibt. Rangt es zwar ab, wechselt aber nie den Zauber, steht der Zauber in keiner Heilkette oder `/fbp smartcross` ist aus. Unter 30 % Leben geht immer der belegte Rang raus. `/fbp debug` schreibt zu jeder Entscheidung den Grund in den Chat.

**Ein Zauber taucht im Menü nicht auf.** Er steht nicht in der Zauberliste deiner Klasse (`Spell.Name` am Dateianfang) oder ist noch nicht gelernt. Die Liste lässt sich frei erweitern.

**Gelernte Absorb-Werte sind gedeckelt.** Ein gemerkter Absorb über dem 1,5-fachen des Tooltipwerts gilt als Zählfehler und wird beim Laden verworfen (`FBPredict_SanitizeMemory`); die durch die alte Doppelladung verdoppelten Werte aus Versionen vor 1.4.2 räumen sich so von selbst auf.

**Keine Vorhersage für einen bestimmten Zauber.** `/fbp` aufrufen: Steht der Zauber nicht in der Liste der ausgelesenen Zauber, hat der Tooltip-Parser ihn nicht erkannt. Auf abweichenden Servern können die Formulierungen abweichen; die Muster sitzen gebündelt in `FBPredict_GetSpellInfo`.

**Combatlog-Korrekturen greifen nicht.** Die Muster werden aus den GlobalStrings des Clients gebaut (`PERIODICAURAHEALOTHERSELF`, `HEALEDSELFOTHER`, `ABSORB_TRAILER`) und fallen sonst auf englische Vorgaben zurück. `/fbp debug` zeigt, ob Korrekturen ankommen.

**Werte sind zu niedrig.** Vor der ersten beobachteten Heilung steht nur der Tooltip-Basiswert ohne +Heilung zur Verfügung. Ein einziger Cast über die Buttons genügt zum Einpendeln.

**Der HealComm-Sync scheint tot.** Er sendet nur in Gruppe oder Raid; allein passiert nichts. `/fbp` zeigt den Schaltzustand, `/fbp debug` jede ausgehende Nachricht.

**Nach einem Gear-Wechsel stimmen die Zahlen nicht.** Sie korrigieren sich beim nächsten Cast von selbst; `/fbp reset` erzwingt den Neustart.

---

## Klassenzauber

Die vorbelegten Listen, frei erweiterbar in `Spell.Name`:

|Klasse|Zauber|
|-|-|
|Priester|Renew · Flash Heal · Lesser Heal · Heal · Greater Heal · Binding Heal · Prayer of Healing · Prayer of Mending · Circle of Healing · Power Word: Shield · Abolish Disease · Cure Disease · Dispel Magic · Power Word: Fortitude · Prayer of Fortitude · Divine Spirit · Prayer of Spirit · Shadow Protection · Prayer of Shadow Protection · Fear Ward · Power Infusion · Resurrection|
|Druide|Healing Touch · Regrowth · Rejuvenation · Swiftmend · Tranquility · Lifebloom · Abolish Poison · Cure Poison · Remove Curse · Mark of the Wild · Gift of the Wild · Thorns · Innervate · Rebirth|
|Schamane|Lesser Healing Wave · Healing Wave · Chain Heal · Earth Shield · Water Shield · Cure Poison · Cure Disease · Purge · Ancestral Spirit · Water Walking · Water Breathing|
|Paladin|Flash of Light · Holy Light · Holy Shock · Lay on Hands · Cleanse · Purify · Blessing of Protection · Blessing of Freedom · Blessing of Sacrifice · Redemption · Divine Intervention · Blessing of Wisdom / Might / Kings / Salvation / Light / Sanctuary · Greater Blessing of Wisdom / Might / Kings / Salvation / Light / Sanctuary|
|Magier|Remove Lesser Curse · Arcane Intellect · Arcane Brilliance · Dampen Magic · Amplify Magic|
|Hexenmeister|Unending Breath · Detect Invisibility · Detect Lesser / Greater Invisibility|

Nicht vorhandene Einträge stören nicht: Findet der Zauberbuch-Scan sie nicht, werden sie stillschweigend übergangen.

---

## Credits

**Original: Heal Box von Dourd** (Argent Dawn EU), UI Overhauled. Von ihm stammen die Grundidee, der Aufbau mit Namensplaketten und Schnellzugriff-Buttons und das ursprüngliche Optionsfenster. Ohne diese Vorlage gäbe es dieses Addon nicht. Ehre wem Ehre gebührt.

**Vanilla-Portierung und Funktionserweiterung 09/2026: Mquadrat.** Portiert auf Client 1.12.1 mit optionaler SuperWoW-Unterstützung, dazu:

* eigenes Kaskadenmenü für Zauber- und Rangwahl, weil `UIDropDownMenu` in 1.12 keine brauchbaren Untermenüs liefert
* Heilvorhersage für Direktheilung, HoT-Restticks und Absorb-Schilde, selbstkorrigierend über den Combatlog
* HealComm-Sync mit Puppeteer, pfUI, Luna und Co., ohne Ace-Bibliotheken
* Lokalisierung Deutsch, Englisch, Spanisch, Französisch und Italienisch, im laufenden Spiel umschaltbar
* 1.4.5.3: Einstellbarer Hintergrund hinter den Balken der Plaketten, damit die Spielwelt nicht mehr durch fehlendes Leben scheint; siehe CHANGELOG
* 1.4.5.2: Ein laufender HoT zählt bei der Rangwahl von Smart Healing nicht mehr als anfliegende Heilung; siehe CHANGELOG
* 1.4.5.1: Ruckeln des Manafunkens behoben (Bewegungsschwelle und Zeichentakt), der globale Cooldown dunkelt nicht mehr alle Buttons ab und läuft stattdessen als Uhr mit (eigene Schwelle `FBCD_SHOW_MIN`); siehe CHANGELOG
* 1.4.5: Blizzards Gruppenfenster ausblendbar (schließt sich mit dem Anheftmodus gegenseitig aus), Wut, Energie und Fokus im Ressourcenbalken, Heilbonus der Ausrüstung über ClassicAPI in der Vorhersage, dazu ein Leistungsdurchgang ohne Funktionsänderung (Spielerbuffs einmal je Frame, gestaffelte Reichweiten- und Sichtlinienprüfung im Raid, weniger geschützte Aufrufe, keine Wegwerf-Strings im Raid-HP-Text); siehe CHANGELOG
* 1.4.4.3: Klassensperre für Krieger, Schurke und Jäger (Anzeige bleibt aus, Hinweis im Chat, Freischaltung mit `/fbp forceload`) und Smart Healing rangt HoTs aller Klassen nicht mehr ab. Smart Healing rangt innerhalb einer Heilkette auch über Zaubergrenzen ab (Große Heilung zu Geringem Heilen, Heiliges Licht zu Blitz des Lichts), `/fbp smartcross` schaltet es aus; siehe CHANGELOG
* 1.4.4.2: 32-Stufen-Ablaufanzeige für Buff-Icons (ersetzt die 4-Quadranten-Uhr durch 32 vertikale Stufen) sowie Syntax- und Diagnose-Korrekturen; siehe CHANGELOG
* 1.4.4.1: Buff-Erkennung & Tooltip-Scan behoben (Göttlicher Willen Uhr-Icon), vollständige Klassen-Zauberlisten mit Segen, Buffs, Hilfszaubern und Wiederbelebung, Gruppen-Buff-Erkennung; siehe CHANGELOG
* 1.4.4: Leistungsdurchgang ohne Funktionsänderung (zentrale Button-Zustände, Anzeige-Zwischenspeicher, gemeinsame Aura-Scans, zusammengefasste Event-Salven); siehe CHANGELOG
* 1.4.3: Mana-Ticker-Modul (2-s-Regenerationstick und Fünf-Sekunden-Regel als Funke im Manabalken), Smart-Damage-Modul (Rangwahl für Angriffszauber auf jeder Aktionsleiste), Smart Healing (automatisches Abrangen, standardmäßig aus), Cooldown-Uhr auf den Buttons, roter Rahmen für den Angegriffenen, HoT/Schild-Timer auf den Buttons
* 1.4.2: Raidmodus als eigenes Modul (`FBHealBox_Raid.lua`) mit kompaktem 20/40-Raster, Mini-Buttons, eigenem Options-Reiter und Raid-Test; Hook-Schnittstelle im Kern
* 1.4.1: Begleiter-Plaketten, Manabalken im Lebensbalken, einstellbare Button- und Zeilenabstände, Testmodus mit Geisterspielern, gespeicherte Plattenposition, Klassenfarben, Buff-Wache, Reichweiten-Fading, Optionen in Reitern, Rechtsklick-Zauber, Tot/Geist/Offline-Text, Debuff-Icon. Siehe CHANGELOG.md.

---

Heal Box Vanilla v1.4.5.3 · Original von Dourd, UI Overhauled · Vanilla-Portierung und Erweiterung 09/2026 von Mquadrat

---

## Keywords

**English:** World of Warcraft Vanilla 1.12.1 healer addon, Classic WoW healing addon, WoW 1.12 heal frames with click buttons, Healium alternative for Vanilla, HealComm compatible, heal prediction and incoming heals, absorb shield tracking, HoT timers, Power Word: Shield and Weakened Soul tracker, buff timers with clock icons, Fortitude rebuff reminder, dispel indicator, party frames and pet frames, compact raid frames for 20 and 40 player raids, raid grid for healers, mana ticker and five second rule, spirit regeneration tick bar, smart downranking, auto downrank heals, Smart Damage rank selection, target of target aggro marker, line of sight indicator, range fading, class colors, SuperWoW support, UnitXP support, MobHealth3 and MobInfo-2 support, works on Turtle WoW, Nordanaar, Kronos, Everlook and other 1.12 private servers, Priest Druid Paladin Shaman healer UI, Lua 5.0 addon, German English Spanish French Italian.

**Deutsch:** World of Warcraft Vanilla 1.12.1 Heiler-Addon, Classic WoW Heil-Addon, Heilfenster mit Klick-Buttons, Healium-Alternative für Vanilla, HealComm-kompatibel, Heilvorhersage und eingehende Heilung, Absorb-Schild-Anzeige, HoT-Timer, Machtwort: Schild und Geschwächte Seele, Buff-Timer als Uhr-Icons, Seelenstärke nachbuffen, Dispel-Anzeige, Gruppen- und Begleiterfenster, kompakte Raidframes für 20er und 40er Schlachtzüge, Raid-Raster für Heiler, Mana-Ticker und Fünf-Sekunden-Regel, Regenerations-Tick-Balken, automatisches Abrangen, Smart Healing, Smart Damage, Angriffsziel-Markierung, Sichtlinien-Anzeige, Reichweiten-Fading, Klassenfarben, SuperWoW, UnitXP, MobHealth3 und MobInfo-2, läuft auf Turtle WoW und anderen 1.12-Privatservern, Priester Druide Paladin Schamane Heiler-UI, Lua 5.0 Addon, Deutsch Englisch Spanisch Französisch Italienisch.

#WoWVanilla #Vanilla112 #WoW1121 #ClassicWoW #TurtleWoW #WoWAddon #VanillaAddon #HealerAddon #HealingAddon #Healium #HealComm #HealPrediction #RaidFrames #PartyFrames #UnitFrames #ClickCasting #ManaTicker #FiveSecondRule #Downranking #SmartHealing #SmartDamage #BuffTimer #HoTTracker #DispelTracker #Priest #Druid #Paladin #Shaman #SuperWoW #UnitXP #MobHealth #Lua50 #HealBoxVanilla

