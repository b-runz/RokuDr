sub init()
    m.rows = m.top.findNode("rows")
    m.nav = m.top.findNode("nav")
    m.msg = m.top.findNode("msg")
    m.busy = m.top.findNode("busy")
    m.specs = []
    m.tasks = []
    m.gotRows = false
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

sub Activate()
    if m.specs.Count() > 0 then
        m.rows.setFocus(true)
    else
        m.nav.setFocus(true)
    end if
end sub

' background API call: the callback runs on this component when the task answers
function CallApi(req as Object, callback as String) as Object
    t = CreateObject("roSGNode", "ApiTask")
    t.request = req
    t.observeField("response", callback)
    t.control = "RUN"
    m.tasks.Push(t)
    if m.tasks.Count() > 40 then m.tasks.Shift()
    return t
end function

sub ShowMessage(text as String)
    m.msg.text = text
    m.msg.visible = text <> ""
end sub

sub SetBusy(on as Boolean)
    if m.busy = invalid then return
    m.busy.visible = on
    if on then m.busy.control = "start" else m.busy.control = "stop"
end sub

' replace the rows; keeps focus on the same row (by key) when rows were added above it
sub ShowSpecs(specs as Object, forceFirst = false as Boolean)
    keepKey = ""
    keepCol = 0
    cur = m.rows.rowItemFocused
    if cur <> invalid and m.specs.Count() > 0 and cur.Count() = 2 then
        if cur[0] >= 0 and cur[0] < m.specs.Count() then
            keepKey = m.specs[cur[0]].key
            keepCol = cur[1]
        end if
    end if
    m.specs = specs
    row = 0
    if keepKey <> "" then
        for i = 0 to specs.Count() - 1
            if specs[i].key = keepKey then row = i
        end for
    end if
    if forceFirst then
        row = 0
        keepCol = 0
    end if
    ApplyRows(m.rows, specs, 880, row, keepCol)
    ' first content: hand focus from the nav to the rows
    if not m.gotRows and specs.Count() > 0 then
        m.gotRows = true
        m.rows.setFocus(true)
    end if
end sub

sub onRowSelected()
    sel = m.rows.rowItemSelected
    if sel = invalid or sel.Count() < 2 then return
    row = m.rows.content.getChild(sel[0])
    if row = invalid then return
    item = row.getChild(sel[1])
    if item = invalid then return
    d = item.data
    if d = invalid then return
    if d.go <> invalid then
        m.top.action = { type: "go", go: d.go }
    else
        m.top.action = { type: "open", data: d }
    end if
end sub

sub onNavSelected()
    m.top.action = { type: "nav", id: m.nav.selected }
end sub

sub onNavDown()
    if m.specs.Count() > 0 then m.rows.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "up" and m.rows.isInFocusChain() then
        m.nav.setFocus(true)
        return true
    end if
    return false
end function
