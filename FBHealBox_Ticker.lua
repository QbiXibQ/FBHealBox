-- ==========================================================================
-- Heal Box Vanilla: Mana-Ticker (Modul, ab v1.4.3)
--
-- Ein Funke wandert ueber den Manastreifen der eigenen Plakette (und der
-- eigenen Raid-Zelle) und zeigt den 2-Sekunden-Regenerationstick des
-- Servers. Nach jedem Manaverbrauch laeuft er orange ueber die
-- 5-Sekunden-Regel, verlaengert bis zum ersten Tick nach deren Ablauf,
-- denn erst dort setzt die Regeneration wieder ein.
--
-- Erkennung ohne Combatlog und ohne SuperWoW:
--   * UNIT_MANA fuer "player": Mana gestiegen = Tick-Kandidat,
--     Mana gesunken = Zauber hat gekostet, Regel startet.
--   * Das Tickraster ist serverseitig fest (2 s). Der letzte erkannte Tick
--     wird gemerkt, weitere werden extrapoliert (auch bei vollem Mana),
--     jeder passende echte Tick synchronisiert neu.
--   * Kandidaten ausserhalb der Toleranz um den erwarteten Zeitpunkt
--     (Manaquelle-Totem, Innervate-Pulse) werden verworfen; erst nach
--     mehreren Fehlschlaegen in Folge wird ein neues Raster angenommen.
--     Grosse Spruenge (Traenke, Runen) zaehlen nie als Tick.
--
-- Bei vollem Mana ist der Funke aus (nichts zu regenerieren).
-- Haengt sich wie der Raidmodus nur ueber die Hook-Schnittstelle ein.
-- ==========================================================================

if (FBHealBox_TickerLoaded) then return; end
FBHealBox_TickerLoaded = true;

FBTICK_PERIOD      = 2.0;    -- Sek. zwischen zwei Regenerationsticks
FBTICK_FSR         = 5.0;    -- Sek. Fuenf-Sekunden-Regel
FBTICK_RESYNC_MISS = 3;      -- so viele Kandidaten ausserhalb der Toleranz -> neues Raster
FBTICK_POTION_FACT = 4;      -- Zuwachs groesser als das Vielfache der Tickgroesse = Trank
FBTICK_POTION_MIN  = 300;    -- ... und mindestens so viel Mana

FBTICK_COLOR_TICK  = { 1.00, 1.00, 1.00, 0.95 };   -- Funke im Tickzyklus
FBTICK_COLOR_FSR   = { 1.00, 0.55, 0.10, 1.00 };   -- Funke waehrend der Regel

FBTickerDefaults = {
    Enabled   = 1,      -- Ticker an/aus
    FSR       = 1,      -- 5-Sekunden-Regel anzeigen
    Tolerance = 0.3,    -- Sek. Toleranz um den erwarteten Tick
    Offset    = 0.0,    -- Sek. Vorlauf (Latenzausgleich): Funke laeuft frueher los
    SparkW    = 2,      -- px Funkenbreite
};

-- ==========================================================================
-- [ Texte ]
-- ==========================================================================

FBLocale["enUS"].TICK_HEADER       = "Mana ticker";
FBLocale["enUS"].TICK_ENABLED      = "Mana ticker";
FBLocale["enUS"].TICK_ENABLED_TIP  = "A spark travels across your own mana bar every 2 seconds, in step with the server's mana regeneration tick. Cast right after the spark reaches the end and you lose no regeneration. Needs the mana bar to be on.";
FBLocale["enUS"].TICK_FSR          = "Five-second rule";
FBLocale["enUS"].TICK_FSR_TIP      = "After you spend mana the spark turns orange and runs over the five seconds (plus the wait for the next tick) until spirit regeneration resumes.";
FBLocale["enUS"].TICK_TOLERANCE    = "Tick tolerance: |cFFFFFFFF%s s";
FBLocale["enUS"].TICK_OFFSET       = "Tick offset: |cFFFFFFFF%s s";
FBLocale["enUS"].TICK_SPARKW       = "Spark width: |cFFFFFFFF%s px";
FBLocale["enUS"].TICK_INFO         = "White spark: time until the next regeneration tick. Orange spark: five-second rule running, regeneration resumes when it reaches the end. Raise the tolerance if ticks are missed (totems, Innervate); use the offset if the spark arrives late compared to your mana jumps.";
FBLocale["enUS"].TICK_STATUS       = "Ticker: %s, next tick in %.1f s%s";
FBLocale["enUS"].TICK_SYNCED       = "synced";
FBLocale["enUS"].TICK_UNSYNCED     = "waiting for first tick";
FBLocale["enUS"].TICK_STATUS_FSR   = ", five-second rule %.1f s";
FBLocale["enUS"].TICK_LOADED       = "Mana ticker module loaded: section in tab |cFFFFFFFFExtras|r, /fbp ticker";
FBLocale["enUS"].TICK_ON           = "Mana ticker |cFF00FF00on|r.";
FBLocale["enUS"].TICK_OFF          = "Mana ticker |cFFFF0000off|r.";

