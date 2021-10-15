//
//  RequestManager.swift
//  DRsdk
//
//  Source code
//

import Alamofire
import SwiftyJSON
import Foundation

protocol NetworkManagerProtocol {
    init(host: String,
         token: String,
         userToken: String)
    func makeGetRequest(_ path: String, parameters: [String: AnyObject]?, completedBlock:@escaping RequestManagerCompletedBlock) -> Alamofire.Request?
    func makeDeleteRequest(_ path: String, parameters: [String: AnyObject]?, completedBlock:@escaping RequestManagerCompletedBlock) -> Alamofire.Request?
    func makePostRequest(_ path: String, parameters: [String: AnyObject]?, completedBlock:@escaping RequestManagerCompletedBlock) -> Alamofire.Request?
}

protocol RequestManagerProtocol: RequestManagerCodable {
    var applicationNetworkManager: ApplicationNetworkManagerProtocol? { get set }
    var loginManager: LoginManagerProtocol? { get set }
    var errorParser: RequestManagerErrorParserProtocol? { get set }
}

protocol RequestManagerCodable: NetworkManagerProtocol {
    @discardableResult
    func makeGetRequest<Result: Decodable>(_ path: String, keyPath: String?, parameters: [String: Any]?,
                                           completion: ((CodableRequestResult<Result>) -> Void)?) -> Alamofire.Request?
    @discardableResult
    func makePostRequest<Result: Decodable>(_ path: String, keyPath: String?, parameters: [String: Any]?,
                                            completion: ((CodableRequestResult<Result>) -> Void)?) -> Alamofire.Request?
    @discardableResult
    func makeDeleteRequest<Result: Decodable>(_ path: String, keyPath: String?, parameters: [String: Any]?,
                                              completion: ((CodableRequestResult<Result>) -> Void)?) -> Alamofire.Request?
}

typealias RequestManagerCompletedBlock = ((FetchRequestResult<JSON>) -> Void)

enum CodableRequestResult<Data: Decodable> {
    case success(Data)
    case failure(Error)
}

enum FetchRequestResult<T> {
    case success(T)
    case failure(Error)
}

class RequestManager {
    private let host: String
    private let token: String
    private let userToken: String
    var applicationNetworkManager: ApplicationNetworkManagerProtocol?
    weak var loginManager: LoginManagerProtocol?
    var errorParser: RequestManagerErrorParserProtocol?

    let arrayUrlsNotNeedToken = ["auth", "/registration"]

    // MARK: - Initialization
    public required init(host: String,
                         token: String,
                         userToken: String) {
        self.host = host
        self.token = token
        self.userToken = userToken
        self.errorParser = RequestManagerErrorParser()
    }

    let almgr : Session = {
        return Session()
    }()
}

// MARK: - RequestManagerCodable
extension RequestManager: RequestManagerCodable {
    func makeGetRequest<Result>(_ path: String, keyPath: String?, parameters: [String: Any]?,
                                completion: ((CodableRequestResult<Result>) -> Void)?) -> Alamofire.Request? {
        return makeRequest(.get, path: path, keyPath: keyPath, parameters: parameters, completion: completion)
    }

    func makePostRequest<Result>(_ path: String, keyPath: String?, parameters: [String: Any]?,
                                 completion: ((CodableRequestResult<Result>) -> Void)?) -> Alamofire.Request? {
        return makeRequest(.post, path: path, keyPath: keyPath, parameters: parameters, completion: completion)
    }

    func makeDeleteRequest<Result>(_ path: String, keyPath: String?, parameters: [String: Any]?,
                                   completion: ((CodableRequestResult<Result>) -> Void)?) -> Alamofire.Request? {
        return makeRequest(.delete, path: path, keyPath: keyPath, parameters: parameters, completion: completion)
    }

