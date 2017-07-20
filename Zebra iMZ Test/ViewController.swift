//
//  ViewController.swift
//  Zebra iMZ Test
//
//  Created by Marcos Torres on 6/26/17.
//  Copyright © 2017 HSoft. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UITextFieldDelegate {
	
	@IBOutlet weak var textMessage: UITextField!
	
	@IBOutlet weak var imageView: UIImageView!
	
	@IBOutlet weak var loaderView: UIView!
	
	@IBOutlet weak var loaderSpinner: UIActivityIndicatorView!
	
	@IBOutlet var loaderLabel: UILabel!
	
	@IBOutlet var printerInfoLabel: UILabel!
	
	var printerModel: String!
	
	var availablePrinters: [String]!
	
	var selectedPrinter: String!
	
	var imagePicker: UIImagePickerController!
	
	let supportedModels: [String] = ["imz220", "imz320"]
	
	var printerSelected: Bool!
	
	var imageSelected: Bool!

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		
		imagePicker = UIImagePickerController()
		imagePicker.delegate = self
		imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
		
		textMessage.delegate = self
		
		availablePrinters = []
		selectedPrinter = ""
		printerSelected = false
		printerModel = ""
		imageSelected = false
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	// MARK: - IB Actions
	
	@IBAction func tapPrintText(_ sender: AnyObject) {
		let text = textMessage.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
		if !text.isEmpty {
			printTextCpcl(text)
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
		printImageCpcl()
	}
	
	@IBAction func tapResetPrinter(_ sender: Any) {
		resetPrinter()
	}
	
	@IBAction func tapSelectPrinter(_ sender: Any) {
		selectPrinter()
	}
	
	// MARK: - Text field delegate
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if textField == textMessage {
			textField.resignFirstResponder()
			return true
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
	
	// MARK: - iMZ printer
	
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
	
	func selectPrinter() -> Void {
		showLoader(withMessage: "Looking for connected printers")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			self.availablePrinters = []
			let sam: EAAccessoryManager = EAAccessoryManager.shared()
			let connectedAccessories = sam.connectedAccessories
			for accessory in connectedAccessories {
				if accessory.protocolStrings.index(of: "com.zebra.rawport")! >= 0 {
					self.availablePrinters.append(accessory.serialNumber)
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
		for serialNumber in availablePrinters {
			let action = UIAlertAction(title: serialNumber, style: UIAlertActionStyle.default, handler: { (theAction) in
				self.selectedPrinter = theAction.title ?? ""
				print("Selected printer: " + self.selectedPrinter)
				self.printerSelected = true
				self.printerInfoLabel.text = self.selectedPrinter
				self.printerInfoLabel.isHighlighted = true
				self.initPrinter()
			})
			actionSheet.addAction(action)
		}
		let cancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil)
		actionSheet.addAction(cancel)
		present(actionSheet, animated: true, completion: nil)
	}
	
	func initPrinter() -> Void {
		guard selectedPrinter.isEmpty == false else {
			showAlert(asError: true, withMessage: "Invalid serial number: " + selectedPrinter)
			return
		}
		showLoader(withMessage: "Configuring printer")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			var errorMsg = ""
			// create connection
			let thePrinterConnection = MfiBtPrinterConnection.init(serialNumber: self.selectedPrinter)
			// try to open the connection
			if !(thePrinterConnection?.open() ?? false) {
				errorMsg = "Error opening connection with printer " + self.selectedPrinter
			} else {
				// set printer language to ZPL
				do {
					// ! U1 setvar "device.languages" "zpl"
					try SGD.set("device.languages", withValue: "zpl", andWithPrinterConnection: thePrinterConnection)
					// get printer ID
					let hostId = try SGD.get("device.host_identification", withPrinterConnection: thePrinterConnection)
					print(hostId)
					self.printerModel = self.getPrinterModel(fromString: hostId)
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
	
	func resetPrinter() -> Void {
		guard isPrinterSelected() else {
			return
		}
		showLoader(withMessage: "Resetting printer")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			var errorMsg = ""
			
			let thePrinterConnection = MfiBtPrinterConnection.init(serialNumber: self.selectedPrinter)
			if !(thePrinterConnection?.open() ?? false) {
				errorMsg = "Error connecting to printer " + self.selectedPrinter
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
	
	func isPrinterSelected() -> Bool {
		if !printerSelected	{
			showAlert(asError: true, withMessage: "You need to select a printer first")
		}
		return printerSelected
	}
	
	func clearPrinterData() -> Void {
		self.printerSelected = false
		self.printerInfoLabel.text = "No printer selected"
		self.printerInfoLabel.isHighlighted = false
	}
	
	func printTextCpcl(_ text: String) -> Void {
		guard isPrinterSelected() else {
			return
		}
		showLoader(withMessage: "Printing text")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			var errorMsg = ""
			var nsError: NSError? = nil
			
			// Instantiate connection to Zebra Bluetooth accessory
			let thePrinterConn = MfiBtPrinterConnection.init(serialNumber: self.selectedPrinter)
			
			// Open the connection - physical connection is established here.
			if !(thePrinterConn?.open() ?? false) {
				errorMsg = "Error opening connection to printer " + self.selectedPrinter
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
						let cpclString = "! 0 200 200 110 1\r\nTEXT 4 0 5 5 \(text)\r\nFORM\r\nPRINT\r\n"
						let writtenBytes = thePrinterConn?.write(cpclString.data(using: String.Encoding.utf8), error: &nsError) ?? -1
						if writtenBytes < 0 || nsError != nil {
							errorMsg = "Error writing to the printer " + self.selectedPrinter
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
		let printerModel = supportedModels.contains(model) ? model : supportedModels[0]
		let maxWidthZ220: Int = 380 // iMZ220-200dpi: (2 x 200) - 20 = 380
		let maxWidthMz320: Int = 580 // iMZ320-200dpi: (3 x 200) - 20 = 580
		let maxWidth: Int = (printerModel == supportedModels[0]) ? maxWidthZ220 : maxWidthMz320
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
	
	func getPrinterModel(fromString string: String) -> String {
		let hostRange = NSRange(location: 0, length: string.characters.count)
		let reModel = try! NSRegularExpression(pattern: "^(imz\\d+)", options: NSRegularExpression.Options.caseInsensitive)
		let modelMatches = reModel.matches(in: string, options: NSRegularExpression.MatchingOptions.withoutAnchoringBounds, range: hostRange)
		var printerModel = supportedModels[0]
		if modelMatches.count > 0 {
			printerModel = (string as NSString).substring(with: modelMatches[0].range)
		}
		return printerModel.lowercased()
	}
	
	func printImageCpcl() -> Void {
		guard isPrinterSelected() else {
			return
		}
		guard let cgImage = imageView.image?.cgImage else {
			showAlert(asError: true, withMessage: "Error getting CGImage")
			return
		}
		if imageView.image == nil {
			showAlert(asError: true, withMessage: "Please choose an image first")
		}
		showLoader(withMessage: "Printing image")
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			var errorMsg = ""
			
			// Instantiate connection to Zebra Bluetooth accessory
			let thePrinterConn = MfiBtPrinterConnection.init(serialNumber: self.selectedPrinter)
			// Open the connection - physical connection is established here.
			if !(thePrinterConn?.open() ?? false) {
				errorMsg = "Error opening connection to printer " + self.selectedPrinter
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
	
	// MARK: - Misc methods
	
	func showLoader(withMessage message: String!) {
		if message == nil || message.isEmpty {
			loaderLabel.text = "Please wait"
		} else {
			loaderLabel.text = message
		}
		loaderView.isHidden = false
		loaderSpinner.startAnimating()
	}
	
	func hideLoader() {
		loaderLabel.text = ""
		loaderView.isHidden = true
		loaderSpinner.stopAnimating()
	}
	
	func showAlert(asError isError: Bool, withMessage message: String) -> Void {
		let alert = UIAlertController(title: isError ? "Error" : "Info", message: message, preferredStyle: .alert)
		let actionOk = UIAlertAction(title: "OK", style: .default, handler: nil)
		alert.addAction(actionOk)
		present(alert, animated: true, completion: nil)
	}
}

