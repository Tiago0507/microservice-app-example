package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	jwt "github.com/dgrijalva/jwt-go"
	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	gommonlog "github.com/labstack/gommon/log"
	"github.com/sony/gobreaker"
)

var (
	// ErrHttpGenericMessage that is returned in general case, details should be logged in such case
	ErrHttpGenericMessage = echo.NewHTTPError(http.StatusInternalServerError, "something went wrong, please try again later")

	// ErrWrongCredentials indicates that login attempt failed because of incorrect login or password
	ErrWrongCredentials = echo.NewHTTPError(http.StatusUnauthorized, "username or password is invalid")

	jwtSecret = "myfancysecret"
)

func main() {
	hostport := ":" + os.Getenv("AUTH_API_PORT")
	userAPIAddress := os.Getenv("USERS_API_ADDRESS")

	envJwtSecret := os.Getenv("JWT_SECRET")
	if len(envJwtSecret) != 0 {
		jwtSecret = envJwtSecret
	}

	var st gobreaker.Settings
	st.Name = "users-api"
	st.MaxRequests = 1 // Peticiones en estado semi-abierto
	st.Interval = time.Minute * 5 // Ciclo para resetear contadores
	st.Timeout = time.Second * 10 // Tiempo para pasar de abierto a semi-abierto
	st.ReadyToTrip = func(counts gobreaker.Counts) bool {
		// Se abrirá el circuito después de 3 fallos consecutivos
		return counts.ConsecutiveFailures > 3
	}

	userService := UserService{
		Client:         http.DefaultClient,
		UserAPIAddress: userAPIAddress,
		AllowedUserHashes: map[string]interface{}{
			"admin_admin": nil,
			"johnd_foo":   nil,
			"janed_ddd":   nil,
		},
		breaker: gobreaker.NewCircuitBreaker(st),
	}

	e := echo.New()
	e.Logger.SetLevel(gommonlog.INFO)

	if zipkinURL := os.Getenv("ZIPKIN_URL"); len(zipkinURL) != 0 {
		e.Logger.Infof("init tracing to Zipkit at %s", zipkinURL)

		if tracedMiddleware, tracedClient, err := initTracing(zipkinURL); err == nil {
			e.Use(echo.WrapMiddleware(tracedMiddleware))
			userService.Client = tracedClient
		} else {
			e.Logger.Infof("Zipkin tracer init failed: %s", err.Error())
		}
	} else {
		e.Logger.Infof("Zipkin URL was not provided, tracing is not initialised")
	}

	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// Route => handler
	e.GET("/version", func(c echo.Context) error {
		return c.String(http.StatusOK, "Auth API, written in Go\n")
	})

	e.POST("/login", getLoginHandler(userService))

	// Start server
	e.Logger.Fatal(e.Start(hostport))
}

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func getLoginHandler(userService UserService) echo.HandlerFunc {
	f := func(c echo.Context) error {
		requestData := LoginRequest{}
		decoder := json.NewDecoder(c.Request().Body)
		if err := decoder.Decode(&requestData); err != nil {
			log.Printf("could not read credentials from POST body: %s", err.Error())
			return ErrHttpGenericMessage
		}

		ctx := c.Request().Context()
		user, err := userService.Login(ctx, requestData.Username, requestData.Password)
		if err != nil {
			if err == gobreaker.ErrOpenState {
				log.Printf("Petición rechazada para '%s' porque el Circuit Breaker está abierto.", requestData.Username)
				// Devolvemos 503 Service Unavailable
				return echo.NewHTTPError(http.StatusServiceUnavailable, "Servicio no disponible, por favor intente más tarde. El circuito está abierto.")
			}

			if err != ErrWrongCredentials {
				log.Printf("could not authorize user '%s': %s", requestData.Username, err.Error())
				return ErrHttpGenericMessage
			}

			return ErrWrongCredentials
		}
		token := jwt.New(jwt.SigningMethodHS256)

		// Set claims
		claims := token.Claims.(jwt.MapClaims)
		claims["username"] = user.Username
		claims["firstname"] = user.FirstName
		claims["lastname"] = user.LastName
		claims["role"] = user.Role
		claims["exp"] = time.Now().Add(time.Hour * 72).Unix()

		// Generate encoded token and send it as response.
		t, err := token.SignedString([]byte(jwtSecret))
		if err != nil {
			log.Printf("could not generate a JWT token: %s", err.Error())
			return ErrHttpGenericMessage
		}

		return c.JSON(http.StatusOK, map[string]string{
			"accessToken": t,
		})
	}

	return echo.HandlerFunc(f)
}
