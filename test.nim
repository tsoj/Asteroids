import ecSystem
import macros
import times
import math

type
    ComponentA = object
        i: int
    ComponentB = object
        f: float
    ComponentC = ref object
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
    result = new ComponentC
    # discard

proc test() =

    for numberEntities in [0, 1, 2, 3, 4, 10, 25, 60, 150, 400, 1_000, 2_000, 5_000, 10_000]:#, 50_000, 100_000]:
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

proc benchmark(numEntities = 1_000_000) =
    block:
        var ecm: EntityComponentManager
        block:
            let start = now()
            for i in 0..<numEntities:
                discard ecm.addEntity()
            echo(
                "Create ", numEntities, " entities: ",
                (now() - start).inMicroseconds.float / 1000_000.0, "s"
            )
        block:
            let start = now()
            for i in 0..<numEntities:
                ecm.remove(i)
            echo(
                "Remove ", numEntities, " entities: ",
                (now() - start).inMicroseconds.float / 1000_000.0, "s"
            )
        block:
            for i in 0..<numEntities:
                let entity = ecm.addEntity()
                ecm.add(entity, ComponentA(i: 5))
                ecm.get(entity, ComponentA).i = 50
            let start = now()
            for entity in ecm.iter(ComponentA):
                doAssert ecm.get(entity, ComponentA).i == 50
            echo(
                "Iterating over ", numEntities, " entities, one component: ",
                (now() - start).inMicroseconds.float / 1000_000.0, "s"
            )
    block:
        var ecm: EntityComponentManager
        for i in 0..<numEntities:
            let entity = ecm.addEntity()
            ecm.add(entity, ComponentA(i: 5))
            ecm.get(entity, ComponentA).i = 50
            ecm.add(entity, ComponentB(f: 1.0))
            ecm.get(entity, ComponentB).f = 60.0
        let start = now()
        for entity in ecm.iter(ComponentA, ComponentB):
            doAssert ecm.get(entity, ComponentA).i == 50
            doAssert ecm.get(entity, ComponentB).f == 60.0
        echo(
            "Iterating over ", numEntities, " entities, two components: ",
            (now() - start).inMicroseconds.float / 1000_000.0, "s"
        )
    block:
        var ecm: EntityComponentManager
        for i in 0..<numEntities:
            let entity = ecm.addEntity()
            ecm.add(entity, ComponentA(i: 5))
            ecm.get(entity, ComponentA).i = 50
            if (i mod 2) == 0:
                ecm.add(entity, ComponentB(f: 1.0))
                ecm.get(entity, ComponentB).f = 60.0
        let start = now()
        for entity in ecm.iter(ComponentA, ComponentB):
            doAssert ecm.get(entity, ComponentA).i == 50
            doAssert ecm.get(entity, ComponentB).f == 60.0
        echo(
            "Iterating over ", numEntities, " entities, two components, half of the entities have all the components: ",
            (now() - start).inMicroseconds.float / 1000_000.0, "s"
        )    
    block:
        var ecm: EntityComponentManager
        for i in 0..<numEntities:
            let entity = ecm.addEntity()
            ecm.add(entity, ComponentA(i: 5))
            ecm.get(entity, ComponentA).i = 50
            if i == numEntities div 2:
                ecm.add(entity, ComponentB(f: 1.0))
                ecm.get(entity, ComponentB).f = 60.0
        let start = now()
        for entity in ecm.iter(ComponentA, ComponentB):
            doAssert ecm.get(entity, ComponentA).i == 50
            doAssert ecm.get(entity, ComponentB).f == 60.0
        echo(
            "Iterating over ", numEntities, " entities, two components, only one entity has all the components: ",
            (now() - start).inMicroseconds.float / 1000_000.0, "s"
        )
    block:
        var ecm: EntityComponentManager
        for i in 0..<numEntities:
            let entity = ecm.addEntity()
            ecm.add(entity, ComponentA(i: 5))
            ecm.add(entity, ComponentB(f: 1.0))
            ecm.add(entity, ComponentD(u: 0))
            ecm.add(entity, ComponentE(u: 2))
            ecm.add(entity, ComponentF(u: 1))

            ecm.get(entity, ComponentA).i = 50
            ecm.get(entity, ComponentB).f = 60.0
            ecm.get(entity, ComponentD).u = 100
            ecm.get(entity, ComponentE).u = 101
            ecm.get(entity, ComponentF).u = 102
        let start = now()
        for entity in ecm.iter(ComponentA, ComponentB, ComponentD, ComponentE, ComponentF):
            doAssert ecm.get(entity, ComponentA).i == 50
            doAssert ecm.get(entity, ComponentB).f == 60.0
            doAssert ecm.get(entity, ComponentD).u == 100
            doAssert ecm.get(entity, ComponentE).u == 101
            doAssert ecm.get(entity, ComponentF).u == 102
        echo(
            "Iterating over ", numEntities, " entities, five components: ",
            (now() - start).inMicroseconds.float / 1000_000.0, "s"
        )
    block:
        var ecm: EntityComponentManager
        for i in 0..<numEntities:
            let entity = ecm.addEntity()
            ecm.add(entity, ComponentA(i: 5))
            ecm.add(entity, ComponentB(f: 1.0))
            ecm.add(entity, ComponentD(u: 0))
            ecm.add(entity, ComponentE(u: 1))
            ecm.add(entity, ComponentF(u: 2))
            ecm.add(entity, ComponentG(u: 3))
            ecm.add(entity, ComponentH(u: 4))
            ecm.add(entity, ComponentI(u: 5))
            ecm.add(entity, ComponentJ(u: 6))
            ecm.add(entity, ComponentK(u: 7))

            ecm.get(entity, ComponentA).i = 50
            ecm.get(entity, ComponentB).f = 60.0
            ecm.get(entity, ComponentD).u = 100
            ecm.get(entity, ComponentE).u = 101
            ecm.get(entity, ComponentF).u = 102
            ecm.get(entity, ComponentG).u = 103
            ecm.get(entity, ComponentH).u = 104
            ecm.get(entity, ComponentI).u = 105
            ecm.get(entity, ComponentJ).u = 106
            ecm.get(entity, ComponentK).u = 107
        let start = now()
        for entity in ecm.iter(
            ComponentA,
            ComponentB,
            ComponentD,
            ComponentE,
            ComponentF,
            ComponentG,
            ComponentH,
            ComponentI,
            ComponentJ,
            ComponentK
        ):
            doAssert ecm.get(entity, ComponentA).i == 50
            doAssert ecm.get(entity, ComponentB).f == 60.0
            doAssert ecm.get(entity, ComponentD).u == 100
            doAssert ecm.get(entity, ComponentE).u == 101
            doAssert ecm.get(entity, ComponentF).u == 102
            doAssert ecm.get(entity, ComponentG).u == 103
            doAssert ecm.get(entity, ComponentH).u == 104
            doAssert ecm.get(entity, ComponentI).u == 105
            doAssert ecm.get(entity, ComponentJ).u == 106
            doAssert ecm.get(entity, ComponentK).u == 107
        echo(
            "Iterating over ", numEntities, " entities, ten components: ",
            (now() - start).inMicroseconds.float / 1000_000.0, "s"
        )    
    block:
        var ecm: EntityComponentManager
        for i in 0..<numEntities:
            let entity = ecm.addEntity()
            ecm.add(entity, ComponentA(i: 5))
            ecm.add(entity, ComponentB(f: 1.0))
            ecm.add(entity, ComponentD(u: 0))
            ecm.add(entity, ComponentE(u: 1))
            ecm.add(entity, ComponentF(u: 2))
            ecm.add(entity, ComponentG(u: 3))
            ecm.add(entity, ComponentH(u: 4))
            ecm.add(entity, ComponentI(u: 5))
            ecm.add(entity, ComponentJ(u: 6))

            ecm.get(entity, ComponentA).i = 50
            ecm.get(entity, ComponentB).f = 60.0
            ecm.get(entity, ComponentD).u = 100
            ecm.get(entity, ComponentE).u = 101
            ecm.get(entity, ComponentF).u = 102
            ecm.get(entity, ComponentG).u = 103
            ecm.get(entity, ComponentH).u = 104
            ecm.get(entity, ComponentI).u = 105
            ecm.get(entity, ComponentJ).u = 106

            if (i mod 2) == 0:
                ecm.add(entity, ComponentK(u: 7))
                ecm.get(entity, ComponentK).u = 107
        let start = now()
        for entity in ecm.iter(
            ComponentA,
            ComponentB,
            ComponentD,
            ComponentE,
            ComponentF,
            ComponentG,
            ComponentH,
            ComponentI,
            ComponentJ,
            ComponentK
        ):
            doAssert ecm.get(entity, ComponentA).i == 50
            doAssert ecm.get(entity, ComponentB).f == 60.0
            doAssert ecm.get(entity, ComponentD).u == 100
            doAssert ecm.get(entity, ComponentE).u == 101
            doAssert ecm.get(entity, ComponentF).u == 102
            doAssert ecm.get(entity, ComponentG).u == 103
            doAssert ecm.get(entity, ComponentH).u == 104
            doAssert ecm.get(entity, ComponentI).u == 105
            doAssert ecm.get(entity, ComponentJ).u == 106
            doAssert ecm.get(entity, ComponentK).u == 107
        echo(
            "Iterating over ", numEntities, " entities, ten components, half of the entities have all the components: ",
            (now() - start).inMicroseconds.float / 1000_000.0, "s"
        )
    block:
        var ecm: EntityComponentManager
        for i in 0..<numEntities:
            let entity = ecm.addEntity()
            ecm.add(entity, ComponentA(i: 5))
            ecm.add(entity, ComponentB(f: 1.0))
            ecm.add(entity, ComponentD(u: 0))
            ecm.add(entity, ComponentE(u: 1))
            ecm.add(entity, ComponentF(u: 2))
            ecm.add(entity, ComponentG(u: 3))
            ecm.add(entity, ComponentH(u: 4))
            ecm.add(entity, ComponentI(u: 5))
            ecm.add(entity, ComponentJ(u: 6))

            ecm.get(entity, ComponentA).i = 50
            ecm.get(entity, ComponentB).f = 60.0
            ecm.get(entity, ComponentD).u = 100
            ecm.get(entity, ComponentE).u = 101
            ecm.get(entity, ComponentF).u = 102
            ecm.get(entity, ComponentG).u = 103
            ecm.get(entity, ComponentH).u = 104
            ecm.get(entity, ComponentI).u = 105
            ecm.get(entity, ComponentJ).u = 106

            if i == numEntities div 2:
                ecm.add(entity, ComponentK(u: 7))
                ecm.get(entity, ComponentK).u = 107
        let start = now()
        for entity in ecm.iter(
            ComponentA,
            ComponentB,
            ComponentD,
            ComponentE,
            ComponentF,
            ComponentG,
            ComponentH,
            ComponentI,
            ComponentJ,
            ComponentK
        ):
            doAssert ecm.get(entity, ComponentA).i == 50
            doAssert ecm.get(entity, ComponentB).f == 60.0
            doAssert ecm.get(entity, ComponentD).u == 100
            doAssert ecm.get(entity, ComponentE).u == 101
            doAssert ecm.get(entity, ComponentF).u == 102
            doAssert ecm.get(entity, ComponentG).u == 103
            doAssert ecm.get(entity, ComponentH).u == 104
            doAssert ecm.get(entity, ComponentI).u == 105
            doAssert ecm.get(entity, ComponentJ).u == 106
            doAssert ecm.get(entity, ComponentK).u == 107
        echo(
            "Iterating over ", numEntities, " entities, ten components, only one entity has all the components: ",
            (now() - start).inMicroseconds.float / 1000_000.0, "s"
        )

