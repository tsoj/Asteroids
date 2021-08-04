
proc olli(T: typedesc): var T =
    var t: ref T = new T
    var t1 = addr t
    t1[][]

olli(float) = 0.5

proc olli(T: typedesc): T =
    var t: ref T = new T
    var t1 = addr t
    t1[][]

echo olli(float)

proc olli[T](): var T =
    var t: ref T = new T
    var t1 = addr t
    t1[][]

olli[float]() = 0.5