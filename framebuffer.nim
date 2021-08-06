import
    terminal,
    unicode

func toRune*(s: string): Rune =
    doAssert s.runeLen == 1
    s.runeAt(0)

type
    Framebuffer* = object
        buffer: seq[seq[Rune]]
        width, height: int
        transparentRune: Rune

func width*(framebuffer: Framebuffer): int = framebuffer.width
func height*(framebuffer: Framebuffer): int = framebuffer.height

func clear*(framebuffer: var Framebuffer, fillWith = " ".toRune) =
    for line in framebuffer.buffer.mitems:
        for rune in line.mitems:
            rune = fillWith

proc newFramebuffer*(transparentRune = "\0".toRune): Framebuffer =
    result.transparentRune = transparentRune
    result.height = terminalHeight()
    result.width = terminalWidth()
    result.buffer.setLen(result.height)
    for line in result.buffer.mitems:
        line.setLen(result.width)
    result.clear()        

proc print*(framebuffer: Framebuffer) =
    hideCursor()
    setCursorPos(0, 0)
    doAssert framebuffer.buffer.len == terminalHeight()
    doAssert framebuffer.buffer.len == framebuffer.height
    for index, line in framebuffer.buffer.pairs:
        doAssert line.len == terminalWidth()
        doAssert line.len == framebuffer.width
        setCursorXPos(0)
        stdout.write($line)
        if index < framebuffer.buffer.len - 1:
            stdout.write("\n")
    stdout.flushFile()
    showCursor()

func add*(framebuffer: var Framebuffer, image: openArray[seq[Rune]], x, y: int) =
    doAssert y + image.len <= framebuffer.height
    for yOffset, line in image.pairs:
        doAssert x + line.len <= framebuffer.width
        for xOffset, rune in line.pairs:
            if rune != framebuffer.transparentRune:
                framebuffer.buffer[y + yOffset][x + xOffset] = image[yOffset][xOffset]

func add*(framebuffer: var Framebuffer, image: seq[Rune] or Rune, x, y: int) =
    framebuffer.add(@[image], x, y)