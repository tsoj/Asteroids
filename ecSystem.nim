import macros
import macrocache
import strutils
import typetraits

#----------------------------------------------#

const nextTypeId = CacheCounter("nextTypeId")

type TypeId = int

# number of components is limited, as the bit mask is only 64 bit big
const maxNumComponentTypes = 63
const entityBit = 0b1

func typeId*(T:typedesc): TypeId =
    const id = nextTypeId.value
    static:
        doAssert id < maxNumComponentTypes, "Maximum number of different component types is " & $maxNumComponentTypes
        inc nextTypeId
    id

func bitTypeId(T: typedesc): uint64 =
    let bitID {.global.} = (0b10'u64 shl typeId(T).uint64)
    {.cast(noSideEffect).}:
        bitID


func bitTypeIdUnion(Ts: tuple): uint64 =
    {.cast(noSideEffect).}:
        let bitId {.global.} = block:
            var b: uint64 = 0
            for T in Ts.fields:
                b = b or bitTypeId(typeof T)
            b
        assert (bitId and entityBit) == 0
        bitId

# template bitTypeId(Ts: untyped): uint64 =
#     var ts: Ts
#     bitTypeIdInternal(ts)

#----------------------------------------------#

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

#----------------------------------------------#

type Entity = int
type EntityComponentManager = object
    componentVectors: ComponentVectors
    hasMask: seq[uint64]
    numComponents: array[maxNumComponentTypes, int]
    componentTypeToEntity: array[maxNumComponentTypes, seq[Entity]]
    unusedEntities: seq[Entity]

func has(ecm: EntityComponentManager, entity: Entity): bool =
    if entity < ecm.hasMask.len:
        return (ecm.hasMask[entity] and entityBit) != 0
    false

func has(ecm: EntityComponentManager, entity: Entity, ComponentTypes: tuple): bool =
    if ecm.has(entity):
        let bitId = bitTypeIdUnion(ComponentTypes)
        return (ecm.hasMask[entity] and bitId) == bitId
    false

template has(ecm: EntityComponentManager, entity: Entity, ComponentTypes: untyped): bool =
    var test: ComponentTypes
    when test is tuple:
        var t: ComponentTypes
    else:
        var t: (ComponentTypes,)
    ecm.has(entity, t)

func createEntity(ecm: var EntityComponentManager): Entity =
    if ecm.unusedEntities.len > 0:
        result = ecm.unusedEntities.pop()
        assert ecm.hasMask[result] == 0
        ecm.hasMask[result] = entityBit
    else:
        result = ecm.hasMask.len
        ecm.hasMask.add(entityBit)
    assert result < ecm.hasMask.len
    assert ecm.hasMask[result] == entityBit

func remove(ecm: var EntityComponentManager, entity: Entity) =
    if not ecm.has(entity):
        raise newException(KeyError, "Entity cannot be removed: Entity " & $entity & " does not exist.")
    ecm.hasMask[entity] = 0
    ecm.unusedEntities.add(entity)

func create[T](ecm: var EntityComponentManager, entity: Entity, component: T) =
    if not ecm.has(entity):
        raise newException(KeyError, "Component cannot be added to entity: Entity " & $entity & " does not exist.")
    if ecm.has(entity, T):
        raise newException(KeyError, "Component cannot be added to entity: Entity " & $entity & " already has component " & $T & ".")
    var componentVector = ecm.componentVectors.get(T)
    if componentVector.len <= entity:
        componentVector.setLen(entity + 1)
    ecm.hasMask[entity] = ecm.hasMask[entity] or bitTypeId(T)



#----------------------------------------------#


var ecm: EntityComponentManager

let entity1 = ecm.createEntity()


echo ecm.has(34, (float, int, string))
echo ecm.has(34, float)
echo ecm.has(34, string)




# var c: ComponentVectors
# c.get(float).add(0.5)
# c.get(int).add(1234)
# c.get(float).add(0.6)
# echo c.get(float)
# echo c.get(int)
# echo c.get(int8)
# type A = (int, float)
# let a: uint64 = bitTypeId((float,))
# echo toBin(a.int64, 64)