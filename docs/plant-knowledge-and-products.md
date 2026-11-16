# 植物资料来源与参考产品的软件功能

核查日期：2026-11-12。本文基于可访问的官方网站、官方帮助中心、开发者 API 文档和 App Store 的开发者描述；没有实际购买、登录或逐一测试这些 App。产品描述属于厂商声明，不能代替效果测评。

## 1. 对本项目最相关的产品结论

### 形色：识别和内容体验的参考

核查了[形色官网](https://www.xingse.net/)和[中国区 App Store 条目](https://apps.apple.com/cn/app/id1018747351)。公开说明主要包含：拍照识花、植物百科/植物介绍、植物趣闻、专家文章、达人鉴定、花语与图片内容。

适合参考「选定植物 → 查看知识」的流程。不能仅凭这些页面认定它有自动连续传感器监测、基于硬件历史数据的个性化 AI 对话或周报。

### 形色养花：更直接的养护参考

[中国区 App Store 条目](https://apps.apple.com/cn/app/id1626994454)公开列出智能浇水/施肥提醒、光度计、照片识别、植物诊断及处理/预防说明。

比形色主应用更接近本次的基础养护与照片分析。公开条目并未证明它具备连续土壤传感数据或基于长期测量历史的 AI 总结；手机光度计也不能视为持续安装在花盆上的照度传感器。

### PictureThis：可作为补充的软件参考

核查了[官网](https://www.picturethisai.com/)与[美国区 App Store 条目](https://apps.apple.com/us/app/id1252497129)。开发者说明包含植物识别、照片病害分析、养护提示、浇水记录与提醒、光度计、植物收藏管理及专家咨询。

适合参考「识别/建档 → 养护指南 → 提醒 → 异常分析」闭环。这里的专家咨询不能直接等同于与本项目相同的 LLM 聊天；公开说明也不足以推断内部数据库、模型架构、传感器接入能力和长期报告实现。

形色、形色养花和 PictureThis 是不同上架条目，不将其功能混合成单一产品的事实清单。

### PlantsIO Ivy：设备状态到养护解释的参考

用户给出的[具体商店产品页](https://store.plantsio.com/products/ivy-gen-2-easter-edit)在本次访问中返回 HTTP 429。另读取了[官方首页](https://www.plantsio.com/)、[官方使用指南目录](https://help.plantsio.com/en/categories/using-ivy)和[官方 FAQ](https://help.plantsio.com/en/categories/faq)，并进一步读取下列具体文章：

- [土壤湿度未校准](https://help.plantsio.com/en/articles/1765786231-why-does-the-soil-moisture-status-show-uncalibrated)：厂商说明初次使用需要适应植物与土壤，通常经过 1–2 个浇水周期自动校准；此前显示的是参考土壤基础上的数值。
- [光照建议](https://help.plantsio.com/en/articles/1762439554-is-ivy-s-light-suggestion-reliable)：厂商说明结合光强和持续时间；传感器遮挡与位置影响结果，App 有环境光页面及手动光照模式。
- [浇水面板](https://help.plantsio.com/en/articles/1765864972-what-does-the-watering-panel-mean)：描述当前水箱水位、目标范围、过量警告与初始化状态。水箱水位和土壤含水情况是不同概念。
- [Wi-Fi 连接](https://help.plantsio.com/en/articles/1762400568-does-ivy-need-a-wi_fi-connection)：描述联网用于 OTA、植物数据分析、天气时间同步和自定义动画；配网时通过蓝牙帮助发现设备。
- [电子手册入口](https://help.plantsio.com/en/articles/1762422195-electronic-user-manual)：确认官方提供 Gen 2 用户手册下载；本次未逐页核查手册 PDF。

适合本项目借鉴的重点是：数据状态与质量必须对用户可见；光照不能只看瞬时值；提醒应解释原因与下一步行动；设备网络状态需要与应用联网状态区分。

不据此声称 Ivy 已验证有本项目所需的完整 AI 聊天、照片诊断、历史曲线和周报。其土壤校准算法也不能从帮助文章中还原，MVP 无需复刻。

### PlantWave：音乐体验的参考，本次优先级低

读取了[官方首页](https://plantwave.com/en-hk)。其公开的软件流程是连接植物上的设备、通过 iOS/Android App 无线连接、选择 soundsets 并播放声音。厂商将植物信号变化转成音高等音乐表现，页面也介绍了调式/音阶等体验。

本次排除音乐，因此只需了解其「硬件数据 → 软件反馈」形式，不把它作为养护、诊断或权威植物知识库的主要参考。官方音乐描述不构成植物健康状态的诊断证据。

### Sprout：保留为候选，软件细节待核实

用户提供的[James Dyson Award 项目页](https://www.jamesdysonaward.org/en-US/2026/project/sprout/)及全局路径本次均返回 HTTP 403，未获取项目正文。Figma 中的讨论记录可以作为团队已有想法，但不代替项目官方证据。

因此不将其是否已有 App、AI 对话、养护算法、设备协议等写成已验证事实；本次功能基线不依赖它。

## 2. 为什么不能只找「一个权威植物数据库」

本项目需要三种不同资料：

1. 名称与分类：这是哪种植物，接受名、异名、科属与外部 ID 是什么。
2. 栽培养护：在什么环境、介质和季节下，如何浇水、提供光照、换盆及排查问题。
3. 具体个体状态：用户这盆植物当前读数、养护历史、照片与摆放位置。

植物志与分类库擅长第一类；园艺机构和大学推广资料更适合第二类；第三类来自本产品自己积累。照片识别和异常分析 API 属于模型服务，不天然等同于权威养护知识库。

在本次核查范围内，没有发现能直接提供「全面中文物种信息 + 通用且经验证的传感器告警阈值 + 病害诊断 + 自由商用」的单一来源。

## 3. 名称、分类与中文资料

### World Flora Online（WFO）：建议的首选分类底座

- 来源：[官方网站](https://www.worldfloraonline.org/)、[数据下载与许可说明](https://www.worldfloraonline.org/downloadData)。
- 本次直接确认：提供可下载的 Taxonomic Backbone，用于名称与分类标准化；下载页将这份分类骨架标为 Public Domain CC0 1.0。
- 首页一般文本/图片说明为 CC BY 4.0，且注明另有标注时例外。因此分类骨架许可不能自动推广到所有图片和全文。
- 适合保存标准学名、接受名/异名关系、科属与 WFO 标识；本次未下载全量数据，也未完成物种逐条导入。
- 不直接提供可用于本项目的统一土壤湿度或照度阈值。

MVP 不需要先导入全球分类。先手动校对支持的少量物种，并记录 WFO ID 与资料版本即可。

### Kew WCVP / Plants of the World Online（POWO）：交叉核对候选

- 来源：[POWO](https://powo.science.kew.org/)、[WCVP 公开下载目录](https://sftp.kew.org/pub/data-repositories/WCVP/)。
- 本次 POWO 关于页与 Kew 说明页返回 HTTP 403；公开下载目录可访问，列出了 `wcvp.zip` 和 `wcvp_dwca.zip`。
- Kew 的名称与分类资源适合作为接受名、异名和分布的交叉核对来源；本次未下载压缩包，未核查包内许可和字段，不能声称已经具备可直接导入的完整资料。
- 不把其内容当作盆栽湿度告警阈值库。

### GBIF：便于程序查询和名称匹配

- 来源：[Species API 官方文档](https://techdocs.gbif.org/en/openapi/v1/species)。
- 本次实际读取公开名称匹配接口：[`Epipremnum aureum` 示例](https://api.gbif.org/v1/species/match?name=Epipremnum%20aureum)。返回接受种名、科属、匹配类型和 `usageKey=2868323`。
- 适合名称校对和外部 ID 映射；不同分类底座版本可能存在差异，应保留采用的来源及版本。
- API 可访问不等于其聚合的所有图片/原始数据都具有同一再利用许可；按实际采用数据核查。
- 缺少完整的室内植物养护规则，不能据此直接生成浇水阈值。

### IPNI：名称发表信息补充，不负责裁定接受名

- 来源：[官方首页](https://www.ipni.org/)。
- 官网明确提供学名拼写、作者、模式和首次发表地点/日期等命名学资料；分类数据另引向 POWO。
- 适合核对命名信息；不要把 IPNI 中「收录一个名字」误解为该名当前被接受，也不作为养护资料源。

### 植物智 / 中国植物志 / Flora of China：中文信息候选

- 来源：[植物智](http://www.iplant.cn/)。本次读取了首页，确认其汇集《中国植物志》、Flora of China、图库、标本与名称校对入口；页脚标明中国科学院植物研究所。
- 适合中文名、形态描述、中国分布、科属及中文知识校对。
- 本次未确认通用开放批量 API、全文/图片再发布授权或可直接商用的统一许可，不建议按「网站可访问」就自动整站入库。
- 植物志的生态分布描述并不自动等于室内栽培说明。

## 4. 养护资料

### NC State Extension Gardener Plant Toolbox：首版养护资料重点候选

- 来源：[绿萝 `Epipremnum aureum` 物种页](https://plants.ces.ncsu.edu/plants/epipremnum-aureum/)。
- 本次实际读到明亮间接光、浇水间让排水良好的介质变干、过度浇水与根腐/叶缘发黑、低光影响斑锦等说明；页面还提供形态、毒性及常见问题信息。
- 适合整理「需求偏好—观察现象—建议检查」等有出处的知识条目。
- 图片逐张显示作者与许可，含 CC BY、CC BY-SA、CC BY-NC、CC BY-NC-ND 等不同情况，不能统称整站图片可自由商用；正文再利用范围另需确认。
- 该页没有给出适用于所有花盆和传感器的「湿度低于某百分比就浇水」规则。

### RHS：园艺养护补充

- 来源：[RHS 室内植物入口](https://www.rhs.org.uk/plants/types/houseplants)。
- 本次确认其室内植物内容覆盖光照、浇水、施肥、湿度、换盆、介质和繁殖等主题。
- 适合作为栽培建议的交叉核对来源；具体物种内容需要后续逐条确认，不能用普通网页可读性推断批量 API 或内容授权。
- 地区、季节和种植环境影响建议适用性，应将条件一同保留。

## 5. 可接入的商业/聚合 API 候选

### Perenual

- 来源：[API 文档](https://perenual.com/docs/api)。
- 本次读到物种列表、详情、养护指南等接口及浇水、日照、介质、病虫害、毒性和图片许可字段；接口需要 API key。
- 适合快速获取结构化候选数据，但不因字段齐全就将其视为每条结论均由权威园艺机构审核。
- 实际物种覆盖、中文内容、套餐权限、调用额度、缓存/再发布条款尚未用付费账号核实；文档示例不代表所有物种返回完整值。

### Kindwise plant.id / plant.health

- 来源：[plant.id 官方介绍](https://www.kindwise.com/plant-id)。
- 本次读到照片识别、名称/分类、多语言详情和部分养护字段；页面列有 plant.health 产品入口。
- 适合将来评估照片识别与异常分析服务，不作为本次已选定的模型服务。
- 官网覆盖表中 watering 字段仅覆盖约 9.50% 的植物，说明「能识别很多植物」不等于「这些植物都有完整养护资料」。该比例是本次访问到的厂商声明。
- plant.health 的详细响应、效果、计费和许可本次未逐项核查。

### Trefle

- 来源：[官方文档](https://docs.trefle.io/)、[字段解释](https://docs.trefle.io/docs/advanced/plants-fields/)。
- 本次读取到分类、形态、分布、生长属性与来源字段；未使用 token 实测完整查询。
- 文档明确 `light`、`soil_humidity`、`atmospheric_humidity` 等部分字段属于生态指示等级，而非具体植物的传感器测量或栽培容忍阈值。例如光照等级不能直接当作 lux，土壤湿度等级也不能直接当作含水百分比。
- 不建议未经验证就拿这些字段驱动本项目的实时告警。

## 6. 俗名目录与养护查询

目录包含绿萝、龟背竹、吊兰、虎皮兰、金钱树、玉树、芦荟、橡皮树和仙人球。用户直接使用俗名，仙人球按类别提供养护参考，不要求学名或具体物种确认。

- 项目文件为 `data/plant-knowledge/catalog.json`，包含版本、核查日期、引用许可状态、俗名、中文别名、英文检索名称和首选来源路径，不设置学名字段。
- 文件随后端安装包交付；应用加载时检查重复名称、英文名称和来源路径。Docker 构建和后端发布路径检测包含此目录。
- 已收录名称采用核实的英文名称；其他俗名由 Agent 翻译，最多三个英文检索名称。
- 运行时名称搜索使用 `GET /find_a_plant/?q=英文名称`，只解析直接结果，按来源路径去重，再读取最多三页详情。已收录类别只选择目录中核实的来源页面。
- `topics` 指定光照、浇水、基质、温度、空气湿度、施肥、修剪、换盆、繁殖、常见问题或毒性。结构化字段与 Description 完整段落作为英文证据交给 Agent 翻译。
- 每份结果包含实际来源网址、获取时间和未提取到明确说明的主题。保留季节、基质和环境条件；类别参考不构成统一数值阈值。
- 工具原文仅供当轮查询，不将来源全文或图片存入项目。最终回复中的来源链接随会话正文保存，完整工具执行轨迹仍为扩展项。
- 规则配置需另行记录数据项、单位、持续条件、有效时段、触发与恢复逻辑、依据及版本。定性养护描述不能直接生成传感器阈值。

## 7. 网站查询结构与使用边界

2026-11-15 核查了首页、搜索表单、帮助说明、前端公开脚本和详情页：

- [名称搜索说明](https://extensiongardener.ces.ncsu.edu/2022/01/how-to-use-a-plant-name-to-search-the-eg-toolbox-for-the-plant-profile-images-and-videos/)：支持英文俗名和学名；实际 `q=golden+pothos` 返回一个直接结果，`q=绿萝` 和 `q=pothos+watering` 没有直接结果。植物名称与查询主题需要分开。
- 搜索自动补全为 `/autocomplete/?term=名称`，返回 `category`、`label`、`slug`；属于网站前端接口。植物列表按 `page` 分页，可切换 `/find_a_plant/common-name/` 展示俗名，同一植物会以多个名称出现。
- [标签说明](https://extensiongardener.ces.ncsu.edu/extension-gardener-plant-toolbox/how-to-use-tags/)：`tag=houseplant` 等标签可筛选植物。
- [环境筛选说明](https://extensiongardener.ces.ncsu.edu/extension-gardener-plant-toolbox/how-to-select-a-plant-using-extension-gardener-plant-toolbox/)：`light__id`、`plant_type__id` 等参数用于选择适合某环境的植物。养护主题查询直接读取详情，避免预先筛掉不符合某种条件的条目。
- `/ajax_filters/` 为筛选表单的前端数据接口，包含环境、景观、植株和花叶特征字段；不作为独立养护正文 API。
- 搜索结果为零时仍可能展示推荐链接，解析以 `plant_object_count` 和 `plant_list` 中的直接结果为准。
- 正文再利用与图片许可仍需逐条核实。当前目录的 `REFERENCE_ONLY` 表示仅保存名称及引用信息，不授予来源正文或图片的再分发许可。

## 8. 验证范围

九类俗名均已通过真实 NC State 网站的光照和浇水查询验证，仙人球取得两份类别参考。资料 HTTP 客户端显式直连；自动测试使用自行编写的结构样例和隔离服务，覆盖系统代理不可用、零结果建议列表、名称映射、去重、主题证据、参数边界、响应超限、超时和来源失败。

2026-11-16：通过 Flutter Web 页面注册测试账号、进入对话并发送“仙人球怎么养”，真实 DeepSeek 模型完成流式回复，引用 Parodia 与 Echinopsis oxygona 两份 NC State 资料。回复覆盖光照、干湿交替、排水、冬季减水及常见问题；历史消息保存为 `COMPLETED`，正文与最终生成结果一致。数据库和 Redis 使用隔离容器。

专业养护质量仍需结合用户场景评测；来源正文许可、数值阈值校准、照片分析和长期总结尚未完成。
