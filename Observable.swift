//
//  Observable.swift
//
//  Created by Alexei on 1/9/17.
//  Copyright © 2017 Evenly. All rights reserved.

import Foundation

struct WeakObserver<T> {
    typealias Closure = (Result<T>) -> ()
    weak var object : AnyObject?
    let closure : Closure
}

protocol Observable: class {
    associatedtype T
    func add(observer: AnyObject, closure: @escaping WeakObserver<T>.Closure)
    func removeObserver(observer: AnyObject, alreadyOnQueue: Bool)
    func notifyObservers(result: Result<T>)
    var observers: [WeakObserver<T>] { get set }
}

private let observersQueue = DispatchQueue(label: "ObservableQueue", qos: .utility)
extension Observable {
    func add(observer: AnyObject, closure: @escaping WeakObserver<T>.Closure) {
        observersQueue.async {
            let observer = WeakObserver(object: observer, closure: closure)
            self.observers.append(observer)
            self.cleanup() //makes a cleanup timing. It may be not the best, but seems to be OK for now
        }
    }
    
    //sync is true by default because usually this method is called from deinit
    func removeObserver(observer: AnyObject, alreadyOnQueue: Bool = false) {
        let closure = {
            var indexToRemove : Int? = nil
            
            for index in 0..<self.observers.count {
                let weakObserver = self.observers[index]
                if let object = weakObserver.object {
                    if object === observer {
                        indexToRemove = index
                    }
                }
            }
            
            if let uIndex = indexToRemove {
                _ = self.observers.remove(at: uIndex)
            }
        }
        
        if alreadyOnQueue {
            if #available(iOS 10.0, *) {
                //dispatch_sync is going to be called from 
                dispatchPrecondition(condition: .onQueue(observersQueue))
            } else {
                // Fallback on earlier versions
            }
            
            closure()
        } else {
            if #available(iOS 10.0, *) {
                //dispatch_sync is going to be called from
                dispatchPrecondition(condition: .notOnQueue(observersQueue))
            } else {
                // Fallback on earlier versions
            }
            
            observersQueue.sync(execute: closure)
        }
    }
    
    func notifyObservers(result: Result<T>) {
        observersQueue.async {
            for weakObserver in self.observers {
                if weakObserver.object != nil {
                    weakObserver.closure(result)
                }
            }
        }
    }
    
    private func cleanup() {
        self.observers = self.observers.filter { $0.object != nil }
    }
}
