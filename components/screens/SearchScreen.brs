sub init()
    m.nav = m.top.findNode("nav")
    m.keys = m.top.findNode("keys")
    m.queryLbl = m.top.findNode("query")
    m.query = ""
    m.caret = 0
    BuildKeys()
    m.rows = m.top.findNode("rows")
    m.msg = m.top.findNode("msg")
    m.debounce = m.top.findNode("debounce")
    m.tasks = []
    m.seq = 0
    m.hasRows = false
    m.keys.observeField("itemSelected", "onKeySelected")
    m.debounce.observeField("fire", "onDebounce")
    m.rows.observeField("rowItemSelected", "onRowSelected")
    m.nav.observeField("selected", "onNavSelected")
    m.nav.observeField("downRequested", "onNavDown")
    m.top.observeField("tabs", "onTabs")
    m.top.observeField("activeTab", "onTabs")
end sub

sub onTabs()
    m.nav.tabs = m.top.tabs
    m.nav.active = m.top.activeTab
end sub

sub Start()
end sub

sub Activate()
    m.keys.setFocus(true)
end sub

function CallApi(req as Object, callback as String) as Object
    t = CreateObject("roSGNode", "ApiTask")
    t.request = req
    t.observeField("response", callback)
    t.control = "RUN"
    m.tasks.Push(t)
    if m.tasks.Count() > 20 then m.tasks.Shift()
    return t
end function

sub onNavSelected()
    m.top.action = { type: "nav", id: m.nav.selected }
end sub

sub onNavDown()
    m.keys.setFocus(true)
end sub

' QWERTY with Danish letters on the main page: digits + backspace, q-p + å, a-l + æ ø, z-m, cursor left, space, cursor right
sub BuildKeys()
    layout = ["1","2","3","4","5","6","7","8","9","0","⌫", "q","w","e","r","t","y","u","i","o","p","å", "a","s","d","f","g","h","j","k","l","æ","ø", "z","x","c","v","b","n","m","-","←","␣","→"]
    m.keyChars = layout
    root = CreateObject("roSGNode", "ContentNode")
    for each k in layout
        n = CreateObject("roSGNode", "ContentNode")
        n.title = k
        if k = "␣" then n.title = "mellemrum"
        root.appendChild(n)
    end for
    m.keys.content = root
end sub

sub SetQuery(q as String, caret as Integer)
    m.query = q
    if caret < 0 then caret = 0
    if caret > Len(q) then caret = Len(q)
    m.caret = caret
    m.queryLbl.text = Left(q, caret) + "|" + Mid(q, caret + 1)
    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

sub Typed(ch as String)
    q = m.query
    c = m.caret
    if c = invalid then c = Len(q)
    if ch = "⌫" then
        if c > 0 then SetQuery(Left(q, c - 1) + Mid(q, c + 1), c - 1)
    else if ch = "←" then
        if c > 0 then SetQuery(q, c - 1)
    else if ch = "→" then
        if c < Len(q) then SetQuery(q, c + 1)
    else if ch = "␣" then
        if c > 0 and Mid(q, c, 1) <> " " and Len(q) < 40 then SetQuery(Left(q, c) + " " + Mid(q, c + 1), c + 1)
    else if Len(q) < 40 then
        SetQuery(Left(q, c) + ch + Mid(q, c + 1), c + 1)
    end if
end sub

sub onKeySelected()
    i = m.keys.itemSelected
    if i >= 0 and i < m.keyChars.Count() then Typed(m.keyChars[i])
end sub

sub onDebounce()
    term = m.query.Trim()
    if Len(term) < 2 then
        m.rows.visible = false
        m.hasRows = false
        return
    end if
    m.seq = m.seq + 1
    CallApi({ path: "/v2/search", params: { term: term, group: "true", limit: "20" }, token: "acc", tag: m.seq }, "onResults")
end sub

sub onResults(event as Object)
    r = event.getData()
    if r = invalid or r.tag <> m.seq then return
    if not r.ok or r.json = invalid then
        m.msg.text = "Søgningen kunne ikke gennemføres."
        m.msg.visible = true
        return
    end if
    specs = []
    for each g in [{ k: "series", t: "Serier" }, { k: "movies", t: "Film" }, { k: "playable", t: "Programmer" }, { k: "tv", t: "TV" }]
        grp = r.json[g.k]
        if grp <> invalid and grp.items <> invalid and grp.items.Count() > 0 then
            items = []
            for each it in grp.items
                if g.k = "series" then items.Push(PosterSpec(it, 165, invalid)) else items.Push(TileSpec(it, 384))
            end for
            kind = "tile"
            w = 384
            if g.k = "series" then
                kind = "poster"
                w = 165
            end if
            specs.Push(RowSpec("g" + g.k, g.t, kind, items, w))
        end if
    end for
    m.msg.visible = false
    if specs.Count() = 0 then
        m.rows.visible = false
        m.hasRows = false
        m.msg.text = "Ingen resultater"
        m.msg.visible = true
        return
    end if
    ApplyRows(m.rows, specs, 480, -1, 0)
    m.rows.numRows = 1
    m.rows.visible = true
    m.hasRows = true
end sub

sub onRowSelected()
    sel = m.rows.rowItemSelected
    row = m.rows.content.getChild(sel[0])
    if row = invalid then return
    item = row.getChild(sel[1])
    if item <> invalid and item.data <> invalid then m.top.action = { type: "open", data: item.data }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "up" and m.keys.isInFocusChain() and m.keys.currFocusRow = 0 then
        m.nav.setFocus(true)
        return true
    else if key = "down" and m.keys.isInFocusChain() and m.keys.currFocusRow = 3 and m.hasRows then
        m.rows.setFocus(true)
        return true
    else if key = "up" and m.rows.isInFocusChain() then
        m.keys.setFocus(true)
        return true
    else if key = "replay" or key = "backspace" or key = "rewind" then
        Typed("⌫")
        return true
    end if
    ' letters typed from the Roku mobile app or a USB keyboard
    ch = key
    if Left(key, 4) = "Lit_" then ch = Mid(key, 5)
    if Len(ch) = 1 and ch <> " " and (UCase(ch) <> LCase(ch) or Instr(1, "0123456789-", ch) > 0) then
        Typed(LCase(ch))
        return true
    else if ch = " " or key = "Lit_ " then
        Typed("␣")
        return true
    end if
    return false
end function
