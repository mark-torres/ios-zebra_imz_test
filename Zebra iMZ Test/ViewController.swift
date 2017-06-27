//
//  ViewController.swift
//  Zebra iMZ Test
//
//  Created by Marcos Torres on 6/26/17.
//  Copyright © 2017 HSoft. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
	
	@IBOutlet weak var textMessage: UITextField!
	
	@IBOutlet weak var imageView: UIImageView!
	
	@IBOutlet weak var loaderView: UIView!
	
	@IBOutlet weak var loaderSpinner: UIActivityIndicatorView!
	

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	// MARK - IB Actions
	
	@IBAction func tapPrintText(_ sender: AnyObject) {
		showAlert(asError: false, withMessage: "Tapped 'Print text'")
	}
	
	@IBAction func tapChooseImage(_ sender: AnyObject) {
		showAlert(asError: false, withMessage: "Tapped 'Choose image'")
	}
	
	@IBAction func tapPrintImage(_ sender: AnyObject) {
		showAlert(asError: false, withMessage: "Tapped 'Print image'")
	}
	
	// MARK - iMZ printer
	
	func printTextCpcl(text: String) -> Void {
	}
	
	func printImageCpcl() -> Void {
	}
	
	// MARK - Misc methods
	
	func showAlert(asError isError: Bool, withMessage message: String) -> Void {
		let alert = UIAlertController(title: isError ? "Error" : "Info", message: message, preferredStyle: .alert)
		let actionOk = UIAlertAction(title: "OK", style: .default, handler: nil)
		alert.addAction(actionOk)
		present(alert, animated: true, completion: nil)
	}
}

