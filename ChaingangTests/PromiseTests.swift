//
//  PromiseTests.swift
//  Chaingang
//
//  Created by Matt Isaacs.
//  Copyright (c) 2014 Matt Isaacs. All rights reserved.
//

import Chaingang
import LlamaKit
import XCTest

class promiseTestCase: XCTestCase {
    func testInit() {
        let p = Promise<AnyObject, NSError>()
        XCTAssert(!p.isRealized(), "")
    }

    func testDelivered() {
        let p = Promise<AnyObject, NSError>()
        p.deliver(value: 5)
        XCTAssert(p.isRealized(), "")
        XCTAssert(p.deref().value as! Int == 5, "")

        p.deliver(value: 3)
        XCTAssert(p.deref().value as! Int == 5, "")
    }

    func testWaitForDelivery() {
        let p = Promise<AnyObject, NSError>()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            sleep(4)
            p.deliver(value: 5)
        })

        XCTAssert(!p.isRealized(), "")
        XCTAssert(p.deref().value as! Int == 5, "")
        XCTAssert(p.isRealized(), "")
    }

    func testMapComposition() {
        let intPromise = Promise<AnyObject, NSError>()
        let stringPromise = intPromise.map({ x -> Result<String, NSError> in
            return x.map({ xform in return String(xform as! Int) })
        })
        let doubledPromise = stringPromise.map({ s -> Result<Int, NSError> in
            return s.map({ xform in return xform.toInt()! * 2 })
        })
        XCTAssert(!stringPromise.isRealized(), "")
        XCTAssert(!doubledPromise.isRealized(), "")
        intPromise.deliver(value: 24)

        XCTAssert(doubledPromise.deref().value! == 48, "")
    }

    func testFlatMapComposition() {
        let intPromise = Promise<AnyObject, NSError>()
        let stringPromise = intPromise.flatMap({ (x: Result<AnyObject, NSError>) -> Promise<String, NSError> in
            sleep(4)
            return Promise(x.map( { xform in
                return String(xform as! Int)
            }))
        })
        let doubledPromise = stringPromise.flatMap({ (s: Result<String, NSError>) -> Promise<Int, NSError> in
            return Promise(s.map( { xform in
                xform.toInt()! * 2
            }))
        })
        XCTAssert(!stringPromise.isRealized(), "")
        XCTAssert(!doubledPromise.isRealized(), "")
        intPromise.deliver(value: 24)

        XCTAssert(doubledPromise.deref().value! == 48, "")
    }
}

