//
//  OrderService.swift
//  DRsdk
//
//  Source code
//

import Foundation
import Alamofire

protocol OrderServiceProtocol: ServiceProtocol {
    // GET /user/order/{id}
    func getOrder(id: String, _ completedBlock: @escaping ((_ error: Error?, _ orders: ConsultationInformationObject?) -> Void))
}

class OrderService: OrderServiceProtocol {
    enum TypeOrdersList: String {
        case history
        case future
        case current
        case all
        case futureAndCurrent
        case filled
    }
    let requestManager: RequestManagerProtocol

    init(requestManager: RequestManagerProtocol) {
        self.requestManager = requestManager
    }
    
    // GET /user/order/{id}
    func getOrder(id: String, _ completedBlock: @escaping ((_ error: Error?, _ orders: ConsultationInformationObject?) -> Void)) {
        _ = requestManager.makeGetRequest("user/order/\(id)", parameters: [String : AnyObject](), completedBlock: { result in
            switch result {
            case .success(let json):
                print(json)
                if let data  = try? json.dictionary?["data"]?.rawData() {
                    let decoder = JSONDecoder()
                    do {
                        let order = try decoder.decode(ConsultationInformationObject.self, from: data)
                        print(order)
                        completedBlock(nil, order)
                        return
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                completedBlock(CommonError.encodingError, nil)
            case .failure(let error):
                completedBlock(error, nil)
            }
        })
    }
}

