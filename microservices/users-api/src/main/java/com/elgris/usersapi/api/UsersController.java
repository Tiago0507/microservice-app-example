package com.elgris.usersapi.api;

import com.elgris.usersapi.models.User;
import com.elgris.usersapi.repository.UserRepository;
import io.jsonwebtoken.Claims;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.http.ResponseEntity;
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
    private CacheManager cacheManager;

    @RequestMapping(value = "/", method = RequestMethod.GET)
    public List<User> getUsers() {
        List<User> response = new LinkedList<>();
        userRepository.findAll().forEach(response::add);
        return response;
    }

    @RequestMapping(value = "/{username}",  method = RequestMethod.GET)
    public User getUser(HttpServletRequest request, @PathVariable("username") String username) {
        // 1. Revisar el caché primero
        Cache usersCache = cacheManager.getCache("users");
        Cache.ValueWrapper userWrapper = usersCache.get(username);

        if (userWrapper != null) {
            // 2. CACHE HIT: El usuario está en el caché
            logger.info("============== Cache Hit! Devolviendo usuario '{}' desde Redis. ==============", username);
            return (User) userWrapper.get();
        }

        // 3. CACHE MISS: El usuario no está en el caché
        logger.info("============== Cache Miss! Buscando usuario '{}' en la base de datos... ==============", username);

        Object requestAttribute = request.getAttribute("claims");
        if((requestAttribute == null) || !(requestAttribute instanceof Claims)){
            throw new RuntimeException("Did not receive required data from JWT token");
        }

        Claims claims = (Claims) requestAttribute;

        if (!username.equalsIgnoreCase((String)claims.get("username"))) {
            throw new AccessDeniedException("No access for requested entity");
        }

        User user = userRepository.findOneByUsername(username);

        // 4. Guardar el resultado en el caché para la próxima vez
        if (user != null) {
            usersCache.put(username, user);
        }

        return user;
    }

    @RequestMapping(value = "/{username}", method = RequestMethod.DELETE)
    @CacheEvict(value = "users", key = "#username") // <-- @CacheEvict sigue siendo la mejor opción aquí
    public ResponseEntity<Void> deleteUser(@PathVariable("username") String username) {
        logger.info("============== INVALIDANDO CACHÉ! Eliminando usuario '{}' de la base de datos y del caché... ==============", username);
        User user = userRepository.findOneByUsername(username);
        if (user != null) {
            userRepository.delete(user);
        }
        return ResponseEntity.ok().build();
    }
}