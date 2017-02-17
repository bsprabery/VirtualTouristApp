//
//  Photo+CoreDataClass.swift
//  VirtualTouristApp
//
//  Created by Brittany Sprabery on 2/8/17.
//  Copyright © 2017 Brittany Sprabery. All rights reserved.
//

import Foundation
import UIKit
import CoreData


public class Photo: NSManagedObject {

    convenience init(image: UIImage, context: NSManagedObjectContext) {
        if let entity = NSEntityDescription.entity(forEntityName: "Photo", in: context) {
            self.init(entity: entity, insertInto: context)
        } else {
            fatalError("Unable to find Entity name!")
        }
    }
}
