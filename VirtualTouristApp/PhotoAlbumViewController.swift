//
//  PhotoAlbumViewController.swift
//  VirtualTouristApp
//
//  Created by Brittany Sprabery on 2/8/17.
//  Copyright © 2017 Brittany Sprabery. All rights reserved.
//

import Foundation
import MapKit
import UIKit
import CoreData

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate {
    
    @IBOutlet var mapView: MKMapView!
    @IBOutlet var newCollectionButton: UIButton!
    @IBOutlet var collectionView: UICollectionView!
    
    let managedContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var annotationInstance: MKAnnotation?

    var insertedIndexPaths = [IndexPath]()
    var deletedIndexPaths = [IndexPath]()
    var updatedIndexPaths = [IndexPath]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addAnnotation()
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("An error occurred: PhotoAlbumViewController: viewDidLoad")
        }
        
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    func addAnnotation() {
        self.mapView.addAnnotation(annotationInstance!)
        let coordinates = annotationInstance!.coordinate
        
        //Zoom in on region.
        let latDelta: CLLocationDegrees = 1.75
        let longDelta: CLLocationDegrees = 0.85
        let span = MKCoordinateSpanMake(latDelta, longDelta)
        let region = MKCoordinateRegionMake(coordinates, span)
        self.mapView.setRegion(region, animated: false)
    }
    
    func returnPin(annotation: MKAnnotation) -> NSManagedObject? {
        let latitude = annotationInstance!.coordinate.latitude
        let longitude = annotationInstance!.coordinate.longitude
        
        let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
        let predicate = NSCompoundPredicate(format: "latitude == %lf AND longitude == %lf", latitude, longitude)
        
        fetchRequest.predicate = predicate
        
        do {
            let result = try managedContext.fetch(fetchRequest)
            if result.count == 1 {
                let pin = result[0]
                return pin
            } else {
                fatalError("There are no results from the fetch request; PhotoAlbumVC.")
            }
        } catch {
            print("There was an error with performing the fetch request.")
        }
        return nil
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController<Photo> = { () -> NSFetchedResultsController<Photo> in
        
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let pin: Pin = self.returnPin(annotation: self.annotationInstance!) as! Pin

        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        fetchRequest.sortDescriptors = []

        let pred = NSPredicate(format: "pin == %@", pin)
        fetchRequest.predicate = pred

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCollectionViewCell
        let photo = self.fetchedResultsController.object(at: indexPath)
        
        print(photo)
        
        if let data = photo.value(forKey: "image") as? NSData {
            cell.imageView.image = UIImage(data: data as Data)
            cell.activityIndicator.stopAnimating()
            cell.activityIndicator.hidesWhenStopped = true
        }
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if let numberOfSections = self.fetchedResultsController.sections?.count {
            return numberOfSections
        } else {
            return 0
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if fetchedResultsController.sections![section].numberOfObjects > 0 {
            return fetchedResultsController.sections![section].numberOfObjects
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
        collectionView.allowsMultipleSelection = true
        cell.layer.borderWidth = 2.0
        cell.layer.borderColor = UIColor.blue.cgColor
        
        deletedIndexPaths.append(indexPath)
        updateButtonTitle()
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
        
        cell.layer.borderWidth = 0.0
        cell.layer.borderColor = UIColor.blue.cgColor
        
        if let index = deletedIndexPaths.index(of: indexPath) {
            deletedIndexPaths.remove(at: index)
            updateButtonTitle()
        }
    }
    
    func updateButtonTitle() {
        if deletedIndexPaths.count > 0 {
            self.newCollectionButton.setTitle("Remove Selected Pictures", for: .normal)
        } else {
            self.newCollectionButton.setTitle("New Collection", for: .normal)
        }
    }
    
    @IBAction func newCollectionButton(_ sender: AnyObject) {
        print("Deleted Index Paths Array Count: \(deletedIndexPaths.count)")
        if deletedIndexPaths.count > 0 {
            for indexPath in deletedIndexPaths {
                let photo = fetchedResultsController.object(at: indexPath)
                managedContext.delete(photo)
                (UIApplication.shared.delegate as! AppDelegate).saveContext()
            }
            self.collectionView.reloadData()
        } else {
            print("There were no items to delete. Need to trigger download and fetch of new photos.")
            for indexPath in insertedIndexPaths {
                let photo = fetchedResultsController.object(at: indexPath)
                managedContext.delete(photo)
                (UIApplication.shared.delegate as! AppDelegate).saveContext()
            }
            self.collectionView.reloadData()
        }
    }
    
    //MARK: NSFetchedResultsControllerDelegate
    //Any change to the context will cause these delegate methods to be called.
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("Deleted index paths .count = \(deletedIndexPaths.count)")
        insertedIndexPaths = [IndexPath]()
        deletedIndexPaths = [IndexPath]()
        updatedIndexPaths = [IndexPath]()
        print("Deleted index paths .count = \(deletedIndexPaths.count)")
    }
    
    //Save the index path of each object that is added/deleted/updated as the change is identified by Core Data.
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        
        //A new Photo has been added. Save the "newIndexPath" so that the cell can be added later.
        case .insert:
            print("Insert an item.")
            insertedIndexPaths.append(newIndexPath!)
            break
            
        //A Photo has been deleted. Save the index path, so the corresponding cell can be removed.
        case .delete:
            print("Delete an item.")
            print("deletedIndexPaths.count = \(deletedIndexPaths.count)")
            deletedIndexPaths.append(indexPath!)
            print("deletedIndexPaths.count = \(deletedIndexPaths.count)")
            break
        case .update:
            print("Update an item.")
            updatedIndexPaths.append(indexPath!)
            break
        default:
            print("There was an unexpecteed case in the switch statement: CoreDataCollectionViewController - controller didChange.")
        }
    }
    
    
    //Perform all of the updates in the current batch:
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                print("# of insertedIndexPaths: \(self.insertedIndexPaths.count)")
                self.collectionView?.insertItems(at: [indexPath])
            }
            
            //This is the point at which it is deleted from the context and the context is saved again:
            for indexPath in self.deletedIndexPaths {
                print("# of deletedIndexPaths: \(self.deletedIndexPaths.count)")
                self.collectionView?.deleteItems(at: [indexPath])
                print("# of deletedIndexPaths: \(self.deletedIndexPaths.count)")
            }
            
            for indexPath in self.updatedIndexPaths {
                print("# of updatedIndexPaths: \(self.updatedIndexPaths.count)")
                self.collectionView?.reloadItems(at: [indexPath])
            }
            
            }, completion: nil)

    }
    
}