FBLocale["deDE"].TICK_HEADER       = "Mana-Ticker";
FBLocale["deDE"].TICK_ENABLED      = "Mana-Ticker";
FBLocale["deDE"].TICK_ENABLED_TIP  = "Ein Funke wandert alle 2 Sekunden ueber deinen eigenen Manastreifen, im Takt des Regenerationsticks des Servers. Wer direkt nach dem Funken am Ende castet, verliert keine Regeneration. Braucht den eingeschalteten Manabalken.";
FBLocale["deDE"].TICK_FSR          = "Fuenf-Sekunden-Regel";
FBLocale["deDE"].TICK_FSR_TIP      = "Nach jedem Manaverbrauch wird der Funke orange und laeuft ueber die fuenf Sekunden (plus Wartezeit bis zum naechsten Tick), bis die Willenskraft-Regeneration wieder einsetzt.";
FBLocale["deDE"].TICK_TOLERANCE    = "Tick-Toleranz: |cFFFFFFFF%s s";
FBLocale["deDE"].TICK_OFFSET       = "Tick-Vorlauf: |cFFFFFFFF%s s";

-- Weitere Sprachen (Spanisch, Franzoesisch, Italienisch)

FBLocale["esES"].TICK_HEADER       = "Ticker de maná";
FBLocale["esES"].TICK_ENABLED      = "Ticker de maná";
FBLocale["esES"].TICK_ENABLED_TIP  = "Una chispa recorre tu propia barra de maná cada 2 segundos, al compás del pulso de regeneración de maná del servidor. Lanza justo después de que la chispa llegue al final y no perderás regeneración. Requiere la barra de maná activada.";
FBLocale["esES"].TICK_FSR          = "Regla de los cinco segundos";
FBLocale["esES"].TICK_FSR_TIP      = "Tras gastar maná, la chispa se vuelve naranja y recorre los cinco segundos (más la espera hasta el siguiente pulso) hasta que la regeneración por espíritu se reanuda.";
FBLocale["esES"].TICK_TOLERANCE    = "Tolerancia del pulso: |cFFFFFFFF%s s";
FBLocale["esES"].TICK_OFFSET       = "Desfase del pulso: |cFFFFFFFF%s s";
FBLocale["esES"].TICK_SPARKW       = "Ancho de la chispa: |cFFFFFFFF%s px";
FBLocale["esES"].TICK_INFO         = "Chispa blanca: tiempo hasta el siguiente pulso de regeneración. Chispa naranja: regla de los cinco segundos en curso, la regeneración se reanuda cuando llega al final. Sube la tolerancia si se pierden pulsos (tótems, Estimular); usa el desfase si la chispa llega tarde respecto a tus saltos de maná.";
FBLocale["esES"].TICK_STATUS       = "Ticker: %s, siguiente pulso en %.1f s%s";
FBLocale["esES"].TICK_SYNCED       = "sincronizado";
FBLocale["esES"].TICK_UNSYNCED     = "esperando el primer pulso";
FBLocale["esES"].TICK_STATUS_FSR   = ", regla de los cinco segundos %.1f s";
FBLocale["esES"].TICK_LOADED       = "Módulo de ticker de maná cargado: pestaña |cFFFFFFFFExtras|r en las opciones, /fbp ticker";
FBLocale["esES"].TICK_ON           = "Ticker de maná |cFF00FF00activado|r.";
FBLocale["esES"].TICK_OFF          = "Ticker de maná |cFFFF0000desactivado|r.";

