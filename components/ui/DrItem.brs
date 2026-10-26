sub init()
    m.art = m.top.findNode("art")
    m.artBg = m.top.findNode("artBg")
    m.shade = m.top.findNode("shade")
    m.chipBg = m.top.findNode("chipBg")
    m.chip = m.top.findNode("chip")
    m.title = m.top.findNode("title")
    m.sub = m.top.findNode("sub")
    m.l2 = m.top.findNode("l2")
    m.progBg = m.top.findNode("progBg")
    m.prog = m.top.findNode("prog")
    m.badgeBg = m.top.findNode("badgeBg")
    m.badge = m.top.findNode("badge")
    m.mineBg = m.top.findNode("mineBg")
    m.mine = m.top.findNode("mine")
    m.ring = m.top.findNode("ring")
    m.ringT = m.top.findNode("ringT")
    m.ringB = m.top.findNode("ringB")
    m.ringL = m.top.findNode("ringL")
    m.ringR = m.top.findNode("ringR")
end sub

sub onSize()
    layout()
end sub

sub onContent()
    layout()
end sub

sub onFocus()
    m.ring.visible = m.top.itemHasFocus and m.top.rowListHasFocus
end sub

function F(c as Object, name as String, fallback as Dynamic) as Dynamic
    v = c[name]
    if v = invalid then return fallback
    return v
end function

' size of the picture part for a kind (rest of the item height is caption space)
function ArtHeight(kind as String, w as Float, h as Float) as Float
    if kind = "hero" or kind = "pill" then return h
    if kind = "poster" then return Int(w * 1.5)
    if kind = "square" then return w
    if kind = "more" then return Int(w * 1.5)
    return Int(w * 9 / 16)   ' tile, live
end function

