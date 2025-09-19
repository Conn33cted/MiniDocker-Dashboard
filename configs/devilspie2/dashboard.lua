-- devilspie2 rule for Dashboard window (Chromium --class=DashboardApp)

local function s(v) return v or "" end
local wname = s(get_window_name())
local wclass = s(get_window_class())           -- "DashboardApp"
local winst  = s(get_class_instance_name())    -- np. home_anti_...
local app    = s(get_application_name())       -- chromium / Dashboard / ścieżka

-- dopasowanie: klasa "DashboardApp" lub awaryjnie chromium + "dashboard" w tytule/instancji
local function has(hay, needle)
  return string.find(string.lower(hay), string.lower(needle), 1, true) ~= nil
end
local is_dash = (wclass == "DashboardApp")
             or (has(app, "chrom") and (has(winst, "dashboard") or has(wname, "dashboard")))

if is_dash then
  print(string.format("[ds2] match: class=%s inst=%s name=%s app=%s", wclass, winst, wname, app))

  set_skip_tasklist(true)     -- ukryj z paska zadań
  set_skip_pager(true)        -- ukryj z Alt+Tab
  set_window_above(true)      -- zawsze na wierzchu
  set_window_sticky(true)     -- na wszystkich wirtualnych desktopach
end