FBLocale["frFR"].TICK_HEADER       = "Ticker de mana";
FBLocale["frFR"].TICK_ENABLED      = "Ticker de mana";
FBLocale["frFR"].TICK_ENABLED_TIP  = "Une étincelle parcourt votre propre barre de mana toutes les 2 secondes, au rythme du tick de régénération de mana du serveur. Lancez juste après que l'étincelle atteint la fin et vous ne perdez aucune régénération. Nécessite la barre de mana activée.";
FBLocale["frFR"].TICK_FSR          = "Règle des cinq secondes";
FBLocale["frFR"].TICK_FSR_TIP      = "Après une dépense de mana, l'étincelle devient orange et parcourt les cinq secondes (plus l'attente du prochain tick) jusqu'à la reprise de la régénération par l'esprit.";
FBLocale["frFR"].TICK_TOLERANCE    = "Tolérance du tick : |cFFFFFFFF%s s";
FBLocale["frFR"].TICK_OFFSET       = "Décalage du tick : |cFFFFFFFF%s s";
FBLocale["frFR"].TICK_SPARKW       = "Largeur de l'étincelle : |cFFFFFFFF%s px";
FBLocale["frFR"].TICK_INFO         = "Étincelle blanche : temps jusqu'au prochain tick de régénération. Étincelle orange : règle des cinq secondes en cours, la régénération reprend quand elle atteint la fin. Augmentez la tolérance si des ticks sont manqués (totems, Innervation) ; utilisez le décalage si l'étincelle arrive en retard par rapport à vos sauts de mana.";
FBLocale["frFR"].TICK_STATUS       = "Ticker : %s, prochain tick dans %.1f s%s";
FBLocale["frFR"].TICK_SYNCED       = "synchronisé";
FBLocale["frFR"].TICK_UNSYNCED     = "en attente du premier tick";
FBLocale["frFR"].TICK_STATUS_FSR   = ", règle des cinq secondes %.1f s";
FBLocale["frFR"].TICK_LOADED       = "Module ticker de mana chargé : onglet |cFFFFFFFFExtras|r dans les options, /fbp ticker";
FBLocale["frFR"].TICK_ON           = "Ticker de mana |cFF00FF00activé|r.";
FBLocale["frFR"].TICK_OFF          = "Ticker de mana |cFFFF0000désactivé|r.";

FBLocale["itIT"].TICK_HEADER       = "Ticker del mana";
FBLocale["itIT"].TICK_ENABLED      = "Ticker del mana";
FBLocale["itIT"].TICK_ENABLED_TIP  = "Una scintilla attraversa la tua barra del mana ogni 2 secondi, a tempo con il tick di rigenerazione del mana del server. Lancia subito dopo che la scintilla arriva in fondo e non perdi rigenerazione. Richiede la barra del mana attiva.";
FBLocale["itIT"].TICK_FSR          = "Regola dei cinque secondi";
FBLocale["itIT"].TICK_FSR_TIP      = "Dopo aver speso mana la scintilla diventa arancione e percorre i cinque secondi (più l'attesa del tick successivo) finché la rigenerazione da spirito riprende.";
FBLocale["itIT"].TICK_TOLERANCE    = "Tolleranza del tick: |cFFFFFFFF%s s";
FBLocale["itIT"].TICK_OFFSET       = "Anticipo del tick: |cFFFFFFFF%s s";
FBLocale["itIT"].TICK_SPARKW       = "Larghezza scintilla: |cFFFFFFFF%s px";
FBLocale["itIT"].TICK_INFO         = "Scintilla bianca: tempo al prossimo tick di rigenerazione. Scintilla arancione: regola dei cinque secondi in corso, la rigenerazione riprende quando arriva in fondo. Alza la tolleranza se i tick vengono persi (totem, Innervazione); usa l'anticipo se la scintilla arriva in ritardo rispetto ai tuoi salti di mana.";
FBLocale["itIT"].TICK_STATUS       = "Ticker: %s, prossimo tick tra %.1f s%s";
FBLocale["itIT"].TICK_SYNCED       = "sincronizzato";
FBLocale["itIT"].TICK_UNSYNCED     = "in attesa del primo tick";
FBLocale["itIT"].TICK_STATUS_FSR   = ", regola dei cinque secondi %.1f s";
FBLocale["itIT"].TICK_LOADED       = "Modulo ticker del mana caricato: scheda |cFFFFFFFFExtra|r nelle opzioni, /fbp ticker";
FBLocale["itIT"].TICK_ON           = "Ticker del mana |cFF00FF00attivo|r.";
FBLocale["itIT"].TICK_OFF          = "Ticker del mana |cFFFF0000disattivato|r.";
FBLocale["deDE"].TICK_SPARKW       = "Funkenbreite: |cFFFFFFFF%s px";
FBLocale["deDE"].TICK_INFO         = "Weisser Funke: Zeit bis zum naechsten Regenerationstick. Oranger Funke: Fuenf-Sekunden-Regel laeuft, am Ende setzt die Regeneration wieder ein. Toleranz erhoehen, wenn Ticks verpasst werden (Totems, Anregen); Vorlauf nutzen, wenn der Funke spaeter ankommt als deine Manaspruenge.";
FBLocale["deDE"].TICK_STATUS       = "Ticker: %s, naechster Tick in %.1f s%s";
FBLocale["deDE"].TICK_SYNCED       = "synchron";
FBLocale["deDE"].TICK_UNSYNCED     = "wartet auf ersten Tick";
FBLocale["deDE"].TICK_STATUS_FSR   = ", Fuenf-Sekunden-Regel %.1f s";
FBLocale["deDE"].TICK_LOADED       = "Mana-Ticker-Modul geladen: Abschnitt im Reiter |cFFFFFFFFExtras|r, /fbp ticker";
FBLocale["deDE"].TICK_ON           = "Mana-Ticker |cFF00FF00an|r.";
FBLocale["deDE"].TICK_OFF          = "Mana-Ticker |cFFFF0000aus|r.";

