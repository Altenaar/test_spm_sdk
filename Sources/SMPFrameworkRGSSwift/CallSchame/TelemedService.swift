import Foundation
import Alamofire
import SwiftyJSON

protocol TelemedServiceProtocol: ServiceProtocol {
    // telemed/join
    func createJoinConsultationWithParams(_ params: [String: AnyObject], completionBlock:@escaping ( Error?, JoinConsultation?) -> Void) -> Alamofire.Request?
   
    // telemed/leave
    func createLeaveConsultationWithParams(_ params: [String: AnyObject], completionBlock:@escaping ( Error?) -> Void) -> Alamofire.Request?
}

class TelemedService: TelemedServiceProtocol {
    let requestManager: RequestManagerProtocol

    init(requestManager: RequestManagerProtocol) {
        self.requestManager = requestManager
    }

    func createJoinConsultationWithParams(_ params: [String: AnyObject], completionBlock: @escaping ( Error?, JoinConsultation?) -> Void) -> Alamofire.Request? {
        let parameters = params
        let request = requestManager.makePostRequest("telemed/join",
                                                     parameters: parameters,
                                                     completedBlock: { [weak self] result in
                                                        switch result {
                                                        case .success(let json):
                                                            completionBlock(nil, self?.parseJoinConsultationsData(data: json["data"]))
                                                        case .failure(let error):
                                                            completionBlock(error, nil)
                                                        }
        })
        return request
    }
    
    //telemed/leave
    func createLeaveConsultationWithParams(_ params: [String: AnyObject], completionBlock: @escaping ( Error?) -> Void) -> Alamofire.Request? {
        let request = requestManager.makePostRequest("telemed/leave",
                                                    parameters: params,
                                                    completedBlock: {
                                                        switch $0 {
                                                        case .success(let json):
                                                            print(json)
                                                            completionBlock(nil)
                                                        case .failure(let error):
                                                            completionBlock(error)
                                                        }
        })
        return request
    }
}

extension TelemedService {
    func parseJoinConsultationsData(data: JSON) -> JoinConsultation {
        var joinConsultation = JoinConsultation()

        if let useMediaServer = data["useMediaServer"].int {
            joinConsultation.useMediaServer = useMediaServer == 1 ? true : false
        }
        if let wssPostUrl = data["wssPostUrl"].string {
            joinConsultation.wssPostUrl = wssPostUrl
        }
        if let wssUrl = data["wssUrl"].string {
            joinConsultation.wssUrl = wssUrl
        }
        if let clientId = data["userId"].string {
            joinConsultation.clientId = clientId
        }
        if let roomId = data["roomId"].string {
            joinConsultation.roomId = roomId
        }
        if let isInitiator = data["isInitiator"].string {
            joinConsultation.isInitiator = isInitiator
        }

        if let arrayTurn = data["turnServerOverride"].array, arrayTurn.count > 0 {
            var arrayUrls = [String]()
            for turn in arrayTurn {
                if let turnServerOverride = turn.dictionary {
                    
                    if joinConsultation.usernameTurn == nil {
                        joinConsultation.usernameTurn = turnServerOverride["username"]?.string
                    }
                    if joinConsultation.credentialTurn == nil {
                        joinConsultation.credentialTurn = turnServerOverride["credential"]?.string
                    }
//                    joinConsultation.usernameTurn = turnServerOverride["username"]?.string
//                    joinConsultation.credentialTurn = turnServerOverride["credential"]?.string
                    if let unwrapImagesArray = turnServerOverride["urls"]?.array {
                        for url in unwrapImagesArray {
                            if let unwrapString = url.string {
                                arrayUrls.append(unwrapString)
                            }
                        }
                    }
                }
            }
            joinConsultation.turnServers = arrayUrls
        }
        return joinConsultation
    }
}
