-- ==========================================================================
-- Heal Box Vanilla: Smart Damage (Modul, ab v1.4.3)
--
-- Rangwahl fuer Angriffszauber auf jeder Aktionsleiste. Bongos, Blizzard-
-- Leisten und Tastenkuerzel rufen UseAction(slot) auf; ein Vor-Hook erkennt
-- den Zauber im Slot per Tooltip-Scan und wirkt, wenn ein kleinerer Rang
-- den Gegner sicher toetet, diesen Rang per CastSpellByName. Sonst laeuft
-- der Aufruf unveraendert weiter. Nie ueber dem Rang auf der Leiste.
--
-- Leben des Gegners, vier Quellen mit Vorrang:
--   1) Server sendet echte Werte (UnitHealthMax ~= 100)
--   2) MobHealth3            MobHealth3:GetUnitHealth(unit)
--   3) MobInfo-2             MobHealth_GetTargetCurHP()/MaxHP()
--   4) eigene Schaetzung     Lebenspunkte je Prozent aus beobachtetem Schaden
--      (eigener, Gruppe, Begleiter, andere freundliche Spieler, auch deren
--      DoTs) und dem Prozentabfall des Ziels, erst ab FBDMG_MIN_DROP Prozent
--      Abfall, Maximum ueber alle Messungen (Fehler nur nach oben, also in
--      die sichere Richtung), gemerkt je Name:Stufe. Im Raid wird weder
--      gemessen noch geschaetzt: Der Combatlog zeigt den Schaden der anderen
--      Raidgruppen nicht vollstaendig, jede Messung fiele dort zu niedrig aus.
--
-- Schaden je Rang: Mindestschaden aus dem Tooltip ("86 to 98 Holy damage"),
-- angehoben um den Bonus, den der kleinste eigene Treffer ohne Crit und
-- Teilwiderstand beweist (FBDmg_MinDamage). Entscheidung:
-- Mindestschaden >= Ziel-Leben (bei Prozent: Obergrenze) x (1 + Aufschlag).
-- ==========================================================================

if (FBHealBox_DamageLoaded) then return; end
FBHealBox_DamageLoaded = true;

FBDMG_MIN_DROP     = 3;      -- Prozent Abfall, ab dem eine Messung zaehlt
FBDMG_LASTCAST_SEC = 4;      -- Sek., wie lange ein eigener Cast fuers Lernen gilt
FBDMG_MOBHP_MAX    = 400;    -- gemerkte Mobtypen, darueber fallen die aeltesten weg
FBDMG_SECTION_H    = 180;    -- px, Hoehe des Abschnitts im Reiter "Extras"

FBDamageDefaults = {
    Enabled = 0,             -- Smart Damage an/aus (bewusst aus)
    Margin  = 20,            -- Sicherheitsaufschlag in Prozent
};

-- Angriffszauber je Klasse (englische Zaubernamen wie im ganzen Addon).
-- Kanalisierte, reine DoTs und Flaechenzauber bleiben draussen.
FBDamageSpells = {
    Priest  = { "Smite", "Holy Fire", "Mind Blast" },
    Druid   = { "Wrath", "Starfire", "Moonfire" },
    Shaman  = { "Lightning Bolt", "Chain Lightning", "Earth Shock", "Flame Shock", "Frost Shock" },
    Paladin = { "Holy Shock", "Hammer of Wrath", "Exorcism", "Holy Wrath" },
    Mage    = { "Fireball", "Frostbolt", "Fire Blast", "Scorch", "Pyroblast" },
    Warlock = { "Shadow Bolt", "Searing Pain", "Immolate", "Soul Fire", "Conflagrate" },
    Hunter  = { "Arcane Shot", "Aimed Shot" },
};

-- ==========================================================================
-- [ Texte ]
-- ==========================================================================

FBLocale["enUS"].DMG_HEADER      = "Smart Damage";
FBLocale["enUS"].DMG_ENABLED     = "Smart Damage";
FBLocale["enUS"].DMG_ENABLED_TIP = "What it does: when you press an attack spell on any action bar (Bongos, Blizzard bars, key bindings) and a lower rank of that spell would still kill the target, that rank is cast instead. Saves mana on nearly dead targets. Rules: never above the rank on the bar, minimum damage of the rank must cover the target's remaining health plus the safety margin. Needs the target's real health: from the server, from MobHealth3 or MobInfo-2, or from the addon's own estimate learned while fighting a mob type. Downsides: estimates can be wrong, partial resists lower the damage, and on unknown mobs nothing happens until enough has been learned. Off by default.";
FBLocale["enUS"].DMG_MARGIN      = "Safety margin: |cFFFFFFFF%s %%";
FBLocale["enUS"].DMG_SRC         = "Target health source: |cFFFFFFFF%s";
FBLocale["enUS"].DMG_SRC_REAL    = "server sends real values";
FBLocale["enUS"].DMG_SRC_MH3     = "MobHealth3";
FBLocale["enUS"].DMG_SRC_MI2     = "MobInfo-2";
FBLocale["enUS"].DMG_SRC_EST     = "own estimate (%d mob types learned)";
FBLocale["enUS"].DMG_SRC_NONE    = "no target";
FBLocale["enUS"].DMG_SRC_UNKNOWN = "percent only, nothing learned yet";
FBLocale["enUS"].DMG_SPELLS      = "Spells: |cFFFFFFFF%s";
FBLocale["enUS"].DMG_INFO        = "The target line above updates with your current target. Learning happens automatically: every fight against a mob type improves the estimate for that type.";
FBLocale["enUS"].DMG_STATUS      = "Smart Damage: %s, margin %d %%, %s";
FBLocale["enUS"].DBG_DMG         = "Smart Damage: %s -> %s (target %d HP via %s, min damage %d)";
FBLocale["enUS"].DBG_DMG_KEEP    = "Smart Damage: %s kept (target %d HP via %s)";
FBLocale["enUS"].DMG_LOADED      = "Smart Damage module loaded: section in tab |cFFFFFFFFExtras|r, /fbp damage";
FBLocale["enUS"].DMG_ON          = "Smart Damage |cFF00FF00on|r.";
FBLocale["enUS"].DMG_OFF         = "Smart Damage |cFFFF0000off|r.";

