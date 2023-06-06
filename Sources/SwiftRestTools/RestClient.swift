//
//  RestClient.swift
//  swift-utilities
//
//  Created by Bill Gestrich on 10/29/17.
//  Copyright © 2017 Bill Gestrich. All rights reserved.
//

import Foundation

public enum RestClientError: Error {
    case serviceError(Error)
    case statusCode(Int)
    case noData
	case noResponse
	case failedHTTPURLResponseParsing
	case failedDataParsing
    case deserialization(Error)
	case wrongStatusCode(String)
}

open class RestClient: NSObject {
    
    let baseURL: String
    open var headers: [String:String]?
    var auth : BasicAuth?
    
    public init(baseURL: String){
        self.baseURL = baseURL
        super.init()
    }
    
    public convenience init(baseURL: String, auth: BasicAuth){
        self.init(baseURL: baseURL)
        self.auth = auth
    }
    
    public convenience init(baseURL: String, auth: BasicAuth?, headers:[String:String]?){
        self.init(baseURL: baseURL)
        self.auth = auth
        self.headers = headers
    }

	// MARK: Get
    
    public func get(
		relativeURL: String,
		completionHandler: @escaping (Result<Data, RestClientError>) -> Void
	) {
        let urlString = baseURL.appending(relativeURL)

		get(fullURL: urlString, completionHandler: completionHandler)
    }
    
    public func get(
		fullURL: String,
		completionHandler: @escaping (Result<Data, RestClientError>) -> Void
	) {
        var headersToSet = [
			"Content-Type": "application/json",
			"Accept": "application/json"
		]

        if let headers {
            headersToSet += headers
        }

        let http = SimpleHttp(
			auth: auth,
			headers: headersToSet
		)

        let url = URL(string: fullURL)!
		
        http.get(url: url, completionHandler: completionHandler)
    }

	// MARK: Post
    
    public func post<T>(
		relativeURL: String,
		payload: T,
		completionHandler: @escaping (Result<Data, RestClientError>) -> Void
	)  where T: Encodable {
        let urlString = baseURL.appending(relativeURL)

		post(fullURL: urlString, payload: payload, completionHandler: completionHandler)
    }
    
    public func post<T>(
		fullURL: String,
		payload: T,
		completionHandler: @escaping (Result<Data, RestClientError>) -> Void
	) where T : Encodable {
        var headersToSet = ["Content-Type":"application/json", "Accept":"application/json"]

        if let headers {
            headersToSet += headers
        }

        let http = SimpleHttp(auth: auth, headers: headersToSet)
        let url = URL(string: fullURL)!

		http.post(url: url, payload: payload, completionHandler: completionHandler)
    }

	// MARK: Upload

    public func uploadFile(filePath: String, relativeDestinationPath: String, completionBlock:@escaping ((Data) -> Void), errorBlock:(@escaping (RestClientError) -> Void)){
        let fullDestinationPath = baseURL.appending(relativeDestinationPath)
        uploadFile(filePath: filePath, fullDestinationPath: fullDestinationPath, completionBlock: completionBlock, errorBlock: errorBlock)
    }
    
    public func uploadFile(filePath: String, fullDestinationPath: String, completionBlock:@escaping ((Data) -> Void), errorBlock:(@escaping (RestClientError) -> Void)){
        var headersToSet = ["Accept":"application/json", "X-Atlassian-Token":"nocheck"]
        if let headers = self.headers {
            headersToSet += headers
        }
        let http = SimpleHttp(auth:self.auth, headers:headersToSet)
        let destinationURL = URL(string: fullDestinationPath)!
        let fileURL = URL(string: filePath)!
        http.uploadFile(fileUrl: fileURL, destinationURL: destinationURL, completionBlock: completionBlock, errorBlock: errorBlock)
    }
    
    public func fullURLWithRelativeURL(relativeURL: String) -> String {
        return baseURL.appending(relativeURL)
    }
    
}
