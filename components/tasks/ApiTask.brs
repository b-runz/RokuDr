sub init()
    m.top.functionName = "doRequest"
end sub

sub doRequest()
    req = m.top.request
    if req = invalid then return
    if req.batch <> invalid then
        par = 6
        if req.parallel <> invalid then par = req.parallel
        m.top.response = { batch: RunBatch(req.batch, par), tag: req.tag }
        return
    end if
    resp = RunRequest(req)
    resp.tag = req.tag
    m.top.response = resp
end sub
