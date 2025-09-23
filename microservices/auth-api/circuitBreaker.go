package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/sony/gobreaker"
)

// CircuitBreakerConfig configuración del Circuit Breaker
type CircuitBreakerConfig struct {
	MaxRequests   uint32        // Número máximo de requests antes de evaluar el estado
	Interval      time.Duration // Intervalo de tiempo para evaluar el estado
	Timeout       time.Duration // Timeout para cada request
	ReadyToTrip   func(counts gobreaker.Counts) bool
	OnStateChange func(name string, from gobreaker.State, to gobreaker.State)
}

// DefaultCircuitBreakerConfig configuración por defecto del Circuit Breaker
func DefaultCircuitBreakerConfig() CircuitBreakerConfig {
	return CircuitBreakerConfig{
		MaxRequests: 3,
		Interval:    time.Second * 10,
		Timeout:     time.Second * 3,
		ReadyToTrip: func(counts gobreaker.Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
		OnStateChange: func(name string, from gobreaker.State, to gobreaker.State) {
			log.Printf("🔄 Circuit Breaker '%s' changed from %v to %v", name, from, to)
		},
	}
}

// HTTPCircuitBreaker wrapper del Circuit Breaker para operaciones HTTP
type HTTPCircuitBreaker struct {
	breaker *gobreaker.CircuitBreaker
	client  *http.Client
	name    string
}

// NewHTTPCircuitBreaker crea una nueva instancia del Circuit Breaker HTTP
func NewHTTPCircuitBreaker(name string, config CircuitBreakerConfig) *HTTPCircuitBreaker {
	settings := gobreaker.Settings{
		Name:        name,
		MaxRequests: config.MaxRequests,
		Interval:    config.Interval,
		Timeout:     config.Timeout,
		ReadyToTrip: config.ReadyToTrip,
		OnStateChange: config.OnStateChange,
	}

	return &HTTPCircuitBreaker{
		breaker: gobreaker.NewCircuitBreaker(settings),
		client: &http.Client{
			Timeout: config.Timeout,
		},
		name: name,
	}
}

// Execute ejecuta una operación HTTP con Circuit Breaker
func (cb *HTTPCircuitBreaker) Execute(ctx context.Context, req *http.Request) (*http.Response, error) {
	result, err := cb.breaker.Execute(func() (interface{}, error) {
		// Crear una copia del request con el contexto
		reqWithCtx := req.WithContext(ctx)
		
		// Ejecutar la request HTTP
		resp, err := cb.client.Do(reqWithCtx)
		if err != nil {
			log.Printf("❌ Circuit Breaker '%s' HTTP request failed: %v", cb.name, err)
			return nil, err
		}

		// Verificar el código de estado HTTP
		if resp.StatusCode >= 500 {
			resp.Body.Close()
			err := fmt.Errorf("HTTP error: %d", resp.StatusCode)
			log.Printf("❌ Circuit Breaker '%s' HTTP error: %v", cb.name, err)
			return nil, err
		}

		log.Printf("✅ Circuit Breaker '%s' HTTP request successful: %d", cb.name, resp.StatusCode)
		return resp, nil
	})

	if err != nil {
		return nil, err
	}

	return result.(*http.Response), nil
}

// GetState retorna el estado actual del Circuit Breaker
func (cb *HTTPCircuitBreaker) GetState() gobreaker.State {
	return cb.breaker.State()
}

// GetCounts retorna las estadísticas del Circuit Breaker
func (cb *HTTPCircuitBreaker) GetCounts() gobreaker.Counts {
	return cb.breaker.Counts()
}

// GetName retorna el nombre del Circuit Breaker
func (cb *HTTPCircuitBreaker) GetName() string {
	return cb.name
}

// IsOpen verifica si el Circuit Breaker está abierto
func (cb *HTTPCircuitBreaker) IsOpen() bool {
	return cb.breaker.State() == gobreaker.StateOpen
}

// IsHalfOpen verifica si el Circuit Breaker está medio abierto
func (cb *HTTPCircuitBreaker) IsHalfOpen() bool {
	return cb.breaker.State() == gobreaker.StateHalfOpen
}

// IsClosed verifica si el Circuit Breaker está cerrado
func (cb *HTTPCircuitBreaker) IsClosed() bool {
	return cb.breaker.State() == gobreaker.StateClosed
}

// GetStatus retorna el estado completo del Circuit Breaker
func (cb *HTTPCircuitBreaker) GetStatus() map[string]interface{} {
	counts := cb.GetCounts()
	state := cb.GetState()
	
	return map[string]interface{}{
		"name":           cb.name,
		"state":          state.String(),
		"requests":       counts.Requests,
		"totalSuccesses": counts.TotalSuccesses,
		"totalFailures":  counts.TotalFailures,
		"consecutiveSuccesses": counts.ConsecutiveSuccesses,
		"consecutiveFailures": counts.ConsecutiveFailures,
		"isOpen":         cb.IsOpen(),
		"isHalfOpen":     cb.IsHalfOpen(),
		"isClosed":       cb.IsClosed(),
	}
}
