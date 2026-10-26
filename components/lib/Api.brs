' DR "Massive" API client for task threads: HTTP, default query, token handling (device-code login + refresh).
' Requires Util.brs. Never call from the render thread (blocking network).

function DrBase() as String
    return "https://prod95.dr-massive.com/api"
end function

function DefaultParams(signedIn as Boolean) as Object
    p = CsAA()
    p["device"] = "web_browser"
    p["ff"] = "idp,ldp,rpt"
    p["geoLocation"] = "dk"
    p["isDeviceAbroad"] = "false"
    p["lang"] = "da"
    if signedIn then
        p["sub"] = "Registered"
        p["segments"] = "drtv,optedin"
    else
        p["sub"] = "Anonymous"
        p["segments"] = "drtv,optedout"
    end if
    return p
end function

function QueryString(params as Object) as String
    xfer = CreateObject("roUrlTransfer")
    parts = []
    for each k in params
        v = params[k]
        parts.Push(xfer.Escape(k) + "=" + xfer.Escape(Txt(v)))
    end for
    out = ""
    for i = 0 to parts.Count() - 1
        if i > 0 then out = out + "&"
        out = out + parts[i]
    end for
    return out
end function

' ---------------------------------------------------------------- tokens
' kind = "acc" (account token) or "pro" (profile token). Both live in the registry; refreshed when < 30 min left.
function GetToken(kind as String) as String
    tok = RegRead(kind + "T")
    if tok = "" then return ""
    exp = Val(RegRead(kind + "E"))
    if exp - TimeNow() < 1800 then
        if RefreshToken(kind, tok) then tok = RegRead(kind + "T")
    end if
    return tok
end function

function RefreshToken(kind as String, tok as String) as Boolean
    body = CsAA()
    body["token"] = tok
    body["cookieType"] = "Persistent"
    body["optout"] = false
    p = CsAA()
    p["ff"] = "idp,ldp,rpt"
    p["lang"] = "da"
    p["supportFallbackToken"] = "true"
    r = HttpOnce("POST", DrBase() + "/authorization/refresh?" + QueryString(p), tok, FormatJson(body))
    if r.status < 200 or r.status >= 300 then
        if r.status = 401 or r.status = 403 then
            RegDelete(kind + "T")
            RegDelete(kind + "E")
        end if
        return false
    end if
    j = ParseJson(r.body)
    if j = invalid then return false
    if j.value = invalid then return false
    RegWrite(kind + "T", j.value)
    RegWrite(kind + "E", JwtExp(j.value).ToStr())
    return true
end function

sub StoreTokens(list as Object)
    for each t in list
        v = t.value
        if v = invalid then v = t.Token
        if v <> invalid then
            kind = "acc"
            ty = t.type
            if ty = invalid then ty = t.TokenType
            if ty = "UserProfile" then kind = "pro"
            RegWrite(kind + "T", v)
            RegWrite(kind + "E", JwtExp(v).ToStr())
        end if
    end for
end sub

sub ClearTokens()
    RegDelete("accT") : RegDelete("accE") : RegDelete("proT") : RegDelete("proE") : RegDelete("pend")
end sub



' ---------------------------------------------------------------- HTTP
function NewTransfer(port as Object, method as String, url as String, token as String, body as String) as Object
    http = CreateObject("roUrlTransfer")
    http.SetPort(port)
    http.SetUrl(url)
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    http.EnableEncodings(true)
    http.RetainBodyOnError(true)
    http.AddHeader("Accept", "application/json")
    http.AddHeader("User-Agent", "Mozilla/5.0")
    if token <> "" then http.AddHeader("X-Authorization", token)
    if method <> "GET" then
        http.AddHeader("Content-Type", "application/json")
        http.SetRequest(method)
    end if
    return http
end function

function StartTransfer(http as Object, method as String, body as String) as Boolean
    if method = "GET" then return http.AsyncGetToString()
    return http.AsyncPostFromString(body)
end function

