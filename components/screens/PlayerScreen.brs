sub init()
    m.video = m.top.findNode("video")
    m.card = m.top.findNode("card")
    m.cardTitle = m.top.findNode("cardTitle")
    m.cardHint = m.top.findNode("cardHint")
    m.msg = m.top.findNode("msg")
    m.syncTimer = m.top.findNode("syncTimer")
    m.countTimer = m.top.findNode("countTimer")
    m.msgTimer = m.top.findNode("msgTimer")
    m.tasks = []
    m.hinted = false
    m.cardShown = false
    m.cardDismissed = false
    m.stopped = false
    m.endCredit = -1
    m.nextEp = invalid
    m.video.observeField("state", "onVideoState")
    m.video.observeField("availableSubtitleTracks", "onTracks")
    m.video.observeField("position", "onPosition")
    m.syncTimer.observeField("fire", "onSyncTick")
    m.countTimer.observeField("fire", "onCountTick")
    m.msgTimer.observeField("fire", "onMsgDone")
end sub

sub Activate()
    m.video.setFocus(true)
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

sub Say(text as String)
    m.msg.text = text
    m.msg.visible = true
    m.msgTimer.control = "stop"
    m.msgTimer.control = "start"
end sub

sub onMsgDone()
    m.msg.visible = false
end sub

' ---------------------------------------------------------------- start
sub Start()
    item = m.top.item
    if m.top.live then
        CallApi({ path: "/channels/" + Txt(item.channelId) + "/liveStreams", token: "pro" }, "onLive")
    else
        access = RegRead("access")
        if access = "" then access = "StandardVideo"
        m.access = access
        CallApi({ path: "/account/items/" + Txt(item.id) + "/videos", params: { delivery: "stream", resolution: "HD-1080", formats: "hls,dash" }, token: "acc" }, "onVideos")
    end if
    Say("Henter stream…")
end sub

sub onLive(event as Object)
    r = event.getData()
    if r = invalid or not r.ok or r.json = invalid then
        if r <> invalid and (r.status = 401 or r.status = 403) then Fail("Log ind for at se live tv") else Fail("Kunne ikke starte kanalen")
        return
    end if
    url = ""
    for each s in r.json
        if s.type = "hlsWithSubtitlesURL" and Txt(s.link) <> "" then url = s.link
    end for
    if url = "" then
        for each s in r.json
            if s.type = "hlsURL" and Txt(s.link) <> "" then url = s.link
        end for
    end if
    if url = "" then
        Fail("Kanalen kan ikke afspilles")
        return
    end if
    Play(url, 0)
end sub

sub onVideos(event as Object)
    r = event.getData()
    if r = invalid or not r.ok or r.json = invalid or Type(r.json) <> "roArray" then
        if r <> invalid and (r.status = 401 or r.status = 403) then
            Fail("Log ind for at afspille")
        else if r <> invalid and r.status = 404 then
            Fail("Ingen video tilgængelig")
        else
            Fail("Kunne ikke starte afspilning")
        end if
        return
    end if
    best = invalid
    fallback = invalid
    for each v in r.json
        if v.format = "video/hls" then
            if v.accessService = m.access then best = v
            if v.accessService = "StandardVideo" then fallback = v
        end if
    end for
    if best = invalid then best = fallback
    if best = invalid and r.json.Count() > 0 then best = r.json[0]
    if best = invalid then
        Fail("Ingen video tilgængelig")
        return
    end if
    if best.timeCodes <> invalid then
        for each tc in best.timeCodes
            if tc.timeCodeType = "EndCredit" then m.endCredit = Num(tc.startTime)
        end for
    end if
    Play(best.url, Num(m.top.item.resumeAt))
end sub

sub Fail(text as String)
    Say(text)
end sub

sub Play(url as String, startAt as Float)
    c = CreateObject("roSGNode", "ContentNode")
    c.url = url
    c.streamFormat = "hls"
    c.title = PlayTitle()
    if m.top.live then c.live = true
    if startAt > 10 then c.PlayStart = startAt
    m.video.content = c
    ' native captions, styled by us: sans, no background/window box, uniform outline
    m.video.captionStyle = {
        "Text/Font": "Sans Serif Proportional"
        "Text/Effect": "Uniform"
        "Text/Size": "Medium"
        "Text/Color": "White"
        "Text/Opacity": "100%"
        "Background/Opacity": "Off"
        "Window/Opacity": "Off"
    }
    if RegRead("subs") = "0" then m.video.globalCaptionMode = "Off" else m.video.globalCaptionMode = "On"
    m.video.control = "play"
    m.video.setFocus(true)
    if not m.top.live then m.syncTimer.control = "start"
end sub

