//
//  SMComms.swift
//  Zebra iMZ Test
//
//  Created by Marcos Torres on 7/5/19.
//  Copyright © 2019 HSoft. All rights reserved.
//

import Foundation

let sm_true:  UInt32 = 1     // SM_TRUE
let sm_false: UInt32 = 0     // SM_FALSE

enum PaperSizeIndex: Int {
	case twoInch = 384
	case threeInch = 576
	case fourInch = 832
	case escPosThreeInch = 512
	case dotImpactThreeInch = 210
}

typealias SendCompletionHandler = (_ result: Bool, _ title: String, _ message: String) -> Void

typealias SendCompletionHandlerWithNullableString = (_ result: Bool, _ title: String?, _ message: String?) -> Void

typealias RequestStatusCompletionHandler = (_ result: Bool, _ title: String, _ message: String, _ connect: Bool) -> Void

class SMComms {
	
	static func sendCommands(_ commands: Data!, portName: String!, timeout: UInt32, completionHandler: SendCompletionHandler?) -> Bool {
		// portSettings is empty string for TSP650II
		let portSettings: String = ""
		
		var result: Bool = false
		
		var title:   String = ""
		var message: String = ""
		
		var error: NSError?
		
		var commandsArray: [UInt8] = [UInt8](repeating: 0, count: commands.count)
		
		commands.copyBytes(to: &commandsArray, count: commands.count)
		
		while true {
			guard let port: SMPort = SMPort.getPort(portName, portSettings, timeout) else {
				title   = "Fail to Open Port"
				message = ""
				break
			}
			
			defer {
				SMPort.release(port)
			}
			
			// Sleep to avoid a problem which sometimes cannot communicate with Bluetooth.
			// (Refer Readme for details)
			if #available(iOS 11.0, *), portName.uppercased().hasPrefix("BT:") {
				Thread.sleep(forTimeInterval: 0.4)
			}
			
			var printerStatus: StarPrinterStatus_2 = StarPrinterStatus_2()
			
			port.beginCheckedBlock(&printerStatus, 2, &error)
			
			if error != nil {
				break
			}
			
			let beginStatusErrorMsg = getStatusError(printerStatus)
			if !beginStatusErrorMsg.isEmpty {
				title   = "Printer Error"
				message = beginStatusErrorMsg + " (BeginCheckedBlock)"
				break
			}
			
			let startDate: Date = Date()
			
			var total: UInt32 = 0
			
			while total < UInt32(commands.count) {
				let written: UInt32 = port.write(commandsArray, total, UInt32(commands.count) - total, &error)
				
				if error != nil {
					break
				}
				
				total += written
				
				if Date().timeIntervalSince(startDate) >= 30.0 {     // 30000mS!!!
					title   = "Printer Error"
					message = "Write port timed out"
					break
				}
			}
			
			if total < UInt32(commands.count) {
				break
			}
			
			port.endCheckedBlockTimeoutMillis = 30000     // 30000mS!!!
			
			port.endCheckedBlock(&printerStatus, 2, &error)
			
			if error != nil {
				break
			}
			
			let endStatusErrorMsg = getStatusError(printerStatus)
			if !endStatusErrorMsg.isEmpty {
				title   = "Printer Error"
				message = endStatusErrorMsg + " (EndCheckedBlock)"
				break
			}
			
			title   = "Send Commands"
			message = "Success"
			
			result = true
			break
		}
		
		if error != nil {
			title   = "Printer Error"
			message = error!.description
		}
		
		if completionHandler != nil {
			completionHandler!(result, title, message)
		}
		
		return result
	}
	
	static func getStatusError(_ printerStatus: StarPrinterStatus_2) -> String {
		if printerStatus.offline == sm_true {
			return "Printer is offline"
		}
		if printerStatus.coverOpen == sm_true {
			return "Printer cover is open"
		}
		if printerStatus.receiptPaperEmpty == sm_true {
			return "Printer is out of paper"
		}
		if printerStatus.overTemp == sm_true {
			return "Printer head is overheated"
		}
		if printerStatus.unrecoverableError == sm_true {
			return "Critical unrecoverable error"
		}
		if printerStatus.cutterError == sm_true {
			return "Paper cutter error"
		}
		if printerStatus.headThermistorError == sm_true {
			return "Head thermistor error"
		}
		if printerStatus.voltageError == sm_true {
			return "Voltage error"
		}
		return ""
	}
	
}
