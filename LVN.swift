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
    
    public func tableIndex(of value: Value) -> IndexIntoTable? {
        if value.op == "id" {
            assert(value.args != nil)
            assert(value.args!.count == 1)
            if let val = self.tableEntryAt(index: value.args![0])?.key {
                return self.table.index(of: val)
            }
        }
        return self.table.index(of: value)
    }
    
    // If we have a Value like ( id #0 ) this would return directly #0
    // If not, it would just return the corresponding index into the table.
    public func lookUpInVar2num(_ varName: VariableName, beingIdInstr: Bool = false) -> IndexIntoTable? {
        return self.var2num[varName]
    }
    
    public func lookupInTable(_ value: Value) -> CanonicalHomeForVariable? {
        if value.op == "id" {
            assert(value.args != nil)
            assert(value.args!.count == 1)
            return self.tableEntryAt(index: value.args![0])?.value
        }
        return self.table[value]
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
                debugStr += " "
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
    
    func canonicalizeValue(_ value: Value) -> Value {
        if value.op == "add" || value.op == "mul" {
            assert(value.args != nil)
            assert(value.args!.count == 2)
            var sortedArgs = value.args!
            sortedArgs.sort()
            return Value(op: value.op, args: sortedArgs)
        }
        return value
    }
    

    
    mutating func localValueNumbering() {
        
        var lvn = LVNContext()
        
        // Build the LVN table:
        
        // If the function has arguments, we first put those in the table.
        if self.function.hasArguments() {
            for (i, (argName, _)) in self.function.args.enumerated() {
                let value = Value(op: "FuncArg", args: [i])
                lvn.table[value] = argName
                lvn.var2num[argName] = lvn.table.index(of: value)
            }
        }
        
        
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
                    if let constValue = instr.value {
                        switch constValue {
                            case .bool(let booleanValue):
                                if let booleanValue = booleanValue {
                                    valueArgs.append(booleanValue ? 1 : 0)
                                }
                            case .int(let intValue):
                                valueArgs.append(intValue!)
                        }
                    }
                } else {
                    if let args = instr.args {
                        for arg in args {
                            // We want instructions in the LVN table to have as arguments numbers
                            // referencing other rows of the table.
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
                
                var value: Value
                // TODO: Fix this. The handling of arguments that reside outside of this basic block.
                
                var args = [Int]()
                if !valueArgsDefinedOutsideOfBlock.isEmpty {
                    for (idx, argDefinedOutside) in valueArgsDefinedOutsideOfBlock.enumerated() {
                        value = Value(op: "OutsideBlock", args: [idx])
                        args.append(idx)
                        lvn.table[value] = argDefinedOutside
                        lvn.var2num[argDefinedOutside] = lvn.table.index(of: value)
                    }
                }
                    
                if !valueArgsDefinedOutsideOfBlock.isEmpty {
                    value = Value(op: instr.op, args: args)
                } else {
                    value = Value(op: instr.op, args: valueArgs)
                }
                    
                
                    
                value = self.canonicalizeValue(value)
                
                
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
                        
                        value = Value(op: "OutsideBlock", args: [0])
                        
                    }
                }
                
                // If the instr is some kind of an assignment.
                if var varAssignedTo = instr.dest {
                    var indexInTableForVar: Int? = nil
                    
                    // Independently if the value is in the table or not, we need to modify the variable names
                    // if they are cobbled later in the block.
                    let isInstructionOverwritten = self.isInstructionOverwrittenLater(at: index)
                    // .0 is the boolean result, and .1 is the index of the (possible) "cobblerer".
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
                    if lvn.lookupInTable(value) != nil {
                        
                        indexInTableForVar = lvn.tableIndex(of: value)
                        
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
                                    // If arg == newArg, that will be handled by the Instruction's method replaceArg,
                                    // it will just return the given instruction.
                                    
                                    // There is a special case:
                                    
                                    //      y: int = id x;
                                    //      x: int = add x x;
                                    //      print y;
                                    // LVN TABLE:
                                    // | #0     |  VAL: ( OutsideBlock #0 )  |  VAR: x |
                                    // | #1     |  VAL: ( add #0 #0 )        |  VAR: x |
                                    // LVN var2num:
                                    //  | y: #0
                                    //  | x: #1
                                    
                                    // If between the 'arg' definition (assignment) and the this use (instr given by 'index'),
                                    // 'newArg' was overwritten, then don't replace 'arg'.
                                    
                                    if let indexWhereArgIsDefined = self.getIndexOfInstructionWhereVariableIsDefined(arg, &lvn) {
                                        let isInstructionOverwritten = self.isVariableEverOverwritten(varName: newArg, betweenStartIndex: indexWhereArgIsDefined, andUntilIndex: index, &lvn)
                                        if !isInstructionOverwritten.0 {
                                            self.replaceArgument(arg, ofInstructionAt: index, withNewArgument: newArg)
                                        }
                                    }
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
                                        self.replaceInstr(at: index, toConstValue: IntOrBoolean.int(value.args![0]))
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
            if let X = lvn.var2num[arg] {
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
    
    // TODO: Fix this v ^ . It's the same code!
    
    // Given an instruction, if its arguments are constants, return those constants.
    func constantsOfInstruction(_ instr: Instruction, _ lvn: LVNContext) -> [Int] {
        var constants: [Int] = []
        
        for instrArg in instr.args ?? [] {
            // First get the table entry corresponding to the (only) argument of the instruction.
            if let tableEntryIndex = lvn.var2num[instrArg] {
                // Get the canonical home for that argument.
                if let canonicalHomeForArgOfIdInstr = (lvn.tableEntryAt(index: tableEntryIndex)?.value) {
                    // Once with the canonical home we access the var2num again to obtain the Value from the canonical home (from the table)
                    if let value = lvn.valueFrom(canonicalHome: canonicalHomeForArgOfIdInstr) {
                        if value.op == "const" {
                            assert(value.args != nil)
                            assert(value.args!.count == 1)
                            constants.append(Int(exactly: value.args![0])!)
                        }
                    }
                }
            }
            
        }
        return constants
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
                self.replaceInstr(at: indexOfInstr, toConstValue: IntOrBoolean.int(resultOfAddingConstants))
                // Not only replace the actual instruction in the block, but also update the LVN table:
                lvn.updateInstruction(atIndexInTable: indexOfInstr, withNewValue: Value(op: "const", args: [resultOfAddingConstants]))
                return true
        }
        return false
    }
    
    
    // Handle the trivial case where the arguments of the comparison instruction are the same.
    // eq       X X => true
    // {gt, lt} X X => false
    // {ge, le} X X => true
    mutating func constantFoldingComparisonInstruction(indexOfInstr: Int, comparisonOp: String, _ lvn: inout LVNContext) -> Bool {
        
        let instr_ = self.instrs[indexOfInstr]
        switch instr_ {
        case .Label(_):
            break
        case .Instruction(let instr):
            var constantArgs = [Int]()
            var functionArgs = [Int]()
            
            for arg in instr.args ?? []  {
                // We need to access the constant value of each. To do that, we use the LVN table.
                
                if let indexOfVarInTable = lvn.var2num[arg] {
                    
                    if let tableEntry = lvn.tableEntryAt(index: indexOfVarInTable) {
                        
                        let valueOfArg = tableEntry.key
                        
                        assert(valueOfArg.op == "const" || valueOfArg.op == "FuncArg")
                        assert(valueOfArg.args != nil)
                        assert(valueOfArg.args!.count >= 1)
                        if valueOfArg.op == "const" {
                            for arg_ in valueOfArg.args! {
                                constantArgs.append(arg_)
                            }
                        } else {
                            for arg_ in valueOfArg.args! {
                                functionArgs.append(arg_)
                            }
                        }
                    }
                }
            }
            
            // Two possibilites for constants to be folded, in a comparison operation:
            //  1) The two arguments being constants defined elsewhere with the `: const` op
            //  2) The two arguments being part of the function arguments, in that case
            assert((constantArgs.count == 2 && functionArgs.count == 0 ) || (functionArgs.count == 2 && constantArgs.count == 0))
            
            let resultOfComparingConstants: Bool
            
            assert(["eq", "lt", "le", "gt", "ge"].contains(comparisonOp))
            
            
            if !functionArgs.isEmpty {
                // If the args are equal...
                if functionArgs[0] == functionArgs[1] { // ...the result can be computed statically.
                    if comparisonOp == "gt" || comparisonOp == "lt" {
                        //resultOfComparingConstants = false    NOT SURE WHY, but the expected output from the tests from the CS6120 expects this case to not be 'foldable'.
                        return false
                    } else {
                        resultOfComparingConstants = true
                    }
                } else { // If the args are not equal and they are from the functions arguments, then there is not constant folding to be done here.
                    return false
                }
            } else { // Then they are constants arguments
            
                // If the args are equal...
                if constantArgs[0] == constantArgs[1] {  // ...the result can be computed statically.
                    if comparisonOp == "gt" || comparisonOp == "lt" {
                        resultOfComparingConstants = false
                    } else {
                        resultOfComparingConstants = true
                    }
                } else { // Args are not equal, so we need to compute result, *but* only if the args are constant.
                    let comparisonOperations: [String : (Int, Int) -> Bool] = [
                                                                                "eq" : { $0 == $1 },
                                                                                "lt" : { $0 < $1  },
                                                                                "le" : { $0 <= $1 },
                                                                                "gt" : { $0 > $1  },
                                                                                "ge" : { $0 >= $1 }]
                    let compInstr = comparisonOperations[comparisonOp]!
                    resultOfComparingConstants = compInstr(constantArgs[0], constantArgs[1])
                }
            
                }
                self.replaceInstr(at: indexOfInstr, toConstValue: IntOrBoolean.bool(resultOfComparingConstants))
            
                // Not only replace the actual instruction in the block, but also update the LVN table:
        
                let indexOfInstrInTable = indexOfInstr + 2; // TODO: Fix this! That + 2 should be + func.numberOfArguments
                lvn.updateInstruction(atIndexInTable: indexOfInstrInTable, withNewValue: Value(op: "const", args: [resultOfComparingConstants ? 1 : 0]))
                return true
        }
        return false
    }
    

    
    func isSafeToDivide(_ instr: Instruction, _ lvn: LVNContext) -> Bool {
        assert(instr.op == "div")
        assert(instr.args != nil)
        assert(instr.args!.count == 2)
        
        let constantsOfInstruction = self.constantsOfInstruction(instr, lvn)
        assert(constantsOfInstruction.count == 2)
        return constantsOfInstruction[1] != 0
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
                            if !self.isSafeToDivide(instr, lvn) {
                                break
                            }
                            programChanged = programChanged || self.constantFoldingArithmeticInstruction(indexOfInstr: index, arithmeticOp: /, &lvn)
                        }
                    }
                }
                
                if instr.isComparisonOp() {
                    // instr.op will be one of ["eq", "lt", "le", "gt", "ge"]
                    programChanged = programChanged || self.constantFoldingComparisonInstruction(indexOfInstr: index, comparisonOp: instr.op, &lvn)
                }
            }
    }
        
        return programChanged
    }
    
    mutating func constantFolding(_ lvn: inout LVNContext) {
        while self.constantFoldingPass(&lvn) {}
    }
    
    mutating func replaceInstr(at indexOfInstruction: Int, toConstValue: IntOrBoolean) {
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
    
    func isValidVariableName(_ varName: String, _ lvn: inout LVNContext) -> Bool {
        return lvn.var2num.keys.contains(varName)
    }
    
    func getIndexOfInstructionWhereVariableIsDefined(_ varName: String, _ lvn: inout LVNContext) -> Int? {
        assert(self.isValidVariableName(varName, &lvn))
        
        var indexToVarDef: Int? = nil
        
        for index in self.instrs.indices {
            let instr_ = self.instrs[index]
            switch instr_ {
                case .Label(_):
                    break
                case .Instruction(let instr):
                    if instr.dest == varName {
                        indexToVarDef = index
                    }
            }
        }
        return indexToVarDef
    }
    
    // Returns true if the given variable is overwritten between the given indices.
    func isVariableEverOverwritten(varName: String, betweenStartIndex startIndex: Int, andUntilIndex untilIndex: Int, _ lvn: inout LVNContext) -> (Bool, Int?) {
        assert(self.isValidInstructionIndex(startIndex))
        assert(self.isValidInstructionIndex(untilIndex))
        assert(self.isValidVariableName(varName, &lvn))
        
        var isOverwritten: Bool = false
        var indexOfInstructionOverwriter: Int? = nil
        
        for index in self.instrs.indices {
            if index >= startIndex && index <= untilIndex {
                let instr_ = self.instrs[index]
                switch instr_ {
                    case .Label(_):
                        break
                    case .Instruction(let instr):
                        if let destOfOtherInstr = instr.dest {
                            if destOfOtherInstr == varName {
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
    
    func isInstructionOverwrittenLater2(at indexOfInstruction: Int, _ lvn: inout LVNContext) -> (Bool, Int?) {
        assert(self.isValidInstructionIndex(indexOfInstruction))
        
        let varBeingAssignedAtGivenIndex: String?
        
        switch self.instrs[indexOfInstruction] {
            case .Label(_):
                varBeingAssignedAtGivenIndex = nil
            case .Instruction(let instr):
                varBeingAssignedAtGivenIndex = instr.dest
        }
        assert(varBeingAssignedAtGivenIndex != nil)
        assert(!self.instrs.indices.isEmpty)
        
        return self.isVariableEverOverwritten(varName: varBeingAssignedAtGivenIndex!, betweenStartIndex: indexOfInstruction, andUntilIndex: self.instrs.indices.last!, &lvn)
    }
    
    // TODO: Make sure we can replace isInstructionOverwrittenLater with isInstructionOverwrittenLater2
    
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
            print("Calling localValueNumbering from Block \(indexBB)")
            self.basicBlocks[indexBB].localValueNumbering()
        }
    }
    
}