-- ==========================================================================
-- [ Zustand ]
-- ==========================================================================

FBTicker = {
    lastTick  = nil,    -- GetTime() des letzten akzeptierten Ticks (Rasterpunkt)
    lastMana  = nil,    -- zuletzt gesehener Manawert
    tickSize  = nil,    -- gelernte typische Tickgroesse (fuer den Trankfilter)
    misses    = 0,      -- Kandidaten in Folge ausserhalb der Toleranz
    fsrStart  = nil,    -- Beginn der Fuenf-Sekunden-Regel
    fsrUntil  = nil,    -- ihr Ende (5 s nach Beginn)
    sparks    = {},     -- Funken auf den Manabalken (Plakette, Raid-Zelle)
};

function FBTicker_Cfg()
    if (not HealBox.Ticker) then FBTicker_ApplyDefaults(); end
    return HealBox.Ticker;
end

function FBTicker_ApplyDefaults()
    if (not HealBox.Ticker) then HealBox.Ticker = {}; end
    for k, v in pairs(FBTickerDefaults) do
        if (HealBox.Ticker[k] == nil) then HealBox.Ticker[k] = v; end
    end
    return true;
end

-- Volles Mana? (dann gibt es nichts zu regenerieren, Funke aus)
function FBTicker_ManaFull()
    local mp, mpMax = UnitMana("player"), UnitManaMax("player");
    if (not mp) or (not mpMax) or (mpMax <= 0) then return true; end
    return (mp >= mpMax);
end

-- Nutzt der Spieler gerade Mana? (Druiden in Gestalt: nein)
function FBTicker_PlayerHasMana()
    if (UnitPowerType and UnitPowerType("player") ~= 0) then return false; end
    local max = UnitManaMax("player");
    return (max and max > 0);
end

-- ==========================================================================
-- [ Erkennung ]
-- ==========================================================================

-- Naechster Rasterpunkt ab Zeitpunkt t (t selbst, wenn t genau auf dem Raster liegt)
function FBTicker_NextTickAfter(t)
    local last = FBTicker.lastTick;
    if (not last) then return nil; end
    if (t <= last) then return last; end
    local k = math.ceil((t - last) / FBTICK_PERIOD - 0.0001);
    return last + k * FBTICK_PERIOD;
end

-- Abstand von t zum naechstgelegenen Rasterpunkt
function FBTicker_GridDistance(t)
    local last = FBTicker.lastTick;
    if (not last) then return nil; end
    local phase = math.mod(t - last, FBTICK_PERIOD);
    if (phase < 0) then phase = phase + FBTICK_PERIOD; end
    if (phase > FBTICK_PERIOD / 2) then phase = FBTICK_PERIOD - phase; end
    return phase;
end