sub layout()
    c = m.top.itemContent
    w = m.top.width
    h = m.top.height
    if c = invalid or w = 0 or h = 0 then return
    kind = F(c, "kind", "tile")
    aH = ArtHeight(kind, w, h)

    m.chip.font = "font:SmallestBoldSystemFont"
    for each n in [m.shade, m.chipBg, m.chip, m.title, m.sub, m.l2, m.progBg, m.prog, m.badgeBg, m.badge, m.mineBg, m.mine]
        n.visible = false
    end for
    m.artBg.color = "0xE9E4E4FF"
    m.title.color = "0x222222FF"
    m.title.horizAlign = "left"
    m.title.vertAlign = "top"
    m.artBg.width = w : m.artBg.height = aH
    m.art.width = w : m.art.height = aH
    m.art.uri = F(c, "art", "")
    m.art.visible = kind <> "more" and kind <> "pill"
    m.artBg.visible = true
    if kind = "more" then m.artBg.color = "0xEFEAEAFF"

    ttl = c.title
    if ttl = invalid then ttl = ""
    chipTxt = F(c, "chip", "")
    chipColor = F(c, "chipColor", "0xFF0018FF")

    if kind = "hero" then
        boxH = 150
        if chipTxt = "" then boxH = 112
        m.shade.translation = [24, h - 24 - boxH]
        m.shade.width = w - 48
        m.shade.height = boxH
        m.shade.visible = true
        y = h - 24 - boxH + 8
        if chipTxt <> "" then
            m.chipBg.color = chipColor
            m.chip.text = chipTxt
            cw = Len(chipTxt) * 17 + 30
            m.chipBg.translation = [36, y] : m.chipBg.width = cw : m.chipBg.height = 34 : m.chipBg.visible = true
            m.chip.translation = [36, y] : m.chip.width = cw : m.chip.height = 34 : m.chip.visible = true
            y = y + 40
        end if
        m.title.font = "font:MediumBoldSystemFont"
        m.title.translation = [36, y] : m.title.width = w - 72 : m.title.height = 40 : m.title.numLines = 1 : m.title.text = ttl : m.title.visible = true
        m.sub.translation = [36, y + 42] : m.sub.width = w - 72 : m.sub.height = 32 : m.sub.text = F(c, "sub", "") : m.sub.visible = true
    else if kind = "pill" then
        if F(c, "chip", "") = "sel" then
            m.artBg.color = "0x222222FF"
            m.title.color = "0xFFFFFFFF"
        else
            m.artBg.color = "0xECE8E8FF"
        end if
        m.title.font = "font:MediumBoldSystemFont"
        m.title.translation = [0, 0] : m.title.width = w : m.title.height = h
        m.title.numLines = 1 : m.title.text = ttl : m.title.visible = true
        m.title.vertAlign = "center" : m.title.horizAlign = "center"
    else if kind = "more" then
        m.title.font = "font:SmallBoldSystemFont"
        m.title.translation = [0, 0] : m.title.width = w : m.title.height = aH
        m.title.numLines = 3 : m.title.text = ttl : m.title.visible = true : m.title.vertAlign = "center" : m.title.horizAlign = "center"
        m.progBg.visible = false
    else
        ' caption below the picture
        y = aH + 10
        m.title.font = "font:SmallBoldSystemFont"
        m.title.translation = [0, y] : m.title.width = w : m.title.height = 64 : m.title.numLines = 2 : m.title.text = ttl : m.title.visible = true
        m.title.vertAlign = "top" : m.title.horizAlign = "left"
        y = y + 64
        if kind = "live" then
            m.sub.translation = [0, y] : m.sub.width = w : m.sub.height = 30 : m.sub.text = F(c, "sub", "") : m.sub.visible = true
            m.l2.translation = [0, y + 32] : m.l2.width = w : m.l2.height = 28 : m.l2.text = F(c, "l2", "") : m.l2.visible = true
        else if F(c, "sub", "") <> "" then
            m.sub.translation = [0, y] : m.sub.width = w : m.sub.height = 30 : m.sub.text = F(c, "sub", "") : m.sub.visible = true
        end if
        if chipTxt <> "" and kind <> "live" then
            m.chipBg.color = chipColor
            m.chip.text = chipTxt
            cw = Len(chipTxt) * 17 + 26
            m.chipBg.translation = [0, y] : m.chipBg.width = cw : m.chipBg.height = 30 : m.chipBg.visible = true
            m.chip.translation = [0, y] : m.chip.width = cw : m.chip.height = 30 : m.chip.visible = true
        end if
        if kind = "live" then
            m.chipBg.color = "0xFF0018FF"
            m.chip.text = "LIVE"
            m.chipBg.translation = [14, 14] : m.chipBg.width = 76 : m.chipBg.height = 32 : m.chipBg.visible = true
            m.chip.translation = [14, 14] : m.chip.width = 76 : m.chip.height = 32 : m.chip.visible = true
        end if
    end if

    p = F(c, "progress", 0)
    if p > 0 and kind <> "more" and kind <> "pill" then
        m.progBg.translation = [0, aH - 9] : m.progBg.width = w : m.progBg.height = 9 : m.progBg.visible = true
        m.prog.translation = [0, aH - 9] : m.prog.width = w * p : m.prog.height = 9 : m.prog.visible = true
    end if

    b = F(c, "badge", "")
    if b <> "" and kind <> "hero" and kind <> "more" then
        m.badge.text = b
        bw = Len(b) * 13 + 28
        m.badgeBg.translation = [-18, 24] : m.badgeBg.width = bw : m.badgeBg.height = 38 : m.badgeBg.visible = true
        m.badge.translation = [-18, 24] : m.badge.width = bw : m.badge.height = 38 : m.badge.visible = true
    end if
    mn = F(c, "mine", "")
    if mn <> "" then
        m.mine.text = mn
        m.mineBg.translation = [8, 8] : m.mineBg.width = 54 : m.mineBg.height = 26 : m.mineBg.visible = true
        m.mine.translation = [8, 8] : m.mine.width = 54 : m.mine.height = 26 : m.mine.visible = true
    end if

    ' focus ring around the picture area
    t = 5
    rh = aH
    if kind = "more" then rh = aH
    m.ringT.translation = [-t, -t] : m.ringT.width = w + 2 * t : m.ringT.height = t
    m.ringB.translation = [-t, rh] : m.ringB.width = w + 2 * t : m.ringB.height = t
    m.ringL.translation = [-t, 0] : m.ringL.width = t : m.ringL.height = rh
    m.ringR.translation = [w, 0] : m.ringR.width = t : m.ringR.height = rh
    onFocus()
end sub