FBLocale["deDE"].DMG_HEADER      = "Smart Damage";
FBLocale["deDE"].DMG_ENABLED     = "Smart Damage";
FBLocale["deDE"].DMG_ENABLED_TIP = "Was es tut: Drueckst du einen Angriffszauber auf einer beliebigen Aktionsleiste (Bongos, Blizzard-Leisten, Tastenkuerzel) und ein niedrigerer Rang wuerde das Ziel noch toeten, wird stattdessen dieser Rang gewirkt. Spart Mana bei fast toten Zielen. Regeln: nie ueber dem Rang auf der Leiste, der Mindestschaden des Rangs muss das Restleben des Ziels plus Sicherheitsaufschlag decken. Braucht das echte Leben des Ziels: vom Server, von MobHealth3 oder MobInfo-2, oder aus der eigenen Schaetzung, die das Addon im Kampf gegen einen Mobtyp lernt. Nachteile: Schaetzungen koennen danebenliegen, Teilwiderstaende senken den Schaden, und bei unbekannten Mobs passiert nichts, bis genug gelernt ist. Standardmaessig aus.";
FBLocale["deDE"].DMG_MARGIN      = "Sicherheitsaufschlag: |cFFFFFFFF%s %%";
FBLocale["deDE"].DMG_SRC         = "Lebensquelle des Ziels: |cFFFFFFFF%s";
FBLocale["deDE"].DMG_SRC_REAL    = "Server sendet echte Werte";
FBLocale["deDE"].DMG_SRC_MH3     = "MobHealth3";
FBLocale["deDE"].DMG_SRC_MI2     = "MobInfo-2";
FBLocale["deDE"].DMG_SRC_EST     = "eigene Schaetzung (%d Mobtypen gelernt)";
FBLocale["deDE"].DMG_SRC_NONE    = "kein Ziel";
FBLocale["deDE"].DMG_SRC_UNKNOWN = "nur Prozent, noch nichts gelernt";
FBLocale["deDE"].DMG_SPELLS      = "Zauber: |cFFFFFFFF%s";
FBLocale["deDE"].DMG_INFO        = "Die Zielzeile oben folgt deinem aktuellen Ziel. Gelernt wird von selbst: Jeder Kampf gegen einen Mobtyp verbessert die Schaetzung fuer diesen Typ.";
FBLocale["deDE"].DMG_STATUS      = "Smart Damage: %s, Aufschlag %d %%, %s";
FBLocale["deDE"].DBG_DMG         = "Smart Damage: %s -> %s (Ziel %d LP ueber %s, Mindestschaden %d)";
FBLocale["deDE"].DBG_DMG_KEEP    = "Smart Damage: %s bleibt (Ziel %d LP ueber %s)";
FBLocale["deDE"].DMG_LOADED      = "Smart-Damage-Modul geladen: Abschnitt im Reiter |cFFFFFFFFExtras|r, /fbp damage";
FBLocale["deDE"].DMG_ON          = "Smart Damage |cFF00FF00an|r.";
FBLocale["deDE"].DMG_OFF         = "Smart Damage |cFFFF0000aus|r.";

-- Weitere Sprachen (Spanisch, Franzoesisch, Italienisch)

FBLocale["esES"].DMG_HEADER        = "Smart Damage";
FBLocale["esES"].DMG_ENABLED       = "Smart Damage";
FBLocale["esES"].DMG_ENABLED_TIP   = "Qué hace: cuando pulsas un hechizo de ataque en cualquier barra de acción (Bongos, barras de Blizzard, atajos de teclado) y un rango inferior de ese hechizo aún mataría al objetivo, se lanza ese rango en su lugar. Ahorra maná con objetivos casi muertos. Reglas: nunca por encima del rango de la barra, el daño mínimo del rango debe cubrir la vida restante del objetivo más el margen de seguridad. Necesita la vida real del objetivo: del servidor, de MobHealth3 o MobInfo-2, o de la estimación propia del addon aprendida al combatir un tipo de enemigo. Desventajas: las estimaciones pueden fallar, las resistencias parciales reducen el daño y con enemigos desconocidos no ocurre nada hasta haber aprendido lo suficiente. Desactivado por defecto.";
FBLocale["esES"].DMG_MARGIN        = "Margen de seguridad: |cFFFFFFFF%s %%";
FBLocale["esES"].DMG_SRC           = "Fuente de vida del objetivo: |cFFFFFFFF%s";
FBLocale["esES"].DMG_SRC_REAL      = "el servidor envía valores reales";
FBLocale["esES"].DMG_SRC_MH3       = "MobHealth3";
FBLocale["esES"].DMG_SRC_MI2       = "MobInfo-2";
FBLocale["esES"].DMG_SRC_EST       = "estimación propia (%d tipos de enemigo aprendidos)";
FBLocale["esES"].DMG_SRC_NONE      = "sin objetivo";
FBLocale["esES"].DMG_SRC_UNKNOWN   = "solo porcentaje, aún nada aprendido";
FBLocale["esES"].DMG_SPELLS        = "Hechizos: |cFFFFFFFF%s";
FBLocale["esES"].DMG_INFO          = "La línea del objetivo se actualiza con tu objetivo actual. El aprendizaje es automático: cada combate contra un tipo de enemigo mejora la estimación de ese tipo.";
FBLocale["esES"].DMG_STATUS        = "Smart Damage: %s, margen %d %%, %s";
FBLocale["esES"].DBG_DMG           = "Smart Damage: %s -> %s (objetivo %d PV vía %s, daño mínimo %d)";
FBLocale["esES"].DBG_DMG_KEEP      = "Smart Damage: %s mantenido (objetivo %d PV vía %s)";
FBLocale["esES"].DMG_LOADED        = "Módulo Smart Damage cargado: sección en la pestaña |cFFFFFFFFExtras|r, /fbp damage";
FBLocale["esES"].DMG_ON            = "Smart Damage |cFF00FF00activado|r.";
FBLocale["esES"].DMG_OFF           = "Smart Damage |cFFFF0000desactivado|r.";

