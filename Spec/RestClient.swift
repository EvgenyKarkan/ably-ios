//
//  RestClient.swift
//  ably
//
//  Created by Yavor Georgiev on 2.08.15.
//  Copyright © 2015 г. Ably. All rights reserved.
//

import AblyRealtime
import Nimble
import Quick

class RestClient: QuickSpec {
    override func spec() {

        var testHTTPExecutor: TestProxyHTTPExecutor!

        beforeEach {
            testHTTPExecutor = TestProxyHTTPExecutor()
        }

        describe("RestClient") {
            // G4
            it("All REST requests should include the current API version") {
                let client = ARTRest(options: AblyTests.commonAppSetup())
                client.httpExecutor = testHTTPExecutor
                let channel = client.channels.get("test")
                waitUntil(timeout: testTimeout) { done in
                    channel.publish(nil, data: "message") { error in
                        expect(error).to(beNil())
                        let version = testHTTPExecutor.requests.first!.allHTTPHeaderFields?["X-Ably-Version"]
                        expect(version).to(equal("0.8"))
                        done()
                    }
                }
            }

            // RSC1
            context("initializer") {
                it("should accept an API key") {
                    let options = AblyTests.commonAppSetup()
                    
                    let client = ARTRest(key: options.key!)
                    client.prioritizedHost = options.restHost

                    let publishTask = publishTestMessage(client)

                    expect(publishTask.error).toEventually(beNil(), timeout: testTimeout)
                }

                it("should throw when provided an invalid key") {
                    expect{ ARTRest(key: "invalid_key") }.to(raiseException())
                }

                it("should result in error status when provided a bad key") {
                    let client = ARTRest(key: "fake:key")

                    let publishTask = publishTestMessage(client, failOnError: false)

                    expect(publishTask.error?.code).toEventually(equal(40005), timeout:testTimeout)
                }

                it("should accept a token") {
                    ARTClientOptions.setDefaultEnvironment("sandbox")
                    defer { ARTClientOptions.setDefaultEnvironment(nil) }

                    let client = ARTRest(token: getTestToken())
                    let publishTask = publishTestMessage(client)
                    expect(publishTask.error).toEventually(beNil(), timeout: testTimeout)
                }

                it("should accept an options object") {
                    let options = AblyTests.commonAppSetup()
                    let client = ARTRest(options: options)

                    let publishTask = publishTestMessage(client)

                    expect(publishTask.error).toEventually(beNil(), timeout: testTimeout)
                }

                it("should accept an options object with token authentication") {
                    let options = AblyTests.clientOptions(requestToken: true)
                    let client = ARTRest(options: options)

                    let publishTask = publishTestMessage(client)

                    expect(publishTask.error).toEventually(beNil(), timeout: testTimeout)
                }

                it("should result in error status when provided a bad token") {
                    let options = AblyTests.clientOptions()
                    options.token = "invalid_token"
                    let client = ARTRest(options: options)

                    let publishTask = publishTestMessage(client, failOnError: false)

                    expect(publishTask.error?.code).toEventually(equal(40005), timeout: testTimeout)
                }
            }

            context("logging") {
                // RSC2
                it("should output to the system log and the log level should be Warn") {
                    ARTClientOptions.setDefaultEnvironment("sandbox")
                    defer {
                        ARTClientOptions.setDefaultEnvironment(nil)
                    }

                    let options = ARTClientOptions(key: "xxxx:xxxx")
                    options.logHandler = ARTLog(capturingOutput: true)
                    let client = ARTRest(options: options)

                    client.logger.log("This is a warning", withLevel: .Warn)

                    expect(client.logger.logLevel).to(equal(ARTLogLevel.Warn))
                    guard let line = options.logHandler.captured.last else {
                        fail("didn't log line.")
                        return
                    }
                    expect(line.level).to(equal(ARTLogLevel.Warn))
                    expect(line.toString()).to(equal("WARN: This is a warning"))
                }

                // RSC3
                it("should have a mutable log level") {
                    let options = AblyTests.commonAppSetup()
                    options.logHandler = ARTLog(capturingOutput: true)
                    let client = ARTRest(options: options)
                    client.logger.logLevel = .Error

                    let logTime = NSDate()
                    client.logger.log("This is a warning", withLevel: .Warn)

                    let logs = options.logHandler.captured.filter({!$0.date.isBefore(logTime)})
                    expect(logs).to(beEmpty())
                }

                // RSC4
                it("should accept a custom logger") {
                    struct Log {
                        static var interceptedLog: (String, ARTLogLevel) = ("", .None)
                    }
                    class MyLogger : ARTLog {
                        override func log(message: String, withLevel level: ARTLogLevel) {
                            Log.interceptedLog = (message, level)
                        }
                    }

                    let options = AblyTests.commonAppSetup()
                    let customLogger = MyLogger()
                    options.logHandler = customLogger
                    options.logLevel = .Verbose
                    let client = ARTRest(options: options)

                    client.logger.log("This is a warning", withLevel: .Warn)
                    
                    expect(Log.interceptedLog.0).to(equal("This is a warning"))
                    expect(Log.interceptedLog.1).to(equal(ARTLogLevel.Warn))
                    
                    expect(client.logger.logLevel).to(equal(customLogger.logLevel))
                }
            }

            // RSC11
            context("endpoint") {
                it("should accept an options object with a host set") {
                    let options = ARTClientOptions(key: "fake:key")
                    options.environment = "fake"
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    
                    publishTestMessage(client, failOnError: false)
                    
                    expect(testHTTPExecutor.requests.first?.URL?.host).toEventually(equal("fake-rest.ably.io"), timeout: testTimeout)
                }
                
                it("should accept an options object with an environment set") {
                    let options = ARTClientOptions(key: "fake:key")
                    options.environment = "myEnvironment"
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    
                    publishTestMessage(client, failOnError: false)
                    
                    expect(testHTTPExecutor.requests.first?.URL?.host).toEventually(equal("myEnvironment-rest.ably.io"), timeout: testTimeout)
                }
                
                it("should default to https://rest.ably.io") {
                    let options = ARTClientOptions(key: "fake:key")
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    
                    publishTestMessage(client, failOnError: false)
                    
                    expect(testHTTPExecutor.requests.first?.URL?.absoluteString).toEventually(beginWith("https://rest.ably.io"), timeout: testTimeout)
                }
                
                it("should connect over plain http:// when tls is off") {
                    let options = AblyTests.clientOptions(requestToken: true)
                    options.tls = false
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    
                    publishTestMessage(client, failOnError: false)
                    
                    expect(testHTTPExecutor.requests.first?.URL?.scheme).toEventually(equal("http"), timeout: testTimeout)
                }
            }

            // RSC13
            context("should use the the connection and request timeouts specified") {

                it("timeout for any single HTTP request and response") {
                    let options = ARTClientOptions(key: "xxxx:xxxx")
                    options.restHost = "10.255.255.1" //non-routable IP address
                    expect(options.httpRequestTimeout).to(equal(15.0)) //Seconds
                    options.httpRequestTimeout = 0.5
                    let client = ARTRest(options: options)
                    let channel = client.channels.get("test")
                    waitUntil(timeout: testTimeout) { done in
                        let start = NSDate()
                        channel.publish(nil, data: "message") { error in
                            let end = NSDate()
                            expect(end.timeIntervalSinceDate(start)).to(beCloseTo(options.httpRequestTimeout, within: 0.1))
                            expect(error).toNot(beNil())
                            if let error = error {
                                expect(error.code).to(equal(-1001))
                            }
                            done()
                        }
                    }
                }

                it("max number of fallback hosts") {
                    let options = ARTClientOptions(key: "xxxx:xxxx")
                    expect(options.httpMaxRetryCount).to(equal(3))
                    options.httpMaxRetryCount = 1
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    testHTTPExecutor.http = MockHTTP(network: .HostUnreachable)

                    var totalRetry: UInt = 0
                    testHTTPExecutor.afterRequest = { request, _ in
                        if NSRegularExpression.match(request.URL!.absoluteString, pattern: "//[a-e].ably-realtime.com") {
                            totalRetry += 1
                        }
                    }

                    let channel = client.channels.get("test")
                    waitUntil(timeout: testTimeout) { done in
                        channel.publish(nil, data: "nil") { _ in
                            done()
                        }
                    }
                    expect(totalRetry).to(equal(options.httpMaxRetryCount))
                }

                it("max elapsed time in which fallback host retries for HTTP requests will be attempted") {
                    let options = ARTClientOptions(key: "xxxx:xxxx")
                    expect(options.httpMaxRetryDuration).to(equal(10.0)) //Seconds
                    options.httpMaxRetryDuration = 0.2
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    testHTTPExecutor.http = MockHTTP(network: .RequestTimeout(timeout: 0.1))
                    let channel = client.channels.get("test")
                    waitUntil(timeout: testTimeout) { done in
                        let start = NSDate()
                        channel.publish(nil, data: "nil") { _ in
                            let end = NSDate()
                            expect(end.timeIntervalSinceDate(start)).to(beCloseTo(options.httpMaxRetryDuration, within: 0.5))
                            done()
                        }
                    }
                }

            }

            // RSC5
            it("should provide access to the AuthOptions object passed in ClientOptions") {
                let options = AblyTests.setupOptions(AblyTests.jsonRestOptions)
                let client = ARTRest(options: options)
                
                let authOptions = client.auth.options

                expect(authOptions == options).to(beTrue())
            }

            // RSC12
            it("REST endpoint host should be configurable in the Client constructor with the option restHost") {
                let options = ARTClientOptions(key: "xxxx:xxxx")
                expect(options.restHost).to(equal("rest.ably.io"))
                options.restHost = "rest.ably.test"
                expect(options.restHost).to(equal("rest.ably.test"))
                let client = ARTRest(options: options)
                client.httpExecutor = testHTTPExecutor
                waitUntil(timeout: testTimeout) { done in
                    client.channels.get("test").publish(nil, data: "message") { error in
                        expect(error).toNot(beNil())
                        done()
                    }
                }
                expect(testHTTPExecutor.requests.first!.URL!.absoluteString).to(contain("//rest.ably.test"))
            }
            
            // RSC16
            context("time") {
                it("should return server time") {
                    let options = AblyTests.setupOptions(AblyTests.jsonRestOptions)
                    let client = ARTRest(options: options)
                    
                    var time: NSDate?

                    client.time({ date, error in
                        time = date
                    })
                    
                    expect(time?.timeIntervalSince1970).toEventually(beCloseTo(NSDate().timeIntervalSince1970, within: 60), timeout: testTimeout)
                }
            }

            // RSC7, RSC18
            it("should send requests over http and https") {
                let options = AblyTests.commonAppSetup()

                let clientHttps = ARTRest(options: options)
                clientHttps.httpExecutor = testHTTPExecutor

                options.clientId = "client_http"
                options.tls = false
                let clientHttp = ARTRest(options: options)
                clientHttp.httpExecutor = testHTTPExecutor

                waitUntil(timeout: testTimeout) { done in
                    publishTestMessage(clientHttps) { error in
                        done()
                    }
                }

                waitUntil(timeout: testTimeout) { done in
                    publishTestMessage(clientHttp) { error in
                        done()
                    }
                }

                let requestUrlA = testHTTPExecutor.requests.first!.URL!
                expect(requestUrlA.scheme).to(equal("https"))

                let requestUrlB = testHTTPExecutor.requests.last!.URL!
                expect(requestUrlB.scheme).to(equal("http"))
            }

            // RSC9
            it("should use Auth to manage authentication") {
                let options = AblyTests.clientOptions()
                options.tokenDetails = getTestTokenDetails()

                waitUntil(timeout: testTimeout) { done in
                    ARTRest(options: options).auth.authorise(nil, options: nil) { tokenDetails, error in
                        if let e = error {
                            XCTFail(e.description)
                            done()
                            return
                        }
                        guard let tokenDetails = tokenDetails else {
                            XCTFail("expected tokenDetails not to be nil when error is nil")
                            done()
                            return
                        }
                        // Use the same token because it is valid
                        expect(tokenDetails.token).to(equal(options.tokenDetails!.token))
                        done()
                    }
                }
            }

            // RSC10
            it("should request another token after current one is no longer valid") {
                let options = AblyTests.commonAppSetup()
                let client = ARTRest(options: options)
                let auth = client.auth

                let tokenParams = ARTTokenParams()
                tokenParams.ttl = 3.0 //Seconds

                waitUntil(timeout: testTimeout) { done in
                    auth.authorise(tokenParams, options: nil) { tokenDetailsA, error in
                        if let e = error {
                            XCTFail(e.description)
                            done()
                            return
                        }
                        guard let tokenDetailsA = tokenDetailsA else {
                            XCTFail("expected tokenDetails not to be nil when error is nil")
                            done()
                            return
                        }
                        // Delay for token expiration
                        delay(tokenParams.ttl + 1.0) {
                            auth.authorise(nil, options: nil) { tokenDetailsB, error in
                                if let e = error {
                                    XCTFail(e.description)
                                    done()
                                    return
                                }
                                guard let tokenDetailsB = tokenDetailsB else {
                                    XCTFail("expected tokenDetails not to be nil when error is nil")
                                    done()
                                    return
                                }
                                // Different token
                                expect(tokenDetailsA.token).toNot(equal(tokenDetailsB.token))
                                done()
                            }
                        }
                    }
                }
            }

            // RSC14
            context("Authentication") {

                // RSC14b
                context("basic authentication flag") {
                    it("should be true when key is set") {
                        let client = ARTRest(key: "key:secret")
                        expect(client.auth.options.isBasicAuth()).to(beTrue())
                    }

                    for (caseName, caseSetter) in AblyTests.authTokenCases {
                        it("should be false when \(caseName) is set") {
                            let options = ARTClientOptions()
                            caseSetter(options)

                            let client = ARTRest(options: options)

                            expect(client.auth.options.isBasicAuth()).to(beFalse())
                        }
                    }
                }

                // RSC14c
                it("should error when expired token and no means to renew") {
                    let client = ARTRest(options: AblyTests.commonAppSetup())
                    let auth = client.auth

                    let tokenParams = ARTTokenParams()
                    tokenParams.ttl = 3.0 //Seconds

                    waitUntil(timeout: testTimeout) { done in
                        auth.requestToken(tokenParams, withOptions: nil) { tokenDetails, error in
                            if let e = error {
                                XCTFail(e.description)
                                done()
                                return
                            }

                            guard let currentTokenDetails = tokenDetails else {
                                XCTFail("expected tokenDetails not to be nil when error is nil")
                                done()
                                return
                            }

                            let options = AblyTests.clientOptions()
                            options.key = client.options.key

                            // Expired token
                            options.tokenDetails = ARTTokenDetails(token: currentTokenDetails.token, expires: currentTokenDetails.expires!.dateByAddingTimeInterval(testTimeout), issued: currentTokenDetails.issued, capability: currentTokenDetails.capability, clientId: currentTokenDetails.clientId)

                            options.authUrl = NSURL(string: "http://test-auth.ably.io")

                            let rest = ARTRest(options: options)
                            rest.httpExecutor = testHTTPExecutor

                            // Delay for token expiration
                            delay(tokenParams.ttl) {
                                // [40140, 40150) - token expired and will not recover because authUrl is invalid
                                publishTestMessage(rest) { error in
                                    guard let errorCode = testHTTPExecutor.responses.first?.allHeaderFields["X-Ably-ErrorCode"] as? String else {
                                        fail("expected X-Ably-ErrorCode header in request")
                                        return
                                    }
                                    expect(Int(errorCode)).to(beGreaterThanOrEqualTo(40140))
                                    expect(Int(errorCode)).to(beLessThan(40150))
                                    expect(error).toNot(beNil())
                                    done()
                                }
                            }
                        }
                    }
                }

                // RSC14d
                it("should renew the token when it has expired") {
                    let client = ARTRest(options: AblyTests.commonAppSetup())
                    let auth = client.auth

                    let tokenParams = ARTTokenParams()
                    tokenParams.ttl = 3.0 //Seconds

                    waitUntil(timeout: testTimeout) { done in
                        auth.requestToken(tokenParams, withOptions: nil) { tokenDetails, error in
                            if let e = error {
                                XCTFail(e.description)
                                done()
                                return
                            }

                            guard let currentTokenDetails = tokenDetails else {
                                XCTFail("expected tokenDetails not to be nil when error is nil")
                                done()
                                return
                            }

                            let options = AblyTests.clientOptions()
                            options.key = client.options.key

                            // Expired token
                            options.tokenDetails = ARTTokenDetails(token: currentTokenDetails.token, expires: currentTokenDetails.expires!.dateByAddingTimeInterval(testTimeout), issued: currentTokenDetails.issued, capability: currentTokenDetails.capability, clientId: currentTokenDetails.clientId)

                            let rest = ARTRest(options: options)
                            rest.httpExecutor = testHTTPExecutor

                            // Delay for token expiration
                            delay(tokenParams.ttl) {
                                // [40140, 40150) - token expired and will not recover because authUrl is invalid
                                publishTestMessage(rest) { error in
                                    guard let errorCode = testHTTPExecutor.responses.first?.allHeaderFields["X-Ably-ErrorCode"] as? String else {
                                        fail("expected X-Ably-ErrorCode header in request")
                                        return
                                    }
                                    expect(Int(errorCode)).to(beGreaterThanOrEqualTo(40140))
                                    expect(Int(errorCode)).to(beLessThan(40150))
                                    expect(error).to(beNil())
                                    expect(rest.auth.tokenDetails!.token).toNot(equal(currentTokenDetails.token))
                                    done()
                                }
                            }
                        }
                    }
                }
            }

            // RSC15
            context("Host Fallback") {

                // RSC15b
                it("failing HTTP requests with custom endpoint should result in an error immediately") {
                    let options = ARTClientOptions(key: "xxxx:xxxx")
                    options.environment = "test"
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    testHTTPExecutor.http = MockHTTP(network: .HostUnreachable)
                    let channel = client.channels.get("test")

                    waitUntil(timeout: testTimeout) { done in
                        channel.publish(nil, data: "message") { error in
                            expect(error!.message).to(contain("hostname could not be found"))
                            done()
                        }
                    }
                }

                // RSC15b
                it("applies when the default rest.ably.io endpoint is being used") {
                    let options = ARTClientOptions(key: "xxxx:xxxx")
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    testHTTPExecutor.http = MockHTTP(network: .HostUnreachable)
                    let channel = client.channels.get("test")

                    var capturedURLs = [String]()
                    testHTTPExecutor.afterRequest = { request, callback in
                        capturedURLs.append(request.URL!.absoluteString)
                        if testHTTPExecutor.requests.count == 2 {
                            // Stop
                            testHTTPExecutor.http = nil
                            callback!(nil, nil, nil)
                        }
                    }

                    waitUntil(timeout: testTimeout) { done in
                        channel.publish(nil, data: "nil") { _ in
                            done()
                        }
                    }

                    expect(testHTTPExecutor.requests).to(haveCount(2))
                    if testHTTPExecutor.requests.count < 2 {
                        return
                    }
                    expect(NSRegularExpression.match(capturedURLs[0], pattern: "//rest.ably.io")).to(beTrue())
                    expect(NSRegularExpression.match(capturedURLs[1], pattern: "//[a-e].ably-realtime.com")).to(beTrue())
                }

                // RSC15e
                it("every new HTTP request is first attempted to the primary host rest.ably.io") {
                    let options = ARTClientOptions(key: "xxxx:xxxx")
                    options.httpMaxRetryCount = 1
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    testHTTPExecutor.http = MockHTTP(network: .HostUnreachable)
                    let channel = client.channels.get("test")

                    waitUntil(timeout: testTimeout) { done in
                        channel.publish(nil, data: "nil") { _ in
                            done()
                        }
                    }

                    testHTTPExecutor.http = ARTHttp()

                    waitUntil(timeout: testTimeout) { done in
                        channel.publish(nil, data: "nil") { _ in
                            done()
                        }
                    }

                    expect(testHTTPExecutor.requests).to(haveCount(3))
                    if testHTTPExecutor.requests.count != 3 {
                        return
                    }
                    expect(NSRegularExpression.match(testHTTPExecutor.requests[0].URL!.absoluteString, pattern: "//rest.ably.io")).to(beTrue())
                    expect(NSRegularExpression.match(testHTTPExecutor.requests[1].URL!.absoluteString, pattern: "//[a-e].ably-realtime.com")).to(beTrue())
                    expect(NSRegularExpression.match(testHTTPExecutor.requests[2].URL!.absoluteString, pattern: "//rest.ably.io")).to(beTrue())
                }

                // RSC15a
                context("retry hosts in random order") {
                    let expectedHostOrder = [4, 3, 0, 2, 1]

                    let originalARTFallback_getRandomHostIndex = ARTFallback_getRandomHostIndex

                    beforeEach {
                        ARTFallback_getRandomHostIndex = {
                            let hostIndexes = [1, 1, 0, 0, 0]
                            var i = 0
                            return { count in
                                let hostIndex = hostIndexes[i]
                                i += 1
                                return Int32(hostIndex)
                            }
                        }()
                    }

                    afterEach {
                        ARTFallback_getRandomHostIndex = originalARTFallback_getRandomHostIndex
                    }

                    it("until httpMaxRetryCount has been reached") {
                        let options = ARTClientOptions(key: "xxxx:xxxx")
                        let client = ARTRest(options: options)
                        options.httpMaxRetryCount = 3
                        client.httpExecutor = testHTTPExecutor
                        testHTTPExecutor.http = MockHTTP(network: .HostUnreachable)
                        testHTTPExecutor.afterRequest = { _, _ in
                            if testHTTPExecutor.requests.count > Int(1 + options.httpMaxRetryCount) {
                                fail("Should not retry more than \(options.httpMaxRetryCount)")
                                testHTTPExecutor.http = nil
                            }
                        }
                        let channel = client.channels.get("test")


                        waitUntil(timeout: testTimeout) { done in
                            channel.publish(nil, data: "nil") { _ in
                                done()
                            }
                        }

                        expect(testHTTPExecutor.requests).to(haveCount(Int(1 + options.httpMaxRetryCount)))

                        let extractHostname = { (request: NSMutableURLRequest) in
                            NSRegularExpression.extract(request.URL!.absoluteString, pattern: "[a-e].ably-realtime.com")
                        }
                        let resultFallbackHosts = testHTTPExecutor.requests.flatMap(extractHostname)
                        let expectedFallbackHosts = Array(expectedHostOrder.map({ ARTDefault.fallbackHosts()[$0] as! String })[0..<Int(options.httpMaxRetryCount)])

                        expect(resultFallbackHosts).to(equal(expectedFallbackHosts))
                    }

                    it("until all fallback hosts have been tried") {
                        let options = ARTClientOptions(key: "xxxx:xxxx")
                        options.httpMaxRetryCount = 10
                        let client = ARTRest(options: options)
                        client.httpExecutor = testHTTPExecutor
                        testHTTPExecutor.http = MockHTTP(network: .HostUnreachable)
                        let channel = client.channels.get("test")

                        waitUntil(timeout: testTimeout) { done in
                            channel.publish(nil, data: "nil") { _ in
                                done()
                            }
                        }

                        expect(testHTTPExecutor.requests).to(haveCount(ARTDefault.fallbackHosts().count + 1))

                        let extractHostname = { (request: NSMutableURLRequest) in
                            NSRegularExpression.extract(request.URL!.absoluteString, pattern: "[a-e].ably-realtime.com")
                        }
                        let resultFallbackHosts = testHTTPExecutor.requests.flatMap(extractHostname)
                        let expectedFallbackHosts = expectedHostOrder.map { ARTDefault.fallbackHosts()[$0] as! String }

                        expect(resultFallbackHosts).to(equal(expectedFallbackHosts))
                    }
                }

                // RSC15d
                context("should use an alternative host when") {

                    for caseTest: NetworkAnswer in [.HostUnreachable,
                                                    .RequestTimeout(timeout: 0.1),
                                                    .HostInternalError(code: 501)] {
                        it("\(caseTest)") {
                            let options = ARTClientOptions(key: "xxxx:xxxx")
                            let client = ARTRest(options: options)
                            client.httpExecutor = testHTTPExecutor
                            testHTTPExecutor.http = MockHTTP(network: caseTest)
                            let channel = client.channels.get("test")

                            testHTTPExecutor.afterRequest = { _, callback in
                                if testHTTPExecutor.requests.count == 2 {
                                    // Stop
                                    testHTTPExecutor.http = nil
                                    callback!(nil, nil, nil)
                                }
                            }

                            waitUntil(timeout: testTimeout) { done in
                                channel.publish(nil, data: "nil") { _ in
                                    done()
                                }
                            }

                            expect(testHTTPExecutor.requests).to(haveCount(2))
                            if testHTTPExecutor.requests.count != 2 {
                                return
                            }
                            expect(NSRegularExpression.match(testHTTPExecutor.requests[0].URL!.absoluteString, pattern: "//rest.ably.io")).to(beTrue())
                            expect(NSRegularExpression.match(testHTTPExecutor.requests[1].URL!.absoluteString, pattern: "//[a-e].ably-realtime.com")).to(beTrue())
                        }
                    }

                }

                // RSC15d
                it("should not use an alternative host when the client receives an bad request") {
                    let options = ARTClientOptions(key: "xxxx:xxxx")
                    let client = ARTRest(options: options)
                    client.httpExecutor = testHTTPExecutor
                    testHTTPExecutor.http = MockHTTP(network: .Host400BadRequest)
                    let channel = client.channels.get("test")

                    testHTTPExecutor.afterRequest = { _ in
                        if testHTTPExecutor.requests.count == 2 {
                            // Stop
                            testHTTPExecutor.http = nil
                        }
                    }

                    waitUntil(timeout: testTimeout) { done in
                        channel.publish(nil, data: "nil") { _ in
                            done()
                        }
                    }

                    expect(testHTTPExecutor.requests).to(haveCount(1))
                    expect(NSRegularExpression.match(testHTTPExecutor.requests[0].URL!.absoluteString, pattern: "//rest.ably.io")).to(beTrue())
                }

            }

            // RSC8a
            it("should use MsgPack binary protocol") {
                let options = AblyTests.commonAppSetup()
                expect(options.useBinaryProtocol).to(beTrue())

                let rest = ARTRest(options: options)
                rest.httpExecutor = testHTTPExecutor
                waitUntil(timeout: testTimeout) { done in
                    rest.channels.get("test").publish(nil, data: "message") { error in
                        done()
                    }
                }

                switch extractBodyAsMsgPack(testHTTPExecutor.requests.first) {
                case .Failure(let error):
                    fail(error)
                default: break
                }

                let realtime = AblyTests.newRealtime(options)
                defer { realtime.close() }
                waitUntil(timeout: testTimeout) { done in
                    realtime.channels.get("test").publish(nil, data: "message") { error in
                        done()
                    }
                }

                let transport = realtime.transport as! TestProxyTransport
                let object = AblyTests.msgpackToJSON(transport.rawDataSent.last!)
                expect(object["messages"][0]["data"].string).to(equal("message"))
            }

            // RSC8b
            it("should use JSON text protocol") {
                let options = AblyTests.commonAppSetup()
                options.useBinaryProtocol = false

                let rest = ARTRest(options: options)
                rest.httpExecutor = testHTTPExecutor
                waitUntil(timeout: testTimeout) { done in
                    rest.channels.get("test").publish(nil, data: "message") { error in
                        done()
                    }
                }

                switch extractBodyAsJSON(testHTTPExecutor.requests.first) {
                case .Failure(let error):
                    fail(error)
                default: break
                }

                let realtime = AblyTests.newRealtime(options)
                defer { realtime.close() }
                waitUntil(timeout: testTimeout) { done in
                    realtime.channels.get("test").publish(nil, data: "message") { error in
                        done()
                    }
                }

                let transport = realtime.transport as! TestProxyTransport
                let object = try! NSJSONSerialization.JSONObjectWithData(transport.rawDataSent.first!, options: NSJSONReadingOptions(rawValue: 0))
                expect(NSJSONSerialization.isValidJSONObject(object)).to(beTrue())
            }

        } //RestClient
    }
}