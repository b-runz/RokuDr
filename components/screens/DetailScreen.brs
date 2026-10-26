' Port of web/js/detail.js
sub init()
    m.page = m.top.findNode("page")
    m.banner = m.top.findNode("banner")
    m.title = m.top.findNode("title")
    m.actions = m.top.findNode("actions")
    m.subline = m.top.findNode("subline")
    m.meta = m.top.findNode("meta")
    m.desc = m.top.findNode("desc")
    m.rows = m.top.findNode("rows")
    m.busy = m.top.findNode("busy")
    m.tasks = []
    m.actions.observeField("selected", "onAction")
    m.rows.observeField("rowItemSelected", "onRowSelected")
end sub

sub Activate()
    m.actions.setFocus(true)
    m.page.translation = [0, 0]
end sub

sub Refresh()
    if m.top.item <> invalid then Start()
end sub

function CallApi(req as Object, callback as String) as Object
    t = CreateObject("roSGNode", "ApiTask")
    t.request = req
    t.observeField("response", callback)
    t.control = "RUN"
    m.tasks.Push(t)
    if m.tasks.Count() > 30 then m.tasks.Shift()
    return t
end function

' ---------------------------------------------------------------- load
sub Start()
    item = m.top.item
    m.gen = Rnd(1000000)
    m.info = item
    m.isShow = (item.type = "show" or item.type = "season" or (IsStr(item.path) and Left(item.path, 7) = "/serie/"))
    m.showId = Txt(item.id)
    if item.type = "season" then m.showId = Txt(item.showId)
    if not m.isShow and item.showId <> invalid then m.showId = Txt(item.showId)
    m.seasons = []
    m.seasonEps = {}
    m.watched = {}
    m.nextInfo = invalid
    m.related = []
    m.target = invalid
    m.followed = false
    m.bookmarked = false
    m.title.text = Txt(item.title)
    m.desc.text = Txt(item.description)
    if m.desc.text = "" then m.desc.text = Txt(item.shortDescription)
    m.meta.text = ""
    m.subline.text = ""
    m.banner.uri = Sized(PickImage(item.images, ["wallpaper", "tile"]), 1920, 1080)
    m.rows.content = invalid
    RefreshButtons()
    if m.busy <> invalid then
        m.busy.visible = true
        m.busy.control = "start"
    end if

    reqs = [{ path: "/account/profile/watched", token: "pro" }]
    if m.isShow then
        reqs.Push({ path: "/items/" + m.showId, params: { expand: "all" }, token: "acc" })
        reqs.Push({ path: "/account/profile/items/" + m.showId + "/next", params: { expand: "parent" }, token: "pro" })
        reqs.Push({ path: "/account/profile/follows/list", params: { page: "1", page_size: "50" }, token: "pro" })
    else
        reqs.Push({ path: "/items/" + Txt(item.id), params: { item_detail_expand: "all" }, token: "acc" })
    end if
    reqs.Push({ path: "/account/profile/bookmarks/list", params: { page: "1", page_size: "100" }, token: "pro" })
    CallApi({ batch: reqs, parallel: 5, tag: "A" }, "onBatchA")
end sub

function Resp(r as Object, i as Integer) as Object
    if r.batch <> invalid and i < r.batch.Count() then
        x = r.batch[i]
        if x.ok then return x.json
    end if
    return invalid
end function

