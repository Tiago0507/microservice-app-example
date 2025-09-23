package com.elgris.usersapi.api;

import com.elgris.usersapi.models.User;
import com.elgris.usersapi.repository.UserRepository;
import com.elgris.usersapi.service.CacheAsideService;
import io.jsonwebtoken.Claims;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.util.LinkedList;
import java.util.List;

@RestController()
@RequestMapping("/users")
public class UsersController {

    private static final Logger logger = LoggerFactory.getLogger(UsersController.class);

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CacheAsideService cacheAsideService;


    @RequestMapping(value = "/", method = RequestMethod.GET)
    public List<User> getUsers() {
        logger.info("📋 Obteniendo lista de usuarios usando Cache-Aside");
        return cacheAsideService.getAllUsers();
    }

    @RequestMapping(value = "/{username}",  method = RequestMethod.GET)
    public User getUser(HttpServletRequest request, @PathVariable("username") String username) {

        Object requestAttribute = request.getAttribute("claims");
        if((requestAttribute == null) || !(requestAttribute instanceof Claims)){
            throw new RuntimeException("Did not receive required data from JWT token");
        }

        Claims claims = (Claims) requestAttribute;

        if (!username.equalsIgnoreCase((String)claims.get("username"))) {
            throw new AccessDeniedException("No access for requested entity");
        }

        logger.info("👤 Obteniendo usuario '{}' usando Cache-Aside", username);
        return cacheAsideService.getUserByUsername(username);
    }

    /**
     * Endpoint para invalidar el caché de un usuario específico
     */
    @RequestMapping(value = "/cache/evict/{username}", method = RequestMethod.POST)
    public String evictUserCache(@PathVariable("username") String username) {
        logger.info("🗑️ Invalidando caché para usuario '{}'", username);
        cacheAsideService.evictUserFromCache(username);
        return "Cache invalidated for user: " + username;
    }

    /**
     * Endpoint para invalidar todo el caché de usuarios
     */
    @RequestMapping(value = "/cache/evict-all", method = RequestMethod.POST)
    public String evictAllCache() {
        logger.info("🗑️ Invalidando todo el caché de usuarios");
        cacheAsideService.evictAllCache();
        return "All user cache invalidated";
    }

    /**
     * Endpoint para verificar el estado del caché
     */
    @RequestMapping(value = "/cache/status", method = RequestMethod.GET)
    public String getCacheStatus() {
        logger.info("📊 Obteniendo estado del caché");
        return "Cache-Aside pattern is active. Use /cache/evict/{username} or /cache/evict-all to manage cache";
    }

}
