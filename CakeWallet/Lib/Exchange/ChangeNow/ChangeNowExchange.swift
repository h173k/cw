import Foundation
import CakeWalletLib
import CWMonero
import SwiftyJSON
import Alamofire
import RxSwift

final class ChangeNowExchange: Exchange {
    static let pairs: [Pair] = {
        return CryptoCurrency.all.map { i -> [Pair] in
            return CryptoCurrency.all.map { o -> Pair? in
                // XMR -> BTC is only for XMR.to
                
                if i == .bitcoin && o == .monero {
                    return Pair(from: i, to: o, reverse: false)
                }
                
                if i == .monero && o == .bitcoin {
                    return nil
                }
                
                return Pair(from: i, to: o, reverse: true)
                }.compactMap { $0 }
            }.flatMap { $0 }
    }()
    
    static let provider = ExchangeProvider.changenow
    static let apiKey = AppSecrets.changeNowApiKey
    static let uri = "https://changenow.io/api/v1/"
    private static let baseExchangeAmountURI = String(format: "%@exchange-amount/", uri)
    private static let minAmountURI = String(format: "%@min-amount/", uri)
    private static let createTransactionURI = String(format: "%@transactions/", uri)
    
    let name: String
    let pairs: [Pair]
    
    init() {
        pairs = [Pair(from: CryptoCurrency.monero, to: CryptoCurrency.bitcoin, reverse: false)]
        name = "ChangeNow"
    }
    
    func createTrade1(from request: ChangeNowTradeRequest) -> Observable<ChangeNowTrade> {
        return Observable.create({ o -> Disposable in
            let url = "\(ChangeNowExchange.createTransactionURI)\(ChangeNowExchange.apiKey)"
            let parameters = [
                "from": request.from.formatted().lowercased(),
                "to": request.to.formatted().lowercased(),
                "address": request.address,
                "amount": request.amount,
                "refundAddress": request.refundAddress
            ]

            Alamofire.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default).responseData(completionHandler: { response in
                if let error = response.error {
                    o.onError(error)
                    return
                }
                
                guard let data = response.data else {
                    return
                }
                
                do {
                    let json = try JSON(data: data)
                    
                    if let error = json["error"].string {
                        if error == "cannot_create_transction" {
                            o.onError(ExchangerError.tradeNotCreated)
                        } else {
                            o.onError(ExchangerError.notCreated(error))
                        }
                        
                        return
                    }
                    
                    let trade = ChangeNowTrade(
                        id: json["id"].stringValue,
                        from: request.from,
                        to: request.to,
                        inputAddress: json["payinAddress"].stringValue,
                        amount: makeAmount(request.amount, currency: request.from),
                        payoutAddress: json["payoutAddress"].stringValue,
                        refundAddress: json["refundAddress"].string,
                        state: .created,
                        extraId: json["payinExtraId"].string,
                        outputTransaction: nil)
                    o.onNext(trade)
                } catch {
                    o.onError(error)
                }
            })
            
            return Disposables.create()
        })
    }
    
    func calculateAmount(_ amount: Double, from input: CryptoCurrency, to output: CryptoCurrency) -> Observable<Amount> {
        return Observable.create({ o -> Disposable in
            let url = "\(ChangeNowExchange.baseExchangeAmountURI)\(String(amount))/\(input.formatted())_\(output.formatted())"
            Alamofire.request(url).responseData(completionHandler: { response in
                if let error = response.error {
                    o.onError(error)
                    return
                }

                guard let data = response.data else {
                    return
                }
                
                do {
                    let json = try JSON(data: data)
                    let estimatedAmount = json["estimatedAmount"].stringValue
                    let amount = makeAmount(estimatedAmount, currency: output)
                    o.onNext(amount)
                } catch {
                    o.onError(error)
                }
            })
            
            return Disposables.create()
        })
    }
    
    func fetchLimist(from input: CryptoCurrency, to output: CryptoCurrency) -> Observable<ExchangeLimits> {
        return Observable.create({ o -> Disposable in
            let url = "\(ChangeNowExchange.minAmountURI)\(input.formatted())_\(output.formatted())"
            Alamofire.request(url).responseData(completionHandler: { response in
                if let error = response.error {
                    o.onError(error)
                    return
                }
                
                guard let data = response.data else {
                    return
                }
                
                do {
                    let json = try JSON(data: data)
                    let minAmountRaw = json["minAmount"].stringValue
                    let minAmount = makeAmount(minAmountRaw, currency: output)
                    let limits = (min: minAmount, max: nil) as ExchangeLimits
                    o.onNext(limits)
                } catch {
                    o.onError(error)
                }
            })
            
            return Disposables.create()
        })
    }
}
