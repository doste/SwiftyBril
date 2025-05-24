//
//  LVN.swift
//  SwiftyBril
//
//  Created by Juan Ignacio  Bianchi on 21/05/2025.
//

import Foundation

public struct Value: Hashable {
    var op: String
    var args: [Int]?        // In case of a 'const', its (only) arg will be the field 'value
}

public typealias CanonicalHomeForVariable = String
public typealias VariableName = String
public typealias IndexIntoTable = Int

public struct LVNContext {
    // TODO: Rename or fix in some way this. The key is named Value!
    // IDEA: MapVector<Int, (Value, CanonicalHomeForVariable)> . So we can index it by just the number of row in the table.
    var table: MapVector<Value, CanonicalHomeForVariable> = MapVector<Value, CanonicalHomeForVariable>()
    
    var var2num: [VariableName : IndexIntoTable] = [:]
}

extension LVNContext {
    
    // Kind of a inverse key-value lookup. Given the value it returns the corresponding key.
    public func valueFrom(canonicalHome: CanonicalHomeForVariable) -> Value? {
        for tableEntry: KeyValue<Value, CanonicalHomeForVariable> in self.table {
            if tableEntry.value == canonicalHome {
                return tableEntry.key
            }
        }
        return nil
    }
    
    public func tableEntryAt(index: IndexIntoTable) -> KeyValue<Value, CanonicalHomeForVariable>? {
        for tableEntry: KeyValue<Value, CanonicalHomeForVariable> in self.table {
            if let idx = self.table.index(of: tableEntry.key) {
                if idx == index {
                    return tableEntry
                }
            }
        }
        return nil
    }
    
    // If we have a Value like ( id #0 ) this would return directly #0
    // If not, it would just return the corresponding index into the table.
    public func lookUpInVar2num(_ varName: VariableName, beingIdInstr: Bool = false) -> IndexIntoTable? {
        return self.var2num[varName]
    }
    
    public mutating func updateInstruction(atIndexInTable: IndexIntoTable, withNewValue newValue: Value) {
        if let tableEntry: KeyValue<Value, CanonicalHomeForVariable> = self.tableEntryAt(index: atIndexInTable) {
            if let _ = self.table.removeValue(forKey: tableEntry.key) {
                self.table[newValue] = tableEntry.value
                
                // Every entry in var2num that has as value 'atIndexInTable' needs to be updated too.
                for (key, value) in self.var2num {
                    if value == atIndexInTable {
                        self.var2num[key] = self.table.index(of: newValue)!
                    }
                }
            }
        }
    }
}

extension BasicBlock {
    
    func debugValue(_ value: Value) -> String {
        var debugStr: String = ""
        
        if value.op == "const" {
            debugStr += "( \(value.op)"
            debugStr += " \(value.args!.first!))"
            return debugStr
        }
        debugStr += "( \(value.op)"
        if let args = value.args {
            debugStr += " "
            for arg in args {
                debugStr += "#\(arg)"
                //if arg != args.last! {
                    debugStr += " "
                //}
            }
        }
        debugStr += ")"
        return debugStr
    }
    
