' ---------------------------------------------------------------- entry
sub Start()
    m.mineSpecs = []
    m.edSlots = []          ' one slot (array of row specs) per DR page entry, filled as lazy lists arrive
    m.edEntries = []
    m.headSpecs = []
    m.mine = invalid
    mode = m.top.mode
    if mode = "home" then
        StartHome()
    else if mode = "series" then
        StartSeries()
    else
        StartPage(m.top.path, "pg")
    end if
end sub

sub Refresh()
    ' called when returning from the player: positions changed
    if m.top.mode = "home" then
        m.mine = invalid
        StartHomeMine()
    else if m.top.mode = "series" and m.top.chip <> "az" then
        m.mine = invalid
        StartSeries()
    end if
end sub

sub Rebuild()
    all = []
    for each s in m.headSpecs
        all.Push(s)
    end for
    for each s in m.mineSpecs
        all.Push(s)
    end for
    for each slot in m.edSlots
        for each s in slot
            all.Push(s)
        end for
    end for
    ShowSpecs(all, m.focusFirst = true)
    m.focusFirst = false
end sub

' ---------------------------------------------------------------- status helpers
function StatusText(st as String) as String
    if st = "C" then return "FORTSÆT"
    if st = "N" then return "NYT AFSNIT"
    if st = "X" then return "NÆSTE AFSNIT"
    return ""
end function

function StatusColor(st as String) as String
    if st = "N" then return "0x00A05AFF"
    if st = "X" then return "0x2B6CFFFF"
    return "0xFF0018FF"
end function

' opening a series from a tile: remember which episode the tile was about
function SeriesData(e as Object) as Object
    d = e.show
    if e.ep <> invalid then d._cont = e.ep
    return d
end function

' ---------------------------------------------------------------- FORSIDE
sub StartHome()
    SetBusy(true)
    StartHomeMine()
    StartPage("/", "ed")
end sub

sub StartHomeMine()
    if not m.top.loggedIn then
        m.mineSpecs = []
        return
    end if
    t = CreateObject("roSGNode", "MineTask")
    t.observeField("response", "onMine")
    t.control = "RUN"
    m.mineTask = t
end sub

sub onMine(event as Object)
    r = event.getData()
    SetBusy(false)
    if r = invalid then return
    m.mine = r
    if m.top.mode = "series" then
        BuildSeriesView()
        return
    end if
    specs = []
    if r.loggedOut = true then
        m.mineSpecs = []
        Rebuild()
        return
    end if
    ' banner: one card per series that needs attention
    cards = []
    for each e in r.entries
        if e.st <> "" then
            src = e.show
            if e.ep <> invalid then src = e.ep
            cards.Push({
                title: Txt(e.show.title), sub: e.line, chip: StatusText(e.st), chipColor: StatusColor(e.st),
                progress: e.prog, art: Sized(PickImage(src.images, ["tile", "wallpaper"]), 1290, 726), data: SeriesData(e)
            })
        end if
    end for
    if cards.Count() > 0 then
        n = cards.Count()
        if n > 16 then n = 16
        sl = []
        for i = 0 to n - 1
            sl.Push(cards[i])
        end for
        specs.Push(RowSpec("m-banner", "Mine serier", "hero", sl, 0))
    end if
    ' compact poster row of all my series (A-Å)
    mine = []
    for each e in r.entries
        mine.Push(e)
    end for
    sorted = []
    for each e in mine
        sorted.Push({ title: Txt(e.show.title), e: e })
    end for
    sorted = SortAA(sorted, "title", false)
    items = []
    k = 0
    for each x in sorted
        e = x.e
        if k < 12 then items.Push(PosterSpec(e.show, 165, { chip: StatusText(e.st), chipColor: StatusColor(e.st), progress: e.prog, data: SeriesData(e) }))
        k = k + 1
    end for
    if items.Count() > 0 then
        items.Push({ title: "Se alle ›", kind: "more", data: { go: { id: "series", chip: "mine" } } })
        specs.Push(RowSpec("m-mine", "Dine serier · " + sorted.Count().ToStr(), "poster", items, 165))
    end if
    ' one Udforsk row (max 10) + a way into the SERIER menu
    ex = []
    for each it in r.explore
        ex.Push(PosterSpec(it, 165, invalid))
    end for
    if ex.Count() > 0 then
        ex.Push({ title: "Flere serier ›", kind: "more", data: { go: { id: "series", chip: "all" } } })
        specs.Push(RowSpec("m-udf", "Udforsk serier · " + Txt(r.why), "poster", ex, 165))
    end if
    m.mineSpecs = specs
    m.focusFirst = specs.Count() > 0
    Rebuild()
end sub

' ---------------------------------------------------------------- any DR page (editorial home, kategorier, børn, ultra ...)
sub StartPage(path as String, prefix as String)
    m.pagePrefix = prefix
    SetBusy(true)
    CallApi(PageRequest(path), "onPage")
end sub