function FBTicker_OnManaChanged()
    local cfg = FBTicker_Cfg();
    local now = GetTime();
    local mana = UnitMana("player") or 0;
    local prev = FBTicker.lastMana;
    FBTicker.lastMana = mana;
    if (prev == nil) then return; end
    local delta = mana - prev;

    if (delta < 0) then
        -- Mana ausgegeben: Fuenf-Sekunden-Regel beginnt jetzt
        FBTicker.fsrStart = now;
        FBTicker.fsrUntil = now + FBTICK_FSR;
        return;
    end
    if (delta == 0) then return; end

    -- Zuwachs: Trank oder Rune? (grosser Sprung im Vergleich zur Tickgroesse)
    if (FBTicker.tickSize and delta >= FBTICK_POTION_MIN and delta > FBTicker.tickSize * FBTICK_POTION_FACT) then
        return;
    end

    if (not FBTicker.lastTick) then
        FBTicker.lastTick = now;
        FBTicker.misses = 0;
    else
        local dist = FBTicker_GridDistance(now);
        if (dist <= (cfg.Tolerance or 0.3)) then
            FBTicker.lastTick = now;           -- passt ins Raster: neu synchronisieren
            FBTicker.misses = 0;
        else
            FBTicker.misses = FBTicker.misses + 1;
            if (FBTicker.misses >= FBTICK_RESYNC_MISS) then
                FBTicker.lastTick = now;       -- Raster hat sich verschoben
                FBTicker.misses = 0;
            end
            return;                            -- fremder Puls, Tickgroesse nicht lernen
        end
    end

    -- Tickgroesse lernen (gleitend), nur ausserhalb der Regel (volle Ticks)
    local inFSR = (FBTicker.fsrUntil and now < FBTicker.fsrUntil);
    if (not inFSR) then
        if (not FBTicker.tickSize) then
            FBTicker.tickSize = delta;
        else
            FBTicker.tickSize = FBTicker.tickSize * 0.7 + delta * 0.3;
        end
    end
end

-- Zeitpunkt, an dem die Regeneration nach der Regel wieder einsetzt:
-- erster Rasterpunkt nach fsrUntil (ohne Raster: fsrUntil selbst)
function FBTicker_FSREnd()
    if (not FBTicker.fsrUntil) then return nil; end
    local grid = FBTicker_NextTickAfter(FBTicker.fsrUntil);
    if (grid) then return grid; end
    return FBTicker.fsrUntil;
end

-- Anteil 0..1 und Modus ("tick" | "fsr" | nil) fuer den Funken zur Zeit now
function FBTicker_Progress(now)
    local cfg = FBTicker_Cfg();
    local t = now + (cfg.Offset or 0);

    if (cfg.FSR == 1 and FBTicker.fsrStart) then
        local fsrEnd = FBTicker_FSREnd();
        if (fsrEnd and t < fsrEnd) then
            local total = fsrEnd - FBTicker.fsrStart;
            if (total <= 0) then total = FBTICK_FSR; end
            local frac = (t - FBTicker.fsrStart) / total;
            if (frac < 0) then frac = 0; end
            if (frac > 1) then frac = 1; end
            return frac, "fsr";
        end
        -- Regel vorbei
        FBTicker.fsrStart = nil;
        FBTicker.fsrUntil = nil;
    end

    if (not FBTicker.lastTick) then return nil, nil; end
    local phase = math.mod(t - FBTicker.lastTick, FBTICK_PERIOD);
    if (phase < 0) then phase = phase + FBTICK_PERIOD; end
    return phase / FBTICK_PERIOD, "tick";
end

function FBTicker_Reset()
    FBTicker.lastTick = nil;
    FBTicker.lastMana = UnitMana("player");
    FBTicker.tickSize = nil;
    FBTicker.misses = 0;
    FBTicker.fsrStart = nil;
    FBTicker.fsrUntil = nil;
end

-- ==========================================================================
-- [ Funken ]
-- ==========================================================================

-- Funke auf einem Manabalken anlegen (einmal je Balken)
function FBTicker_SparkFor(bar)
    if (not bar) then return nil; end
    if (bar.fbSpark) then return bar.fbSpark; end
    local s = bar:CreateTexture(nil, "OVERLAY");
    s:SetTexture(1, 1, 1, 1);
    s:SetWidth(2);
    s:SetHeight(4);
    s:SetPoint("LEFT", bar, "LEFT", 0, 0);
    s:Hide();
    bar.fbSpark = s;
    return s;