FBLocale["frFR"].DMG_HEADER        = "Smart Damage";
FBLocale["frFR"].DMG_ENABLED       = "Smart Damage";
FBLocale["frFR"].DMG_ENABLED_TIP   = "Ce que ça fait : quand vous appuyez sur un sort d'attaque sur n'importe quelle barre d'action (Bongos, barres Blizzard, raccourcis) et qu'un rang inférieur de ce sort tuerait encore la cible, c'est ce rang qui est lancé. Économise du mana sur les cibles presque mortes. Règles : jamais au-dessus du rang de la barre, les dégâts minimaux du rang doivent couvrir la vie restante de la cible plus la marge de sécurité. Nécessite la vie réelle de la cible : du serveur, de MobHealth3 ou MobInfo-2, ou de l'estimation propre de l'addon apprise en combattant un type de monstre. Inconvénients : les estimations peuvent se tromper, les résistances partielles réduisent les dégâts, et sur les monstres inconnus rien ne se passe tant que l'apprentissage est insuffisant. Désactivé par défaut.";
FBLocale["frFR"].DMG_MARGIN        = "Marge de sécurité : |cFFFFFFFF%s %%";
FBLocale["frFR"].DMG_SRC           = "Source de vie de la cible : |cFFFFFFFF%s";
FBLocale["frFR"].DMG_SRC_REAL      = "le serveur envoie des valeurs réelles";
FBLocale["frFR"].DMG_SRC_MH3       = "MobHealth3";
FBLocale["frFR"].DMG_SRC_MI2       = "MobInfo-2";
FBLocale["frFR"].DMG_SRC_EST       = "estimation propre (%d types de monstres appris)";
FBLocale["frFR"].DMG_SRC_NONE      = "aucune cible";
FBLocale["frFR"].DMG_SRC_UNKNOWN   = "pourcentage seulement, rien appris pour le moment";
FBLocale["frFR"].DMG_SPELLS        = "Sorts : |cFFFFFFFF%s";
FBLocale["frFR"].DMG_INFO          = "La ligne de cible ci-dessus se met à jour avec votre cible actuelle. L'apprentissage est automatique : chaque combat contre un type de monstre améliore l'estimation pour ce type.";
FBLocale["frFR"].DMG_STATUS        = "Smart Damage : %s, marge %d %%, %s";
FBLocale["frFR"].DBG_DMG           = "Smart Damage : %s -> %s (cible %d PV via %s, dégâts min %d)";
FBLocale["frFR"].DBG_DMG_KEEP      = "Smart Damage : %s conservé (cible %d PV via %s)";
FBLocale["frFR"].DMG_LOADED        = "Module Smart Damage chargé : section dans l'onglet |cFFFFFFFFExtras|r, /fbp damage";
FBLocale["frFR"].DMG_ON            = "Smart Damage |cFF00FF00activé|r.";
FBLocale["frFR"].DMG_OFF           = "Smart Damage |cFFFF0000désactivé|r.";

FBLocale["itIT"].DMG_HEADER        = "Smart Damage";
FBLocale["itIT"].DMG_ENABLED       = "Smart Damage";
FBLocale["itIT"].DMG_ENABLED_TIP   = "Cosa fa: quando premi un incantesimo d'attacco su una qualsiasi barra delle azioni (Bongos, barre Blizzard, scorciatoie) e un rango inferiore di quell'incantesimo ucciderebbe comunque il bersaglio, viene lanciato quel rango. Risparmia mana sui bersagli quasi morti. Regole: mai sopra il rango sulla barra, il danno minimo del rango deve coprire la salute rimanente del bersaglio più il margine di sicurezza. Richiede la salute reale del bersaglio: dal server, da MobHealth3 o MobInfo-2, o dalla stima dell'addon appresa combattendo un tipo di mostro. Svantaggi: le stime possono sbagliare, le resistenze parziali riducono il danno e sui mostri sconosciuti non succede nulla finché non si è appreso abbastanza. Disattivato per impostazione predefinita.";
FBLocale["itIT"].DMG_MARGIN        = "Margine di sicurezza: |cFFFFFFFF%s %%";
FBLocale["itIT"].DMG_SRC           = "Fonte della salute del bersaglio: |cFFFFFFFF%s";
FBLocale["itIT"].DMG_SRC_REAL      = "il server invia valori reali";
FBLocale["itIT"].DMG_SRC_MH3       = "MobHealth3";
FBLocale["itIT"].DMG_SRC_MI2       = "MobInfo-2";
FBLocale["itIT"].DMG_SRC_EST       = "stima propria (%d tipi di mostro appresi)";
FBLocale["itIT"].DMG_SRC_NONE      = "nessun bersaglio";
FBLocale["itIT"].DMG_SRC_UNKNOWN   = "solo percentuale, ancora nulla appreso";
FBLocale["itIT"].DMG_SPELLS        = "Incantesimi: |cFFFFFFFF%s";
FBLocale["itIT"].DMG_INFO          = "La riga del bersaglio qui sopra si aggiorna con il tuo bersaglio attuale. L'apprendimento è automatico: ogni combattimento contro un tipo di mostro migliora la stima per quel tipo.";
FBLocale["itIT"].DMG_STATUS        = "Smart Damage: %s, margine %d %%, %s";
FBLocale["itIT"].DBG_DMG           = "Smart Damage: %s -> %s (bersaglio %d PS via %s, danno minimo %d)";
FBLocale["itIT"].DBG_DMG_KEEP      = "Smart Damage: %s mantenuto (bersaglio %d PS via %s)";
FBLocale["itIT"].DMG_LOADED        = "Modulo Smart Damage caricato: sezione nella scheda |cFFFFFFFFExtra|r, /fbp damage";
FBLocale["itIT"].DMG_ON            = "Smart Damage |cFF00FF00attivo|r.";
FBLocale["itIT"].DMG_OFF           = "Smart Damage |cFFFF0000disattivato|r.";