sub onBatchA(event as Object)
    r = event.getData()
    if r = invalid then return
    w = Resp(r, 0)
    if w <> invalid then m.watched = w
    if m.isShow then
        show = Resp(r, 1)
        nx = Resp(r, 2)
        fol = Resp(r, 3)
        bm = Resp(r, 4)
        if show <> invalid then
            m.info = show
            for each k in m.top.item
                if m.info[k] = invalid then m.info[k] = m.top.item[k]
            end for
            m.info.title = Txt(m.top.item.title)
            if m.info.title = "" then m.info.title = Txt(show.title)
            if show.seasons <> invalid and show.seasons.items <> invalid then
                for each s in show.seasons.items
                    m.seasons.Push({ k: -Num(s.seasonNumber), s: s })
                end for
                m.seasons = SortAA(m.seasons, "k", false)
                sorted = []
                for each x in m.seasons
                    sorted.Push(x.s)
                end for
                m.seasons = sorted
            end if
        end if
        m.nextInfo = nx
        if fol <> invalid and fol.items <> invalid then
            for each f in fol.items
                if Txt(f.id) = m.showId then m.followed = true
            end for
        end if
        MarkBookmark(bm)
        m.desc.text = Txt(m.info.description)
        if m.desc.text = "" then m.desc.text = Txt(m.info.shortDescription)
        n = Int(Num(m.info.availableSeasonCount))
        meta = Txt(m.info.releaseYear)
        if n > 0 then
            if meta <> "" then meta = meta + "  ·  "
            if n = 1 then meta = meta + "1 sæson" else meta = meta + n.ToStr() + " sæsoner"
        end if
        m.meta.text = meta
        ' the season you are up to goes first
        want = ""
        if m.nextInfo <> invalid and m.nextInfo.next <> invalid then want = Txt(m.nextInfo.next.seasonId)
        found = false
        for each s in m.seasons
            if Txt(s.id) = want then found = true
        end for
        if not found and m.seasons.Count() > 0 then want = Txt(m.seasons[0].id)
        m.wantSeason = want
        if want <> "" then
            CallApi({ path: "/items/" + want, params: { expand: "all" }, token: "acc", tag: "B" }, "onSeasonB")
        else
            FinishLoad()
        end if
    else
        d = Resp(r, 1)
        bm = Resp(r, 2)
        if d <> invalid then
            for each k in m.top.item
                if d[k] = invalid then d[k] = m.top.item[k]
            end for
            m.info = d
        end if
        MarkBookmark(bm)
        m.desc.text = Txt(m.info.description)
        if m.desc.text = "" then m.desc.text = Txt(m.info.shortDescription)
        cf = m.info.customFields
        if cf <> invalid then
            m.meta.text = Txt(cf.ContextualTitleExtraDetails)
            if m.meta.text = "" then m.meta.text = Txt(cf.ExtraDetails)
        end if
        if m.info.seasonId <> invalid then
            CallApi({ path: "/items/" + Txt(m.info.seasonId), params: { expand: "all" }, token: "acc", tag: "B" }, "onSeasonB")
        else
            FinishLoad()
        end if
    end if
end sub

sub MarkBookmark(bm as Dynamic)
    m.bookmarked = false
    if bm <> invalid and bm.items <> invalid then
        for each b in bm.items
            if Txt(b.id) = m.showId then m.bookmarked = true
        end for
    end if
end sub

function SeasonEpisodes(json as Object) as Object
    eps = []
    if json <> invalid and json.episodes <> invalid and json.episodes.items <> invalid then
        for each e in json.episodes.items
            e.seasonNumber = json.seasonNumber
            eps.Push({ k: Num(e.episodeNumber), e: e })
        end for
    end if
    eps = SortAA(eps, "k", false)
    out = []
    for each x in eps
        out.Push(x.e)
    end for
    return out
end function

sub onSeasonB(event as Object)
    r = event.getData()
    if r <> invalid and r.ok and r.json <> invalid then
        id = Txt(r.json.id)
        eps = SeasonEpisodes(r.json)
        m.seasonEps[id] = eps
        if not m.isShow then
            keep = []
            for each e in eps
                if Txt(e.id) <> Txt(m.info.id) then keep.Push(e)
            end for
            m.seasonEps[id] = keep
        end if
    end if
    FinishLoad()
    ' remaining seasons + related in the background
    if m.isShow then
        reqs = []
        for each s in m.seasons
            if m.seasonEps[Txt(s.id)] = invalid then reqs.Push({ path: "/items/" + Txt(s.id), params: { expand: "all" }, token: "acc" })
        end for
        reqs.Push({ path: "/items/" + m.showId + "/related", token: "pro" })
        CallApi({ batch: reqs, parallel: 6, tag: "C" }, "onBatchC")
    else
        CallApi({ path: "/items/" + Txt(m.info.id) + "/related", token: "pro", tag: "R" }, "onRelated")
    end if
end sub

sub onBatchC(event as Object)
    r = event.getData()
    if r = invalid or r.batch = invalid then return
    for i = 0 to r.batch.Count() - 1
        x = r.batch[i]
        if x.ok and x.json <> invalid then
            if x.json.type = "season" then
                m.seasonEps[Txt(x.json.id)] = SeasonEpisodes(x.json)
            else if x.json.items <> invalid then
                m.related = x.json.items
            end if
        end if
    end for
    BuildRows()
end sub

sub onRelated(event as Object)
    r = event.getData()
    if r <> invalid and r.ok and r.json <> invalid and r.json.items <> invalid then m.related = r.json.items
    BuildRows()
end sub

