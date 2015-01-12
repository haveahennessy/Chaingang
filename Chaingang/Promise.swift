//
//  Promise.swift
//  Chaingang
//
//  Created by Matt Isaacs.
//  Copyright (c) 2014 Matt Isaacs. All rights reserved.
//

import LlamaKit

public enum State<T, E> {
    case Unrealized
    case Realized(Result<T, E>)
}

// Clojure Style promises.

public class Promise<T, E> {
    let condition = NSCondition()
    let queue = dispatch_queue_create("org.hh.promise", DISPATCH_QUEUE_CONCURRENT)
    var callbacks: [() -> Void] = []
    var state: State<T, E> = State.Unrealized
    lazy var unwrapped: Result<T, E> = self.deref(NSDate.distantFuture() as NSDate)

    public init() { }

    // Initialize using an alternative queue.
    // Avoid passing global queues, unless you're okay with the possibility of the queue being blocked for an unknown length of time.
    public init(_ queue: dispatch_queue_t) {
        self.queue = queue
    }

    public init(_ result: Result<T, E>) {
        self.deliver(result)
    }

    // Has this promise been delivered?
    public func isRealized() -> Bool {
        switch self.state {
        case .Unrealized :
            return false
        default :
            return true
        }
    }

    // Kept promise helper.
    public func deliver(#value: T) {
        self.deliver(success(value))
    }

    // Broken promise helper.
    public func deliver(#error: E) {
        self.deliver(failure(error))
    }

    // Deliver a result.
    public func deliver(value: Result<T, E>) {
        self.transition(State.Realized(value))
    }

    // Promise state transitions
    func transition(to: State<T, E>) {
        condition.lock()
        switch self.state {
        case .Unrealized :
            switch to {
            case .Unrealized :
                // This is an error. Unrealized is the start state and can't be transition into.
                condition.unlock()

            case .Realized(let value) :
                self.state = State.Realized(value)

                condition.broadcast()
                condition.unlock()
                dispatch_barrier_async(self.queue, {
                    for callback in self.callbacks {
                        callback()
                    }
                    self.callbacks.removeAll(keepCapacity: false)
                })
            }
        case .Realized(_) :
            condition.unlock()
        }
    }

    // Dereference the promise. Caller will be blocked until promise kept or broken.
    public func deref() -> Result<T, E> {
        return self.unwrapped
    }

    // Dereference the promise. Caller will be blocked until promise kept or broken, or the specified timeout expires.
    public func deref(timeout: NSTimeInterval) -> Result<T, E> {
        let start = NSDate()
        let until = start.dateByAddingTimeInterval(timeout)

        return self.deref(until)
    }

    // Dereferencing helper. Alternative form for dereference with timeout.
    public func deref(until: NSDate) -> Result<T, E> {
        condition.lock()
        switch self.state {
        case .Unrealized :
            condition.waitUntilDate(until)
            condition.unlock()
            return self.deref(until)

        case .Realized(let value) :
            condition.unlock()
            return value
        }
    }
}

extension Promise {
    // Callback helper
    func onCompletion(callback: Result<T, E> -> Void) {
        dispatch_barrier_async(self.queue, {
            // No locking here. The dispatch barrier in the transition method above
            // provides protection against lost/uncalled callbacks.
            switch self.state {
            case .Realized(let value) :
                callback(value)
                return
            case .Unrealized :
                self.callbacks.append({
                    callback(self.unwrapped)
                })
            }
        })
    }

    // Map functional combinator
    public func map<U, F>(body: (Result<T, E>) -> Result<U, F>) -> Promise<U, F> {
        let chained = Promise<U, F>()

        self.onCompletion( { result in
            chained.deliver(body(result))
        })

        return chained
    }

    // Flatmap functional combinator
    public func flatMap<U, F>(body: (Result<T, E>) -> Promise<U, F>) -> Promise<U, F> {
        let chained = Promise<U, F>()

        self.onCompletion({ result in
            body(result).onCompletion({ bodyResult in
                chained.deliver(bodyResult)
            })
        })

        return chained
    }
}

