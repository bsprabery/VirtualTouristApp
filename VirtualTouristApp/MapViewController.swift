//
//  MapViewController.swift
//  VirtualTouristApp
//
//  Created by Brittany Sprabery on 2/8/17.
//  Copyright © 2017 Brittany Sprabery. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet var editPinsButton: UIButton!
    @IBOutlet var instructionLabel: UILabel!
    @IBOutlet var mapView: MKMapView!
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var inEditMode = false
    var annotationInstance: MKAnnotation?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        //Check to see if the pins have already been loaded; if they haven't, load them.
        if mapView.annotations.count > 0 {
            print("Pins have already been loaded.")
        } else {
            populatePinsOnMap()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapView.delegate = self
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.addAnnotation(gestureRecognizer:)))
        longPress.minimumPressDuration = 1.0
        mapView.addGestureRecognizer(longPress)
        
        instructionLabel.isHidden = true
    }

    func addAnnotation(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizerState.began {
            let touchPoint = gestureRecognizer.location(in: mapView)
            let newCoordinate = mapView.convert(touchPoint, toCoordinateFrom: self.mapView)
            let annotation = MKPointAnnotation()
            
            annotation.coordinate = newCoordinate
            let latitude = annotation.coordinate.latitude
            let longitude = annotation.coordinate.longitude
            Client.sharedInstance().setLatitude(lat: latitude)
            Client.sharedInstance().setLongitude(lon: longitude)
            
            //MARK: Add pin to persisted pin Array:
            let entity = NSEntityDescription.entity(forEntityName: "Pin", in: context)
            let pin = NSManagedObject(entity: entity!, insertInto: context)
            
            pin.setValue(latitude, forKey: "latitude")
            pin.setValue(longitude, forKey: "longitude")
            
            (UIApplication.shared.delegate as! AppDelegate).saveContext()
            
            self.mapView.addAnnotation(annotation)
            
            //MARK: Retrieve photos for the pin and save them to the context:
            Client.sharedInstance().getImagesForLocation()
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) ->MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.animatesDrop = true
        } else {
            pinView!.annotation = annotation
        }
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        //Delete the pin from the map and the context if the map is in Edit Mode.
        if inEditMode == true {
            let annotation = view.annotation!
            let latitude = annotation.coordinate.latitude
            let longitude = annotation.coordinate.longitude
            
            let fetchRequest = NSFetchRequest<Pin>(entityName: "Pin")
            fetchRequest.sortDescriptors = []
            let predicate = NSCompoundPredicate(format: "latitude == %lf AND longitude == %lf", latitude, longitude)
            fetchRequest.predicate = predicate
            
            do {
                let pin = try context.fetch(fetchRequest)
                if pin.count > 0 {
                    let pin = pin[0]
                    context.delete(pin)
                    (UIApplication.shared.delegate as! AppDelegate).saveContext()
                } else {
                    print("There were no results from the fetchRequest in MapViewController: didSelect view.")
                }
            } catch {
                print("There was an error performing the fetchRequest in MapViewController: didSelect view.")
            }
            
            mapView.removeAnnotation(annotation)
         
        //If the map is not in Edit Mode, set the latitude and longitude and segue to the PhotoAblumViewController. Setting the latitude and longitude here is important because future network requests depend on it. Deselect the annotation, so that it will not be selected when you return to the MapViewController.
        } else {
            let annotation = view.annotation!
            annotationInstance = annotation
            let latitude = view.annotation!.coordinate.latitude
            let longitude = view.annotation!.coordinate.longitude
            
            Client.sharedInstance().setLatitude(lat: latitude)
            Client.sharedInstance().setLongitude(lon: longitude)
            segueToPhotoAlbumViewController()
            mapView.deselectAnnotation(annotation, animated: true)
        }
    }
    
    func segueToPhotoAlbumViewController() ->  Void {
        DispatchQueue.main.async {
            let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhotoAlbumViewController") as! PhotoAlbumViewController
            vc.annotationInstance = self.annotationInstance
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func editPinsButtonClicked(_ sender: AnyObject) {
        let item = self.navigationItem.rightBarButtonItem
        let button = item!.customView as! UIButton
        
        if button.title(for: .normal) == "Edit" {
            button.setTitle("Done", for: .normal)
            instructionLabel.isHidden = false
            inEditMode = true
        } else {
            button.setTitle("Edit", for: .normal)
            instructionLabel.isHidden = true
            inEditMode = false
        }
    }
    
    func fetchPins() -> [NSManagedObject] {
        let fetchRequest = NSFetchRequest<Pin>(entityName: "Pin")
        var pinObjects = [NSManagedObject]()
        
        do {
            pinObjects = try context.fetch(fetchRequest)
            return pinObjects
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo).")
        }
        return pinObjects
    }
    
    func populatePinsOnMap() {
        let pinObjects = fetchPins()
        
        if pinObjects.count > 0 {
            for pinObject in pinObjects {
                //Get the latitude and longitude of the pins
                let lat = (pinObject.value(forKey: "latitude") as! Double)
                let lon = (pinObject.value(forKey: "longitude") as! Double)
                
                //Create a MKPointAnnotation and set it's lat and lon to match
                // the lat and lon from the saved pins
                let annotation = MKPointAnnotation()
                annotation.coordinate.latitude = lat
                annotation.coordinate.longitude = lon
                
                //Add the annotations back to the map
                self.mapView.addAnnotation(annotation)
            }
            
        } else {
            print("There are no pins saved in the context.")
        }
    }

}

