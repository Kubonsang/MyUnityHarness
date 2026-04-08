/task-start MAP-01
Bash Run testplay environment check
IN
testplay check

OUT
{
  "project_path": "/Users/gubonsang/Desktop/Dev/GNF_",
  "ready": true,
  "schema_version": "1",
  "unity_path": "/Applications/Unity/Hub/Editor/6000.3.8f1/Unity.app/Contents/MacOS/Unity"
}
Edit feature_list.json
Modified
system-architect에게 설계도 작성을 위임합니다.

Agent:Architect MAP-01 blueprint
IN
현재 태스크 MAP-01의 요구사항과 코드베이스를 분석해서, docs/blueprints/MAP-01_blueprint.md 파일에 구현 설계도를 작성해줘.

## 태스크 MAP-01 요구사항
던전 레이아웃 생성기 — 룸 랜덤 산포 + Delaunay Triangulation 연결 그래프. 연속 2D 공간에 룸을 최소 간격(룸 크기+복도 길이)으로 랜덤 배치한 뒤, Delaunay 삼각분할로 연결 후보를 구하고 MST+α 엣지를 선택하여 StartRoom→ExitRoom 경로가 보장되는 복도 그래프를 생성한다. 기존 WFC 그리드 레이아웃을 대체한다.

## 배경
- 기존 시스템: 5×5 그리드 기반 WFC. 룸이 다닥다닥 붙어있어 문 열면 바로 문이 보임
- 사용자 요구: 룸 사이에 실제 복도 공간 확보. Delaunay Triangulation으로 자연스러운 연결
- 룸 내부 장식은 기존 WFC/RoomPreset 시스템 재활용 (MAP-03에서 연동)
- 복도 지오메트리 생성은 MAP-02에서 처리

## MAP-01 스코프 (이것만 구현)
1. 2D 공간에 룸을 최소 간격으로 랜덤 배치하는 알고리즘
2. Bowyer-Watson Delaunay Triangulation 구현
3. MST(Kruskal/Prim) + 일부 추가 엣지 선택
4. StartRoom → ExitRoom BFS 경로 보장 검증
5. DungeonLayoutGenerator.cs 새 파일로 작성 (기존 WFCGenerator.cs는 수정하지 않음)

## 분석 대상 파일
- Assets/Scripts/Map/WFC/WFCGenerator.cs — 기존 시스템 구조 참고
- Assets/Scripts/Map/WFC/Tile.cs — TileType, RoomFlavor enum 재사용
- Assets/Scripts/Map/WFC/RoomStateManager.cs — 방 점유 시스템 참고
- docs/blueprints/WFC.md — 현재 블루프린트 (방 개수/비율 등)

## 설계도에 반드시 포함할 항목
1. 새 파일/클래스 목록 및 위치
2. 핵심 데이터 구조 (RoomNode, CorridorEdge 등)
3. 알고리즘 의사코드 (배치, Delaunay, MST, 엣지 선택)
4. public 필드 (Inspector 노출: 룸 수, 최소 간격, 맵 크기 등)
5. 기존 시스템과의 관계 (WFCGenerator는 건드리지 않음, 새 시스템 병존)
6. 검증 방법
Read WFC.md
Globpattern: "Assets/Scripts/Map/**/*.cs"
Found 6 files
Bash List existing blueprints directory
IN
ls /Users/gubonsang/Desktop/Dev/GNF_/docs/blueprints/

OUT
COMBAT.md
ITEM.md
MONSTER.md
NET.md
PLAYER.md
ROLE.md
SKILL.md
STATUS.md
WEAPON.md
WFC.md
Read WFCPrefabBuilder.cs
Write MAP-01_blueprint.md
717 lines
설계도 작성 완료. 읽어서 구현에 착수합니다.

Read MAP-01_blueprint.md
Read MAP-01_blueprint.md (lines 1-120)
Read MAP-01_blueprint.md (lines 121-240)
Read MAP-01_blueprint.md (lines 241-360)
Read MAP-01_blueprint.md (lines 361-460)
Read MAP-01_blueprint.md
Bash List Map directory structure
IN
ls /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/

OUT
WFC
WFC.meta
Read MAP-01_blueprint.md (lines 2-121)
Read MAP-01_blueprint.md (lines 122-241)
Read MAP-01_blueprint.md (lines 242-361)
Read MAP-01_blueprint.md (lines 362-481)
Read MAP-01_blueprint.md (lines 482-581)
Grep "public enum (TileType|RoomFlavor|ObjectiveType)" (in /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map)
35 lines of output
Read MAP-01_blueprint.md (lines 582-681)
Good. I have all the blueprint details. Let me now create the 3 files.

Bash Create Dungeon directory
IN
mkdir -p /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/Dungeon

OUT
(Bash completed with no output)
Update Todos

Create DungeonLayoutData.cs (RoomNode, CorridorEdge, DungeonLayout)

Create DelaunayTriangulation.cs (Bowyer-Watson static class)

Create DungeonLayoutGenerator.cs (MonoBehaviour orchestrator)

Delegate to QA agent for testing

Delegate to tech-writer agent for documentation

Finalize task (done + archive)
Write DungeonLayoutData.cs
49 lines
Update Todos

Create DungeonLayoutData.cs (RoomNode, CorridorEdge, DungeonLayout)

Create DelaunayTriangulation.cs (Bowyer-Watson static class)

Create DungeonLayoutGenerator.cs (MonoBehaviour orchestrator)

Delegate to QA agent for testing

Delegate to tech-writer agent for documentation

Finalize task (done + archive)
Write DelaunayTriangulation.cs
175 lines
Update Todos

Create DungeonLayoutData.cs (RoomNode, CorridorEdge, DungeonLayout)

Create DelaunayTriangulation.cs (Bowyer-Watson static class)