    func debugLVNTable(_ lvn: LVNContext) {
        print("LVN TABLE:")
        
        for tableEntry: KeyValue<Value, CanonicalHomeForVariable> in lvn.table{
            print("  | #\(lvn.table.index(of: tableEntry.key) ?? -1)", terminator: "")
            print("     |  VAL: \(debugValue(tableEntry.key))",terminator: "")
            print("  |  VAR: \(tableEntry.value) |")
        }
        
        print("LVN var2num:")
        for (varName, index) in lvn.var2num {
            print("  | \(varName): #\(index)")
        }
    }
    

    
    mutating func localValueNumbering() {
        
        var lvn = LVNContext()
        
        for index in self.instrs.indices {
            let instr_ = self.instrs[index]
            switch instr_ {
            case .Label(_):
                break
            case .Instruction(let instr):
                
                //print("-------------NEW INSTR \(index)")
                
                var valueArgs: [Int] = []
                var valueArgsDefinedOutsideOfBlock: [String] = []
                
                if instr.isConstOp() {                      // A little tweak to have the 'value' of a const instr be its "argument".
                    if let literalValue = instr.value {
                        valueArgs.append(literalValue)
                    }
                } else {
                    if let args = instr.args {
                        for arg in args {
                            if let indexInTableForVar = lvn.var2num[arg] {
                                valueArgs.append(indexInTableForVar)
                            } else {
                                valueArgsDefinedOutsideOfBlock.append(arg)
                            }
                        }
                    }
                }
                
                // Build a new value tuple.
                // For example: (add, #1, #2) => The value corresponding to the instr `add a b` where 'a' is in the table entry #1
                // and 'b' in the #2.
                //var value = Value(op: instr.op, args: valueArgs)
                
                var value: Value
                if !valueArgsDefinedOutsideOfBlock.isEmpty && instr.isIdOp() {
                    value = Value(op: "outside", args: [])
                    lvn.table[value] = valueArgsDefinedOutsideOfBlock[0]
                    lvn.var2num[valueArgsDefinedOutsideOfBlock[0]] = lvn.table.index(of: value)
                } else {
                    value = Value(op: instr.op, args: valueArgs)
                }
                
                
                // If it's a 'id' instr, we will treat the value tuple `(id #n)` exactly as `#n`.
                if instr.isIdOp() {
                    if !valueArgs.isEmpty {
                        // For example, if we have this LVN table:
                        //   | #0     |  VAL: ( const 4)  |  VAR: x     |
                        //   | #1     |  VAL: ( id #0 )   |  VAR: copy1 |
                        // We want to transform the second VAL into exactly the first VAL. And then copy1 just to point to #0 in the
                        // var2num struct.
                        value = lvn.valueFrom(canonicalHome: (lvn.tableEntryAt(index: valueArgs[0])!.value))!
                        // Following the example, here we have:
                        // valueArgs[0] would be #0
                        // then, with lvn.tableEntryAt(index: valueArgs[0]) we get the first entry of the table.
                        // After that, with .value we get the VAR: x.
                        // Finally, with valueFrom(canonicalHome:) we get the corresponding VAL for that VAR, the (const 4) tuple.
                    }
                }
                
                // If the instr is some kind of an assignment.
                if var varAssignedTo = instr.dest {
                    var indexInTableForVar: Int? = nil
                    
                    // Independently if the value is in the table or not, we need to modify the variable names
                    // if they are cobbled later in the block.
                    let isInstructionOverwritten = self.isInstructionOverwrittenLater(at: index)
                    // .0 is the boolean result, and .1 is the index of the (possible) 'cobblerer'.
                    if isInstructionOverwritten.0 {
                        let oldVarValue: String = varAssignedTo
                        varAssignedTo = self.replaceNameOfVarAssignedTo(ofInstructionAt: index)
                        self.replaceUsesOfVar(oldVarValue, withNewVar: varAssignedTo, untilIndex: isInstructionOverwritten.1!)
                        // This way we replace only uses of the var that refer to the value that we are replacing.
                        // Example:
                        // x = 10               <- When we change the name of x, for example to x'
                        // ...
                        // y = add x, z             <- We would have here: y = add x', z
                        // ...
                        // x = 20           <- Here, x gets clobbered.
                        // w = mul x, x                     <- BUT here we want x to refer to 20, so we don't change x to x' after its clobbering.
                    }
                    
                    // If value is already in table,
                    // the value has been computed before, reuse it.
                    if lvn.table[value] != nil {
                        
                        indexInTableForVar = lvn.table.index(of: value)
                        
                        // Example: If we had:
                        //      sum1: int = add a b;
                        //      sum2: int = add a b;
                        // This replacement would result in:
                        //      sum1: int = add a b;
                        //      sum2: int = id sum1;
                        if let variableName = lvn.table[value] {
                            // Replace instr with copy of var.
                            self.replaceInstr(at: index, withCopyOfVar: variableName)
                        }
                    } else {
                        
                        // A newly computed value.
                        
                        indexInTableForVar = lvn.table.count    // Create a new index for the new entry.
                        
                        lvn.table[value] = varAssignedTo        // Assign the canonical home to this value.
                        
                        for arg in instr.args ?? [] {
                            
                            // Replace arg with table[var2num[arg]].var
                            
                            // lvn.var2num[arg] gives us the row (index) into the table corresponding to this particular value.
                            // Then, lvn.tableEntryAt(index:) gives us the VAL and VAR for that value, that is: the tuple and its canonical home.
                            // So we replace the argument of the instruction to point to the table entry.
                            
                            //if let indexInTableForVar = lvn.var2num[arg] {
                            if let indexInTableForVar = lvn.lookUpInVar2num(arg) {
                            
                                if let newArg = lvn.tableEntryAt(index: indexInTableForVar) {
                        
                                    self.replaceArgument(arg, ofInstructionAt: index, withNewArgument: newArg.value)
                                    
                                    //self.replaceArgument(arg, ofInstructionAt: index, withNewArgument: newArg.value)
                                    // Example: If we had:
                                    //      sum1: int = add a b;
                                    //      sum2: int = add a b;
                                    //      prod: int = mul sum1 sum2;
                                    // After this we would have:
                                    //      sum1: int = add a b;
                                    //      sum2: int = id sum1;
                                    //      prod: int = mul sum1 sum1;
                                }
                            }
                        }
                    }
                   
                    // Independently if the value was in the table or not, we now have to add the variable to the var2num structure.
                    if let indexInTableForVar = indexInTableForVar {
                        lvn.var2num[varAssignedTo] = indexInTableForVar
                    }
               
                } else { // instr doesn't have a 'dest', for example `print`.
                    if let args = instr.args {
                        for arg in args {
                            // First index into the table,
                            if let indexInTableForVar = lvn.var2num[arg] {
                                // then, get the canonical home (.value) for this variable.
                                if let newArg = lvn.tableEntryAt(index: indexInTableForVar)?.value {
                                    // Replace the argument of the instr with the new argument given by the table.
                                    self.replaceArgument(arg, ofInstructionAt: index, withNewArgument: newArg)
                                    // If arg == newArg, that will be handled by the Instruction's method replaceArg,
                                    // it will just return the given instruction.
                                }
                            }
                        }
                    }
                }
                
            }
        }
        
        self.debugLVNTable(lvn)
        
        self.constantPropagation(lvn)
        
        self.constantFolding(&lvn)
    }
    
    
    // To be run *after* localValueNumbering() (Assumes the lvnContext is given built).
    mutating func constantPropagation(_ lvn: LVNContext) {
        for index in self.instrs.indices {
            let instr_ = self.instrs[index]
            switch instr_ {
                case .Label(_):
                    break
                case .Instruction(let instr):
                    
                    if instr.isIdOp() {
                        assert(instr.args != nil)
                        assert(instr.args!.count == 1)
                        
                        if let indexOfArgOfIdInstr = lvn.var2num[instr.args![0]] {
                            if let tableEntry = lvn.tableEntryAt(index: indexOfArgOfIdInstr) {
                                let canonicalHomeForArgOfIdInstr = tableEntry.value
                                
                                if let value = lvn.valueFrom(canonicalHome: canonicalHomeForArgOfIdInstr) {
                                    if value.op == "const" {
                                        assert(value.args != nil)
                                        assert(value.args!.count == 1)
                                        self.replaceInstr(at: index, toConstValue: value.args![0])
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }
    
    func areInstructionArgumentsContants(_ instr: Instruction, _ lvn: LVNContext) -> Bool {
        if instr.args == nil {
            return false
        }
        
        return instr.args!.allSatisfy { (arg) -> Bool in
            if let X = lvn.var2num[instr.args![0]] {
                if let canonicalHomeForArgOfIdInstr = (lvn.tableEntryAt(index: X)?.value) {
                    if let value = lvn.valueFrom(canonicalHome: canonicalHomeForArgOfIdInstr) {
                        if value.op == "const" {
                            assert(value.args != nil)
                            assert(value.args!.count == 1)
                            return true
                        }
                    }
                }
            }
            return false
        }
    }
    
    
    mutating func constantFoldingArithmeticInstruction(indexOfInstr: Int, arithmeticOp: (Int, Int) -> Int, _ lvn: inout LVNContext) -> Bool {
        
        let instr_ = self.instrs[indexOfInstr]
        switch instr_ {
            case .Label(_):
                break
            case .Instruction(let instr):
                var constantArgs = [Int]()
                for arg in instr.args ?? []  {
                    // We need to access the constant value of each. To do that, we use the LVN table.
                    if let indexOfVarInTable = lvn.var2num[arg] {
                        if let tableEntry = lvn.tableEntryAt(index: indexOfVarInTable) {
                            let valueOfArg = tableEntry.key
                            assert(valueOfArg.op == "const")
                            assert(valueOfArg.args != nil)
                            assert(valueOfArg.args!.count == 1)
                            constantArgs.append(valueOfArg.args![0])
                        }
                    }
                }
                assert(constantArgs.count == 2)
                let resultOfAddingConstants: Int = arithmeticOp(constantArgs[0], constantArgs[1])
                self.replaceInstr(at: indexOfInstr, toConstValue: resultOfAddingConstants)
                // Not only replace the actual instruction in the block, but also update the LVN table:
                lvn.updateInstruction(atIndexInTable: indexOfInstr, withNewValue: Value(op: "const", args: [resultOfAddingConstants]))
                return true
        }
        return false
    }
    
    mutating func constantFoldingPass(_ lvn: inout LVNContext) -> Bool {
        
        var programChanged: Bool = false
        for index in self.instrs.indices {
            
            let instr_ = self.instrs[index]
            switch instr_ {
            case .Label(_):
                break
            case .Instruction(let instr):
                
                if instr.isArithmeticOp() {
                    if self.areInstructionArgumentsContants(instr, lvn) {
                        if instr.isArithmeticOp(ofKind: "add") {
                            programChanged = programChanged || self.constantFoldingArithmeticInstruction(indexOfInstr: index, arithmeticOp: +, &lvn)
                        } else if instr.isArithmeticOp(ofKind: "sub") {
                            programChanged = programChanged || self.constantFoldingArithmeticInstruction(indexOfInstr: index, arithmeticOp: -, &lvn)
                        } else if instr.isArithmeticOp(ofKind: "mul") {
                            programChanged = programChanged || self.constantFoldingArithmeticInstruction(indexOfInstr: index, arithmeticOp: *, &lvn)
                        } else if instr.isArithmeticOp(ofKind: "div") {
                            programChanged = programChanged || self.constantFoldingArithmeticInstruction(indexOfInstr: index, arithmeticOp: /, &lvn)
                        }
                    }
                }
            }
    }
        
        return programChanged
    }
    
    mutating func constantFolding(_ lvn: inout LVNContext) {
        while self.constantFoldingPass(&lvn) {}
    }
    
    mutating func replaceInstr(at indexOfInstruction: Int, toConstValue: Int) {
        let instr_ = self.instrs[indexOfInstruction]
        switch instr_ {
        case .Label(_):
            break
        case .Instruction(let instr):
            self.instrs[indexOfInstruction] = InstructionOrLabel.Instruction(instr.replaceInstr(toConstValue: toConstValue))
        }
    }
    
    mutating func replaceInstr(at indexOfInstruction: Int, withCopyOfVar: CanonicalHomeForVariable) {
        let instr_ = self.instrs[indexOfInstruction]
        switch instr_ {
        case .Label(_):
            break
        case .Instruction(let instr):
            if !instr.isConstOp() { // TODO: Should we handle this case?
                self.instrs[indexOfInstruction] = InstructionOrLabel.Instruction(instr.replaceInstr(withCopyOfVar: withCopyOfVar))
            }
        }
    }
    
    
    mutating func replaceArgument(_ oldArg: String, ofInstructionAt indexOfInstruction: Int, withNewArgument newArg: String) {
        let instr_ = self.instrs[indexOfInstruction]
        switch instr_ {
        case .Label(_):
            break
        case .Instruction(let instr):
            self.instrs[indexOfInstruction] = InstructionOrLabel.Instruction(instr.replaceArg(oldArg, newArg))
            
        }
    }
    
    func isValidInstructionIndex(_ index: Int) -> Bool {
        return index >= 0 && index < self.instrs.count
    }
    
    // Returns a tuple indicating:
    // In the first coord, true if the 'dest' field of the instruction at the given index gets overwritten
    // later in the basic block.
    // That is: if any other instr between the given index and the end of the basic block,
    // has the same 'dest'.
    // In the second coord, the index of the (possible) overwritter instruction.
    func isInstructionOverwrittenLater(at indexOfInstruction: Int) -> (Bool, Int?) {
        assert(self.isValidInstructionIndex(indexOfInstruction))
        
        var isOverwritten: Bool = false
        var indexOfInstructionOverwriter: Int? = nil
        
        let varBeingAssignedAtGivenIndex: String?
        
        switch self.instrs[indexOfInstruction] {
        case .Label(_):
            varBeingAssignedAtGivenIndex = nil
        case .Instruction(let instr):
            varBeingAssignedAtGivenIndex = instr.dest
        }
        assert(varBeingAssignedAtGivenIndex != nil)
        
        for index in self.instrs.indices {
            if index > indexOfInstruction {
                let instr_ = self.instrs[index]
                switch instr_ {
                    case .Label(_):
                        break
                    case .Instruction(let instr):
                        if let destOfOtherInstr = instr.dest {
                            if destOfOtherInstr == varBeingAssignedAtGivenIndex {
                                isOverwritten = true
                                indexOfInstructionOverwriter = index
                                break
                            }
                        }
                    }
            }
        }
        return (isOverwritten, indexOfInstructionOverwriter)
    }
    
    mutating func replaceUsesOfVar(_ varToReplace: String, withNewVar newVar: String, untilIndex upperBoundIndex: Int) {
        for index in self.instrs.indices {
            
            if index >= upperBoundIndex { break }
            
            let instr_ = self.instrs[index]
            switch instr_ {
                case .Label(_):
                    break
                case .Instruction(var instr):
                    if let args = instr.args {
                        for arg in args {
                            if arg == varToReplace {
                                instr.args = instr.args!.map { $0 == varToReplace ? newVar : $0 }
                                self.instrs[index] = InstructionOrLabel.Instruction(instr)
                            }
                        }
                    }
                }
        }
    }
    
    mutating func replaceNameOfVarAssignedTo(ofInstructionAt indexOfInstruction: Int) -> String {
        let instr_ = self.instrs[indexOfInstruction]
        switch instr_ {
        case .Label(_):
            break
        case .Instruction(let instr):
            let newDest = "lvn.\(indexOfInstruction)"
            self.instrs[indexOfInstruction] = InstructionOrLabel.Instruction(instr.replaceDest(newDest))
            return newDest
        }
        
        return ""
    }
    
}


extension Function {
    
    mutating func localValueNumbering() {
        for indexBB in self.basicBlocks.indices {
            self.basicBlocks[indexBB].localValueNumbering()
        }
    }
    
}
