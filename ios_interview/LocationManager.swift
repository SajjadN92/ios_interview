//
//  LocationManager.swift
//  Ethica
//
//  Created by amin tavassolian on 2016-06-09.
//  Copyright © 2016 EthicaDataServices. All rights reserved.
//
import Foundation
import CoreLocation
import UIKit

class LocationManager: NSObject, CLLocationManagerDelegate {
    private static let DEFAULT_DEVICE_CLASS = 0
    private static let DEFAULT_MAC = "none"
    private static let DEFAULT_DEVICE_NAME = "none"
    private static let GPS_PROVIDER_REUSE = "-reuse"

    private static let instance = LocationManager()
    private var locationManager: CLLocationManager
    private var lastUpdatedLocation: CLLocation?

    private var prevLocation1: CLLocation?
    private var prevLocation2: CLLocation?
    private var prevLocation3: CLLocation?
    private var prevCycleBestLocation: CLLocation?

    static func getInstance() -> LocationManager {
        return instance
    }

    fileprivate override init() {
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        self.prevCycleBestLocation = nil
    }

    func isLocationServiceEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }

    @discardableResult
    func startUpdatingLocation(collectionType: LocationCollectionTypes) -> Bool {
        var log = "Updating location was requested. "
        self.locationManager.delegate = nil
        self.locationManager.delegate = self

        guard CLLocationManager.locationServicesEnabled() else {
            return false
        }
        
        if MotionBasedActivityRecognition.isUserStationary() {
            self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        }

        var requestResult = false
        if collectionType == .WHEN_IN_USE {
            if self.locationManager.authorizationStatus == .notDetermined
                || self.locationManager.authorizationStatus == .restricted
                || self.locationManager.authorizationStatus == .denied {
                log += "Failed. The when-in-use permission is either not determined or not granted. "
                requestResult = false
            } else {
                self.locationManager.startUpdatingLocation()
                requestResult = true
            }
        } else {
            if self.locationManager.authorizationStatus == .notDetermined {
                log += "Failed. The background locationing is not determind."
            } else if self.locationManager.authorizationStatus == .restricted {
                log += "Failed. The background locationing is restricted."
            } else if self.locationManager.authorizationStatus == .denied {
                log += "Failed. The background locationing permission is not granted."
            } else if self.locationManager.authorizationStatus == .authorizedWhenInUse {
                log += "Failed. Only inapp locationing permission is granted."
            } else if self.locationManager.authorizationStatus == .authorizedAlways {
                self.locationManager.startUpdatingLocation()
                requestResult =  true
            } else {
                log += "Failed. GPS locationing is not supported."
            }
        }
        // report the log
        return requestResult
    }

    private func updateCachedLocations(newLocation: CLLocation) {
        self.prevLocation3 = prevLocation2
        self.prevLocation2 = prevLocation1
        self.prevLocation1 = newLocation
    }

    private func clearCachedLocations() {
        self.prevLocation1 = nil
        self.prevLocation2 = nil
        self.prevLocation3 = nil
        self.prevCycleBestLocation = nil
    }

    private func isMoreLocationsRequiredForCurrentCycle() -> Bool {
        guard self.prevLocation1 != nil
            && self.prevLocation2 != nil
            && self.prevLocation3 != nil
            && self.prevLocation1!.horizontalAccuracy <= kCLLocationAccuracyHundredMeters
            && self.prevLocation2!.horizontalAccuracy <= kCLLocationAccuracyHundredMeters
            && self.prevLocation3!.horizontalAccuracy <= kCLLocationAccuracyHundredMeters else {
                return true
        }
        return false
    }

    private func saveLocation(_ locations: CLLocation, provider: String = "") {
        // You can assume this function saves the location locally
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.lastUpdatedLocation = locations.last! as CLLocation

        if self.isMoreLocationsRequiredForCurrentCycle() {
            self.updateCachedLocations(newLocation: self.lastUpdatedLocation!)
            if let prevBestLocation = self.prevCycleBestLocation,
                self.lastUpdatedLocation!.horizontalAccuracy <= prevBestLocation.horizontalAccuracy {
                // We only save the best location for each cycle.
                self.prevCycleBestLocation = self.lastUpdatedLocation!
            } else {
                self.prevCycleBestLocation = self.lastUpdatedLocation!
            }
            saveLocation(self.lastUpdatedLocation!)
        } else {
            self.changeLocationAccuracy(newAccuracy: .THREE_KILOMETERS)
        }
    }

    func changeLocationAccuracy(newAccuracy: LocationAccuracy) {
        DispatchQueue.main.async {
            switch newAccuracy {
            case .BEST:
                if MotionBasedActivityRecognition.isUserStationary() &&
                    self.prevCycleBestLocation != nil {
                    self.reportPrviousCycleLocations()
                    self.changeLocationAccuracy(newAccuracy: .THREE_KILOMETERS)
                } else {
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                    self.clearCachedLocations()
                }
            case .BEST_FOR_NAV:
                self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            case .HUNDRED_METERS:
                self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            case .KILOMETER:
                self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
            case .NEAREST_TEN_METERS:
                self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            case .THREE_KILOMETERS:
                self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            }
        }
    }

    func reportPrviousCycleLocations() {
        guard self.prevCycleBestLocation != nil else {
            return
        }
        saveLocation(self.prevCycleBestLocation!, provider: LocationManager.GPS_PROVIDER_REUSE)
    }

    func stopUpdatingLocation() {
        self.lastUpdatedLocation = nil
        guard locationManager.delegate != nil else {
            return
        }
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Communicate this issue with the user
    }

    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        // Communicate this issue with the user
    }
}
