import Foundation


public struct CommandLineOptions {
    public var applyDeadCodeElimination: Bool = false
    public var applyLocalValueNumbering: Bool = false
    public var showDebugInfo: Bool = false
    public var generateDotFile: Bool = false
    public var printToStdOut: Bool = false
    
    public init() {}
}

func cmdOptionExists(_ option: String) -> Bool {
    return CommandLine.arguments.contains(option) || CommandLine.arguments.contains("-\(option)")
}

func parseCmdLineOptions(_ cmdLineArguments: [String]) -> CommandLineOptions {
    var options: CommandLineOptions = .init()
    
    if cmdOptionExists("--dce") {
        options.applyDeadCodeElimination = true
    }
    
    if cmdOptionExists("--lvn") {
        options.applyLocalValueNumbering = true
    }
    
    if cmdOptionExists("--debug") {
        options.showDebugInfo = true
    }
    
    if cmdOptionExists("--graph") {
        options.generateDotFile = true
    }
    
    if cmdOptionExists("--print") {
        options.printToStdOut = true
    }
    
    if cmdLineArguments.contains("-h") || cmdLineArguments.contains("--help") {
        printUsage()
        exit(0)
    }
    
    if (cmdOptionExists("--debug") && cmdOptionExists("--graph")) {
        print("Error: --debug and --graph options cannot be used together. Graphviz expects to read input from stdin.")
        exit(1)
    }
    
    return options
}



func printUsage() {
    print(
        """
        USAGE: swift run SwiftyBril [--dce] [--lvn] [--graph] [--debug] [--print] <bril_program_json>

        ARGUMENTS:
          <bril_program_json>   A path to a json file representing bril program.

        OPTIONS:
          --dce                 Apply Dead Code Elimination optimization pass.
          --lvn                 Apply Local Value Numbering optimization pass.
          --graph               Output GraphViz command to pipe like: ` | dot -Tpdf -o cfg.pdf`
          --debug               Show debug information (Note that --graph and --debug should never be used together).
          --print               Print to standard output the input bril program (transformed if optimizations were applied).
          -h, --help            Show help for this command.
        
        """
    )
}


// Returns the bril program potentially modified because of the optimizations.
public func compileBrilProgram(brilProgramAsJsonData: Data, options: CommandLineOptions) -> String? {
    
    var outputProgram: String? = nil
    
    if let brilProgramAsJson = try? JSONSerialization.jsonObject(with: brilProgramAsJsonData, options: []) as? [String: Any] {
        if let cfg = Cfg(json: brilProgramAsJson) {
            
            for var fun in cfg.functions {
                fun.buildBasicBlocks()
                fun.buildSuccesorsMap()
                
                if options.showDebugInfo {
                    fun.printSuccesorsMap()
                }
                
                //fun.trivialDeadCodeElimination()
                //fun.dropKilledLocalDeadCodeElimination()
                
                if options.showDebugInfo {
                    print(fun.toString())
                }
                
                if options.applyLocalValueNumbering {
                    fun.localValueNumbering(showingDebugInfo: options.showDebugInfo)
                    
                    if options.showDebugInfo {
                        print("After local value numbering:")
                        print(fun.toString())
                    }
                }
                
                fun.trivialDeadCodeElimination()
                if options.showDebugInfo {
                    print("After DCE:")
                    print(fun.toString())
                }
                
                if options.showDebugInfo {
                    print("There are \(fun.basicBlocks.count) in total")
                    
                    for basicBlock in fun.basicBlocks {
                        print("Block with name \(basicBlock.name) has index : \(fun.basicBlocks.firstIndex(of: basicBlock)!)")
                    }
                }
                
                if options.generateDotFile {
                    fun.generateDotForGraphViz()
                }
                
                if options.printToStdOut {
                    print(fun.toString())
                }
                
                outputProgram = fun.toString()
            }
        }
    }
    
    return outputProgram
}



func main() {
    var inputProgram: Data?
    
    
    if CommandLine.arguments.count >= 2 {
        if #available(macOS 13.0, *) {
            inputProgram = openFile(filePath: URL(filePath: CommandLine.arguments.last!))
            
            let cmdLineOptions = parseCmdLineOptions(CommandLine.arguments)
            
            if let inputProgram = inputProgram {
                _ = compileBrilProgram(brilProgramAsJsonData: inputProgram, options: cmdLineOptions)
            } else {
                print("Could not open bril program file")
            }
        }
    } else {
        print("Error: Please provide a bril program.")
        printUsage()
    }

    /*
    Uncomment to use if we want to input the program by redirecting it with '<', just like the CS6120 code expects it.
    repeat {
        inputProgram = FileHandle.standardInput.availableData
        compileBrilProgram(brilProgramAsJson: inputProgram)
    } while (inputProgram.count > 0)
    */
    
}

main()
