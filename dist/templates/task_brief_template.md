# Task Brief 模板

> PM 在交付给 architect 之前填写。architect 以此为入口，按需跳转阅读五个源文档。

---

## 1. 任务标识

- **系统**：[如 CommissionSystem]
- **架构范围**：[如 Phase C 全部]
- **任务文件数**：新建 X 个 / 修改 Y 个

---

## 2. 一句话目标

[用一句话说清：做完这件事后，系统新增了什么能力？]

---

## 3. 阅读导航（核心）

> architect 必须按以下顺序阅读，不得跳过标记为「必读」的章节。

### 第一轮：建立全局认知（架构设计开始前必读）

| 顺序 | 文档 | 章节/行范围 | 必读内容 | 为什么读 |
|------|------|------------|---------|---------|
| 1 | `general_flow_chart.md`（PM 产出的功能走线图） | §1（总体流程）+ §2（营业执行） | 全文 | 理解完整功能交互流程，建立心智模型 |
| 2 | `PROJECT.md` | 「关键约束」+「重大决策记录」表 | 全文 | 理解技术边界和已决设计决策，避免重复讨论 |
| 3 | `STATE.md` | 「当前正在做的事」+「阻塞项/风险」 | 全文 | 了解当前状态和已知风险 |

### 第二轮：理解数据与行为（设计各模块时按需查阅）

| 文档 | 查阅时机 | 查阅方式 |
|------|---------|---------|
| `REQUIREMENTS.md` | 设计具体模块时 | 按 COM-XXX 编号精准定位，不从头通读 |
| `ROADMAP.md` | 规划文件清单和编译顺序时 | 读「Phase C 子阶段总览」表和「编译顺序」 |
| `general_flow_chart.md` §3~§10 | 设计特定子系统时 | 按需跳转对应章节 |

### 第三轮：验证（设计完成后自检）

| 文档 | 检查项 |
|------|--------|
| `REQUIREMENTS.md` | 逐条确认本阶段需求是否已覆盖 |
| `PROJECT.md` | 确认所有设计决策未被违反 |

---

## 4. 关键需求索引

> 列出了架构范围内的所有需求 ID + 一句话摘要。architect 按需在 REQUIREMENTS.md 中搜索 COM-XXX 查看完整验收标准。

| 需求ID | 摘要 | 涉及模块 |
|--------|------|---------|
| COM-001 | 委托系统主界面（三栏布局） | UI |
| COM-007 | FActiveCommissionRuntime 11字段 | 数据 |
| ... | ... | ... |

---

## 5. 设计决策速查（摘自已决事项，不新增）

> 从 PROJECT.md 和 STATE.md 中提取与本次架构直接相关的决策。architect 不需要自己从 1700 行文档里挑。

| 决策 | 结论 | 对架构的约束 |
|------|------|-------------|
| 不建状态机 | 状态由已有数据推导 | 禁止定义 ECommissionStatus 枚举 |
| 严格串行 | 一次一单，不做并发 | 不需要并发安全设计 |
| 单 DA 多阶段 | TArray<FPhaseConfig> 内嵌 | PhaseConfigs[CurrentPhase] 直接索引 |
| 状态变就写 | 每次状态变更即时写 SaveGame | SaveGame 写入调用点分散在各逻辑中 |
| ... | ... | ... |

---

## 6. 硬依赖清单

| 依赖系统 | 已有接口 | 本次需要新增的调用 |
|----------|---------|------------------|
| UFerryAISubsystem | PreloadNPC, SendDialogueMessage, CurrentClientNPC | 订阅 FOnPreloadComplete |
| UFerryMailboxSubsystem | SubmitLetter, FOnLetterSubmitted | 订阅 FOnLetterSubmitted |
| ... | ... | ... |

---

## 7. 禁区

> architect 在设计时绝对不能触碰的区域。

- [ ] 不定义 ECommissionStatus 枚举
- [ ] 不修改 FerryAISubsystem 的 CurrentClientNPC 归属（留在 AISubsystem）
- [ ] 不在 USTRUCT 中持有 UObject 指针
- [ ] 不让 UI Widget 直接感知 CommissionSystem（依赖反转：Widget → Mailbox → 广播 → CommissionSystem）
- [ ] ...

---

## 8. 跨模块连接点（关键）

> 这是最容易出错的环节。PM 必须明确指出哪些接口是跨模块的，architect 在设计时必须优先锁死这些接口签名。

| 连接点 | 生产者 | 消费者 | 接口形式 | 优先级 |
|--------|--------|--------|---------|--------|
| NPC 预加载完成通知 | FerryAISubsystem | CommissionSystem → MainHUD | FOnPreloadComplete 委托 | 🔴 先锁死 |
| 信件提交回传 | MailboxSubsystem | CommissionSystem | FOnLetterSubmitted 委托 | 🔴 先锁死 |
| 结算数据 | CommissionSystem | WBP_CommissionComplete | FCommissionSettlementData 结构体 | 🔴 先锁死 |
| ... | ... | ... | ... | ... |

---

## 9. 架构输出要求

- **主输出文件**：`docs/architecture/ARCH_PhaseC.md`（一份，覆盖整个 Phase C）
- **结构**：按 `architecture_report_template.md` 模板
- **产出内容**：
  - 0. 架构总览（全局依赖拓扑 + 全部文件清单 + 代码流程图（调用链） + 数据流序列图）
  - 1. 逐个文件明细卡片（每个新建/修改文件一张）
  - 2. 变更影响范围表（跨文件依赖矩阵）
  - 3. 对外暴露 API 索引（按源文件/消费方/功能域三维索引）
- **附加输出**：架构报告审阅通过后，架构师须按 `debug_reference_template.md` 模板生成 `docs/architecture/DEBUG_<Phase名>.md`
- **不产出**：每个子阶段单独的架构文档（C1/C2/C3...各一份）
