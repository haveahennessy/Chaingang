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
    let queue = dispatch_queue_create("org.hh.promise", DISPATCH_QUEUE_SERIAL)
    var realized: Bool = false
    var value: Result<T> = Result.Failure(NSError())

    public init() { }

    // Initialize using an alternative queue.
    // Avoid passing global queues, unless you're okay with the possibility of the queue being blocked for an unknown length of time.
    public init(_ queue: dispatch_queue_t) {
        self.queue = queue
    }

    // Has this promise been delivered?
    public func isRealized() -> Bool {
        return self.realized
    }

    // Kept promise.
    public func deliver(#value: T) {
        self.deliver(Result.Success(Box(value)))
    }

    // Broken promise.
    public func deliver(#error: ErrorType) {
        self.deliver(Result.Failure(error))
    }

    // Delivery helper.
    func deliver(value: Result<T>) {
        condition.lock()
        if !self.realized {
            self.value = value
            self.realized = true
            condition.broadcast()
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

// Some functional combinators.
// --
// Haters - I'm aware that blocking threads is a crime against humanity. The intended environment for this implementation is not one in which 1000s
// or even 100s of promise chains exist at a given time, and so in this case blocking is excusable.
// Non-haters - Don't use this if you intend to have hundreds of promise chains active at any given moment.

extension Promise {
    public func map<U>(body: (T) -> U) -> Promise<U> {
        let chained = Promise<U>(self.queue)
        dispatch_async(self.queue, {
            switch self.deref() {
            case .Success(let box) :
                chained.deliver(value: body(box.unbox))
            case .Failure(let error) :
                chained.deliver(.Failure(error))
            }

        })
        return chained
    }

    public func map<U>(body: (Result<T>) -> Result<U>) -> Promise<U> {
        let chained = Promise<U>(self.queue)
        dispatch_async(self.queue, {
            chained.deliver(body(self.deref()))
        })
        return chained
    }

    public func flatMap<U>(body: (T) -> Promise<U>) -> Promise<U> {
        let chained = Promise<U>(self.queue)
        dispatch_async(self.queue, {
            switch self.deref() {
            case .Success(let box) :
                chained.deliver(body(box.unbox).deref())
            case .Failure(let error) :
                chained.deliver(error: error)
            }
        })
        return chained
    }
}

