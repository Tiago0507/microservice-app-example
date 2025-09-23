'use strict';

const CircuitBreaker = require('opossum');

/**
 * Circuit Breaker para operaciones de Redis
 * Implementa el patrón Circuit Breaker para manejar fallos en la comunicación con Redis
 */
class RedisCircuitBreaker {
    constructor(redisClient) {
        this.redisClient = redisClient;
        this.circuitBreaker = null;
        this.initializeCircuitBreaker();
    }

    initializeCircuitBreaker() {
        // Configuración del Circuit Breaker
        const options = {
            timeout: 3000,           // Timeout de 3 segundos
            errorThresholdPercentage: 50,  // Abre el circuito si 50% de las llamadas fallan
            resetTimeout: 30000,    // Intenta cerrar el circuito después de 30 segundos
            rollingCountTimeout: 10000,  // Ventana de tiempo para contar errores
            rollingCountBuckets: 10,     // Número de buckets para la ventana deslizante
            name: 'redis-circuit-breaker',
            group: 'redis-operations'
        };

        // Crear el Circuit Breaker para operaciones de Redis
        this.circuitBreaker = new CircuitBreaker(this.executeRedisOperation.bind(this), options);

        // Event listeners para monitoreo
        this.circuitBreaker.on('open', () => {
            console.log('🔴 Circuit Breaker OPENED - Redis operations are failing');
        });

        this.circuitBreaker.on('halfOpen', () => {
            console.log('🟡 Circuit Breaker HALF-OPEN - Testing Redis connection');
        });

        this.circuitBreaker.on('close', () => {
            console.log('🟢 Circuit Breaker CLOSED - Redis operations are working');
        });

        this.circuitBreaker.on('failure', (error) => {
            console.log('❌ Circuit Breaker FAILURE:', error.message);
        });

        this.circuitBreaker.on('success', () => {
            console.log('✅ Circuit Breaker SUCCESS - Redis operation completed');
        });
    }

    /**
     * Ejecuta una operación de Redis con manejo de errores
     */
    async executeRedisOperation(operation) {
        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                reject(new Error('Redis operation timeout'));
            }, 2000);

            try {
                operation((error, result) => {
                    clearTimeout(timeout);
                    if (error) {
                        reject(error);
                    } else {
                        resolve(result);
                    }
                });
            } catch (error) {
                clearTimeout(timeout);
                reject(error);
            }
        });
    }

    /**
     * Publica un mensaje en Redis con Circuit Breaker
     */
    async publishMessage(channel, message) {
        try {
            const result = await this.circuitBreaker.fire((callback) => {
                this.redisClient.publish(channel, message, callback);
            });
            return result;
        } catch (error) {
            console.log('🚫 Redis publish failed, using fallback:', error.message);
            // Fallback: log to console instead of Redis
            console.log(`[FALLBACK] Message for channel ${channel}: ${message}`);
            return 'fallback-success';
        }
    }

    /**
     * Obtiene el estado del Circuit Breaker
     */
    getStatus() {
        return {
            state: this.circuitBreaker.state,
            stats: this.circuitBreaker.stats,
            isOpen: this.circuitBreaker.opened,
            isHalfOpen: this.circuitBreaker.halfOpen,
            isClosed: this.circuitBreaker.closed
        };
    }

    /**
     * Cierra manualmente el Circuit Breaker
     */
    close() {
        this.circuitBreaker.close();
    }

    /**
     * Abre manualmente el Circuit Breaker
     */
    open() {
        this.circuitBreaker.open();
    }
}

module.exports = RedisCircuitBreaker;
