sub init()
    m.bg = m.top.findNode("bg")
    m.lbl = m.top.findNode("lbl")
end sub

sub onContent()
    c = m.top.itemContent
    if c <> invalid then
        m.lbl.text = c.title
        if Len(c.title) > 2 then m.lbl.font = "font:SmallestSystemFont" else m.lbl.font = "font:MediumSystemFont"
    end if
    layout()
end sub

sub layout()
    w = m.top.width
    h = m.top.height
    if w = 0 or h = 0 then return
    m.bg.width = w
    m.bg.height = h
    m.lbl.width = w
    m.lbl.height = h
    onFocus()
end sub

sub onFocus()
    focused = m.top.itemHasFocus and m.top.gridHasFocus
    if focused then
        m.bg.color = "0xFFFFFFFF"
        m.lbl.color = "0x111111FF"
    else
        m.bg.color = "0x3A3A3AFF"
        m.lbl.color = "0xFFFFFFFF"
    end if
end sub
