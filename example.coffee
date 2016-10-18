Mutex = require './source'
lock = new Mutex.Lock

testLock = (n) ->

  work = (done) ->
    console.log request.id, "working"
    setTimeout done.bind(null, null, n), 1000

  request = lock.sync work, (error, result) ->
    throw error if error?
    console.log request.id, "result", result

r1 = testLock 1
r2 = testLock 2
r3 = testLock 3
r4 = testLock 4

setTimeout lock.removeRequest.bind(lock, r2.id), 500
