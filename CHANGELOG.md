# Changelog

## 1.4.7 (2026-10-08)

The complete code review in one version. Fixes first: Weakened Soul finally shows, other healers' HoTs and shields no longer pass as yours, a click only counts for the cast it started, direct heals are learned, the tooltip scanner reads cast time and range where they actually are, Smart Healing leaves group heals and cooldown spells alone, Smart Damage's minimum damage is safe again, plus line of sight, localized clients, the scale slider and drag and drop in the raid grid. Then performance, robustness and clean-up: redraws collected once per frame, mana events only touch the mana strip, no generic globals any more, modules independent of each other, errors reported instead of swallowed.

### English

**Fixed**

- **Weakened Soul shows up.** The red Weakened Soul timer on the shield button was worked out from the shield entry, and that entry is deleted the moment the shield breaks, which is exactly when Weakened Soul starts to matter. So it hardly ever appeared. It now runs in a table of its own (`FBWeakenedSoul`) for 15 seconds after your own Power Word: Shield, on plates and raid cells alike.
- **Other healers' HoTs no longer count as yours.** Every HoT seen only as a buff was entered as your own, with your highest rank and its full duration. It filled the prediction bar and the button timer even when it was another druid's Rejuvenation. Such a HoT is now provisional and counts nowhere until your own first tick (`… from your Rejuvenation.`) confirms it. If none of yours arrives within one tick interval plus `FBPREDICT_HOT_CONFIRM_GRACE` (1.5) seconds, it is dropped and remembered as someone else's for as long as the buff stays. A tick of yours for a HoT that is not tracked at all adds it on the spot. `/fbp` marks provisional HoTs with `(?)`.
- **Other priests' shields no longer count as yours.** A shield seen only as a buff used your learned absorb value and showed your timer. It now gets the tooltip value, and only shields cast through the Heal Box buttons get the button timer and start Weakened Soul.
- **Smart Healing leaves group heals and cooldown spells alone.** An assigned Prayer of Healing or Chain Heal was downranked by the health missing on the one unit you clicked; over a player at full health that meant rank 1, however the rest of the group looked. Spells with a cooldown such as Holy Shock were downranked as well and then burned the whole cooldown on a small rank. Both are now cast as assigned: the known cases are listed in `FBSmartSkip`, and any spell whose tooltip names a cooldown longer than the global one is left alone too. Within a heal chain they are never picked either. Tooltip help and debug output in all five languages say so.
- **Smart Healing rates low ranks correctly.** In vanilla, ranks learned below level 20 only get a reduced share of +healing, 3.75 per cent less for every level below 20. The estimate added the full share, so with a lot of +healing a Lesser Heal rank 3 looked far stronger than it is and Smart Healing picked ranks that fell short. The learning levels of the ranks concerned are in `FBRankLearnLevel` and the bonus is cut accordingly.
- **The tooltip scanner reads cast time and range at the right place.** In 1.12 the cast time sits on the left of line 3 and the range on the right of line 2. The scanner looked for the cast time on the right and for the range on the left, exactly the wrong way round. The range was never found, so the exact distance check through UnitXP (used when the client has no `IsSpellInRange`) never ran. The cast time was only found for the highest ranks through a fallback scan, and every other rank weighted the gear bonus with a fallback of 2.5 seconds. Cast time, range and now also the cooldown are read together from both columns of the first five tooltip lines and kept per spellbook slot. The range and mana caches are now also cleared when you learn a new rank, because that moves the slots behind it. `/fbp` lists the three values for every watched spell.
- **Line of sight errors only mark the unit you clicked.** Without UnitXP the error went to the last button target of the past two seconds, otherwise to your friendly target, otherwise to yourself. A Smite into a pillar right after a heal greyed out the player you had just healed, and without a heal click your own plate got the eye. Now only the target of the click that caused the error is marked: up to `FBLOS_ERROR_WINDOW` (1) second after the click, and for spells with a cast time until one second after the cast ends, because the server checks line of sight again at the end of a cast. A cast that goes through, an interruption, another error message or another spell starting ends the wait, and your own plate is never marked.
- **Class tables work on every client language.** `UnitClass` returns the localized class name first, and that is what the addon kept. All tables keyed by class (spell lists, buff watch, dispel colours, class icon, Smart Damage) use the English name, so on a German, French or Spanish client they stayed empty and dispel colouring did not work at all. The class now comes from the English token; chat lines and the options window still show the localized name (`FBClassLocal`). Spell lists and tooltip patterns remain English, see the README.
- **The scale slider no longer moves the display.** `SetScale` reads the anchor offsets in the new scale, so dragging the slider made the plates and the raid grid wander off, and they only jumped back after the next reload or roster change. Both are anchored again right after scaling; the raid grid only when the scale really changed and never while you are dragging it.
- **Drag and drop on raid mini buttons.** The click handler of the four mini buttons used the variable of the loop that created them. Lua 5.0, the version inside client 1.12, shares that variable between all functions created in the loop, so every mini button saw its final value and a spell dropped on any of them landed on button 4. The handler now uses the button's own index.
- **A click only counts for the cast it started.** Target and rank of a click on a Heal Box button stayed valid for two and three seconds for every following cast, even after a failed click and for casts from the action bar. A Flash Heal from the bar right after a click was booked for the clicked player with the clicked rank and announced that way over HealComm, and after a failed shield click another priest's shield on the same player passed as yours as soon as any aura there changed. A click now belongs only to the spell that starts or goes through right after it (`FBPREDICT_CLICK_TIME`, 2 seconds); a failure, an error message or another spell drops it. A click made while another spell is still being cast waits for the next start, so spam clicking and the spell queue of client mods keep the running cast intact. Error messages and failed casts always answer the latest attempt; to know which one that is, Heal Box now counts every attempt through hooks on `UseAction`, `CastSpellByName` and `CastSpell`, which only count and pass everything on. HoTs, shields and buffs are confirmed only once the cast has gone through.
- **Direct heals are learned.** The server usually reports the end of a cast before the heal shows up in the combat log, and by then the cast was already forgotten. The self correction of direct heals therefore hardly ever learned anything. A finished cast now waits up to two seconds for its line.
- **Smart Damage's minimum damage is safe again.** The smallest hit seen so far counted as a rank's minimum damage. After a single high roll that was above the real minimum (Smite rank 1 does 13 to 17), and the chosen rank did not kill. The smallest normal hit is still what gets learned, but it now only proves a bonus: hit minus the tooltip's maximum, and only that is added to the tooltip's minimum. It stays the smallest hit, because boosts such as Curse of Shadow or Power Infusion only raise some hits. Saved values keep working unchanged.
- **Smart Damage's own health estimate stays out of raids.** There the combat log does not show all damage of the other groups, so every measurement came out too low, and for mob types you only meet in raids the estimate was far too small. In a raid the module now neither measures nor uses its estimate; real values, MobHealth3 and MobInfo-2 still count. Outside raids, damage of friendly players outside your group and other players' damage over time count as well.
- **Raid grid.** A cell taken over by a new player kept the red aggro border of the previous one until the next hostile target; the cells now drop that state on every roster change. The *Class colours* and *Buff icons* switches on the *General* tab reach the grid at once instead of with the next roster change. And `/fbp raid` during a raid test no longer leaves the test ghosts breathing in the background, which redrew the grid five times a second until the next reload.
- **Blizzard's party frames stay hidden when another addon hid them.** With *Hide Blizzard party frames* off (the default), every group change showed the frames again. Heal Box now only brings back what it hid itself. Saved settings with both this option and the attach mode on locked both switches in the options; the attach mode now wins at login.
- **Scale slider in attach mode.** There the buttons hang on Blizzard's party frames at scale 1, yet the slider scaled them anyway, and their offsets grew along with them. In attach mode the slider now only stores its value, which applies once the mode is switched off.
- **HoT ticks no longer clear the line of sight mark.** A tick needs no line of sight. Only a cast starting on the unit or a direct heal landing clears the mark.
- **pfUI's `HealStop`.** pfUI sends the command with a capital S, Heal Box only knew `Healstop`, so a cancelled pfUI heal stayed on the bar until its cast time ran out. Commands are now compared regardless of upper and lower case.
- **Language change, empty buttons, pet spells.** After switching the language, Dead, Ghost and Offline stayed in the old language until the next group change. A button cleared in the options, or holding a spell you no longer know, kept the tint and the cooldown clock of its old spell. A spell dragged from the pet's spellbook was stored by its slot number, which belongs to a different spell in your own spellbook; it is now refused with a note in the chat.

**Performance**

- **Redraws are collected once per frame.** Seven places still redrew all ten plates and forty raid cells on every event: every HealComm message from another healer, every tick of your own HoT, every direct heal, every absorb, cast start and cast end, and every aura check with a change. With several HealComm users in a raid that was several full sweeps a second, more than 1.4.6 had saved. These places now only note the affected name; at the end of the frame the collected names are drawn once (`FBHealBox_MarkDirty`, `FBHealBox_FlushDirty`). A burst of ten messages costs one redraw of the units concerned. The raid module looks the cell up by name instead of searching forty cells. The full sweep at most once a second stays as a safety net.
- **Mana only redraws the mana strip.** `UNIT_MANA` fires for every mana user in the raid every two seconds, and each one recomputed health, prediction, shield, colour and text of a plate or cell. Now only the strip is updated. Rage, energy and focus are registered as well, so with *Show rage, energy, focus* those strips no longer lag behind.
- **Range per unit, not per button.** In a full raid up to 160 buttons asked the range one by one, although nearly all heals reach equally far. Each pass now asks once per unit and range. The red out of range tint moved into the 0.5 second range pass: it was only evaluated on `SPELL_UPDATE_USABLE`, which does not fire at full mana, so a player running out of range stayed untinted.
- **Spellbook read once per burst.** At login and when zoning, `PLAYER_ENTERING_WORLD` and several `SPELLS_CHANGED` arrive back to back, and each one read the whole spellbook including every tooltip right away. That now happens once, in the next frame. The full setup at login ran twice (`ADDON_LOADED` and `VARIABLES_LOADED`); it runs once now, unless the saved settings only arrive with the second event.
- **Cooldown sweep compares numbers.** Its key was built as a string for every button on every pass, during the global cooldown for every single button. Start and duration are compared as numbers now.
- **Smart Damage rests while it is off.** The module listened to the combat log, `UNIT_HEALTH` and target changes even in its default off state, and read the spellbook on every `SPELLS_CHANGED`. Now it registers those events only when switched on, and it reads the spellbook only when switched on or when you open the options.

**Robustness**

- **Global names with an `FB` prefix.** `icon` (a missing `local`, never used, now removed), `panel` (the options window, under one of the most common names there are), `Spell`, `ClassIcon`, `LowHP`, `VeryLowHP`, `NamePlateWidth`, `NamePlateHeight`, `MaxButtonCount`, `MMButton` and the option widgets such as `ScaleSlider` and `MaxButtonSlider` were plain globals. Another addon with a global `panel` or `Spell` could break Heal Box. They are now `FBPanel`, `FBClassSpells`, `FBClassIcon`, `FBLowHP`, `FBVeryLowHP`, `FBNamePlateWidth`, `FBNamePlateHeight`, `FBMaxButtonCount`, `FBMinimapButton`, `FBScaleSlider` and so on.
- **Modules no longer depend on each other.** Smart Damage looked for the mana ticker's tab and placed itself below it; without the ticker file there were no Smart Damage options at all, although both modules are meant to be removable. The core now manages the shared *Extras* tab (`FBHealBox_ExtrasSection`), and each module gets its own section. The ticker only learned about new cells through `UpdateNames`; when the raid grid rebuilt on a pure `RAID_ROSTER_UPDATE`, for example when crossing the threshold, the spark was missing or ran on someone else's cell. The raid module now fires the new hook `RaidRoster` after every rebuild.
- **Errors are no longer swallowed.** An error in a module hook aborted the whole core routine that ran it. Every hook now runs protected; the first error of each hook appears in the chat, further ones with `/fbp debug`. The protected range and line of sight sweeps switched to protected single calls on any error, a future programming error included, without a word. With `/fbp debug` the error now shows, and if the same sweep fails three times in a row, so that the single calls do not help either, it is reported once even without debug mode.
- **Button passes run protected.** After the first successful range query the range was asked without protection for every spell, for the buttons as well. If the client threw for one button spell only, the error came back every half second. The button passes of core and raid grid now run protected like the range sweep, and whether the range may be asked without protection is decided per spell: a spell the client throws for takes the fallback on its own, the others keep using `IsSpellInRange`. Smart Damage's hook on `UseAction` is protected too: an error is reported once, and the key press goes through unchanged.
- **Combat log templates with numbered placeholders.** If a client wrote its combat log templates with positions such as `%1$s`, the pattern kept the `$` and every search with it threw an error. Numbered placeholders in their natural order are now removed; should a language swap the order, the English fallback applies.
- **HealComm in battlegrounds and with limits.** In battlegrounds HealComm-1.0 sends over `BATTLEGROUND`; over `RAID` nobody is reached there. Heal Box now does the same. Amounts and cast times from other addons are capped at 20000 and 10 seconds (`FBCOMM_MAX_AMOUNT`, `FBCOMM_MAX_CAST_MS`), so a broken message cannot fill a bar for a long time.
- **Your own heal on yourself.** "Your Flash Heal heals you for 1240." also matched the pattern for heals on others and went to a unit called "you"; your own plate kept its prediction until the cast ended. The pattern for heals on yourself is checked first now.
- **Spell button tooltip.** It used `SpellBookFrame.bookType`, so a warlock who last had the pet tab open saw pet spells there. It always shows your own spellbook now.
- **Drag and drop remembers less.** The spell last picked up from the spellbook was only forgotten through `ClearCursor`. With an action, a macro or an item on the cursor afterwards, the old spell could still land on a button. Picking up or placing actions, macros and items now clears it as well.
- **Minimap button.** The old code passed `math.rad(225)` to `cos` and `sin`, which take degrees in WoW; the button ended up at about four degrees, on the left of the minimap. It stays there, but dragging it with the right mouse button now saves its spot per character (`HealBox.MinimapPos`). Before, it jumped back after every reload.
- **Saved data no longer grows without end.** `HealBox.MobHP`, Smart Damage's mob health per type, grew by every mob type and level while leveling. It now keeps at most 400 types (`FBDMG_MOBHP_MAX`) and drops the ones not seen for the longest time. `FBBuffPresent` kept every name ever scanned; after every roster change, names that left the group are dropped now, together with their buff timers and foreign HoT marks.

**Cleaned up**

- **Dead code removed:** `FBGetSpellID` (which also read an undefined global `spellRank`), `HealBoxButton_OnEvent`, `FBUnitGUID`, `FBHealBox_UpdateButtonCooldown`, `FBRaid_InRaid`, `FBDropDown`, `FBDropDownButtonValue`, `FBTIMER_COLOR_BUFF`, `FBRaidOptionsTab`, and the second assignment of `FBHealBox2` to `FBHealBoxPet5`; `CreateFrame` with a name already creates these globals.
- **Outdated texts fixed:** the *Buff icons* tooltip still described the clock with quadrants in all five languages; since 1.4.4.2 the icon fades from top to bottom in 32 steps. The ticker's load message pointed to a tab called *Ticker*, which is *Extras*. The XML comment named only two of the four scripts. The README spoke of two tabs and did not know the hooks `Suppress`, `ButtonStates`, `BuffIcons` and `RefreshNames`.
- **Duplicate logic merged:** the raid module's copies of the bar helpers (`FBRaid_SetValues`, `FBRaid_SetMax`, `FBRaid_SetColor`) are gone, the cells use the core's helpers. The two nearly identical slider factories of ticker and raid module became one, `FBHealBox_CreateSlider`, which Smart Damage now uses instead of its hand built slider as well. The double loop over groups and positions, about ten times in the raid module, became flat lists of cells. The defaults stood twice in the core and had already drifted apart (`HealComm` was missing in one of them); there is one table now, `FBHealBoxDefaults`, filled in by a loop as in the modules.
- **Small things:** the comment on ae, oe and ue now says what is true: accents are fine, characters outside Latin-1 are not reliably in the default fonts. That is why the Smart Healing tooltips use the middle dot instead of "•". SuperWoW is detected in one place instead of two. `## OptionalDeps: SuperWoW` is gone from the `.toc`; SuperWoW is a client extension, not an addon, so the line had no effect. The learning branch at a shield break could never run, because the absorb handler raises the maximum beforehand; it is gone.

