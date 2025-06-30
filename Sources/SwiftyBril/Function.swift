import Foundation

public enum Type {
    case Primitive(String)
    indirect case Parameterized(Type)
}

// I'd like for the field 'args' to keep maintain its insertion order, that's why I use a MapVector instead of a Swift's Dictionary.

public struct Function {
    let name: String
    let args: MapVector<String, Type>     // // An optional list of arguments, which consist of a name and a type. Missing args is the same as an empty list.
    let type: Type?                       // Optionally, the function’s return type, if any.

    // TODO: Should we delete this field and only have basicBlocks?
    let instrs: [InstructionOrLabel]      // A list of Label and Instruction objects.
    
    var basicBlocks: [BasicBlock]
}

extension Function {
    // Set the basicBlocks field of Function
    public mutating func buildBasicBlocks() {
        
        var currentBlock = BasicBlock(asPartOfFunction: self)

        for instr in self.instrs {
            switch instr {
                case .Instruction(let anActualInstr):
                    // We are looking at a instruction, so we add it to the basic block we are building.
                    currentBlock.appendInstruction(instr)

                    if anActualInstr.isTerminator() {
                        // We are done with this block.
                        self.appendBasicBlock(&currentBlock)
                        currentBlock.removeAllInstructions()    // Clean it for the next iteration, so currentBlock can be used to create a new one.
                    }

                // When we hit a Label, we want to end our current basic block. Just like the Terminator case *but* in the new one we will create
                // we want that new block to start with the Label we just hit.
                case .Label(_):
                    self.appendBasicBlock(&currentBlock)
                    currentBlock.removeAllInstructions()
                    currentBlock.appendInstruction(instr) // So the Label is included at the start of the next basic block.
            }
        }
        // Add the last block
        self.appendBasicBlock(&currentBlock)
        
    }
    
    
    func setNameToBasicBlock(basicBlock: inout BasicBlock) {
        var name =  String()
        if let firstInstr = basicBlock.firstInstruction() {
            switch firstInstr {
                case .Label(let label):
                    name = label
                case .Instruction(_):
                    name = "BB\(self.basicBlocks.count)"
            }
        }
        basicBlock.name = name
    }
    
    // Append a basicblock only if it's not emtpy
    mutating func appendBasicBlock(_ basicBlock: inout BasicBlock) {
        if !basicBlock.isEmpty() {
            self.setNameToBasicBlock(basicBlock: &basicBlock)
            self.basicBlocks.append(basicBlock)
        }
    }
    
    public func printSuccesorsMap() {
        print("Successors map:")
        for basicBlock in self.basicBlocks {
            if basicBlock.succesors.isEmpty {
                print("Block \(basicBlock.name) has no succesors.")
            } else {
                print("Block \(basicBlock.name) has \(basicBlock.succesors.count) succesors: ")
                for succesor in basicBlock.succesors {
                    print("\t\(succesor)")
                }
            }
        }
    }
    
    public mutating func buildSuccesorsMap() {
        
        for index in self.basicBlocks.indices {
            if let lastInstr = self.basicBlocks[index].lastInstruction() {
                switch lastInstr {
                    case .Instruction(let anActualInstr):
                        if anActualInstr.isJump() {            // Jump instructions have one label: the label to jump to.
                            assert(anActualInstr.labels != nil)
                            assert(anActualInstr.labels!.count == 1)
                            //print("Edge from Block to \(anActualInstr.labels![0])")
                            let succName = anActualInstr.labels![0]
                            self.basicBlocks[index].addSuccesor(withName: succName)
                        } else if anActualInstr.isBranch() {    // Conditional branchs have two labels: a true label and a false label. Transfer control to one of the two labels depending on the value of the variable argument.
                            assert(anActualInstr.labels != nil)
                            assert(anActualInstr.labels!.count == 2)
                        
                            let trueBranch = anActualInstr.labels![0]
                            self.basicBlocks[index].addSuccesor(withName: trueBranch)
                            let falseBranch = anActualInstr.labels![1]
                            self.basicBlocks[index].addSuccesor(withName: falseBranch)
                            
                        } else if anActualInstr.isRet() { // A Return instruction doesn't have labels to jump to.
                            print("nada")
                        } else {
                            // Finally, in the case that anActualInstr is not a terminator, its succesor will be just the following block (the one to which falls through)
                            
                            if index != self.basicBlocks.count - 1 {
                                let nextBB = self.basicBlocks[index + 1]
                                self.basicBlocks[index].addSuccesor(withName: nextBB.name)
                            }
                        }
                    case .Label(_):
                        break
                }
            }
        }
    }
    
    // To use with the command `| dot -Tpdf -o cfg.pdf`
    public func generateDotForGraphViz() {
        print("digraph main {")
        for basicBlock in self.basicBlocks {
            print(" \(basicBlock.name) [shape=rect] [label= \"\(basicBlock.name)\n")
            for instr: InstructionOrLabel in basicBlock.instrs {
                switch instr {
                    case .Instruction(let anActualInstr):
                        print(anActualInstr.toString())
                    case .Label(_):
                        //print(" \(label)\n")    No need to print it, the name of the block will already be the label itself.
                        break
                }
            }
            print(" \" ] ;")
            
            for succesor in basicBlock.succesors {
                print(" \(basicBlock.name) -> \(succesor);")
            }
        }
        print("}")
    }
    
    
    
    public func toString() -> String {
        var result: String = "@\(self.name)"
        
        if !self.args.isEmpty {
            result += "("
            
            for (i, (argName, argType)) in self.args.enumerated() {
                result += "\(argName):"
                
                switch argType {
                    case .Primitive(let primValue):
                        result += " \(primValue)"
                    case .Parameterized(let paramValue):
                        result += " \(paramValue)"   // TODO: fix this.
                }
                
                if i < self.args.count - 1 {
                    result += ", "
                }
            }
            result += ")"
        }
        result += " {\n"
        
        
        for basicBlock in self.basicBlocks {
            result += basicBlock.toString()
        }
        result += "}\n"
        return result
    }
    
    public func hasArguments() -> Bool {
        return self.args.count > 0
    }

}
