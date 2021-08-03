import
    terminal,
    unicode

const asteroidMiddleTemplates = [
    [
        "OOOOOOO".toRunes,
        "OOOOOOO".toRunes
    ],
    [
        "OOOOOOO".toRunes,
        "OOOOOO🪟".toRunes
    ],
    [
        "OOOOOOO".toRunes,
        "🪟OOOOOO".toRunes
    ],
    [
        "OOOOOOO".toRunes,
        "🪟OOOOO🪟".toRunes
    ],
    [
        "OOOOOO🪟".toRunes,
        "🪟OOOOOO".toRunes
    ],
    [
        "🪟OOOOOO".toRunes,
        "OOOOOO🪟".toRunes
    ],
    [
        "OOOOOO🪟".toRunes,
        "OOOOOOO".toRunes
    ],
    [
        "🪟OOOOOO".toRunes,
        "OOOOOOO".toRunes
    ],
    [
        "🪟OOOOO🪟".toRunes,
        "OOOOOOO".toRunes
    ]
]

const asteroidTopTemplates = [
    "🪟OOOOO🪟".toRunes,
    "🪟🪟OOOO🪟".toRunes,
    "🪟OOOO🪟🪟".toRunes,
    "🪟🪟🪟OOO🪟".toRunes,
    "🪟🪟OOO🪟🪟".toRunes,
    "¸OOO🪟🪟🪟".toRunes
]

func toRune(s: string): Rune =
    doAssert s.runeLen == 1
    s.runeAt(0)

type
    Vec2 = object
        x, y: float
    Framebuffer = object
        buffer: seq[seq[Rune]]
        width, height: int

const transparentRune = "🪟".toRune

func clear(framebuffer: var Framebuffer, fillWith = " ".toRune) =
    for line in framebuffer.buffer.mitems:
        for rune in line.mitems:
            rune = fillWith

proc newFramebuffer(): Framebuffer =
    result.height = terminalHeight()
    result.width = terminalWidth()
    result.buffer.setLen(result.height)
    for line in result.buffer.mitems:
        line.setLen(result.width)
    result.clear()        

proc print(framebuffer: Framebuffer) =
    setCursorPos(0, 0)
    doAssert framebuffer.buffer.len == terminalHeight()
    doAssert framebuffer.buffer.len == framebuffer.height
    for index, line in framebuffer.buffer.pairs:
        doAssert line.len == terminalWidth()
        doAssert line.len == framebuffer.width
        stdout.write($line)
        if index < framebuffer.buffer.len - 1:
            stdout.write("\n")
    stdout.flushFile()

func add(framebuffer: var Framebuffer, image: openArray[seq[Rune]], pos: Vec2) =
    doAssert pos.y.int + image.len <= framebuffer.height
    for yOffset, line in image.pairs:
        doAssert pos.x.int + line.len <= framebuffer.width
        for xOffset, rune in line.pairs:
            if rune != transparentRune:
                framebuffer.buffer[pos.y.int + yOffset][pos.x.int + xOffset] = image[yOffset][xOffset]

func add(framebuffer: var Framebuffer, image: seq[Rune] or Rune, pos: Vec2) =
    framebuffer.add(@[image], pos)

type Asteroid = object
    image: array[4, seq[Rune]]

# discard getch()
# discard getch()
# discard getch()
# discard getch()
var framebuffer = newFramebuffer()
framebuffer.clear(fillWith = ".".toRune)

framebuffer.add(asteroidMiddleTemplates[3], Vec2(x: 20.0, y: 30.0))
framebuffer.add("1".toRune, Vec2(x: 20.0, y: 30.0))
framebuffer.print()
discard getch()


type ComponentManager = object
    components[T]: seq[T]