end

-- Balken einsammeln: eigene Plakette und, falls vorhanden, eigene Raid-Zelle
function FBTicker_CollectBars()
    -- alte Funken verstecken, Zwischenspeicher neu
    FBTicker_HideAll();
    FBTicker.sparks = {};
    if (FBHealBox1 and FBHealBox1.ManaBar) then
        table.insert(FBTicker.sparks, { bar = FBHealBox1.ManaBar, spark = FBTicker_SparkFor(FBHealBox1.ManaBar) });
    end
    if (FBRaidUnitCell and FBRaidTestMode == 0) then
        local me = UnitName("player");
        for unit, cell in pairs(FBRaidUnitCell) do
            if (cell.name == me and cell.ManaBar) then
                table.insert(FBTicker.sparks, { bar = cell.ManaBar, spark = FBTicker_SparkFor(cell.ManaBar) });
            end
        end
    end
end

function FBTicker_HideAll()
    for _, e in ipairs(FBTicker.sparks) do
        if (e.spark and e.shown ~= false) then e.shown = false; e.spark:Hide(); end
    end
end

-- Torwaechter fuer das Zeichnen: wird nur bei Events und Optionswechseln
-- neu bewertet (Mana-Events, Gestaltwechsel, Schalter), nicht jeden Frame.
FBTicker.gate = false;
function FBTicker_UpdateGate()
    local cfg = FBTicker_Cfg();
    FBTicker.gate = (cfg.Enabled == 1) and (HealBox.Active == 1)
        and FBTicker_PlayerHasMana() and (not FBTicker_ManaFull());
    if (not FBTicker.gate) then FBTicker_HideAll(); end
end

function FBTicker_Draw()
    if (not FBTicker.gate) then return; end
    local now = GetTime();
    local frac, mode = FBTicker_Progress(now);
    if (not frac) then
        FBTicker_HideAll();
        return;
    end
    local col = FBTICK_COLOR_TICK;
    if (mode == "fsr") then col = FBTICK_COLOR_FSR; end
    local w = FBTicker_Cfg().SparkW or 2;

    for _, e in ipairs(FBTicker.sparks) do
        local bar, s = e.bar, e.spark;
        if (s and bar) then
            if (bar:IsShown()) then
                -- Breite und Hoehe aendern sich nur beim Umbauen der Anzeige.
                -- Sie werden deshalb viermal je Sekunde nachgelesen und
                -- dazwischen gemerkt; so kostet das Zeichnen je Frame fast
                -- nichts mehr und darf wieder in jedem Frame laufen.
                if (not e.geomT) or ((now - e.geomT) >= FBTICK_GEOM_STEP) then
                    e.geomT = now;
                    e.bw = bar:GetWidth() or 0;
                    e.bh = bar:GetHeight() or 0;
                end
                local bw = e.bw or 0;
                local bh = e.bh or 0;
                if (bw > w and bh > 0) then
                    if (e.w ~= w or e.h ~= bh) then
                        e.w = w; e.h = bh;
                        s:SetWidth(w);
                        s:SetHeight(bh);
                    end
                    if (e.mode ~= mode) then
                        e.mode = mode;
                        s:SetTexture(col[1], col[2], col[3], col[4]);
                    end
                    -- Anker setzen, sobald sich die Position ueberhaupt
                    -- geaendert hat. Eine Schwelle von einem halben Pixel
                    -- klingt sparsam, der Funke wandert aber nur rund 20 px
                    -- je Sekunde: bei 60 Bildern kam er damit nur in jedem
                    -- zweiten Frame voran, und je nach Rundung mal nach einem,
                    -- mal nach zwei Frames. Genau das sah ruckelig aus. Die
                    -- Feinrundung auf ganze Bildpunkte macht ohnehin die
                    -- Oberflaeche selbst.
                    local x = frac * (bw - w);
                    if (not e.x) or (math.abs(x - e.x) >= 0.05) then
                        e.x = x;
                        s:ClearAllPoints();
                        s:SetPoint("LEFT", bar, "LEFT", x, 0);
                    end
                    if (not e.shown) then e.shown = true; s:Show(); end
                else
                    if (e.shown) then e.shown = false; s:Hide(); end
                end
            elseif (e.shown) then
                e.shown = false; s:Hide();
            end
        end
    end
