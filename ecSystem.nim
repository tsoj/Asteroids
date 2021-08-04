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
# TODO: check if componentTypeToEntity can replace numComponents
# TODO: describe all the eigenartiges behaviour of this:
# - rare and big objects should be passed as refs to the entity component manager, otherwiese alot of space will be wasted
# - Components of type tuple may not work. Better use proper objects
type Entity* = int
type EntityComponentManager* = object
    componentVectors: ComponentVectors
    hasMask: seq[uint64]
    numComponents: array[maxNumComponentTypes, int]
    componentTypeToEntity: array[maxNumComponentTypes, seq[Entity]]
    unusedEntities: seq[Entity]

func has*(ecm: EntityComponentManager, entity: Entity): bool =
    if entity < ecm.hasMask.len:
        return (ecm.hasMask[entity] and entityBit) != 0
    false

func hasInternal*(ecm: EntityComponentManager, entity: Entity, ComponentTypes: tuple): bool =
    if ecm.has(entity):
        let bitId = bitTypeIdUnion(ComponentTypes)
        return (ecm.hasMask[entity] and bitId) == bitId
    false

template has*(ecm: EntityComponentManager, entity: Entity, ComponentTypes: untyped): bool =
    var test: ComponentTypes
    when test is tuple:
        var t: ComponentTypes
    else:
        var t: (ComponentTypes,)
    ecm.hasInternal(entity, t)

func addEntity*(ecm: var EntityComponentManager): Entity =
    if ecm.unusedEntities.len > 0:
        result = ecm.unusedEntities.pop()
        assert ecm.hasMask[result] == 0
        ecm.hasMask[result] = entityBit
    else:
        result = ecm.hasMask.len
        ecm.hasMask.add(entityBit)
    assert result < ecm.hasMask.len
    assert ecm.hasMask[result] == entityBit

func remove*(ecm: var EntityComponentManager, entity: Entity) =
    if not ecm.has(entity):
        raise newException(KeyError, "Entity cannot be removed: Entity " & $entity & " does not exist.")
    ecm.hasMask[entity] = 0
    ecm.unusedEntities.add(entity)

func add*[T](ecm: var EntityComponentManager, entity: Entity, component: T) =
    if not ecm.has(entity):
        raise newException(
            KeyError,
            "Component cannot be added to entity: Entity " & $entity & " does not exist."
        )
    if ecm.has(entity, T):
        raise newException(
            KeyError,
            "Component cannot be added to entity: Entity " & $entity & " already has component " & $T & "."
        )
    
    template componentVector: auto = ecm.componentVectors.get(T)
    if componentVector.len <= entity:
        componentVector.setLen(entity + 1)
    ecm.hasMask[entity] = ecm.hasMask[entity] or bitTypeId(T)
    componentVector[entity] = component
    ecm.numComponents[typeId(T)] += 1
    ecm.componentTypeToEntity[typeId(T)].add(entity)

func remove*(ecm: var EntityComponentManager, entity: Entity, T: typedesc) =
    if not ecm.has(entity):
        raise newException(
            KeyError,
            "Component cannot be removed from entity: Entity " & $entity & " does not exist."
        )
    if not ecm.has(entity, T):
        raise newException(
            KeyError,
            "Component cannot be remove from entity: Entity " & $entity & " does not have component " & $T & "."
        )
    
    ecm.hasMask[entity] = ecm.hasMask[entity] and not bitTypeId(T)
    ecm.numComponents[typeId(T)] -= 1
    let index = ecm.componentTypeToEntity[typeId(T)].find(entity)
    if index != -1:
        ecm.componentTypeToEntity[typeId(T)].delete(index)

template getTemplate(ecm: EntityComponentManager or var EntityComponentManager, entity: Entity, T: typedesc): auto =
    if not ecm.has(entity):
        raise newException(
            KeyError,
            "Component cannot be accessed: Entity " & $entity & " does not exist."
        )
    if not ecm.has(entity, T):
        raise newException(
            KeyError,
            "Component cannot be accessed: Entity " & $entity & " does not have component " & $T & "."
        )
    template componentVector: auto = ecm.componentVectors.get(T)
    assert componentVector.len > entity
    componentVector[entity]

func get*[T](ecm: var EntityComponentManager, entity: Entity, desc: typedesc[T]): var T =
    ecm.getTemplate(entity, T)
func get*(ecm: EntityComponentManager, entity: Entity, T: typedesc): T =
    ecm.getTemplate(entity, T)

func getRarestComponent(ecm: EntityComponentManager, ComponentTypes: tuple): TypeId =
    var min = int.high
    for T in ComponentTypes.fields:
        let id = typeId(typeof T)
        if min > ecm.numComponents[id]:
            min = ecm.numComponents[id]
            result = id

iterator iterInternal*(ecm: EntityComponentManager, ComponentTypes: tuple): Entity =
    let rarestComponent = ecm.getRarestComponent(ComponentTypes)
    for entity in ecm.componentTypeToEntity[rarestComponent]:
        if ecm.hasInternal(entity, ComponentTypes):
            yield entity

template iter*(ecm: EntityComponentManager, ComponentTypes: varargs[untyped]): auto =
    ecm.iterInternal((new (ComponentTypes,))[])

#----------------------------------------------#


var ecm: EntityComponentManager

let entity1 = ecm.addEntity()
ecm.add(entity1, float(0.5))
ecm.add(entity1, int(2))

echo ecm.has(entity1, (float, int, string))
echo ecm.has(entity1, string)
echo ecm.has(entity1, float)
echo ecm.has(entity1, (float, int))
ecm.remove(entity1, int)
echo ecm.has(entity1, (float, int))
echo ecm.get(entity1, float)
ecm.get(entity1, float) = 0.6
echo ecm.get(entity1, float)

proc stuff(ecm: EntityComponentManager, entity: Entity) =
    echo ecm.get(entity, float)

ecm.stuff(entity1)


ecm.add(entity1, string("hello :D"))


let entity2 = ecm.addEntity()
ecm.add(entity2, string("hello 2"))
ecm.add(entity2, float(2.0))

let entity3 = ecm.addEntity()
ecm.add(entity3, string("hello 3"))
ecm.add(entity3, int(3))

let entity4 = ecm.addEntity()
ecm.add(entity4, float(4.0))
ecm.add(entity4, int(4))
ecm.add(entity4, string("hello 4"))
ecm.remove(entity4, float)

let entity5 = ecm.addEntity()
ecm.add(entity5, string("hello 5"))
ecm.add(entity5, float(5.0))

for entity in ecm.iter(float, string):
    echo entity

echo ecm


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