# 单人植物养护 MVP：待确认组件与实施事项

日期：2026-11-14。本文记录待确认组件以及模型接入、会话与流式接口约定。已经写入工程的依赖以仓库配置为准。

## 1. 客户端组件

以下组件需要在引入时确认版本、兼容性和实际使用需求：

- Riverpod：状态管理。
- Dio：普通请求、图片上传、流式读取与取消。登录请求已经使用 Dio。
- go_router：路由与登录跳转。
- image_picker：拍照和相册选择。
- fl_chart：历史曲线。
- flutter_secure_storage：登录凭据的系统安全存储。登录令牌已经使用该组件保存。

Riverpod、go_router、image_picker 和 fl_chart 尚未引入。组件引入后需验证 iOS 与 Android 的权限、运行和打包行为。

## 2. 后端配套组件与登录会话

已确定：

- 持久化使用 MyBatis-Plus。建表脚本位于 `backend/src/main/resources/db/migration/`。后端启动不执行这些脚本。
- 登录签发有效期 7 天的 JWT。当前令牌保存在服务器上的 Redis，键为 `plant:jwt:token:{用户编号}`，有效期与令牌一致。再次登录覆盖旧令牌，退出删除令牌。
- 账号去掉首尾空白并转为小写，长度 3–32，只允许字母、数字和下划线。唯一约束建立在规范化结果上。
- 密码使用 BCrypt 哈希，长度 8–64，保存前不改写密码内容。
- 数据库与 Redis 位于服务器 `8.155.138.61`。连接项写在 `backend/.env`，模板见 `backend/.env.example`。

注册仅使用账号和密码，无需接入邮箱、短信或第三方身份验证。

## 3. 模型服务与适配器

文字问答直连 DeepSeek 官方服务，配置保存在后端环境文件，模板为 `backend/.env.example`：

| 配置 | 当前值或默认值 | 含义 |
| --- | --- | --- |
| `AI_BASE_URL` | `https://api.deepseek.com/v1` | 官方兼容 Chat Completions 的根地址 |
| `AI_MODEL` | `deepseek-flash` | 官方 Flash 模型名称 |
| `AI_API_KEY` | 本机私有配置 | 模型调用密钥 |
| `AI_MEMORY_TURNS` | `10` | 最近已完成问答轮数，允许 1–50 |
| `AI_INPUT_BUDGET_BYTES` | `32000` | 输入 UTF-8 字节预算，包含每条消息 256 字节预留 |
| `AI_MAX_OUTPUT_TOKENS` | `2048` | 模型输出 token 上限 |
| `AI_TIMEOUT_SECONDS` | `120` | 一轮生成的总超时秒数 |
| `AI_MAX_CONCURRENT` | `16` | 每个后端实例的生成并发上限 |

工程使用 Spring AI 2.0.2，通过 `spring-ai-openai` 的兼容接口适配器、`ChatClient` 和原生工具调用循环完成文字流式问答。自动重试关闭，模型 HTTP 资源在应用停止时释放。配置缺失时问答返回 HTTP 503 / `AI_NOT_CONFIGURED`，账号与植物档案功能仍可使用。

模型名称以官方模型列表 `GET /models` 和官方文档为准，Flash 模型使用 `deepseek-flash`。上游失败的诊断日志记录问答编号与 HTTP 状态，不向客户端转发任意上游正文。模型密钥仅保存在后端私有环境配置中。

文字问答请求显式携带 `thinking: {type: disabled}`，模型输出预算用于最终回复。会话长期保存用户问题与最终回复，工具调用期间由框架维护当轮执行上下文。

真实官方模型已通过文字流式回复、植物查询工具和持久化连续问答联调。以下能力仍需验证：

