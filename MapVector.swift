//
//  MapVector.swift
//  SwiftyBril
//
//  Created by Juan Ignacio  Bianchi on 21/05/2025.
//

import Foundation

/*
******************** MapVector ********************

Implements a map that provides insertion order iteration.
It is implemented by mapping from key to an index in a vector of (key, value) pairs.
Two copies of the key are kept, one for indexing in a ordinary Dictionary,
and one for iteration in an Array.

Based on llvm:MapVector [https://llvm.org/doxygen/MapVector_8h_source.html]
*/



public struct KeyValue<A, B> {
    public var key: A
    public var value: B
}


extension KeyValue: Equatable where A: Equatable, B: Equatable {
    public static func == (lhs: KeyValue<A, B>, rhs: KeyValue<A, B>) -> Bool {
        return lhs.key == rhs.key && lhs.value == rhs.value
    }
}

public struct MapVector<K: Hashable, V> : Sequence {
    var map: [K : Int]
    var vector: [KeyValue<K, V>]
    
    public var count: Int {
        return vector.count
    }

    public var keys: [K] {
        var keys = [K]()
        for pair in self.vector {
            keys.append(pair.key)
        }
        return keys
    }
    
    public var isEmpty: Bool {
        return vector.isEmpty
    }
    
}

func isValidIndexInVector<T>(vector: [T], index: Int) -> Bool {
        return index >= 0 && index < vector.count
}

public struct MapVectorIterator<K: Hashable, V>: IteratorProtocol {
    private var iterator: Array<KeyValue<K, V>>.Iterator
    private var mapVector: MapVector<K, V>

    init(_ aMapVector: MapVector<K, V>) {
        iterator = aMapVector.vector.makeIterator()
        mapVector = aMapVector
    }

    public mutating func next() -> KeyValue<K, V>? {
        if let indexInVector = iterator.next() {
            return KeyValue(key: indexInVector.key, value: indexInVector.value)
        }
        return nil
    }
}

extension MapVector {
    
    public func index(of element: K) -> Int? {
        self.vector.firstIndex(where: { $0.key == element })
    }
    
    public func keyFor(index: Int) -> K? {
        assert(isValidIndexInVector(vector: self.vector, index: index))
        return self.vector[index].key
    }

    public func makeIterator() -> MapVectorIterator<K, V> {
        return MapVectorIterator(self)
    }

    public init() {
        self.map = [K : Int]()
        self.vector = [KeyValue<K, V>]()
    }
 
    public subscript(key: K) -> V? {
        get {
            if let indexInVector = map[key] {
                assert(isValidIndexInVector(vector: self.vector, index: indexInVector))
                return self.vector[indexInVector].value
            }
            return nil
        }
        set(newElement) {
            if let newValue = newElement {
                self.vector.append(KeyValue(key: key, value: newValue))
            }
            map[key] = self.vector.count - 1
        }
    }
    
    public func contains(_ key: K) -> Bool {
        return self.map[key] != nil
    }
    
    public mutating func removeAll() {
        vector.removeAll()
        map.removeAll()
    }
    
    // Returns the value that was removed, or nil if the key was not present in the dictionary.
    public mutating func removeValue(forKey key: K) -> V? {
        if !self.contains(key) {
            return nil
        }
        let indexInVector = self.map[key]!
        let keyValuePair = self.vector[indexInVector]
        let removedValue = keyValuePair.value
        
        // Remove it from the vector.
        self.vector.remove(at: indexInVector)
        
        // Update the map entries, so now each entry that was after the deleted (key, indexIntoVector),
        // has its value updated, that is, one less.
        for i in indexInVector..<self.vector.count {
            self.map[self.vector[i].key]! -= 1
        }
        
        // Finally remove it from the map.
        self.map.removeValue(forKey: key)
        
        return removedValue
    }
    
    // TODO: Learn how to do this propertly (should be: func enumerated() -> EnumeratedSequence<Self>)
    public func enumerated() -> Array<(Int, (K, V))> {
        var enumeration : Array<(Int, (K, V))> = []
        
        enumeration.reserveCapacity(self.vector.count)
        
        for (index, keyValuePair) in self.vector.enumerated() {
            enumeration.append((index, (keyValuePair.key, keyValuePair.value)))
        }
        
        return enumeration
    }
}



