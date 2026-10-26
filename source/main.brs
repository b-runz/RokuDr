' Unofficial personal DRTV client. Entry point: creates the SceneGraph screen with MainScene.
sub Main(args as Dynamic)
    SeedFromPackage()
    SeedFromArgs(args)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.Show()
    scene.signalBeacon("AppLaunchComplete")

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" then
            if msg.isScreenClosed() then return
        end if
    end while
end sub

' Personal builds (`npm run build -- --bake`) carry the DR session in pkg:/config/session.json.
' It is applied only when it is newer than the one already used on this device ("bakedAt"), so:
'  - a fresh install starts logged in,
'  - installing a newer build brings a fresher session,
'  - "Log ud" really logs out (the same build never re-applies its session).
sub SeedFromPackage()
    txt = ReadAsciiFile("pkg:/config/session.json")
    if txt = "" then return
    s = ParseJson(txt)
    if s = invalid then return
    if s.proT = invalid or s.accT = invalid or s.bakedAt = invalid then return
    sec = CreateObject("roRegistrySection", "drtv")
    have = 0
    if sec.Exists("bakedAt") then have = Val(sec.Read("bakedAt"))
    if Val(s.bakedAt.ToStr()) <= have then return
    for each k in ["accT", "accE", "proT", "proE", "deviceId"]
        if s[k] <> invalid and s[k] <> "" then sec.Write(k, s[k])
    end for
    sec.Write("bakedAt", s.bakedAt.ToStr())
    sec.Flush()
end sub

' Dev convenience: launch with accT/accE/proT/proE/deviceId (ECP "launch/dev?..." or the emulator deep link)
' to start already logged in, e.g. with the tokens of the local dev server. Ignored when absent.
sub SeedFromArgs(args as Dynamic)
    if args = invalid then return
    if args.proT = invalid or args.accT = invalid then return
    sec = CreateObject("roRegistrySection", "drtv")
    for each k in ["accT", "accE", "proT", "proE", "deviceId"]
        if args[k] <> invalid and args[k] <> "" then sec.Write(k, args[k])
    end for
    sec.Flush()
end sub