**Good to know**

- A HoT cast from the action bar or a macro now shows its timer and its prediction with your first tick, about three seconds after the cast, instead of right away. Casts through the Heal Box buttons are confirmed immediately, as before.
- A shield cast from the action bar can no longer be told apart from another priest's and gets no button timer and no Weakened Soul. Cast it through the buttons to have both.
- A HoT, shield or buff cast through the buttons is confirmed once the cast has gone through and its aura appears. A click that fails (out of range, line of sight, global cooldown) leaves nothing behind.
- Smart Damage keeps the values it learned with older versions: minimum damage values are read with the new, safe formula, and mob health estimates are still used outside raids.
- If you edited the class spell lists or the HP thresholds in your own copy: they are called `FBClassSpells.Name`, `FBLowHP` and `FBVeryLowHP` now.
- A red line "Error in …" in the chat means a module or a sweep hit a Lua error. The addon keeps running; the line names the place, which helps with a bug report.

### Deutsch

**Behoben**

- **Geschwaechte Seele wird angezeigt.** Der rote Timer fuer Geschwaechte Seele auf dem Schildbutton wurde aus dem Schildeintrag berechnet, und der wird in dem Moment geloescht, in dem der Schild bricht, also genau dann, wenn die Seele ueberhaupt zaehlt. Zu sehen war sie deshalb so gut wie nie. Sie laeuft jetzt in einer eigenen Tabelle (`FBWeakenedSoul`) 15 Sekunden nach deinem eigenen Machtwort: Schild, auf Plaketten und Raidzellen gleichermassen.
- **HoTs anderer Heiler zaehlen nicht mehr als deine.** Jeder HoT, der nur als Buff zu sehen war, wurde als eigener eingetragen, mit deinem hoechsten Rang und voller Laufzeit. Er fuellte Vorhersagebalken und Buttontimer, auch wenn es die Verjuengung eines anderen Druiden war. Ein solcher HoT ist jetzt vorlaeufig und zaehlt nirgends, bis dein eigener erster Tick (`… from your Rejuvenation.`) ihn bestaetigt. Kommt binnen eines Tickintervalls plus `FBPREDICT_HOT_CONFIRM_GRACE` (1,5) Sekunden keiner von dir, wird er verworfen und als fremd gemerkt, solange der Buff bleibt. Ein Tick von dir fuer einen HoT, der gar nicht verfolgt wird, nimmt ihn sofort auf. `/fbp` kennzeichnet vorlaeufige HoTs mit `(?)`.
- **Schilde anderer Priester zaehlen nicht mehr als deine.** Ein nur als Buff gesehener Schild bekam deinen gelernten Absorbwert und zeigte deinen Timer. Er bekommt jetzt den Tooltipwert, und nur Schilde, die du ueber die Heal Box Buttons wirkst, bekommen den Buttontimer und starten die Geschwaechte Seele.
- **Smart Healing laesst Gruppenheilungen und Zauber mit Abklingzeit in Ruhe.** Ein belegtes Gebet der Heilung oder eine Kettenheilung wurde nach dem fehlenden Leben der einen angeklickten Einheit abgerangt; ueber einem vollen Spieler hiess das Rang 1, egal wie der Rest der Gruppe aussah. Zauber mit Abklingzeit wie Heiliger Schock wurden ebenfalls abgerangt und verbrauchten dann die volle Abklingzeit fuer einen kleinen Rang. Beide gehen jetzt wie belegt raus: Die bekannten Faelle stehen in `FBSmartSkip`, und jeder Zauber, dessen Tooltip eine Abklingzeit ueber dem globalen Cooldown nennt, bleibt ebenfalls unberuehrt. Innerhalb einer Heilkette werden sie auch nie gewaehlt. Tooltiphilfe und Debugausgabe sagen das in allen fuenf Sprachen.
- **Smart Healing bewertet niedrige Raenge richtig.** In Vanilla bekommen Raenge, die unter Stufe 20 gelernt werden, nur einen gekuerzten Anteil an +Heilung, je Stufe unter 20 sind es 3,75 Prozent weniger. Die Schaetzung rechnete den vollen Anteil drauf; mit viel +Heilung sah ein Geringes Heilen Rang 3 so deutlich staerker aus, als es ist, und Smart Healing waehlte Raenge, die zu wenig heilten. Die Lernstufen der betroffenen Raenge stehen in `FBRankLearnLevel`, der Bonus wird entsprechend gekuerzt.
- **Der Tooltipscanner liest Zauberzeit und Reichweite an der richtigen Stelle.** In 1.12 steht die Zauberzeit links in Zeile 3 und die Reichweite rechts in Zeile 2. Der Scanner suchte die Zauberzeit rechts und die Reichweite links, also genau vertauscht. Die Reichweite fand sich nie, damit lief die genaue Abstandspruefung ueber UnitXP (genutzt, wenn der Client kein `IsSpellInRange` hat) nie. Die Zauberzeit fand sich nur fuer die Hoechstraenge ueber einen Rueckfallscan, alle anderen Raenge gewichteten den Ausruestungsbonus mit dem Ersatzwert 2,5 Sekunden. Zauberzeit, Reichweite und jetzt auch die Abklingzeit werden gemeinsam aus beiden Spalten der ersten fuenf Tooltipzeilen gelesen und je Zauberbuchplatz gemerkt. Die Speicher fuer Reichweite und Manapreis werden jetzt auch geleert, wenn du einen neuen Rang lernst, denn der verschiebt die Plaetze dahinter. `/fbp` nennt die drei Werte fuer jeden beobachteten Zauber.
- **Sichtlinienfehler markieren nur die angeklickte Einheit.** Ohne UnitXP ging der Fehler an das letzte Buttonziel der vergangenen zwei Sekunden, sonst an dein freundliches Ziel, sonst an dich selbst. Ein Angriffszauber ohne Sicht direkt nach einer Heilung graute den gerade geheilten Spieler aus, und ohne Heilklick bekam deine eigene Plakette das Auge. Jetzt wird nur das Ziel des Klicks markiert, der den Fehler ausgeloest hat: bis `FBLOS_ERROR_WINDOW` (1) Sekunde nach dem Klick, bei Zaubern mit Zauberzeit bis eine Sekunde nach dem Castende, denn der Server prueft die Sicht am Ende eines Casts noch einmal. Ein Cast, der durchgeht, eine Unterbrechung, eine andere Fehlermeldung oder ein anderer Zauber, der anlaeuft, beendet das Warten, und deine eigene Plakette wird nie markiert.
- **Klassentabellen in jeder Clientsprache.** `UnitClass` liefert zuerst den lokalisierten Klassennamen, und genau den hat sich das Addon gemerkt. Alle nach Klasse geschluesselten Tabellen (Zauberlisten, Buff-Wache, Dispelfarben, Klassenicon, Smart Damage) nutzen den englischen Namen; auf einem deutschen, franzoesischen oder spanischen Client blieben sie deshalb leer, und die Dispelfaerbung fiel komplett aus. Die Klasse kommt jetzt aus dem englischen Token; Chatzeilen und Optionsfenster zeigen weiter den lokalisierten Namen (`FBClassLocal`). Zauberlisten und Tooltipmuster bleiben englisch, siehe README.
- **Der Skalierungsregler verschiebt die Anzeige nicht mehr.** `SetScale` liest die Ankerversaetze im neuen Massstab, beim Ziehen am Regler wanderten Plaketten und Raidraster deshalb weg und sprangen erst nach dem naechsten Laden oder Rosterwechsel zurueck. Beide werden direkt nach dem Skalieren neu verankert; das Raidraster nur bei echter Aenderung und nie, waehrend du es gerade ziehst.
- **Drag & Drop auf die Minibuttons im Raid.** Der Klickhandler der vier Minibuttons benutzte die Variable der Schleife, die sie erzeugt. Lua 5.0, die Version im Client 1.12, teilt diese Variable zwischen allen in der Schleife erzeugten Funktionen; jeder Minibutton sah ihren Endwert, und ein Zauber, egal auf welchen gezogen, landete auf Button 4. Der Handler nimmt jetzt den eigenen Index des Buttons.
- **Ein Klick gilt nur fuer den Cast, den er ausloest.** Ziel und Rang eines Klicks auf einen Heal Box Button galten zwei und drei Sekunden lang fuer jeden folgenden Cast, auch nach einem gescheiterten Klick und fuer Casts von der Aktionsleiste. Eine Blitzheilung von der Leiste kurz nach einem Klick wurde fuer den angeklickten Spieler mit dem angeklickten Rang verbucht und so ueber HealComm gemeldet, und nach einem gescheiterten Klick auf den Schild galt der Schild eines anderen Priesters auf demselben Spieler als deiner, sobald sich dort irgendeine Aura aenderte. Ein Klick gehoert jetzt nur zu dem Zauber, der gleich danach anlaeuft oder durchgeht (`FBPREDICT_CLICK_TIME`, 2 Sekunden); ein Fehlschlag, eine Fehlermeldung oder ein anderer Zauber verwirft ihn. Ein Klick, waehrend noch ein anderer Zauber gewirkt wird, wartet auf den naechsten Castbeginn; Spamklicks und die Zauberwarteschlange von Clientmods lassen den laufenden Cast so unberuehrt. Fehlermeldungen und gescheiterte Casts beantworten immer den juengsten Versuch; damit klar ist, welcher das ist, zaehlt Heal Box jetzt jeden Versuch ueber Hooks auf `UseAction`, `CastSpellByName` und `CastSpell`, die nur zaehlen und alles weiterreichen. HoTs, Schilde und Buffs werden erst bestaetigt, wenn der Cast durchgegangen ist.
- **Direktheilungen werden gelernt.** Der Server meldet das Castende in der Regel, bevor die Heilung im Combatlog steht, und dann war der Cast schon vergessen. Die Selbstkorrektur der Direktheilungen lernte deshalb so gut wie nie etwas. Ein beendeter Cast wartet jetzt bis zu zwei Sekunden auf seine Zeile.
- **Der Mindestschaden von Smart Damage ist wieder sicher.** Als Mindestschaden eines Rangs galt der kleinste bisher gesehene Treffer. Nach einem einzigen hohen Wurf lag er ueber dem echten Minimum (Smite Rang 1 macht 13 bis 17), und der gewaehlte Rang toetete nicht. Gelernt wird weiter der kleinste normale Treffer, er beweist jetzt aber nur einen Bonus: Treffer minus Hoechstwert des Tooltips, und nur der kommt auf das Minimum des Tooltips. Es bleibt beim kleinsten Treffer, weil Verstaerker wie Curse of Shadow oder Power Infusion nur manche Treffer heben. Gespeicherte Werte gelten unveraendert weiter.
- **Die eigene Lebensschaetzung von Smart Damage bleibt aus Raids heraus.** Dort zeigt der Combatlog den Schaden der anderen Gruppen nicht vollstaendig, jede Messung fiel zu niedrig aus, und bei Mobtypen, die man nur im Raid trifft, war die Schaetzung viel zu klein. Im Raid misst das Modul jetzt nicht und nutzt seine Schaetzung auch nicht; echte Werte, MobHealth3 und MobInfo-2 gelten weiter. Ausserhalb von Raids zaehlen jetzt auch der Schaden freundlicher Spieler ausserhalb deiner Gruppe und der Schaden ueber Zeit anderer Spieler.
- **Raidraster.** Eine Zelle, die ein neuer Spieler uebernahm, behielt den roten Angriffsrahmen ihres Vorgaengers bis zum naechsten feindlichen Ziel; die Zellen legen diesen Zustand jetzt bei jedem Rosterwechsel ab. Die Schalter *Klassenfarben* und *Buff-Icons* im Reiter *Allgemein* erreichen das Raster sofort statt erst beim naechsten Rosterwechsel. Und `/fbp raid` waehrend eines Raidtests laesst die Testgeister nicht mehr im Hintergrund atmen; das Raster wurde dann bis zum naechsten Laden fuenfmal je Sekunde neu gezeichnet.
- **Blizzards Gruppenfenster bleiben versteckt, wenn ein anderes Addon sie versteckt hat.** Mit *Blizzard-Gruppenfenster aus* auf aus (die Vorgabe) holte jede Gruppenaenderung die Fenster wieder hervor. Heal Box nimmt jetzt nur zurueck, was es selbst versteckt hat. Gespeicherte Einstellungen mit dieser Option und dem Anheftmodus zugleich sperrten im Optionsfenster beide Schalter; beim Laden gewinnt jetzt der Anheftmodus.
- **Skalierungsregler im Anheftmodus.** Dort haengen die Buttons im Massstab 1 an Blizzards Gruppenfenstern, der Regler skalierte sie trotzdem, und ihre Versaetze wuchsen mit. Im Anheftmodus merkt sich der Regler jetzt nur seinen Wert, der gilt, sobald der Modus endet.
- **HoT-Ticks loeschen die Sichtlinienmarke nicht mehr.** Ein Tick braucht keine Sicht. Nur ein Cast, der auf der Einheit anlaeuft, oder eine angekommene Direktheilung loescht die Marke.
- **`HealStop` von pfUI.** pfUI schickt den Befehl mit grossem S, Heal Box kannte nur `Healstop`; eine abgebrochene Heilung aus pfUI blieb so bis zum Ende ihrer Zauberzeit auf dem Balken. Befehle werden jetzt unabhaengig von grossen und kleinen Buchstaben verglichen.
- **Sprachwechsel, leere Buttons, Begleiterzauber.** Nach einem Sprachwechsel blieben Tot, Geist und Offline bis zum naechsten Gruppenwechsel in der alten Sprache. Ein Button, dessen Belegung im Optionsfenster geleert wurde oder dessen Zauber du nicht mehr kennst, behielt Toenung und Abklingzeituhr seines alten Zaubers. Ein Zauber aus dem Zauberbuch des Begleiters wurde mit seiner Platznummer gemerkt, die im eigenen Zauberbuch zu einem anderen Zauber gehoert; er wird jetzt mit einem Hinweis im Chat abgelehnt.

**Leistung**

- **Neuzeichnen einmal je Frame gesammelt.** Sieben Stellen zeichneten bei jedem Ereignis noch alle zehn Plaketten und vierzig Raidzellen neu: jede HealComm-Nachricht eines anderen Heilers, jeder Tick deines eigenen HoTs, jede Direktheilung, jeder Absorb, Castbeginn und Castende und jeder Auraabgleich mit Aenderung. Mit mehreren Nutzern von HealComm im Raid waren das mehrere volle Durchlaeufe je Sekunde, mehr als 1.4.6 eingespart hatte. Diese Stellen merken jetzt nur den betroffenen Namen vor; am Ende des Frames werden die gesammelten Namen einmal gezeichnet (`FBHealBox_MarkDirty`, `FBHealBox_FlushDirty`). Eine Salve aus zehn Nachrichten kostet ein Neuzeichnen der betroffenen Einheiten. Das Raidmodul schlaegt die Zelle ueber den Namen nach, statt vierzig Zellen abzusuchen. Der volle Durchlauf hoechstens einmal je Sekunde bleibt als Sicherheitsnetz.
- **Mana zeichnet nur noch den Manastreifen.** `UNIT_MANA` feuert im Raid fuer jeden Manabenutzer alle zwei Sekunden, und jedes davon rechnete Leben, Vorhersage, Schild, Farbe und Text einer Plakette oder Zelle neu. Jetzt wird nur der Streifen nachgefuehrt. Wut, Energie und Fokus sind ebenfalls angemeldet, mit *Wut, Energie, Fokus zeigen* hinken diese Streifen nicht mehr hinterher.
- **Reichweite je Einheit statt je Button.** Im vollen Raid fragten bis zu 160 Buttons die Reichweite einzeln ab, obwohl fast alle Heilzauber gleich weit reichen. Jeder Durchgang fragt jetzt einmal je Einheit und Reichweite. Die rote Toenung ausser Reichweite laeuft im Reichweitentakt von 0,5 Sekunden mit: Bewertet wurde sie nur bei `SPELL_UPDATE_USABLE`, das bei vollem Mana nicht feuert, ein Mitspieler, der aus der Reichweite lief, blieb dann ungetoent.
- **Zauberbuch einmal je Salve gelesen.** Beim Login und beim Zonen kommen `PLAYER_ENTERING_WORLD` und mehrere `SPELLS_CHANGED` kurz hintereinander, und jedes davon las das ganze Zauberbuch samt aller Tooltips sofort. Das geschieht jetzt einmal, im naechsten Frame. Die volle Einrichtung beim Login lief zweimal (`ADDON_LOADED` und `VARIABLES_LOADED`); jetzt laeuft sie einmal, ausser die gespeicherten Einstellungen kommen erst mit dem zweiten Ereignis.
- **Cooldown-Uhr vergleicht Zahlen.** Ihr Schluessel wurde je Button und Durchgang als String gebaut, im globalen Cooldown fuer jeden einzelnen Button. Beginn und Dauer werden jetzt als Zahlen verglichen.
- **Smart Damage ruht, solange es aus ist.** Das Modul hoerte auch im Standardzustand aus auf Combatlog, `UNIT_HEALTH` und Zielwechsel und las bei jedem `SPELLS_CHANGED` das Zauberbuch. Jetzt meldet es diese Ereignisse erst beim Einschalten an und liest das Zauberbuch erst beim Einschalten oder wenn du die Optionen oeffnest.