- 文字问答质量：结合权威植物资料、环境摘要和养护事件评测建议准确性。
- 图片理解：能接收植物照片，并结合上下文给出异常辅助分析。
- 结构化输出：支持的 JSON 或 JSON Schema 能力，以及后端的解析、校验和错误处理方式。
- 手机真机联调：测量首段延迟，验证设备端持续输出、取消和断连。
- 费用与数据处理：调用成本、速率限制、图片限制和服务的数据保存政策。

模型服务密钥保留在后端。照片判断质量需要用实际样本评测，不能仅凭接口调用成功认定有效。

## 4. 知识检索与上下文策略

- 小型知识目录可以按物种、主题和适用条件查询，检索结果保留来源标识。
- 是否引入语义向量检索，需要结合资料规模、自然语言检索效果和维护成本确定。
- 引入向量检索时，确认 embedding 模型、维度、切片方式、pgvector 扩展版本、索引与元数据过滤。
- 向量对应的资料和模型版本必须可追溯，变更 embedding 模型时明确重建方式。
- 完整聊天历史保存在 `ai_conversations`、`ai_turns`、`ai_messages`。每次按顺序加载最近 N 轮 `COMPLETED` 问答，并加入当前问题、系统提示词和指定植物最新档案。历史分页与上下文窗口独立，窗口之外的历史仍可查看。
- `FAILED`、`CANCELLED`、`INTERRUPTED` 轮次保留正文和状态，不进入后续上下文。输入超出字节预算立即返回 `AI_CONTEXT_TOO_LONG`；不静默裁剪配置的轮数。自动摘要和长期事实记忆尚未实现。
- 系统提示词位于 `backend/src/main/resources/prompts/plant-care-system.st`，限定证据、来源与建议表达。原生只读工具可分页查询当前账号植物列表和单株档案，身份从服务端工具上下文传递，每轮工具总调用数最多五次，工具错误立即终止。
- 工具调用及其响应参与当轮模型执行。当前长期保存用户问题、助手文本、状态、模型、提示词版本和供应商返回的用量；完整工具执行轨迹与知识引用仍为扩展项。

环境统计、养护次数和时间范围由程序计算，模型负责解释；用户私有事件与实时读数使用结构化查询。

## 5. 图片存储与通信

- 图片存储：本地开发可使用服务端文件目录；部署时选择持久化文件存储或对象存储，明确访问权限和删除策略。
- 数据库保存图片归属、文件标识及必要元数据。
- 普通操作使用 REST，部署链路使用 HTTPS；AI 回复使用 POST SSE，并携带当前账号的 Bearer 令牌。
- 流式链路需处理 UTF-8 分段、事件边界、结束、错误、取消和断连，避免将单个网络数据块当作完整事件。
- App 的运行地址按模拟器或真机环境配置；后台运行和通知能力按系统限制设计。

智能问答接口均位于 `/ai/conversations`，资源归属只从登录身份取得，其他账号访问统一返回会话不存在：

| 操作 | 路径与请求 |
| --- | --- |
| 新建会话 | `POST /ai/conversations`，`{"plantId":123,"title":"绿萝"}`，字段均可省略 |
| 会话列表 | `GET /ai/conversations?offset=0&limit=20` |
| 历史消息 | `GET /ai/conversations/{id}/messages?before=轮次&limit=20`，默认最近 20 轮，正文按时间正序 |
| 流式提问 | `POST /ai/conversations/{id}/messages`，`{"requestId":"小写UUID","content":"问题"}` |
| 查询一轮状态 | `GET /ai/conversations/{id}/turns/{turnId}` |
| 停止生成 | `POST /ai/conversations/{id}/turns/{turnId}/cancel` |
| 删除会话及消息 | `DELETE /ai/conversations/{id}` |

会话编号、轮次编号和请求编号使用 UUID。问题去除首尾空白后为 1–4000 字；标题最多 100 字，省略时使用植物昵称或“养护问答”。列表与历史每页最多 50 项。指定植物删除后保留会话历史，再次提问返回植物不存在。