function HttpOnce(method as String, url as String, token as String, body as String) as Object
    port = CreateObject("roMessagePort")
    http = NewTransfer(port, method, url, token, body)
    if not StartTransfer(http, method, body) then return { status: 0, body: "" }
    msg = wait(20000, port)
    if type(msg) = "roUrlEvent" then return { status: msg.GetResponseCode(), body: msg.GetString() }
    http.AsyncCancel()
    return { status: 0, body: "" }
end function

' run many requests concurrently; reqs = [{method,url,token,body}]; returns [{status, body}] in the same order
function HttpBatch(reqs as Object, maxParallel as Integer) as Object
    port = CreateObject("roMessagePort")
    total = reqs.Count()
    results = []
    for i = 0 to total - 1
        results.Push({ status: 0, body: "" })
    end for
    pending = {}
    active = {}
    nextIdx = 0
    done = 0
    while done < total
        while nextIdx < total and pending.Count() < maxParallel
            r = reqs[nextIdx]
            http = NewTransfer(port, r.method, r.url, r.token, r.body)
            id = http.GetIdentity().ToStr()
            if StartTransfer(http, r.method, r.body) then
                pending[id] = nextIdx
                active[id] = http
            else
                done = done + 1
            end if
            nextIdx = nextIdx + 1
        end while
        if pending.Count() = 0 then
            if nextIdx >= total then exit while
        else
            msg = wait(25000, port)
            if type(msg) <> "roUrlEvent" then exit while
            id = msg.GetSourceIdentity().ToStr()
            if pending.DoesExist(id) then
                results[pending[id]] = { status: msg.GetResponseCode(), body: msg.GetString() }
                pending.Delete(id)
                active.Delete(id)
                done = done + 1
            end if
        end if
    end while
    return results
end function

' build one request description for HttpBatch / RunRequest
function BuildRequest(req as Object, tokens as Object) as Object
    method = "GET"
    if req.method <> invalid then method = req.method
    kind = "acc"
    if req.token <> invalid then kind = req.token
    tok = ""
    if kind <> "none" then tok = tokens[kind]
    if tok = invalid then tok = ""
    params = DefaultParams(tok <> "")
    if req.minimal = true then
        params = CsAA()
        params["ff"] = "idp,ldp,rpt"
        params["lang"] = "da"
    end if
    if req.params <> invalid then
        for each k in req.params
            params[k] = req.params[k]
        end for
    end if
    if req.path = "/v2/search" and params["userId"] = invalid then
        uid = "anonymous"
        pt = tokens["pro"]
        if pt <> invalid and pt <> "" then
            c = JwtClaim(pt, "userProfileId")
            if c <> "" then uid = c
        end if
        params["userId"] = uid
    end if
    url = req.url
    if url = invalid then url = DrBase() + req.path
    sep = "?"
    if Instr(1, url, "?") > 0 then sep = "&"
    url = url + sep + QueryString(params)
    body = ""
    if req.body <> invalid then body = FormatJson(req.body)
    return { method: method, url: url, token: tok, body: body }
end function

function CurrentTokens() as Object
    t = CsAA()
    t["acc"] = GetToken("acc")
    t["pro"] = GetToken("pro")
    return t
end function

function ParseResponse(r as Object) as Object
    ok = r.status >= 200 and r.status < 300
    j = invalid
    if r.body <> invalid and r.body <> "" then j = ParseJson(r.body)
    return { status: r.status, ok: ok, json: j }
end function

' one API call with tokens resolved: req = {path|url, method, params, token:"acc"|"pro"|"none", body, storeTokens}
function RunRequest(req as Object) as Object
    tokens = CurrentTokens()
    b = BuildRequest(req, tokens)
    r = HttpOnce(b.method, b.url, b.token, b.body)
    resp = ParseResponse(r)
    if resp.ok and req.storeTokens = true and resp.json <> invalid and Type(resp.json) = "roArray" then StoreTokens(resp.json)
    return resp
end function

' many API calls in parallel; returns [{status, ok, json}]
function RunBatch(reqs as Object, maxParallel as Integer) as Object
    tokens = CurrentTokens()
    built = []
    for each r in reqs
        built.Push(BuildRequest(r, tokens))
    end for
    raw = HttpBatch(built, maxParallel)
    out = []
    for each r in raw
        out.Push(ParseResponse(r))
    end for
    return out
end function