**Robustheit**

- **Globale Namen mit `FB` versehen.** `icon` (ein fehlendes `local`, nie benutzt, jetzt entfernt), `panel` (das Optionsfenster, unter einem der haeufigsten Namen ueberhaupt), `Spell`, `ClassIcon`, `LowHP`, `VeryLowHP`, `NamePlateWidth`, `NamePlateHeight`, `MaxButtonCount`, `MMButton` und die Bedienelemente wie `ScaleSlider` und `MaxButtonSlider` waren einfache Globals. Ein anderes Addon mit globalem `panel` oder `Spell` konnte Heal Box lahmlegen. Sie heissen jetzt `FBPanel`, `FBClassSpells`, `FBClassIcon`, `FBLowHP`, `FBVeryLowHP`, `FBNamePlateWidth`, `FBNamePlateHeight`, `FBMaxButtonCount`, `FBMinimapButton`, `FBScaleSlider` und so weiter.
- **Module haengen nicht mehr voneinander ab.** Smart Damage suchte den Reiter des Mana-Tickers und setzte sich darunter; ohne Tickerdatei gab es gar keine Optionen fuer Smart Damage, obwohl beide Module einzeln entfernbar sein sollen. Den gemeinsamen Reiter *Extras* verwaltet jetzt der Kern (`FBHealBox_ExtrasSection`), und jedes Modul bekommt darin einen eigenen Abschnitt. Der Ticker erfuhr von neuen Zellen nur ueber `UpdateNames`; baute das Raidraster nach einem reinen `RAID_ROSTER_UPDATE` um, etwa beim Ueberschreiten der Schwelle, fehlte der Funke oder lief auf der Zelle eines anderen Spielers. Das Raidmodul ruft jetzt nach jedem Umbau den neuen Hook `RaidRoster`.
- **Fehler werden nicht mehr verschluckt.** Ein Fehler in einem Modulhook brach den ganzen Ablauf des Kerns ab, der ihn ausgeloest hatte. Jeder Hook laeuft jetzt geschuetzt; der erste Fehler je Hook erscheint im Chat, weitere mit `/fbp debug`. Die geschuetzten Durchlaeufe fuer Reichweite und Sichtlinie schalteten bei jedem Fehler, auch einem kuenftigen Programmierfehler, wortlos auf geschuetzte Einzelaufrufe um. Mit `/fbp debug` steht der Fehler jetzt im Chat, und scheitert derselbe Durchlauf dreimal in Folge, helfen also auch die Einzelaufrufe nicht, meldet er sich einmal auch ohne Debugmodus.
- **Durchlaeufe ueber die Buttons laufen geschuetzt.** Nach der ersten erfolgreichen Abfrage wurde die Reichweite fuer jeden Zauber ungeschuetzt gefragt, auch fuer die Buttons. Warf der Client nur fuer den Zauber eines Buttons, kam der Fehler jede halbe Sekunde wieder. Die Durchlaeufe ueber die Buttons von Kern und Raidraster laufen jetzt geschuetzt wie der Reichweitendurchlauf, und ob die Reichweite ungeschuetzt gefragt werden darf, entscheidet sich je Zauber: Ein Zauber, fuer den der Client wirft, nimmt allein den Rueckfallweg, die anderen fragen weiter `IsSpellInRange`. Auch der Hook von Smart Damage auf `UseAction` ist geschuetzt: Ein Fehler wird einmal gemeldet, und der Tastendruck geht unveraendert durch.
- **Combatlogvorlagen mit nummerierten Platzhaltern.** Schrieb ein Client seine Vorlagen mit Positionen wie `%1$s`, blieb das `$` im Muster stehen, und jede Suche damit warf einen Fehler. Nummerierte Platzhalter in natuerlicher Folge werden jetzt entfernt; stellt eine Sprache die Folge um, greift der englische Rueckfall.
- **HealComm im Schlachtfeld und mit Grenzen.** Im Schlachtfeld sendet HealComm-1.0 ueber `BATTLEGROUND`; ueber `RAID` erreicht man dort niemanden. Heal Box macht es jetzt genauso. Betraege und Zauberzeiten aus anderen Addons werden auf 20000 und 10 Sekunden begrenzt (`FBCOMM_MAX_AMOUNT`, `FBCOMM_MAX_CAST_MS`); eine kaputte Nachricht kann so keinen Balken lange fuellen.
- **Eigene Heilung auf dich selbst.** "Your Flash Heal heals you for 1240." passte auch auf das Muster fuer Heilungen auf andere und ging an eine Einheit namens "you"; deine eigene Plakette behielt ihre Vorhersage dann bis zum Castende. Das Muster fuer Heilungen auf dich wird jetzt zuerst geprueft.
- **Tooltip der Zauberbuttons.** Er nahm `SpellBookFrame.bookType`; ein Hexenmeister, der zuletzt den Begleiterreiter offen hatte, sah dort Begleiterzauber. Jetzt immer das eigene Zauberbuch.
- **Drag & Drop merkt sich weniger.** Der zuletzt aus dem Zauberbuch genommene Zauber wurde nur ueber `ClearCursor` vergessen. Lag danach eine Aktion, ein Makro oder ein Gegenstand am Cursor, konnte trotzdem der alte Zauber auf einem Button landen. Aufnehmen oder Ablegen von Aktionen, Makros und Gegenstaenden loescht ihn jetzt ebenfalls.
- **Minimap-Button.** Der alte Code gab `math.rad(225)` an `cos` und `sin`, die in WoW mit Grad rechnen; der Button landete bei etwa vier Grad, links an der Minimap. Dort bleibt er, aber mit der rechten Maustaste gezogen merkt er sich seine Stelle jetzt je Charakter (`HealBox.MinimapPos`). Vorher sprang er nach jedem Laden zurueck.
- **Gespeicherte Daten wachsen nicht mehr endlos.** `HealBox.MobHP`, das Mobleben je Typ fuer Smart Damage, wuchs beim Leveln um jeden Mobtyp und jede Stufe. Jetzt bleiben hoechstens 400 Typen (`FBDMG_MOBHP_MAX`), die am laengsten nicht gesehenen fallen weg. `FBBuffPresent` behielt jeden je gescannten Namen; nach jedem Rosterwechsel fallen Namen, die nicht mehr in der Gruppe sind, jetzt heraus, samt ihrer Bufftimer und Fremdmarken fuer HoTs.

**Aufgeraeumt**

- **Toter Code entfernt:** `FBGetSpellID` (das zudem eine undefinierte globale `spellRank` las), `HealBoxButton_OnEvent`, `FBUnitGUID`, `FBHealBox_UpdateButtonCooldown`, `FBRaid_InRaid`, `FBDropDown`, `FBDropDownButtonValue`, `FBTIMER_COLOR_BUFF`, `FBRaidOptionsTab` und die zweite Zuweisung von `FBHealBox2` bis `FBHealBoxPet5`; `CreateFrame` mit Namen legt diese Globals schon an.
- **Veraltete Texte korrigiert:** Der Tooltip *Buff-Icons* beschrieb in allen fuenf Sprachen noch die Uhr mit Quadranten; seit 1.4.4.2 blendet das Icon in 32 Stufen von oben nach unten ab. Die Ladezeile des Tickers nannte einen Reiter *Ticker*, er heisst *Extras*. Der Kommentar in der XML nannte nur zwei der vier Skripte. Die README sprach von zwei Reitern und kannte die Hooks `Suppress`, `ButtonStates`, `BuffIcons` und `RefreshNames` nicht.
- **Doppelte Logik zusammengelegt:** Die Kopien der Balkenhelfer im Raidmodul (`FBRaid_SetValues`, `FBRaid_SetMax`, `FBRaid_SetColor`) sind weg, die Zellen nutzen die Helfer des Kerns. Aus den zwei fast gleichen Sliderfabriken von Ticker und Raidmodul wurde eine, `FBHealBox_CreateSlider`, die jetzt auch Smart Damage statt seines handgebauten Reglers nutzt. Die doppelte Schleife ueber Gruppen und Plaetze, rund zehnmal im Raidmodul, wurde zu flachen Zellenlisten. Die Vorgaben standen im Kern zweimal und waren schon auseinandergelaufen (`HealComm` fehlte in einer davon); jetzt gibt es eine Tabelle, `FBHealBoxDefaults`, die eine Schleife nachzieht wie in den Modulen.
- **Kleinigkeiten:** Der Kommentar zu ae, oe und ue sagt jetzt, was stimmt: Akzente sind kein Problem, Zeichen ausserhalb von Latin-1 sind in den Standardschriften nicht sicher enthalten. Deshalb nutzen die Tooltips von Smart Healing den Mittelpunkt statt "•". SuperWoW wird an einer Stelle erkannt statt an zweien. `## OptionalDeps: SuperWoW` ist aus der `.toc` verschwunden; SuperWoW ist eine Clienterweiterung, kein Addon, die Zeile wirkte nie. Der Lernzweig beim Bruch eines Schildes konnte nie laufen, weil die Absorbauswertung das Maximum schon vorher anhebt; er ist entfernt.

**Gut zu wissen**

- Ein HoT von der Aktionsleiste oder aus einem Makro zeigt Timer und Vorhersage jetzt mit deinem ersten Tick, also etwa drei Sekunden nach dem Cast, statt sofort. Casts ueber die Heal Box Buttons sind wie bisher sofort bestaetigt.
- Ein Schild von der Aktionsleiste laesst sich nicht mehr von dem eines anderen Priesters unterscheiden und bekommt weder Buttontimer noch Geschwaechte Seele. Ueber die Buttons gewirkt gibt es beides.
- Ein HoT, Schild oder Buff ueber die Buttons gilt als bestaetigt, sobald der Cast durchgegangen ist und seine Aura erscheint. Ein gescheiterter Klick (ausser Reichweite, keine Sicht, globaler Cooldown) hinterlaesst nichts.
- Smart Damage behaelt, was es mit aelteren Versionen gelernt hat: Mindestschaeden werden mit der neuen, sicheren Rechnung gelesen, Lebensschaetzungen gelten ausserhalb von Raids weiter.
- Wer die Zauberlisten der Klassen oder die Lebensschwellen in der eigenen Kopie angepasst hat: Sie heissen jetzt `FBClassSpells.Name`, `FBLowHP` und `FBVeryLowHP`.
- Eine rote Zeile "Fehler in …" im Chat bedeutet, dass ein Modul oder ein Durchlauf auf einen Lua-Fehler gestossen ist. Das Addon laeuft weiter; die Zeile nennt die Stelle, das hilft bei einer Fehlermeldung.


## 1.4.6 (2026-10-06)

Performance pass over the display loop, with no change in behaviour: only the units that actually changed are redrawn, and two loops that ran empty five times a second now stop early.

### English

**Performance**

- **Only the units that changed are redrawn.** The 0.2 second pass used to set a single dirty flag: if any heal over time ticked anywhere, everything was redrawn, which in a full raid meant forty cells plus ten plates although exactly one unit had changed. The pass now collects the affected unit names in a reused table and hands them to `FBHealBox_RefreshUnitsByName`, and the raid module picks up the same list through the new `RefreshNames` hook. With several HoTs running this turns three to five full sweeps a second into at most one plus a handful of single-unit updates.
- **A full sweep stays as a safety net.** At most once a second, and only while something is actually changing, the old full refresh still runs, so a name that does not match a plate for any reason can never leave a stale bar behind for longer than that.
- **Empty leftovers are cleared.** When the last heal over time or the last foreign heal on a unit expires, the now-empty sub-table is removed instead of being left behind. Several places read `FBHoTs[name]` as "is anything running on this unit", and an empty table answered yes.
- **Raid spell timers skip cells with nothing to show.** The intent to skip was already in the code but the result was thrown away two lines later, so the button loop ran anyway: in a full raid that was 160 do-nothing calls five times a second. The cell is now skipped outright, exactly as the plates already did.
- **Spell timers get an early out.** When no heal over time and no shield of yours is running anywhere, the plate loop no longer asks every slot for its unit and name five times a second; it only looks where a timer still has to be cleared. Classes without HoTs and the time between fights benefit.

**Checked and left alone**

- The three `OnUpdate` loops do no unnecessary work. The prediction checks three dirty flags and two counters per frame, the mana ticker leaves at its gate (a full mana bar means no pass at all), and the raid ghost ticker is hidden outside test mode. Event handling filters unit events through a lookup table rather than walking every frame.
- The global cooldown has been drawn as a sweep since 1.4.5.1, which means every visible button gets a fresh sweep after every cast. That is the intended behaviour and the animation runs in the client, not in Lua, so it stays. Should it ever feel heavy in a dense raid, `FBCD_SHOW_MIN` set to 2 limits the sweep to real cooldowns again.

### Deutsch

**Leistung**

- **Nur noch die Einheiten neu zeichnen, bei denen sich etwas geaendert hat.** Der 0,2-Sekunden-Takt setzte bisher ein einziges Dirty-Flag: Lief irgendwo ein HoT-Tick ab, wurde alles neu gezeichnet, im Vierzigerraid also vierzig Zellen und zehn Plaketten, obwohl sich bei genau einer Einheit etwas geaendert hatte. Der Takt sammelt die betroffenen Namen jetzt in einer wiederverwendeten Tabelle und reicht sie an `FBHealBox_RefreshUnitsByName`; das Raidmodul bekommt dieselbe Liste ueber den neuen Hook `RefreshNames`. Mit mehreren laufenden HoTs werden aus drei bis fuenf vollen Durchlaeufen je Sekunde hoechstens einer plus eine Handvoll Einzel-Updates.
- **Der volle Durchlauf bleibt als Sicherheitsnetz.** Hoechstens einmal je Sekunde, und nur solange sich ueberhaupt etwas aendert, laeuft er weiterhin. Ein Name, der aus irgendeinem Grund zu keiner Plakette passt, kann so nie laenger als eine Sekunde einen alten Balken stehen lassen.
- **Leere Reste werden weggeraeumt.** Laeuft der letzte HoT oder die letzte fremde Heilung auf einer Einheit ab, verschwindet die nun leere Untertabelle, statt liegen zu bleiben. Mehrere Stellen lesen `FBHoTs[name]` als "laeuft da ueberhaupt etwas", und eine leere Tabelle hat darauf mit ja geantwortet.
- **Raid-Zaubertimer ueberspringen Zellen ohne Anzeige.** Die Absicht zu ueberspringen stand schon im Code, das Ergebnis wurde aber zwei Zeilen spaeter wieder verworfen, sodass die Buttonschleife trotzdem lief: im Vierzigerraid 160 Leeraufrufe fuenfmal je Sekunde. Die Zelle wird jetzt wirklich uebersprungen, genau wie es die Plaketten laengst machen.
- **Zaubertimer steigen frueher aus.** Laeuft nirgends ein eigener HoT und kein eigener Schild, fragt die Plakettenschleife nicht mehr fuenfmal je Sekunde jeden Slot nach Einheit und Namen, sondern schaut nur noch dort hinein, wo ein Timer wegzuraeumen ist. Davon profitieren Klassen ohne HoTs und die Zeit zwischen den Kaempfen.

**Geprueft und so gelassen**

