import
    framebuffer,
    inputCatcher,
    ecSystem,
    unicode,
    terminal,
    random,
    os

type
    Image = object
        data: seq[seq[Rune]]
    Position = object
        x,y: float
    Asteroid = object
        value: int
    Star = distinct int
    Player = object
        score: int
    Bullet = distinct int

const transparentRune = "`".toRune

const asteroidMiddleTemplates = [
    [
        "OOOOOOO".toRunes,
        "OOOOOOO".toRunes
    ],
    [
        "OOOOOOO".toRunes,
        "OOOOOO`".toRunes
    ],
    [
        "OOOOOOO".toRunes,
        "`OOOOOO".toRunes
    ],
    [
        "OOOOOOO".toRunes,
        "`OOOOO`".toRunes
    ],
    [
        "OOOOOO`".toRunes,
        "`OOOOOO".toRunes
    ],
    [
        "`OOOOOO".toRunes,
        "OOOOOO`".toRunes
    ],
    [
        "OOOOOO`".toRunes,
        "OOOOOOO".toRunes
    ],
    [
        "`OOOOOO".toRunes,
        "OOOOOOO".toRunes
    ],
    [
        "`OOOOO`".toRunes,
        "OOOOOOO".toRunes
    ]
]

const asteroidTopTemplates = [
    "`OOOOO`".toRunes,
    "``OOOO`".toRunes,
    "`OOOO``".toRunes,
    "```OOO`".toRunes,
    "``OOO``".toRunes,
    "`OOO```".toRunes
]

const spaceshipImg = Image(data: @[
    "``Λ``".toRunes,
    "`/^\\`".toRunes,
    "/___\\".toRunes,
    "`^^^`".toRunes
])

func isOk(img: Image): bool =
    if img.data.len == 0:
        return false
    for line in img.data:
        if line.len != img.data[0].len:
            return false
    true

func width(img: Image): int =
    doAssert img.data.len > 0
    assert img.isOk
    img.data[0].len

func height(img: Image): int =
    img.data.len


func areColliding(posA, posB: Position, imgA, imgB: Image): bool =
    let
        xA = posA.x.int
        yA = posA.y.int
        xB = posB.x.int
        yB = posB.y.int

        left = max(xA, xB)
        right = min(xA + imgA.width, xB + imgB.width)
        top = max(yA, yB)
        bottom = min(yA + imgA.height, yB + imgB.height)
    
    template getRune(img: Image, xImg, yImg, xAt, yAt): Rune =
        let
            x = xAt - xImg
            y = yAt - yImg
        doAssert y >= 0
        doAssert y < img.data.len
        doAssert x >= 0
        doAssert x < img.data[0].len
        img.data[y][x]

    for x in left..right:
        for y in top..bottom:
            if imgA.getRune(xA, yA, x, y) != transparentRune and
            imgB.getRune(xB, yB, x, y) != transparentRune:
                return true
    false

proc randomAsteroidImage(): Image =
    result.data.add asteroidTopTemplates[rand(asteroidTopTemplates.high)]
    result.data.add asteroidMiddleTemplates[rand(asteroidMiddleTemplates.high)]
    result.data.add asteroidTopTemplates[rand(asteroidTopTemplates.high)]
    for line in result.data.mitems:
        for rune in line.mitems:
            if rune == "O".toRune:
                if rand(1.0) < 0.1:
                    rune = "o".toRune
                elif rand(1.0) < 0.1:
                    rune = "0".toRune

proc randomStarImage(): Image =
    result.data = @[@[".".toRune]]
    if rand(1.0) > 0.9:
        result.data[0][0] = "✦".toRune

proc game() =
    var
        ecm: EntityComponentManager
        fb = newFramebuffer(transparentRune)
        inputCatcher: InputCatcher

    let quitChars = ['q', 27.char]
    inputCatcher.start(quitChars)

    while true:
        for input in inputCatcher.get():
            if input in quitChars:
                return
            case input:
            of ' ':
                fb.clear()
                for x in 0..<fb.width:
                    for y in 0..<fb.height:
                        if rand(1.0) < 0.01:
                            fb.add(randomStarImage().data, x, y)

                fb.add(randomAsteroidImage().data, x = 20, y = 30)
                fb.add(spaceshipImg.data, x = 50, y = 10)
            else:
                discard
        fb.print()
        


randomize()
game()