end

-- ==========================================================================
-- [ Events ]
-- ==========================================================================

FBTickerFrame = CreateFrame("Frame", "FBHealBoxTickerFrame", UIParent);
FBTickerFrame:RegisterEvent("UNIT_MANA");
FBTickerFrame:RegisterEvent("UNIT_MAXMANA");
FBTickerFrame:RegisterEvent("UNIT_DISPLAYPOWER");
FBTickerFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
FBTickerFrame:SetScript("OnEvent", function()
    if (FBAddonSuppressed) then return; end
    if (event == "PLAYER_ENTERING_WORLD") then
        FBTicker_Reset();
        FBTicker_CollectBars();
        FBTicker_UpdateGate();
        return;
    end
    if (arg1 ~= "player") then return; end
    if (event == "UNIT_MANA") then
        FBTicker_OnManaChanged();
    elseif (event == "UNIT_DISPLAYPOWER") then
        FBTicker_Reset();
    else
        FBTicker.lastMana = UnitMana("player");
    end
    FBTicker_UpdateGate();
end);
-- Gezeichnet wird in jedem Frame. Ein fester Takt spart zwar Durchlaeufe,
-- macht die Bewegung aber sichtbar stufig: der Funke braucht fuer den Balken
-- fuenf Sekunden, jede ausgelassene Position sieht man sofort. Teuer ist das
-- Zeichnen nicht mehr, weil die Balkenmasse gemerkt werden und der Ausstieg
-- ueber das Gate davor sitzt (voller Manabalken = gar kein Durchlauf).
FBTICK_GEOM_STEP = 0.25;   -- Sek.: so oft werden Breite und Hoehe nachgelesen

FBTickerFrame:SetScript("OnUpdate", function()
    if (FBAddonSuppressed) then return; end
    if (not FBTicker.gate) then return; end
    FBTicker_Draw();
end);

-- ==========================================================================
-- [ Abschnitt im Reiter "Extras" ]
--
-- Den Reiter verwaltet der Kern (FBHealBox_ExtrasSection); er wird mit
-- Smart Damage geteilt, jedes Modul funktioniert aber auch allein.
-- ==========================================================================

FBTickerSliders = {};
FBTICK_SECTION_H = 232;   -- px, Hoehe des Abschnitts

function FBTicker_BuildOptions()
    local tab, top = FBHealBox_ExtrasSection(FBTICK_SECTION_H);
    if (not tab) then return; end
    FBTickerHeader = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    FBTickerHeader:SetPoint("TOPLEFT", tab, "TOPLEFT", 35, top);
    FBTickerHeader:SetText(FBT("TICK_HEADER"));
    local y = top - 26;

    FBTickerEnabledCheck = FBHealBox_CreateCheck("FBHealBoxTickerEnabledCheck", tab, 40, y, "TICK_ENABLED", "TICK_ENABLED_TIP", function()
        FBTicker_Cfg().Enabled = FBTickerEnabledCheck:GetChecked() and 1 or 0;
        FBTicker_UpdateGate();
        FBTicker_Draw();
    end);
    FBTickerFSRCheck = FBHealBox_CreateCheck("FBHealBoxTickerFSRCheck", tab, 250, y, "TICK_FSR", "TICK_FSR_TIP", function()
        FBTicker_Cfg().FSR = FBTickerFSRCheck:GetChecked() and 1 or 0;
        FBTicker_Draw();
    end);

    local sy = y - 60;
    FBHealBox_CreateSlider("FBTickerToleranceSlider", tab, 75, sy, "TICK_TOLERANCE", FBTicker_Cfg, "Tolerance", 0.1, 0.6, 0.1, true, nil, FBTickerSliders);
    FBHealBox_CreateSlider("FBTickerOffsetSlider", tab, 260, sy, "TICK_OFFSET", FBTicker_Cfg, "Offset", 0.0, 0.5, 0.1, true, nil, FBTickerSliders);
    FBHealBox_CreateSlider("FBTickerSparkWSlider", tab, 75, sy - 46, "TICK_SPARKW", FBTicker_Cfg, "SparkW", 1, 4, 1, false, nil, FBTickerSliders);

    FBTickerInfoText = tab:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
    FBTickerInfoText:SetPoint("TOPLEFT", tab, "TOPLEFT", 35, sy - 84);
    FBTickerInfoText:SetWidth(395);
    FBTickerInfoText:SetJustifyH("LEFT");
    FBTickerInfoText:SetText(FBT("TICK_INFO"));

    FBTicker_SyncOptions();
