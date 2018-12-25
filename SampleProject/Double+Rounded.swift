//
//  Double+Rounded.swift
//  SampleProject
//
//  Created by Jack Amoratis on 12/23/18.
//  Copyright © 2018 John Amoratis. All rights reserved.
//

import Foundation

extension Double {
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
