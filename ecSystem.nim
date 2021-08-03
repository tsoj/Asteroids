import macros
import macrocache
import strutils


const nextTypeId = CacheCounter("nextTypeId")

type TypeId = int

func typeId*(T:typedesc): TypeId =
    const id = nextTypeId.value
    static:
        inc nextTypeId
    id

func bitTypeIdInternal(Ts: tuple): uint64 =
    {.cast(noSideEffect).}:
        let bitId {.global.} = block:
            var b: uint64 = 0
            for T in Ts.fields:
                debugEcho $(typeof T)
                b = b or (0b10'u64 shl typeId(typeof T).uint64)
            b
        bitId
template bitTypeId(Ts: untyped): uint64 =
    var ts: Ts
    bitTypeIdInternal(ts)


type ComponentVectors = seq[ref seq[int8]]

func get(componentVectors: var ComponentVectors, T: typedesc): var seq[T] =
    static: doAssert (ref seq[int8]).default == nil
    let id = typeId(T)
    if componentVectors.len <= id:
        componentVectors.setLen(id + 1)
    if componentVectors[id] == nil:
        componentVectors[id] = new seq[int8]
    #debugEcho $T , ": id: ", id, ", addr: ", cast[uint64](componentVectors[id])
    assert componentVectors[id] != nil
    cast[ref seq[T]](componentVectors[id])[]

func get(componentVectors: ComponentVectors, T: typedesc): seq[T] =
    let id = typeId(T)
    if componentVectors.len > id and componentVectors[id] != nil:
        return cast[ref seq[T]](componentVectors[id])[]


type ComponentManager = object





var c: ComponentVectors
c.get(float).add(0.5)
c.get(int).add(1234)
c.get(float).add(0.6)
echo c.get(float)
echo c.get(int)
echo c.get(int8)
# type A = (int, float)
let a: uint64 = bitTypeId((float,))
echo toBin(a.int64, 64)