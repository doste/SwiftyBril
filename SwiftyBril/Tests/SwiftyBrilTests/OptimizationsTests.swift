import Foundation
import Testing
import SwiftyBril


func buildTestingInfraForBrilPrograms() -> [BrilProgramToTest] {
    // First we obtain each bril program to test, as json.
    let fm = FileManager.default
    
    // The folder LVN has the files to test.
    // Each test case corresponds to three files: the .bril file, its corresponding .json file and the expected output from
    // applying the optimizations.
    let inputFolderPath = fm.currentDirectoryPath + "/Tests/FilesToTest/LVN/"
    
    var brilProgramsToTest: [BrilProgramToTest] = []

    do {
        let brilPrograms = try fm.contentsOfDirectory(at: URL(string: inputFolderPath)!, includingPropertiesForKeys: nil, options: [])

        for brilProgramAsJson in brilPrograms {
            if brilProgramAsJson.pathExtension == "json" {
                
                let brilProgram: BrilProgramToTest = .init(name: getFileName(from: brilProgramAsJson),
                                                           path: brilProgramAsJson,
                                                           outputToComparePath: getFilePathForOutputFileToCompare(from: brilProgramAsJson))
                brilProgramsToTest.append(brilProgram)
                
                //print("NAME: \(getFileName(from: brilProgramAsJson))")
                //print("PATH: \(brilProgramAsJson)")
                //print("OUT: \(getFilePathForOutputFileToCompare(from: brilProgramAsJson))")
            }
        }
    } catch {
        print(error)
    }
    
    return brilProgramsToTest
}

func testOptimizationsForSingleProgram(brilProgramToTest: BrilProgramToTest) -> Bool {
    
    let inputProgramPath = brilProgramToTest.path
    let inputProgram: Data? = openFile(filePath: inputProgramPath)
    
    if inputProgram == nil {
        return false
    }
    var cmdLineOptions: CommandLineOptions = .init()
    cmdLineOptions.applyDeadCodeElimination = true
    cmdLineOptions.applyLocalValueNumbering = true
    
    
    if let compiledProgram = compileBrilProgram(brilProgramAsJsonData: inputProgram!, options: cmdLineOptions) {

        let outputProgramToComparePath = brilProgramToTest.outputToComparePath
        let outputProgramToCompare: Data? = openFile(filePath: outputProgramToComparePath)
        
        if outputProgramToCompare == nil {
            return false
        }
        if let outputProgramToCompareAsString = String(data: outputProgramToCompare!, encoding: .utf8) {
            //print("compiledProgram: \(compiledProgram)")
            //print("outputProgramToCompareAsString: \(outputProgramToCompareAsString)")
            return compiledProgram == outputProgramToCompareAsString
        }
    }
    
    return false
}

// TODO:  fold-comparisons NOT WORKING

@Test func testOptimizations() {
    
    let brilProgramsToTest: [BrilProgramToTest] = buildTestingInfraForBrilPrograms()
    
    for brilProgramToTest in brilProgramsToTest {
        print("TESTING: \(brilProgramToTest.name)")
        //if brilProgramToTest.name == "nonlocal" {
            #expect(testOptimizationsForSingleProgram(brilProgramToTest: brilProgramToTest))
        //}
    }
    
}