function PlayTitle() as String
    item = m.top.item
    if m.top.live then
        t = Txt(item.title)
        if Txt(item.now) <> "" then t = t + " — " + Txt(item.now)
        return t
    end if
    p = m.top.parent
    if p <> invalid and Txt(p.title) <> "" and Txt(p.title) <> Txt(item.title) then return Txt(p.title) + " — " + EpisodeName(item)
    return Txt(item.title)
end function

' ---------------------------------------------------------------- captions: pick the track we prefer
sub onTracks()
    if m.top.live then return
    tracks = m.video.availableSubtitleTracks
    if tracks = invalid or tracks.Count() = 0 then return
    if RegRead("subs") = "0" then return
    pick = invalid
    for each t in tracks
        d = LCase(Txt(t.Description))
        if pick = invalid and Instr(1, d, "fremmed") > 0 then pick = t
    end for
    if pick = invalid then
        for each t in tracks
            if pick = invalid and Instr(1, LCase(Txt(t.Description)), "dansk") > 0 then pick = t
        end for
    end if
    if pick = invalid then pick = tracks[0]
    m.video.subtitleTrack = pick.TrackName
    m.video.globalCaptionMode = "On"
end sub

' ---------------------------------------------------------------- state / position
sub onVideoState()
    s = m.video.state
    if s = "playing" then
        m.msg.visible = false
        if not m.hinted and not m.top.live then
            m.hinted = true
            Say("Tryk * for undertekster og sprog")
        end if
    else if s = "finished" then
        FinishEpisode()
    else if s = "error" then
        Fail("Afspilningsfejl")
    end if
end sub

sub onPosition()
    if m.top.live or m.cardShown or m.cardDismissed then return
    if m.endCredit > 0 and m.video.position >= m.endCredit then ShowNextCard()
end sub

sub onSyncTick()
    SyncPosition(false)
end sub

sub SyncPosition(final as Boolean)
    if m.top.live or m.top.item.id = invalid then return
    p = Int(m.video.position)
    if p < 10 then return
    CallApi({ path: "/account/profile/watched/" + Txt(m.top.item.id), method: "PUT", params: { position: p.ToStr() }, token: "pro" }, "onIgnore")
end sub

sub onIgnore(event as Object)
end sub

sub StopScreen()
    if m.stopped then return
    m.stopped = true
    SyncPosition(true)
    m.syncTimer.control = "stop"
    m.countTimer.control = "stop"
    m.video.control = "stop"
end sub

' ---------------------------------------------------------------- next episode
sub FinishEpisode()
    if m.top.live then return
    if not m.cardShown and not m.cardDismissed then ShowNextCard() else if m.nextEp <> invalid and m.cardShown then StartNext()
end sub

sub ShowNextCard()
    m.cardShown = true
    d = Num(m.video.duration)
    if d > 0 then CallApi({ path: "/account/profile/watched/" + Txt(m.top.item.id), method: "PUT", params: { position: Int(d).ToStr() }, token: "pro" }, "onMarked")
end sub

sub onMarked(event as Object)
    showId = Txt(m.top.item.showId)
    if showId = "" and m.top.parent <> invalid then showId = Txt(m.top.parent.id)
    if showId = "" then return
    CallApi({ path: "/account/profile/items/" + showId + "/next", params: { expand: "parent" }, token: "pro" }, "onNext")
end sub

sub onNext(event as Object)
    r = event.getData()
    if r = invalid or not r.ok or r.json = invalid then return
    if Txt(r.json.suggestionType) <> "Sequential" or r.json.next = invalid then return
    if Txt(r.json.next.id) = Txt(m.top.item.id) then return
    m.nextEp = r.json.next
    m.countLeft = 10
    m.cardTitle.text = EpisodeName(m.nextEp)
    UpdateHint()
    m.card.visible = true
    m.top.setFocus(true)
    m.countTimer.control = "start"
end sub

sub UpdateHint()
    m.cardHint.text = "Starter om " + m.countLeft.ToStr() + " s  ·  OK: afspil nu  ·  Tilbage: bliv"
end sub

sub onCountTick()
    m.countLeft = m.countLeft - 1
    if m.countLeft <= 0 then
        StartNext()
    else
        UpdateHint()
    end if
end sub

sub StartNext()
    m.countTimer.control = "stop"
    if m.nextEp = invalid then return
    ep = m.nextEp
    if ep.showId = invalid then ep.showId = m.top.item.showId
    m.nextEp = invalid
    m.top.action = { type: "next", item: ep, parent: m.top.parent }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.card.visible then
        if key = "OK" then
            StartNext()
            return true
        else if key = "back" then
            m.countTimer.control = "stop"
            m.card.visible = false
            m.cardDismissed = true
            m.video.setFocus(true)
            return true
        end if
    end if
    if m.top.live and (key = "up" or key = "down" or key = "channelUp" or key = "channelDown") then
        d = 1
        if key = "up" or key = "channelUp" then d = -1
        m.top.action = { type: "zap", dir: d }
        return true
    end if
    return false
end function
