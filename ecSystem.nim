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
        var bitId {.global.}: uint64
        once:
            bitId = 0
            for T in Ts.fields:
                bitId = bitId or bitTypeId(typeof T)
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
# TODO: describe all the eigenartiges behaviour of this:
# - rare and big objects should be passed as refs to the entity component manager, otherwiese alot of space will be wasted
# - Components of type tuple may not work. Better use proper objects
# TODO: add logging
# TODO: fix slow performance(?)
type Entity* = int
type EntityComponentManager* = object
    componentVectors: ComponentVectors
    hasMask: seq[uint64]
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
    componentVector[entity] = component

    ecm.hasMask[entity] = ecm.hasMask[entity] or bitTypeId(T)
    
    # sorting entities, such that while iterating over them we always have the smaller first and bigger last
    template typeToEntity: auto = ecm.componentTypeToEntity[typeId(T)]
    if typeToEntity.len == 0:
        typeToEntity.add entity
    else:
        for i in countdown(typeToEntity.high, typeToEntity.low):
            assert typeToEntity[i] != entity
            if typeToEntity[i] < entity:
                typeToEntity.insert(entity, i + 1)
                break

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

    template typeToEntity: auto = ecm.componentTypeToEntity[typeId(T)]
    let index =typeToEntity.find(entity)
    if index != -1:
        typeToEntity.delete(index)

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
        if min > ecm.componentTypeToEntity[id].len:
            min = ecm.componentTypeToEntity[id].len
            result = id

iterator iterInternal*(ecm: EntityComponentManager, ComponentTypes: tuple): Entity =
    let rarestComponent = ecm.getRarestComponent(ComponentTypes)
    for entity in ecm.componentTypeToEntity[rarestComponent]:
        if ecm.hasInternal(entity, ComponentTypes):
            yield entity

template iter*(ecm: EntityComponentManager, ComponentTypes: varargs[untyped]): auto =
    ecm.iterInternal((new (ComponentTypes,))[])

iterator iterAll*(ecm: EntityComponentManager): Entity =
    for entity, hasMask in ecm.hasMask.pairs:
        if ecm.has(entity):
            yield entity

# usage example:
# forEach(ecm, a: ComponentA, b: var ComponentB, c: ComponentC):
#     echo a
#     b.x = c.y
macro forEach*(args: varargs[untyped]): untyped =
    args.expectMinLen 3
    args[0].expectKind nnkIdent
    args[^1].expectKind nnkStmtList

    let ecmVarIdent = args[0]
    var paramsIdentDefs = @[newEmptyNode()]
    var typeIdents: seq[NimNode]
    for n in args[1..^2]:
        n.expectKind nnkExprColonExpr
        paramsIdentDefs.add newIdentDefs(n[0], n[1])

        if n[1].kind == nnkVarTy:
            typeIdents.add n[1][0]
        else:
            typeIdents.add n[1]

    let bodyProcIdent = ident("bodyProc")        
    let forLoopEntity = ident("entity")

    var bodyProcCall = newCall(bodyProcIdent)
    for t in typeIdents:
        bodyProcCall.add newCall(ident("get"), ecmVarIdent, forLoopEntity, t)
    
    newStmtList(
        newBlockStmt(
            newStmtList(
                newProc(
                    name = bodyProcIdent,
                    body = args[^1],
                    params = paramsIdentDefs
                ),
                newNimNode(nnkForStmt).add([
                    forLoopEntity,
                    newCall(ident("iter"), ecmVarIdent).add typeIdents,
                    newStmtList(bodyProcCall)
                ])
            )
        )
    )


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

let entity6 = ecm.addEntity()
ecm.add(entity6, int(6))
ecm.add(entity6, float(6.0))

for entity in ecm.iter(float, string):
    echo entity

forEach(ecm, f: var float, s: string):
    echo s
    f = 10.0

forEach(ecm, f: float):
    echo f

forEach(ecm, f: var float, s: string):
    echo s
    f = 10.0


ecm.remove(entity4)

let entity7 = ecm.addEntity()
let entity8 = ecm.addEntity()
ecm.remove(entity7)

for entity in ecm.iterAll():
    echo entity