sub onPage(event as Object)
    r = event.getData()
    SetBusy(false)
    if r = invalid or not r.ok or r.json = invalid then
        if m.edEntries.Count() = 0 then ShowMessage("Kunne ikke hente siden.")
        return
    end if
    entries = []
    for each e in r.json.entries
        if e.type = "ListEntry" and e.template <> "TX1" then
            if m.top.mode <> "series" then
                entries.Push(e)
            else if m.pagePrefix = "az" and IsLetterTitle(Txt(e.title)) then
                entries.Push(e)
            else if m.pagePrefix = "se" and e.template = "P1" and not IsLetterTitle(Txt(e.title)) then
                entries.Push(e)
            end if
        end if
    end for
    m.edEntries = entries
    m.edSlots = []
    lazy = []
    for i = 0 to entries.Count() - 1
        e = entries[i]
        items = []
        if e.list <> invalid and e.list.items <> invalid then items = e.list.items
        m.edSlots.Push(SlotRows(e, items))
        if items.Count() = 0 and e.list <> invalid and e.list.paging <> invalid and e.list.paging.next <> invalid then lazy.Push(i)
    end for
    m.lazyQueue = lazy
    m.lazyBusy = 0
    PumpLazy()
    if m.edSlots.Count() = 0 then ShowMessage("Siden er tom.")
    Rebuild()
end sub

' fetch lazy lists three at a time
sub PumpLazy()
    while m.lazyQueue.Count() > 0 and m.lazyBusy < 3
        i = m.lazyQueue.Shift()
        req = ListRequest(m.edEntries[i].list.paging.next)
        req.tag = i
        m.lazyBusy = m.lazyBusy + 1
        CallApi(req, "onLazy")
    end while
end sub

sub onLazy(event as Object)
    r = event.getData()
    m.lazyBusy = m.lazyBusy - 1
    if r <> invalid and r.ok and r.json <> invalid and r.json.items <> invalid and r.tag <> invalid then
        i = r.tag
        m.edSlots[i] = SlotRows(m.edEntries[i], r.json.items)
        Rebuild()
    end if
    PumpLazy()
end sub

' ---------------------------------------------------------------- SERIER menu
sub StartSeries()
    m.seriesChip = m.top.chip
    if m.seriesChip = "" then m.seriesChip = "all"
    ShowChips()
    if m.seriesChip = "mine" then
        if m.top.loggedIn then
            SetBusy(true)
            t = CreateObject("roSGNode", "MineTask")
            t.observeField("response", "onMine")
            t.control = "RUN"
            m.mineTask = t
        else
            ShowMessage("Log ind for at se dine serier.")
        end if
    else if m.seriesChip = "az" then
        m.mineSpecs = []
        StartPage("/kategorier/a-aa", "az")
    else
        m.mineSpecs = []
        StartPage("/kategorier/fiktionsserier", "se")
    end if
end sub

sub ShowChips()
    chips = []
    for each c in [{ id: "mine", t: "Mine serier" }, { id: "all", t: "Alle" }, { id: "az", t: "A–Å" }]
        sel = ""
        if c.id = m.seriesChip then sel = "sel"
        chips.Push({ title: c.t, chip: sel, data: { go: { id: "series", chip: c.id, stay: true } } })
    end for
    m.chipSpec = RowSpec("chips", "Serier", "pill", chips, 300)
    m.headSpecs = [m.chipSpec]
    Rebuild()
end sub

sub BuildSeriesView()
    r = m.mine
    ShowChips()
    specs = []
    if r <> invalid and r.entries <> invalid then
        sorted = []
        for each e in r.entries
            sorted.Push({ title: Txt(e.show.title), e: e })
        end for
        sorted = SortAA(sorted, "title", false)
        row = []
        n = 0
        for each x in sorted
            e = x.e
            row.Push(PosterSpec(e.show, 225, { chip: StatusText(e.st), chipColor: StatusColor(e.st), progress: e.prog, data: SeriesData(e) }))
            if row.Count() = 8 then
                t = ""
                if n = 0 then t = "Dine serier · " + sorted.Count().ToStr()
                specs.Push(RowSpec("mine" + n.ToStr(), t, "poster", row, 225))
                row = []
                n = n + 1
            end if
        end for
        if row.Count() > 0 then
            t = ""
            if n = 0 then t = "Dine serier · " + sorted.Count().ToStr()
            specs.Push(RowSpec("mine" + n.ToStr(), t, "poster", row, 225))
        end if
        if sorted.Count() = 0 then ShowMessage("Du har ingen serier endnu. Åbn en serie og vælg Følg serie, eller se et afsnit.")
    end if
    m.mineSpecs = specs
    m.edSlots = []
    Rebuild()
end sub

' poster rows for catalogue pages inside the SERIER menu (genre rows, A-Å letters)
function PosterRowsFromEntry(entry as Object, items as Object, prefix as String) as Object
    rows = []
    if items.Count() = 0 then return rows
    out = []
    for each it in items
        out.Push(PosterSpec(it, 225, invalid))
    end for
    rows.Push(RowSpec(prefix + Txt(entry.id), Txt(entry.title), "poster", out, 225))
    return rows
end function

function IsLetterTitle(t as String) as Boolean
    if t = "0-9" then return true
    return t.Len() = 1 and UCase(t) <> LCase(t)
end function

' rows for one DR page entry: poster rows inside the SERIER menu, tiles elsewhere
function SlotRows(e as Object, items as Object) as Object
    if m.top.mode = "series" then return PosterRowsFromEntry(e, items, m.pagePrefix)
    return RowsFromEntry(e, items, m.pagePrefix)
end function
