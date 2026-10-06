# Changelog

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
