//
//  ViewController.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

// This exampe is meant to be run with the python example:
//              tornado_turiexamples.py 
//              from the course GitHub repository: tornado_bare, branch sklearn_example


// if you do not know your local sharing server name try:
//    ifconfig |grep "inet "
// to see what your public facing IP address is, the ip address can be used here

// CHANGE THIS TO THE URL FOR YOUR LAPTOP
let SERVER_URL = "http://192.168.1.217:8000" // change this for your server name!!!

import UIKit
import CoreMotion

extension UIImage {
    func pixelData() -> [UInt8]? {
        let size = self.size
        let dataSize = size.width * size.height * 4
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        return pixelData
    }
 }

class ViewController: UIViewController, UIImagePickerControllerDelegate, URLSessionDelegate, UINavigationControllerDelegate {
    
    // MARK: Class Properties
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        return URLSession(configuration: sessionConfig,
                          delegate: self,
                          delegateQueue:self.operationQueue)
    }()
    
    let operationQueue = OperationQueue()
    let motionOperationQueue = OperationQueue()
    let calibrationOperationQueue = OperationQueue()
    
    var ringBuffer = RingBuffer()
    
    var openHand = false
    var fistHand = false
    var prediction = false
    
    @IBOutlet weak var predictionLabel: UILabel!
 
    @IBOutlet weak var dsidLabel: UILabel!
    
    @IBAction func dsidChanged(_ sender: UISlider) {
        self.dsid = Int(sender.value)
    }
    
    var dsid:Int = 0 {
        didSet{
            DispatchQueue.main.async{
                // update label when set
              
                self.dsidLabel.text = String(self.dsid)
            }
        }
    }
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        dsid = 50 // set this and it will update UI
    }
    
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBAction func uploadOpenHand(_ sender: UIButton) {
        self.openHand = true
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        self.present(picker, animated: true, completion: nil)
        print("uploadOpenHand button clicked")
    }
    
    @IBAction func uploadFistHand(_ sender: UIButton) {
        self.fistHand = true
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        self.present(picker, animated: true, completion: nil)
        print("uploadFistHand button clicked")
    }
    
    @IBAction func uploadPrediction(_ sender: UIButton) {
        self.prediction = true
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        self.present(picker, animated: true, completion: nil)
        print("uploadPrediction button clicked")
    }
    
    //user canceled, do nothing
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //where we send image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        self.dismiss(animated: true, completion: nil)
        
        let image = info["UIImagePickerControllerOriginalImage"] as? UIImage
 
        let imageData: Data = image?.jpegData(compressionQuality: 0.1) ?? Data()
        let imagestr: String = imageData.base64EncodedString()
        
        if (imagestr != nil){
            if self.openHand { //call send features with the label "open"
                self.openHand = false
                sendFeatures(imagestr, withLabel: "open")
            } else if self.fistHand { //call send features with the label "open"
                self.fistHand = false
                sendFeatures(imagestr, withLabel: "fist")
            } else if self.prediction { //call getPrediction with new picture
                self.prediction = false
                getPrediction(imagestr)
            }else {
                print("some error with boolean flags")
            }
        } else{
            print("imagestr is nil")
        }
        
        DispatchQueue.main.async {
            self.imageView.image = image
        }
    }
    
    fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any]{
        return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
    }
    
    //MARK: Comm with Server
    func sendFeatures(_ encoding:String, withLabel label:NSString){
        let baseURL = "\(SERVER_URL)/AddDataPoint"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":encoding,
                                       "label":"\(label)",
                                       "dsid":self.dsid]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        //where post happens, sending the encoded image
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{(data, response, error) in
            if(error != nil){
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
//                print("error response")
//                let jsonDictionary = self.convertDataToDictionary(with: data)
//                
//                print(jsonDictionary["feature"]!)
//                print(jsonDictionary["label"]!)
                let jsonDictionary = self.convertDataToDictionary(with: data)
                //printouts for error checking labels and sent pictures
                if (jsonDictionary["feature"] == nil){
                    print("jsondic is nil")
                }else{
                    print("jsondic not nil")
                }
                if let feature = jsonDictionary["feature"]{
                    print(feature)

                }else{
                    print("feature is nil")
                }
                if let label = jsonDictionary["label"]{
                    print(label)

                }else{
                    print("label is nil")
                }
            }
            
        })
        
        postTask.resume() // start the task
    }
    
    func getPrediction(_ encoding:String){
        let baseURL = "\(SERVER_URL)/PredictOne"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":encoding, "dsid":self.dsid]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{
            (data, response, error) in
            if(error != nil){
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{ // no error we are aware of
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                let labelResponse = jsonDictionary["prediction"]!
                print(labelResponse)
                if let res = labelResponse as? Int, res == -404 {
                    print("404!!!!")
                } else {
                    self.displayLabelResponse(labelResponse as! String)
                }
            }
            
        })
        
        postTask.resume() // start the task
    }
    
    func displayLabelResponse(_ response:String){
        switch response {
        case "open":
            DispatchQueue.main.async {
                self.predictionLabel.text = "open hand"
            }
            break
        case "['fist']":
            DispatchQueue.main.async {
                self.predictionLabel.text = "fist"
            }
            break
        default:
            print("Unknown")
            break
        }
    }
    
    
    @IBAction func makeModelSVM(_ sender: AnyObject) {
        // create a GET request for server to update the ML model with current data
        let baseURL = "\(SERVER_URL)/UpdateModel2" //update model with svm classifier
        let query = "?dsid=\(self.dsid)"
        
        let getUrl = URL(string: baseURL+query)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{(data, response, error) in
            // handle error!
            if (error != nil) {
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                if let resubAcc = jsonDictionary["resubAccuracy"]{
                    print("Resubstitution Accuracy is", resubAcc)
                }
            }
            
        })
        
        dataTask.resume() // start the task
    }
    
    @IBAction func makeModel(_ sender: AnyObject) {
        
        // create a GET request for server to update the ML model with current data
        let baseURL = "\(SERVER_URL)/UpdateModel"
        let query = "?dsid=\(self.dsid)"
        
        let getUrl = URL(string: baseURL+query)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{(data, response, error) in
            // handle error!
            if (error != nil) {
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                if let resubAcc = jsonDictionary["resubAccuracy"]{
                    print("Resubstitution Accuracy is", resubAcc)
                }
            }
            
        })
        
        dataTask.resume() // start the task
        
    }
    
    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
            try JSONSerialization.jsonObject(with: data!,
                                             options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            
            return jsonDictionary
            
        } catch {
            
            if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
                print("printing JSON received as string: "+strData)
            }else{
                print("json error: \(error.localizedDescription)")
            }
            return NSDictionary() // just return empty
        }
    }
    
}





