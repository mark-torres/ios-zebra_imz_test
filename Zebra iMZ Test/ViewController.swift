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
	
	var imagePicker: UIImagePickerController!
	

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		
		imagePicker = UIImagePickerController()
		imagePicker.delegate = self
		imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
		
		textMessage.delegate = self
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	// MARK - IB Actions
	
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
		printImageCpcl()
	}
	
	// MARK - Text field delegate
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if textField == textMessage {
			textField.resignFirstResponder()
			return true
		}
		return true
	}
	
	// MARK - ImagePickerController Delegate
	
	// https://makeapppie.com/2014/12/04/swift-swift-using-the-uiimagepickercontroller-for-a-camera-and-photo-library/
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		let chosenImage = info[UIImagePickerControllerOriginalImage] as! UIImage
		imageView.image = chosenImage
		
		dismiss(animated: true, completion: nil)
	}
	
	// MARK - iMZ printer
	
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
	
	func printTextCpcl(_ text: String) -> Void {
		showLoader()
		DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
			var errorMsg = ""
			var nsError: NSError? = nil
			
			let serialNumber = self.getFirstBtPrinter()
			
			if serialNumber.isEmpty {
				errorMsg = "No BT printer found"
			} else {
				// Instantiate connection to Zebra Bluetooth accessory
				let thePrinterConn = MfiBtPrinterConnection.init(serialNumber: serialNumber)
				
				// Open the connection - physical connection is established here.
				if !(thePrinterConn?.open() ?? false) {
					errorMsg = "Error opening connection to printer " + serialNumber
				} else {
					let cpclString = "! 0 200 200 110 1\r\nTEXT 4 0 5 5 \(text)\r\nFORM\r\nPRINT\r\n"
					
					let writtenBytes = thePrinterConn?.write(cpclString.data(using: String.Encoding.utf8), error: &nsError) ?? -1
					
					if writtenBytes < 0 || nsError != nil {
						errorMsg = "Error writing to the printer " + serialNumber
					}
					
					// close printer connection
					thePrinterConn?.close()
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
	
	func printImageCpcl() -> Void {
		guard let cgImage = imageView.image?.cgImage else {
			showAlert(asError: true, withMessage: "Error getting CGImage")
			return
		}
		if imageView.image == nil {
			showAlert(asError: true, withMessage: "Please choose an image first")
		} else {
			showLoader()
			DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
				var errorMsg = ""
				let serialNumber = self.getFirstBtPrinter()
				
				if serialNumber.isEmpty {
					errorMsg = "No BT printer found"
				} else {
					// Instantiate connection to Zebra Bluetooth accessory
					let thePrinterConn = MfiBtPrinterConnection.init(serialNumber: serialNumber)
					
					// Open the connection - physical connection is established here.
					if !(thePrinterConn?.open() ?? false) {
						errorMsg = "Error opening connection to printer " + serialNumber
					} else {
						// try to print image
						do {
							let printer = ZebraPrinterFactory.getInstance(thePrinterConn, with: PrinterLanguage.init(0))
							try printer?.getGraphicsUtil().print(cgImage, atX: 0, atY: 0, withWidth: 320, withHeight: 480, andIsInsideFormat: false)
						} catch let printError as NSError {
							errorMsg = printError.localizedDescription
							print(printError.localizedDescription)
						}
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
	}
	
	// MARK - Misc methods
	
	func showLoader() {
		loaderView.isHidden = false
		loaderSpinner.startAnimating()
	}
	
	func hideLoader() {
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

