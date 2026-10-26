sub init()
    m.items = m.top.findNode("items")
    m.ring = m.top.findNode("ring")
    m.ringT = m.top.findNode("ringT")
    m.ringB = m.top.findNode("ringB")
    m.ringL = m.top.findNode("ringL")
    m.ringR = m.top.findNode("ringR")
    m.nodes = []
    m.top.observeField("focusedChild", "paint")
end sub

function BtnFont(bold as Boolean) as String
    if bold then return "font:SmallBoldSystemFont"
    return "font:SmallSystemFont"
end function

sub rebuild()
    labels = m.top.labels
    if labels = invalid then return
    m.items.removeChildrenIndex(m.items.getChildCount(), 0)
    m.nodes = []
    x = 0
    for i = 0 to labels.Count() - 1
        bg = CreateObject("roSGNode", "Rectangle")
        lbl = CreateObject("roSGNode", "Label")
        lbl.font = BtnFont(true)
        lbl.text = labels[i]
        w = Len(labels[i]) * 20 + 56
        if i = 0 and w < 250 then w = 250
        bg.width = w
        bg.height = 66
        bg.translation = [x, 0]
        if i = 0 then
            bg.color = "0xFF0018FF"
            lbl.color = "0xFFFFFFFF"
        else
            bg.color = "0x00000000"
            lbl.color = "0x222222FF"
        end if
        lbl.width = w
        lbl.height = 66
        lbl.horizAlign = "center"
        lbl.vertAlign = "center"
        lbl.translation = [x, 0]
        m.items.appendChild(bg)
        m.items.appendChild(lbl)
        m.nodes.Push({ x: x, w: w, bg: bg, lbl: lbl })
        x = x + w + 18
    end for
    if m.top.index >= labels.Count() then m.top.index = 0
    paint()
end sub

sub paint()
    focused = m.top.hasFocus()
    m.ring.visible = focused and m.nodes.Count() > 0
    if not m.ring.visible then return
    n = m.nodes[m.top.index]
    t = 5
    h = 66
    m.ringT.translation = [n.x - t, -t] : m.ringT.width = n.w + 2 * t : m.ringT.height = t
    m.ringB.translation = [n.x - t, h] : m.ringB.width = n.w + 2 * t : m.ringB.height = t
    m.ringL.translation = [n.x - t, 0] : m.ringL.width = t : m.ringL.height = h
    m.ringR.translation = [n.x + n.w, 0] : m.ringR.width = t : m.ringR.height = h
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "left" then
        if m.top.index > 0 then m.top.index = m.top.index - 1
        paint()
        return true
    else if key = "right" then
        if m.top.index < m.nodes.Count() - 1 then m.top.index = m.top.index + 1
        paint()
        return true
    else if key = "OK" then
        m.top.selected = m.top.index
        return true
    end if
    return false
end function
