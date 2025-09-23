package com.elgris.usersapi.configuration;

import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.connection.RedisConnectionFactory;

import java.util.HashMap;
import java.util.Map;

@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public RedisCacheManager cacheManager(RedisTemplate<Object, Object> redisTemplate) {
        RedisCacheManager cacheManager = new RedisCacheManager(redisTemplate);
        
        // Establecer un tiempo de expiración por defecto de 10 minutos para cualquier caché
        cacheManager.setDefaultExpiration(600); 

        // Opcional: Configurar TTL específico para el caché de 'users'
        Map<String, Long> expires = new HashMap<>();
        expires.put("users", 3600L); // 1 hora de TTL para el caché 'users'
        cacheManager.setExpires(expires);
        
        return cacheManager;
    }

    @Bean
    public RedisTemplate<Object, Object> redisTemplate(RedisConnectionFactory connectionFactory) {
        RedisTemplate<Object, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        return template;
    }
}