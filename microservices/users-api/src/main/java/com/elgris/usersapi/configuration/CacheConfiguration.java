package com.elgris.usersapi.configuration;

import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.connection.jedis.JedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

/**
 * Configuración del patrón Cache-Aside para el microservicio users-api
 * 
 * Este patrón implementa:
 * 1. Verificar si los datos están en caché
 * 2. Si no están, obtenerlos de la base de datos
 * 3. Almacenar los datos en caché para futuras consultas
 * 4. Retornar los datos al cliente
 */
@Configuration
@EnableCaching
public class CacheConfiguration {

    /**
     * Configuración de conexión a Redis
     */
    @Bean
    public RedisConnectionFactory redisConnectionFactory() {
        JedisConnectionFactory factory = new JedisConnectionFactory();
        factory.setHostName(System.getProperty("redis.host", "localhost"));
        factory.setPort(Integer.parseInt(System.getProperty("redis.port", "6379")));
        factory.setUsePool(true);
        return factory;
    }

    /**
     * Template de Redis para operaciones de caché
     */
    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory connectionFactory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        
        // Configurar serializadores
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(new GenericJackson2JsonRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        template.setHashValueSerializer(new GenericJackson2JsonRedisSerializer());
        
        template.afterPropertiesSet();
        return template;
    }

    /**
     * Manager de caché usando Redis
     */
    @Bean
    public CacheManager cacheManager(RedisConnectionFactory connectionFactory) {
        RedisCacheManager cacheManager = new RedisCacheManager(redisTemplate(connectionFactory));
        cacheManager.setDefaultExpiration(300); // 5 minutes
        return cacheManager;
    }
}
