# VideoPlayer
This is a tool that can cache the data while playing remote video.

# Environment
xcode: 10.2 beta4  
swift: 5.0

<img src="https://github.com/ZhongshanHuang/VideoPlayer/raw/master/Docs/shot.png" width="50%" height="50%">

# 使用方法

``` swift
func playerTest() {
    let player = PoAVPlayer(frame: view.bounds)
    player.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    let control = PoAVPlayerControlView(player: player) // 控制层，可自定义替换
    player.addControlLayer(control)
    view.addSubview(player)

    let urlArray = ["http://www.w3school.com.cn/example/html5/mov_bbb.mp4",
                    "https://www.w3schools.com/html/movie.mp4",
                    "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
                    "https://media.w3.org/2010/05/sintel/trailer.mp4",
                    "http://mvvideo2.meitudata.com/576bc2fc91ef22121.mp4",
                    "http://mvvideo10.meitudata.com/5a92ee2fa975d9739_H264_3.mp4",
                    "http://mvvideo11.meitudata.com/5a44d13c362a23002_H264_11_5.mp4",
                    "http://mvvideo10.meitudata.com/572ff691113842657.mp4",
                    "https://api.tuwan.com/apps/Video/play?key=aHR0cHM6Ly92LnFxLmNvbS9pZnJhbWUvcGxheWVyLmh0bWw%2FdmlkPXUwNjk3MmtqNWV6JnRpbnk9MCZhdXRvPTA%3D&aid=381374",
                    "https://api.tuwan.com/apps/Video/play?key=aHR0cHM6Ly92LnFxLmNvbS9pZnJhbWUvcGxheWVyLmh0bWw%2FdmlkPWswNjk2enBud2xvJnRpbnk9MCZhdXRvPTA%3D&aid=381395"
    ]

    player.play(with: URL(string:urlArray.randomElement()!)!, needCache: true)
}
```
