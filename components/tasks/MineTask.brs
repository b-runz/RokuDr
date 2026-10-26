' Port of web/js/mine.js: one pass over DR's profile endpoints, all calls issued in parallel waves.
sub init()
    m.top.functionName = "doMine"
end sub

function JsonItems(r as Object) as Object
    if r.ok and r.json <> invalid and r.json.items <> invalid then return r.json.items
    return []
end function

function AvailSecs(ep as Object) as Integer
    if ep = invalid then return 0
    cf = ep.customFields
    if cf = invalid then return 0
    return IsoSeconds(cf.AvailableFrom)
end function

function ItemReq(id as String, expand as String) as Object
    p = {}
    if expand = "detail" then p.item_detail_expand = "all" else p.expand = "all"
    return { path: "/items/" + id, params: p, token: "acc" }
end function

sub doMine()
    out = { ok: false, entries: [], bookmarks: [], explore: [], why: "" }
    tokens = CurrentTokens()
    if tokens["pro"] = "" then
        out.loggedOut = true
        m.top.response = out
        return
    end if
    out.loggedOut = false

    ' ---- wave 1: what DR knows about me
    w1 = RunBatch([
        { path: "/account/profile/continue-watching/list", params: { page: "1", page_size: "30" }, token: "pro" },
        { path: "/account/profile/follows/list", params: { page: "1", page_size: "50" }, token: "pro" },
        { path: "/account/profile/watched", token: "pro" },
        { path: "/account/profile/bookmarks/list", params: { page: "1", page_size: "100" }, token: "pro" }
    ], 4)
    cw = JsonItems(w1[0])
    fol = JsonItems(w1[1])
    watched = {}
    if w1[2].ok and w1[2].json <> invalid then watched = w1[2].json
    out.bookmarks = JsonItems(w1[3])

    followedIds = {}
    for each f in fol
        followedIds[Txt(f.id)] = true
    end for

    ' continue-watching mixes partly watched episodes (position > 30 s) with queued "up next" episodes (position 0)
    seen = {}
    cont = []
    queued = []
    for each ep in cw
        key = Txt(ep.showId)
        if key = "" then key = Txt(ep.id)
        if not seen.DoesExist(key) then
            seen[key] = true
            secs = 0
            w = watched[Txt(ep.id)]
            if w <> invalid and w.position <> invalid then secs = Num(w.position)
            ep._pos = secs
            prog = 0
            if Num(ep.duration) > 0 then prog = secs / Num(ep.duration)
            if prog > 1 then prog = 1
            ep._progress = prog
            if secs > 30 then cont.Push(ep) else queued.Push(ep)
        end if
    end for
    contIds = {}
    contShows = {}
    for each ep in cont
        contIds[Txt(ep.id)] = true
        contShows[Txt(ep.showId)] = true
    end for
    queuedShows = {}
    for each ep in queued
        queuedShows[Txt(ep.showId)] = true
    end for

    ' ---- wave 2: shows of the 20 most recently watched items
    recent = []
    for each id in watched
        w = watched[id]
        recent.Push({ id: id, last: Txt(w.lastWatchedDate) })
    end for
    recent = SortAA(recent, "last", true)
    recentReqs = []
    for i = 0 to recent.Count() - 1
        if i >= 20 then exit for
        recentReqs.Push(ItemReq(recent[i].id, "detail"))
    end for
    recentShowIds = []
    if recentReqs.Count() > 0 then
        w2 = RunBatch(recentReqs, 8)
        for each r in w2
            if r.ok and r.json <> invalid and r.json.showId <> invalid then recentShowIds.Push(Txt(r.json.showId))
        end for
    end if

    ' ---- wave 3: the show items themselves
    ids = []
    idSet = {}
    sources = []
    for each k in followedIds
        sources.Push(k)
    end for
    for each ep in cont
        sources.Push(Txt(ep.showId))
    end for
    for each ep in queued
        sources.Push(Txt(ep.showId))
    end for
    for each s in recentShowIds
        sources.Push(s)
    end for
    for each s in sources
        if s <> "" and not idSet.DoesExist(s) and ids.Count() < 24 then
            idSet[s] = true
            ids.Push(s)
        end if
    end for
    showReqs = []
    for each id in ids
        showReqs.Push(ItemReq(id, "detail"))
    end for
    shows = []
    if showReqs.Count() > 0 then
        w3 = RunBatch(showReqs, 8)
        for each r in w3
            if r.ok and r.json <> invalid and r.json.type = "show" then shows.Push(r.json)
        end for
    end if
    showById = {}
    for each s in shows
        showById[Txt(s.id)] = s
    end for

    ' ---- wave 4: next-episode suggestion + seasons for the first 16 shows
    top = []
    for i = 0 to shows.Count() - 1
        if i < 16 then top.Push(shows[i])
    end for
    w4reqs = []
    for each s in top
        w4reqs.Push({ path: "/account/profile/items/" + Txt(s.id) + "/next", params: { expand: "parent" }, token: "pro" })
        w4reqs.Push(ItemReq(Txt(s.id), "expand"))
    end for
    w4 = []
    if w4reqs.Count() > 0 then w4 = RunBatch(w4reqs, 8)

    latestSeason = []
    w5reqs = []
    for i = 0 to top.Count() - 1
        detail = w4[i * 2 + 1]
        lat = invalid
        if detail.ok and detail.json <> invalid and detail.json.seasons <> invalid and detail.json.seasons.items <> invalid then
            for each se in detail.json.seasons.items
                if lat = invalid or Num(se.seasonNumber) > Num(lat.seasonNumber) then lat = se
            end for
        end if
        latestSeason.Push(lat)
        if lat <> invalid then w5reqs.Push(ItemReq(Txt(lat.id), "expand"))
    end for
    w5 = []
    if w5reqs.Count() > 0 then w5 = RunBatch(w5reqs, 8)

    ' ---- classify
    newEps = []
    upNext = []
    now = TimeNow()
    k5 = 0
    for i = 0 to top.Count() - 1
        sh = top[i]
        nxt = w4[i * 2]
        nx = invalid
        sug = ""
        if nxt.ok and nxt.json <> invalid then
            nx = nxt.json.next
            sug = Txt(nxt.json.suggestionType)
        end if
        newest = invalid
        lat = latestSeason[i]
        if lat <> invalid then
            season = w5[k5]
            k5 = k5 + 1
            if season.ok and season.json <> invalid and season.json.episodes <> invalid and season.json.episodes.items <> invalid then
                for each e in season.json.episodes.items
                    if newest = invalid or AvailSecs(e) > AvailSecs(newest) then newest = e
                end for
                if newest <> invalid then
                    newest.showId = Txt(sh.id)
                    newest.seasonNumber = lat.seasonNumber
                end if
            end if
        end if
        isNew = false
        if newest <> invalid then
            wn = watched[Txt(newest.id)]
            done = false
            if wn <> invalid and wn.isFullyWatched = true then done = true
            if (now - AvailSecs(newest)) < 45 * 86400 and not done and not contIds.DoesExist(Txt(newest.id)) then isNew = true
        end if
        if isNew then
            newEps.Push({ ep: newest, show: sh, when: AvailSecs(newest) })
        else if sug = "Sequential" and nx <> invalid and not contShows.DoesExist(Txt(sh.id)) and not queuedShows.DoesExist(Txt(sh.id)) then
            nx.showId = Txt(sh.id)
            upNext.Push({ ep: nx, show: sh, when: AvailSecs(nx) })
        end if
    end for
    for each ep in queued
        sh = showById[Txt(ep.showId)]
        if sh <> invalid and not contShows.DoesExist(Txt(sh.id)) then upNext.Push({ ep: ep, show: sh, when: AvailSecs(ep) })
    end for

    ' ---- one entry per series: FORTSÆT > NYT AFSNIT > NÆSTE AFSNIT > nothing pending
    entries = []
    byShow = {}
    for each ep in cont
        sh = showById[Txt(ep.showId)]
        if sh = invalid then sh = ep
        sid = Txt(sh.id)
        if not byShow.DoesExist(sid) then
            byShow[sid] = true
            left = Int((Num(ep.duration) - ep._pos) / 60)
            if left < 1 then left = 1
            entries.Push({ show: sh, st: "C", ep: ep, prog: ep._progress, line: "Afsnit " + Txt(ep.episodeNumber) + " · " + left.ToStr() + " min tilbage" })
        end if
    end for
    for each x in newEps
        sid = Txt(x.show.id)
        if not byShow.DoesExist(sid) then
            byShow[sid] = true
            entries.Push({ show: x.show, st: "N", ep: x.ep, prog: 0, line: "Afsnit " + Txt(x.ep.episodeNumber) + " · " + EpisodeName(x.ep) + " · " + DayMonth(x.when) })
        end if
    end for
    for each x in upNext
        sid = Txt(x.show.id)
        if not byShow.DoesExist(sid) then
            byShow[sid] = true
            entries.Push({ show: x.show, st: "X", ep: x.ep, prog: 0, line: "Afsnit " + Txt(x.ep.episodeNumber) + " · " + EpisodeName(x.ep) })
        end if
    end for
    for each sh in shows
        sid = Txt(sh.id)
        if not byShow.DoesExist(sid) then
            byShow[sid] = true
            line = ""
            n = Int(Num(sh.availableSeasonCount))
            if n > 1 then
                line = n.ToStr() + " sæsoner"
            else if n = 1 then
                line = "1 sæson"
            end if
            entries.Push({ show: sh, st: "", ep: invalid, prog: 0, line: line })
        end if
    end for
    out.entries = entries

    ' ---- Udforsk suggestions: DR's "related" for the series I last watched + DR's series rows, max 10 I don't have
    seed = invalid
    for each e in entries
        if seed = invalid and e.st = "C" then seed = e
    end for
    if seed = invalid then
        for each e in entries
            if seed = invalid and e.ep <> invalid then seed = e
        end for
    end if
    if seed = invalid and entries.Count() > 0 then seed = entries[0]
    reqs = [{ path: "/page", params: { path: "/kategorier/fiktionsserier", item_detail_expand: "all", list_page_size: "24", max_list_prefetch: "14" }, token: "acc" }]
    if seed <> invalid then reqs.Push({ path: "/items/" + Txt(seed.show.id) + "/related", token: "pro" })
    w6 = RunBatch(reqs, 2)
    cands = []
    if seed <> invalid and w6.Count() > 1 then
        for each it in JsonItems(w6[1])
            cands.Push(it)
        end for
        out.why = "fordi du så " + Txt(seed.show.title)
    end if
    if w6[0].ok and w6[0].json <> invalid and w6[0].json.entries <> invalid then
        for each e in w6[0].json.entries
            if e.template = "P1" and e.list <> invalid and e.list.items <> invalid then
                for each it in e.list.items
                    cands.Push(it)
                end for
            end if
        end for
        if out.why = "" then out.why = "populære serier"
    end if
    explore = []
    seenX = {}
    for each it in cands
        iid = Txt(it.id)
        if it.type = "show" and not byShow.DoesExist(iid) and not seenX.DoesExist(iid) and explore.Count() < 10 then
            seenX[iid] = true
            explore.Push(it)
        end if
    end for
    out.explore = explore
    out.ok = true
    m.top.response = out
end sub
