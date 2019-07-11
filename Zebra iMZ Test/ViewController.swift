//
//  ViewController.swift
//  Zebra iMZ Test
//
//  Created by Marcos Torres on 6/26/17.
//  Copyright © 2017 HSoft. All rights reserved.
//

import UIKit

enum BxlPrintAction {
	case none
	case text
	case image
}

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UITextFieldDelegate, BXPrinterControlDelegate {
	
	@IBOutlet weak var textMessage: UITextField!
	
	@IBOutlet weak var imageView: UIImageView!
	
	@IBOutlet weak var loaderView: UIView!
	
	@IBOutlet weak var loaderSpinner: UIActivityIndicatorView!
	
	@IBOutlet var loaderLabel: UILabel!
	
	@IBOutlet var printerInfoLabel: UILabel!
	
	var bxlPrinterController: BXPrinterController!
	
	var bxlPrinter: BXPrinter!
	
	var printerModel: String!
	
	var textToPrint: String!
	
	var availablePrinters: [BTPrinterData]!
	
	var selectedPrinter: BTPrinterData!
	
	var imagePicker: UIImagePickerController!
	
	let supportedZbrModels: [String] = ["imz220", "imz320"]
	
	let supportedBxlModels: [String] = ["spp-r200ii", "spp-r200iii"]
	
	var printerSelected: Bool!
	
	var imageSelected: Bool!
	
	var bxlAction: BxlPrintAction!

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		
		imagePicker = UIImagePickerController()
		imagePicker.delegate = self
		imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
		
		textMessage.delegate = self
		
		availablePrinters = []
		selectedPrinter = BTPrinterData()
		printerSelected = false
		printerModel = ""
		imageSelected = false
		textToPrint = ""
		bxlAction = .none
		
		// initialize controller
		bxlPrinterController = BXPrinterController.getInstance()
		bxlPrinterController.delegate = self
		bxlPrinterController.lookupCount = 5
		bxlPrinterController.asyncMode(true)
		bxlPrinterController.transactionMode(false)
		bxlPrinterController.autoConnection = Int(BXL_CONNECTIONMODE_NOAUTO)
		bxlPrinterController.open()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		if bxlPrinterController.isConnected() {
			bxlPrinterController.disconnect()
		}
		bxlPrinterController.close()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	// MARK: - IB Actions
	
	@IBAction func tapPrintText(_ sender: AnyObject) {
		let text = textMessage.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
		if !text.isEmpty {
			textToPrint = text
			switch selectedPrinter.brand {
			case "zebra":
				zbrPrintText()
				break
			case "bixolon":
				bxlPrintText()
				break
			case "star":
				strPrintText()
				break
			default:
				showAlert(asError: true, withMessage: "Unknown printer brand")
			}
		}
	}
	
	@IBAction func tapChooseImage(_ sender: AnyObject) {
		present(imagePicker, animated: true, completion: nil)
	}
	
	@IBAction func tapPrintImage(_ sender: AnyObject) {
		guard imageSelected else {
			showAlert(asError: true, withMessage: "You need to pick an image first")
			return
		}
		switch selectedPrinter.brand {
		case "zebra":
			zbrPrintImage()
			break
		case "bixolon":
			bxlPrintImage()
			break
		case "star":
			strPrintImage()
			break
		default:
			showAlert(asError: true, withMessage: "Unknown printer brand")
		}
	}
	
	@IBAction func tapResetPrinter(_ sender: Any) {
		if selectedPrinter.brand == "zebra" {
			resetZbrPrinter()
		} else {
			showAlert(asError: false, withMessage: "Reset not implemented for selected printer")
		}
	}
	
	@IBAction func tapSelectPrinter(_ sender: Any) {
		findBtPrinters()
	}
	
	// MARK: - Text field delegate
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if textField.isFirstResponder {
			textField.resignFirstResponder()
		}
		return true
	}
	
	// MARK: - ImagePickerController Delegate
	
	// https://makeapppie.com/2014/12/04/swift-swift-using-the-uiimagepickercontroller-for-a-camera-and-photo-library/
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		let chosenImage = info[UIImagePickerControllerOriginalImage] as! UIImage
		imageView.image = chosenImage
		imageSelected = true
		dismiss(animated: true, completion: nil)
	}
	
	// MARK: - Common printer methods
	
	func findBtPrinters() -> Void {
		showLoader(withMessage: "Looking for connected printers")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			self.availablePrinters = []
			let sam: EAAccessoryManager = EAAccessoryManager.shared()
			for accessory in sam.connectedAccessories {
				//print(accessory.protocolStrings)
				print(accessory)
				// get Zebra printers
				if accessory.protocolStrings.contains("com.zebra.rawport") {
					let btPrinter = BTPrinterData()
					btPrinter.brand = "zebra"
					btPrinter.name = accessory.name
					btPrinter.model = accessory.modelNumber
					btPrinter.serialNumber = accessory.serialNumber
					self.availablePrinters.append(btPrinter)
				}
				// get Bixolon printers
				if accessory.protocolStrings.contains("com.bixolon.protocol"){
					let btPrinter = BTPrinterData()
					btPrinter.brand = "bixolon"
					btPrinter.name = accessory.name
					// model contains the mac address
					btPrinter.serialNumber = accessory.modelNumber
					self.availablePrinters.append(btPrinter)
				}
				// get Star printers
				if accessory.protocolStrings.contains("jp.star-m.starpro"){
					let btPrinter = BTPrinterData()
					btPrinter.brand = "star"
					btPrinter.name = accessory.name
					// model contains the mac address
					btPrinter.serialNumber = accessory.serialNumber
					self.availablePrinters.append(btPrinter)
				}
			}
			DispatchQueue.main.async {
				self.hideLoader()
				self.displayPrinterList()
			}
		}
	}
	
	func displayPrinterList() -> Void {
		guard availablePrinters.count > 0 else {
			showAlert(asError: true, withMessage: "There are no printers connected")
			return
		}
		let actionSheet = UIAlertController(title: "Available printers", message: "Select the printer you want to use", preferredStyle: UIAlertControllerStyle.actionSheet)
		print("Available printers list:")
		for btPrinterData in availablePrinters {
			print(btPrinterData.name + " - " + btPrinterData.brand + " - " + btPrinterData.model + " - " + btPrinterData.serialNumber)
			let action = UIAlertAction(title: btPrinterData.name, style: UIAlertActionStyle.default, handler: { (theAction) in
				self.selectedPrinter = btPrinterData
				print("Selected printer: " + self.selectedPrinter.name + "(" + self.selectedPrinter.serialNumber + ")")
				self.printerSelected = true
				self.printerInfoLabel.text = self.selectedPrinter.name
				self.printerInfoLabel.isHighlighted = true
				// check printer brand before initialize
				if self.selectedPrinter.brand == "zebra" {
					self.zbInitPrinter()
				} else if self.selectedPrinter.brand == "bixolon" {
					self.bxlInitPrinter()
				} else if self.selectedPrinter.brand == "star" {
					self.strInitPrinter()
				}
			})
			actionSheet.addAction(action)
		}
		let cancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil)
		actionSheet.addAction(cancel)
		present(actionSheet, animated: true, completion: nil)
	}
	
	func unselectPrinter() -> Void {
		printerInfoLabel.text = "No printer selected"
		printerInfoLabel.isHighlighted = false
		printerSelected = false
		selectedPrinter = BTPrinterData()
	}
	
	func isPrinterSelected() -> Bool {
		if !printerSelected	{
			showAlert(asError: true, withMessage: "You need to select a printer first")
		}
		return printerSelected
	}
	
	func clearPrinterData() -> Void {
		printerSelected = false
		printerInfoLabel.text = "No printer selected"
		printerInfoLabel.isHighlighted = false
	}
	
	// MARK: - Zebra printer
	
	func getFirstBtPrinter() -> String {
		var serialNumber: String = ""
		
		// Find the Zebra BT Accessory
		let sam: EAAccessoryManager = EAAccessoryManager.shared()
		let connectedAccessories = sam.connectedAccessories
		for accessory in connectedAccessories {
			// Note: This will find the first printer connected!
			// If you have multiple Zebra printers connected,
			// you should display a list to the user and have
			// him select the one they wish to use
			if accessory.protocolStrings.index(of: "com.zebra.rawport")! >= 0 {
				serialNumber = accessory.serialNumber
				break
			}
		}
		
		return serialNumber
	}
	
	func zbInitPrinter() -> Void {
		print("Init ZBR printer")
		guard selectedPrinter.serialNumber.isEmpty == false else {
			showAlert(asError: true, withMessage: "Invalid serial number: " + selectedPrinter.serialNumber)
			return
		}
		showLoader(withMessage: "Configuring printer")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			var errorMsg = ""
			// create connection
			let thePrinterConnection = MfiBtPrinterConnection.init(serialNumber: self.selectedPrinter.serialNumber)
			// try to open the connection
			if !(thePrinterConnection?.open() ?? false) {
				errorMsg = "Error opening connection with printer " + self.selectedPrinter.serialNumber
			} else {
				// set printer language to ZPL
				do {
					// ! U1 setvar "device.languages" "zpl"
					try SGD.set("device.languages", withValue: "zpl", andWithPrinterConnection: thePrinterConnection)
					// get printer ID
					let hostId = try SGD.get("device.host_identification", withPrinterConnection: thePrinterConnection)
					print(hostId)
					self.printerModel = self.zbrGetPrinterModel(fromString: hostId)
				} catch let configErr as NSError {
					print(configErr.localizedDescription)
					errorMsg = configErr.localizedDescription
				}
				thePrinterConnection?.close()
			}
			DispatchQueue.main.async {
				self.hideLoader()
				if !errorMsg.isEmpty {
					self.showAlert(asError: true, withMessage: errorMsg)
				}
			}
		}
	}
	
	func resetZbrPrinter() -> Void {
		guard isPrinterSelected() else {
			return
		}
		showLoader(withMessage: "Resetting printer")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			var errorMsg = ""
			
			let thePrinterConnection = MfiBtPrinterConnection.init(serialNumber: self.selectedPrinter.serialNumber)
			if !(thePrinterConnection?.open() ?? false) {
				errorMsg = "Error connecting to printer " + self.selectedPrinter.serialNumber
			} else {
				// try to reset the printer
				do {
					// ! U1 setvar "device.restore_defaults" "all"
					try SGD.do("device.restore_defaults", withValue: "all", andWithPrinterConnection: thePrinterConnection)
					// ! U1 setvar "device.reset" ""
					try SGD.do("device.reset", withValue: "", andWithPrinterConnection: thePrinterConnection)
				} catch let configError as NSError {
					print(configError.localizedDescription)
					errorMsg = configError.localizedDescription
				}
				
				thePrinterConnection?.close()
			}
			
			DispatchQueue.main.async {
				self.hideLoader()
				self.clearPrinterData()
				if !errorMsg.isEmpty {
					self.showAlert(asError: true, withMessage: errorMsg)
				}
			}
		}
	}
	
	func zbrPrintText() -> Void {
		guard isPrinterSelected() else {
			return
		}
		showLoader(withMessage: "Printing text")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			var errorMsg = ""
			var nsError: NSError? = nil
			
			// Instantiate connection to Zebra Bluetooth accessory
			let thePrinterConn = MfiBtPrinterConnection.init(serialNumber: self.selectedPrinter.serialNumber)
			
			// Open the connection - physical connection is established here.
			if !(thePrinterConn?.open() ?? false) {
				errorMsg = "Error opening connection to printer " + self.selectedPrinter.name
				self.clearPrinterData()
			} else {
				let printer = ZebraPrinterFactory.getInstance(thePrinterConn, with: PrinterLanguage.init(0))
				do {
					let printerStatus = try printer?.getCurrentStatus()
					if !(printerStatus?.isReadyToPrint ?? false) {
						var msgs:[String] = []
						if (printerStatus?.isHeadOpen ?? false) {
							msgs.append("- the head is open")
							print("the head is open")
						}
						if (printerStatus?.isHeadCold ?? false) {
							msgs.append("- the head is cold")
							print("the head is cold")
						}
						if (printerStatus?.isHeadTooHot ?? false) {
							msgs.append("- the head is too hot")
							print("the head is too hot")
						}
						if (printerStatus?.isPaperOut ?? false) {
							msgs.append("- the paper is out")
							print("the paper is out")
						}
						if (printerStatus?.isRibbonOut ?? false) {
							msgs.append("- the ribbon is out")
							print("the ribbon is out")
						}
						if (printerStatus?.isReceiveBufferFull ?? false) {
							msgs.append("- the receive buffer is full")
							print("the receive buffer is full")
						}
						if (printerStatus?.isPaused ?? false) {
							msgs.append("- the printer is paused")
							print("the printer is paused")
						}
						errorMsg = msgs.joined(separator: "\n")
					} else {
						let cpclString = "! 0 200 200 110 1\r\nTEXT 4 0 5 5 \(self.textToPrint!)\r\nFORM\r\nPRINT\r\n"
						let writtenBytes = thePrinterConn?.write(cpclString.data(using: String.Encoding.utf8), error: &nsError) ?? -1
						if writtenBytes < 0 || nsError != nil {
							errorMsg = "Error writing to the printer " + self.selectedPrinter.serialNumber
						}
					}
				} catch let statErr as NSError {
					print(statErr.localizedDescription)
				}
				// close printer connection
				thePrinterConn?.close()
			}
			
			DispatchQueue.main.async {
				self.hideLoader()
				
				if !errorMsg.isEmpty {
					self.showAlert(asError: true, withMessage: errorMsg)
				}
			}
		}
	}
	
	func getPrintArea(forImage image: CGImage, forModel model: String) -> CGSize {
		let printerModel = supportedZbrModels.contains(model) ? model : supportedZbrModels[0]
		let maxWidthZ220: Int = 380 // iMZ220-200dpi: (2 x 200) - 20 = 380
		let maxWidthMz320: Int = 580 // iMZ320-200dpi: (3 x 200) - 20 = 580
		let maxWidth: Int = (printerModel == supportedZbrModels[0]) ? maxWidthZ220 : maxWidthMz320
		var targetWidth: Int = image.width
		var targetHeight: Int = image.height
		if targetWidth > maxWidth {
			let scaleFactor: Float = Float(targetWidth) / Float(maxWidth)
			targetWidth = maxWidth
			targetHeight = Int( Float(targetHeight) / scaleFactor )
		} else if targetWidth < maxWidth {
			let scaleFactor: Float = Float(maxWidth) / Float(targetWidth)
			targetWidth = maxWidth
			targetHeight = Int( Float(targetHeight) * Float(scaleFactor) )
		}
		return CGSize(width: targetWidth, height: targetHeight)
	}
	
	func zbrGetPrinterModel(fromString string: String) -> String {
		let hostRange = NSRange(location: 0, length: string.characters.count)
		let reModel = try! NSRegularExpression(pattern: "^(imz\\d+)", options: NSRegularExpression.Options.caseInsensitive)
		let modelMatches = reModel.matches(in: string, options: NSRegularExpression.MatchingOptions.withoutAnchoringBounds, range: hostRange)
		var printerModel = supportedZbrModels[0]
		if modelMatches.count > 0 {
			printerModel = (string as NSString).substring(with: modelMatches[0].range)
		}
		return printerModel.lowercased()
	}
	
	func zbrPrintImage() -> Void {
		guard isPrinterSelected() else {
			return
		}
		guard imageView.image != nil else {
			showAlert(asError: true, withMessage: "Please choose an image first")
			return
		}
		guard let cgImage = imageView.image?.cgImage else {
			showAlert(asError: true, withMessage: "Error getting CGImage")
			return
		}
		showLoader(withMessage: "Printing image")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			var errorMsg = ""
			
			// Instantiate connection to Zebra Bluetooth accessory
			let thePrinterConn = MfiBtPrinterConnection.init(serialNumber: self.selectedPrinter.serialNumber)
			// Open the connection - physical connection is established here.
			if !(thePrinterConn?.open() ?? false) {
				errorMsg = "Error opening connection to printer " + self.selectedPrinter.name
				self.clearPrinterData()
			} else {
				// try to print image
				do {
					let printArea = self.getPrintArea(forImage: cgImage, forModel: self.printerModel)
					print("Target print size: \(printArea.width) x \(printArea.height)")
					let topMargin: Int = 100
					// configure label length
					try SGD.set("zpl.label_length", withValue: String(Int(printArea.width) + topMargin), andWithPrinterConnection: thePrinterConn)
					let printer = ZebraPrinterFactory.getInstance(thePrinterConn, with: PrinterLanguage.init(0))
					try printer?.getGraphicsUtil().print(cgImage, atX: 0, atY: topMargin, withWidth: Int(printArea.width), withHeight: Int(printArea.height), andIsInsideFormat: false)
					// configure label length
					try SGD.set("zpl.label_length", withValue: "20", andWithPrinterConnection: thePrinterConn)
					//
				} catch let printError as NSError {
					errorMsg = printError.localizedDescription
					print(printError.localizedDescription)
				}
			}
			
			DispatchQueue.main.async {
				self.hideLoader()
				if !errorMsg.isEmpty {
					self.showAlert(asError: true, withMessage: errorMsg)
				}
			}
		}
	}
	
	// MARK: - Bixolon printer
	
	func bxlInitPrinter() -> Void {
		print("Init BXL printer")
		guard selectedPrinter.serialNumber.isEmpty == false else {
			showAlert(asError: true, withMessage: "Invalid serial number: " + selectedPrinter.serialNumber)
			return
		}
		
		// setup printer
		bxlPrinter = BXPrinter()
		bxlPrinter.macAddress = selectedPrinter.serialNumber
		bxlPrinter.connectionClass = UInt16(BXL_CONNECTIONCLASS_BT)
		bxlPrinterController.target = bxlPrinter
		bxlPrinterController.selectTarget()
		bxlPrinterController.setTimeoutOnConnection(5.0)
	}
	
	func bxlPrintText() -> Void {
		//
		guard isPrinterSelected() else {
			return
		}
		bxlAction = .text
		showLoader(withMessage: "Printing text...")
		bxlPrinterController.connect()
	}
	
	func bxlPrintImage() -> Void {
		guard isPrinterSelected() else {
			return
		}
		guard imageView.image != nil else {
			showAlert(asError: true, withMessage: "Please choose an image first")
			return
		}
		bxlAction = .image
		showLoader(withMessage: "Printing image...")
		bxlPrinterController.connect()
	}
	
	func bxlStateString(_ stateCode: Int) -> String {
		switch Int32(stateCode) {
		case BXL_STS_NORMAL:
			return "Normal state"
		case BXL_STS_PAPEREMPTY:
			return "No paper"
		case BXL_STS_COVEROPEN:
			return "Printer cover is open"
		case BXL_STS_POWEROVER:
			return "Battery is low"
		case BXL_STS_MSR_READY:
			return "Printer is not ready. It is in MSR read mode"
		case BXL_STS_PRINTING:
			return "Printer is printing / exchanging data"
		case BXL_STS_ERROR:
			return "There is an error in communication with printer"
		case BXL_STS_NOT_OPEN:
			return "The 'open' method on BXPrinterContro has not been called"
		case BXL_STS_ERROR_OCCUR:
			return "There is an error in the printer"
		default:
			return "State code: \(stateCode)"
		}
	}
	
	func bxlResultString(_ resultCode: Int) -> String {
		switch Int32(resultCode) {
		case BXL_SUCCESS:
			return "Success"
		case BXL_NOT_CONNECTED:
			return "Printer is not connected."
		case BXL_NOT_OPENED:
			return "SDK is not open."
		case BXL_STATUS_ERROR:
			return "There is an error during status check."
		case BXL_CONNECT_ERROR:
			return "Connection error"
		case BXL_NOT_SUPPORT:
			return "Not supported"
		case BXL_BAD_ARGUMENT:
			return "Wrong function argument"
		case BXL_BUFFER_ERROR:
			return "Error in MSR buffer"
		case BXL_NOT_CONNECTED:
			return "Printer is not connected"
		case BXL_RGBA_ERROR:
			return "Error in converting image file to RGBA data"
		case BXL_MEMORY_ERROR:
			return "Memory allocation error"
		case BXL_TOO_LARGE_IMAGE:
			return "Image file to download NV area is too big"
		case BXL_NOT_SUPPORT_DEVICE:
			return "Not supported by the printer."
		case BXL_READ_ERROR:
			return "Error in data reception"
		case BXL_WRITE_ERROR:
			return "Error in data transmission"
		case BXL_BITMAPLOAD_ERROR:
			return "Error in reading image file"
		case BXL_BC_DATA_ERROR:
			return "Error in bar code data"
		case BXL_BC_NOT_SUPPORT:
			return "Unsupported barcode type"
		case BXLMSR_NOTREADY:
			return "MSR is not ready."
		case BXLMSR_FAILEDMODE:
			return "Automatic read mode is not set."
		case BXLMSR_DATAEMPTY:
			return "There is no data read from MSR."
		default:
			return "Result code: \(resultCode)"
		}
	}
	
	func message(_ controller: BXPrinterController!, text: String!) {
		//
		print("BXL:message")
		print(text)
		showAlert(asError: true, withMessage: text!)
		if bxlPrinterController.isConnected() {
			bxlPrinterController.disconnect()
		}
		unselectPrinter()
	}
	
	func outputComplete(_ controller: BXPrinterController!, outputID: NSNumber!, errorStatus: NSNumber!) {
		// This delegate is generated when printing is successful
		print("BXL:outputComplete")
		hideLoader()
		bxlPrinterController.lineFeed(5)
		if bxlPrinterController.isConnected() {
			bxlPrinterController.disconnect()
		}
	}
	
	func errorEvent(_ controller: BXPrinterController!, errorStatus: NSNumber!) {
		//
		print("BXL:errorEvent")
		print(errorStatus!)
		hideLoader()
	}
	
	func msrArrived(_ controller: BXPrinterController!, track: NSNumber!) {
		//
		print("BXL:msrArrived")
	}
	
	func msrTerminated(_ controller: BXPrinterController!) {
		//
		print("BXL:msrTerminated")
	}
	
	func willLookupPrinters(_ controller: BXPrinterController!) {
		//
		print("BXL:willLookupPrinters")
	}
	
	func didLookupPrinters(_ controller: BXPrinterController!) {
		//
		print("BXL:didLookupPrinters")
	}
	
	func didFindPrinter(_ controller: BXPrinterController!, printer: BXPrinter!) {
		//
		print("BXL:didFindPrinter")
	}
	
	func willConnect(_ controller: BXPrinterController!, printer: BXPrinter!) {
		//
		print("BXL:willConnect")
	}
	
	func didConnect(_ controller: BXPrinterController!, printer: BXPrinter!) {
		//
		print("BXL:didConnect")
		// get printer model
		selectedPrinter.model = printer.modelStr
		print("Printer model: " + selectedPrinter.model)
		// print
		bxlPrinterController.asyncMode(true)
		switch bxlAction! {
		case .text:
			let result = bxlPrinterController.printText(textToPrint)
			print(bxlResultString(result))
			break
		case .image:
			let result = bxlPrinterController.printBitmap(with: imageView.image!, width: Int(BXL_WIDTH_FULL), level: 1050)
			print(bxlResultString(result))
			break
		default:
			print("Unknown action")
		}
	}
	
	func didNotConnect(_ controller: BXPrinterController!, printer: BXPrinter!, withError error: Error!) {
		//
		print("BXL:didNotConnect")
		hideLoader()
		showAlert(asError: true, withMessage: error.localizedDescription)
	}
	
	func didDisconnect(_ controller: BXPrinterController!, printer: BXPrinter!) {
		// This method is called when the process to disconnect the printer is completed
		print("BXL:didDisconnect")
	}
	
	func didBeBrokenConnection(_ controller: BXPrinterController!, printer: BXPrinter!, withError error: Error!) {
		// This method is called when the printer gets disconnected
		print("BXL:didBeBrokenConnection")
		hideLoader()
		showAlert(asError: true, withMessage: error.localizedDescription)
	}
	
	func targetPrinterPaired(_ controller: BXPrinterController!) {
		//
		print("BXL:targetPrinterPaired")
	}
	
	// MARK: - Star printer
	
	func strInitPrinter() -> Void {
		showAlert(asError: false, withMessage: "Init Star printer")
	}
	
	func strPrintImage() -> Void {
		guard isPrinterSelected() else {
			return
		}
		guard imageView.image != nil else {
			showAlert(asError: true, withMessage: "Please choose an image first")
			return
		}
		let builder:ISCBBuilder = StarIoExt.createCommandBuilder(StarIoExtEmulation.starPRNT)
		builder.beginDocument()
		builder.appendBitmap(imageView.image!, diffusion: true, width: PaperSizeIndex.threeInch.rawValue, bothScale: true)
		builder.appendByte(0x0a) // hex new line (\n)
		builder.appendCutPaper(SCBCutPaperAction.partialCutWithFeed)
		builder.endDocument()
		
		strSendCommands(builder.commands.copy() as! Data)
	}
	
	func strPrintText() -> Void {
		guard isPrinterSelected() else {
			return
		}
		let textData = textToPrint.data(using: String.Encoding.ascii)
		
		let builder:ISCBBuilder = StarIoExt.createCommandBuilder(StarIoExtEmulation.starPRNT)
		builder.beginDocument()
		builder.append(textData)
		builder.appendByte(0x0a) // hex new line (\n)
		builder.appendCutPaper(SCBCutPaperAction.partialCutWithFeed)
		builder.endDocument()
		
		strSendCommands(builder.commands.copy() as! Data)
	}
	
	func strSendCommands(_ commands: Data?) -> Void {
		let portName:     String = "BT:\(selectedPrinter.name)"
		
		showLoader(withMessage: "Printing...")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			_ = SMComms.sendCommands(
				commands,
				portName: portName,
				timeout: 10000,
				completionHandler: { (success, title, message) in
					DispatchQueue.main.async {
						self.hideLoader()
						if !success {
							self.showAlert(asError: true, withMessage: message)
						}
					}
				}
			)
		}
	}
	
	// MARK: - Misc methods
	
	func showLoader(withMessage message: String!) {
		print("showLoader: " + message)
		if message == nil || message.isEmpty {
			loaderLabel.text = "Please wait"
		} else {
			loaderLabel.text = message
		}
		if loaderView.isHidden {
			loaderView.isHidden = false
			loaderSpinner.startAnimating()
		}
	}
	
	func hideLoader() {
		print("hideLoader")
		if !loaderView.isHidden {
			loaderLabel.text = ""
			loaderView.isHidden = true
			loaderSpinner.stopAnimating()
		}
	}
	
	func showAlert(asError isError: Bool, withMessage message: String) -> Void {
		print("showAlert: " + message)
		let alert = UIAlertController(title: isError ? "Error" : "Info", message: message, preferredStyle: .alert)
		let actionOk = UIAlertAction(title: "OK", style: .default, handler: nil)
		alert.addAction(actionOk)
		present(alert, animated: true, completion: nil)
	}
}