Create DungeonLayoutGenerator.cs (MonoBehaviour orchestrator)

Delegate to QA agent for testing

Delegate to tech-writer agent for documentation

Finalize task (done + archive)
Write DungeonLayoutGenerator.cs
573 lines
Update Todos

Create DungeonLayoutData.cs (RoomNode, CorridorEdge, DungeonLayout)

Create DelaunayTriangulation.cs (Bowyer-Watson static class)

Create DungeonLayoutGenerator.cs (MonoBehaviour orchestrator)

Delegate to QA agent for testing

Delegate to tech-writer agent for documentation

Finalize task (done + archive)
코어 로직 3파일 작성 완료. QA 에이전트에게 테스트 파이프라인을 위임합니다.

Agent:QA testing for MAP-01
IN
방금 MAP-01 태스크의 코어 로직이 구현되었습니다. 3개의 새 파일이 생성되었습니다:

1. `Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs` — RoomNode, CorridorEdge, DungeonLayout 데이터 클래스
2. `Assets/Scripts/Map/Dungeon/DelaunayTriangulation.cs` — Bowyer-Watson 알고리즘 static 클래스
3. `Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs` — MonoBehaviour 오케스트레이터 (4 Phase: PlaceRooms → Delaunay → MST+extra → BFS validation)

이 코드들은 기존 Tile.cs의 TileType, RoomFlavor enum을 재사용합니다.

다음 4단계를 수행해 주세요:

1. `Assets/Tests/PlayMode` 경로에 반드시 `MAP01_Tests.cs`라는 새 파일을 만들어 테스트 코드를 작성할 것 (기존 파일 수정 절대 금지). 테스트 항목:
   - DelaunayTriangulation: 3점/4점/14점 삼각분할 시 올바른 엣지 수 생성
   - DungeonLayoutGenerator: BakeLayout() 호출 시 null이 아닌 결과 반환
   - BakeLayout 결과의 StartRoom/ExitRoom 존재 확인
   - 모든 룸 간 최소 간격(corridorMinLength) 보장 확인
   - BFS 연결성: StartRoom→ExitRoom 경로 존재
   - SpecialRoom 최소 1개 존재
   - Delaunay/MST/corridor 로그 포맷 확인

2. 코어 어셈블리를 참조할 수 있게 Tests.asmdef 파일을 업데이트할 것.

3. `testplay run --shadow --filter MAP01_Tests`를 실행할 것.

4. 에러가 나면 통과할 때까지 스스로 다 고치고, 최종 성공하면 요약해서 보고해.
Bash List Map/Dungeon and Tests/PlayMode directories
IN
ls /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/Dungeon/ 2>/dev/null && ls /Users/gubonsang/Desktop/Dev/GNF_/Assets/Tests/PlayMode/ 2>/dev/null

OUT
DelaunayTriangulation.cs
DungeonLayoutData.cs
DungeonLayoutGenerator.cs
FIX01_Tests.cs
FIX01_Tests.cs.meta
FIX02_Tests.cs
FIX02_Tests.cs.meta
Status01StunRegressionTests.cs
Status01StunRegressionTests.cs.meta
Status03DebuffTests.cs
Status03DebuffTests.cs.meta
WFC08_Tests.cs
WFC08_Tests.cs.meta
[result-id: r1]
Read DungeonLayoutGenerator.cs
Bash Find asmdef files in Tests directory
IN
find /Users/gubonsang/Desktop/Dev/GNF_/Assets/Tests -name "*.asmdef" 2>/dev/null

OUT
/Users/gubonsang/Desktop/Dev/GNF_/Assets/Tests/GNF.Tests.PlayMode.asmdef
Bash Find asmdef files in Scripts directory
IN
find /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts -name "*.asmdef" 2>/dev/null

OUT
/Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/GNF.Runtime.asmdef
Bash Check Map/Dungeon directory contents
IN
ls /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/Dungeon/

OUT
DelaunayTriangulation.cs
DungeonLayoutData.cs
DungeonLayoutGenerator.cs
Bash Find files defining TileType enum
IN
grep -r "TileType" /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts --include="*.cs" -l 2>/dev/null | head -5

OUT
/Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/WFC/RoomPreset.cs
/Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/WFC/Tile.cs
/Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/WFC/WFCGenerator.cs
/Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs
/Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs
[result-id: r8]
Bash Find TileType and RoomFlavor enum definitions
IN
grep -n "enum TileType\|enum RoomFlavor" /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/WFC/Tile.cs

OUT
3:public enum TileType { Air, Corridor, NormalRoom, SpecialRoom, StartRoom, ObjectiveRoom, ExitRoom }
5:public enum RoomFlavor
Bash List available testplay tests
IN
cd /Users/gubonsang/Desktop/Dev/GNF_ && testplay list 2>/dev/null | head -40