-- ==========================================================================
-- [ Zustand ]
-- ==========================================================================

FBDmgSpellRanks = {};   -- [Name] = { { rank, id, min, max }, ... } aufsteigend
FBDmgSlotCache  = {};   -- [slot] = { name, rank } oder false (kein Zauber)
FBDmgAnchorPct  = nil;  -- Prozent des Ziels beim letzten Messpunkt
FBDmgAccum      = 0;    -- Schaden auf das Ziel seit dem Messpunkt
FBDmgTargetName = nil;
FBDmgLastCast   = nil;  -- { spell, rank, t } fuer das Lernen aus dem Combatlog
FBDmgActive     = false; -- Ereignisse registriert (Smart Damage an)
FBDmgSpellsDirty = true; -- Zauberbuch noch nicht (neu) gelesen
FBDmgMobCount   = 0;    -- Eintraege in HealBox.MobHP

function FBDmg_Cfg()
    if (not HealBox.Damage) then FBDmg_ApplyDefaults(); end
    return HealBox.Damage;
end

function FBDmg_ApplyDefaults()
    if (not HealBox.Damage) then HealBox.Damage = {}; end
    for k, v in pairs(FBDamageDefaults) do
        if (HealBox.Damage[k] == nil) then HealBox.Damage[k] = v; end
    end
    if (not HealBox.MobHP) then HealBox.MobHP = {}; end          -- [Name:Stufe] = { ppp, n, seen }
    if (not HealBox.DmgMemory) then HealBox.DmgMemory = {}; end  -- [Zauber|Rang] = kleinster normaler Treffer
    FBDmg_PruneMobHP();
    return true;
end

-- Gemerkte Mobtypen begrenzen. HealBox.MobHP wuchs bis 1.4.6 beim Leveln um
-- jeden Mobtyp und jede Stufe, ohne je zu schrumpfen. Ueber der Grenze
-- fallen die am laengsten nicht gesehenen Eintraege weg, und zwar bis auf
-- drei Viertel der Grenze, damit nicht jeder neue Mob eine Sortierung
-- ausloest. Eintraege aus aelteren Versionen ohne Zeitstempel gelten als
-- die aeltesten.
function FBDmg_SeenOf(e)
    if (type(e) == "table") and e.seen then return e.seen; end
    return 0;
end

function FBDmg_PruneMobHP()
    local t = HealBox.MobHP;
    if (not t) then FBDmgMobCount = 0; return; end
    local keys = {};
    for k in pairs(t) do table.insert(keys, k); end
    local n = table.getn(keys);
    FBDmgMobCount = n;
    if (n <= FBDMG_MOBHP_MAX) then return; end
    table.sort(keys, function(a, b) return FBDmg_SeenOf(t[a]) < FBDmg_SeenOf(t[b]); end);
    local drop = n - math.floor(FBDMG_MOBHP_MAX * 0.75);
    for i = 1, drop do t[keys[i]] = nil; end
    FBDmgMobCount = n - drop;
end

-- ==========================================================================
-- [ Zauberbuch: Raenge und Schaden ]
-- ==========================================================================

function FBDmg_ScanSpells()
    FBDmgSpellRanks = {};
    local wanted = {};
    for _, n in ipairs(FBDamageSpells[FBClass] or {}) do wanted[n] = true; end
    local i = 1;
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL);
        if (not name) then break; end
        if (wanted[name]) then
            local txt = FBPredict_TooltipText(i) or "";
            local lo, hi = FBPredict_FindAmountRange(txt);
            if (not lo) then
                lo = FBPredict_FindAmountSingle(txt);
                hi = lo;
            end
            local isDamage = (string.find(txt, "[Dd]amage") or string.find(txt, "[Ss]chaden")) ~= nil;
            if (lo and isDamage) then
                if (not FBDmgSpellRanks[name]) then FBDmgSpellRanks[name] = {}; end
                table.insert(FBDmgSpellRanks[name], { rank = rank or "", id = i, min = lo, max = hi });
            end
        end
        i = i + 1;
    end
    FBDmgSlotCache = {};
    FBDmgSpellsDirty = false;
end

-- Mindestschaden eines Rangs. Gelernt wird der kleinste eigene Treffer ohne
-- Crit und Teilwiderstand. Jeder Treffer liegt hoechstens beim Hoechstwert
-- des Tooltips plus Bonus, der Bonus ist also mindestens Treffer minus
-- Hoechstwert, und so viel liegt sicher auch auf dem Minimum. Der kleinste
-- Treffer, weil Verstaerker wie Curse of Shadow oder Power Infusion nur
-- manche Treffer heben; ein einzelner verstaerkter Treffer darf den Wert
-- nicht dauerhaft hochziehen. Bis 1.4.6 galt der kleinste Treffer selbst als
-- Mindestschaden; nach einem einzigen hohen Wurf lag er ueber dem echten
-- Minimum, und der gewaehlte Rang toetete nicht.
function FBDmg_MinDamage(spell, entry)
    local learned = HealBox.DmgMemory and HealBox.DmgMemory[spell.."|"..entry.rank];
    if (not learned) then return entry.min; end
    return math.max(entry.min, learned - (entry.max - entry.min));
end

-- ==========================================================================
-- [ Leben des Ziels ]
-- ==========================================================================

function FBDmg_MobKey(unit)
    local name = UnitName(unit);
    if (not name) then return nil; end
    local lvl = UnitLevel and UnitLevel(unit) or 0;
    return name..":"..tostring(lvl or 0);
end

-- Sendet der Server echte Werte fuer diese Einheit?
function FBDmg_HasRealValues(unit)
    local max = UnitHealthMax(unit);
    return (max and max ~= 100 and max > 0);
end

