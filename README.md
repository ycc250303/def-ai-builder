# def-ai-builder

面向个人植物主人的养护 MVP：植物档案、模拟环境监测、养护记录与提醒，以及结合植物知识和个体历史的 AI 养护助手。

Flutter 客户端示例在 `app/`，Spring Boot 后端在 `backend/`，容器部署在 `deploy/`。第一版可联网，保留简化账号与同步；暂不包含真实硬件接入、音乐或社交。

已选择 Flutter、Java / Spring Boot 和 PostgreSQL。当前开发顺序：工程搭建 → 唯一账号与密码注册登录 → 用户植物档案录入 → 权威植物知识资料整理与项目内保存。注册无需邮箱或短信验证。

- [单人植物养护 MVP：需求基线](docs/mvp-scope.md)
- [植物资料来源与参考产品的软件功能](docs/plant-knowledge-and-products.md)
- [单人植物养护 MVP：技术栈选型建议](docs/technology-selection.md)
