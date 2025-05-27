//
//  Cfg.swift
//  SwiftyBril
//
//  Created by Juan Ignacio  Bianchi on 20/05/2025.
//

import Foundation

public struct Cfg {
    var functions: [Function]
}

extension Cfg {
    init?(json: [String: Any]) {
        self.functions = [Function]()

        if let functions_json = json["functions"] as? [[String : Any]] {
            for function_json in functions_json {

                var function_name = ""

                if let func_name_json = function_json["name"] as? String {
                    function_name = func_name_json
                }
                
                // TODO: Handle (return) type of function.
                
                var arguments = MapVector<String, Type>()
                
                if let func_args_json = function_json["args"] as? [[String : Any]] {
                    //print("Args: \(func_args_json)")
                    for arg_json in func_args_json {
                        if let arg_name = arg_json["name"] as? String {
                            //print("Arg: \(arg_name)")
                            if let arg_type = arg_json["type"] as? String {
                                //print("Type: \(arg_type)")
                                arguments[arg_name] = Type.Primitive(arg_type)
                            }
                        }
                    }
                }

                var instructions = [InstructionOrLabel]()

                if let instrs_json = function_json["instrs"] as? [[String : Any]] {
                    for instr_json in instrs_json {

                        var instr: InstructionOrLabel

                        // instr is either a Label or a Instruction.

                        if let label = instr_json["label"] as? String {
                            //print("Label: \(label)")
                            instr = InstructionOrLabel.Label(label)
                        } else {
                            guard let op = instr_json["op"] as? String,
                                let dest = instr_json["dest"] as? String?,
                                let type = instr_json["type"] as? String?,
                                let value = instr_json["value"] as? Int?,
                                let args = instr_json["args"] as? [String]?,
                                let funcs = instr_json["funcs"] as? [String]?,
                                let labels = instr_json["labels"] as? [String]?
                            else {
                                return nil
                            }
                            let actualInstr = Instruction(op: op, dest: dest, type: type, args: args, funcs: funcs, labels: labels, value: IntOrBoolean.int(value))
                            instr = InstructionOrLabel.Instruction(actualInstr)
                        }
                        
                        instructions.append(instr)
                    }
                }
                let function = Function(name: function_name, args: arguments, type: nil, instrs: instructions, basicBlocks: [BasicBlock]())
                self.functions.append(function)
            }
        }
    }
}