-- Liefert cur, max, source oder nil. cur ist bei Schaetzung die Obergrenze.
function FBDmg_TargetHP(unit)
    unit = unit or "target";
    if (not UnitExists(unit)) then return nil; end
    if (FBDmg_HasRealValues(unit)) then
        return UnitHealth(unit), UnitHealthMax(unit), "real";
    end
    -- MobHealth3
    if (MobHealth3 and MobHealth3.GetUnitHealth) then
        local ok, cur, max, found = pcall(MobHealth3.GetUnitHealth, MobHealth3, unit);
        if (ok and found and cur and max and max > 100) then return cur, max, "mh3"; end
    end
    -- MobInfo-2 (nur fuer das aktuelle Ziel)
    if (unit == "target" and MobHealth_GetTargetCurHP and MobHealth_GetTargetMaxHP) then
        local ok, cur = pcall(MobHealth_GetTargetCurHP);
        local ok2, max = pcall(MobHealth_GetTargetMaxHP);
        if (ok and ok2 and cur and max and max > 100) then return cur, max, "mi2"; end
    end
    -- eigene Schaetzung: Prozent-Obergrenze x Lebenspunkte je Prozent. Nicht
    -- im Raid: Dort wird nicht gemessen (FBDmg_OnTargetHealth), und was
    -- fruehere Versionen dort gemessen haben, fiel zu niedrig aus.
    if (GetNumRaidMembers() > 0) then return nil; end
    local key = FBDmg_MobKey(unit);
    local est = key and HealBox.MobHP and HealBox.MobHP[key];
    if (est and est.ppp and est.ppp > 0) then
        est.seen = time();
        local pct = UnitHealth(unit) or 0;
        return math.ceil((pct + 1) * est.ppp), math.ceil(100 * est.ppp), "est";
    end
    return nil;
end

-- [ Lernen: Lebenspunkte je Prozent ] ---------------------------------------

function FBDmg_ResetTarget()
    FBDmgTargetName = nil;
    FBDmgAnchorPct  = nil;
    FBDmgAccum      = 0;
    -- Im Raid wird nicht vermessen (siehe Kopf der Datei)
    if (GetNumRaidMembers() > 0) then FBDmg_UpdateSourceText(); return; end
    if (UnitExists("target") and UnitCanAttack and UnitCanAttack("player", "target") and not FBDmg_HasRealValues("target")) then
        FBDmgTargetName = UnitName("target");
        FBDmgAnchorPct  = UnitHealth("target");
    end
    FBDmg_UpdateSourceText();
end

-- Schaden auf das Ziel vermerken (aus dem Combatlog)
function FBDmg_NoteDamage(victim, amount)
    if (not FBDmgTargetName) or (victim ~= FBDmgTargetName) then return; end
    FBDmgAccum = FBDmgAccum + (amount or 0);
end

-- UNIT_HEALTH des Ziels: Prozent gefallen -> Messung
function FBDmg_OnTargetHealth()
    if (not FBDmgTargetName) or (not FBDmgAnchorPct) then return; end
    if (FBDmg_HasRealValues("target")) then return; end
    -- Mitten im Kampf einem Raid beigetreten: Messung verwerfen. Bis 1.4.6
    -- wurde auch im Raid gemessen; bei Mobtypen, die man nur dort trifft,
    -- war dann keine Messung sauber und die Schaetzung viel zu niedrig.
    if (GetNumRaidMembers() > 0) then
        FBDmgTargetName = nil; FBDmgAnchorPct = nil; FBDmgAccum = 0;
        return;
    end
    local pct = UnitHealth("target") or 0;
    local drop = FBDmgAnchorPct - pct;
    if (drop >= FBDMG_MIN_DROP and FBDmgAccum > 0) then
        local ppp = FBDmgAccum / drop;
        local key = FBDmg_MobKey("target");
        if (key) then
            if (not HealBox.MobHP) then HealBox.MobHP = {}; end
            local e = HealBox.MobHP[key];
            if (not e) then
                HealBox.MobHP[key] = { ppp = ppp, n = 1, seen = time() };
                FBDmgMobCount = FBDmgMobCount + 1;
                if (FBDmgMobCount > FBDMG_MOBHP_MAX) then FBDmg_PruneMobHP(); end
            else
                -- Maximum: Fehler nur nach oben (fremder, nicht gezaehlter Schaden
                -- wuerde die Schaetzung sonst nach unten ziehen)
                if (ppp > e.ppp) then e.ppp = ppp; end
                e.n = (e.n or 0) + 1;
                e.seen = time();
            end
        end
        FBDmgAnchorPct = pct;
        FBDmgAccum = 0;
        FBDmg_UpdateSourceText();
    elseif (pct > FBDmgAnchorPct) then
        -- Ziel wurde geheilt: neu ansetzen
        FBDmgAnchorPct = pct;
        FBDmgAccum = 0;
    end
end

-- [ Combatlog ] --------------------------------------------------------------

-- Schadenszeilen: Opfer und Betrag herausziehen (englischer Client, wie das
-- ganze Addon). "(N resisted)" markiert Teilwiderstand.
function FBDmg_ParseLine(msg)
    if (not msg) then return nil; end
    local _, _, spell, victim, amount;
    -- "Your Smite hits Kobold for 95." / "crits"
    _, _, spell, victim, amount = string.find(msg, "^Your (.-) hits (.-) for (%d+)");
    if (not spell) then _, _, spell, victim, amount = string.find(msg, "^Your (.-) crits (.-) for (%d+)"); end
    if (spell) then return victim, tonumber(amount), spell, "self"; end
    -- "You hit Kobold for 20." / "You crit"
    _, _, victim, amount = string.find(msg, "^You hit (.-) for (%d+)");
    if (not victim) then _, _, victim, amount = string.find(msg, "^You crit (.-) for (%d+)"); end
    if (victim) then return victim, tonumber(amount), nil, "self"; end
    -- "Kobold suffers 50 Shadow damage from your Shadow Word: Pain."
    _, _, victim, amount = string.find(msg, "^(.-) suffers (%d+) .- damage from your");
    if (victim) then return victim, tonumber(amount), nil, "self"; end
    -- "Kobold suffers 50 Shadow damage from Bob's Shadow Word: Pain."
    _, _, victim, amount = string.find(msg, "^(.-) suffers (%d+) .- damage from .-'s ");
    if (victim) then return victim, tonumber(amount), nil, "other"; end
    -- "Bob's Fireball hits Kobold for 200." / crits  (Gruppe, Begleiter)
    _, _, victim, amount = string.find(msg, "^.-'s .- hits (.-) for (%d+)");
    if (not victim) then _, _, victim, amount = string.find(msg, "^.-'s .- crits (.-) for (%d+)"); end
    if (victim) then return victim, tonumber(amount), nil, "other"; end
    -- "Bob hits Kobold for 50." / crits  (Nahkampf Gruppe, Begleiter)
    _, _, victim, amount = string.find(msg, "^.- hits (.-) for (%d+)");
    if (not victim) then _, _, victim, amount = string.find(msg, "^.- crits (.-) for (%d+)"); end
    if (victim) then return victim, tonumber(amount), nil, "other"; end
    return nil;
