package com.def.plant.aiService.mapper;

import java.util.List;

import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import com.def.plant.aiService.dto.ConversationResponse;
import com.def.plant.aiService.dto.MessageResponse;
import com.def.plant.aiService.entity.AiTurn;

/** 会话持久化，所有入口显式限定登录用户；行锁只在短事务内持有。 */
@Mapper
public interface AiMapper {
    String CONVERSATION_COLUMNS = "id,scope,plant_id,title,created_at,updated_at";
    String TURN_SELECT = """
        SELECT t.id,t.conversation_id,t.request_id,t.run_id,t.status,t.error_code,
               u.content AS question,a.content,a.id AS assistant_message_id,t.sequence
        FROM ai_turns t JOIN ai_conversations c ON c.id=t.conversation_id
        JOIN ai_messages u ON u.turn_id=t.id AND u.sequence=0
        JOIN ai_messages a ON a.turn_id=t.id AND a.sequence=1
        """;

    @Select("SELECT " + CONVERSATION_COLUMNS + " FROM ai_conversations WHERE id=#{id} AND user_id=#{userId} FOR UPDATE")
    ConversationResponse lock(@Param("userId") long userId, @Param("id") String id);

    @Select("SELECT " + CONVERSATION_COLUMNS + " FROM ai_conversations WHERE id=#{id} AND user_id=#{userId}")
    ConversationResponse conversation(@Param("userId") long userId, @Param("id") String id);

    @Select("SELECT " + CONVERSATION_COLUMNS + " FROM ai_conversations WHERE user_id=#{userId} ORDER BY updated_at DESC,id LIMIT #{limit} OFFSET #{offset}")
    List<ConversationResponse> list(@Param("userId") long userId, @Param("offset") int offset, @Param("limit") int limit);

    @Insert("""
        INSERT INTO ai_conversations(id,user_id,scope,plant_id,title)
        VALUES(#{id},#{userId},#{scope},#{plantId},#{title})
        """)
    void create(@Param("id") String id, @Param("userId") long userId, @Param("scope") String scope,
            @Param("plantId") Long plantId, @Param("title") String title);

    @Select(TURN_SELECT + " WHERE c.user_id=#{userId} AND c.id=#{conversationId} AND t.id=#{id}")
    AiTurn turn(@Param("userId") long userId, @Param("conversationId") String conversationId, @Param("id") String id);

    @Select(TURN_SELECT + " WHERE c.user_id=#{userId} AND c.id=#{conversationId} AND t.request_id=#{requestId}")
    AiTurn byRequest(@Param("userId") long userId, @Param("conversationId") String conversationId,
            @Param("requestId") String requestId);

    @Select("""
        SELECT count(*) FROM ai_turns t JOIN ai_conversations c ON c.id=t.conversation_id
        WHERE c.id=#{id} AND c.user_id=#{userId} AND t.status IN ('ACCEPTED','STREAMING')
        """)
    int activeCount(@Param("userId") long userId, @Param("id") String id);

    @Insert("""
        INSERT INTO ai_turns(id,conversation_id,request_id,sequence,status,run_id,lease_until,model,prompt_version)
        SELECT #{id},#{conversationId},#{requestId},coalesce(max(sequence),0)+1,'ACCEPTED',#{runId},
            CURRENT_TIMESTAMP + INTERVAL '30 seconds',#{model},'plant-care-v1'
        FROM ai_turns WHERE conversation_id=#{conversationId}
        """)
    void createTurn(@Param("id") String id, @Param("conversationId") String conversationId,
            @Param("requestId") String requestId, @Param("runId") String runId, @Param("model") String model);

    @Insert("INSERT INTO ai_messages(id,turn_id,sequence,role,content) VALUES(#{id},#{turnId},#{sequence},#{role},#{content})")
    void createMessage(@Param("id") String id, @Param("turnId") String turnId, @Param("sequence") int sequence,
            @Param("role") String role, @Param("content") String content);

    @Update("UPDATE ai_conversations SET updated_at=CURRENT_TIMESTAMP WHERE id=#{id} AND user_id=#{userId}")
    void touch(@Param("userId") long userId, @Param("id") String id);

    @Select(TURN_SELECT + """
        WHERE c.user_id=#{userId} AND c.id=#{conversationId} AND t.status='COMPLETED'
        ORDER BY t.sequence DESC LIMIT #{limit}
        """)
    List<AiTurn> recent(@Param("userId") long userId, @Param("conversationId") String conversationId, @Param("limit") int limit);

    @Select("""
        SELECT m.id,m.turn_id,t.sequence,m.role,m.content,t.status,t.error_code,m.created_at
        FROM ai_messages m JOIN ai_turns t ON t.id=m.turn_id
        JOIN ai_conversations c ON c.id=t.conversation_id
        WHERE c.user_id=#{userId} AND c.id=#{id} AND t.sequence < #{before}
          AND t.sequence IN (SELECT sequence FROM ai_turns WHERE conversation_id=#{id}
                AND sequence < #{before} ORDER BY sequence DESC LIMIT #{limit})
        ORDER BY t.sequence,m.sequence
        """)
    List<MessageResponse> messages(@Param("userId") long userId, @Param("id") String id,
            @Param("before") long before, @Param("limit") int limit);

    @Update("""
        UPDATE ai_turns t SET status='INTERRUPTED',error_code='AI_INTERRUPTED',finished_at=CURRENT_TIMESTAMP
        FROM ai_conversations c WHERE c.id=t.conversation_id AND c.user_id=#{userId}
          AND c.id=#{conversationId} AND t.status IN ('ACCEPTED','STREAMING') AND t.lease_until < CURRENT_TIMESTAMP
        """)
    void recover(@Param("userId") long userId, @Param("conversationId") String conversationId);

    @Update("""
        UPDATE ai_turns t SET lease_until=CURRENT_TIMESTAMP + INTERVAL '30 seconds'
        FROM ai_conversations c WHERE c.id=t.conversation_id AND c.user_id=#{userId}
          AND t.id=#{id} AND t.run_id=#{runId} AND t.status IN ('ACCEPTED','STREAMING')
          AND t.lease_until >= CURRENT_TIMESTAMP
        """)
    int renew(@Param("userId") long userId, @Param("id") String id, @Param("runId") String runId);

    @Update("""
        UPDATE ai_messages m SET content=#{content},metadata=CAST(#{metadata} AS jsonb),updated_at=CURRENT_TIMESTAMP
        FROM ai_turns t JOIN ai_conversations c ON c.id=t.conversation_id
        WHERE m.turn_id=t.id AND m.sequence=1 AND t.id=#{id} AND c.user_id=#{userId}
        """)
    void saveContent(@Param("userId") long userId, @Param("id") String id,
            @Param("content") String content, @Param("metadata") String metadata);

    @Update("""
        UPDATE ai_turns t SET status=#{status},error_code=#{errorCode},
          finished_at=CASE WHEN #{status}='STREAMING' THEN NULL ELSE CURRENT_TIMESTAMP END
        FROM ai_conversations c WHERE c.id=t.conversation_id AND c.user_id=#{userId}
          AND t.id=#{id} AND t.run_id=#{runId} AND t.status IN ('ACCEPTED','STREAMING')
        """)
    int transition(@Param("userId") long userId, @Param("id") String id, @Param("runId") String runId,
            @Param("status") String status, @Param("errorCode") String errorCode);

    @Delete("DELETE FROM ai_conversations WHERE id=#{id} AND user_id=#{userId}")
    int delete(@Param("userId") long userId, @Param("id") String id);
}
