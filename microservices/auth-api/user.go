package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"

	jwt "github.com/dgrijalva/jwt-go"
	"github.com/sony/gobreaker"
)

var allowedUserHashes = map[string]interface{}{
	"admin_admin": nil,
	"johnd_foo":   nil,
	"janed_ddd":   nil,
}

type User struct {
	Username  string `json:"username"`
	FirstName string `json:"firstname"`
	LastName  string `json:"lastname"`
	Role      string `json:"role"`
}

type HTTPDoer interface {
	Do(req *http.Request) (*http.Response, error)
}

type UserService struct {
	Client            HTTPDoer
	UserAPIAddress    string
	AllowedUserHashes map[string]interface{}
	breaker           *gobreaker.CircuitBreaker
}

func (h *UserService) Login(ctx context.Context, username, password string) (User, error) {
	user, err := h.getUser(ctx, username)
	if err != nil {
		return user, err
	}

	userKey := fmt.Sprintf("%s_%s", username, password)

	if _, ok := h.AllowedUserHashes[userKey]; !ok {
		return user, ErrWrongCredentials // this is BAD, business logic layer must not return HTTP-specific errors
	}

	return user, nil
}

func (h *UserService) getUser(ctx context.Context, username string) (User, error) {
	var user User

	// La lógica de la petición ahora se ejecuta dentro del Circuit Breaker
	body, err := h.breaker.Execute(func() (interface{}, error) {
		token, err := h.getUserAPIToken(username)
		if err != nil {
			return nil, err
		}
		url := fmt.Sprintf("%s/users/%s", h.UserAPIAddress, username)
		req, _ := http.NewRequest("GET", url, nil)
		req.Header.Add("Authorization", "Bearer "+token)
		req = req.WithContext(ctx)

		resp, err := h.Client.Do(req)
		if err != nil {
			return nil, err
		}

		defer resp.Body.Close()
		bodyBytes, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return nil, err
		}

		if resp.StatusCode >= 500 { // Consideramos errores de servidor como fallos
			return nil, fmt.Errorf("servicio de usuarios no disponible: %s", string(bodyBytes))
		}

		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			return nil, fmt.Errorf("no se pudieron obtener los datos del usuario: %s", string(bodyBytes))
		}

		return bodyBytes, nil
	})

	if err != nil {
		// Si el error es del circuit breaker, este error se propagará
		return user, err
	}

	// Si la petición fue exitosa, decodificamos el cuerpo
	err = json.Unmarshal(body.([]byte), &user)
	return user, err
}

func (h *UserService) getUserAPIToken(username string) (string, error) {
	token := jwt.New(jwt.SigningMethodHS256)
	claims := token.Claims.(jwt.MapClaims)
	claims["username"] = username
	claims["scope"] = "read"
	return token.SignedString([]byte(jwtSecret))
}
