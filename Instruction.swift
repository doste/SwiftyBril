//
//  Instruction.swift
//  SwiftyBril
//
//  Created by Juan Ignacio Bianchi on 20/05/2025.
//

import Foundation

public enum InstructionOrLabel {
    case Instruction(Instruction)
    case Label(String)
}

enum IntOrBoolean {
    case int(Int?)
    case bool(Bool?)
}

public struct Instruction {
    var op: String              //the opcode that determines what the instruction does.
//Depending on the opcode, the instruction might also have:
    var dest: String?           // the name of the variable where the operation’s result is stored.
    var type: String?           // the type of the destination variable.
    var args: [String]?         // the arguments to the operation. These are names of variables.
    let funcs: [String]?        // any names of functions referenced by the instruction.
    let labels: [String]?       // any label names referenced by the instruction.
    //var value: Int?             // a number or boolean: the value, for a constant.
    var value: IntOrBoolean?
}


extension Instruction {
    
    public func isJump() -> Bool {
        return self.op == "jmp"
    }

    public func isBranch() -> Bool {
        return self.op == "br"
    }

    public func isRet() -> Bool {
        return self.op == "ret"
    }

    public func isTerminator() -> Bool {
        return self.isJump() || self.isBranch() || self.isRet()
    }
    
    public func isArithmeticOp() -> Bool {
        return ["add", "sub", "mul", "div"].contains(self.op)
    }
    
    public func isArithmeticOp(ofKind: String) -> Bool {
        return self.isArithmeticOp() && ofKind == self.op
    }
    
    public func isComparisonOp() -> Bool {
        return ["eq", "lt", "le", "gt", "ge"].contains(self.op)
    }
    
    public func isComparisonOp(ofKind: String) -> Bool {
        return self.isComparisonOp() && ofKind == self.op
    }
    
    public func isLogicOp() -> Bool {
        return ["and", "or", "not"].contains(self.op)
    }
    
    public func isConstOp() -> Bool {
        return self.op == "const"
    }
    
    public func isPrintOp() -> Bool {
        return self.op == "print"
    }
    
    public func isIdOp() -> Bool {
        return self.op == "id"
    }
    
    public func toString() -> String {
        var instrStr: String = "  "
        
        // v: int = const 4;
        // v2: int = add v0 v1;
        if let dest = self.dest {
            instrStr += "\(dest):"
            if let type = self.type {
                instrStr += " \(type) ="
                
                instrStr += " \(self.op)" // No need to if let, all instructions have an 'op'.
                
                if isArithmeticOp() || isComparisonOp() {  // Both arithmetic and comparison operations take two arguments.
                    assert(self.args != nil)
                    assert(self.args!.count == 2)
                    instrStr += " \(self.args![0]) \(self.args![1]);\n"
                } else if isConstOp() { // A Constant must have a 'value', which is the literal value for the constant.
                    assert(self.value != nil)
                    assert(self.type != nil)
                    
                    switch self.value! {
                    case .int(let intVal):
                        instrStr += " \(intVal!);\n"
                    case .bool(let booleanVal):
                        if booleanVal == true {
                             instrStr += " true;\n"
                         } else {
                             instrStr += " false;\n"
                         }
                    }
                } else if isLogicOp(){
                    assert(self.args != nil)
                    assert(self.args!.count == 1)
                    instrStr += " \(self.args![0]);\n"
                } else if isIdOp() {
                    
                    if (self.args == nil) {
                        instrStr += " >>\n"
                    } else {
                        instrStr += " \(self.args![0]);\n"
                    }
                    
                    //assert(self.args != nil)
                    //assert(self.args!.count == 1)
                    //instrStr += " \(self.args![0]);\n"
                }
            }
        }
        
        // jmp .somewhere;
        if isJump() {
            instrStr += "jmp"
            assert(self.labels != nil)
            assert(self.labels!.count == 1)
            instrStr += " .\(self.labels![0]);\n"
        }
        
        //print v;
        if isPrintOp() {
            instrStr += "print"
            if let printArgs = self.args {
                for arg in printArgs {
                    instrStr += " \(arg)"
                }
                instrStr += ";\n"
            }
        }
        
        //ret;
        if isRet() {
            instrStr += "ret;\n"
        }
        
        return instrStr
    }

    public func printInstruction() {
        print(self.toString())
    }
    
    
    public func replaceArg(_ oldArg: String, _ newArg: String) -> Instruction {
        
        var newInstruction = self
        
        if oldArg == newArg {
            return newInstruction
        }
        
        if let args = self.args {
            var newArgs: [String] = []
            for arg in args {
                if arg == oldArg {
                    newArgs.append(newArg)
                } else {
                    newArgs.append(arg)
                }
            }
            newInstruction.args = newArgs
        }
        
        return newInstruction
    }
    
    
    func replaceInstr(toConstValue: IntOrBoolean) -> Instruction {
        var newInstruction = self
    
        switch toConstValue {
            case .int(let intConst):
                newInstruction.op = "const"
                newInstruction.args?.removeAll()
                newInstruction.value = IntOrBoolean.int(intConst)
                newInstruction.type = "int"
            case .bool(let boolConst):
                newInstruction.op = "const"
                newInstruction.args?.removeAll()
                newInstruction.value = IntOrBoolean.bool(boolConst)
                newInstruction.type = "bool"
        }
        
        return newInstruction
    }
    
    /*
    func replaceInstr(toConstValue: Int) -> Instruction {
        var newInstruction = self
    
        newInstruction.op = "const"
        newInstruction.args?.removeAll()
        newInstruction.value = toConstValue
        newInstruction.type = "int"
        
        return newInstruction
    }*/
    
    func replaceInstr(withCopyOfVar: String) -> Instruction {
        var newInstruction = self
    
        newInstruction.op = "id"
        newInstruction.args?.removeAll()
        newInstruction.args?.append(withCopyOfVar)
        
        return newInstruction
    }
    
    func replaceDest(_ newDest: String) -> Instruction {
        var newInstruction = self
        
        newInstruction.dest = newDest
        
        return newInstruction
    }
}

