' Small helpers shared by tasks and screens (included with <script> in each component that needs them).

function CsAA() as Object
    ' case-sensitive associative array: DR's API has camelCase query names/JSON keys that must keep their case
    a = CreateObject("roAssociativeArray")
    a.SetModeCaseSensitive()
    return a
end function

function TimeNow() as Integer
    d = CreateObject("roDateTime")
    return d.AsSeconds()
end function

function IsStr(v as Dynamic) as Boolean
    t = Type(v)
    return t = "roString" or t = "String"
end function

function Txt(v as Dynamic) as String
    ' safe string for any JSON value (numbers may arrive as Integer, Float, LongInteger or Double)
    if v = invalid then return ""
    if IsStr(v) then return v
    t = Type(v)
    if t = "roAssociativeArray" or t = "roArray" or t = "roSGNode" or t = "roList" then return ""
    if t = "Boolean" or t = "roBoolean" then
        if v then return "true"
        return "false"
    end if
    if GetInterface(v, "ifToStr") <> invalid then return v.ToStr()
    return ""
end function

function Num(v as Dynamic) as Float
    if v = invalid then return 0
    if IsStr(v) then return Val(v)
    t = Type(v)
    if t = "Integer" or t = "roInt" or t = "LongInteger" or t = "roLongInteger" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return v
    return 0
end function

function RegRead(key as String) as String
    sec = CreateObject("roRegistrySection", "drtv")
    if sec.Exists(key) then return sec.Read(key)
    return ""
end function

sub RegWrite(key as String, value as String)
    sec = CreateObject("roRegistrySection", "drtv")
    sec.Write(key, value)
    sec.Flush()
end sub

sub RegDelete(key as String)
    sec = CreateObject("roRegistrySection", "drtv")
    sec.Delete(key)
    sec.Flush()
end sub

function B64UrlToString(s as String) as String
    t = s.Replace("-", "+").Replace("_", "/")
    while t.Len() mod 4 <> 0
        t = t + "="
    end while
    ba = CreateObject("roByteArray")
    ba.FromBase64String(t)
    return ba.ToAsciiString()
end function

function JwtExp(token as String) as Integer
    parts = token.Split(".")
    if parts.Count() < 2 then return 0
    j = ParseJson(B64UrlToString(parts[1]))
    if j = invalid then return 0
    if j.exp = invalid then return 0
    return Int(Num(j.exp))
end function

' DR image URLs carry Width/Height: ask for about what we display. Quotes are escaped for the Roku image loader.
function Sized(url as Dynamic, w as Integer, h as Integer) as String
    if not IsStr(url) then return ""
    if url = "" then return ""
    u = url
    re1 = CreateObject("roRegex", "Width=\d+", "")
    re2 = CreateObject("roRegex", "Height=\d+", "")
    u = re1.Replace(u, "Width=" + w.ToStr())
    u = re2.Replace(u, "Height=" + h.ToStr())
    return u.Replace("'", "%27")
end function

' first non-empty image of the given keys
function PickImage(images as Dynamic, keys as Object) as String
    if images = invalid then return ""
    for each k in keys
        v = images[k]
        if IsStr(v) and v <> "" then return v
    end for
    return ""
end function

' DR serves one generic placeholder as "poster" for series without artwork
function NoArt(url as Dynamic) as Boolean
    if not IsStr(url) then return true
    if url = "" then return true
    return Instr(1, url, "ImageId='16099618'") > 0 or Instr(1, url, "ImageId='16099620'") > 0 or Instr(1, url, "ImageId=%2716099618%27") > 0
end function

function Pad2(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

' "13:15" in local time from an ISO string (DR sends UTC)
function ClockOf(iso as Dynamic) as String
    if not IsStr(iso) then return ""
    d = CreateObject("roDateTime")
    d.FromISO8601String(iso)
    d.ToLocalTime()
    return Pad2(d.GetHours()) + ":" + Pad2(d.GetMinutes())
end function

function IsoSeconds(iso as Dynamic) as Integer
    if not IsStr(iso) then return 0
    d = CreateObject("roDateTime")
    d.FromISO8601String(iso)
    return d.AsSeconds()
end function

function DayMonth(seconds as Integer) as String
    d = CreateObject("roDateTime")
    d.FromSeconds(seconds)
    d.ToLocalTime()
    months = ["jan.", "feb.", "mar.", "apr.", "maj", "jun.", "jul.", "aug.", "sep.", "okt.", "nov.", "dec."]
    return d.GetDayOfMonth().ToStr() + ". " + months[d.GetMonth() - 1]
end function

' the part after "Show: " in an episode title
function EpisodeName(ep as Object) as String
    n = Txt(ep.episodeName)
    if n = "" then n = Txt(ep.title)
    p = Instr(1, n, ": ")
    if p > 0 then n = Mid(n, p + 2)
    return n
end function

function LastPathId(path as Dynamic) as String
    if not IsStr(path) then return ""
    re = CreateObject("roRegex", "_(\d+)$", "")
    m = re.Match(path)
    if m.Count() > 1 then return m[1]
    return ""
end function

' stable insertion sort of an array of associative arrays by one key (numbers or case-insensitive strings)
function SortAA(items as Object, key as String, descending as Boolean) as Object
    out = []
    for each it in items
        v = it[key]
        if IsStr(v) then v = LCase(v)
        i = out.Count() - 1
        while i >= 0
            ov = out[i][key]
            if IsStr(ov) then ov = LCase(ov)
            moveBefore = v < ov
            if descending then moveBefore = v > ov
            if moveBefore then i = i - 1 else exit while
        end while
        out.Push(invalid)
        j = out.Count() - 1
        while j > i + 1
            out[j] = out[j - 1]
            j = j - 1
        end while
        out[i + 1] = it
    end for
    return out
end function

function DeviceId() as String
    id = RegRead("deviceId")
    if id = "" then
        id = CreateObject("roDeviceInfo").GetRandomUUID()
        RegWrite("deviceId", id)
    end if
    return id
end function

function JwtClaim(token as String, name as String) as String
    parts = token.Split(".")
    if parts.Count() < 2 then return ""
    j = ParseJson(B64UrlToString(parts[1]))
    if j = invalid or j[name] = invalid then return ""
    return Txt(j[name])
end function
