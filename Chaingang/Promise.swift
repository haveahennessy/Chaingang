//
//  Promise.swift
//  Chaingang
//
//  Created by Matt Isaacs.
//  Copyright (c) 2014 Matt Isaacs. All rights reserved.
//

import LlamaKit

// Clojure Style promises.

public class Promise<T> {
    let condition = NSCondition()
    let queue = dispatch_queue_create("org.hh.promise", DISPATCH_QUEUE_CONCURRENT)
    var callbacks: [() -> Void] = []
    var realized: Bool = false
    var value: Result<T> = Result.Failure(NSError())

    public init() { }

    // Initialize using an alternative queue.
    // Avoid passing global queues, unless you're okay with the possibility of the queue being blocked for an unknown length of time.
    public init(_ queue: dispatch_queue_t) {
        self.queue = queue
    }

    public init(_ result: Result<T>) {
        self.deliver(result)
    }

    // Has this promise been delivered?
    public func isRealized() -> Bool {
        condition.lock()
        let realized = self.realized
        condition.unlock()
        return realized
    }

    // Kept promise.
    public func deliver(#value: T) {
        self.deliver(Result.Success(Box(value)))
    }

    // Broken promise.
    public func deliver(#error: ErrorType) {
        self.deliver(Result.Failure(error))
    }

    // Deliver a result.
    public func deliver(value: Result<T>) {
        condition.lock()
        if !self.realized {
            self.value = value
            self.realized = true
            condition.broadcast()

            dispatch_barrier_async(self.queue, {
                for callback in self.callbacks {
                    callback()
                }
                self.callbacks = []
            })
        }
        condition.unlock()
    }

    // Dereference the promise. Caller will be blocked until promise kept or broken.
    public func deref() -> Result<T> {
        return self.deref(NSDate.distantFuture() as NSDate)
    }

    // Dereference the promise. Caller will be blocked until promise kept or broken, or the specified timeout expires.
    public func deref(timeout: NSTimeInterval) -> Result<T> {
        let start = NSDate()
        let until = start.dateByAddingTimeInterval(timeout)

        return self.deref(until)
    }

    // Dereferencing helper. Alternative form for dereference with timeout.
    public func deref(until: NSDate) -> Result<T> {
        condition.lock()
        if (!self.realized) {
            condition.waitUntilDate(until)
        }
        condition.unlock()

        return self.value
    }
}

extension Promise {
    // Callback helper
    func onRealization(callback: Result<T> -> Void) {
        dispatch_async(self.queue, {
            if self.isRealized() {
                callback(self.value)
                return
            }
            self.callbacks.append({
                callback(self.value)
            })
        })
    }

    // Map functional combinator
    public func map<U>(body: (T) -> U) -> Promise<U> {
        let chained = Promise<U>()

        self.onRealization( { result in
            chained.deliver(result.map(body))
        })

        return chained
    }

    public func map<U>(body: (Result<T>) -> Result<U>) -> Promise<U> {
        let chained = Promise<U>()

        self.onRealization( { result in
            chained.deliver(body(result))
        })

        return chained
    }

    // Flatmap functional combinator
    public func flatMap<U>(body: (T) -> Promise<U>) -> Promise<U> {
        let chained = Promise<U>()

        self.onRealization({ result in
            switch result {
            case .Success(let box) :
                let p = body(box.unbox)
                p.onRealization({ tmp in
                    chained.deliver(tmp)
                })
            case .Failure(let error) :
                chained.deliver(error: error)
            }
        })

        return chained
    }
}