- Die drei `OnUpdate`-Schleifen arbeiten nicht unnoetig. Die Vorhersage prueft je Frame drei Dirty-Flags und zwei Zaehler, der Mana-Ticker steigt am Torwaechter aus (voller Manabalken heisst gar kein Durchlauf), und der Geister-Ticker im Raid ist ausserhalb des Testmodus versteckt. Die Ereignisverarbeitung filtert Unit-Events ueber eine Nachschlagetabelle, statt je Frame zu suchen.
- Der globale Cooldown laeuft seit 1.4.5.1 als Uhr mit, das heisst nach jedem Zauber bekommt jeder sichtbare Button eine neue Uhr gesetzt. Das ist das gewollte Verhalten, und die Animation laeuft im Client, nicht in Lua, deshalb bleibt es so. Sollte es im dichten Raid doch schwer wirken, beschraenkt `FBCD_SHOW_MIN` auf 2 die Uhr wieder auf echte Abklingzeiten.


## 1.4.5.3 (2026-10-05)

A readability option suggested by a user: the area behind the bars can be given a solid background, so the game world no longer shows through where health is missing.

### English

**New**

- **Bar background.** New slider *Bar background* on the *General* tab, 0 to 100 per cent in steps of 5. At 0, which is the default, nothing changes: the plate stays see-through and grass, sky or stone show through the empty part of the health bar. Turned up, a quiet dark grey surface sits behind the bars, so the green of the health bar stands on a fixed background. At 100 the plate is opaque. The shade is `FBBAR_BG_COLOR` (0.15 grey) and the setting is kept per character in `HealBox.BarBG`.
- **Where it sits.** The texture hangs on the lowest of the four stacked bars, the incoming-heal bar, on the `BACKGROUND` layer. That puts it under the prediction, the shield, the health and the mana bar, and it is shown and hidden together with them, so nothing is left behind on a plate that is currently empty or hidden by the attach mode. At 0 per cent no texture is set at all, rather than a fully transparent one.
- **Raid cells need nothing.** They already have their own backdrop at 80 per cent black, so there is no world shining through there; the slider deliberately only touches the plates.

**Thanks**

- The idea and a working patch came from a user who finds the translucent bar hard to read. The patch used `WHITE8X8` plus `SetVertexColor`; the version shipped here uses `SetTexture(r, g, b, a)`, which creates a solid colour directly in 1.12 and is what the mana strip already does. Same result, no texture file involved.

### Deutsch

**Neu**

- **Balkenhintergrund.** Neuer Regler *Balkenhintergrund* im Reiter *Allgemein*, 0 bis 100 Prozent in Fuenferschritten. Bei 0, dem Standard, aendert sich nichts: Die Plakette bleibt durchscheinend, durch den leeren Teil des Lebensbalkens sieht man Gras, Himmel oder Stein. Hochgedreht liegt eine ruhige dunkelgraue Flaeche hinter den Balken, das Gruen des Lebensbalkens steht dann auf festem Grund. Bei 100 ist die Plakette undurchsichtig. Der Grundton ist `FBBAR_BG_COLOR` (0,15 Grau), die Einstellung bleibt je Charakter in `HealBox.BarBG` gespeichert.
- **Wo die Flaeche haengt.** Die Textur sitzt auf der untersten der vier gestapelten Balken, der Heilvorhersage, auf der Ebene `BACKGROUND`. Damit liegt sie unter Vorhersage, Schild, Leben und Mana, und sie wird zusammen mit ihnen ein- und ausgeblendet; auf einer leeren oder im Anheftmodus versteckten Plakette bleibt also nichts stehen. Bei 0 Prozent wird gar keine Textur gesetzt statt einer voellig durchsichtigen.
- **Raidzellen brauchen nichts.** Sie haben bereits ihren eigenen Hintergrund mit 80 Prozent Schwarz, dort scheint keine Welt durch; der Regler fasst bewusst nur die Plaketten an.

**Dank**

- Idee und ein lauffaehiger Patch kamen von einem Nutzer, dem der durchscheinende Balken schlecht lesbar ist. Der Patch benutzte `WHITE8X8` mit `SetVertexColor`; hier ausgeliefert wird `SetTexture(r, g, b, a)`, das in 1.12 direkt eine Vollfarbe erzeugt und genau das ist, was der Manastreifen ohnehin schon macht. Gleiches Ergebnis, ohne Texturdatei.


## 1.4.5.2 (2026-09-12)

One fix: a running HoT no longer pulls Smart Healing down a rank.

### English

**Fixed**

- **A HoT on the target no longer talks Smart Healing into a lower rank.** The full healing still owed by a running HoT was subtracted from the deficit as if it had already landed, so a ticking Renew could turn a Heal rank 4 into a Lesser Heal. Only healing that arrives right away is deducted now, meaning direct heals and spells reported over HealComm, roughly one to three seconds out; HoTs stay out of the calculation because they spread their healing over up to fifteen seconds. They are of course still shown on the bar, and the rule that HoTs are never downranked themselves is untouched.

### Deutsch

**Behoben**

- **Ein HoT auf dem Ziel redet Smart Healing keinen kleineren Rang mehr ein.** Die noch offene Heilung eines laufenden HoT wurde vom Fehlbetrag abgezogen, als waere sie schon angekommen; ein tickendes Erneuerung konnte so aus einem Heilen Rang 4 ein Geringes Heilen machen. Abgezogen wird jetzt nur noch Heilung, die gleich ankommt, also Direktheilungen und ueber HealComm gemeldete Zauber, grob ein bis drei Sekunden; HoTs bleiben aus der Rechnung heraus, weil sie ihre Heilung ueber bis zu fuenfzehn Sekunden verteilen. Angezeigt werden sie auf dem Balken selbstverstaendlich weiterhin, und die Regel, dass HoTs selbst nie abgerangt werden, bleibt unberuehrt.


## 1.4.5.1 (2026-09-11)

Button and ticker fixes: the mana ticker spark moves smoothly again, and the global cooldown no longer greys out every button but runs as a sweep instead.

### English

**Fixed**

- **The mana ticker spark moves smoothly again.** The spark was only redrawn once it had travelled half a pixel. That sounds frugal, but it crosses the bar in five seconds, roughly 20 pixels per second, so at 60 frames it advanced on every second frame at best and, depending on rounding, sometimes after one frame and sometimes after two. That uneven step was the stutter, and the fixed 0.03 second redraw step introduced in 1.4.5 made it worse. The threshold is now effectively gone (0.05 px) and the spark is drawn every frame again, which doubles its motion from 30 to 60 steps per second with an even gap.
- **Drawing every frame still costs nothing.** Each spark remembers the width and height of its bar and re-reads them four times a second (`FBTICK_GEOM_STEP`) instead of asking the frame on every pass, and the gate check sits in front of it all: with a full mana bar there is no pass at all.
- **The global cooldown no longer darkens every button.** After casting anything, the client reports every spell as unusable for the length of the global cooldown. Taken literally, that turned all icons dark grey for a second and a half after every cast, as if nothing were available at all. A running cooldown no longer than the global one (`FBCD_MIN_DURATION`) is no longer treated as a reason to darken a button. Blue for missing mana, red for out of range and grey for a spell that really cannot be cast, for instance in the wrong shapeshift form, all work as before. This affects the plates and the raid cells alike, both go through `FBHealBox_ButtonUsable`.
- **It runs as a sweep instead.** Not showing it at all was the other half of the inconsistency: an instant like Renew or Abolish Disease left every button untouched, while Power Word: Shield, which has a real cooldown in 1.12, showed one. The sweep is the calm way to show a short wait, so after every cast you watch it run out on all buttons, the way the action bars do it.
- **Two thresholds instead of one.** The display threshold moved into its own constant `FBCD_SHOW_MIN` (0, show every running cooldown) and is no longer tied to `FBCD_MIN_DURATION` (2), which now only answers whether a cooldown is a reason to darken a button. The two were the same value before, which is why showing the global cooldown and not darkening for it could not be had at the same time. Setting `FBCD_SHOW_MIN` to 2 restores the quiet display. A cooldown is also only shown when one is really running (`cd[1] > 0`), and the sweep starts in the very next frame because the button pass is not throttled.

### Deutsch

**Behoben**

- **Der Funke im Manabalken laeuft wieder rund.** Neu gezeichnet wurde er erst, wenn er einen halben Pixel weitergewandert war. Das klingt sparsam, er braucht fuer den Balken aber fuenf Sekunden, also rund 20 Pixel je Sekunde: Bei 60 Bildern kam er damit bestenfalls in jedem zweiten Frame voran und je nach Rundung mal nach einem, mal nach zwei Frames. Genau dieser ungleiche Schritt war das Ruckeln, und der feste Zeichentakt von 0,03 Sekunden aus 1.4.5 hat es verstaerkt. Die Schwelle ist jetzt praktisch weg (0,05 px) und gezeichnet wird wieder in jedem Frame, das verdoppelt die Bewegung von 30 auf 60 gleichmaessige Schritte je Sekunde.
- **Das Zeichnen je Frame kostet trotzdem nichts.** Jeder Funke merkt sich Breite und Hoehe seines Balkens und liest sie viermal je Sekunde nach (`FBTICK_GEOM_STEP`), statt sie bei jedem Durchlauf zu erfragen, und der Torwaechter sitzt weiterhin davor: Bei vollem Manabalken laeuft gar kein Durchlauf.
- **Der globale Cooldown dunkelt nicht mehr alle Buttons ab.** Nach jedem gewirkten Zauber meldet der Client fuer die Dauer des globalen Cooldowns saemtliche Zauber als nicht nutzbar. Woertlich genommen wurden dadurch nach jedem Zauber anderthalb Sekunden lang alle Symbole dunkelgrau, als waere gar nichts mehr verfuegbar. Eine laufende Abklingzeit, die nicht laenger ist als der globale Cooldown (`FBCD_MIN_DURATION`), gilt jetzt nicht mehr als Grund zum Abdunkeln. Blau fuer fehlendes Mana, Rot fuer ausser Reichweite und Grau fuer einen Zauber, der wirklich nicht geht, etwa in der falschen Gestalt, arbeiten unveraendert weiter. Das gilt fuer Plaketten und Raidzellen gleichermassen, beide laufen ueber `FBHealBox_ButtonUsable`.
- **Stattdessen laeuft er als Uhr mit.** Ihn gar nicht zu zeigen war die andere Haelfte der Ungereimtheit: Ein Instant wie Erneuerung oder Krankheit aufheben liess alle Buttons unberuehrt, waehrend Machtwort: Schild, das in 1.12 eine echte Abklingzeit hat, eine Uhr zeigte. Die Uhr ist die ruhige Art, eine kurze Wartezeit anzuzeigen: Nach jedem Zauber laeuft sie auf allen Buttons ab, so wie es die Aktionsleisten machen.
- **Zwei Schwellen statt einer.** Die Anzeigeschwelle sitzt jetzt in einer eigenen Konstante `FBCD_SHOW_MIN` (0, also jede laufende Abklingzeit zeigen) und haengt nicht mehr an `FBCD_MIN_DURATION` (2), die nur noch beantwortet, ob eine Abklingzeit ein Grund zum Abdunkeln ist. Vorher war beides derselbe Wert, deshalb liess sich "globalen Cooldown zeigen" und "wegen ihm nicht abdunkeln" nicht gleichzeitig haben. Wer `FBCD_SHOW_MIN` auf 2 setzt, hat die ruhige Anzeige zurueck. Gezeigt wird ausserdem nur, wenn wirklich eine Abklingzeit laeuft (`cd[1] > 0`), und die Uhr startet im naechsten Frame, weil der Button-Durchgang nicht gedrosselt ist.


## 1.4.5 (2026-09-08)

Three additions around the frames and the prediction: Blizzard's party frames can go away, the resource bar is no longer reserved for mana, and gear healing is counted where an API can supply it. Plus a performance pass with no change in behaviour.

### English

**New & Changed**

- **Hide Blizzard party frames.** New switch on the *General* tab that hides `PartyMemberFrame1` to `4` while you are grouped, leaving only the Heal Box plates. Off by default. Blizzard shows those frames again on every roster change, so the addon hooks their `OnShow` once instead of hiding them a single time; a frame that reappears is hidden again in the same moment.
- **Mutually exclusive with the attach mode.** *Default party frames* docks the plates onto exactly those frames, so the two options can never both be on. Whichever one is ticked disables and greys out the other (`FBHealBox_UpdatePartyExclusion`), and `FBHealBox_HideBlizzPartyActive()` re-checks the same rule in code for saved settings that were edited by hand. Switching the option off brings the frames back immediately, and so does the class gate: an addon that stays asleep for warriors, rogues and hunters returns the frames as well.
- **Rage, energy and focus in the resource bar.** The thin strip under the health bar used to be reserved for mana and stayed empty for everyone else. New switch *Show rage, energy, focus* on the *General* tab gives every unit its own resource in its usual colour, from the new table `FBPOWER_COLORS`: mana blue, rage red, focus orange, energy yellow. `FBUnitMana()` now returns the power type as a fourth value, and both the plates and the raid cells colour their bar from it. Off by default, and it still needs the mana bar to be on.
- **Equipment healing bonus in the prediction.** Vanilla spell tooltips show the naked base value; the bonus from your gear is missing. Learned values from the combat log carry it automatically, so the gap only affected ranks you had never cast. `FBHealBox_ProbeHealBonus()` now looks for `GetSpellBonusHealing`, `GetSpellBonusHeal` and `GetHealingBonus`, first as globals and then inside a `ClassicAPI` table, and `FBPredict_ExpectedDirect()` adds the share that belongs to the spell.
- **Weighted the vanilla way.** The bonus counts as cast time divided by 3.5, capped at 3.5 seconds, with instants counting as 1.5 and an unreadable cast time as 2.5. Cast time is read once per spellbook slot from the tooltip (`FBHealBox_SpellCastSeconds`, right-hand side of line 2), so a 3 second Greater Heal takes 600 of a +700 bonus and a 1.5 second Flash Heal takes 300. Without a suitable API the bonus stays 0 and nothing about the old behaviour changes.
- **New command `/fbp healbonus`.** Turns the equipment bonus off and on, saved per character in `HealBox.HealBonus` (on by default). `/fbp` reports the value found and whether it is being applied; the command says so when no API supplies a bonus at all.

**Performance (no change in behaviour)**

- **Own buff timers read once per frame.** `FBPredict_PlayerBuffTimeLeft` used to walk the whole player buff list once per watched buff, calling `strupper` on every texture along the way: with six watches and thirty buffs that was around 200 API calls and 200 throwaway strings a second. The list is now read once per frame into a texture-to-seconds map (`FBPredict_ScanPlayerBuffTimes`), the way `FBHealBox_UnitBuffs` already worked, and every watch is served from it. Texture paths are upper-cased once and remembered (`FBHealBox_UpperTex`), which also removes the same allocation from the unit buff scan.
- **Range and line of sight in raid mode are spread over several ticks.** `FBRaid_Tick` used to check up to 40 cells in one frame every half second. It now walks a quarter of the groups per tick at a quarter of the interval (`FBRAID_TICK_SLICES`), so a full sweep still takes the same half second while the peak load per frame drops to a quarter.
- **`pcall` per sweep instead of per unit.** Range, distance and line of sight went through a protected call for every single unit, up to 160 a second in a full raid. The first successful call now marks the form as safe and the individual calls go straight through, while the sweep as a whole stays protected: one `pcall` per pass in `FBHealBox_CheckRangeAll`, `FBHealBox_CheckLOSAll` and `FBRaid_Tick`. A client that throws on the very first call keeps the old per-call protection and its fallback path.
- **Self-healing if an API throws late.** Should a sweep throw after the form had already proven itself, `FBHealBox_ApiFailed()` puts all three queries back to the protected single call, where the error is caught and the fallback takes over as before. The frame is never torn open, and at worst one pass is skipped.
- **Raid health text no longer builds strings it throws away.** The percentage and deficit texts were formatted before the change check, so every `UNIT_HEALTH` in a 40 man raid produced a string that was usually discarded immediately. The cell now compares the number and only formats on a real change, the way the plates always did.
- **Cheap pre-test before the combat log patterns.** Up to four anchored patterns ran on every message from twenty registered events. A plain substring test now filters first, with the words cut out of the client's own message templates so it works in every language. The tick test deliberately comes from the self template, because "You gain" and "%s gains" differ in the verb but share what follows.
- **Equipment bonus read once instead of per candidate.** With heal chains a single Smart Healing click asked the API for the bonus up to fifteen times. The value is now remembered and dropped again on `UNIT_INVENTORY_CHANGED` or a spellbook rebuild.
- **Cast time comes free with the spell scan.** `FBHealBox_SpellCastSeconds` used to build its own tooltip on a cache miss, which could mean a dozen tooltip builds in the middle of combat on the first click. `FBPredict_TooltipText` now picks the cast time off the right-hand side while the tooltip is standing anyway and fills the cache; the standalone scan remains only as a fallback. The cast time is deliberately kept out of the parsed text, because a number like 2.5 would confuse the shield duration and heal amount patterns.
- **Smaller things.** The range spell of the first assigned button is remembered instead of being searched over ten slots on every range check (invalidated on rebinding and on a spellbook rebuild). The ticker redraws on a fixed 0.03 second step instead of every frame (taken back in 1.4.5.1, it made the spark stutter). Blizzard's party frames are re-evaluated in the same collection point as the name updates instead of on every event of a burst. Two `or {}` fallbacks in loops no longer allocate a throwaway table.

