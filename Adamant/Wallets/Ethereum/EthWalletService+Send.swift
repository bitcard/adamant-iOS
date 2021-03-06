//
//  EthWalletService+Send.swift
//  Adamant
//
//  Created by Anokhov Pavel on 21.08.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import web3swift
import struct BigInt.BigUInt
import PromiseKit

extension EthereumTransaction: RawTransaction {
    var txHash: String? {
        return txhash
    }
}

extension EthWalletService: WalletServiceTwoStepSend {
    typealias T = EthereumTransaction
    
    func transferViewController() -> UIViewController {
        guard let vc = router.get(scene: AdamantScene.Wallets.Ethereum.transfer) as? EthTransferViewController else {
            fatalError("Can't get EthTransferViewController")
        }
        
        vc.service = self
        return vc
    }
    
    
    // MARK: Create & Send
    func createTransaction(recipient: String, amount: Decimal, completion: @escaping (WalletServiceResult<EthereumTransaction>) -> Void) {
        // MARK: 1. Prepare
        guard let ethWallet = ethWallet else {
            completion(.failure(error: .notLogged))
            return
        }
        
        guard let ethRecipient = EthereumAddress(recipient) else {
            completion(.failure(error: .accountNotFound))
            return
        }
        
        guard let bigUIntAmount = Web3.Utils.parseToBigUInt(String(format: "%.18f", amount.doubleValue), units: .eth) else {
            completion(.failure(error: .invalidAmount(amount)))
            return
        }
        
        guard let keystoreManager = web3.provider.attachedKeystoreManager else {
            completion(.failure(error: .internalError(message: "Failed to get web3.provider.KeystoreManager", error: nil)))
            return
        }
        
        // MARK: Go background
        defaultDispatchQueue.async {
            // MARK: 2. Create contract
            
            var options = Web3Options.defaultOptions()
            options.from = ethWallet.ethAddress
            options.value = bigUIntAmount
            
            guard let contract = self.web3.contract(Web3.Utils.coldWalletABI, at: ethRecipient) else {
                completion(.failure(error: .internalError(message: "ETH Wallet: Send - contract loading error", error: nil)))
                return
            }
            
            guard let estimatedGas = contract.method(options: options)?.estimateGas(options: nil).value else {
                completion(.failure(error: .internalError(message: "ETH Wallet: Send - retrieving estimated gas error", error: nil)))
                return
            }
            
            options.gasLimit = estimatedGas
            
            guard let gasPrice = self.web3.eth.getGasPrice().value else {
                completion(.failure(error: .internalError(message: "ETH Wallet: Send - retrieving gas price error", error: nil)))
                return
            }
            
            options.gasPrice = gasPrice
            
            guard let intermediate = contract.method(options: options) else {
                completion(.failure(error: .internalError(message: "ETH Wallet: Send - create transaction issue", error: nil)))
                return
            }
            
            do {
                let transaction = try intermediate.assemblePromise().then { transaction throws -> Promise<EthereumTransaction> in
                    var trs = transaction
                    try Web3Signer.signTX(transaction: &trs, keystore: keystoreManager, account: ethWallet.ethAddress, password: "")
                    let promise = Promise<EthereumTransaction>.pending()
                    promise.resolver.fulfill(trs)
                    return promise.promise
                }.wait()
                
                completion(.success(result: transaction))
            } catch {
                completion(.failure(error: WalletServiceError.internalError(message: "Transaction sign error", error: error)))
            }
        }
    }
    
    func sendTransaction(_ transaction: EthereumTransaction, completion: @escaping (WalletServiceResult<String>) -> Void) {
        defaultDispatchQueue.async {
            switch self.web3.eth.sendRawTransaction(transaction) {
            case .success(let result):
                completion(.success(result: result.hash))
                
            case .failure(let error):
                completion(.failure(error: error.asWalletServiceError()))
            }
        }
    }
}
