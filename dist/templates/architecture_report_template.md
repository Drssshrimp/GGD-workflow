ARCHITECTURE_REPORT
# 架构设计报告：<任务名>

> 对应 PLAN：<PLAN 文件路径>
> 日期：<YYYY-MM-DD>

---

## 0. 架构总览

### 0.1 依赖拓扑图

```
图例：[新] 新建  [改] 修改  [已] 已有只读

[已] ExistingSystem        [新] NewFileA
    │                          │
    │ GetData() ──────────────→│
    │                          │ OnResult(Delegate)
    │                          │
    ▼                          ▼
[改] ModifiedFile ──────────→ [新] NewFileB
      暴露: DoSomething()         引用: NewFileA
      消费: NewFileB
```

**每个箭头上标注调用的函数名或委托名。**

### 0.2 引入与暴露速览

按文件分块，每个文件标注状态、引入了谁、暴露给谁。函数/委托用 `→` 连接源与目标。

```
■ NewFileA (新增)
  引入: ExistingSystem → GetData()
  暴露: NewFileB → OnResult (委托)

■ ModifiedFile (修改)
  引入: (无外部引入)
  暴露: NewFileB → DoSomething()

■ NewFileB (新增)
  引入: NewFileA → OnResult (委托订阅)
        ModifiedFile → DoSomething()
  暴露: (无对外暴露)
```

### 0.3 数据流序列图

选取一个核心业务流程的完整调用链：

```
Player          UI_Widget        NewSubsystem      ExistingSystem
  │                │                  │                  │
  │── 点击按钮 ──→│                  │                  │
  │                │── ProcessX() ──→│                  │
  │                │                  │── GetData() ──→│
  │                │                  │←── result ──────│
  │                │                  │─ 广播 OnDone ───│
  │                │←── 更新UI ───────│                  │
```

标注同步/异步、委托广播时机。

### 0.4 文件清单

| 文件名 | 状态 | 模块 | 一句话职能 |
|----------|------|------|-----------|
| NewA.h | 新增 | FerryCore | ... |
| NewA.cpp | 新增 | FerryCore | ... |
| ExistingB.h | 修改 | FerryCore | ... |

### 0.5 数据契约（真代码）

给出本次新建或修改的所有 USTRUCT / UENUM / UCLASS 声明 / DataAsset / 委托声明。每个条目标注所在文件。

```cpp
// === NewA.h ===
USTRUCT(BlueprintType)
struct FNewData {
    GENERATED_BODY()
    UPROPERTY(EditAnywhere) FName ID;
    UPROPERTY(EditAnywhere) FText DisplayName;
};

UCLASS()
class UFerryNewSubsystem : public UGameInstanceSubsystem {
    GENERATED_BODY()
public:
    void ProcessX(const FNewData& Data);
    DECLARE_EVENT_OneParam(UFerryNewSubsystem, FOnDone, FName);
    FOnDone OnDone;
};
```

### 0.6 初始化与生命周期顺序表

| 序号 | 文件 | 钩子 | 操作 | 前置依赖 | 委托操作 |
|------|------|------|------|----------|----------|
| 1 | ExistingSystem | Initialize | 初始化数据 | 无 | — |
| 2 | NewSubsystem | Initialize | 初始化，绑定委托 | 序号 1 | Subscribe: ExistingSystem.OnXxx |
| 3 | NewSubsystem | Deinitialize | 解绑委托 | — | Unsubscribe: ExistingSystem.OnXxx |

---

## 1. 逐个文件明细卡片

对每个代码文件，输出下列卡片。与用户逐卡讨论锁定。

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
文件：Source/Ferry/NewSubsystem.h + .cpp
状态：新增   模块：FerryCore
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【职能】（一句话）

【外部引入】
| 来源文件 | 使用的函数/属性/类型 | 用途 |
|----------|---------------------|------|
| ExistingSystem.h | GetData() | 获取数据 |

【对外暴露】
| 函数/委托/属性 | 签名 | 消费方 | 用途 |
|--------------|------|--------|------|
| ProcessX | void(const FNewData&) | UI_Widget | 处理请求 |

【跨文件交互协议】（每个公开函数）
ProcessX():
  前置:
  后置:
  错误处理:
  同步/异步:

【生命周期】
  钩子:
  初始化依赖:
  委托订阅:
  委托解绑:

【伪代码骨架】（签名真代码，实现伪代码）
void UFerryNewSubsystem::ProcessX(const FNewData& Data)
{
    // [伪] 校验 Data.ID 非空
    // [伪] 调用 ExistingSystem->GetData()
    // [伪] 广播 OnDone
}

【数据成员】
| 成员名 | 类型 | UPROPERTY | 用途 |
|--------|------|----------|------|
| Cache | TMap<FName, int32> | —（非 UObject） | 本地缓存 |

【禁区】
· 不调用 AI API
· 不直接操作 UI Widget

【引用白名单】
| 允许引用 | 禁止引用 |
|----------|----------|
| ExistingSystem.h | UI/ 下所有文件 |

【Blueprint 暴露面】
| 暴露项 | 修饰符 |
|--------|--------|
| OnDone | BlueprintAssignable |

【GC 安全】
  UPROPERTY 保护: —
  TWeakObjectPtr: —
  手动管理: —

【存档序列化】
  需持久化: 是 / 否
  方式: —

【架构决策理由】（如有）
  为什么选 X 而非 Y：
```

---

## 2. 变更影响范围表

| 文件 | 若变更需同步检查 | 不受影响 |
|------|-----------------|----------|
| NewData 字段变更 | NewSubsystem.cpp, UI_Widget | ExistingSystem |

---

## 3. 对外暴露 API 索引

### 按功能域索引

```
■ 功能域名
  ClassName::FunctionName(Signature)
    → 文件: 完整路径
    → 用途: 一句话
    → 前置: ...
    → 范例: Class->Function(args);
```

### 按源文件索引

```
文件名 对外暴露：
  · FunctionName(Signature) → 消费方: FileA
  · DelegateName → 订阅方: FileB
```

### 按消费方索引

```
消费方文件名 可调用的外部接口：
  来源: SourceFileA → Function1() / Function2()
  来源: SourceFileB → DelegateX
```
