//
//  DCE.swift
//  SwiftyBril
//
//  Created by Juan Ignacio  Bianchi on 20/05/2025.
//

import Foundation

// TODO: It would be nice if the optimization passes would not be extensions, but rather their own structs that manipulate
// the different IR objects.

extension Function {
    
    
    public mutating func trivialDeadCodeElimination() {
        // Iteratively remove dead instructions, stopping when nothing remains to remove.
        while self.trivialDCEPass() {}
    }
    
    // Remove instructions from this function that are never used as arguments to any other instruction.
    // Return a bool indicating whether we deleted anything.
    public mutating func trivialDCEPass() -> Bool {
        
        var usedInstructions = Set<String>()    // Set of the names of the variables.
        
        var programHasChanged: Bool = false
        
        // Find all the variables used as an argument to any instruction, even once.
        for indexBB in self.basicBlocks.indices {
            for instr in self.basicBlocks[indexBB].instrs {
                switch instr {
                case .Instruction(let anActualInstr):
                    if let args = anActualInstr.args {
                        for arg in args {
                            usedInstructions.insert(arg)
                        }
                    }
                default:
                    break
                }
            }
        }
        
        
        var indicesOfInstructionsToDelete : [(Int, Int)] = []    // First index into Block, second into Instructions.
        
        // Delete the instructions that write to unused variables.
        for indexBB in self.basicBlocks.indices {
            for indexInstr in self.basicBlocks[indexBB].instrs.indices {
                let instr = self.basicBlocks[indexBB].instrs[indexInstr]
                switch instr {
                case .Instruction(let anActualInstr):
                    if let assignedTo = anActualInstr.dest {
                        if !usedInstructions.contains(assignedTo) {
                            // Delele instr
                            indicesOfInstructionsToDelete.append((indexBB, indexInstr))
                        }
                    }
                default:
                    break
                }
            }
            
            for indexToDelete in indicesOfInstructionsToDelete.reversed() {
                self.basicBlocks[indexToDelete.0].instrs.remove(at: indexToDelete.1)
                programHasChanged = true
            }
        }
        
        return programHasChanged
    }
    
    
    
    
    // Delete instructions in a single block whose result is unused before the next assignment.
    // Return a bool indicating whether anything changed.
    public mutating func dropKilledLocalDeadCodeElimination() {
        // Drop killed functions from *all* blocks.
        for index in self.basicBlocks.indices {
            while self.basicBlocks[index].dropKilledLocalDeadCodeElimination() {}
        }
    }
    
}

extension BasicBlock {
    
    // We will keep track of those variables that are assigned to, but not used. Those will be the candidates to delete.
    // We will keep the variables that were assigned to, but not used in this block. Because maybe is used in some succesor block.
    mutating func dropKilledLocalDeadCodeElimination() -> Bool {
        var programHasChanged: Bool = false
        
        // A map from variable names to the last place they were assigned since the last use. These are candidates for deletion---if a
        // variable is assigned while in this map, we'll delete what the maps point to.
        var lastDef = [String : (Instruction, Int)]()     // Mapping to keep track of defined variables *not* used yet.
                                                    //The second element of the tuple is to indicate the index of the instruction in the
                                                    // self.instrs array.
        var indicesOfInstructionsToDelete : [Int] = []
        
        for index in self.instrs.indices {
            let instr_ = self.instrs[index]
            switch instr_ {
            case .Label(_):
                break
            case .Instruction(let instr):
                
                // Check for uses
                if let instr_args = instr.args {             // Check if the instr has arguments, if it does we remove them from the last_def map
                    for arg in instr_args {                  // lastDef indicates which variables are defined but not yet used.
                        if lastDef[arg] != nil {             // So when we come across an instruction that does use them (it has them as arguments),
                            lastDef.removeValue(forKey: arg)   // we remove them
                        }
                    }
                }
                
                // Check for defs
                if let varBeingAssignedTo = instr.dest {
                    if lastDef.contains(where: { $0.key == varBeingAssignedTo }) {  // If the instr is in the lastDef map, then we are reassigning                                                                  it, so the previous assignment can be deleted.
                        
                        // Delele instr:
                        indicesOfInstructionsToDelete.append(lastDef[varBeingAssignedTo]!.1) // .1 because the index is given by the second element of the pair
                    }
                    
                    lastDef[varBeingAssignedTo] = (instr, index)        // Independently if we remove it or not, now we know the last definition of this instr, so we update lastDef accordingly
                }
            }
        }
        
        for indexToDelete in indicesOfInstructionsToDelete.reversed() {
            self.instrs.remove(at: indexToDelete)
            programHasChanged = true
        }
        
        
        return programHasChanged
    }
}
