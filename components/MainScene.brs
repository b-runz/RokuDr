' Screen stack, top-level tabs, and routing of events coming from the screens.
sub init()
    m.screens = m.top.findNode("screens")
    m.toast = m.top.findNode("toast")
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "onToastDone")
    m.stack = []
    m.activeTab = "home"
    m.loggedIn = RegRead("proT") <> ""
    m.top.setFocus(true)
    if m.loggedIn then
        OpenTab("home")
    else
        OpenTab("home")
        PushLogin()
    end if
end sub

' ---------------------------------------------------------------- tabs
function Tabs() as Object
    auth = "Log ind"
    if m.loggedIn then auth = "Log ud"
    return [
        { id: "home", label: "Forside" }
        { id: "series", label: "Serier" }
        { id: "udforsk", label: "Udforsk" }
        { id: "kategorier", label: "Kategorier" }
        { id: "boern", label: "Børn" }
        { id: "ultra", label: "Ultra" }
        { id: "live", label: "Live" }
        { id: "search", label: "Søg", right: true }
        { id: "auth", label: auth, right: true }
    ]
end function

sub OpenTab(id as String, chip = "all" as String)
    if id = "auth" then
        if m.loggedIn then
            Logout()
        else
            PushLogin()
        end if
        return
    end if
    m.activeTab = id
    scr = invalid
    if id = "home" then
        scr = NewBrowse("home", "", "all")
    else if id = "series" then
        scr = NewBrowse("series", "", chip)
    else if id = "udforsk" then
        scr = NewBrowse("page", "/", "all")
    else if id = "kategorier" then
        scr = NewBrowse("page", "/kategorier", "all")
    else if id = "boern" then
        scr = NewBrowse("page", "/boern", "all")
    else if id = "ultra" then
        scr = NewBrowse("page", "/ultra", "all")
    else if id = "live" then
        scr = CreateObject("roSGNode", "LiveScreen")
        Wire(scr, true)
        scr.callFunc("Start")
    else if id = "search" then
        scr = CreateObject("roSGNode", "SearchScreen")
        Wire(scr, true)
    end if
    if scr = invalid then return
    ReplaceRoot(scr)
end sub

function NewBrowse(mode as String, path as String, chip as String) as Object
    s = CreateObject("roSGNode", "BrowseScreen")
    s.mode = mode
    s.path = path
    s.chip = chip
    Wire(s, true)
    s.callFunc("Start")
    return s
end function

' common wiring: events, nav tabs, login state
sub Wire(s as Object, withTabs as Boolean)
    s.observeField("action", "onAction")
    if withTabs then
        s.tabs = Tabs()
        s.activeTab = m.activeTab
        s.loggedIn = m.loggedIn
    end if
end sub

' ---------------------------------------------------------------- stack
sub ReplaceRoot(scr as Object)
    for each s in m.stack
        DisposeScreen(s)
    end for
    m.stack = []
    Push(scr)
end sub

sub Push(scr as Object)
    if m.stack.Count() > 0 then m.stack[m.stack.Count() - 1].visible = false
    m.screens.appendChild(scr)
    m.stack.Push(scr)
    scr.visible = true
    scr.callFunc("Activate")
end sub

sub DisposeScreen(s as Object)
    if s.hasField("action") then s.unobserveField("action")
    if s.isSubtype("PlayerScreen") or s.isSubtype("LoginScreen") then s.callFunc("StopScreen")
    m.screens.removeChild(s)
end sub

sub Pop()
    if m.stack.Count() <= 1 then return
    s = m.stack.Pop()
    DisposeScreen(s)
    top = m.stack[m.stack.Count() - 1]
    top.visible = true
    top.callFunc("Activate")
    ' positions changed after watching: refresh the screen we return to
    if s.isSubtype("PlayerScreen") then
        if top.isSubtype("BrowseScreen") or top.isSubtype("DetailScreen") then top.callFunc("Refresh")
    end if