### Deutsch

**Neu & Geaendert**

- **Blizzards Gruppenfenster ausblenden.** Neuer Schalter im Reiter *Allgemein*, der `PartyMemberFrame1` bis `4` versteckt, solange du in einer Gruppe bist, sodass nur die Plaketten der Heal Box uebrig bleiben. Standardmaessig aus. Blizzard zeigt diese Frames bei jeder Gruppenaenderung neu an, deshalb haengt sich das Addon einmalig in deren `OnShow` statt sie nur einmal zu verstecken; ein Frame, der wieder auftaucht, verschwindet im selben Moment erneut.
- **Schliesst sich mit dem Anheftmodus aus.** *Standard-Gruppenfenster* haengt die Plaketten genau an diese Frames, beide Optionen koennen also nie zusammen an sein. Was angehakt ist, sperrt und graut das andere aus (`FBHealBox_UpdatePartyExclusion`), und `FBHealBox_HideBlizzPartyActive()` prueft dieselbe Regel im Code noch einmal nach, fuer von Hand bearbeitete gespeicherte Werte. Ausschalten holt die Frames sofort zurueck, ebenso die Klassensperre: Ein Addon, das fuer Krieger, Schurken und Jaeger schlaeft, gibt die Frames mit zurueck.
- **Wut, Energie und Fokus im Ressourcenbalken.** Der schmale Streifen unter dem Lebensbalken war dem Mana vorbehalten und blieb bei allen anderen leer. Der neue Schalter *Wut, Energie, Fokus zeigen* im Reiter *Allgemein* gibt jeder Einheit ihre eigene Ressource in der gewohnten Farbe, aus der neuen Tabelle `FBPOWER_COLORS`: Mana blau, Wut rot, Fokus orange, Energie gelb. `FBUnitMana()` liefert die Energieart jetzt als vierten Rueckgabewert, Plaketten und Raidzellen faerben ihren Balken danach. Standardmaessig aus, und der Manabalken muss weiterhin an sein.
- **Heilbonus der Ausruestung in der Vorhersage.** Vanilla-Tooltips zeigen den nackten Grundwert, der Bonus der Ausruestung fehlt darin. Gelernte Werte aus dem Combatlog tragen ihn von selbst, die Luecke betraf also nur Raenge, die nie gewirkt wurden. `FBHealBox_ProbeHealBonus()` sucht jetzt nach `GetSpellBonusHealing`, `GetSpellBonusHeal` und `GetHealingBonus`, erst als globale Funktion, dann in einer `ClassicAPI`-Tabelle, und `FBPredict_ExpectedDirect()` schlaegt den Anteil auf, der auf den Zauber entfaellt.
- **Gewichtet wie in Vanilla ueblich.** Der Bonus zaehlt mit Zauberzeit geteilt durch 3,5, gedeckelt bei 3,5 Sekunden, Instants rechnen mit 1,5 und eine unlesbare Zauberzeit mit 2,5. Die Zauberzeit wird einmal je Zauberbuchplatz aus dem Tooltip gelesen (`FBHealBox_SpellCastSeconds`, rechte Seite der zweiten Zeile). Eine Grosse Heilung mit 3 Sekunden nimmt von +700 Heilung also 600 mit, eine Blitzheilung mit 1,5 Sekunden 300. Ohne passende API bleibt der Bonus 0 und am bisherigen Verhalten aendert sich nichts.
- **Neuer Befehl `/fbp healbonus`.** Schaltet den Ausruestungsbonus aus und wieder ein, gespeichert je Charakter in `HealBox.HealBonus` (Standard an). `/fbp` nennt den gefundenen Wert und ob er angewandt wird; der Befehl sagt es, wenn ueberhaupt keine API einen Bonus liefert.

**Leistung (ohne Funktionsaenderung)**

- **Eigene Bufflaufzeiten einmal je Frame.** `FBPredict_PlayerBuffTimeLeft` lief bisher je ueberwachtem Buff einmal durch die gesamte Buffliste und rief dabei fuer jede Textur `strupper` auf: bei sechs Wachen und dreissig Buffs rund 200 API-Aufrufe und 200 Wegwerf-Strings je Sekunde. Die Liste wird jetzt einmal je Frame in eine Tabelle Textur nach Sekunden gelesen (`FBPredict_ScanPlayerBuffTimes`), genau wie es `FBHealBox_UnitBuffs` schon vormacht, und alle Wachen bedienen sich daraus. Texturpfade werden einmal gross geschrieben und gemerkt (`FBHealBox_UpperTex`), was dieselbe Zuteilung auch aus dem Buffscan der Einheiten nimmt.
- **Reichweite und Sichtlinie im Raid auf mehrere Ticks verteilt.** `FBRaid_Tick` pruefte alle halbe Sekunde bis zu 40 Zellen in einem einzigen Frame. Jetzt kommt je Tick ein Viertel der Gruppen dran, dafuer viermal so oft (`FBRAID_TICK_SLICES`): Der volle Durchlauf dauert weiterhin eine halbe Sekunde, die Spitzenlast je Frame sinkt auf ein Viertel.
- **`pcall` je Durchlauf statt je Einheit.** Reichweite, Abstand und Sichtlinie liefen fuer jede einzelne Einheit durch einen geschuetzten Aufruf, im Vierzigerraid bis zu 160 je Sekunde. Der erste erfolgreiche Aufruf erklaert die Form jetzt fuer sicher und die Einzelaufrufe gehen direkt hinein, der Durchlauf als Ganzes bleibt aber geschuetzt: ein `pcall` je Durchgang in `FBHealBox_CheckRangeAll`, `FBHealBox_CheckLOSAll` und `FBRaid_Tick`. Ein Client, der schon beim ersten Aufruf wirft, behaelt den geschuetzten Einzelaufruf samt Rueckfallweg.
- **Selbstheilung, wenn eine API doch spaet wirft.** Wirft ein Durchlauf, obwohl die Form sich vorher bewaehrt hatte, stellt `FBHealBox_ApiFailed()` alle drei Abfragen auf den geschuetzten Einzelaufruf zurueck, wo der Fehler abgefangen wird und der Rueckfall wie frueher greift. Der Frame wird nie aufgerissen, schlimmstenfalls faellt ein Durchgang aus.
- **Kein HP-Text im Raid, der gleich wieder weggeworfen wird.** Prozent- und Deficit-Text wurden vor dem Vergleich gebaut, jedes `UNIT_HEALTH` im Vierzigerraid erzeugte also einen String, der meist sofort verfiel. Die Zelle vergleicht jetzt die Zahl und formatiert nur bei echter Aenderung, so wie es die Plaketten immer schon tun.
- **Billiger Vortest vor den Combatlog-Mustern.** Bei jeder Meldung aus zwanzig registrierten Ereignissen liefen bis zu vier verankerte Muster. Ein einfacher Textvergleich filtert jetzt vorweg, mit Wortstuecken, die aus den Meldungsvorlagen des Clients geschnitten werden und damit in jeder Sprache passen. Der Tick-Vortest kommt bewusst aus der Selbst-Vorlage, weil sich "You gain" und "%s gains" im Verb unterscheiden, im Rest aber gleich sind.
- **Ausruestungsbonus einmal statt je Kandidat.** Mit Heilketten fragte ein einziger Smart-Healing-Klick die API bis zu fuenfzehnmal nach dem Bonus. Der Wert wird jetzt gemerkt und bei `UNIT_INVENTORY_CHANGED` oder einem Neuaufbau des Zauberbuchs wieder verworfen.
- **Zauberzeit faellt beim Auslesen der Zauber mit ab.** `FBHealBox_SpellCastSeconds` baute bei einem Fehlgriff einen eigenen Tooltip, was beim ersten Klick mitten im Kampf ein Dutzend Tooltip-Aufbauten bedeuten konnte. `FBPredict_TooltipText` liest die Zauberzeit jetzt nebenbei von der rechten Seite ab, solange der Tooltip ohnehin steht, und fuellt den Zwischenspeicher; der eigene Scan bleibt nur als Rueckfall. Der Wert kommt bewusst nicht in den ausgewerteten Text, weil eine Zahl wie 2.5 die Muster fuer Schilddauer und Heilbetrag durcheinanderbraechte.
- **Kleinigkeiten.** Der Reichweiten-Zauber des ersten belegten Buttons wird gemerkt, statt bei jeder Pruefung ueber zehn Plaetze zu suchen (verworfen beim Umbelegen und beim Neuaufbau des Zauberbuchs). Der Ticker zeichnet in einem festen Takt von 0,03 Sekunden statt in jedem Frame (in 1.4.5.1 zurueckgenommen, der Funke ruckelte dadurch). Blizzards Gruppenfenster werden im selben Sammelpunkt wie die Namen neu bewertet statt bei jedem Ereignis einer Salve. Zwei `or {}`-Rueckfaelle in Schleifen legen keine Wegwerf-Tabelle mehr an.


## 1.4.4.3 (2026-09-08)

Class gate, heal chains and a Smart Healing fix. The addon no longer loads its display for warriors, rogues and hunters, Smart Healing keeps its hands off heal over time spells, and downranking may now switch spell inside a heal chain.

### English

**New & Changed**

- **Smartcross option in UI.** Added a *Smartcross* checkbox under Smart Healing in the *Buttons* tab. It is automatically enabled/disabled and grayed out based on the Smart Healing master switch (also toggleable via `/fbp smartcross`).
- **Streamlined Smart Healing tooltip.** Overhauled the options tooltip for Smart Healing across all languages. Replaced the screen-filling block of text with a compact, readable bullet-point summary of key rules.
- **Priest heal chain cleaned.** Completely removed *Flash Heal* from the Priest heal chain (`Lesser Heal · Heal · Greater Heal`). Flash Heal is preserved as a dedicated fast emergency heal and is never swapped into from Greater Heal or Heal.
- **Downranking across spells.** Until now Smart Healing only ever lowered the rank of the spell on the button, so Greater Heal (rank 4) could become Greater Heal (rank 1) but never Lesser Heal (rank 3), even though that would have covered the deficit for a fraction of the mana. Every single-target direct heal of a class now forms a *heal chain*, and the whole chain is searched: Priest `Lesser Heal · Heal · Greater Heal`, Paladin `Flash of Light · Holy Light`, Shaman `Lesser Healing Wave · Healing Wave`, Druid `Healing Touch`. The candidate with the smallest expected heal that still covers the need wins.
- **The button never gets stronger.** Nothing that heals more than the rank you assigned is ever chosen, and a tie keeps the assigned spell. Note that the cast time can change: for a small deficit a Greater Heal click may come out as Lesser Heal, and Holy Light as Flash of Light.
- **What stays out of the chains.** Group heals (Prayer of Healing, Chain Heal), fast emergency heals (Flash Heal), HoTs (Renew, Rejuvenation, Regrowth), shields and cooldown spells (Holy Shock, Lay on Hands) are never swapped. The chains sit in `FBHealChains` and can be edited freely; German spell names are included, with special characters stored as byte sequences for both Latin-1 and UTF-8 clients.
- **New command `/fbp smartcross`.** Turns chain switching off and on, saved per character in `HealBox.SmartCross` (on by default). With it off, Smart Healing stays on the assigned spell and only lowers its rank. `/fbp` shows the state next to the Smart Healing line, and the command says so when Smart Healing itself is still off.
- **Class gate for warriors, rogues and hunters.** The addon is built for healing and buffing, and those three classes get nothing out of it: no heals, no heal prediction, and a mana ticker with either no mana to watch (rage, energy) or nobody to heal (hunter). Logging in on one of them now leaves the whole display switched off: no plates, no raid grid, no minimap button, no options window. All event handlers and `OnUpdate` loops of the core and of the raid, ticker and Smart Damage modules return immediately (`FBAddonSuppressed`), so the addon costs nothing while it sleeps. Two lines in the chat explain what happened and how to change it.
- **New command `/fbp forceload`.** Shows the addon on a blocked class anyway. It starts immediately, without `/reload`, and the setting is kept per character in `HealBox.ForceLoad`. The same command switches it back off. On every other class the command reports that it is not needed. While the addon sleeps, every other `/fbp` command answers with the same hint instead of reporting on a display that was never built.
- **Class detection.** Uses the client's English class token (`WARRIOR`, `ROGUE`, `HUNTER`) with a fallback to the displayed class name in five languages, plus a last resort over the power type (rage and energy are never mana classes).
- **New hook `Suppress`.** Modules hide their own frames when the core goes to sleep; the raid module hides the grid, the ticker hides its sparks.
- **Startup message moved.** The greeting and the modules' `Loaded` hooks now run on `ADDON_LOADED` / `VARIABLES_LOADED` instead of `FBHealBox_OnLoad`, so the saved language is applied and nothing is announced for a class that stays asleep.
- **Rank rules generalised.** The upper limit is no longer "never above the assigned rank" but "never more expected healing than the assigned rank", which is the same thing inside one spell and the right rule across spells. A rank whose tooltip cannot be read is now skipped instead of ending the search.

**Fixed**

- **Smart Healing no longer downranks heal over time spells.** Renew, Rejuvenation, Regrowth, Tranquility, Lifebloom, Wild Growth, Riptide and Earth Shield now always go out at the assigned rank, for every class. A HoT spreads its healing over many seconds, so the health missing at the moment of the click says nothing about which rank fits, and a downranked HoT keeps ticking too weakly for its whole duration. Mixed spells such as Regrowth count as HoTs as well.
- **HoT detection** The new `FBHealBox_IsHoT()` checks the name list `FBHoTSpells` (English and German names, umlauts stored as byte sequences for both Latin-1 and UTF-8 clients), the tooltip evaluation (`info.hot`), the spell watch (`hasHoT`) and the HoTs currently running from the combat log. The exception therefore also applies to spells that are not in the list, for instance on custom servers. In addition the per-rank check now rejects any rank with a HoT portion.

---

### Deutsch

**Neu & Geaendert**