SSE 的 `accepted` 返回轮次与助手消息编号，`delta` 返回增量 `text` 和递增 `sequence`，`done` 在事务保存完成状态后返回最终 `content`，`error` 返回业务错误代号与说明。相同请求编号和正文只回放已保存的 `done` 或 `snapshot`；相同编号不同正文、同会话已有其他生成均返回 HTTP 409。建立流之前的失败使用 HTTP Problem Details，建立流之后使用错误事件。客户端支持 UTF-8 跨数据块解析、心跳、重试去重与历史恢复。

每个会话通过短事务行锁和唯一索引限制一个活动轮次，模型请求在事务之外执行。累计正文定期保存，取消、超时、断连和删除会话终止生成；执行租约每秒续期，租约过期后恢复为中断状态。终态不可覆写，持久化失败时不得发送完成事件。

新增表结构由 `backend/src/main/resources/db/migration/V3__create_ai_conversations.sql` 定义。后端启动保持关闭自动迁移；本次只在隔离测试数据库执行脚本，共享服务器尚未创建这些表。运行智能问答前需要在目标数据库执行新增建表脚本，并设置上述模型配置。

## 6. 版本兼容与工程验证

工程初始化和新增依赖时，整体锁定运行时、框架、模型适配器、数据库驱动和客户端插件版本，依据对应版本的官方文档验证。

已核查文档中的兼容范围包括：Spring AI 2.0.x 对应 Spring Boot 4.0.x / 4.1.x；1.1 文档对应 Spring Boot 3.4.x / 3.5.x。Alibaba 适配组件还需核查其独立兼容矩阵。精确版本在初始化时确定，不直接拼接各组件的最新版本。

需要执行的验证：

1. 应用连通：客户端能够调用后端，后端能够访问数据库。
2. 注册登录：重复账号、错误密码、未登录访问、登录恢复和退出失效符合约定。
3. 植物档案：创建、查询、编辑和删除可持久化，不同账号的数据相互隔离。
4. 模型请求：文字与图片输入可用，结构化结果可解析，引用对应实际知识条目。
5. 流式链路：真机逐步显示回复，取消和断连后停止相关请求。
6. 知识导入：项目文件可重复导入，不产生重复条目，来源和许可可核查。
7. 总结：模型回复中的次数、时间范围和关键数值与程序统计一致。

验证结果随工程进展记录；候选方案和文档示例不代表已经执行验证。

2026-11-14：后端 `./mvnw -o -B -ntp clean verify` 通过 28 项测试并完成打包，其中智能问答 9 项集成测试覆盖持久化、重新启动、归属、去重、状态、工具调用、超时、断连、保存失败、配置缺失及非思考模式参数；客户端格式检查、`flutter analyze` 和全部 26 项测试通过。另使用真实 DeepSeek 官方模型完成两轮 SSE、实际植物工具查询、持久化连续问答和用量保存联调。测试使用隔离数据库及 Redis，未操作共享服务器；手机端尚未执行真机联调。

## 7. 相关官方资料

- [结构化输出与模型适配](https://docs.spring.io/spring-ai/reference/api/structured-output-converter.html)
- [模型图片输入](https://docs.spring.io/spring-ai/reference/api/multimodality.html)
- [向量存储集成配置](https://docs.spring.io/spring-ai/reference/api/vectordbs/pgvector.html)
- [会话记忆与完整历史](https://docs.spring.io/spring-ai/reference/api/chat-memory.html)
- [框架版本兼容范围](https://docs.spring.io/spring-ai/reference/getting-started.html)
- [Alibaba 组件版本兼容说明](https://java2ai.com/docs/versions)
- [DashScope 模型与图片参数](https://java2ai.com/integration/chatmodels/dashScope)
- [HTTP 流式响应与 SSE](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-async.html)
- [DeepSeek 官方调用说明与模型名称](https://api-docs.deepseek.com/)

官方在线文档会变化，应以最终锁定版本的文档与接口验证为准。
