//
//  FragmentArray.swift
//  VideoPlayer
//
//  Created by 黄山哥 on 2019/1/31.
//  Copyright © 2019 黄山哥. All rights reserved.
//

import Foundation


struct FragmentArray {
    
    private var storage: [NSRange]
    
    init() {
        self.storage = []
    }
    
    init(_ array: [NSRange]) {
        self.storage = array
    }
}

extension FragmentArray {
    
    /// 插入数据
    mutating func insert(_ newElement: NSRange) {
        let index = self.index(for: newElement)
        if index < count && storage[index] == newElement {
            return
        }
        // 合并相连的fragment
        if index >= 1 && storage[index - 1].upperBound == newElement.location {
            storage[index - 1].length += newElement.length
            if index < count && storage[index].location == newElement.upperBound {
                storage[index - 1].length += storage[index].length
                storage.remove(at: index)
            }
            return
        } else if index < count && storage[index].location == newElement.upperBound {
            storage[index - 1].length += storage[index].length
            storage.remove(at: index)
            return
        }
        storage.insert(newElement, at: index)
    }
    
    /// 查找element的索引
    func index(of element: NSRange) -> Int? {
        let index = self.index(for: element)
        guard index < count, storage[index] == element else { return nil }
        return index
    }
    
    /// 是否包含element
    func contains(_ element: NSRange) -> Bool {
        let index = self.index(for: element)
        return index < count && storage[index] == element
    }
    
    /// 对每个element执行body
    func forEach(_ body: (NSRange) throws -> Void) rethrows {
        try storage.forEach(body)
    }
    
    /// 返回一个有序数组
    func sorted() -> [NSRange] {
        return storage
    }
    
    private func index(for element: NSRange) -> Int {
        var start = 0
        var end = count
        
        while start < end {
            let mid = start + (end - start) / 2
            if element > storage[mid] {
                start = mid + 1
            } else {
                end = mid
            }
        }
        return start
    }
}


// MARK: - CustomStringConvertible
extension FragmentArray: CustomStringConvertible {
    
    var description: String {
        let contents = self.lazy.map({"\($0)"}).joined(separator: ",")
        return "[\(contents)]"
    }

}

// MARK: - RandomAccessCollection
extension FragmentArray: RandomAccessCollection {
    typealias Indices = CountableRange<Int>
    
    var startIndex: Int { return storage.startIndex }
    var endIndex: Int { return storage.endIndex }
    
    subscript(index: Int) -> NSRange { return storage[index] }
}


// MARK: - NSRange

extension NSRange: Comparable {
    
    public static func < (lhs: _NSRange, rhs: _NSRange) -> Bool {
        return lhs.location < rhs.location
    }
    
}