- **Smartcross im Optionsfenster.** Checkbox unter Smart Healing im Reiter *Buttons* hinzugefügt. Sie steuert das zauberübergreifende Abrangen in Heilketten und wird dynamisch gesperrt und ausgegraut, wenn Smart Healing deaktiviert ist (weiterhin auch per `/fbp smartcross` schaltbar).
- **Gestraffter Smart-Healing-Tooltip.** Der bisherige riesige Fließtextblock im Optionsfenster wurde in allen Sprachen durch eine übersichtliche, stichpunktartige Zusammenfassung der Kernregeln ersetzt. Der Tooltip sprengt damit nicht mehr den Bildschirm.
- **Priester-Heilkette bereinigt.** *Blitzheilung* (*Flash Heal*) vollständig aus der Priesterkette entfernt (`Geringes Heilen · Heilen · Große Heilung`). Blitzheilung bleibt ein reiner schneller Notfallzauber und wird von Großer Heilung / Heilen nie ungewollt ausgewählt.
- **Abrangen ueber Zaubergrenzen.** Bisher senkte Smart Healing nur den Rang des Zaubers auf dem Button: Aus Große Heilung (Rang 4) konnte Große Heilung (Rang 1) werden, nie aber Geringes Heilen (Rang 3), obwohl das den Fehlbetrag für einen Bruchteil des Manas gedeckt hätte. Alle Einzelziel-Direktheilungen einer Klasse bilden nun eine *Heilkette*, und die ganze Kette wird durchsucht: Priester `Geringes Heilen · Heilen · Große Heilung`, Paladin `Blitz des Lichts · Heiliges Licht`, Schamane `Geringe Welle der Heilung · Welle der Heilung`, Druide `Heilende Berührung`. Gewonnen hat der Kandidat mit der kleinsten erwarteten Heilung, die den Bedarf noch deckt.
- **Der Button wird nie staerker.** Nie gewählt wird etwas, das mehr heilt als der belegte Rang; bei Gleichstand bleibt es beim belegten Zauber. Die Zauberzeit kann sich dabei ändern: Bei kleinem Fehlbetrag wird aus einem Klick auf Große Heilung ein Geringes Heilen, aus Heiligem Licht ein Blitz des Lichts.
- **Was draussen bleibt.** Gruppenheilungen (Gebet der Heilung, Kettenheilung), schnelle Notfallzauber (Blitzheilung), HoTs (Erneuerung, Verjüngung, Nachwachsen), Schilde und Zauber mit Abklingzeit (Heiliger Schock, Handauflegung) werden nie getauscht. Die Ketten stehen in `FBHealChains` und lassen sich frei bearbeiten; die deutschen Zaubernamen sind enthalten, Sonderzeichen als Bytefolge für Latin-1- und UTF-8-Clients.
- **Neuer Befehl `/fbp smartcross`.** Schaltet den Kettenwechsel aus und wieder ein, gespeichert je Charakter in `HealBox.SmartCross` (Standard an). Aus bleibt Smart Healing beim belegten Zauber und senkt nur dessen Rang. `/fbp` zeigt den Zustand neben der Smart-Healing-Zeile, und der Befehl weist darauf hin, wenn Smart Healing selbst noch aus ist.
- **Klassensperre fuer Krieger, Schurke und Jaeger.** Das Addon ist fürs Heilen und Buffen gebaut, diese drei Klassen haben nichts davon: keine Heilzauber, keine Heilvorhersage, und ein Mana-Ticker, der entweder kein Mana zu beobachten hat (Wut, Energie) oder niemanden zu heilen (Jäger). Wer sich damit einloggt, bekommt die Anzeige nun gar nicht mehr zu sehen: keine Plaketten, kein Raid-Raster, kein Minimap-Button, kein Optionsfenster. Sämtliche Event-Handler und `OnUpdate`-Schleifen des Kerns und der Module Raid, Ticker und Smart Damage steigen sofort aus (`FBAddonSuppressed`), das Addon kostet im Ruhezustand also nichts. Zwei Zeilen im Chat erklären, was passiert ist und wie man es ändert.
- **Neuer Befehl `/fbp forceload`.** Zeigt das Addon bei einer gesperrten Klasse trotzdem an. Es startet sofort, ohne `/reload`, und die Einstellung bleibt je Charakter in `HealBox.ForceLoad` gespeichert. Derselbe Befehl schaltet wieder aus. Bei jeder anderen Klasse meldet der Befehl, dass er nicht nötig ist. Solange das Addon ruht, antworten alle übrigen `/fbp`-Befehle mit demselben Hinweis, statt über eine Anzeige zu berichten, die nie aufgebaut wurde.
- **Klassenerkennung.** Über das englische Klassen-Token des Clients (`WARRIOR`, `ROGUE`, `HUNTER`), mit Rückfall auf den angezeigten Klassennamen in fünf Sprachen und als letzter Notnagel über den Energietyp (Wut und Energie sind nie Manaklassen).
- **Neuer Hook `Suppress`.** Module blenden ihre eigenen Rahmen aus, wenn der Kern schlafen geht: Das Raidmodul versteckt das Raster, der Ticker seine Funken.
- **Startmeldung verschoben.** Begrüßung und die `Loaded`-Hooks der Module laufen jetzt bei `ADDON_LOADED` / `VARIABLES_LOADED` statt in `FBHealBox_OnLoad`. So gilt die gespeicherte Sprache, und bei einer schlafenden Klasse meldet sich niemand.
- **Rangregel verallgemeinert.** Die Obergrenze heißt nicht mehr "nie über dem belegten Rang", sondern "nie mehr erwartete Heilung als der belegte Rang". Innerhalb eines Zaubers ist das dasselbe, über Zaubergrenzen hinweg ist es die richtige Regel. Ein Rang, dessen Tooltip sich nicht lesen lässt, wird jetzt übersprungen, statt die Suche zu beenden.

**Behoben**

- **Smart Healing rangt keine HoTs mehr ab.** Erneuerung, Verjüngung, Nachwachsen, Gelassenheit, Lebensblüte, Wildwuchs, Springflut und Erdschild gehen nun immer im belegten Rang raus, bei jeder Klasse. Ein HoT verteilt seine Heilung über viele Sekunden, das im Moment des Klicks fehlende Leben sagt also nichts darüber aus, welcher Rang passt, und ein abgerangter HoT tickt die volle Laufzeit zu schwach. Gemischte Zauber wie Nachwachsen zählen ebenfalls als HoT.
- **HoT Erkennung** Die neue Funktion `FBHealBox_IsHoT()` prüft die Namensliste `FBHoTSpells` (englische und deutsche Namen, Umlaute als Bytefolge für Latin-1- und UTF-8-Clients), die Tooltip-Auswertung (`info.hot`), die Zauberwache (`hasHoT`) und die gerade aus dem Combatlog laufenden HoTs. Die Ausnahme greift damit auch bei Zaubern, die nicht in der Liste stehen, etwa auf abweichenden Servern. Zusätzlich weist die Rangprüfung jeden Rang mit HoT-Anteil ab.

## 1.4.4.2 (2026-09-07)

Buff duration display update & bugfix. Replaces the 4-quadrant clock division for buff icons with a 32-step vertical duration wipe, offering much finer timer resolution, and fixes an <eof> syntax error when loading.

### English

**New & Changed**

- **32-step buff icon duration display.** The buff icons left of the health bar previously divided the remaining duration into 4 coarse quadrants (quarters). They now transition in 32 fine vertical steps (`FBBUFFICON_STEPS = 32`) from top to bottom. As a buff expires, the top portion is progressively desaturated and darkened in 32 increments. For a 30-minute buff like *Power Word: Fortitude* or *Divine Spirit*, the visual display now updates approximately every 56 seconds rather than once every 7.5 minutes.
- **Optimised texture usage.** Replaced the 4 quadrant textures and 4 wash textures per buff icon with a single dynamically cropped desaturated overlay (`ic.qTex`) and dark wash (`ic.wTex`), reducing texture objects by 75 % per buff icon while increasing visual granularity eightfold.
- **Shortened addon notes.** Better display in WoW-Launcher addon managers.


### Deutsch

**Neu & Geaendert**

- **32-Stufen-Ablaufanzeige fuer Buff-Icons.** Die Buff-Symbole links neben dem Lebensbalken teilten die Restlaufzeit bisher in 4 grobe Bloecke (Quadranten) auf. Dies wurde auf 32 feine Ablaufstufen (`FBBUFFICON_STEPS = 32`) von oben nach unten umgestellt. Bei ablaufender Restzeit wird das Icon in 32 Teilschritten von oben nach unten schrittweise entsaettigt (schwarz-weiss) und abgedunkelt. Bei einem 30-Minuten-Buff (z. B. *Machtwort: Seelenstaerke*) aktualisiert sich die visuelle Anzeige nun ca. alle 56 Sekunden statt nur alle 7,5 Minuten.
- **Ressourcenschonende Textur-Struktur.** Statt 4 separaten Quadranten-Texturen und 4 Abdunklungs-Overlays nutzt jedes Icon nun nur noch je eine dynamisch skalierte und beschnittene Overlay-Textur (`ic.qTex` und `ic.wTex`). Das spart 75 % der Texturobjekte pro Icon ein und erhoeht gleichzeitig die Anzeigegenauigkeit um das Achtfache.
- **Addon Beschreibung eingekuerzt** Fuer bessere Übersicht in WoW-Launchern.


## 1.4.4.1 (2026-09-06)

Buff tracking & class spells update. Fixes buff clock icons (Divine Spirit, etc.) not appearing next to the health bar, adds group buff alternate matching, and completes the spell selection lists across all healer classes with buffs, utility and rez spells.

### English

**Fixed**

- **Buff tracking & Tooltip scanning.** In Vanilla 1.12.1, `ClearLines()` on the hidden scan tooltip (`FBHealBoxScanTip`) does not clear hidden text lines. Because `FBPredict_TooltipText` did not check `fs:IsShown()`, leftover lines from previously scanned heal spells (e.g. "Heals a friendly target...") lingered and were read when inspecting buff tooltips like *Divine Spirit*. This erroneously flagged `info.isHeal = true`, skipping buff duration detection (`info.buff`) and causing *Divine Spirit* not to display its clock icon and timer in the plate UI.
- **Group buff alternate detection.** `FBPredict_BuildWatch` and `FBPredict_ScanUnit` now track group buff variants (`altTex`). When a group buff is applied or present (*Prayer of Fortitude*, *Prayer of Spirit*, *Gift of the Wild*, *Greater Blessings*), the addon correctly recognises the aura, confirms pending casts, and displays the buff clock icon.
- **Buff watch textures.** `FBLoadSpellData` now flags all spells in `FBBuffWatchSpells` as addon spells (`isHealBoxSpell = true`), ensuring their textures and ranks are gathered and monitored even if they are not yet assigned to a heal button.
- **Drag & drop instant sync.** Dropping a spell onto a button now immediately calls `FBPredict_BuildWatch()`, updating tracked buffs and predictions without requiring a `/reload`.

**New & Changed**

- **Expanded class spell lists.** Greatly expanded `Spell.Name` for all classes so that all relevant buffs, utility spells, dispels, and resurrections appear in the cascading spell menus:
  - **Priest:** Added *Power Word: Fortitude*, *Prayer of Fortitude*, *Divine Spirit*, *Prayer of Spirit*, *Shadow Protection*, *Prayer of Shadow Protection*, *Fear Ward*, *Power Infusion*, *Resurrection*.
  - **Druid:** Added *Mark of the Wild*, *Gift of the Wild*, *Thorns*, *Tranquility*, *Innervate*, *Rebirth*, *Cure Poison*.
  - **Paladin:** Added all normal and Greater Blessings (*Wisdom, Might, Kings, Salvation, Light, Sanctuary*), *Blessing of Freedom*, *Blessing of Sacrifice*, *Redemption*, *Divine Intervention*.
  - **Shaman:** Added *Ancestral Spirit*, *Purge*, *Water Walking*, *Water Breathing*, *Water Shield*.
  - Added optional support for **Mage** (*Remove Lesser Curse*, *Arcane Intellect*, *Arcane Brilliance*, *Dampen Magic*, *Amplify Magic*) and **Warlock** (*Unending Breath*, *Detect Invisibility*).
- **Fear Ward in Buff Watch.** Added *Fear Ward* to `FBBuffWatchSpells` for Priests.

### Deutsch

**Behoben**

