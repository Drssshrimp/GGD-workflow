# GGD Workflow for Claude Code

**GGD == Get Games Done**——一套方便个人或者小团队进行游戏开发的 Claude Code 工作流。

GGD 参考了传统软件开发中的 [GSD（Get Shit Done）](https://github.com/open-gsd/gsd-pi) 工作流，用状态机 + Hook 硬门禁确保项目不跳步，用专业化 Agent 链（PM → Architect → Dispatcher）把「讨论 → 设计 → 编码」拆成可接续的标准化流程。

## 为什么用 GGD

游戏项目的特点：超长上下文、需求频繁变动、引擎代码与业务逻辑交织、代码依赖关系复杂、一次性 prompt 写出的代码往往很难直接投入使用。

裸用 Claude Code 时，其一，Agent 容易跳过需求确认直接写代码，时常导致生成的代码不达预期，需要反复明确需求细节，造成浪费。其二，游戏开发所需的代码文件通常有较复杂的依赖关系，若在一次对话中生成全部代码，很容易引入大量的低级 bug，若通过多次对话逐渐产出代码，一方面，agent 反复阅读之前的代码会造成很多不必要的 token 消耗，另一方面，会话中断后新会话丢失进度——这些问题在游戏开发中会被进一步放大。

GGD 学习了 GSD 工作流的核心机制，针对游戏开发做了三件事：

- **硬门禁防跳步** — 通过状态切换与脚本的约束，在每次调用工具前，都会根据状态的设置进行禁止或放行
- **Agent 链专业分工** — 三个主要 Subagent 职责：PM 和你讨论并确定功能需求，明确边界漏洞（策划）；Architect 与你一起设计程序架构，根据架构分配任务，调用 Coding Dispatcher 开发代码（程序）；Dispatcher 纯执行代码
- **文档驱动** — PROJECT / REQUIREMENTS / ROADMAP / STATE 四份文档是唯一真相源，新会话读 STATE.md 即可无缝接续

## 前置要求

- **[Claude Code](https://github.com/anthropics/claude-code)** 
- **使用引擎开发的话请安装对应引擎的 MCP**


## 安装

```powershell
# 1. 克隆仓库
git clone https://github.com/Drssshrimp/ggd-workflow.git
cd ggd-workflow

# 2. 全局安装（推荐）—— 所有项目共用
.\install.ps1

# 或者项目级安装 —— 仅当前项目
.\install.ps1 -Local

# 3. 重载终端配置
. $PROFILE
```

安装脚本自动完成：
- 复制 Agent / Command / 模板 / Hook 到 `.claude/`
- 合并 Hook 配置到 `settings.local.json`（不覆盖已有设置）
- 追加 `ggd-*` 命令到 PowerShell Profile 或 `.bashrc`

## 目录结构

```
ggd-workflow/
├── install.ps1                  # 安装脚本
├── README.md
└── dist/
    ├── init-ggd.ps1             # 项目级初始化脚本
    ├── agents/                  # 5 个专业化 Agent 定义
    │   ├── project-manager.md       # PM — 需求讨论、文档维护、任务拆解
    │   ├── architect.md             # 架构师 — 技术设计、调度 Dispatcher
    │   ├── coding-dispatcher.md     # 编码执行器 — 纯代码实现
    │   ├── debug-assistant.md       # 调试助手 — 基于架构报告的假设排查
    │   └── senior-numerical-designer.md  # 数值策划
    ├── commands/                # 4 个快捷命令
    │   ├── pm.md                    # /pm — 项目经理模式
    │   ├── arch.md                  # /arch — 架构师模式
    │   ├── debug.md                 # /debug — 调试助手模式
    │   └── nd.md                    # /nd — 数值策划模式
    ├── hooks/                   # 门禁脚本
    │   └── enforce_ggd.py
    ├── templates/               # 文档与架构报告模板
    │   ├── project_template.md
    │   ├── requirements_template.md
    │   ├── roadmap_template.md
    │   ├── state_template.md
    │   ├── task_brief_template.md
    │   ├── architecture_report_template.md
    │   ├── debug_reference_template.md
    │   └── pending_issues_template.md
    └── ggd-template/            # 项目初始化引导文件
        ├── state.json               # 状态机
        ├── enforce_ggd.py           # Hook 副本
        ├── setting.json             # Hook 配置模板
        ├── settings.local.json      # 项目级配置模板（含 enforce_ggd 钩子）
        ├── general_flow_chart.md    # 功能走线图（空模板）
        ├── PROJECT.md               # 项目宪法（空模板）
        ├── REQUIREMENTS.md          # 需求清单（空模板）
        ├── ROADMAP.md               # 路线图（空模板）
        └── STATE.md                 # 当前状态（空模板）
```

## Agent 调度链

```
PM（需求讨论、文档维护）
  │
  ├─→ Senior Numerical Designer（数值模型设计）
  │
  └─→ Architect（技术设计、架构报告）
        │
        └─→ Coding Dispatcher（纯代码实现，零架构决策）

Debug Assistant（独立调用，基于架构报告协助排查 bug）
  └─→ Coding Dispatcher（用户确认后调度）
```

核心原则：**PM 不碰代码，Architect 不写实现，Dispatcher 不做决策。**

## 文档产出及介绍

### PM（项目经理）

| 产出物 | 形式 | 用途 | 消费者 |
|--------|------|------|--------|
| `general_flow_chart.md` | 文件 | 功能级流程图，描述用户操作→系统响应的交互流，不涉及代码实现细节 | 全角色 |
| `PENDING_ISSUES.md` | 文件（可选） | 待确认决策清单，逐条追踪逐条划掉，复杂需求时防止遗漏 | 用户 |
| PROJECT / REQUIREMENTS / ROADMAP / STATE | 文件 | 四份文档构成唯一真相源，驱动全流程接续 | 全角色 |

PM 在 planning 阶段只做需求讨论和功能边界对齐，**不产出 PLAN 文件**。讨论完成后可选择性创建 PENDING_ISSUES 追踪未决决策。用户批准后进入 waiting_requirements，PM 按模板生成四份核心文档。

#### 四份核心文档

这四份文档借鉴了 GSD 工作流的文档驱动设计，各司其职，形成一条从愿景到执行的信息链：

```
PROJECT.md（为什么做）
    ↓
REQUIREMENTS.md（具体做什么）
    ↓
ROADMAP.md（按什么顺序做）
    ↓
STATE.md（现在做到哪了）
```

**PROJECT.md — 项目宪法**

定义项目的「不变项」——愿景、约束、成功标准、重大决策。一经确定不应频繁改动。后续所有讨论和设计以此为边界。

| 内容 | 说明 |
|------|------|
| 愿景/目标 | 一句话说清这个系统要达成什么 |
| 核心价值与用户场景 | 为谁解决什么问题，典型使用场景 |
| 关键约束 | 技术栈、工期、合规、性能等硬性限制 |
| 成功标准 | 可验证的验收条件 |
| 重大决策记录 | 已做出的关键架构/设计决策，避免反复讨论 |

**REQUIREMENTS.md — 需求规格**

将 PROJECT 的愿景拆解为可验证的具体功能条目。按版本分档，明确每个需求的验收标准。

| 内容 | 说明 |
|------|------|
| v1 需求表 | ID + 描述 + 验收标准 + 关联里程碑，本次必须实现 |
| v2 需求表 | 后续迭代的内容，标注依赖和推迟理由 |
| Out of Scope | 明确不做的事，防止范围蔓延 |

**ROADMAP.md — 路线图**

将 REQUIREMENTS 中的条目按依赖关系编排成里程碑和阶段，决定施工顺序。

| 内容 | 说明 |
|------|------|
| 里程碑总览 | 各里程碑目标 + 时间预估 |
| 阶段拆解 | 每个 Phase 的目标、依赖、覆盖的需求 ID、当前状态 |
| 状态标记 | ✅ 已完成 / 🔄 进行中 / ⏳ 未开始 |

**STATE.md — 当前状态**

四份文档中更新最频繁的一份。每次会话结束时更新，下次会话开始时先读它。是跨会话接续的锚点。

| 内容 | 说明 |
|------|------|
| 全局进度 | 各 Phase 完成百分比 |
| 当前正在做的事 | 当前任务、负责人、预计完成时间 |
| 阻塞项/风险 | 当前卡住的问题、潜在风险、已解决事项 |
| 已确认的关键决策 | 决策 + 结论 + 日期，追溯决策历史 |
| 会话记忆/继续入口 | 上次做到哪了、下次从哪个文件哪个函数开始 |

### Architect（架构师）

| 产出物 | 形式 | 用途 | 消费者 |
|--------|------|------|--------|
| `ARCH_<任务名>.md` | 文件 | 完整架构设计报告，含代码流程图、文件明细卡片、接口签名、变更影响、API 索引 | 用户审阅 → Dispatcher 按卡片施工 |
| `DEBUG_<任务名>.md` | 文件 | 调试参考文件，集中记录风险点和边界假设，方便调试时快速定位 | Debug Assistant |

架构报告产出前必须先与用户做意图对齐，产出后逐卡片经用户确认。按依赖顺序串行调度 Dispatcher，每个子任务返回后验证签名/引用/禁区。

#### ARCH_<任务名>.md 目录

```
§0 架构总览
  ├─ 0.1 依赖拓扑图          → 文件间调用关系，标注新增/修改/已有
  ├─ 0.2 引入与暴露速览        → 每个文件引入了谁、暴露给谁
  ├─ 0.3 数据流序列图          → 核心业务流程的完整调用链（同步/异步/委托时机）
  ├─ 0.4 文件清单              → 文件名、状态、模块、一句话职能
  ├─ 0.5 数据契约（真代码）     → USTRUCT / UENUM / UCLASS 声明 / 委托声明
  └─ 0.6 初始化与生命周期顺序表  → 初始化顺序、钩子、委托订阅/解绑

§1 逐个文件明细卡片
  对每个代码文件输出一张卡片，包含：
  ├─ 职能（一句话）
  ├─ 外部引入                → 来源文件 + 使用的函数/类型 + 用途
  ├─ 对外暴露                → 签名 + 消费方 + 用途
  ├─ 跨文件交互协议           → 前置/后置/错误处理/同步异步
  ├─ 生命周期                → 钩子 + 初始化依赖 + 委托订阅/解绑
  ├─ 伪代码骨架              → 签名真代码，实现伪代码
  ├─ 数据成员                → 类型 + UPROPERTY + 用途
  ├─ 禁区                    → 不能碰的文件或模块
  ├─ 引用白名单              → 允许/禁止引用的头文件
  ├─ Blueprint 暴露面        → BlueprintAssignable / BlueprintCallable
  ├─ GC 安全                 → UPROPERTY 保护 / TWeakObjectPtr
  └─ 架构决策理由            → 为什么选 X 而非 Y

§2 变更影响范围表           → 文件变更时需要同步检查的文件

§3 对外暴露 API 索引
  ├─ 按功能域索引            → ClassName::Function(Signature) + 前置 + 范例
  ├─ 按源文件索引            → 每个文件对外的函数/委托 + 消费方
  └─ 按消费方索引            → 每个消费方可调用的外部接口
```

#### DEBUG_<任务名>.md 目录

```
文件修改清单（每个改动文件一行）
  ├─ 文件路径                → 相对于 Source/ 或项目根目录
  ├─ 关键函数/类             → 本次改动涉及的符号名
  ├─ 改动意图                → 一句话，设计上这个文件的职责
  ├─ 风险点                  → 架构师判断"这里可能出问题"，无则 —
  └─ 边界假设                → 代码正确运行的前置条件，无则 —
```


## 最佳实践

建议在一个IDE里面打开项目文件，并使用里面的终端唤出claude，方便随时审阅与修改

### 指令

- init-ggd            #初始化
- ggd-status         # 查看状态
- gsd-approve-plan   # 批准 plan
- ggd-approve-reqs   # 批准需求
- ggd-done           # 完成项目
- ggd-reset          # 重置状态

直接在目录路径终端里输入执行就好

### 新项目启动

**有现成的策划案 / 设计文档**

1. 在项目根目录执行 `init-ggd`
2. `ggd-approve-plan` 跳过 planning 讨论，进入需求阶段
3. `/pm` 召唤 PM，将参考文档提供给它阅读理解
4. PM 生成四份核心文档 + 宏观开发顺序建议，审阅后 `ggd-approve-reqs`

**从零起步**

1. `init-ggd` → `/pm`，与 PM 充分讨论需求和技术边界
2. 思路清晰后 `ggd-approve-plan`，PM 生成四份核心文档
3. 审阅确认后 `ggd-approve-reqs`

### 开发流程

将开发任务至少拆到**系统粒度**（背包、任务等），较复杂的系统（如战斗，养成）建议再做进一步细化拆分。每个系统在项目根目录下创建独立子目录，在子目录内再次执行 `init-ggd`。一个系统全部验收后再启动下一个。
同时，我在使用中还从社区中下载并配置了很多skill，这个就看你的个人需求自行安装了

**① Planning — 需求对齐**

- `/pm` 模式下让 PM 向上阅读根目录的核心文档，理解当前子系统的定位
- 与 PM 对齐功能边界和开发顺序
- 如果实现方案尚不明确，让 PM 生成 `PENDING_ISSUES.md` 进行头脑风暴，逐条讨论逐条划掉，思路清晰后再结束
- 完成后 `ggd-approve-plan`

**② Requirements — 文档审阅**

- PM 输出需求文档后，建议**重点审阅 REQUIREMENTS.md 和 ROADMAP.md**，检查遗漏项和规划偏差
- 此阶段可与 PM 就需求边界、细节做进一步补充讨论
- 涉及数值设计时，可切换 `/nd` 召唤数值策划——建议主动给出设计方向引导，AI 的设计品味比较普通
- 确认无误后 `ggd-approve-reqs`

**③ Architecture — 架构设计与编码**

- 让PM 生成 Task Brief （如果功能较为复杂，建议以roadmap中的phase为单位）→ 切换 `/arch`
- Architect 阅读文档后与你讨论架构方案
- **建议先自己构思，再与 Architect 磋商**，共同产出架构报告。如果完全放手让 AI 自行设计，代码质量会下降（虽说接入的模型能力也会影响产出质量）
- 审阅架构报告的每张文件卡片，确认无误后由 Architect 调度 Coding Dispatcher 串行编码

**④ Debug — 问题排查**

- 遇到 bug 时，让 Architect 产出一份 DEBUG 参考文件
- 切换 `/debug`，Debug Assistant 读取相关文件后协助定位根因
- **以人为主导**，不主要依赖 AI 排查

### 进度维护

- 每个阶段结束时，提醒 Claude Code 更新文档进度（目前还做不到自动更新维护）
- 根目录的核心文档可等整个系统开发完成后再统一更新，届时可能涉及根目录需求文档的同步修订

### 核心使用思路
**欲速则不达，记得拆分任务**。不要指望“一句话做游戏” “一次讨论出游戏”这种情况（极简游戏或是原型或许还可以）

### 中断恢复

会话中断后，新会话直接说「阅读需求文档」「查询 State 的项目状态」，Agent 从 STATE.md 接续，无需重述上下文。


## 反馈与交流

这是本人在使用 Claude Code 进行游戏开发的阶段性总结产出，整体还处在一个比较稚嫩的状态，我也在持续学习与迭代。您在使用过程中如有任何建议或不满，欢迎随时提出。

邮箱：3165151545@qq.com

## License

MIT