end

function FBDmg_OnCombatLog(msg)
    -- Nur arbeiten, wenn Smart Damage an ist und es etwas zu lernen gibt
    -- (Prozentziel wird vermessen oder ein eigener Cast wartet auf Treffer).
    if (FBDmg_Cfg().Enabled ~= 1) then return; end
    if (not FBDmgTargetName) and (not FBDmgLastCast) then return; end
    local victim, amount, spell, who = FBDmg_ParseLine(msg);
    if (not victim) then return; end
    FBDmg_NoteDamage(victim, amount);
    -- Kleinsten Treffer lernen (siehe FBDmg_MinDamage): eigener Zauber, kein
    -- Crit, kein Teilwiderstand
    if (who == "self" and spell and FBDmgLastCast and FBDmgLastCast.spell == spell
        and (GetTime() - FBDmgLastCast.t) <= FBDMG_LASTCAST_SEC
        and not string.find(msg, "crits") and not string.find(msg, "resisted")) then
        local key = spell.."|"..(FBDmgLastCast.rank or "");
        if (not HealBox.DmgMemory) then HealBox.DmgMemory = {}; end
        local old = HealBox.DmgMemory[key];
        if (not old) or (amount < old) then
            HealBox.DmgMemory[key] = amount;
        end
    end
end

-- ==========================================================================
-- [ Rangwahl beim Klick ]
-- ==========================================================================

-- Zauber in einem Aktionsslot: name, rank oder nil (Makro, Gegenstand)
function FBDmg_SlotSpell(slot)
    local c = FBDmgSlotCache[slot];
    if (c ~= nil) then
        if (c == false) then return nil; end
        return c.name, c.rank;
    end
    if (not FBPredictTip) or (not FBPredictTip.SetAction) then return nil; end
    FBPredictTip:SetOwner(UIParent, "ANCHOR_NONE");
    FBPredictTip:ClearLines();
    FBPredictTip:SetAction(slot);
    local l = getglobal("FBHealBoxScanTipTextLeft1");
    local r = getglobal("FBHealBoxScanTipTextRight1");
    local name = l and l:GetText();
    local rank = r and r:GetText();
    if (name and FBDmgSpellRanks[name]) then
        FBDmgSlotCache[slot] = { name = name, rank = rank or "" };
        return name, rank or "";
    end
    FBDmgSlotCache[slot] = false;
    return nil;
end

-- Liefert den zu wirkenden Cast-String, wenn abgerangt wird, sonst nil
function FBDmg_Choose(spell, rank)
    local cfg = FBDmg_Cfg();
    local ranks = FBDmgSpellRanks[spell];
    if (not ranks) or (table.getn(ranks) < 2) then return nil; end
    if (not UnitExists("target")) or (UnitCanAttack and not UnitCanAttack("player", "target")) then return nil; end
    if (UnitIsDead and UnitIsDead("target")) then return nil; end
    local cur, max, source = FBDmg_TargetHP("target");
    if (not cur) or (cur <= 0) then return nil; end
    local need = cur * (1 + (cfg.Margin or 20) / 100);

    local assignedIdx = nil;
    for i, e in ipairs(ranks) do
        if (e.rank == rank) then assignedIdx = i; end
    end
    if (not assignedIdx) then assignedIdx = table.getn(ranks); end

    for i = 1, assignedIdx do
        local e = ranks[i];
        if (FBDmg_MinDamage(spell, e) >= need) then
            if (i == assignedIdx) then
                if (FBPredictDebug) then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..format(FBT("DBG_DMG_KEEP"), spell.."("..rank..")", cur, source));
                end
                return nil;
            end
            local chosen = spell;
            if (e.rank ~= "") then chosen = spell.."("..e.rank..")"; end
            if (FBPredictDebug) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..format(FBT("DBG_DMG"), spell.."("..rank..")", chosen, cur, source, FBDmg_MinDamage(spell, e)));
            end
            return chosen, e.rank;
        end
    end
    return nil;
end

-- Vor-Hook auf UseAction. true, wenn das Modul selbst gecastet hat.
function FBDmg_TryDownrank(slot, checkCursor, onSelf)
    -- Klassensperre des Kerns (Krieger/Schurke/Jaeger ohne /fbp forceload):
    -- die Aktionsleiste bleibt unberuehrt
    if (FBAddonSuppressed) then return false; end
    if (FBDmg_Cfg().Enabled ~= 1) or onSelf then return false; end
    if ((CursorHasSpell and CursorHasSpell()) or (CursorHasItem and CursorHasItem())) then return false; end
    local name, rank = FBDmg_SlotSpell(slot);
    if (not name) then return false; end
    local chosen, chosenRank = FBDmg_Choose(name, rank);
    FBDmgLastCast = { spell = name, rank = (chosenRank or rank), t = GetTime() };
    if (not chosen) then return false; end
    CastSpellByName(chosen);
    return true;
end

