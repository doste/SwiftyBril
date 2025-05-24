//
//  main.swift
//  SwiftyBril
//
//  Created by Juan Ignacio  Bianchi on 20/05/2025.
//

import Foundation

func buildCfg(brilProgramAsJson: Data) {
    if let json = try? JSONSerialization.jsonObject(with: brilProgramAsJson, options: []) as? [String: Any] {
        if let cfg = Cfg(json: json) {
            
            for var fun in cfg.functions {
                fun.buildBasicBlocks()
                fun.buildSuccesorsMap()
                
                //fun.printSuccesorsMap()
                
                //fun.trivialDeadCodeElimination()
                //fun.dropKilledLocalDeadCodeElimination()
                
                //fun.generateDotForGraphViz()
                
                print(fun.toString())
                
                fun.localValueNumbering()
                
                print("After local value numbering:")
                print(fun.toString())
                
                fun.trivialDeadCodeElimination()
                print("After DCE:")
                print(fun.toString())
                
                
                //print("There are \(fun.basicBlocks.count) in total")
                //print("last one has \(fun.basicBlocks.last!.instrs.count)")
                
                //for basicBlock in fun.basicBlocks {
                //    print("Block with name \(basicBlock.name) has index : \(fun.basicBlocks.firstIndex(of: basicBlock)!)")
                //}
            }
        }
    }
}



func main() {
    var inputProgram: Data
    repeat {
        inputProgram = FileHandle.standardInput.availableData
        buildCfg(brilProgramAsJson: inputProgram)
    } while (inputProgram.count > 0)
    
}

main()
