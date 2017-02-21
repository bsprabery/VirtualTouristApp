//
//  Client.swift
//  VirtualTouristApp
//
//  Created by Brittany Sprabery on 2/8/17.
//  Copyright © 2017 Brittany Sprabery. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import CoreData
import MapKit


class Client: NSObject {
    
    class func sharedInstance() -> Client {
        struct Singleton {
            static var sharedInstance = Client()
        }
        return Singleton.sharedInstance
    }
    
    /*
     This is triggered when a pin is clicked on the map
     It makes a request and returns images for the selected location.
     The images’ URLs are then saved as strings in an array.
     Then the getImageData function is called.
     */
    func getImagesForLocation() {

        let parameters: Parameters = [
            "method" : "flickr.photos.search",
            "api_key" : "4b6ac0e76f45d3dadc5c2e0f33935aab",
            "lat" : "\(getLatitude())",
            "lon" : "\(getLongitude())",
            "format" : "json",
            "nojsoncallback" : "1",
            "safe_search" : "1",
            "page" : "1",
            "per_page" : "18"
        ]
        
        Alamofire.request("https://api.flickr.com/services/rest/", parameters: parameters).validate().responseData { response in
            guard response.result.isSuccess else {
                print("There was an error while making the request: \(response.result.error)")
                return
            }
            
            if let data = response.result.value, let jsonDataString = String(data: data, encoding: .utf8) {
                if let dataFromString = jsonDataString.data(using: .utf8, allowLossyConversion: false) {
                    let json = JSON(data: dataFromString)

                    //Get the number of pages of images from the network response:
                    let photos = json["photos"]
                    let pages = photos["pages"].intValue
                    self.setNumberOfPages(number: pages)
                    
                    //Set the number of pages for the Pin:
                    let pin = self.fetchPin()!
                    pin.setValue(pages, forKey: "responsePages")
                    (UIApplication.shared.delegate as! AppDelegate).saveContext()
                    
                    
                    for photo in json["photos"]["photo"].arrayValue {
                        let photoID = photo["id"].stringValue
                        let farm = photo["farm"].stringValue
                        let server = photo["server"].stringValue
                        let secret = photo["secret"].stringValue
                        
                        let url = "https://farm" + farm + ".staticflickr.com/" + server + "/" + photoID + "_" + secret + ".jpg"
                        let photoURL = URL(string: url)
                        
                        self.photoArray.append(photoURL!)
                        
                        self.setPhotos(photoArray: self.photoArray)                        
                    }
                }
            }
            self.getImageData()
        }
    }
    /*
     This method retrieves new, random photos for the collection view in PhotoAlbumViewController.
     It gets a random page number based on the number of pages retrieved from the initial network request (which was saved to the Pin object) and uses that as a parameter for this request.
     */
    func getNewImages() {
        
        let parameters: Parameters = [
            "method" : "flickr.photos.search",
            "api_key" : "4b6ac0e76f45d3dadc5c2e0f33935aab",
            "lat" : "\(getLatitude())",
            "lon" : "\(getLongitude())",
            "format" : "json",
            "nojsoncallback" : "1",
            "safe_search" : "1",
            "page" : "\(getRandomNumber())",
            "per_page" : "18"
        ]
        
        Alamofire.request("https://api.flickr.com/services/rest/", parameters: parameters).validate().responseData { response in
            guard response.result.isSuccess else {
                print("There was an error while making the request: \(response.result.error)")
                return
            }
            
            if let data = response.result.value, let jsonDataString = String(data: data, encoding: .utf8) {
                if let dataFromString = jsonDataString.data(using: .utf8, allowLossyConversion: false) {
                    let json = JSON(data: dataFromString)
                    for photo in json["photos"]["photo"].arrayValue {
                        let photoID = photo["id"].stringValue
                        let farm = photo["farm"].stringValue
                        let server = photo["server"].stringValue
                        let secret = photo["secret"].stringValue
                        
                        let url = "https://farm" + farm + ".staticflickr.com/" + server + "/" + photoID + "_" + secret + ".jpg"
                        let photoURL = URL(string: url)
                        
                        self.photoArray.append(photoURL!)
                        
                        self.setPhotos(photoArray: self.photoArray)
                    }
                }
            }
            self.getImageData()
        }
        
    }

    /*
     This method retrieves the photos' URLs from the array created in getImagesForLocation.
     For each photo URL, a request is made to retrieve the photo.
     If the request successfully returns a result, the image is converted to NSData.
     The saveImageToContext function is then called for each photo.
     */
    func getImageData() {
        var photosArray: Array<URL> = getPhotos()
        
        for photo in photosArray {
            Alamofire.request("\(photo)").validate().responseData(completionHandler: { response in
                guard response.result.isSuccess else {
                    print("There was an error getting the image data \(response.result.error).")
                    return
                }
                
                if let image = UIImage(data: response.result.value!, scale: 1.0) {
                    if let imageData = UIImagePNGRepresentation(image) {
                        if imageData.count > 0 {
                            let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
                            let entityDescription = NSEntityDescription.entity(forEntityName: "Photo", in: context)
                            let photo = Photo(entity: entityDescription!, insertInto: context)
                            let pin = self.fetchPin()!
                            photo.setValue(imageData as NSData, forKey: "image")
                            photo.setValue(pin, forKey: "pin")
                            (UIApplication.shared.delegate as! AppDelegate).saveContext()
                        } else {
                            print("The imageData array is empty.")
                        }
                    }
                }
            })
        }
        
        if photosArray.count > 0 {
            photosArray.removeAll()
            self.setPhotos(photoArray: photosArray)
        } else {
            print("There were no photoURLs in the array.")
        }
    }
    
    func fetchPin() -> Pin? {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<Pin>(entityName: "Pin")
        
        let latitude = getLatitude()
        let longitude = getLongitude()
        let pred = NSCompoundPredicate(format: "latitude == %lf AND longitude == %lf", latitude, longitude)
        fetchRequest.predicate = pred
        
        do {
            let results = try context.fetch(fetchRequest)
            let pin = results[0]
            return pin
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo).")
        }
        return nil
    }
    
    //Returns a random number based on the number of responsePages associated with the Pin.
    func getRandomNumber() -> Int {
        let pin = fetchPin()!
        let numberOfPages = pin.responsePages
        
        let randomNumber = arc4random_uniform(UInt32(numberOfPages)) + 1
        return Int(randomNumber)
    }
    
    private override init() {
        latitude = CLLocationDegrees()
        longitude = CLLocationDegrees()
        photoArray = Array<URL>()
        numberOfPages = Int()
    }
    
    private var latitude: CLLocationDegrees
    private var longitude: CLLocationDegrees
    var photoArray: Array<URL>
    var numberOfPages: Int
    
    func getLatitude() -> CLLocationDegrees {
        return self.latitude
    }
    
    func setLatitude(lat: CLLocationDegrees) -> Void {
        self.latitude = lat
    }
    
    func getLongitude() -> CLLocationDegrees {
        return self.longitude
    }
    
    func setLongitude(lon: CLLocationDegrees) -> Void {
        self.longitude = lon
    }
    
    func getPhotos() -> Array<URL> {
        return self.photoArray
    }
    
    func setPhotos(photoArray: Array<URL>) -> Void {
        self.photoArray = photoArray
    }
    
    func getNumberOfPages() -> Int {
        return self.numberOfPages
    }
    
    func setNumberOfPages(number: Int) {
        self.numberOfPages = number
    }

}