sub FinishLoad()
    if m.busy <> invalid then
        m.busy.visible = false
        m.busy.control = "stop"
    end if
    ComputePlay()
    RefreshButtons()
    BuildRows()
end sub

' ---------------------------------------------------------------- the big button
sub ComputePlay()
    label = "AFSPIL NU"
    line = ""
    m.target = invalid
    if m.isShow then
        sug = ""
        nx = invalid
        if m.nextInfo <> invalid then
            sug = Txt(m.nextInfo.suggestionType)
            nx = m.nextInfo.next
        end if
        t = nx
        if t = invalid then
            for each s in m.seasons
                eps = m.seasonEps[Txt(s.id)]
                if t = invalid and eps <> invalid and eps.Count() > 0 then t = eps[0]
            end for
        end if
        if t <> invalid then
            full = FindEpisode(Txt(t.id))
            if full <> invalid then
                for each k in t
                    if full[k] = invalid then full[k] = t[k]
                end for
                t = full
            end if
            w = m.watched[Txt(t.id)]
            if sug = "ContinueWatching" then
                label = "FORTSÆT"
                if w <> invalid and Num(w.position) > 0 then
                    t.resumeAt = Num(w.position)
                    line = EpCode(t) + " · " + Mins(Num(t.duration) - Num(w.position)).ToStr() + " min tilbage"
                else
                    line = EpCode(t)
                end if
            else if sug = "Sequential" then
                label = "NÆSTE AFSNIT"
                line = EpCode(t) + "  " + EpisodeName(t)
            else if sug = "RestartWatching" then
                label = "SE FRA START"
                line = EpCode(t)
            end if
        end if
        m.target = t
    else
        t = m.info
        w = m.watched[Txt(t.id)]
        if w <> invalid and Num(w.position) > 30 and w.isFullyWatched <> true then
            label = "FORTSÆT"
            t.resumeAt = Num(w.position)
            line = Mins(Num(t.duration) - Num(w.position)).ToStr() + " min tilbage"
        end if
        m.target = t
    end if
    m.playLabel = label
    m.subline.text = line
end sub

function FindEpisode(id as String) as Dynamic
    for each sid in m.seasonEps
        for each e in m.seasonEps[sid]
            if Txt(e.id) = id then return e
        end for
    end for
    return invalid
end function

function Mins(secs as Float) as Integer
    n = Int(secs / 60)
    if n < 1 then n = 1
    return n
end function

function EpCode(ep as Object) as String
    sn = Txt(ep.seasonNumber)
    if sn = "" then
        for each s in m.seasons
            if Txt(s.id) = Txt(ep.seasonId) then sn = Txt(s.seasonNumber)
        end for
    end if
    out = ""
    if sn <> "" then out = "Sæson " + sn + " · "
    return out + "Afsnit " + Txt(ep.episodeNumber)
end function

sub RefreshButtons()
    label = m.playLabel
    if label = invalid then label = "AFSPIL NU"
    subs = "Undertekster: Til"
    if RegRead("subs") = "0" then subs = "Undertekster: Fra"
    acc = AccessLabel(AccessMode())
    list = "Min liste"
    if m.bookmarked then list = "På min liste"
    labels = [label]
    kinds = ["play"]
    if m.isShow then
        if m.followed then labels.Push("✓ Følger") else labels.Push("＋ Følg serie")
        kinds.Push("follow")
    else if m.info.showId <> invalid then
        labels.Push("Til serien")
        kinds.Push("series")
    end if
    labels.Push(list) : kinds.Push("list")
    labels.Push(subs) : kinds.Push("subs")
    labels.Push("Tilgængelighed: " + acc) : kinds.Push("access")
    m.kinds = kinds
    m.actions.labels = labels
end sub

function AccessMode() as String
    a = RegRead("access")
    if a = "" then return "StandardVideo"
    return a
end function

function AccessLabel(a as String) as String
    if a = "AudioDescription" then return "Synstolkning"
    if a = "SpokenSubtitles" then return "Oplæste undertekster"
    return "Standard"
end function

