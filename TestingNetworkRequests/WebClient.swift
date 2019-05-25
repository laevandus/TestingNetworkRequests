//
//  WebClient.swift
//  TestingNetworkRequests
//
//  Created by Toomas Vahter on 18/05/2019.
//  Copyright © 2019 Augmented Code. All rights reserved.
//

import Foundation

final class WebClient {
    private let urlSession: URLSession
    
    init(urlSession: URLSession) {
        self.urlSession = urlSession
    }
    
    func fetch<T: Decodable>(_ request: URLRequest, requestDataType: T.Type, completionHandler: @escaping (Result<T, FetchError>) -> Void) {
        let dataTask = urlSession.dataTask(with: request) { (data, urlResponse, error) in
            if let error = error {
                DispatchQueue.main.async {
                    completionHandler(.failure(.connection(error)))
                }
                return
            }
            guard let urlResponse = urlResponse as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completionHandler(.failure(.unknown))
                }
                return
            }
            switch urlResponse.statusCode {
            case 200..<300:
                do {
                    let payload = try JSONDecoder().decode(requestDataType, from: data ?? Data())
                    DispatchQueue.main.async {
                        completionHandler(.success(payload))
                    }
                }
                catch let jsonError {
                    DispatchQueue.main.async {
                        completionHandler(.failure(.invalidData(jsonError)))
                    }
                }
            default:
                DispatchQueue.main.async {
                    completionHandler(.failure(.response(urlResponse.statusCode)))
                }
            }
        }
        dataTask.resume()
    }
}

extension WebClient {
    enum FetchError: Error {
        case response(Int)
        case invalidData(Error)
        case connection(Error)
        case unknown
    }
}
