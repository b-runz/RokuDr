' Unofficial personal DRTV client. Entry point: creates the SceneGraph screen with MainScene.
sub Main(args as Dynamic)
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