type
    Position = object
        x,y: float
    Mass = object
        m: float
    TimeBomb = ref object
        t: int

proc newTimeBomb(): TimeBomb =
    result = new TimeBomb
    result.t = 1
    echo "Activated timebomb ..."

proc demo() =
    var ecm: EntityComponentManager
    let
        entity0 = ecm.addEntity()
        entity1 = ecm.addEntity()
        entity2 = ecm.addEntity()
        entity3 = ecm.addEntity()

    ecm.add(entity0, Position(x: 10.0, y: 20.0))
    ecm.add(entity1, Position(x: 5.5, y: 90.5))
    ecm.add(entity2, Position(x: 30.0, y: 15.0))
    ecm.add(entity3, Position(x: 8.0, y: 18.0))

    ecm.add(entity0, Mass(m: 40_000_000.0))
    ecm.add(entity1, Mass(m: 2_000_000.0))
    ecm.add(entity3, Mass(m: 800_000.0))

    ecm.add(entity0, newTimeBomb())

    forEach(ecm, p: Position, m: var Mass):
        if p.x + p.y < 27.5: # this is only true for entity3
            doAssert m.m == ecm.get(entity3, Mass).m
            m.m *= 1000.0

    for entityA in ecm.iter(Position, Mass):
        for entityB in ecm.iter(Position, Mass):
            if entityA < entityB:
                let
                    dx = ecm.get(entityB, Position).x - ecm.get(entityA,Position).x
                    dy = ecm.get(entityB, Position).y - ecm.get(entityA,Position).y
                    distanceSquared = dx^2 + dy^2
                let F = 6.67259e-11 * ((ecm.get(entityB, Mass).m * ecm.get(entityA, Mass).m) / distanceSquared)
                echo "Force between entity ", entityA, " and ", entityB, ": ", F
    
    for entity in ecm.iterAll():
        if ecm.has(entity, TimeBomb):
            ecm.remove(entity)
            echo "Entity ", entity, " exploded."

                    
    
    


demo()
#benchmark()
#test()


            


