//
//  WebClientTests.swift
//  TestingNetworkRequestsTests
//
//  Created by Toomas Vahter on 18/05/2019.
//  Copyright © 2019 Augmented Code. All rights reserved.
//

import XCTest
@testable import TestingNetworkRequests

final class WebClientTests: XCTestCase {
    override func tearDown() {
        TestURLProtocol.loadingHandler = nil
    }
    
    struct TestPayload: Codable, Equatable {
        let country: String
    }
    
    func testFetchingDataSuccessfully() {
        let expected = TestPayload(country: "Estonia")
        let request = URLRequest(url: URL(string: "https://www.example.com")!)
        let responseJSONData = try! JSONEncoder().encode(expected)
        TestURLProtocol.loadingHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJSONData, nil)
        }
    
        let expectation = XCTestExpectation(description: "Loading")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        let client = WebClient(urlSession: URLSession(configuration: configuration))
        client.fetch(request, requestDataType: TestPayload.self) { (result) in
            switch result {
            case .failure(let error):
                XCTFail("Request was not successful: \(error.localizedDescription)")
            case .success(let payload):
                XCTAssertEqual(payload, expected)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func test404Failure() {
        let request = URLRequest(url: URL(string: "https://www.example.com")!)
        TestURLProtocol.loadingHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data(), nil)
        }
        
        let expectation = XCTestExpectation(description: "Loading")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        let client = WebClient(urlSession: URLSession(configuration: configuration))
        client.fetch(request, requestDataType: TestPayload.self) { (result) in
            switch result {
            case .failure(let error):
                switch error {
                case .response(let code):
                    XCTAssertEqual(code, 404)
                default:
                    XCTFail("Unexpected loading error.")
                }
            case .success(_):
                XCTFail("Request did not fail when it was expected to.")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}

final class TestURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    static var loadingHandler: ((URLRequest) -> (HTTPURLResponse, Data?, Error?))?
    
    override func startLoading() {
        guard let handler = TestURLProtocol.loadingHandler else {
            XCTFail("Loading handler is not set.")
            return
        }
        let (response, data, error) = handler(request)
        if let data = data {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        else {
            client?.urlProtocol(self, didFailWithError: error!)
        }
    }
    
    override func stopLoading() {
    }
}