OUT
{
  "schema_version": "1",
  "tests": [
    "Status01StunRegressionTests.Player_Stun_BlocksAttack_OnHostAndServerRpcPaths",
    "Status01StunRegressionTests.Monster_Stun_ClearsPath_And_StopsNavMeshAgent",
    "Status03DebuffTests.Wound_ReducesHealBy40Percent",
    "Status03DebuffTests.Burn_BlocksHealCompletely",
    "Status03DebuffTests.Fatigue_AmplifiesIncomingDamageBy25Percent",
    "Status03DebuffTests.Poison_DealsDotDamagePerStackPerTick",
    "BurstCompatibleSkipShaderVariants.CompatibilityTests",
    "UseCustomAllocator_Works",
    "UseCustomAllocatorHandle_Works",
    "CustomAllocatorHandle_MultiThreadWorks",
    "UseRewindableAllocator_Works",
    "BitField32_Get_Set",
    "BitField32_Count_Leading_Trailing",
    "BitField32_Throws",
    "BitField64_Get_Set",
    "BitField64_Throws",
    "BitField64_Count_Leading_Trailing",
    "AllocatesOneBitFromLong",
    "FailsToAllocateOneBitFromLong",
    "AllocatesMultipleBitsFromLong",
    "FailsToAllocateMultipleBitsFromLong",
    "FreesOneBitFromLong",
    "FreesMultipleBitsFromLong",
    "AllocatesOneBitFromArray",
    "AllocatesMultipleBitsFromArray",
    "FreesOneBitFromArray",
    "FreesMultipleBitsFromArray",
    "AllocatesFromJob",
    "AllocatorVersioningWorks",
    "ReleasingChildHandlesWorks",
    "ReleasingChildAllocatorsWorks",
    "AllocatesAndFreesFromMono",
    "AllocatesAndFreesFromBurst",
    "UserDefinedAllocatorWorks",
    "StackAllocatorWorks",
    "CustomAllocatorNativeListWorksWithoutHandles",
    "CustomAllocatorNativeListThrowsWhenAllocatorIsWrong",
[result-id: r9]
Bash Read the PlayMode asmdef
IN
cat /Users/gubonsang/Desktop/Dev/GNF_/Assets/Tests/GNF.Tests.PlayMode.asmdef

OUT
{
    "name": "GNF.Tests.PlayMode",
    "rootNamespace": "",
    "references": [
        "Unity.Netcode.Runtime",
        "GNF.Runtime",
        "Unity.AI.Navigation"
    ],
    "editorAssemblyReferences": [
        "UnityEditor.TestRunner"
    ],
    "includePlatforms": [],
    "excludePlatforms": [],
    "allowUnsafeCode": false,
    "overrideReferences": false,
    "precompiledReferences": [],
    "autoReferenced": false,
    "defineConstraints": [],
    "versionDefines": [],
    "noEngineReferences": false,
    "optionalUnityReferences": [
        "TestAssemblies"
    ]
}
[result-id: r10]
Bash Write MAP01_Tests.cs test file
IN
cat > /Users/gubonsang/Desktop/Dev/GNF_/Assets/Tests/PlayMode/MAP01_Tests.cs << 'CSEOF'
using System.Collections;
using System.Collections.Generic;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

/// <summary>
/// MAP-01 PlayMode 테스트.
/// Delaunay 삼각분할 및 DungeonLayoutGenerator 핵심 불변 조건을 검증한다.
/// 1. DelaunayTriangulation: 3점/4점/14점 삼각분할 시 올바른 엣지 수 생성
/// 2. DungeonLayoutGenerator: BakeLayout() 호출 시 null이 아닌 결과 반환
/// 3. BakeLayout 결과의 StartRoom/ExitRoom 존재 확인
/// 4. 모든 룸 간 최소 간격(corridorMinLength) 보장 확인
/// 5. BFS 연결성: StartRoom → ExitRoom 경로 존재
/// 6. SpecialRoom 최소 1개 존재
/// 7. Delaunay/MST/corridor 로그 포맷 확인
/// </summary>
public class MAP01_Tests
{
    private readonly List<GameObject> _created = new List<GameObject>();

    [TearDown]
    public void TearDown()
    {
        foreach (var go in _created)
            if (go != null) Object.DestroyImmediate(go);
        _created.Clear();
    }

    private DungeonLayoutGenerator CreateGenerator(
        int roomCount = 10,
        float mapX = 300f,
        float mapY = 300f,
        float corridorMinLength = 12f)
    {
        var go = new GameObject("[MAP_Test_Generator]");
        _created.Add(go);

        var gen = go.AddComponent<DungeonLayoutGenerator>();
        gen.mapSize            = new Vector2(mapX, mapY);
        gen.roomCount          = roomCount;
        gen.corridorMinLength  = corridorMinLength;
        gen.maxNormalRoom      = 5;
        gen.maxObjectiveRoom   = 2;
        gen.maxSpecialRoom     = 2;
        gen.maxStartRoom       = 1;
        gen.maxExitRoom        = 1;
        gen.largeRoomSize      = new Vector2(40f, 40f);
        gen.smallRoomSize      = new Vector2(24f, 24f);
        gen.extraEdgeRatio     = 0.15f;
        gen.maxPlacementAttempts = 30;
        gen.maxRetries         = 50;
        gen.generateOnStart    = false;
        gen.drawGizmos         = false;

        return gen;
    }

    // ─────────────────────────────────────────────────────────────
    //  TEST 1-A: Delaunay — 3점 삼각분할
    // ─────────────────────────────────────────────────────────────

    [Test]
    public void Delaunay_ThreePoints_ProducesExactlyThreeEdges()
    {
        // 3점으로 만들 수 있는 삼각형은 정확히 하나 → 엣지 3개
        var points = new Vector2[]
        {
            new Vector2(0f,   0f),
            new Vector2(10f,  0f),
            new Vector2(5f,  10f)
        };

        List<DelaunayTriangulation.Edge> edges = DelaunayTriangulation.Triangulate(points);

        Assert.AreEqual(3, edges.Count,
            $"3점 삼각분할은 정확히 3개의 엣지를 가져야 한다 (실제: {edges.Count})");
    }

    // ─────────────────────────────────────────────────────────────
    //  TEST 1-B: Delaunay — 4점 삼각분할
    // ─────────────────────────────────────────────────────────────

    [Test]
    public void Delaunay_FourPoints_ProducesExpectedEdgeRange()
    {
        // 볼록 사각형 4점: 삼각형 2개 → 엣지는 최소 5개 (2삼각형 × 3 - 1 공유) ~ 최대 6개
        var points = new Vector2[]
        {
            new Vector2(0f,   0f),
            new Vector2(10f,  0f),
            new Vector2(10f, 10f),
            new Vector2(0f,  10f)
        };

        List<DelaunayTriangulation.Edge> edges = DelaunayTriangulation.Triangulate(points);

        // 4점 볼록 다각형: Delaunay 삼각분할 결과는 5개의 고유 엣지 (삼각형 2개 × 3엣지 - 1공유 + 대각선)
        Assert.GreaterOrEqual(edges.Count, 5,
            $"4점 삼각분할은 최소 5개 이상의 엣지를 가져야 한다 (실제: {edges.Count})");
        Assert.LessOrEqual(edges.Count, 6,
            $"4점 삼각분할은 최대 6개 이하의 엣지를 가져야 한다 (실제: {edges.Count})");
    }

    // ─────────────────────────────────────────────────────────────
    //  TEST 1-C: Delaunay — 14점 삼각분할
    // ─────────────────────────────────────────────────────────────

    [Test]
    public void Delaunay_FourteenPoints_ProducesSufficientEdges()
    {
        // n개 점의 Delaunay 삼각분할: 엣지 수 ≥ n-1 (MST 최소 요건)
        // 볼록 껍질 안에 점이 있는 일반적 배치: 엣지 수 ~ 3n - 6
        var points = new Vector2[14];
        for (int i = 0; i < 14; i++)
        {
            float angle = i * Mathf.PI * 2f / 14f;
            // 두 레이어: 7점은 r=50, 7점은 r=100
            float r = (i % 2 == 0) ? 50f : 100f;
            points[i] = new Vector2(Mathf.Cos(angle) * r + 150f, Mathf.Sin(angle) * r + 150f);
        }

        List<DelaunayTriangulation.Edge> edges = DelaunayTriangulation.Triangulate(points);

        int n = points.Length;
        Assert.GreaterOrEqual(edges.Count, n - 1,
            $"14점 삼각분할은 최소 {n - 1}개 이상의 엣지를 가져야 한다 (실제: {edges.Count})");

        // 상한: Delaunay의 엣지 수 ≤ 3n - 6 = 36
        int upperBound = 3 * n - 6;
        Assert.LessOrEqual(edges.Count, upperBound,
            $"14점 삼각분할은 최대 {upperBound}개 이하의 엣지를 가져야 한다 (실제: {edges.Count})");
    }

    // ─────────────────────────────────────────────────────────────
    //  TEST 2: BakeLayout — null이 아닌 결과 반환
    // ─────────────────────────────────────────────────────────────

    [Test]
    public void BakeLayout_ReturnsNonNullLayout()
    {
        var gen = CreateGenerator();

        DungeonLayout layout = gen.BakeLayout();

        Assert.IsNotNull(layout,
            "BakeLayout()은 null을 반환하지 않아야 한다 (maxRetries 안에 생성 성공 필요)");
    }

    // ─────────────────────────────────────────────────────────────
    //  TEST 3: BakeLayout — StartRoom / ExitRoom 존재 확인
    // ─────────────────────────────────────────────────────────────

    [Test]
    public void BakeLayout_HasValidStartRoomAndExitRoom()
    {
        var gen = CreateGenerator();

        DungeonLayout layout = gen.BakeLayout();

        Assert.IsNotNull(layout, "레이아웃이 생성되어야 한다");
        Assert.GreaterOrEqual(layout.startRoomId, 0,
            "startRoomId가 유효한 인덱스여야 한다 (≥ 0)");
        Assert.GreaterOrEqual(layout.exitRoomId, 0,
            "exitRoomId가 유효한 인덱스여야 한다 (≥ 0)");

        Assert.Less(layout.startRoomId, layout.rooms.Count,
            "startRoomId가 rooms 범위 내에 있어야 한다");
        Assert.Less(layout.exitRoomId, layout.rooms.Count,
            "exitRoomId가 rooms 범위 내에 있어야 한다");

        Assert.AreEqual(TileType.StartRoom, layout.rooms[layout.startRoomId].tileType,
            "startRoomId가 가리키는 룸은 StartRoom이어야 한다");
        Assert.AreEqual(TileType.ExitRoom, layout.rooms[layout.exitRoomId].tileType,
            "exitRoomId가 가리키는 룸은 ExitRoom이어야 한다");
    }

    // ─────────────────────────────────────────────────────────────
    //  TEST 4: 룸 간 최소 간격 보장
    // ─────────────────────────────────────────────────────────────

    [Test]
    public void BakeLayout_AllRoomsRespectMinimumSpacing()
    {
        var gen = CreateGenerator(corridorMinLength: 12f);

        DungeonLayout layout = gen.BakeLayout();
        Assert.IsNotNull(layout, "레이아웃이 생성되어야 한다");

        List<RoomNode> rooms = layout.rooms;
        float minLen = gen.corridorMinLength;

        for (int i = 0; i < rooms.Count; i++)
        {
            for (int j = i + 1; j < rooms.Count; j++)
            {
                Vector2 halfA = rooms[i].size / 2f;
                Vector2 halfB = rooms[j].size / 2f;

                float dx = Mathf.Abs(rooms[i].center.x - rooms[j].center.x);
                float dy = Mathf.Abs(rooms[i].center.y - rooms[j].center.y);

                float requiredX = halfA.x + halfB.x + minLen;
                float requiredY = halfA.y + halfB.y + minLen;

                bool spacingOk = dx >= requiredX || dy >= requiredY;
                Assert.IsTrue(spacingOk,
                    $"Room {i}와 Room {j} 사이의 간격이 corridorMinLength({minLen}m)를 충족하지 않는다. " +
                    $"dx={dx:F1} (need {requiredX:F1}), dy={dy:F1} (need {requiredY:F1})");
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    //  TEST 5: BFS 연결성 — StartRoom → ExitRoom 경로 존재
    // ─────────────────────────────────────────────────────────────

    [Test]
    public void BakeLayout_BFS_StartRoomCanReachExitRoom()
    {
        var gen = CreateGenerator();

        DungeonLayout layout = gen.BakeLayout();
        Assert.IsNotNull(layout, "레이아웃이 생성되어야 한다");

        int n = layout.rooms.Count;
        var adj = new List<int>[n];
        for (int i = 0; i < n; i++)
            adj[i] = new List<int>();

        for (int i = 0; i < layout.corridors.Count; i++)
        {
            int a = layout.corridors[i].roomA;
            int b = layout.corridors[i].roomB;
            adj[a].Add(b);
            adj[b].Add(a);
        }

        var visited = new bool[n];
        var queue = new Queue<int>();
        queue.Enqueue(layout.startRoomId);
        visited[layout.startRoomId] = true;

        while (queue.Count > 0)
        {
            int cur = queue.Dequeue();
            for (int i = 0; i < adj[cur].Count; i++)
            {
                int next = adj[cur][i];
                if (!visited[next])
                {
                    visited[next] = true;
                    queue.Enqueue(next);
                }
            }
        }

        Assert.IsTrue(visited[layout.exitRoomId],
            "BFS 탐색 시 StartRoom에서 ExitRoom에 도달할 수 있어야 한다");
    }

    // ─────────────────────────────────────────────────────────────
    //  TEST 6: SpecialRoom 최소 1개 존재
    // ─────────────────────────────────────────────────────────────

    [Test]
    public void BakeLayout_HasAtLeastOneSpecialRoom()
    {
        var gen = CreateGenerator();

        DungeonLayout layout = gen.BakeLayout();
        Assert.IsNotNull(layout, "레이아웃이 생성되어야 한다");

        bool hasSpecial = false;
        for (int i = 0; i < layout.rooms.Count; i++)
        {
            if (layout.rooms[i].tileType == TileType.SpecialRoom)
            {
                hasSpecial = true;
                break;
            }
        }

        Assert.IsTrue(hasSpecial,
            "레이아웃에 SpecialRoom이 최소 1개 이상 존재해야 한다");
    }

    // ─────────────────────────────────────────────────────────────
    //  TEST 7: 로그 포맷 확인 — Delaunay/MST/corridor 키워드
    // ─────────────────────────────────────────────────────────────

    [Test]
    public void BakeLayout_LogsContainDelaunayMSTCorridorKeywords()
    {
        var gen = CreateGenerator();

        // UnityEngine.TestTools.LogAssert으로 [MAP] 접두사 로그 패턴 확인
        // BakeLayout 성공 시 다음 3종 로그가 반드시 출력됨:
        //   [MAP] Delaunay edges: X, MST edges: Y, final corridors: Z
        //   [MAP] Room placement: X rooms in WxH map
        //   [MAP] Layout generation SUCCESS (retry: X/Y)
        LogAssert.Expect(LogType.Log, new System.Text.RegularExpressions.Regex(@"\[MAP\] Delaunay edges:"));
        LogAssert.Expect(LogType.Log, new System.Text.RegularExpressions.Regex(@"\[MAP\] Room placement:"));
        LogAssert.Expect(LogType.Log, new System.Text.RegularExpressions.Regex(@"\[MAP\] Layout generation SUCCESS"));
        LogAssert.Expect(LogType.Log, new System.Text.RegularExpressions.Regex(@"\[MAP\] BFS validation:"));

        DungeonLayout layout = gen.BakeLayout();
        Assert.IsNotNull(layout, "레이아웃이 생성되어야 한다");
    }
}
CSEOF

OUT
(Bash completed with no output)
Bash Run MAP01_Tests with shadow flag
IN
cd /Users/gubonsang/Desktop/Dev/GNF_ && testplay run --shadow --filter MAP01_Tests 2>&1

OUT
Exit code 3
{
  "errors": [],
  "exit_code": 3,
  "failed": 1,
  "new_failures": null,
  "passed": 8,
  "run_id": "20260407-165103-1396ad6a",
  "schema_version": "1",
  "skipped": 0,
  "tests": [
    {
      "duration_s": 0.016735,
      "name": "MAP01_Tests.BakeLayout_AllRoomsRespectMinimumSpacing",
      "result": "Passed"
    },
    {
      "duration_s": 0.001527,
      "name": "MAP01_Tests.BakeLayout_BFS_StartRoomCanReachExitRoom",
      "result": "Passed"
    },
    {
      "duration_s": 0.001234,
      "name": "MAP01_Tests.BakeLayout_HasAtLeastOneSpecialRoom",
      "result": "Passed"
    },
    {
      "duration_s": 0.004306,
      "name": "MAP01_Tests.BakeLayout_HasValidStartRoomAndExitRoom",
      "result": "Passed"
    },
    {
      "duration_s": 0.002365,
      "message": "Expected log did not appear: [Log] Regex: /[MAP/] BFS validation:",
      "name": "MAP01_Tests.BakeLayout_LogsContainDelaunayMSTCorridorKeywords",
      "result": "Failed"
    },
    {
      "duration_s": 0.001319,
      "name": "MAP01_Tests.BakeLayout_ReturnsNonNullLayout",
      "result": "Passed"
    },
    {
      "duration_s": 0.000275,
      "name": "MAP01_Tests.Delaunay_FourPoints_ProducesExpectedEdgeRange",
      "result": "Passed"
    },
    {
      "duration_s": 0.000368,
      "name": "MAP01_Tests.Delaunay_FourteenPoints_ProducesSufficientEdges",
      "result": "Passed"
    },
    {
      "duration_s": 0.000339,
      "name": "MAP01_Tests.Delaunay_ThreePoints_ProducesExactlyThreeEdges",
      "result": "Passed"
    }
  ],
  "total": 9
}
Bash Check BFS validation log format in source
IN
grep -n "BFS validation" /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs

OUT
509:        Debug.Log($"[MAP] BFS validation: StartRoom({layout.startRoomId}) → ExitRoom({layout.exitRoomId}) path OK, all {n} rooms reachable");
Edit MAP01_Tests.cs
Edit failed
Read MAP01_Tests.cs (lines 246-275)
Read MAP01_Tests.cs (lines 296-335)
Edit MAP01_Tests.cs
Added 5 lines
Bash Run MAP01_Tests again after fix
IN
cd /Users/gubonsang/Desktop/Dev/GNF_ && testplay run --shadow --filter MAP01_Tests 2>&1

OUT
{
  "errors": [],
  "exit_code": 0,
  "failed": 0,
  "new_failures": null,
  "passed": 9,
  "run_id": "20260407-165335-a84cede3",
  "schema_version": "1",
  "skipped": 0,
  "tests": [
    {
      "duration_s": 0.016899,
      "name": "MAP01_Tests.BakeLayout_AllRoomsRespectMinimumSpacing",
      "result": "Passed"
    },
    {
      "duration_s": 0.002055,
      "name": "MAP01_Tests.BakeLayout_BFS_StartRoomCanReachExitRoom",
      "result": "Passed"
    },
    {
      "duration_s": 0.001245,
      "name": "MAP01_Tests.BakeLayout_HasAtLeastOneSpecialRoom",
      "result": "Passed"
    },
    {
      "duration_s": 0.00448,
      "name": "MAP01_Tests.BakeLayout_HasValidStartRoomAndExitRoom",
      "result": "Passed"
    },
    {
      "duration_s": 0.001864,
      "name": "MAP01_Tests.BakeLayout_LogsContainDelaunayMSTCorridorKeywords",
      "result": "Passed"
    },
    {
      "duration_s": 0.001198,
      "name": "MAP01_Tests.BakeLayout_ReturnsNonNullLayout",
      "result": "Passed"
    },
    {
      "duration_s": 0.000224,
      "name": "MAP01_Tests.Delaunay_FourPoints_ProducesExpectedEdgeRange",
      "result": "Passed"
    },
    {
      "duration_s": 0.000339,
      "name": "MAP01_Tests.Delaunay_FourteenPoints_ProducesSufficientEdges",
      "result": "Passed"
    },
    {
      "duration_s": 0.000328,
      "name": "MAP01_Tests.Delaunay_ThreePoints_ProducesExactlyThreeEdges",
      "result": "Passed"
    }
  ],
  "total": 9
}
[result-id: r13]
QA 통과 (9/9 PASS). 문서화 에이전트에게 위임합니다.

Update Todos

Create DungeonLayoutData.cs (RoomNode, CorridorEdge, DungeonLayout)

Create DelaunayTriangulation.cs (Bowyer-Watson static class)

Create DungeonLayoutGenerator.cs (MonoBehaviour orchestrator)

Delegate to QA agent for testing

Delegate to tech-writer agent for documentation

Finalize task (done + archive)
Agent:Documentation for MAP-01
IN
doc-section-normalize 스킬을 사용해서 방금 구현/테스트가 완료된 태스크(MAP-01)에 대한 공식 세션 문서를 docs/ 폴더에 작성하고 요약 보고해.

MAP-01 태스크 내용: 던전 레이아웃 생성기 — 룸 랜덤 산포 + Delaunay Triangulation 연결 그래프. 연속 2D 공간에 룸을 최소 간격(룸 크기+복도 길이)으로 랜덤 배치한 뒤, Delaunay 삼각분할로 연결 후보를 구하고 MST+α 엣지를 선택하여 StartRoom→ExitRoom 경로가 보장되는 복도 그래프를 생성한다.

변경된 파일:
- Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs (신규) — RoomNode, CorridorEdge, DungeonLayout 데이터 클래스
- Assets/Scripts/Map/Dungeon/DelaunayTriangulation.cs (신규) — Bowyer-Watson 알고리즘 static 클래스
- Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs (신규) — MonoBehaviour 오케스트레이터 (4 Phase)
- Assets/Tests/PlayMode/MAP01_Tests.cs (신규) — 9개 테스트

testplay 결과: Exit 0, 9/9 PASS (testplay run --shadow --filter MAP01_Tests)

검증 기준: 에디터에서 Bake 10회 실행 시 10/10 성공. (1) 모든 룸이 최소 간격 이상 떨어져 있고 (2) StartRoom→ExitRoom BFS 경로 존재 (3) Console에 '[MAP] Delaunay edges: N, MST edges: M, final corridors: K' 로그 출력

프로젝트 경로: /Users/gubonsang/Desktop/Dev/GNF_
docs/ 폴더에 기존 문서 번호 확인 후 다음 번호로 작성해야 합니다.
문서화 에이전트가 백그라운드에서 작업 중입니다. 완료되면 태스크 상태를 done으로 변경하고 feature_archive.json으로 이동하겠습니다.

Read feature_list.json
Read feature_archive.json
문서화 에이전트 완료 대기 중입니다. 완료되면 태스크를 마무리하겠습니다.

Update Todos

Create DungeonLayoutData.cs (RoomNode, CorridorEdge, DungeonLayout)

Create DelaunayTriangulation.cs (Bowyer-Watson static class)

Create DungeonLayoutGenerator.cs (MonoBehaviour orchestrator)

Delegate to QA agent for testing

Delegate to tech-writer agent for documentation

Finalize task (done + archive)
MAP-01 코어 로직 구현 완료. 현재 상태:

DungeonLayoutData.cs — RoomNode, CorridorEdge, DungeonLayout 데이터 클래스
DelaunayTriangulation.cs — Bowyer-Watson 2D Delaunay 삼각분할 (static)
DungeonLayoutGenerator.cs — 4-Phase 오케스트레이터 (PlaceRooms → Delaunay → MST+extra → BFS validation + Gizmo)
QA: 9/9 테스트 PASS (MAP01_Tests.cs)
문서화: 백그라운드 작업 중
문서화 완료. 태스크를 마무리합니다.

Update Todos

Create DungeonLayoutData.cs (RoomNode, CorridorEdge, DungeonLayout)

Create DelaunayTriangulation.cs (Bowyer-Watson static class)

Create DungeonLayoutGenerator.cs (MonoBehaviour orchestrator)

Delegate to QA agent for testing

Delegate to tech-writer agent for documentation

Finalize task (done + archive)
Read feature_list.json
MAP-01을 done으로 변경하고 feature_archive.json으로 이동합니다.

Edit feature_list.json
Removed 5 lines
Read feature_list.json
Good, feature_list.json is clean. Now add MAP-01 to feature_archive.json.

Read feature_archive.json (lines 431-440)
Edit feature_archive.json
Added 6 lines
이제 git-operator에게 커밋을 위임합니다.

Agent:Git commit for MAP-01
IN
현재 태스크 MAP-01과 관련된 모든 변경 사항(코드, 테스트, 문서)을 스테이징하고, 시스템 규격에 맞춰 커밋을 남긴 뒤 커밋 해시만 보고하고 종료해.

프로젝트 경로: /Users/gubonsang/Desktop/Dev/GNF_

MAP-01 관련 변경 파일들:
- Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs (신규)
- Assets/Scripts/Map/Dungeon/DelaunayTriangulation.cs (신규)
- Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs (신규)
- Assets/Tests/PlayMode/MAP01_Tests.cs (신규)
- docs/73_map01_dungeon_layout_generator.md (신규)
- docs/blueprints/MAP-01_blueprint.md (신규)
- feature_list.json (수정 — MAP-01 제거)
- feature_archive.json (수정 — MAP-01 추가)

커밋 메시지 규격: Conventional Commits + [태스크ID]
예: feat: add Delaunay-based dungeon layout generator [MAP-01]

주의: .meta 파일이 있다면 함께 스테이징할 것. 단, git에서 이미 추적 중이지 않은 .meta 파일만 해당.
Bash Show diff for modified JSON files
IN
git diff -- feature_list.json feature_archive.json

OUT
diff --git a/feature_archive.json b/feature_archive.json
index 7c4c8ec..9460548 100644
--- a/feature_archive.json
+++ b/feature_archive.json
@@ -418,5 +418,23 @@
     "task": "WFC 알고리즘 재설계 Phase 1 — 연결 보장형 던전 골격 생성 (StartRoom→Corridor→Room→ExitRoom 경로를 먼저 확정한 뒤 나머지 셀을 WFC로 채우는 2단계 생성 방식)",
     "status": "done",
     "verification": "testplay run --shadow exit_code 0, 테스트 7/7 PASS. ForceCollapse, 골격 배치, 가장자리 ExitRoom, BFS Entrance 체인 연결, 3×3/5×5/7×7 그리드 성공"
+  },
+  {
+    "id": "FIX-01",
+    "task": "Doorway 아치 배치 불일치 수정 — WFCPrefabBuilder의 isDoorSide 로컬 방향 고정을 제거하여, 모든 Entrance 면에 아치를 배치하도록 변경 (회전 변형 간 0-arch/2-arch 문제 해소)",
+    "status": "done",
+    "verification": "testplay run --shadow exit_code 0, 테스트 5/5 PASS. isDoorSide 파라미터 제거 확인, Entrance 하단 아치 배치 경로 정상, 상단 즉시 리턴 정상"
+  },
+  {
+    "id": "FIX-02",
+    "task": "SpecialRoom 크기 불일치 수정 — SpecialRoom A/B의 roomScale을 6에서 10으로 통일하여, 인접 타일과의 8m 바닥·벽 간극 해소",
+    "status": "done",
+    "verification": "testplay run --shadow exit_code 0, 테스트 6/6 PASS. roomScale=10 → wallDist=22m=tileSize/2, 직경 44m 일치 확인"
+  },
+  {
+    "id": "MAP-01",
+    "task": "던전 레이아웃 생성기 — 룸 랜덤 산포 + Delaunay Triangulation 연결 그래프. 연속 2D 공간에 룸을 최소 간격(룸 크기+복도 길이)으로 랜덤 배치한 뒤, Delaunay 삼각분할로 연결 후보를 구하고 MST+α 엣지를 선택하여 StartRoom→ExitRoom 경로가 보장되는 복도 그래프를 생성한다.",
+    "status": "done",
+    "verification": "testplay run --shadow exit_code 0, 테스트 9/9 PASS. Delaunay 삼각분할, BakeLayout 성공, StartRoom/ExitRoom 존재, 최소 간격 보장, BFS 연결성, SpecialRoom 존재, 로그 포맷 확인"
   }
 ]
diff --git a/feature_list.json b/feature_list.json
index 3a1d660..e8acd7b 100644
--- a/feature_list.json
+++ b/feature_list.json
@@ -22,5 +22,17 @@
     "task": "룸 프리셋 NavMesh 호환성 검증 — 소품 배치 후에도 플레이어·몬스터 NavMeshAgent 이동 경로가 유효한지 확인 및 Collider 조정",
     "status": "todo",
     "verification": "데코레이션이 적용된 각 테마 방에서 NavMesh Bake 성공. 플레이어가 방 입구에서 방 내부 전체를 이동 가능. 소품 Collider에 의한 이동 불가 영역이 방 면적의 30% 미만"
+  },
+  {
+    "id": "MAP-02",
+    "task": "복도 지오메트리 생성 — Delaunay 그래프의 각 복도 엣지를 따라 3D 통로(벽·바닥·천장·doorway) 빌드. 룸 간 직선 또는 L자형 복도를 KayKit 에셋으로 조립하고, 룸 벽면에 doorway 아치를 뚫어 연결한다. 문 열면 바로 문이 보이는 현상 없이 충분한 복도 길이를 확보한다.",
+    "status": "todo",
+    "verification": "Bake 후 SpectatorCamera로 전체 복도 순회 시 (1) 모든 복도에 바닥·벽·천장 존재 (2) 룸-복도 연결부에 doorway 아치 정상 (3) 복도 길이가 최소 8m 이상으로 문-문 직결 0건"
+  },
+  {
+    "id": "MAP-03",
+    "task": "룸 내부 장식 통합 — 배치된 각 룸 프리팹 내부를 기존 WFC 소품 배치 또는 RoomPreset 프리셋으로 장식. 룸 매크로 레이아웃(MAP-01/02)과 룸 인테리어(WFC/프리셋)를 분리하여, 룸 셸은 MAP이 배치하고 내부 소품은 기존 시스템이 담당하도록 연결한다.",
+    "status": "todo",
+    "verification": "Bake 3회 실행 시 모든 룸 내부에 소품이 배치됨. 동일 TileType 룸이라도 서로 다른 테마 소품 조합이 등장하는 경우 확인. Console에 '[Room] NormalRoom → Barracks theme' 등 배정 로그 출력"
   }
 ]
\ No newline at end of file
[result-id: r3]
Globpattern: "Assets/Scripts/Map/Dungeon*.meta"
No files found
Bash Check for .meta files associated with MAP-01 files
IN
ls -la /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/Dungeon/*.meta 2>/dev/null; ls -la /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/Dungeon.meta 2>/dev/null; ls -la /Users/gubonsang/Desktop/Dev/GNF_/Assets/Tests/PlayMode/MAP01_Tests.cs.meta 2>/dev/null

OUT
Exit code 1
(eval):1: no matches found: /Users/gubonsang/Desktop/Dev/GNF_/Assets/Scripts/Map/Dungeon/*.meta
Bash List untracked MAP-01 related files including .meta
IN
git ls-files --others --exclude-standard -- 'Assets/Scripts/Map/Dungeon*' 'Assets/Tests/PlayMode/MAP01*'

OUT
Assets/Scripts/Map/Dungeon/DelaunayTriangulation.cs
Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs
Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs
Assets/Tests/PlayMode/MAP01_Tests.cs
Bash Stage all MAP-01 related files
IN
git add \
  Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs \
  Assets/Scripts/Map/Dungeon/DelaunayTriangulation.cs \
  Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs \
  Assets/Tests/PlayMode/MAP01_Tests.cs \
  docs/73_map01_dungeon_layout_generator.md \
  docs/blueprints/MAP-01_blueprint.md \
  feature_list.json \
  feature_archive.json

OUT
(Bash completed with no output)
Bash Verify staged files
IN
git diff --cached --stat

OUT
 .../Scripts/Map/Dungeon/DelaunayTriangulation.cs   | 174 +++++
 Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs    |  48 ++
 .../Scripts/Map/Dungeon/DungeonLayoutGenerator.cs  | 572 ++++++++++++++++
 Assets/Tests/PlayMode/MAP01_Tests.cs               | 315 +++++++++
 docs/73_map01_dungeon_layout_generator.md          |  84 +++
 docs/blueprints/MAP-01_blueprint.md                | 716 +++++++++++++++++++++
 feature_archive.json                               |  18 +
 feature_list.json                                  |  12 +
 8 files changed, 1939 insertions(+)
[result-id: r6]
Bash Create conventional commit for MAP-01
IN
git commit -m "$(cat <<'EOF'
feat: add Delaunay-based dungeon layout generator [MAP-01]

룸 랜덤 산포 + Delaunay Triangulation 연결 그래프 기반 던전 레이아웃 생성기 추가.
연속 2D 공간에 룸을 최소 간격으로 배치한 뒤 MST+α 복도 그래프를 생성하여
StartRoom→ExitRoom 경로를 보장한다.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

OUT
[WFC 7f8fe69] feat: add Delaunay-based dungeon layout generator [MAP-01]
 8 files changed, 1939 insertions(+)
 create mode 100644 Assets/Scripts/Map/Dungeon/DelaunayTriangulation.cs
 create mode 100644 Assets/Scripts/Map/Dungeon/DungeonLayoutData.cs
 create mode 100644 Assets/Scripts/Map/Dungeon/DungeonLayoutGenerator.cs
 create mode 100644 Assets/Tests/PlayMode/MAP01_Tests.cs
 create mode 100644 docs/73_map01_dungeon_layout_generator.md
 create mode 100644 docs/blueprints/MAP-01_blueprint.md
[result-id: r7]
Update Todos

Create DungeonLayoutData.cs (RoomNode, CorridorEdge, DungeonLayout)

Create DelaunayTriangulation.cs (Bowyer-Watson static class)

Create DungeonLayoutGenerator.cs (MonoBehaviour orchestrator)

Delegate to QA agent for testing

Delegate to tech-writer agent for documentation

Finalize task (done + archive)
MAP-01 완료. 커밋: 7f8fe69

요약
단계	결과
코어 로직	3파일 신규 생성 (DungeonLayoutData / DelaunayTriangulation / DungeonLayoutGenerator)
QA	9/9 PASS (MAP01_Tests.cs)
문서	docs/73_map01_dungeon_layout_generator.md
커밋	7f8fe69
생성된 시스템: 4-Phase 파이프라인

PlaceRooms — Poisson disk 변형으로 최소 간격 보장 랜덤 배치
Delaunay — Bowyer-Watson 삼각분할로 연결 후보 생성
MST + extra — Kruskal MST + 15% 추가 엣지로 루프 있는 복도 그래프
BFS validation — StartRoom→ExitRoom 연결 + 전체 도달성 검증
다음 권장 태스크
MAP-02: 복도 지오메트리 생성 (3D 통로 메시)
MAP-03: 룸 내부 장식 통합