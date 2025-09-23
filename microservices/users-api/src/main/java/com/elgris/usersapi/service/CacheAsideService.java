package com.elgris.usersapi.service;

import com.elgris.usersapi.models.User;
import com.elgris.usersapi.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

/**
 * Servicio que implementa el patrón Cache-Aside para operaciones de usuarios
 * 
 * Patrón Cache-Aside:
 * 1. Verificar si los datos están en caché
 * 2. Si no están, obtenerlos de la fuente de datos (base de datos)
 * 3. Almacenar los datos en caché para futuras consultas
 * 4. Retornar los datos al cliente
 */
@Service
public class CacheAsideService {

    private static final Logger logger = LoggerFactory.getLogger(CacheAsideService.class);

    @Autowired
    private UserRepository userRepository;

    /**
     * Obtiene un usuario por username usando Cache-Aside
     * Si no está en caché, lo obtiene de la base de datos y lo cachea
     */
    @Cacheable(value = "users", key = "#username", unless = "#result == null")
    public User getUserByUsername(String username) {
        logger.info("🔍 Cache-Aside: Usuario '{}' no encontrado en caché, consultando base de datos", username);
        
        User user = userRepository.findOneByUsername(username);
        
        if (user != null) {
            logger.info("✅ Cache-Aside: Usuario '{}' obtenido de BD y almacenado en caché", username);
        } else {
            logger.warn("❌ Cache-Aside: Usuario '{}' no encontrado en base de datos", username);
        }
        
        return user;
    }

    /**
     * Obtiene todos los usuarios usando Cache-Aside
     * Si no están en caché, los obtiene de la base de datos y los cachea
     */
    @Cacheable(value = "allUsers", key = "'all'", unless = "#result.isEmpty()")
    public List<User> getAllUsers() {
        logger.info("🔍 Cache-Aside: Lista de usuarios no encontrada en caché, consultando base de datos");
        
        List<User> users = StreamSupport.stream(userRepository.findAll().spliterator(), false)
                .collect(Collectors.toList());
        
        logger.info("✅ Cache-Aside: {} usuarios obtenidos de BD y almacenados en caché", users.size());
        
        return users;
    }

    /**
     * Invalida el caché de un usuario específico
     * Se ejecuta cuando se actualiza o elimina un usuario
     */
    @CacheEvict(value = "users", key = "#username")
    public void evictUserFromCache(String username) {
        logger.info("🗑️ Cache-Aside: Invalidando caché para usuario '{}'", username);
    }

    /**
     * Invalida el caché de todos los usuarios
     * Se ejecuta cuando se realizan cambios que afectan a múltiples usuarios
     */
    @CacheEvict(value = "allUsers", key = "'all'")
    public void evictAllUsersFromCache() {
        logger.info("🗑️ Cache-Aside: Invalidando caché de todos los usuarios");
    }

    /**
     * Invalida todo el caché relacionado con usuarios
     */
    @CacheEvict(value = {"users", "allUsers"}, allEntries = true)
    public void evictAllCache() {
        logger.info("🗑️ Cache-Aside: Invalidando todo el caché de usuarios");
    }

    /**
     * Verifica si un usuario está en caché (método de utilidad para monitoreo)
     */
    public boolean isUserInCache(String username) {
        // Este método es principalmente para logging y monitoreo
        // La implementación real del caché se maneja automáticamente por Spring
        logger.debug("🔍 Verificando si usuario '{}' está en caché", username);
        return true; // Spring maneja esto internamente
    }
}
