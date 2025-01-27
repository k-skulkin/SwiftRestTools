//
//  SimpleHttp.swift
//  swift-utilities
//
//  Created by Bill Gestrich on 10/28/17.
//  Copyright © 2017 Bill Gestrich. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct BasicAuth {
    let username : String
    let password : String
    
    public init(username : String, password: String){
        self.username = username
        self.password = password
    }
}


public class SimpleHttp: NSObject {
    
    var auth : BasicAuth?
    var headers: [String: String] = [String: String]()
    
    init(auth: BasicAuth?){
        self.auth = auth
        super.init()
    }
    
    convenience init(auth: BasicAuth?, headers: [String: String]){
        self.init(auth: auth)
        self.headers = headers
    }
    
    func get(
		url: URL,
		completionHandler: @escaping (Result<Data, RestClientError>) -> Void
	) {
        let request = URLRequest(url: url)

        var authHeaders = [String: String]()

		if let auth {
            let userPasswordData = "\(auth.username):\(auth.password)".data(using: .utf8)
            let base64EncodedCredential = userPasswordData!.base64EncodedString()
            let authString = "Basic \(base64EncodedCredential)"
            authHeaders["Authorization"] = authString
        }
        authHeaders += headers

		let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = authHeaders
        
        print("Curl = \(curlRequestWithURL(url:url.absoluteString, headers:authHeaders))")
        
        let session: URLSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        
        let task = session.dataTask(
			with: request
		) { data, response, error in
            if let error = error {
                print("Error while trying to re-authenticate the user: \(error)")
				completionHandler(
					.failure(.serviceError(error))
				)
            } else if
				let response = response as? HTTPURLResponse,
                300..<600 ~= response.statusCode
			{
				completionHandler(
					.failure(.statusCode(response.statusCode))
				)
            } else if let data {
				completionHandler(
					.success(data)
				)
            } else {
				completionHandler(
					.failure(.noData)
				)
            }
        }
        
        task.resume()
    }

	// MARK: Post
    
    func post<T>(
		url: URL,
		payload: T,
		completionHandler: @escaping (Result<Data, RestClientError>) -> Void
	)  where T : Encodable {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

		let data = try! JSONEncoder().encode(payload)
		request.httpBody = data

        var headers = [String: String]()

		if let auth {
			let userPasswordData = "\(auth.username):\(auth.password)".data(using: .utf8)
			let base64EncodedCredential = userPasswordData!.base64EncodedString()
			let authString = "Basic \(base64EncodedCredential)"
			headers["Authorization"] = authString
		}
		headers += self.headers

		headers.forEach { (key: String, value: String) in
			request.addValue(value, forHTTPHeaderField: key)
		}

		print("Curl = \(curlRequestWithURL(url: url.absoluteString, headers: headers))")
        
        let task = URLSession.shared.dataTask(
			with: request
		) { (data, response, error) in
            if let error = error {
                return completionHandler(
					.failure(.serviceError(error))
				)
            }
            
            guard let data = data else {
				return completionHandler(
					.failure(.noData)
				)
            }

            guard let response = response else {
				return completionHandler(
					.failure(.noResponse)
				)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
				return completionHandler(
					.failure(.failedHTTPURLResponseParsing)
				)
            }

            guard let urlString = String(data: data, encoding: .utf8) else {
				return completionHandler(
					.failure(.failedDataParsing)
				)
            }

			guard (200...299).contains(httpResponse.statusCode) else {
				return completionHandler(
					.failure(
						.wrongStatusCode("Status code \(httpResponse.statusCode) returned. Data: \(urlString)")
					)
				)
			}

			completionHandler(
				.success(data)
			)
        }
        task.resume()
    }

	// MARK: Upload
	
    func uploadFile(fileUrl: URL, destinationURL: URL, completionBlock:(@escaping (Data) -> Void), errorBlock:(@escaping (RestClientError) -> Void)){
        
        let fileName = (fileUrl.path as NSString).lastPathComponent
        let fileData = FileManager.default.contents(atPath: fileUrl.path)!
        let parameterNameForFile = "file" //TODO: move out of here as this is jira api specific
        
        var urlRequest = URLRequest(url: destinationURL)
        urlRequest.httpMethod = "POST"
        
        let config = URLSessionConfiguration.default
        
        var headers = [String: String]()
        if let auth = self.auth {
            var authString = ""
            let userPasswordData = "\(auth.username):\(auth.password)".data(using: .utf8)
            let base64EncodedCredential = userPasswordData!.base64EncodedString(options: Data.Base64EncodingOptions.init(rawValue: 0))
            authString = "Basic \(base64EncodedCredential)"
            headers["authorization"] = authString
        }
        
        headers += self.headers
        config.httpAdditionalHeaders = headers
        
        let boundary = UUID().uuidString
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(parameterNameForFile)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        
        let contentType = "application/octet-stream"
        data.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        let session: URLSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)

         let task = session.uploadTask(with: urlRequest, from: data, completionHandler: { responseData, response, error in
            if let error = error {
                print("Error while trying to re-authenticate the user: \(error)")
                errorBlock(.serviceError(error)) //Error
            } else if let response = response as? HTTPURLResponse,
                300..<600 ~= response.statusCode {
                errorBlock(.statusCode(response.statusCode)) //Error
            } else if let data = responseData {
                completionBlock(data) //Success
            } else {
                errorBlock(.noData) //Error
            }
        })
        
        task.resume()
    }
    
}

func += <K, V> (left: inout [K:V], right: [K:V]) {
    for (k, v) in right {
        left[k] = v
    }
}

func curlRequestWithURL (url: String, headers:Dictionary<String, String>) -> String {
    
    //Example output:
    //curl --header "Date: January 10, 2017 14:37:21" -L  <url>
    
    var toRet = "curl "
    
    if headers.count > 0 {
        for (headerKey, headerValue) in headers {
            toRet += "--header "
            toRet += " \"\(headerKey): \(headerValue)\" "
        }
        
        toRet += "-L "
        
        toRet += "\"\(url)\""
    }
    
    return toRet
}
