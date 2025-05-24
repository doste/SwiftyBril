//
//  BasicBlock.swift
//  SwiftyBril
//
//  Created by Juan Ignacio Bianchi on 20/05/2025.
//

import Foundation

public struct BasicBlock {
    var name: String
    var instrs: [InstructionOrLabel]
    
    var succesors: [String]            // We will identify the succesors by their name
}

extension BasicBlock: Equatable {
    
    init() {
        self.name = String()
        self.instrs = [InstructionOrLabel]()
        self.succesors = [String]()
    }
    
    public static func == (lhs: BasicBlock, rhs: BasicBlock) -> Bool {
        return
            lhs.name == rhs.name &&
            lhs.instrs.count == rhs.instrs.count  // uat ???
    }
    
    mutating func appendInstruction(_ instructionToAppend: InstructionOrLabel) {
        self.instrs.append(instructionToAppend)
    }
    
    mutating func removeAllInstructions() {
        self.instrs.removeAll()
    }
    
    func firstInstruction() -> InstructionOrLabel? {
        if self.instrs.isEmpty {
            return nil
        } else {
            return self.instrs[0]
        }
    }
    
    func lastInstruction() -> InstructionOrLabel? {
        if self.instrs.isEmpty {
            return nil
        } else {
            return self.instrs.last!
        }
    }
    
    mutating func addSuccesor(withName: String) {
        self.succesors.append(withName)
    }
    
    public func isEmpty() -> Bool {
        return self.instrs.isEmpty
    }
    
    public func toString() -> String {
        var res: String = ""
        for instr in self.instrs {
            switch instr {
            case .Instruction(let instruction):
                res += instruction.toString()
            case .Label(let label):
                res += "."
                res += label + ":\n"
            }
        }
        return res
    }
    

}
