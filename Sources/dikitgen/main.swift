import Foundation
import DIGenKit

enum Mode {
    case version
    case generate(path: String, outputPath: String, excluding: [String])
}
struct InvalidArgumentsError: Error {}
func mode(from arguments: [String]) throws -> Mode {
    switch arguments.count {
    case 2 where arguments[1] == "--version":
        return .version
    case 3:
        return .generate(path: arguments[1], outputPath: arguments[2], excluding: [])
    case 4..<Int.max:
        let path = arguments[1]
        let outputPath = arguments[2]
        var exclusions: [String] = []

        var options = arguments.suffix(from: 3).map { $0 }
        while options.count >= 2 {
            let key = options[0]
            let value = options[1]
            switch key {
            case "--exclude": exclusions.append(value)
            case _: throw InvalidArgumentsError()
            }
            options.removeFirst(2)
        }
        if !options.isEmpty {
            throw InvalidArgumentsError()
        }
        return .generate(path: path, outputPath: outputPath, excluding: exclusions)
    case _:
        throw InvalidArgumentsError()
    }
}

let path: String
let outputPath: String
let exclusions: [String]
do {
    switch try mode(from: CommandLine.arguments) {
    case .version:
        print(Version.current)
        exit(0)
    case .generate(let p, let op, let xs):
        path = p
        outputPath = op
        exclusions = xs
    }
} catch {
    print("error: invalid arguments", to: &standardError)
    print("usage: dikitgen <path to source code directory> <output file path> [[--exclude <subpath>] ...]", to: &standardError)
    exit(1)
}

do {
    let generator = try CodeGenerator(path: path, excluding: exclusions)
    let generatedCode = try generator.generate()
    try generatedCode.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
} catch let anyError {
    guard
        let error = anyError as? (Error & Findable),
        let path = error.file.path else {
        print("error: \(anyError.localizedDescription)", to: &standardError)
        exit(1)
    }

    var lineNumber = 1
    for line in error.file.lines {
        if line.range.contains(Int(error.offset)) {
            break
        }
        lineNumber += 1
    }

    print("\(path):\(lineNumber): error: \(error.localizedDescription)", to: &standardError)
    exit(1)
}