end

function FBTicker_SyncOptions()
    local cfg = FBTicker_Cfg();
    if (FBTickerEnabledCheck) then FBTickerEnabledCheck:SetChecked(cfg.Enabled == 1); end
    if (FBTickerFSRCheck) then FBTickerFSRCheck:SetChecked(cfg.FSR == 1); end
    for key, s in pairs(FBTickerSliders) do
        if (cfg[key] ~= nil) then s:SetValue(cfg[key]); end
    end
    return true;
end

function FBTicker_ApplyLocale()
    if (FBTickerHeader) then FBTickerHeader:SetText(FBT("TICK_HEADER")); end
    if (FBTickerEnabledCheck) then FBTickerEnabledCheck.Text:SetText(FBT("TICK_ENABLED")); FBTickerEnabledCheck.tooltipText = FBT("TICK_ENABLED_TIP"); end
    if (FBTickerFSRCheck) then FBTickerFSRCheck.Text:SetText(FBT("TICK_FSR")); FBTickerFSRCheck.tooltipText = FBT("TICK_FSR_TIP"); end
    if (FBTickerInfoText) then FBTickerInfoText:SetText(FBT("TICK_INFO")); end
    for _, s in pairs(FBTickerSliders) do FBHealBox_SliderText(s); end
    return true;
end

-- ==========================================================================
-- [ Anbindung an den Kern ]
-- ==========================================================================

FBHealBox_RegisterHook("Loaded", function()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT("TICK_LOADED"));
    return true;
end);
-- Klassensperre des Kerns: Funken ausknipsen
FBHealBox_RegisterHook("Suppress", function()
    for _, e in ipairs(FBTicker.sparks) do
        if (e.spark) then e.spark:Hide(); end
    end
    return true;
end);
FBHealBox_RegisterHook("Defaults", function() return FBTicker_ApplyDefaults(); end);
FBHealBox_RegisterHook("SyncOptions", function() return FBTicker_SyncOptions(); end);
FBHealBox_RegisterHook("ApplyLocale", function() return FBTicker_ApplyLocale(); end);
FBHealBox_RegisterHook("UpdateNames", function() FBTicker_CollectBars(); FBTicker_UpdateGate(); return true; end);
-- Das Raidraster baut auch ohne "UpdateNames" um (reines RAID_ROSTER_UPDATE,
-- etwa beim Ueberschreiten der Schwelle). Ohne diesen Hook fehlte der Funke
-- dann oder lief auf der Zelle eines anderen Spielers.
FBHealBox_RegisterHook("RaidRoster", function() FBTicker_CollectBars(); FBTicker_UpdateGate(); return true; end);
FBHealBox_RegisterHook("ActiveToggle", function() FBTicker_UpdateGate(); FBTicker_Draw(); return true; end);
FBHealBox_RegisterHook("Status", function()
    local state = FBT("TICK_UNSYNCED");
    local nextIn = 0;
    if (FBTicker.lastTick) then
        state = FBT("TICK_SYNCED");
        local nxt = FBTicker_NextTickAfter(GetTime());
        if (nxt) then nextIn = nxt - GetTime(); end
    end
    local fsr = "";
    local fsrEnd = FBTicker_FSREnd();
    if (fsrEnd and fsrEnd > GetTime()) then fsr = format(FBT("TICK_STATUS_FSR"), fsrEnd - GetTime()); end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[FBP]|r "..format(FBT("TICK_STATUS"), state, nextIn, fsr));
    return true;
end);
FBHealBox_RegisterHook("Slash", function(msg)
    if (msg == "ticker") then
        local cfg = FBTicker_Cfg();
        if (cfg.Enabled == 1) then cfg.Enabled = 0; else cfg.Enabled = 1; end
        FBTicker_SyncOptions();
        FBTicker_UpdateGate();
        FBTicker_Draw();
        local key = "TICK_OFF";
        if (cfg.Enabled == 1) then key = "TICK_ON"; end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00"..FBADDON_NAME..":|r "..FBT(key));
        return true;
    end
    return false;
end);

FBTicker_ApplyDefaults();
FBTicker_BuildOptions();
FBTicker_CollectBars();
