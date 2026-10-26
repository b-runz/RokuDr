sub init()
    m.items = m.top.findNode("items")
    m.idx = 0
    m.nodes = []
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

function NavFont(bold as Boolean) as String
    if bold then return "font:SmallBoldSystemFont"
    return "font:SmallSystemFont"
end function

sub rebuild()
    tabs = m.top.tabs
    if tabs = invalid then return
    m.items.removeChildrenIndex(m.items.getChildCount(), 0)
    m.nodes = []
    xLeft = 120
    xRight = 1800
    ' right-aligned tabs are laid out from the right edge
    for i = 0 to tabs.Count() - 1
        t = tabs[i]
        bg = CreateObject("roSGNode", "Rectangle")
        bg.color = "0x000000FF"
        bg.visible = false
        ul = CreateObject("roSGNode", "Rectangle")
        ul.color = "0xFF0018FF"
        ul.visible = (t.id = m.top.active)
        lbl = CreateObject("roSGNode", "Label")
        lbl.font = NavFont(t.id = m.top.active)
        lbl.text = UCase(t.label)
        lbl.color = "0x111111FF"
        w = Len(t.label) * 22 + 10
        lbl.width = w + 8
        lbl.height = 50
        lbl.vertAlign = "center"
        m.items.appendChild(bg)
        m.items.appendChild(ul)
        m.items.appendChild(lbl)
        m.nodes.Push({ bg: bg, ul: ul, lbl: lbl, w: w + 8, right: t.right = true })
    end for
    ' positions
    x = xLeft
    for each n in m.nodes
        if not n.right then
            n.x = x
            x = x + n.w + 44
        end if
    end for
    x = xRight
    for i = m.nodes.Count() - 1 to 0 step -1
        n = m.nodes[i]
        if n.right then
            x = x - n.w
            n.x = x
            x = x - 44
        end if
    end for
    for each n in m.nodes
        n.lbl.translation = [n.x, 0]
        n.bg.translation = [n.x - 14, 0]
        n.bg.width = n.w + 28
        n.bg.height = 50
        n.ul.translation = [n.x, 54]
        n.ul.width = n.w
        n.ul.height = 5
    end for
    for i = 0 to tabs.Count() - 1
        if tabs[i].id = m.top.active then m.idx = i
    end for
    paint()
end sub

sub paint()
    focused = m.top.hasFocus()
    for i = 0 to m.nodes.Count() - 1
        n = m.nodes[i]
        on = focused and i = m.idx
        n.bg.visible = on
        if on then n.lbl.color = "0xFFFFFFFF" else n.lbl.color = "0x111111FF"
    end for
end sub

sub onFocusChanged()
    paint()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    n = m.nodes.Count()
    if n = 0 then return false
    if key = "left" then
        if m.idx > 0 then m.idx = m.idx - 1
        paint()
        return true
    else if key = "right" then
        if m.idx < n - 1 then m.idx = m.idx + 1
        paint()
        return true
    else if key = "down" then
        m.top.downRequested = true
        return true
    else if key = "OK" then
        m.top.selected = m.top.tabs[m.idx].id
        return true
    end if
    return false
end function