function FBDmg_HookUseAction()
    if (FBHealBox_UseActionHooked) or (not UseAction) then return; end
    FBHealBox_UseActionHooked = true;
    local origUseAction = UseAction;
    UseAction = function(slot, checkCursor, onSelf)
        -- Geschuetzt wie die Hooks des Kerns: Ein Fehler in der Rangwahl wird
        -- gemeldet und darf den Tastendruck nicht verschlucken, der Aufruf
        -- laeuft dann unveraendert weiter
        local ok, done = pcall(FBDmg_TryDownrank, slot, checkCursor, onSelf);
        if (not ok) then
            FBHealBox_ReportError("Smart Damage", done);
            done = false;
        end
        if (done) then return; end
        origUseAction(slot, checkCursor, onSelf);
    end
end

-- ==========================================================================
-- [ Events ]
-- ==========================================================================

FBDmgFrame = CreateFrame("Frame", "FBHealBoxDamageFrame", UIParent);
-- Immer: Zauberbuch geaendert. Das kostet nichts, ausgeschaltet wird nur
-- vorgemerkt.
FBDmgFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
FBDmgFrame:RegisterEvent("SPELLS_CHANGED");

-- Nur solange Smart Damage an ist (FBDmg_UpdateActive). Bis 1.4.6 liefen
-- Combatlog, UNIT_HEALTH und Zielwechsel auch im Standardzustand aus
-- durch dieses Modul.
FBDmgActiveEvents = {
    "ACTIONBAR_SLOT_CHANGED", "PLAYER_TARGET_CHANGED", "UNIT_HEALTH",
    "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_COMBAT_SELF_HITS",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
    "CHAT_MSG_SPELL_PARTY_DAMAGE", "CHAT_MSG_COMBAT_PARTY_HITS",
    "CHAT_MSG_SPELL_PET_DAMAGE", "CHAT_MSG_COMBAT_PET_HITS",
    -- Spieler ausserhalb der Gruppe, die denselben Gegner angreifen
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE", "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS",
};

function FBDmg_UpdateActive()
    local on = (FBDmg_Cfg().Enabled == 1) and (not FBAddonSuppressed);
    if (on == FBDmgActive) then return; end
    FBDmgActive = on;
    for _, ev in ipairs(FBDmgActiveEvents) do
        if (on) then FBDmgFrame:RegisterEvent(ev); else FBDmgFrame:UnregisterEvent(ev); end
    end
    if (on) then
        -- Was waehrend der Pause auf den Leisten passiert ist, weiss das
        -- Modul nicht: Slots neu lesen, Zauberbuch bei Bedarf auch.
        FBDmgSlotCache = {};
        if (FBDmgSpellsDirty) then FBDmg_ScheduleScan(); end
        FBDmg_ResetTarget();
    else
        FBDmgTargetName = nil; FBDmgAnchorPct = nil; FBDmgAccum = 0;
        FBDmgLastCast = nil;
    end
end

-- Zauberbuch im naechsten Frame lesen, einmal je Salve. Beim Login kommen
-- PLAYER_ENTERING_WORLD und mehrere SPELLS_CHANGED kurz hintereinander,
-- bis 1.4.6 las jedes davon alle Schadenszauber samt Tooltips sofort. Der
-- OnUpdate haengt nur, solange etwas ansteht.
function FBDmg_ScheduleScan()
    FBDmgSpellsDirty = true;
    -- Gelesen wird, wenn das Modul an ist oder jemand die Liste gerade sieht
    if (FBDmgActive) or (FBPanel and FBPanel:IsVisible()) then
        FBDmgFrame:SetScript("OnUpdate", FBDmg_OnUpdate);
    end
end

function FBDmg_OnUpdate()
    FBDmgFrame:SetScript("OnUpdate", nil);
    if (FBAddonSuppressed) or (not FBDmgSpellsDirty) then return; end
    if (FBDmgActive) then
        FBDmg_ScanSpells();
        FBDmg_UpdateSpellText();
        FBDmg_ResetTarget();
    else
        -- Ausgeschaltet, Optionen offen: liest bei Bedarf selbst
        FBDmg_UpdateSpellText();
    end
end

