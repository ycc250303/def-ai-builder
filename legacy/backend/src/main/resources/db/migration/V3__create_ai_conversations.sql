CREATE TABLE ai_conversations (
    id VARCHAR(36) PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    scope VARCHAR(10) NOT NULL CHECK (scope IN ('GENERAL', 'PLANT')),
    plant_id BIGINT REFERENCES plants(id) ON DELETE SET NULL,
    title VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (scope = 'PLANT' OR plant_id IS NULL)
);
CREATE INDEX ai_conversations_owner ON ai_conversations(user_id, updated_at DESC, id);

CREATE TABLE ai_turns (
    id VARCHAR(36) PRIMARY KEY,
    conversation_id VARCHAR(36) NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
    request_id VARCHAR(36) NOT NULL,
    sequence BIGINT NOT NULL CHECK (sequence > 0),
    status VARCHAR(16) NOT NULL CHECK (status IN ('ACCEPTED', 'STREAMING', 'COMPLETED', 'FAILED', 'CANCELLED', 'INTERRUPTED')),
    error_code VARCHAR(64),
    run_id VARCHAR(36) NOT NULL,
    lease_until TIMESTAMPTZ NOT NULL,
    model VARCHAR(100) NOT NULL,
    prompt_version VARCHAR(30) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMPTZ,
    UNIQUE (conversation_id, request_id),
    UNIQUE (conversation_id, sequence)
);
CREATE UNIQUE INDEX ai_turns_one_active ON ai_turns(conversation_id)
    WHERE status IN ('ACCEPTED', 'STREAMING');

CREATE TABLE ai_messages (
    id VARCHAR(36) PRIMARY KEY,
    turn_id VARCHAR(36) NOT NULL REFERENCES ai_turns(id) ON DELETE CASCADE,
    sequence INTEGER NOT NULL CHECK (sequence >= 0),
    role VARCHAR(10) NOT NULL CHECK (role IN ('USER', 'ASSISTANT', 'TOOL')),
    content TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (turn_id, sequence)
);
COMMENT ON TABLE ai_conversations IS '按登录用户隔离的养护会话';
COMMENT ON TABLE ai_turns IS '单次问答执行记录及生成租约';
COMMENT ON TABLE ai_messages IS '持久化对话正文与扩展元数据';
COMMENT ON COLUMN ai_conversations.scope IS 'GENERAL 普通问答，PLANT 指定植物问答';
COMMENT ON COLUMN ai_turns.request_id IS '客户端重试去重编号，同一会话内唯一';
COMMENT ON COLUMN ai_turns.run_id IS '执行标识，旧执行不得修改新状态';
COMMENT ON COLUMN ai_turns.lease_until IS '执行租约截止时间，过期后标记中断';
COMMENT ON COLUMN ai_messages.metadata IS '引用、用量及工具消息扩展内容';
