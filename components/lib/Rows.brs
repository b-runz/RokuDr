' Row building for RowList screens: DR items -> item specs -> ContentNodes with per-row sizes.
' Requires Util.brs. Runs on the render thread (pure data shaping, no network).

function Fv(s as Object, key as String, fallback as Dynamic) as Dynamic
    v = s[key]
    if v = invalid then return fallback
    return v
end function

' ---- sizes (FHD). Row item height includes the caption space under the picture.
function KindSize(kind as String, w as Integer) as Object
    if kind = "hero" then return { w: 645, h: 363 }
    if kind = "poster" then
        if w = 0 then w = 165
        return { w: w, h: Int(w * 1.5) + 112 }
    end if
    if kind = "more" then return { w: 165, h: Int(165 * 1.5) + 112 }
    if kind = "square" then
        if w = 0 then w = 240
        return { w: w, h: w + 112 }
    end if
    if kind = "live" then return { w: 570, h: Int(570 * 9 / 16) + 150 }
    if kind = "pill" then return { w: 300, h: 70 }
    if w = 0 then w = 384
    return { w: w, h: Int(w * 9 / 16) + 112 }   ' tile
end function

function NewItem(kind as String, s as Object) as Object
    n = CreateObject("roSGNode", "ContentNode")
    fields = {
        kind: kind
        art: Fv(s, "art", "")
        sub: Fv(s, "sub", "")
        l2: Fv(s, "l2", "")
        chip: Fv(s, "chip", "")
        chipColor: Fv(s, "chipColor", "0xFF0018FF")
        progress: 1.0 * Num(Fv(s, "progress", 0))
        badge: Fv(s, "badge", "")
        mine: Fv(s, "mine", "")
        data: Fv(s, "data", {})
    }
    n.addFields(fields)
    n.title = Fv(s, "title", "")
    return n
end function

' spec = {key, title, kind, w, items:[itemSpec]}
function RowSpec(key as String, title as String, kind as String, items as Object, w as Integer) as Object
    return { key: key, title: title, kind: kind, items: items, w: w }
end function

sub ApplyRows(list as Object, specs as Object, availableHeight as Integer, focusRow as Integer, focusCol as Integer)
    root = CreateObject("roSGNode", "ContentNode")
    sizes = []
    heights = []
    spacings = []
    labels = []
    itemSpacing = []
    fits = 0
    used = 0
    counting = true
    for each spec in specs
        row = CreateObject("roSGNode", "ContentNode")
        row.title = spec.title
        for each it in spec.items
            k = spec.kind
            if it.kind <> invalid then k = it.kind
            row.appendChild(NewItem(k, it))
        end for
        root.appendChild(row)
        sz = KindSize(spec.kind, spec.w)
        labelH = 0
        if spec.title <> "" then labelH = 60
        sizes.Push([sz.w, sz.h])
        heights.Push(sz.h + labelH)
        spacings.Push(26)
        labels.Push(spec.title <> "")
        gap = 22
        if spec.kind = "hero" then gap = 18
        itemSpacing.Push([gap, 0])
        if counting then
            if used + sz.h + labelH <= availableHeight or fits = 0 then
                used = used + sz.h + labelH + 26
                fits = fits + 1
            else
                counting = false
            end if
        end if
    end for
    list.rowItemSize = sizes
    list.rowHeights = heights
    list.rowSpacings = spacings
    list.showRowLabel = labels
    list.rowItemSpacing = itemSpacing
    list.focusXOffset = [120]
    list.rowLabelOffset = [[120, 8]]
    if fits < 1 then fits = 1
    list.numRows = fits
    list.content = root
    if focusRow >= 0 and focusRow < specs.Count() then list.jumpToRowItem = [focusRow, focusCol]
end sub

' ---------------------------------------------------------------- DR items -> item specs
function ShowBadge(item as Object) as String
    cf = item.customFields
    if cf = invalid then return ""
    return Txt(cf["LinkTextBadge_Max_20_Characters"])
end function

function GenreOf(item as Object) as String
    g = item.genres
    if g = invalid or g.Count() = 0 then return ""
    x = g[0]
    if IsStr(x) then
        t = x
    else
        t = Txt(x.title)
    end if
    if LCase(t) = "ukendt" then return ""
    return t
end function

function SeasonsLabel(item as Object) as String
    n = Int(Num(item.availableSeasonCount))
    if n > 1 then return n.ToStr() + " SÆSONER"
    if n = 1 then return "1 SÆSON"
    return ""
