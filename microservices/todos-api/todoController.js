'use strict';
const cache = require('memory-cache');
const {Annotation, 
    jsonEncoder: {JSON_V2}} = require('zipkin');
const RedisCircuitBreaker = require('./circuitBreaker');

const OPERATION_CREATE = 'CREATE',
      OPERATION_DELETE = 'DELETE';

class TodoController {
    constructor({tracer, redisClient, logChannel}) {
        this._tracer = tracer;
        this._redisClient = redisClient;
        this._logChannel = logChannel;
        this._circuitBreaker = new RedisCircuitBreaker(redisClient);
    }

    // TODO: these methods are not concurrent-safe
    list (req, res) {
        const data = this._getTodoData(req.user.username)

        res.json(data.items)
    }

    async create (req, res) {
        // TODO: must be transactional and protected for concurrent access, but
        // the purpose of the whole example app it's enough
        const data = this._getTodoData(req.user.username)
        const todo = {
            content: req.body.content,
            id: data.lastInsertedID
        }
        data.items[data.lastInsertedID] = todo

        data.lastInsertedID++
        this._setTodoData(req.user.username, data)

        await this._logOperation(OPERATION_CREATE, req.user.username, todo.id)

        res.json(todo)
    }

    async delete (req, res) {
        const data = this._getTodoData(req.user.username)
        const id = req.params.taskId
        delete data.items[id]
        this._setTodoData(req.user.username, data)

        await this._logOperation(OPERATION_DELETE, req.user.username, id)

        res.status(204)
        res.send()
    }

    async _logOperation (opName, username, todoId) {
        this._tracer.scoped(async () => {
            const traceId = this._tracer.id;
            const message = JSON.stringify({
                zipkinSpan: traceId,
                opName: opName,
                username: username,
                todoId: todoId,
            });
            
            try {
                await this._circuitBreaker.publishMessage(this._logChannel, message);
            } catch (error) {
                console.log('Failed to log operation to Redis:', error.message);
            }
        })
    }

    _getTodoData (userID) {
        var data = cache.get(userID)
        if (data == null) {
            data = {
                items: {
                    '1': {
                        id: 1,
                        content: "Create new todo",
                    },
                    '2': {
                        id: 2,
                        content: "Update me",
                    },
                    '3': {
                        id: 3,
                        content: "Delete example ones",
                    }
                },
                lastInsertedID: 3
            }

            this._setTodoData(userID, data)
        }
        return data
    }

    _setTodoData (userID, data) {
        cache.put(userID, data)
    }

    // Endpoint para monitorear el estado del Circuit Breaker
    getCircuitBreakerStatus (req, res) {
        const status = this._circuitBreaker.getStatus();
        res.json({
            circuitBreaker: status,
            timestamp: new Date().toISOString(),
            service: 'todos-api'
        });
    }
}

module.exports = TodoController