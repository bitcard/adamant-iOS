//
//  HardFeeCalculator.swift
//  Adamant
//
//  Created by Anokhov Pavel on 16.01.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation

class HardFeeCalculator: FeeCalculator {
	func estimatedFeeFor(message: AdamantMessage) -> UInt {
		switch message {
		case .text(let text):
			return AdamantUtilities.from(double: ceil(Double(text.count) / 255.0) * 0.001)
		}
	}
	
	func estimatedFeeFor(transfer: UInt) -> UInt {
		return AdamantUtilities.from(double: 0.5)
	}
}
