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
    @IBOutlet var noImagesLabel: UILabel!
    
    let managedContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var annotationInstance: MKAnnotation?
    
    var selectedIndexPaths = [IndexPath]()
    var insertedIndexPaths: [IndexPath]!
    var deletedIndexPaths: [IndexPath]!
    var updatedIndexPaths: [IndexPath]!
    
    private let minimumItemSpacing: CGFloat = 5
    private let itemWidth: CGFloat = 130
   
    
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
       
        noImagesLabel.isHidden = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumInteritemSpacing = minimumItemSpacing
        layout.minimumLineSpacing = minimumItemSpacing
        layout.sectionInset = UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        
        collectionView.collectionViewLayout = layout
        
        noImagesLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        noImagesLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
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
                print("There were no pins returned with the request.")
            }
        } catch {
            print("There was an error with performing the fetch request.")
        }
        return nil
    }
    
    @IBAction func newCollectionButton(_ sender: AnyObject) {
  
        if selectedIndexPaths.count > 0 {
            for indexPath in selectedIndexPaths {
                let photo = fetchedResultsController.object(at: indexPath)
                managedContext.delete(photo)
            }
            (UIApplication.shared.delegate as! AppDelegate).saveContext()
            
            selectedIndexPaths.removeAll()
            updateButtonTitle()
            
        } else {
            for photo in fetchedResultsController.fetchedObjects as [Photo]! {
                managedContext.delete(photo)
                noImagesLabel.isHidden = true
            }
            noImagesLabel.isHidden = true
            
            (UIApplication.shared.delegate as! AppDelegate).saveContext()
            Client.sharedInstance().getNewImageURLs()
            
        }
    }
    
    func updateButtonTitle() {
        if selectedIndexPaths.count > 0 {
            self.newCollectionButton.setTitle("Remove Selected Pictures", for: .normal)
        } else {
            self.newCollectionButton.setTitle("New Collection", for: .normal)
        }
    }
    
    func configureCell(cell: PhotoCollectionViewCell, atIndexPath indexPath: IndexPath) {
        let photo = self.fetchedResultsController.object(at: indexPath)
        cell.imageView.image = UIImage(named: "placeholder")
        
        if photo.image == nil {
            downloadImageForPhoto(photo: photo, cell: cell)
        } else {
            cell.imageView.image = UIImage(data: photo.image! as Data)
        }
    }
    
    func downloadImageForPhoto(photo: Photo, cell: PhotoCollectionViewCell) {
        let url = URL(string: photo.imageURL!)
        let request = NSMutableURLRequest(url: url!)
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            
            guard let data = data else {
                return
            }
            
            DispatchQueue.main.async {
                cell.imageView.image = UIImage(data: data)
            }
            
            let imageData = data as NSData
            photo.setValue(imageData, forKey: "image")
            (UIApplication.shared.delegate as! AppDelegate).saveContext()
        }
        
        task.resume()
    }
    
    //MARK: Collection View Datasource:
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCollectionViewCell
        
        cell.layer.borderWidth = 0.0
        cell.layer.borderColor = UIColor.clear.cgColor
        
        configureCell(cell: cell, atIndexPath: indexPath)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let section = fetchedResultsController.sections?[section] {
            if section.numberOfObjects == 0 {
                self.collectionView.backgroundView = noImagesLabel
                noImagesLabel.isHidden = false
            }
            return section.numberOfObjects
        } else {
            return 0
        }
    }
    
    //MARK: Collection View Delgate: 
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
        
        collectionView.allowsMultipleSelection = true
        cell.layer.borderWidth = 3.0
        cell.layer.borderColor = UIColor.blue.cgColor
        
        selectedIndexPaths.append(indexPath)
        updateButtonTitle()
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
        
        cell.layer.borderWidth = 0.0
        cell.layer.borderColor = UIColor.clear.cgColor
        
        if let index = selectedIndexPaths.index(of: indexPath) {
            selectedIndexPaths.remove(at: index)
            updateButtonTitle()
        }
    }
    
    //MARK: NSFetchedResultsController and Delegate
    
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

    
    //Any change to the context will cause these delegate methods to be called.
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        insertedIndexPaths = [IndexPath]()
        deletedIndexPaths = [IndexPath]()
        updatedIndexPaths = [IndexPath]()
        
        noImagesLabel.isHidden = true
        newCollectionButton.isEnabled = true
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
            deletedIndexPaths.append(indexPath!)
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
                self.collectionView?.insertItems(at: [indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView?.deleteItems(at: [indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView?.reloadItems(at: [indexPath])
            }
            
            }, completion: nil
        )
    }
    
}

