import
    framebuffer,
    inputCatcher,
    ecSystem,
    unicode,
    terminal,
    random,
    os,
    times,
    strformat,
    options

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
    BulletMagazine = object
        last: DateTime
        refillTime: Duration
        magazine: int
        capacity: int
    Bullet = object
        whoShot: Entity
    RenderPriority = -1..2
    Exhaust = object
        offsets: seq[(int, int)]
    Timer = object
        activation: DateTime
        duration: Duration
    Dust = object
        chancePerSec: float

const transparentRune = "`".toRune

const dustRune = "·".toRune

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
const bulletExhaust = Exhaust(offsets: @[(0,1)])

const spaceshipMaxVelocityY = 15.0
const spaceshipMaxVelocityX = 20.0

proc getExhaust(): Rune =
    const possibleRunes = [
        "*".toRune,
        "^".toRune,
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
        right = min(xA + imgA.width - 1, xB + imgB.width - 1)
        top = max(yA, yB)
        bottom = min(yA + imgA.height - 1, yB + imgB.height - 1)
    
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
                if rand(1.0) < 0.3:
                    rune = "o".toRune
                elif rand(1.0) < 0.2:
                    rune = "0".toRune


proc starImage(): Image =
    result.data = @[".".toRunes]
    if rand(1.0) < 0.05:
        result.data[0] = "✦".toRunes

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

proc drawStep(ecm: EntityComponentManager, fb: var Framebuffer) =
    fb.clear()
    let fbPtr = addr fb
    for renderPriority in RenderPriority.low..RenderPriority.high:
        forEach(ecm, p: Position, img: Image, rp: RenderPriority):
            if rp == renderPriority:
                fbPtr[].add(img.data, x = p.x.int, y = p.y.int)
        forEach(ecm, p: Position, exhaust: Exhaust, rp: RenderPriority):
            if rp == renderPriority:
                for (xOffset, yOffset) in exhaust.offsets:
                    fbPtr[].add(getExhaust(), x = p.x.int + xOffset, y = p.y.int + yOffset)

proc addAsteroid(ecm: var EntityComponentManager, box: Box) =
    let entity = ecm.addEntity()
    ecm.add(entity, Asteroid(0))
    ecm.add(entity, RenderPriority(1))
    ecm.add(entity, randomAsteroidImage())
    var box = box
    box.dims.x -= ecm.get(entity, Image).width.float
    box.dims.y -= ecm.get(entity, Image).height.float
    ecm.add(entity, randomPositionInBox(box))
    ecm.add(entity, Velocity(x: rand(-7.0..7.0), y: rand(10.0..15.0)))

proc addStar(ecm: var EntityComponentManager, box: Box) =
    let entity = ecm.addEntity()
    ecm.add(entity, Star(0))
    ecm.add(entity, RenderPriority(0))
    ecm.add(entity, starImage())
    ecm.add(entity, randomPositionInBox(box))
    ecm.add(entity, Velocity(x: 0.0, y: spaceshipMaxVelocityY))    

proc getScreenBox(fb: Framebuffer): Box =
    result.pos.x = 0.0
    result.dims.x = fb.width.float
    result.pos.y = 0.0
    result.dims.y = fb.height.float

proc getAboveScreenBox(fb: Framebuffer, doubleHeight = false): Box =
    result = fb.getScreenBox
    result.pos.y = -fb.height.float * (if doubleHeight: 2 else: 1)
    if doubleHeight:
        result.dims.y *= 2.0

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

proc limitPlayer(ecm: var EntityComponentManager, fb: Framebuffer) =
    let fbHeight = fb.height
    let fbWidth = fb.width
    forEach(ecm, player: Player, p: var Position, img: Image):
        p.x = clamp(
            p.x,
            0.0,
            (fbWidth - img.width).float
        )
        p.y = clamp(
            p.y,
            0.0,
            (fbHeight - img.height).float
        )

proc addBullet(ecm: var EntityComponentManager, spaceshipPos: Position, spaceshipImg: Image, whoShot: Entity) =
    let entity = ecm.addEntity()
    ecm.add(entity, Bullet(whoShot: whoShot))
    ecm.add(entity, RenderPriority(1))
    ecm.add(entity, bulletImg)
    ecm.add(entity, bulletExhaust)
    ecm.add(entity, Velocity(x: 0.0, y: -20.0))
    ecm.add(entity, Position(
        x: spaceshipPos.x + spaceshipImg.width.float / 2.0,
        y: spaceshipPos.y
    ))
    ecm.add(entity, Timer(
        activation: now(),
        duration: initDuration(seconds = 10)
    ))

proc addPlayer(ecm: var EntityComponentManager, fb: Framebuffer): Entity =
    result = ecm.addEntity()
    ecm.add(result, Player(score: 0))
    ecm.add(result, RenderPriority(2))
    ecm.add(result, spaceshipImg)
    ecm.add(result, Position(x: (fb.width div 2).float, y: (fb.height div 2).float))
    ecm.add(result, Velocity(x: 0.0, y: 0.0))
    ecm.add(result, BulletMagazine(
        last: now(),
        magazine: 5,
        refillTime: initDuration(seconds = 1),
        capacity: 5
    ))

proc refillBulletMagazin(ecm: var EntityComponentManager) =
    forEach(ecm, bulletMagazine: var BulletMagazine):
        if now() - bulletMagazine.last > bulletMagazine.refillTime:
            bulletMagazine.magazine = min(bulletMagazine.capacity, bulletMagazine.magazine + 1)
            bulletMagazine.last = now()

proc getInfoImage(score, bulletMagazin, bulletMagazineCapacity: int, ): Image =
    doAssert bulletMagazin <= bulletMagazineCapacity
    var infoString = "Score: " & fmt"{score:>4}" & "┃"
    for i in 0..<bulletMagazin:
        infoString &= "▲"
    for i in bulletMagazin..<bulletMagazineCapacity:
        infoString &= "△"
    infoString &= "┃"
    let line1 = infoString.toRunes
    var line2 = line1
    line2[^1] = "┛".toRune
    for i, rune in line2.mpairs:
        if i == line2.len - 1:
            continue
        if rune == "┃".toRune:
            rune = "┻".toRune
        else:
            rune = "━".toRune
    Image(data: @[line1, line2])

proc removeTimers(ecm: var EntityComponentManager) =
    var removeQueue: seq[Entity]
    for entity in ecm.iter(Timer):
        if now() - ecm.get(entity, Timer).activation > ecm.get(entity, Timer).duration:
            removeQueue.add entity
    while removeQueue.len > 0:
        ecm.remove(removeQueue.pop())

proc collidingWithAsteroids(ecm: EntityComponentManager, entity: Entity): Option[Entity] =
    if ecm.has(entity, (Image, Position)):
        for asteroidEntity in ecm.iter(Asteroid, Image, Position):
            if areColliding(
                posA = ecm.get(entity, Position),
                imgA = ecm.get(entity, Image),
                posB = ecm.get(asteroidEntity, Position),
                imgB = ecm.get(asteroidEntity, Image)
            ):
                return some(asteroidEntity)
    none(Entity)

proc bulletHits(ecm: var EntityComponentManager, fb: Framebuffer) =
    var removeQueue: seq[Entity]
    for entity in ecm.iter(Bullet, Image, Position):
        let collidingAsteroid = ecm.collidingWithAsteroids(entity)
        if collidingAsteroid.isSome:
            let whoShot = ecm.get(entity, Bullet).whoShot
            doAssert ecm.has(whoShot, Player)
            ecm.get(whoShot, Player).score += 1
            removeQueue.add entity
            removeQueue.add collidingAsteroid.get()
    while removeQueue.len > 0:
        let entity = removeQueue.pop()
        if ecm.has(entity, Asteroid):
            ecm.addAsteroid(fb.getAboveScreenBox())

            ecm.remove(entity, Asteroid)
            for line in ecm.get(entity, Image).data.mitems:
                for rune in line.mitems:
                    if rune != transparentRune:
                        rune = dustRune
            ecm.add(entity, Timer(
                activation: now(),
                duration: initDuration(seconds = 2)
            ))
            ecm.add(entity, Dust(chancePerSec: 0.9))
            if ecm.has(entity, RenderPriority):
                ecm.get(entity, RenderPriority) = RenderPriority(-1)
        else:
            ecm.remove(entity)

proc processDust(ecm: var EntityComponentManager, delta: Duration) =
    let deltaS = delta.inMicroseconds.float / 1_000_000.0
    forEach(ecm, dust: Dust, img: var Image):
        for line in img.data.mitems:
            for rune in line.mitems:
                if rune == dustRune and dust.chancePerSec * deltaS > rand(1.0):
                    rune = transparentRune

proc game() =
    var
        ecm: EntityComponentManager
        fb = newFramebuffer(transparentRune)
        inputCatcher: InputCatcher

    let quitChars = ['q', 27.char]
    inputCatcher.start(quitChars)

    let numAsteroid = (fb.width * fb.height) div 250
    let numStars = (fb.width * fb.height) div 50

    for i in 1..numAsteroid:
        ecm.addAsteroid(fb.getAboveScreenBox(doubleHeight = true))
    for i in 1..(numStars div 2):
        ecm.addStar(fb.getScreenBox())
        ecm.addStar(fb.getAboveScreenBox())

    let playerEntity = ecm.addPlayer(fb)

    var gameRunning = true

    var last = now()
    var lastNewAsteroid = now()
    let newAsteroidDuration = initDuration(seconds = 60000 div (fb.width * fb.height))
    while true:

        ecm.drawStep(fb)
        fb.add(getInfoImage(
            ecm.get(playerEntity, Player).score,
            ecm.get(playerEntity, BulletMagazine).magazine,
            ecm.get(playerEntity, BulletMagazine).capacity
        ).data, x = 0, y = 0)
        fb.print()


        # Don't waste CPU cycles if we don't notice a difference anyway
        while now() - last < initDuration(milliseconds = 10):
            sleep(1)
        let delta = now() - last
        last = now()
        ecm.physicsStep(delta)
        ecm.limitPlayer(fb)
        ecm.respawner(fb)
        ecm.refillBulletMagazin()
        ecm.removeTimers()
        ecm.bulletHits(fb)
        ecm.processDust(delta)

        if now() - lastNewAsteroid > newAsteroidDuration:
            lastNewAsteroid = now()
            ecm.addAsteroid(fb.getAboveScreenBox())

        

        for input in inputCatcher.get():
            if input in quitChars:
                return
            case input:
            of 'a', 'd':
                ecm.get(playerEntity, Velocity) = Velocity(
                    x: spaceshipMaxVelocityX * (if input == 'a': -1 else: 1),
                    y: 0.0
                )
            of 's', 'w':
                ecm.get(playerEntity, Velocity) = Velocity(
                    x: 0.0,
                    y: spaceshipMaxVelocityY * (if input == 'w': -1 else: 1)
                )
            of ' ':
                if ecm.get(playerEntity, BulletMagazine).magazine > 0:
                    ecm.addBullet(ecm.get(playerEntity, Position), ecm.get(playerEntity, Image), playerEntity)
                    ecm.get(playerEntity, BulletMagazine).magazine -= 1
            else:
                discard
        


randomize()
game()