    @discardableResult
    func makeRequest<Result>(_ method: HTTPMethod, path: String, keyPath: String?,
                             parameters: [String: Any]?,
                             completion: ((CodableRequestResult<Result>) -> Void)?) -> Alamofire.Request? {

        var httpHeaders = applicationHeaders()
        httpHeaders["Content-Type"] = "application/json"
        let encoding: ParameterEncoding
        switch method {
        case .get:
            encoding = URLEncoding.default
        default:
            encoding = JSONEncoding.default
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        var requestPath = "\(self.host)\(path)"
        if path.contains("run.mocky") {
            requestPath = "\(path)"
        }
        var params = getConfiguredRequestParameters(parameters)
        if path.contains("run.mocky") {
            params = [String: Any]()
        }
        let request = almgr.request(
            requestPath,
            method: method,
            parameters: params,
            encoding: encoding,
            headers: httpHeaders)

        print( "REQUEST: \n path: \(path) \n params: \(params) \n httpHeaders: \(httpHeaders)")
        return request.responseDecodableObject(keyPath: keyPath, decoder: decoder) { (response: DataResponse<Result, AFError>) in
            if let data = response.value {
                completion?(CodableRequestResult.success(data))
            } else {
                let error = ServerError(code: response.error?.responseCode ?? 0, message: response.error?.errorDescription ?? "Request manager -> makeRequest ошибка тут")
                print("Request finished with error for path: \(requestPath). Retrying...")
                self.retryRequestAfterHandleIncludedError(error, retryBlock: {
                    self.makeRequest(method, path: path, keyPath: keyPath, parameters: parameters, completion: completion)
                }, failureBlock: { error in
                    completion?(CodableRequestResult.failure(error))
                })
            }
        }
    }
}

// MARK: - RequestManagerProtocol
extension RequestManager: RequestManagerProtocol {
    func makeDeleteRequest(_ path: String, parameters: [String: AnyObject]?, completedBlock: @escaping RequestManagerCompletedBlock) -> Alamofire.Request? {
        return makeRequest(.delete, path: path, parameters: parameters, completedBlock: completedBlock)
    }

    func makeGetRequest(_ path: String, parameters: [String: AnyObject]?, completedBlock: @escaping RequestManagerCompletedBlock) -> Alamofire.Request? {
        return makeRequest(.get, path: path, parameters: parameters, completedBlock: completedBlock)
    }

    func makePostRequest(_ path: String, parameters: [String: AnyObject]?, completedBlock: @escaping RequestManagerCompletedBlock) -> Alamofire.Request? {
        return makeRequest(.post, path: path, parameters: parameters, completedBlock: completedBlock)
    }

    func makeRequest(_ method: HTTPMethod, path: String, parameters: [String: AnyObject]?, completedBlock: @escaping RequestManagerCompletedBlock) -> Alamofire.Request? {

        var httpHeaders = applicationHeaders()
        httpHeaders["Content-Type"] = "application/json"
        var encoding: ParameterEncoding
        switch method {
        case .get:
            encoding = URLEncoding.default
        default:
            encoding = JSONEncoding.default
        }

        var requestPath = "\(self.host)\(path)"
        if path.contains("run.mocky") {
            requestPath = "\(path)"
        }
        var params = getConfiguredRequestParameters(parameters)
        if path.contains("run.mocky") {
            params = [String: Any]()
        }
            
        let request = almgr.request(requestPath, method: method,
            parameters: params,
            encoding: encoding, headers: httpHeaders)
//            Logger.log(debug: "REQUEST: \n\(request.description)")
        print("REQUEST: \n PATH: \(path) \n PARAMS: \(params) \n HEADERS: \(httpHeaders)")

        return request.responseJSON { response in
            
            switch response.result {
            case let .success(jsonDictionary):
                let json = JSON(jsonDictionary)
                print("\(jsonDictionary)")
                
                if json["success"].boolValue == false {
                    print("Request to \(String(describing: response.request?.url)) finished unsuccessfully. Retrying...")
                    self.retryRequestAfterHandleIncludedJSONError(json, retryBlock: {
                        _ = self.makeRequest(method, path: path, parameters: parameters, completedBlock: completedBlock)
                    }, failureBlock: { error in
                        completedBlock(FetchRequestResult.failure(error))
                    })
                } else {
                    completedBlock(FetchRequestResult.success(json))
                }
            case let .failure(error):
                let errorr = response.value as? NSDictionary
                print("\(errorr)")
                print("Request \(String(describing: response.request)) failed with error")
                completedBlock(FetchRequestResult.failure(error))
            }
        }
    }

