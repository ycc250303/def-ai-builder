UPDATE ai_messages m
SET metadata = jsonb_build_object('model', t.model) || m.metadata
FROM ai_turns t
WHERE m.turn_id = t.id AND m.role = 'ASSISTANT';

ALTER TABLE ai_turns
    DROP COLUMN run_id,
    DROP COLUMN model,
    DROP COLUMN prompt_version;

ALTER TABLE ai_messages DROP COLUMN updated_at;
