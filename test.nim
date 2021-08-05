import ecSystem
import macros
#import nimprof

type
    ComponentA = object
        i: int
    ComponentB = object
        f: float
    ComponentC = object
        c: array[10000, char]
    ComponentS = object
        l: int
    ComponentD = object
        u: uint64
    ComponentE = object
        u: uint64
    ComponentF = object
        u: uint64
    ComponentG = object
        u: uint64
    ComponentH = object
        u: uint64
    ComponentI = object
        u: uint64
    ComponentJ = object
        u: uint64
    ComponentK = object
        u: uint64

func newComponentC(): ComponentC =
    discard

proc test(): bool =

    for numberEntities in [0, 1, 2, 3, 4, 10, 25, 60, 150, 400, 1_000, 2_000, 5_000, 10_000, 50_000, 100_000]:
        var ecm: EntityComponentManager
        for i in 1..numberEntities:
            discard ecm.addEntity()
        
        for entity in ecm.iterAll():
            if (entity mod 7) == 0:
                ecm.remove(entity)
                if (entity mod 4) != 0:
                    discard ecm.addEntity()
        
        for entity in ecm.iterAll():
            if (entity mod 1) == 0:
                ecm.add(entity, ComponentS(l: 5))

                ecm.add(entity, ComponentA(i: "Hello".len))
                ecm.get(entity, ComponentA).i = entity
                doAssert ecm.get(entity, ComponentA).i == entity

                if (entity mod 3) == 1:
                    ecm.remove(entity, ComponentA)
                    ecm.add(entity, ComponentA(i: "Hello".len))
                    ecm.get(entity, ComponentA).i = entity
                    doAssert ecm.get(entity, ComponentA).i == entity

                if (entity mod 5) == 2:
                    doAssert ecm.has(entity, ComponentA)
                    ecm.get(entity, ComponentA).i = entity
                    doAssert ecm.get(entity, ComponentA).i == entity

            if (entity mod 2) == 0:
                ecm.add(entity, ComponentB(f: 0.0))
                ecm.get(entity, ComponentB).f = entity.float /  numberEntities.float
            
            if (entity mod 5) == 0:
                ecm.add(entity, newComponentC())
                ecm.get(entity, ComponentC).c[0] = cast[char](entity)

        var removeLater: seq[Entity]
        for entity in ecm.iter(ComponentC):
            if (entity mod 3) == 0:
                removeLater.add(entity)
        for entity in removeLater:
            ecm.remove(entity, ComponentC)        
        for entity in ecm.iter(ComponentC):
            if (entity mod 3) == 0:
                if (entity mod 4) != 0:
                    ecm.add(entity, newComponentC())
                    ecm.get(entity, ComponentC).c[0] = cast[char](entity)

        for entity in ecm.iter(ComponentA):
            doAssert ecm.get(entity, ComponentA).i == entity
        
        for entity in ecm.iter(ComponentA):
            if (entity mod (numberEntities div 5 + 1)) == 0:
                for entity2 in ecm.iter(ComponentA):
                    if entity2 > entity:
                        doAssert entity2 != entity
                        ecm.get(entity2, ComponentA).i += 1
        

        var firstEntity = Entity.high
        for entity in ecm.iter(ComponentA):
            if firstEntity == Entity.high:
                firstEntity = entity
            var addition = 0
            for i in firstEntity..<entity:
                if (i mod (numberEntities div 5 + 1)) == 0 and ecm.has(i, ComponentA):
                    addition += 1
            doAssert entity + addition == ecm.get(entity, ComponentA).i

        # TODO: replace stuff1 and stuff3 with forEach

        forEach(ecm, a: ComponentA, b: ComponentB, s: var ComponentS):
            s.l = (a.i + 1) * (19 + a.i) * (if b.f < 0.999: 1 else: 2)

        proc stuff2(ecm: EntityComponentManager) =
            forEach(ecm, a: ComponentA, b: ComponentB, s: ComponentS):
                doAssert s.l == (a.i + 1) * (19 + a.i) * (if b.f < 0.999: 1 else: 2)
        stuff2(ecm)

        for entity in ecm.iter(ComponentA, ComponentB, ComponentS):
            doAssert(
                ecm.get(entity, ComponentS).l ==
                (ecm.get(entity, ComponentA).i + 1) * (19 + ecm.get(entity, ComponentA).i) *
                (if ecm.get(entity, ComponentB).f < 0.999: 1 else: 2)
            )
    true     

doAssert test()



var ecm: EntityComponentManager

forEach(ecm, a: ComponentA, b: ComponentB, s: var ComponentS):
    echo "Hello"

dumpTree:
    forEachMacroM(ecm, a: ComponentA, b: ComponentB, s: var ComponentS):
        echo a
        s = 0

# dumpTree:
#     block:
#         proc stuff(a: ComponentA, b: ComponentB, s: var ComponentS) =
#             echo a
#             s = 0
#         for entity in iter(ecm, ComponentA, ComponentB, ComponentS):
#             stuff(
#                 get(ecm, entity, ComponentA),
#                 get(ecm, entity, ComponentB),
#                 get(ecm, entity, ComponentS)
#             )