    func retryRequestAfterHandleIncludedJSONError(_ json: JSON, retryBlock: @escaping (() -> Void), failureBlock: @escaping ((Error) -> Void)) {
        guard let errorParser = self.errorParser else {
            print("Parser isn't specified")
            failureBlock(CommonError.classWrongConfigured)
            return
        }
        let error = errorParser.parseErrorJSON(json["data"]["error"])
        retryRequestAfterHandleIncludedError(error, retryBlock: retryBlock, failureBlock: failureBlock)
    }

    func retryRequestAfterHandleIncludedError(_ error: NetworkError, retryBlock: @escaping (() -> Void), failureBlock: @escaping ((Error) -> Void)) {
        if error.code == 300, let applicationNetworkManager = self.applicationNetworkManager {
            print("refresh expired application token")
            applicationNetworkManager.refreshApplicationToken { success in
                if success {
                    retryBlock()
                } else {
                    failureBlock(error)
                }
            }
        } else if error.code == 104 || error.code == 4043, let loginManager = self.loginManager {
            print("refresh expired user token")
            if !RequestManagerStorage.shared.refreshingUserToken {
                RequestManagerStorage.shared.refreshingUserToken = true
                loginManager.refreshUserToken { loginError in
                    if loginError != nil {
                        RequestManagerStorage.shared.removeAllRetry()
//                        loginManager.wipeLoginData()
                        NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: "showLoginNotification"), object: nil)
                        failureBlock(error)
                    } else {
                        RequestManagerStorage.shared.refreshingUserToken = false
                        RequestManagerStorage.shared.reloadAfterUpdateToken()
                        retryBlock()
                    }
                    RequestManagerStorage.shared.refreshingUserToken = false
                }
                failureBlock(error)
            } else {
                RequestManagerStorage.shared.addNewRetryBlock(retryBlock: retryBlock)
            }
        } else {
            failureBlock(error)
        }
    }

    fileprivate func applicationHeaders() -> HTTPHeaders {
        var params = HTTPHeaders()
        /* params["latitude"] = "\(ConfigControl.sharedInstance.location?.coordinate.latitude ?? 0)"
        params["longitude"] = "\(ConfigControl.sharedInstance.location?.coordinate.longitude ?? 0)"
         */
        
//        if let applicationToken = applicationNetworkManager?.applicationToken {
//            params["token"] = applicationToken
//        }
//        params["sign"] = "71b8a7d06f288ee96204f7f3b46c4a03"
        params["locale"] = "ru"
        params["version"] = "ios-sdk"
        params["login"] = "test"
//        params["token"] = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOjEzLCJhdWQiOjEzLCJpYXQiOjE2MTg0MDQ2NjcsIm5iZiI6MTYxODQwNDY2NywiZXhwIjoxNjE4NDkxMDY3fQ.FurQDkTQsla90ZGTiOhpOQhHgrFqAQiMYVQeXvlU1Fo"
        params["token"] = token
//        params["User-Token"] = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOjkzLCJhdWQiOjkzLCJpYXQiOjE2MTg0MDQ2NjcsIm5iZiI6MTYxODQwNDY2NywiZXhwIjoxNjE4NDkxMDY3fQ.CyHUhhyk248wvvkxpVqsliJFJsOEl5eaJijc1I7oXuk"
        params["User-Token"] = userToken
//        if let userToken = loginManager?.loginStorage.token {
//            params["User-Token"] = userToken // set user token
//        }
        return params
    }

    func getConfiguredRequestParameters(_ parameters: [String: Any]?) -> [String: Any] {
        var finalParameters: [String: Any] = parameters ?? [:]
//        finalParameters["application"] = versionParameters // set application version parameters
//        if let userToken = loginManager?.loginStorage.token {
//            finalParameters["User-Token"] = userToken // set user token
//        }
        return finalParameters
    }
}

class RequestManagerStorage {
    static let shared = RequestManagerStorage()

    var refreshingUserToken = false
    private var requestForReload : [(() -> Void)] = []

    func reloadAfterUpdateToken() {
        for retryBlock in requestForReload {
            retryBlock()
        }
        requestForReload.removeAll()
    }

    func removeAllRetry() {
        requestForReload.removeAll()
    }

    func addNewRetryBlock(retryBlock:@escaping (() -> Void)) {
        requestForReload.append(retryBlock)
    }
}