end sub

sub PushLogin()
    l = CreateObject("roSGNode", "LoginScreen")
    Wire(l, false)
    l.callFunc("Start")
    Push(l)
end sub

sub Logout()
    RegDelete("accT") : RegDelete("accE") : RegDelete("proT") : RegDelete("proE") : RegDelete("pend")
    m.loggedIn = false
    Toast("Logget ud")
    OpenTab("home")
end sub

' ---------------------------------------------------------------- events
sub onAction(event as Object)
    a = event.getData()
    if a = invalid then return
    t = a.type
    if t = "nav" then
        OpenTab(a.id)
    else if t = "go" then
        Go(a.go)
    else if t = "open" then
        OpenItem(a.data)
    else if t = "play" then
        PlayItem(a.item, a.parent)
    else if t = "next" then
        ' replace the finished player with the next episode
        Pop()
        PlayItem(a.item, a.parent)
    else if t = "zap" then
        Zap(a.dir)
    else if t = "loggedIn" then
        m.loggedIn = true
        Pop()
        Toast("Logget ind")
        OpenTab("home")
    end if
end sub

sub Go(g as Object)
    if g.id = "series" then
        OpenTab("series", Txt(g.chip))
    else if g.id = "live" then
        PlayLive(g.channel, g.channels)
    end if
end sub

sub OpenItem(d as Object)
    if d.type = "channel" then
        PlayLive({ id: Txt(d.id), title: Txt(d.title) }, [])
        return
    end if
    p = d.path
    isPageLink = false
    if d.type = "link" then isPageLink = true
    if IsStr(p) and p <> "" and d.type <> "show" and d.type <> "episode" and d.type <> "season" and d.type <> "movie" then
        if Left(p, 7) <> "/serie/" and Left(p, 9) <> "/episode/" and Left(p, 6) <> "/film/" and Left(p, 9) <> "/program/" then isPageLink = true
    end if
    if isPageLink and IsStr(p) then
        s = NewBrowse("page", p, "all")
        Push(s)
        return
    end if
    s = CreateObject("roSGNode", "DetailScreen")
    s.item = d
    s.loggedIn = m.loggedIn
    Wire(s, false)
    Push(s)
    s.callFunc("Start")
end sub

sub PlayItem(item as Object, parent as Dynamic)
    if not m.loggedIn then
        Toast("Log ind for at afspille")
        return
    end if
    p = CreateObject("roSGNode", "PlayerScreen")
    p.item = item
    if parent <> invalid then p.parent = parent
    Wire(p, false)
    Push(p)
    p.callFunc("Start")
end sub

sub PlayLive(ch as Object, channels as Object)
    if not m.loggedIn then
        Toast("Log ind for at se live tv")
        return
    end if
    m.liveList = channels
    p = CreateObject("roSGNode", "PlayerScreen")
    p.live = true
    p.item = { channelId: Txt(ch.id), title: Txt(ch.title), now: Txt(ch.now) }
    p.channels = channels
    Wire(p, false)
    Push(p)
    p.callFunc("Start")
end sub

sub Zap(d as Integer)
    list = m.liveList
    if list = invalid or list.Count() < 2 then return
    cur = m.stack[m.stack.Count() - 1]
    id = Txt(cur.item.channelId)
    idx = 0
    for i = 0 to list.Count() - 1
        if Txt(list[i].id) = id then idx = i
    end for
    idx = (idx + d + list.Count()) mod list.Count()
    ch = list[idx]
    Pop()
    PlayLive(ch, list)
end sub

sub Toast(text as String)
    m.toast.text = text
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub onToastDone()
    m.toast.visible = false
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        if m.stack.Count() > 1 then
            Pop()
            return true
        end if
        if m.activeTab <> "home" then
            OpenTab("home")
            return true
        end if
        return false
    end if
    return false
end function