end function

function TileSpec(item as Object, w as Integer) as Object
    imgs = item.images
    h = Int(w * 9 / 16)
    cap = Txt(item.title)
    sl = SeasonsLabel(item)
    if sl <> "" then cap = cap + " | " + sl
    return { title: cap, art: Sized(PickImage(imgs, ["tile", "wallpaper", "poster"]), w * 2, h * 2), badge: ShowBadge(item), data: item }
end function

' poster; series without a poster show their wide artwork cropped
function PosterSpec(item as Object, w as Integer, extra as Object) as Object
    imgs = item.images
    h = Int(w * 1.5)
    p = invalid
    if imgs <> invalid then p = imgs.poster
    if NoArt(p) then
        art = Sized(PickImage(imgs, ["tile", "wallpaper"]), Int(h * 2 * 16 / 9), h * 2)
    else
        art = Sized(p, w * 2, h * 2)
    end if
    s = { title: Txt(item.title), art: art, data: item }
    if extra <> invalid then
        for each k in extra
            s[k] = extra[k]
        end for
    end if
    return s
end function

function SquareSpec(item as Object, w as Integer) as Object
    return { title: Txt(item.title), art: Sized(PickImage(item.images, ["square", "tile", "poster", "wallpaper"]), w * 2, w * 2), data: item }
end function

function ChannelBadge(item as Object) as String
    cf = item.customFields
    if cf = invalid then return ""
    return Txt(cf.BrandingChannelShort)
end function

function ChannelChipColor(short as String) as String
    s = UCase(short)
    if s = "DR1" then return "0xFF0018FF"
    if s = "DR2" then return "0x00AAFFFF"
    if s = "TVL" or s = "ULTRA" then return "0x00B8A8FF"
    if s = "DRR" then return "0xE91E63FF"
    return "0x333333FF"
end function

function HeroSpec(item as Object) as Object
    sub1 = Txt(item.shortDescription)
    if sub1 = "LinkItem" or sub1 = "" then
        cf = item.customFields
        if cf <> invalid then sub1 = Txt(cf.ExtraDetails)
        if sub1 = "" then sub1 = Txt(item.contextualTitle)
    end if
    return { title: Txt(item.title), sub: sub1, art: Sized(PickImage(item.images, ["wallpaper", "tile"]), 1290, 726), chip: ChannelBadge(item), chipColor: ChannelChipColor(ChannelBadge(item)), data: item }
end function

' ---- a DR page entry (ListEntry) -> zero or more row specs
function RowsFromEntry(entry as Object, items as Object, keyPrefix as String) as Object
    rows = []
    if items = invalid or items.Count() = 0 then return rows
    t = Txt(entry.template)
    title = Txt(entry.title)
    key = keyPrefix + Txt(entry.id)
    out = []
    if t = "DRH6" then
        for each it in items
            out.Push(HeroSpec(it))
        end for
        rows.Push(RowSpec(key, "", "hero", out, 0))
    else if Left(t, 1) = "S" and (t = "S1" or t = "S2" or t = "S3") then
        for each it in items
            out.Push(SquareSpec(it, 240))
        end for
        rows.Push(RowSpec(key, title, "square", out, 240))
    else if t = "EPG1" or t = "DREPG5" then
        for each it in items
            out.Push(TileSpec(it, 384))
        end for
        rows.Push(RowSpec(key, title, "tile", out, 384))
    else if t = "TX1" then
        return rows
    else
        w = 384
        for each it in items
            out.Push(TileSpec(it, w))
        end for
        rows.Push(RowSpec(key, title, "tile", out, w))
    end if
    return rows
end function

' request description for a lazy list link ("/lists/123?page_size=24&page=1&sub=Registered")
function ListRequest(link as String) as Object
    re = CreateObject("roRegex", "[?&]sub=[^&]*", "")
    path = re.ReplaceAll(link, "")
    if Instr(1, path, "?") = 0 and Instr(1, path, "&") > 0 then
        p = Instr(1, path, "&")
        path = Left(path, p - 1) + "?" + Mid(path, p + 1)
    end if
    return { path: path, token: "acc" }
end function

function PageRequest(path as String) as Object
    return { path: "/page", params: { path: path, item_detail_expand: "all", list_page_size: "24", max_list_prefetch: "14" }, token: "acc" }
end function
