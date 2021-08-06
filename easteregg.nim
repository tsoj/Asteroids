import
    framebuffer,
    inputCatcher,
    ecSystem,
    unicode,
    terminal,
    random,
    os,
    times

type
    Image = object
        data: seq[seq[Rune]]
    Vec2 = object
        x, y: float
    Position = object#TODO: try distinct Vec2
        x, y: float
    Velocity = object
        x, y: float
    Asteroid = distinct int
    Star = distinct int
    Player = object
        score: int
    Bullet = distinct int
    RenderPriority = 0..2

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

const bulletImg = Image(data: @["▲".toRunes])

const spaceshipMaxVelocityY = 15.0
const spaceshipMaxVelocityX = 20.0

proc getBulletExhaust(): Rune =
    const possibleRunes = [
        "'".toRune,
        "ʼ".toRune,
        "˟".toRune,
        "΅".toRune,
        "\"".toRune,
        "´".toRune
    ]
    possibleRunes[rand(possibleRunes.high)]

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
                if rand(1.0) < 0.2:
                    rune = "o".toRune
                elif rand(1.0) < 0.2:
                    rune = "0".toRune

proc randomStarImage(): Image =
    result.data = @[@[".".toRune]]
    if false and rand(1.0) > 0.9:
        if rand(1.0) > 0.1:
            result.data[0][0] = "✦".toRune
        else:
            result.data[0][0] = "✧".toRune

type Box = object
    pos: Position
    dims: Vec2

proc randomPositionInBox(b: Box): Position =
    result.x = rand(b.pos.x..(b.pos.x + b.dims.x)).int.float
    result.y = rand(b.pos.y..(b.pos.y + b.dims.y)).int.float

func physicsStep(ecm: var EntityComponentManager, delta: Duration) =
    let deltaS = delta.inMicroseconds.float / 1_000_000.0
    forEach(ecm, p: var Position, v: Velocity):
        p.x += v.x * deltaS
        p.y += v.y * deltaS

proc renderStep(ecm: EntityComponentManager, fb: var Framebuffer) =
    fb.clear()
    let fbPtr = addr fb
    for renderPriority in RenderPriority.low..RenderPriority.high:
        forEach(ecm, p: Position, img: Image, rp: RenderPriority):
            if rp == renderPriority:
                fbPtr[].add(img.data, x = p.x.int, y = p.y.int)
    fb.print()

proc addAsteroid(ecm: var EntityComponentManager, box: Box) =
    let entity = ecm.addEntity()
    ecm.add(entity, Asteroid(0))
    ecm.add(entity, RenderPriority(1))
    ecm.add(entity, randomAsteroidImage())
    var box = box
    box.dims.x -= ecm.get(entity, Image).width.float
    box.dims.y -= ecm.get(entity, Image).height.float
    ecm.add(entity, randomPositionInBox(box))
    ecm.add(entity, Velocity(x: 0.0, y: 12.0))

proc addStar(ecm: var EntityComponentManager, box: Box) =
    let entity = ecm.addEntity()
    ecm.add(entity, Star(0))
    ecm.add(entity, RenderPriority(0))
    ecm.add(entity, randomStarImage())
    ecm.add(entity, randomPositionInBox(box))
    ecm.add(entity, Velocity(x: 0.0, y: spaceshipMaxVelocityY))    

proc getAboveScreenBox(fb: Framebuffer, doubleHeight = false): Box =
    result.pos.x = 0.0
    result.dims.x = fb.width.float
    result.pos.y = -fb.height.float * (if doubleHeight: 2 else: 1)
    result.dims.y = fb.height.float * (if doubleHeight: 2 else: 1)

proc respawner(ecm: var EntityComponentManager, fb: Framebuffer) =
    var removeQueue: seq[Entity]
    for entity in ecm.iter(Position):
        doAssert ecm.has(entity)
        if ecm.get(entity, Position).y.int > fb.height:
            doAssert ecm.has(entity)
            removeQueue.add entity
    
    let spawnBox = fb.getAboveScreenBox()
    while removeQueue.len > 0:
        let entity = removeQueue.pop()
        doAssert ecm.has(entity)
        if ecm.has(entity, Asteroid):
            ecm.addAsteroid(spawnBox)
        if ecm.has(entity, Star):
            ecm.addStar(spawnBox)
        ecm.remove(entity)

proc game() =
    var
        ecm: EntityComponentManager
        fb = newFramebuffer(transparentRune)
        inputCatcher: InputCatcher

    let quitChars = ['q', 27.char]
    inputCatcher.start(quitChars)

    const numAsteroid = 20
    const numStars = 150

    for i in 1..numAsteroid:
        ecm.addAsteroid(fb.getAboveScreenBox(doubleHeight = true))
    for i in 1..numStars:
        ecm.addStar(fb.getAboveScreenBox(doubleHeight = true))

    var last = now()
    while true:
        let delta = now() - last
        last = now()
        ecm.physicsStep(delta)
        ecm.respawner(fb)
        ecm.renderStep(fb)

        for input in inputCatcher.get():
            if input in quitChars:
                return
            case input:
            # of ' ':
            #     fb.clear()
            #     for x in 0..<fb.width:
            #         for y in 0..<fb.height:
            #             if rand(1.0) < 0.01:
            #                 fb.add(randomStarImage().data, x, y)

            #     fb.add(randomAsteroidImage().data, x = 20, y = 30)
            #     fb.add(spaceshipImg.data, x = 50, y = 10)
            #     fb.add(bulletImg.data, x = 50, y = 5)
            else:
                discard

        
        # fb.add(getBulletExhaust(), x = 50, y = 6)
        # fb.print()
        


randomize()
game()