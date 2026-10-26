sub init()
    m.code = m.top.findNode("code")
    m.hint = m.top.findNode("hint")
    m.poll = m.top.findNode("poll")
    m.poll.observeField("fire", "onPoll")
    m.tasks = []
    m.busy = false
    m.alive = true
end sub

sub Activate()
    m.top.setFocus(true)
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

sub Start()
    m.alive = true
    body = { id: DeviceId(), name: "Roku (uofficiel)", type: "web_browser" }
    CallApi({ path: "/authorization/device/code", method: "POST", token: "none", minimal: true, body: body }, "onCode")
end sub

sub StopScreen()
    m.alive = false
    m.poll.control = "stop"
end sub

sub onCode(event as Object)
    r = event.getData()
    if r = invalid or not r.ok or r.json = invalid or r.json.code = invalid then
        m.hint.text = "Kunne ikke hente en kode. Tryk Tilbage og prøv igen senere."
        return
    end if
    m.pending = Txt(r.json.code)
    m.code.text = m.pending
    m.hint.text = "Venter på godkendelse…"
    m.poll.control = "start"
end sub

sub onPoll()
    if m.busy or not m.alive then return
    m.busy = true
    body = { code: m.pending, id: DeviceId() }
    CallApi({ path: "/authorization/device", method: "POST", token: "none", minimal: true, body: body, storeTokens: true }, "onPolled")
end sub

sub onPolled(event as Object)
    m.busy = false
    r = event.getData()
    if r <> invalid and r.ok and r.json <> invalid and Type(r.json) = "roArray" then
        m.poll.control = "stop"
        m.hint.text = "Logget ind!"
        m.top.action = { type: "loggedIn" }
    end if
end sub
