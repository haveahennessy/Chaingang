//
//  Promise.swift
//  Chaingang
//
//  Created by Matt Isaacs.
//  Copyright (c) 2014 Matt Isaacs. All rights reserved.
//

import LlamaKit

public enum State<T> {
    case Unrealized
    case Realized(Result<T>)
    case Cancelled
}

// Clojure Style promises.

public class Promise<T> {
    let condition = NSCondition()
    let queue = dispatch_queue_create("org.hh.promise", DISPATCH_QUEUE_CONCURRENT)
    var callbacks: [() -> Void] = []
    var state: State<T> = State.Unrealized
    lazy var unwrapped: Result<T> = self.deref(NSDate.distantFuture() as NSDate)

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
        switch self.state {
        case .Realized(_) :
            return true
        default :
            return false
        }
    }

    // Has this promise been Cancelled?
    public func isCancelled() -> Bool {
        switch self.state {
        case .Cancelled :
            return true
        default :
            return false
        }
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
        self.transition(State.Realized(value))
    }

    // Cancel promise.
    public func cancel() {
        self.transition(State.Cancelled)
    }

    func transition(to: State<T>) {
        condition.lock()
        switch self.state {
        case .Unrealized :
            switch to {
            case .Unrealized :
                // This is an error. Unrealized is the start state and can't be transition into.
                break
            case .Realized(let value) :
                self.state = State.Realized(value)
            case .Cancelled :
                self.state = State.Cancelled
            }

            condition.broadcast()
            condition.unlock()
            dispatch_barrier_async(self.queue, {
                for callback in self.callbacks {
                    callback()
                }
                self.callbacks.removeAll(keepCapacity: false)
            })

        default :
            condition.unlock()
        }
    }

    // Dereference the promise. Caller will be blocked until promise kept or broken.
    public func deref() -> Result<T> {
        return self.unwrapped
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
        switch self.state {
        case .Unrealized :
            condition.waitUntilDate(until)
            condition.unlock()
            return self.deref(until)

        case .Realized(let value) :
            condition.unlock()
            return value
        case .Cancelled :
            condition.unlock()
            return failure("Cancelled")
        }
    }
}

extension Promise {
    // Callback helper
    func onCompletion(callback: Result<T> -> Void) {
        dispatch_async(self.queue, {
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
            case .Cancelled :
                callback(failure("Cancelled"))
            }
        })
    }

    // Map functional combinator
    public func map<U>(body: (T) -> U) -> Promise<U> {
        let chained = Promise<U>()

        self.onCompletion( { result in
            chained.deliver(result.map(body))
        })

        return chained
    }

    public func mapResult<U>(body: (Result<T>) -> Result<U>) -> Promise<U> {
        let chained = Promise<U>()

        self.onCompletion( { result in
            chained.deliver(body(result))
        })

        return chained
    }

    // Flatmap functional combinator
    public func flatMap<U>(body: (T) -> Promise<U>) -> Promise<U> {
        let chained = Promise<U>()

        self.onCompletion({ result in
            switch result {
            case .Success(let box) :
                let p = body(box.unbox)
                p.onCompletion({ tmp in
                    chained.deliver(tmp)
                })
            case .Failure(let error) :
                chained.deliver(error: error)
            }
        })

        return chained
    }
}