' ---------------------------------------------------------------- rows
sub BuildRows()
    specs = []
    shown = []
    ' season you are up to first, then the rest newest-first
    if m.wantSeason <> invalid and m.wantSeason <> "" then
        for each s in m.seasons
            if Txt(s.id) = m.wantSeason then shown.Push(s)
        end for
    end if
    for each s in m.seasons
        if Txt(s.id) <> m.wantSeason then shown.Push(s)
    end for
    if not m.isShow then
        for each id in m.seasonEps
            shown.Push({ id: id, seasonNumber: "" })
        end for
    end if
    firstEpCol = 0
    for each s in shown
        eps = m.seasonEps[Txt(s.id)]
        if eps <> invalid and eps.Count() > 0 then
            items = []
            idx = 0
            for each e in eps
                w = m.watched[Txt(e.id)]
                prog = 0.0
                badge = ""
                if w <> invalid then
                    if w.isFullyWatched = true then
                        badge = "SET ✓"
                    else if Num(e.duration) > 0 then
                        prog = Num(w.position) / Num(e.duration)
                    end if
                end if
                art = Sized(PickImage(e.images, ["tile", "wallpaper"]), 768, 432)
                it = { title: Txt(e.episodeNumber) + ". " + EpisodeName(e), art: art, progress: prog, badge: badge, data: { epItem: e } }
                items.Push(it)
                if m.target <> invalid and Txt(e.id) = Txt(m.target.id) and specs.Count() = 0 then firstEpCol = idx
                idx = idx + 1
            end for
            if m.isShow and m.seasons.Count() > 1 then
                title = "Sæson " + Txt(s.seasonNumber) + " · " + eps.Count().ToStr() + " afsnit"
            else if m.isShow then
                title = "Afsnit (" + eps.Count().ToStr() + ")"
            else
                title = "Flere afsnit"
            end if
            specs.Push(RowSpec("s" + Txt(s.id), title, "tile", items, 384))
        end if
    end for
    if m.related.Count() > 0 then
        items = []
        n = 0
        for each it in m.related
            if n < 18 then items.Push(TileSpec(it, 384))
            n = n + 1
        end for
        specs.Push(RowSpec("rel", "Mere som dette", "tile", items, 384))
    end if
    ApplyRows(m.rows, specs, 400, -1, 0)
    m.rows.numRows = 1
    if specs.Count() > 0 and specs[0].key <> "rel" and firstEpCol > 0 then m.rows.jumpToRowItem = [0, firstEpCol]
    m.hasRows = specs.Count() > 0
end sub

sub onRowSelected()
    sel = m.rows.rowItemSelected
    if sel = invalid or sel.Count() < 2 then return
    row = m.rows.content.getChild(sel[0])
    if row = invalid then return
    item = row.getChild(sel[1])
    if item = invalid or item.data = invalid then return
    d = item.data
    if d.epItem <> invalid then
        ep = d.epItem
        w = m.watched[Txt(ep.id)]
        if w <> invalid and Num(w.position) > 30 and w.isFullyWatched <> true then ep.resumeAt = Num(w.position)
        m.top.action = { type: "play", item: ep, parent: m.info }
    else
        m.top.action = { type: "open", data: d }
    end if
end sub

' ---------------------------------------------------------------- buttons
sub onAction()
    k = m.kinds[m.actions.selected]
    if k = "play" then
        if m.target <> invalid then m.top.action = { type: "play", item: m.target, parent: m.info }
    else if k = "series" then
        d = { id: Txt(m.info.showId), type: "show", title: m.top.item.title, path: "/serie/x_" + Txt(m.info.showId), images: m.info.images }
        m.top.action = { type: "open", data: d }
    else if k = "follow" then
        m.followed = not m.followed
        method = "DELETE"
        if m.followed then method = "PUT"
        CallApi({ path: "/account/profile/follows/" + m.showId, method: method, token: "pro" }, "onIgnore")
        RefreshButtons()
    else if k = "list" then
        m.bookmarked = not m.bookmarked
        method = "DELETE"
        if m.bookmarked then method = "PUT"
        CallApi({ path: "/account/profile/bookmarks/" + m.showId, method: method, token: "pro" }, "onIgnore")
        RefreshButtons()
    else if k = "subs" then
        if RegRead("subs") = "0" then RegWrite("subs", "1") else RegWrite("subs", "0")
        RefreshButtons()
    else if k = "access" then
        a = AccessMode()
        if a = "StandardVideo" then
            a = "AudioDescription"
        else if a = "AudioDescription" then
            a = "SpokenSubtitles"
        else
            a = "StandardVideo"
        end if
        RegWrite("access", a)
        RefreshButtons()
    end if
end sub

sub onIgnore(event as Object)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "down" and m.actions.isInFocusChain() and m.hasRows = true then
        m.page.translation = [0, -560]
        m.rows.setFocus(true)
        return true
    else if key = "up" and m.rows.isInFocusChain() then
        m.page.translation = [0, 0]
        m.actions.setFocus(true)
        return true
    end if
    return false
end function
