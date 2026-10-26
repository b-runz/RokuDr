sub Start()
    if not m.top.loggedIn then
        ShowMessage("Log ind (øverst til højre) for at se live tv.")
        return
    end if
    SetBusy(true)
    CallApi({ path: "/lists/155156", params: { page_size: "24", page: "1" }, token: "acc" }, "onChannels")
end sub

sub onChannels(event as Object)
    r = event.getData()
    list = []
    if r <> invalid and r.ok and r.json <> invalid and r.json.items <> invalid then
        for each it in r.json.items
            if it.type = "channel" then list.Push(it)
        end for
    end if
    if list.Count() = 0 then
        list = [{ id: "20875", title: "DR1" }, { id: "20876", title: "DR2" }, { id: "192099", title: "TVA Live" }, { id: "20892", title: "DR Ramasjang" }]
    end if
    m.channels = list
    BuildRow({})
    ids = ""
    for i = 0 to list.Count() - 1
        if i > 0 then ids = ids + ","
        ids = ids + Txt(list[i].id)
    end for
    from = CreateObject("roDateTime")
    from.FromSeconds(TimeNow() - 7200)
    date = Left(from.ToISOString(), 10)
    CallApi({ path: "/schedules", params: { channels: ids, date: date, hour: from.GetHours().ToStr(), duration: "8" }, token: "pro" }, "onSchedule")
end sub

sub onSchedule(event as Object)
    r = event.getData()
    nn = {}
    now = TimeNow()
    if r <> invalid and r.ok and r.json <> invalid and Type(r.json) = "roArray" then
        for each c in r.json
            progs = []
            if c.schedules <> invalid then
                for each p in c.schedules
                    if p.item <> invalid and Type(p.item) = "roAssociativeArray" then progs.Push({ k: Txt(p.startDate), p: p })
                end for
            end if
            progs = SortAA(progs, "k", false)
            cur = invalid
            nxt = invalid
            for i = 0 to progs.Count() - 1
                p = progs[i].p
                a = IsoSeconds(p.startDate)
                b = IsoSeconds(p.endDate)
                if a <= now and now < b then
                    cur = p
                    if i + 1 < progs.Count() then nxt = progs[i + 1].p
                end if
            end for
            nn[Txt(c.channelId)] = { now: cur, next: nxt }
        end for
    end if
    BuildRow(nn)
end sub

sub BuildRow(nn as Object)
    SetBusy(false)
    items = []
    for each ch in m.channels
        s = nn[Txt(ch.id)]
        sub1 = ""
        l2 = ""
        prog = 0.0
        nowTitle = ""
        if s <> invalid and s.now <> invalid then
            nowTitle = Txt(s.now.item.title)
            sub1 = ClockOf(s.now.startDate) + "  " + nowTitle
            a = IsoSeconds(s.now.startDate)
            b = IsoSeconds(s.now.endDate)
            if b > a then prog = (TimeNow() - a) / (b - a)
        end if
        if s <> invalid and s.next <> invalid then l2 = "Næste " + ClockOf(s.next.startDate) + "  " + Txt(s.next.item.title)
        c = { id: Txt(ch.id), title: Txt(ch.title), now: nowTitle }
        items.Push({
            title: Txt(ch.title), sub: sub1, l2: l2, progress: prog,
            art: Sized(PickImage(ch.images, ["tile", "wallpaper", "square"]), 1140, 642),
            data: { go: { id: "live", channel: c, channels: m.channels } }
        })
    end for
    ShowSpecs([RowSpec("live", "Live tv", "live", items, 570)])
end sub