- **Buff-Erkennung & Tooltip-Scan.** Im 1.12.1-Client leert `ClearLines()` auf dem versteckten Scan-Tooltip (`FBHealBoxScanTip`) ausgeblendete Textzeilen nicht. Da `FBPredict_TooltipText` nicht pruefte, ob eine Zeile sichtbar ist (`fs:IsShown()`), wurden Textzeilen zuvor gescannter Heilzauber (z. B. „Heals a friendly target...") faelschlicherweise auch bei Buff-Tooltips wie *Goettlicher Willen* (*Divine Spirit*) mitgelesen. Dadurch wurde fehlerhaft `isHeal = true` gesetzt, was die Erkennung der Buff-Laufzeit (`info.buff`) verhinderte und dazu fuehrte, dass das Buff-Icon links am Lebensbalken nicht erschien.
- **Erkennung von Gruppen-Buffs.** `FBPredict_BuildWatch` und `FBPredict_ScanUnit` unterstuetzen nun Gruppenversionen (`altTex`). Gruppen-Buffs (*Gebet der Seelenstaerke*, *Gebet der Willenskraft*, *Gabe der Wildnis*, *Grosse Segen*) werden nun zuverlaessig bestaetigt und mit Laufzeit/Icon dargestellt.
- **Buff-Wache Texturen.** `FBLoadSpellData` markiert nun alle Zauber aus `FBBuffWatchSpells` automatisch als Addon-Zauber (`isHealBoxSpell = true`), sodass ihre Texturen und Daten auch dann geladen und getrackt werden, wenn sie noch auf keinem Button liegen.
- **Drag & Drop Sofort-Synchronisation.** Das Ablegen eines Zaubers auf einen Button ruft nun direkt `FBPredict_BuildWatch()` auf, sodass neue Buffs und Vorhersagen ohne `/reload` sofort aktiv sind.

**Neu & Geaendert**

- **Vollstaendige Klassen-Zauberlisten.** `Spell.Name` fuer alle Heilerklassen stark erweitert, sodass saemtliche Heiler-Buffs, Gruppen-Buffs, Hilfszauber und Wiederbelebungen in den Auswahlmenues verfuegbar sind:
  - **Priester:** *Machtwort: Seelenstaerke*, *Gebet der Seelenstaerke*, *Goettlicher Willen*, *Gebet der Willenskraft*, *Schattenschutz*, *Gebet des Schattenschutzes*, *Furchtzauberschutz*, *Seele der Macht*, *Auferstehung* hinzugefuegt.
  - **Druide:** *Mal der Wildnis*, *Gabe der Wildnis*, *Dornen*, *Gelassenheit*, *Anregen*, *Wiedergeburt*, *Vergiftung heilen* hinzugefuegt.
  - **Paladin:** Alle normalen und Grossen Segen (*Weisheit, Macht, Koenige, Rettung, Licht, Schutz*), *Segen der Freiheit*, *Segen der Opferung*, *Erloesung*, *Goettliches Eingreifen* hinzugefuegt.
  - **Schamane:** *Geist der Ahnen*, *Reinigen*, *Wasserwandeln*, *Wasseratmung*, *Wasserschild* hinzugefuegt.
  - Zusaetzliche Unterstuetzung fuer **Magier** (*Geringen Fluch aufheben*, *Arkane Intelligenz*, *Arkane Brillanz*, *Magie daempfen*, *Magie verstaerken*) und **Hexenmeister** (*Unendlicher Atem*, *Unsichtbarkeit entdecken*) ergaenzt.
- **Furchtzauberschutz in Buff-Wache.** *Fear Ward* fuer Priester in `FBBuffWatchSpells` aufgenommen.


## 1.4.4 (2026-09-06)

Performance pass. No feature was added or changed; every visible behaviour is meant to be identical. A simulated five-second raid fight (40 players, aura and health events, mana changes, combat log, 60 frames per second) went from about 63,900 API and widget calls to about 14,450, a reduction of 77 %.

### English

**Changed (internals)**

- **Button states centralised.** The up to 260 heal buttons (10 plates x 10, 40 raid cells x 4) no longer carry their own `SPELL_UPDATE_USABLE` / `SPELL_UPDATE_COOLDOWN` handlers. One pass over the *visible* buttons queries usability and cooldown once per spell id and range once per button, and sets colours and cooldown sweeps only when the state changes. Several such events within one frame are merged into one pass.
- **Display caches.** Health text, bar maxima, bar values, bar colour and mana strip visibility are only written when they change. Dispellable debuffs are searched on `UNIT_AURA` only; `UNIT_HEALTH` and the prediction tick reuse the last result.
- **Aura scans shared.** A unit's buff textures are read once per frame and shared between the heal prediction and the buff watch. Buff names resolved through tooltip scans are remembered per texture, so a unit missing the watched buff no longer costs up to 32 tooltip scans per aura event. Raid units are only scanned when something depends on them (own cast pending, tracked HoT or shield, or a visible cell).
- **Cheaper ticks.** Spell timers use precomputed base spell names instead of string parsing per button per tick and skip units without tracked HoTs or shields. Buff icons reuse their work tables, iterate a presorted list instead of sorting per tick, and update on change or once a second instead of five times a second. The attacked-member check skips entirely while there is no hostile target and nothing is marked, and compares names before calling `UnitIsUnit`.
- **Event bursts coalesced.** `PARTY_MEMBERS_CHANGED`, `UNIT_PET` and `RAID_ROSTER_UPDATE` set a flag that is processed once in the next frame instead of rebuilding plates and grid for every event of a burst.
- **Mana ticker.** Enabled/mana/full checks moved from every frame to mana events and option changes; the spark is re-anchored only when it has moved at least half a pixel; sizes and visibility are cached.
- **Combat log.** Heal patterns run only for buff events, the absorb pattern only for hit events that contain the word absorbed. Smart Damage parses damage lines only while enabled and while there is a target being measured or an own cast waiting; its live target line is refreshed only while the options window is open.
- Raid test ghost animation frame is hidden outside the raid test instead of running an empty update every frame.
- **Client API compatibility.** `IsSpellInRange` and `IsUsableSpell` do not exist in the 1.12 client (they came with 2.0). All range and usability checks now go through wrappers that use them when a client offers them and otherwise fall back to 1.12 means: spell range from the tooltip against `UnitXP("distanceBetween")` where available, else `CheckInteractDistance` (28 m, beyond that undecided rather than red); mana cost from the tooltip against your current mana. Because clients differ (2.0 style `(id, "spell", unit)` versus the Turtle client's `(name, unit)`), the addon probes both signatures once at login with `pcall` and uses the one the client understands; a function that keeps throwing is switched off in favour of the fallback. `/fbp` reports the detected form. Without this the new central button pass crashed at login.

**Fixed**

- The old per-button event handler declared `this`, `event` and `arg1` as parameters, which shadowed the 1.12 globals; range colouring and cooldown sweeps on the buttons never worked in the game. They do now.

### Deutsch

**Geaendert (intern)**

- **Button-Zustaende zentral.** Die bis zu 260 Heil-Buttons (10 Plaketten x 10, 40 Raid-Zellen x 4) tragen keine eigenen `SPELL_UPDATE_USABLE`/`SPELL_UPDATE_COOLDOWN`-Handler mehr. Ein Durchgang ueber die *sichtbaren* Buttons fragt Nutzbarkeit und Cooldown je Zauber-ID einmal und die Reichweite je Button ab und setzt Farben und Cooldown-Uhren nur bei Zustandswechsel. Mehrere solche Events in einem Frame werden zu einem Durchgang zusammengefasst.
- **Anzeige-Zwischenspeicher.** Lebenstext, Balkenmaxima, Balkenwerte, Balkenfarbe und Sichtbarkeit des Manastreifens werden nur geschrieben, wenn sie sich aendern. Entfernbare Debuffs werden nur bei `UNIT_AURA` gesucht; `UNIT_HEALTH` und der Vorhersage-Tick nutzen den letzten Befund.
- **Aura-Scans gemeinsam.** Die Buff-Texturen einer Einheit werden je Frame einmal gelesen und von Heilvorhersage und Buff-Wache geteilt. Per Tooltip ermittelte Buffnamen werden je Textur gemerkt, sodass eine Einheit ohne den ueberwachten Buff nicht mehr bis zu 32 Tooltip-Scans je Aura-Event kostet. Raid-Einheiten werden nur gescannt, wenn etwas davon abhaengt (eigener Cast wartet, HoT oder Schild verfolgt, sichtbare Zelle).
- **Guenstigere Ticks.** Zauber-Timer nutzen vorberechnete Basisnamen statt String-Parsing je Button und Tick und ueberspringen Einheiten ohne verfolgten HoT oder Schild. Buff-Icons verwenden ihre Arbeitstabellen wieder, laufen ueber eine vorsortierte Liste statt je Tick zu sortieren und aktualisieren bei Aenderung oder einmal je Sekunde statt fuenfmal. Der Angegriffenen-Abgleich entfaellt ganz, solange kein feindliches Ziel besteht und nichts markiert ist, und vergleicht Namen, bevor `UnitIsUnit` gerufen wird.
- **Event-Salven zusammengefasst.** `PARTY_MEMBERS_CHANGED`, `UNIT_PET` und `RAID_ROSTER_UPDATE` setzen ein Kennzeichen, das im naechsten Frame einmal abgearbeitet wird, statt Plaketten und Raster bei jedem Event einer Salve neu aufzubauen.
- **Mana-Ticker.** Die Pruefungen an/Mana/voll laufen bei Mana-Events und Optionswechseln statt jeden Frame; der Funke wird nur neu verankert, wenn er sich mindestens einen halben Pixel bewegt hat; Groessen und Sichtbarkeit sind zwischengespeichert.
- **Combatlog.** Heilmuster laufen nur bei Buff-Events, das Absorb-Muster nur bei Treffer-Events, die das Wort absorbed enthalten. Smart Damage liest Schadenszeilen nur, solange es an ist und ein Ziel vermessen wird oder ein eigener Cast wartet; die Live-Zielzeile wird nur bei offenem Optionsfenster aktualisiert.
- Der Animationsframe der Raid-Testgeister ist ausserhalb des Raid-Tests ausgeblendet, statt jeden Frame leer zu laufen.
- **Client-API-Kompatibilitaet.** `IsSpellInRange` und `IsUsableSpell` gibt es im 1.12-Client nicht (sie kamen mit 2.0). Alle Reichweiten- und Nutzbarkeitspruefungen laufen jetzt ueber Wrapper, die sie nutzen, wenn ein Client sie anbietet, und sonst auf 1.12-Mittel zurueckfallen: Zauberreichweite aus dem Tooltip gegen `UnitXP("distanceBetween")`, wo vorhanden, sonst `CheckInteractDistance` (28 m, jenseits davon unentschieden statt rot); Manapreis aus dem Tooltip gegen das eigene Mana. Weil Clients sich unterscheiden (2.0-Form `(id, "spell", unit)` gegenueber der Turtle-Form `(name, unit)`), probiert das Addon beide Signaturen beim Login einmal per `pcall` aus und nutzt die verstandene; eine Funktion, die weiter Fehler wirft, wird zugunsten des Rueckfalls abgeschaltet. `/fbp` meldet die erkannte Form. Ohne das brach der neue zentrale Button-Durchgang beim Login ab.

**Behoben**

- Der alte Button-Handler deklarierte `this`, `event` und `arg1` als Parameter und verdeckte damit die 1.12-Globals; Reichweitenfaerbung und Cooldown-Uhr auf den Buttons haben im Spiel nie gearbeitet. Jetzt tun sie es.


## 1.4.3 (2026-09-05)

### English

**New**

- **Languages.** Spanish, French and Italian added to all addon texts (English and German unchanged). The client locale picks the language automatically, the language button lists all five, missing keys fall back to English.
- **Mana ticker** (module `FBHealBox_Ticker.lua`, on by default). A spark travels across your own mana strip every 2 seconds in step with the server's regeneration tick; after spending mana it turns orange and runs the five-second rule down, extended to the first tick after the five seconds. Works on the party plate and on your own raid cell, hidden while mana is full. Detection via `UNIT_MANA` only: grid from observed ticks, re-sync within a tolerance, foreign pulses (totems, Innervate) ignored, potions and runes filtered by size. Own options tab *Ticker*: master switch, five-second rule, tick tolerance, tick offset, spark width. `/fbp ticker` toggles, `/fbp` reports sync state.
- **Smart Healing** (off by default). When on, a click casts the lowest rank of the assigned spell whose expected heal covers the target's missing health (minus incoming healing) plus a safety margin (default 20 %). Never above the assigned rank, direct heals only, always the assigned rank below 30 % health. Learned heal values are used where available. Downsides (no crits in the estimate, burst damage, deliberate overhealing) are explained in the tooltip. Options on the *Buttons* tab; `/fbp debug` logs each decision, `/fbp` shows the state.
- **Cooldown sweep on buttons**, global cooldown excluded. Option *Cooldowns on buttons*.
- **Red border for the attacked member**: the plate or raid cell of the unit your hostile target is targeting. Takes precedence over the buff-watch border. Option *Mark who is attacked*.
- **HoT and shield timers on buttons**: each spell's button shows the remaining seconds of your own HoT (green) or shield (blue) on that unit; after Power Word: Shield the button shows Weakened Soul in red. Option *HoT and shield timers*.
- **Smart Damage** (module `FBHealBox_Damage.lua`, off by default). Attack spells pressed on any action bar or key binding are cast in the lowest rank that still kills the target, never above the rank on the bar. Target health from the server (real values), MobHealth3, MobInfo-2, or the addon's own per-mob-type estimate learned from combat-log damage and percent drops (highest measurement kept). Minimum damage per rank from the tooltip, raised by observed full hits. Section on the *Extras* tab (shared with the ticker) with switch, safety margin, live health-source line and spell list; `/fbp damage`, decisions in `/fbp debug`.
- **Buff icons in the health bar**: buffs with a duration that sit on your buttons (Fortitude, Divine Spirit, Fear Ward, Inner Fire) appear as small 8 px icons on the outer left side of the plate. The icon is a clock: it turns black and white clockwise from twelve o'clock as the time runs out (half left = right half grey). Exact on yourself, counted from your own cast on others, fully coloured when cast by someone else. Raid cells show them outside their left edge; the grid reserves the room. Line-of-sight badge moved to the plate's top-left corner. Units are scanned once after login and group changes so existing buffs appear immediately. `/fbp buffs` for diagnostics. Option *Buff icons in the health bar*.
- Test-mode ghost Dorn demonstrates the red border and the timers.

**Fixed**

- Own buffs were only read at login and on group changes: Vanilla fires `PLAYER_AURAS_CHANGED` for the player instead of `UNIT_AURA`. The addon now listens to it and re-reads your remaining time on every change, and once a second in between (a refresh of a running buff fires no aura event at all), so recasting a buff on yourself resets its clock and cancelling it removes the icon. Refreshing a buff on someone else through a HealBox button is confirmed by the completed cast. Also fixes confirmation of your own HoTs and shields on yourself.
- Raid cell names and percentages were hidden behind the health bar since the bar levels became relative; the texts now live on their own layer above the bars.
- Buff icons stack two high left of the plate; elapsed clock quadrants are drawn dark on a layer above the icon so the split shows on every client. Raid cells use a 3 by 4 grid of 6 px icons (twelve slots); the new raid option *Show buffs* removes icons and strip together. `/fbp buffs` reports the grey count per icon.
- Test modes extended: party ghost Brynn is dead, pet Bramble carries a disease, Dorn carries six and raid ghost 12 twelve buffs, raid ghost 27 a disease. Up to six buff icons per plate.
- Plate names could sit too low on some rows (the name box grew to two lines internally). Name, paw icon and debuff icon are now vertically centred with a fixed one-line height.

- Tooltip parser took durations ("for 30 min", "again for 15 sec") for direct heal amounts, so buffs such as Power Word: Fortitude and the shield reported a tiny "heal" and Smart Healing downranked them. Durations are ignored now, and Smart Healing only touches spells whose tooltip describes a heal and that carry no absorb.

**Changed**

- Option tab buttons are 100 px wide (was 110) so that four tabs fit in the window; class icon shrunk so it no longer overlaps the tabs. Checkbox labels have a fixed width and end with an ellipsis when a translation is long; the tooltip carries the full text. The fourth tab is called *Extras* and holds the ticker and Smart Damage sections.
- Tooltip parser: only `hr`/`hour` count as hours; `Holy` no longer looks like a time unit.
- New core hooks `Loaded`, `Aggro`, `SpellTimers`, `Cooldowns` for modules.

### Deutsch

**Neu**

- **Sprachen.** Spanisch, Franzoesisch und Italienisch fuer alle Addon-Texte hinzugefuegt (Englisch und Deutsch unveraendert). Die Client-Sprache waehlt automatisch, der Sprachknopf listet alle fuenf, fehlende Schluessel fallen auf Englisch zurueck.
- **Mana-Ticker** (Modul `FBHealBox_Ticker.lua`, standardmaessig an). Ein Funke wandert alle 2 Sekunden im Takt des Regenerationsticks ueber deinen eigenen Manastreifen; nach Manaverbrauch wird er orange und laeuft die Fuenf-Sekunden-Regel herunter, verlaengert bis zum ersten Tick nach den fuenf Sekunden. Auf der Gruppenplakette und der eigenen Raid-Zelle, bei vollem Mana ausgeblendet. Erkennung nur ueber `UNIT_MANA`: Raster aus beobachteten Ticks, Neusynchronisation innerhalb einer Toleranz, fremde Pulse (Totems, Anregen) ignoriert, Traenke und Runen nach Groesse gefiltert. Eigener Options-Reiter *Ticker*: Hauptschalter, Fuenf-Sekunden-Regel, Tick-Toleranz, Tick-Vorlauf, Funkenbreite. `/fbp ticker` schaltet um, `/fbp` meldet den Synchronzustand.
- **Smart Healing** (standardmaessig aus). Eingeschaltet wirkt ein Klick den niedrigsten Rang des belegten Zaubers, dessen erwartete Heilung das fehlende Leben des Ziels (abzueglich eingehender Heilung) plus Sicherheitsaufschlag (Standard 20 %) deckt. Nie ueber dem belegten Rang, nur Direktheilungen, unter 30 % Leben immer der belegte Rang. Gelernte Heilwerte werden genutzt, wo vorhanden. Nachteile (keine Crits in der Schaetzung, Schadensspitzen, gewolltes Ueberheilen) erklaert der Tooltip. Optionen im Reiter *Buttons*; `/fbp debug` protokolliert jede Entscheidung, `/fbp` zeigt den Zustand.
- **Cooldown-Uhr auf den Buttons**, globaler Cooldown ausgenommen. Option *Cooldowns auf den Buttons*.
- **Roter Rahmen fuer den Angegriffenen**: Plakette oder Raid-Zelle der Einheit, die dein feindliches Ziel im Ziel hat. Hat Vorrang vor dem Buff-Wache-Rahmen. Option *Angegriffenen markieren*.
- **HoT- und Schild-Timer auf den Buttons**: Der Button jedes Zaubers zeigt die Restsekunden deines eigenen HoTs (gruen) oder Schilds (blau) auf dieser Einheit; nach Machtwort: Schild zeigt der Button rot die Geschwaechte Seele. Option *HoT- und Schild-Timer*.
- **Smart Damage** (Modul `FBHealBox_Damage.lua`, standardmaessig aus). Angriffszauber auf jeder Aktionsleiste oder Taste werden im niedrigsten Rang gewirkt, der das Ziel noch toetet, nie ueber dem Rang auf der Leiste. Ziel-Leben vom Server (echte Werte), MobHealth3, MobInfo-2 oder aus der eigenen Schaetzung je Mobtyp, gelernt aus Combatlog-Schaden und Prozentabfall (hoechste Messung zaehlt). Mindestschaden je Rang aus dem Tooltip, angehoben durch beobachtete Volltreffer. Abschnitt im Reiter *Extras* (gemeinsam mit dem Ticker) mit Schalter, Sicherheitsaufschlag, Live-Zeile zur Lebensquelle und Zauberliste; `/fbp damage`, Entscheidungen in `/fbp debug`.
- **Buff-Icons im Lebensbalken**: Buffs mit Laufzeit, die auf deinen Buttons liegen (Seelenstaerke, Goettlicher Willen, Furchtzauberschutz, Inneres Feuer), erscheinen als kleine 8-px-Icons aussen links neben der Plakette. Das Icon ist eine Uhr: Es wird im Uhrzeigersinn ab zwoelf Uhr schwarz-weiss, je weiter die Zeit ablaeuft (halbe Zeit = rechte Haelfte grau). Exakt bei dir selbst, ab deinem eigenen Cast bei anderen, ganz farbig bei fremdem Cast. Raid-Zellen zeigen sie aussen an ihrer linken Kante; das Raster haelt den Platz frei. Sichtlinien-Abzeichen in die linke obere Plattenecke verlegt. Nach Login und Gruppenwechsel werden alle Einheiten einmal gescannt, damit vorhandene Buffs sofort erscheinen. `/fbp buffs` zur Diagnose. Option *Buff-Icons im Lebensbalken*.
- Testmodus-Geist Dorn zeigt roten Rahmen und Timer.

**Behoben**

- Eigene Buffs wurden nur beim Login und bei Gruppenwechseln gelesen: Vanilla feuert fuer den Spieler `PLAYER_AURAS_CHANGED` statt `UNIT_AURA`. Das Addon hoert jetzt darauf und liest die eigene Restzeit bei jeder Aenderung neu, und dazwischen einmal je Sekunde (ein Refresh eines laufenden Buffs feuert gar kein Aura-Event), sodass ein Neucast auf dich selbst die Uhr zuruecksetzt und ein Wegklicken das Icon entfernt. Ein Refresh auf jemand anderen ueber einen HealBox-Button gilt mit dem abgeschlossenen Cast als bestaetigt. Behebt auch die Bestaetigung eigener HoTs und Schilde auf dir selbst.
- Namen und Prozente der Raid-Zellen lagen seit den relativen Balken-Ebenen hinter dem Lebensbalken; die Texte liegen jetzt auf einer eigenen Ebene ueber den Balken.
- Buff-Icons stapeln sich zu zweit links neben der Plakette; abgelaufene Uhr-Quadranten werden dunkel auf einer Ebene ueber dem Icon gezeichnet, damit die Teilung auf jedem Client sichtbar ist. Raid-Zellen nutzen ein 3-mal-4-Raster aus 6-px-Icons (zwoelf Plaetze); die neue Raid-Option *Buffs anzeigen* entfernt Icons und Streifen gemeinsam. `/fbp buffs` nennt je Icon die Zahl grauer Quadranten.
- Testmodi erweitert: Partygeist Brynn ist tot, Pet Bramble traegt eine Krankheit, Dorn traegt sechs und Raid-Geist 12 zwoelf Buffs, Raid-Geist 27 eine Krankheit. Bis zu sechs Buff-Icons je Plakette.
- Plakettennamen sassen in manchen Zeilen zu tief (die Namensbox wuchs intern auf zwei Zeilen). Name, Pfoten-Icon und Debuff-Icon sind jetzt mit fester Einzeilenhoehe vertikal zentriert.

- Der Tooltip-Leser hielt Zeitangaben ("for 30 min", "again for 15 sec") fuer Heilbetraege, wodurch Buffs wie Machtwort: Seelenstaerke und der Schild eine winzige "Heilung" meldeten und Smart Healing sie abgerangt hat. Zeitangaben werden jetzt uebersprungen, und Smart Healing fasst nur Zauber an, deren Tooltip eine Heilung beschreibt und die keinen Absorb haben.

**Geaendert**

- Reiterknoepfe der Optionen sind 100 px breit (vorher 110), damit vier Reiter ins Fenster passen; Klassen-Icon verkleinert, damit es die Reiter nicht mehr ueberlagert. Schalterbeschriftungen haben eine feste Breite und enden bei langen Uebersetzungen mit Auslassungspunkten; der Tooltip traegt den vollen Text. Der vierte Reiter heisst *Extras* und enthaelt Ticker und Smart Damage.
- Tooltip-Leser: Nur `hr`/`hour` zaehlen als Stunden; `Holy` sieht nicht mehr wie eine Zeiteinheit aus.
- Neue Kern-Hooks `Loaded`, `Aggro`, `SpellTimers`, `Cooldowns` fuer Module.

## 1.4.2 (2026-09-05)

### English

**New: raid mode** (module `FBHealBox_Raid.lua`, on by default, switches in automatically from 11 raid members; *Raid view from N players* is adjustable)

- Compact grid for 20 and 40 player raids: one cell per member in blocks of five per raid group, blocks arranged in rows (*Groups per row*). Empty groups collapse, so a 20-player raid is a single row.
- Each cell: name in class colour, health bar with shield and incoming-heal layers, 3 px mana strip, HP percent or deficit, dispel colouring, dead/ghost/offline text, range fading, line-of-sight eye, buff-watch border.
- Up to four mini buttons per cell, wired to Button 1 to N from the Buttons tab (right-click spells included). Click on a cell targets the unit (or unit menu / move / nothing, as configured for plates).
- Own options tab *Raid mode* with size, spacing, scale, headers, mana strip, HP text mode, title bar, hide-empty-groups and hide-party-plates switches.
- Raid test with 20 or 40 ghosts covering every visual state. `/fbp raid`, `/fbp raidtest 20|40|off`, raid line in `/fbp`.
- Grid position and scale are saved separately from the party plates. Party plates are hidden while the grid is up (switchable).

**New: drag and drop.** Spells can be dragged from the spellbook onto any heal button, raid mini button or options field. Right mouse button, or Shift held while dropping, fills the right-click side when that option is on. Spells outside the class list are accepted.

**Fixed**

- **Double loading.** The `.xml` included `FBHealBox.lua` a second time on top of the `.toc`. Every frame, hook and the options window existed twice. Visible effects: the raid tab was missing (added to the first, overwritten options window), Escape could crash the client (the second hook called itself), and learned absorb values were doubled (two prediction frames counted every absorb line). The `.xml` no longer loads scripts, and both Lua files refuse to run twice.
- Escape hook stores the original in a local upvalue, is installed at most once, and no longer uses a tail call.
- Learned absorb values above 1.5 times the tooltip are dropped on load; doubled values from earlier versions clean themselves up.

**Changed**

- Core gained a hook interface (`FBHealBox_RegisterHook`, `FBHealBox_AddOptionsTab`) so modules can attach without editing the core. No behaviour change for the party display.
- `.toc` now loads `FBHealBox_Raid.lua` after the core; removing that line disables raid mode entirely.

### Deutsch

**Neu: Raidmodus** (Modul `FBHealBox_Raid.lua`, standardmaessig an, schaltet ab 11 Raidmitgliedern automatisch um; *Raid-Ansicht ab N Spielern* ist einstellbar)

- Kompaktes Raster fuer 20er- und 40er-Raids: eine Zelle je Mitglied in Fuenferbloecken je Gruppe, die Bloecke in Zeilen (*Gruppen je Zeile*). Leere Gruppen fallen weg, ein 20er-Raid ist also eine einzige Zeile.
- Jede Zelle: Name in Klassenfarbe, Lebensbalken mit Schild- und Vorhersage-Schicht, 3 px Manastreifen, HP-Prozent oder Defizit, Dispel-Faerbung, Tot/Geist/Offline, Reichweiten-Fading, Sichtlinien-Auge, Buff-Wache-Rahmen.
- Bis zu vier Mini-Buttons je Zelle, belegt wie Button 1 bis N aus dem Reiter Buttons (Rechtsklick-Zauber inklusive). Klick auf die Zelle visiert an (oder Einheitenmenue / Verschieben / Nichts, wie fuer Plaketten eingestellt).
- Eigener Options-Reiter *Raidmodus* mit Groesse, Abstaenden, Skalierung, Gruppenkoepfen, Manastreifen, HP-Text-Modus, Titelleiste, Leere-Gruppen- und Plaketten-Ausblenden-Schaltern.
- Raid-Test mit 20 oder 40 Geistern, die jeden Anzeigezustand abdecken. `/fbp raid`, `/fbp raidtest 20|40|off`, Raid-Zeile in `/fbp`.
- Position und Skalierung des Rasters werden getrennt von den Plaketten gespeichert. Die Gruppenplaketten sind ausgeblendet, solange das Raster steht (abschaltbar).

**Neu: Drag & Drop.** Zauber lassen sich aus dem Zauberbuch auf jeden Heil-Button, Raid-Mini-Button oder jedes Optionsfeld ziehen. Die rechte Maustaste oder gehaltene Shift-Taste beim Ablegen fuellt die Rechtsklick-Seite, wenn die Option an ist. Zauber ausserhalb der Klassenliste werden angenommen.

**Behoben**

- **Doppeltes Laden.** Die `.xml` band `FBHealBox.lua` zusaetzlich zur `.toc` ein zweites Mal ein. Jeder Frame, jeder Hook und das Optionsfenster existierten doppelt. Sichtbare Folgen: der Raid-Reiter fehlte (an das erste, ueberschriebene Optionsfenster gehaengt), Escape konnte den Client zum Absturz bringen (der zweite Hook rief sich selbst auf), und gelernte Absorb-Werte waren verdoppelt (zwei Vorhersage-Frames zaehlten jede Absorb-Zeile). Die `.xml` laedt keine Skripte mehr, beide Lua-Dateien verweigern einen zweiten Durchlauf.
- Der Escape-Hook haelt das Original in einem lokalen Upvalue, wird hoechstens einmal gesetzt und nutzt keinen Tail-Call mehr.
- Gelernte Absorb-Werte ueber dem 1,5-fachen des Tooltips werden beim Laden verworfen; verdoppelte Werte aus frueheren Versionen bereinigen sich selbst.

**Geaendert**

- Der Kern hat eine Hook-Schnittstelle bekommen (`FBHealBox_RegisterHook`, `FBHealBox_AddOptionsTab`), damit Module andocken koennen, ohne den Kern zu aendern. Kein Verhaltensunterschied fuer die Gruppenanzeige.
- Die `.toc` laedt `FBHealBox_Raid.lua` nach dem Kern; wer die Zeile entfernt, hat keinen Raidmodus.

## 1.4.1 (2026-09-04)

### English

**New**

- **Pets.** Every pet in the group (`pet`, `partypet1` to `partypet4`) gets its own plate with the full set of heal buttons, stacked directly below its owner, indented by 12 px, with a paw icon and a light-blue name to tell it apart. Appears and disappears with `UNIT_PET`. Option *Show pets*.
- **Mana bar.** A 5 px blue bar along the bottom edge of the health bar ("bar in bar"), only for units whose power type is mana. Option *Mana bar*.
- **Button and row spacing.** Two sliders, 0 to 20 px each, for the gap between buttons and the gap between plates.
- **Test mode.** Fills the display with ghost players and pets (health, mana, shield, incoming heal, dispellable debuff, missing buff, out of range) so the layout can be arranged without a group. `/fbp test` or the checkbox. Not saved.
- **Options window with two tabs.** *Buttons* holds the button assignment, the button count and the right-click switch; *General* holds scale, spacing, all other switches, language and buff watch.
- **Right-click spell.** Every button can carry a second spell for right click. Off by default and only enabled through the *Buttons* tab; when on, a second column appears in the assignment and a small corner icon on each button shows the right-click spell. Assignments are kept when the switch is off.
- **Click on a plate.** Left and right click on a name or health bar target the unit by default. Both are configurable (*General* tab): Target, Unit menu, Move display, Nothing. Moving the display is now Shift + left drag (or the *Move display* action).
- **Dead / ghost / offline.** Shown as text in the bar instead of 0 %, with an empty grey bar and no mana strip.
- **Line of sight.** An eye badge on the plate's left edge while the unit is out of line of sight: live via the UnitXP client mod, otherwise inferred from the 'not in line of sight' error after your own heal attempt (8 s, cleared when a cast starts or a heal lands). Option *Line of sight*.
- **Debuff icon.** The icon of the first debuff your class can remove is shown next to the name, with its stack count. Option *Debuff icon*.
- **Class colours.** Names in class colour (client `RAID_CLASS_COLORS`, fallback table built in). Option *Class colours*.
- **Buff watch.** Pick one of your buffs; every plate whose unit is missing it gets an orange border. Group versions count as well, even when cast by another healer (texture check first, tooltip name scan as fallback). Pets are excluded unless *Buff watch on pets* is on.
- **Range fading.** Plates including their buttons fade to 50 % when the unit is out of range of your first assigned spell (28 yards without a spell). Option *Range fading*.
- **`/fbp config`** opens the options window; **Escape** closes it (registered in `UISpecialFrames`, plus a hook on `ToggleGameMenu` for clients that ignore that list). `/fbp` ends with a list of all commands.
- **Saved plate position.** The player plate keeps its position across reloads; scaling no longer moves it.

**Changed**

- All UNIT events run through one slot table (`FBPartyUnit`) instead of five copied handlers; `HealBoxAttachMode` and `FBUpdateNames` are loops.
- Spell buttons are created once and only re-assigned afterwards (previously rebuilt on every `SPELLS_CHANGED`, with random global names like `Button3`).
- Settings missing in an old saved-variables table are filled in on load (`FBHealBox_ApplyDefaults`).
- `UNIT_MAXHEALTH` is handled (was missing).

**Fixed**

- Documentation named a wrong client version; the addon targets client 1.12.1.
- Tooltip error on a button whose target does not exist.
- Division by zero for offline members (`UnitHealthMax` = 0).
- Plate position reset on every login.

### Deutsch

**Neu**

- **Begleiter.** Jeder Begleiter in der Gruppe (`pet`, `partypet1` bis `partypet4`) bekommt eine eigene Plakette mit allen Heil-Buttons, direkt unter seinem Besitzer, um 12 px eingerueckt, mit Pfoten-Icon und hellblauem Namen zur Unterscheidung. Kommt und geht mit `UNIT_PET`. Option *Begleiter anzeigen*.
- **Manabalken.** 5 px blau am unteren Rand des Lebensbalkens ("Balken im Balken"), nur bei Einheiten mit Powertyp Mana. Option *Manabalken*.
- **Button- und Zeilen-Abstand.** Zwei Regler, je 0 bis 20 px, fuer den Abstand der Buttons und den Abstand der Plaketten.
- **Testmodus.** Fuellt die Anzeige mit Geisterspielern und -begleitern (Leben, Mana, Schild, eingehende Heilung, entfernbarer Debuff, fehlender Buff, ausser Reichweite), damit sich alles ohne Gruppe einrichten laesst. `/fbp test` oder der Haken. Wird nicht gespeichert.
- **Optionsfenster mit zwei Reitern.** *Buttons* enthaelt die Belegung, die Buttonzahl und den Rechtsklick-Schalter; *Allgemein* enthaelt Skalierung, Abstaende, alle uebrigen Schalter, Sprache und Buff-Wache.
- **Rechtsklick-Zauber.** Jeder Button kann einen zweiten Zauber fuer Rechtsklick tragen. Standardmaessig aus und nur ueber den Reiter *Buttons* einschaltbar; eingeschaltet erscheint eine zweite Spalte in der Belegung und ein kleines Eck-Icon auf jedem Button zeigt den Rechtsklick-Zauber. Die Belegung bleibt bei ausgeschaltetem Schalter erhalten.
- **Klick auf die Plakette.** Links- und Rechtsklick auf Name oder Lebensbalken visieren die Einheit an (Standard). Beides belegbar (Reiter *Allgemein*): Anvisieren, Einheitenmenue, Anzeige verschieben, Nichts. Verschieben geht jetzt per Shift + Linksklick ziehen (oder Aktion *Anzeige verschieben*).
- **Tot / Geist / Offline.** Als Text im Balken statt 0 %, mit leerem grauem Balken und ohne Manastreifen.
- **Sichtlinie.** Augen-Abzeichen am linken Plattenrand, solange die Einheit ausserhalb der Sichtlinie ist: live ueber den Client-Mod UnitXP, sonst aus der Fehlermeldung 'nicht in Sichtlinie' nach einem eigenen Heilversuch abgeleitet (8 s, geloescht sobald ein Cast startet oder eine Heilung ankommt). Option *Sichtlinie*.
- **Debuff-Icon.** Das Icon des ersten von deiner Klasse entfernbaren Debuffs erscheint neben dem Namen, mit Stackzahl. Option *Debuff-Icon*.
- **Klassenfarben.** Namen in Klassenfarbe (`RAID_CLASS_COLORS` des Clients, Ersatztabelle eingebaut). Option *Klassenfarben*.
- **Buff-Wache.** Einen eigenen Buff waehlen; jede Plakette, deren Einheit ihn nicht traegt, bekommt einen orangen Rahmen. Gruppenversionen zaehlen mit, auch von anderen Heilern (erst Texturvergleich, dann Tooltip-Namensscan). Begleiter sind ausgenommen, solange *Buff-Wache auch fuer Begleiter* aus ist.
- **Reichweiten-Fading.** Plaketten samt Buttons werden auf 50 % abgeblendet, wenn die Einheit ausser Reichweite des ersten belegten Zaubers ist (ohne Zauber 28 Meter). Option *Reichweiten-Fading*.
- **`/fbp config`** oeffnet das Optionsfenster; **Escape** schliesst es (in `UISpecialFrames` eingetragen, dazu ein Hook auf `ToggleGameMenu` fuer Clients, die diese Liste ignorieren). `/fbp` endet mit einer Liste aller Befehle.
- **Gespeicherte Plattenposition.** Die Spielerplakette behaelt ihre Position ueber Reloads; Skalieren verschiebt sie nicht mehr.

**Geaendert**

- Alle UNIT-Events laufen ueber eine Slot-Tabelle (`FBPartyUnit`) statt fuenf kopierter Handler; `HealBoxAttachMode` und `FBUpdateNames` sind Schleifen.
- Zauber-Buttons werden einmal angelegt und danach nur umbelegt (frueher bei jedem `SPELLS_CHANGED` neu gebaut, mit zufaelligen Global-Namen wie `Button3`).
- In einer alten SavedVariables-Tabelle fehlende Einstellungen werden beim Laden nachgezogen (`FBHealBox_ApplyDefaults`).
- `UNIT_MAXHEALTH` wird ausgewertet (fehlte).

**Behoben**

- Die Dokumentation nannte eine falsche Client-Version; das Addon zielt auf Client 1.12.1.
- Tooltip-Fehler auf einem Button, dessen Ziel nicht existiert.
- Division durch Null bei Offline-Mitgliedern (`UnitHealthMax` = 0).
- Plattenposition wurde bei jedem Login zurueckgesetzt.

## 1.4

- Vanilla port, cascading spell menu, heal prediction, HealComm sync, German/English localization. See README.
