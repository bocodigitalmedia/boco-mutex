class Dependencies
  Error: null
  EventEmitter: null
  UUID: null

  constructor: (props) ->
    @[key] = val for own key, val of props
    @Error ?= try Error
    @EventEmitter ?= try require 'events'
    @UUID ?= try require 'uuid'

configure = (props) ->
  {
    Error
    EventEmitter
    UUID
  } = dependencies = new Dependencies props

  class Exception extends Error
    @getMessage: (payload) -> null

    payload: null

    constructor: (payload) ->
      super()

      @name = @constructor.name
      @payload = payload
      @message = @constructor.getMessage payload

      if typeof Error.captureStackTrace is 'function'
        Error.captureStackTrace @, @constructor

  class ReleaseException extends Exception
    @getMessage: -> "Cannot release."

  class NotLocked extends ReleaseException
    @getMessage: -> "Cannot release, not currently locked."

  class LockRequestMismatch extends ReleaseException
    @getMessage: ({requestId}) -> "Cannot release using LockRequest '#{requestId}', not current LockRequest."

  class LockRequestNotFound extends ReleaseException
    @getMessage: ({requestId}) -> "LockRequest not found: '#{requestId}'."

  class LockRequest
    id: null
    callback: null
    releaseListener: null
    lock: null

    constructor: (props) ->
      @[key] = val for own key, val of props
      @id ?= UUID()

  class Lock
    locked: null
    currentRequestId: null
    emitter: null
    requests: null

    constructor: (props) ->
      @[key] = val for own key, val of props

      @locked ?= false
      @currentRequestId ?= null
      @emitter ?= new EventEmitter
      @requests ?= {}

    grantRequest: (requestId, done) ->
      @locked = true
      @currentRequestId = requestId

      setImmediate =>
        release = @release.bind @, requestId
        done null, release

    attemptGrantRequest: (requestId, done) ->
      return @grantRequest requestId, done unless @locked

      request = @getRequest requestId

      request.releaseListener = =>
        @attemptGrantRequest requestId, done

      @emitter.once 'release', request.releaseListener

    hasRequest: (requestId) ->
      @requests[requestId]?

    getRequest: (requestId) ->
      throw new LockRequestNotFound {requestId} unless @hasRequest requestId
      @requests[requestId]

    request: (done) ->
      request = new LockRequest {callback: done, lock: @}
      @requests[request.id] = request
      @attemptGrantRequest request.id, done
      request

    release: (requestId) ->
      throw new NotLocked unless @locked
      throw new LockRequestMismatch {requestId} unless requestId is @currentRequestId

      @locked = false
      @currentRequestId = null
      @removeRequest requestId
      @emitter.emit 'release'

    removeRequest: (requestId) ->
      request = @getRequest requestId
      listener = request.releaseListener

      @emitter.removeListener 'release', listener if listener?

      delete @requests[requestId]

    sync: (work, done) ->
      @request (error, release) =>
        return done error if error?

        work (error, results...) ->
          done error, results...
          release()

  class LockManager
    locks: null

    constructor: (props) ->
      @[key] = val for own key, val of props
      @locks ?= {}
      @Lock ?= Lock

    construct: ->
      new @Lock

    get: (id) ->
      @locks[id] ?= @construct()

  {
    configure
    dependencies
    Dependencies
    Exception
    ReleaseException
    NotLocked
    LockRequestMismatch
    LockRequestNotFound
    Lock
    LockManager
    LockRequest
  }


module.exports = configure()