FBDmgFrame:SetScript("OnEvent", function()
    if (FBAddonSuppressed) then return; end
    if (event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED") then
        FBDmg_ScheduleScan();
    elseif (event == "ACTIONBAR_SLOT_CHANGED") then
        if (arg1) then FBDmgSlotCache[arg1] = nil; else FBDmgSlotCache = {}; end
    elseif (event == "PLAYER_TARGET_CHANGED") then
        FBDmg_ResetTarget();
    elseif (event == "UNIT_HEALTH") then
        if (arg1 == "target") then FBDmg_OnTargetHealth(); FBDmg_UpdateSourceText(); end
    else
        FBDmg_OnCombatLog(arg1);
    end
end);

-- ==========================================================================
-- [ Optionen: Abschnitt im Reiter "Extras" ]
-- ==========================================================================

function FBDmg_SourceText()
    if (not UnitExists("target")) then return FBT("DMG_SRC_NONE"); end
    local cur, max, source = FBDmg_TargetHP("target");
    if (source == "real") then return FBT("DMG_SRC_REAL"); end
    if (source == "mh3") then return FBT("DMG_SRC_MH3"); end
    if (source == "mi2") then return FBT("DMG_SRC_MI2"); end
    if (source == "est") then
        local n = 0;
        for _ in pairs(HealBox.MobHP or {}) do n = n + 1; end
        return format(FBT("DMG_SRC_EST"), n);
    end
    return FBT("DMG_SRC_UNKNOWN");
end

function FBDmg_UpdateSourceText()
    -- nur, wenn das Optionsfenster offen ist (sonst je UNIT_HEALTH des Ziels umsonst)
    if (FBDmgSourceText and FBPanel and FBPanel:IsVisible()) then
        FBDmgSourceText:SetText(format(FBT("DMG_SRC"), FBDmg_SourceText()));
    end
end

function FBDmg_UpdateSpellText()
    if (not FBDmgSpellText) then return; end
    -- Ausgeschaltet liest das Modul das Zauberbuch erst, wenn jemand die
    -- Optionen ansieht
    if (FBDmgSpellsDirty and FBPanel and FBPanel:IsVisible()) then FBDmg_ScanSpells(); end
    local list = {};
    for _, n in ipairs(FBDamageSpells[FBClass] or {}) do
        if (FBDmgSpellRanks[n]) then table.insert(list, n.." ("..table.getn(FBDmgSpellRanks[n])..")"); end
    end
    local shown = "-";
    if (table.getn(list) > 0) then shown = table.concat(list, ", "); end
    FBDmgSpellText:SetText(format(FBT("DMG_SPELLS"), shown));
end

-- Eigener Abschnitt im Reiter "Extras", den der Kern verwaltet. Bis 1.4.6
-- suchte das Modul den Reiter des Mana-Tickers und setzte sich 232 px
-- darunter; ohne Tickerdatei gab es fuer Smart Damage gar keine Optionen.
function FBDmg_BuildOptions()
    local tab, y = FBHealBox_ExtrasSection(FBDMG_SECTION_H);
    if (not tab) then return; end

    FBDmgHeader = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    FBDmgHeader:SetPoint("TOPLEFT", tab, "TOPLEFT", 35, y);
    FBDmgHeader:SetText(FBT("DMG_HEADER"));

    FBDmgEnabledCheck = FBHealBox_CreateCheck("FBHealBoxDmgEnabledCheck", tab, 34, y - 20, "DMG_ENABLED", "DMG_ENABLED_TIP", function()
        FBDmg_Cfg().Enabled = FBDmgEnabledCheck:GetChecked() and 1 or 0;
        FBDmg_UpdateActive();
    end);
    FBDmgEnabledCheck:SetChecked(nil);

    FBDmgMarginSlider = FBHealBox_CreateSlider("FBDmgMarginSlider", tab, 268, y - 40, "DMG_MARGIN",
        FBDmg_Cfg, "Margin", 0, 50, 5, false, nil, nil, 170);

    FBDmgSourceText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    FBDmgSourceText:SetPoint("TOPLEFT", tab, "TOPLEFT", 40, y - 80);
    FBDmgSourceText:SetWidth(390);
    FBDmgSourceText:SetJustifyH("LEFT");
    FBDmgSpellText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    FBDmgSpellText:SetPoint("TOPLEFT", tab, "TOPLEFT", 40, y - 96);
    FBDmgSpellText:SetWidth(390);
    FBDmgSpellText:SetJustifyH("LEFT");
    FBDmgInfoText = tab:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
    FBDmgInfoText:SetPoint("TOPLEFT", tab, "TOPLEFT", 35, y - 120);
    FBDmgInfoText:SetWidth(395);
    FBDmgInfoText:SetJustifyH("LEFT");
    FBDmgInfoText:SetText(FBT("DMG_INFO"));

    FBDmg_UpdateSourceText();
    FBDmg_UpdateSpellText();
    FBDmg_SyncOptions();
    -- beim Oeffnen des Fensters die Zielzeile auffrischen (Vor-Hook auf OnShow)
    local prevShow = FBPanel:GetScript("OnShow");
    FBPanel:SetScript("OnShow", function()
        if (prevShow) then prevShow(); end
        FBDmg_UpdateSourceText();
        FBDmg_UpdateSpellText();
    end);
end

function FBDmg_SyncOptions()
    local cfg = FBDmg_Cfg();
    if (FBDmgEnabledCheck) then FBDmgEnabledCheck:SetChecked(cfg.Enabled == 1); end
    if (FBDmgMarginSlider) then FBDmgMarginSlider:SetValue(cfg.Margin or 20); end
    FBDmg_UpdateActive();
    return true;
end

function FBDmg_ApplyLocale()
    if (FBDmgHeader) then FBDmgHeader:SetText(FBT("DMG_HEADER")); end
    if (FBDmgEnabledCheck) then FBDmgEnabledCheck.Text:SetText(FBT("DMG_ENABLED")); FBDmgEnabledCheck.tooltipText = FBT("DMG_ENABLED_TIP"); end
    if (FBDmgInfoText) then FBDmgInfoText:SetText(FBT("DMG_INFO")); end
    FBHealBox_SliderText(FBDmgMarginSlider);
    FBDmg_UpdateSourceText();
    FBDmg_UpdateSpellText();
    return true;
end

-- ==========================================================================
-- [ Anbindung an den Kern ]
-- ==========================================================================

FBHealBox_RegisterHook("Loaded", function()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("DMG_LOADED"));
    FBDmg_UpdateActive();
    return true;
end);
FBHealBox_RegisterHook("Suppress", function() FBDmg_UpdateActive(); return true; end);
FBHealBox_RegisterHook("Defaults", function() return FBDmg_ApplyDefaults(); end);
FBHealBox_RegisterHook("SyncOptions", function() return FBDmg_SyncOptions(); end);
FBHealBox_RegisterHook("ApplyLocale", function() return FBDmg_ApplyLocale(); end);
FBHealBox_RegisterHook("Status", function()
    local cfg = FBDmg_Cfg();
    local state = FBT("FBP_STATE_OFF");
    if (cfg.Enabled == 1) then state = FBT("FBP_STATE_ON"); end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..format(FBT("DMG_STATUS"), state, cfg.Margin or 20, FBDmg_SourceText()));
    return true;
end);
FBHealBox_RegisterHook("Slash", function(msg)
    if (msg == "damage" or msg == "dmg") then
        local cfg = FBDmg_Cfg();
        if (cfg.Enabled == 1) then cfg.Enabled = 0; else cfg.Enabled = 1; end
        FBDmg_SyncOptions();   -- schaltet auch die Ereignisse um
        local key = "DMG_OFF";
        if (cfg.Enabled == 1) then key = "DMG_ON"; end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT(key));
        return true;
    end
    return false;
end);

FBDmg_ApplyDefaults();
FBDmg_BuildOptions();
FBDmg_HookUseAction();
