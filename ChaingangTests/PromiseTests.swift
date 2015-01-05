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
        let p = Promise<AnyObject>()
        XCTAssert(!p.isRealized(), "")
    }

    func testDelivered() {
        let p = Promise<AnyObject>()
        p.deliver(value: 5)
        XCTAssert(p.isRealized(), "")
        XCTAssert(p.deref().value() as Int == 5, "")

        p.deliver(value: 3)
        XCTAssert(p.deref().value() as Int == 5, "")
    }

    func testWaitForDelivery() {
        let p = Promise<AnyObject>()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
            sleep(4)
            p.deliver(value: 5)
        })

        XCTAssert(!p.isRealized(), "")
        XCTAssert(p.deref().value() as Int == 5, "")
        XCTAssert(p.isRealized(), "")
    }

    func testMapComposition() {
        let intPromise = Promise<AnyObject>()
        let stringPromise = intPromise.map({ (x: AnyObject) -> String in
            return String(x as Int)
        })
        let doubledPromise = stringPromise.map({ (s: String) -> Int in
            return s.toInt()! * 2
        })
        XCTAssert(!stringPromise.isRealized(), "")
        XCTAssert(!doubledPromise.isRealized(), "")
        intPromise.deliver(value: 24)

        XCTAssert(doubledPromise.deref().value()? == 48, "")
    }

    func testFlatMapComposition() {
        let intPromise = Promise<AnyObject>()
        let stringPromise = intPromise.flatMap({ (x: AnyObject) -> Promise<String> in
            sleep(4)
            return Promise(success(String(x as Int)))
        })
        let doubledPromise = stringPromise.flatMap({ (s: String) -> Promise<Int> in
            return Promise(success(s.toInt()! * 2))
        })
        XCTAssert(!stringPromise.isRealized(), "")
        XCTAssert(!doubledPromise.isRealized(), "")
        intPromise.deliver(value: 24)

        XCTAssert(doubledPromise.deref().value()? == 48, "")
    }
}

