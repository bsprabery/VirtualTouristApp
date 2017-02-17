//
//  Pin+CoreDataClass.swift
//  VirtualTouristApp
//
//  Created by Brittany Sprabery on 2/8/17.
//  Copyright © 2017 Brittany Sprabery. All rights reserved.
//

import Foundation
import CoreData


public class Pin: NSManagedObject {

    convenience init(latitude: Double, longitude: Double, context: NSManagedObjectContext) {
        if let entity = NSEntityDescription.entity(forEntityName: "Pin", in: context) {
            self.init(entity: entity, insertInto: context)
            self.latitude = Client.sharedInstance().getLatitude()
            self.longitude = Client.sharedInstance().getLongitude()
        } else {
            fatalError("Unable to find Entity name.")
        }
    }
    
}
