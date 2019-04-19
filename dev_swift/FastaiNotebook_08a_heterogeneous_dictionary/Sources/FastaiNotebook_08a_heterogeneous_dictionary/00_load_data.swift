/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: 00_load_data.ipynb

*/
        
import Foundation
import Just
import Path

@discardableResult
public func shellCommand(_ launchPath: String, _ arguments: [String]) -> String?
{
    let task = Process()
    task.executableURL = URL(fileURLWithPath:launchPath)
    task.arguments = arguments

    let pipe = Pipe()
    task.standardOutput = pipe
    do {try task.run()} catch {print("Unexpected error: \(error).")}

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: String.Encoding.utf8)

    return output
}

public func downloadFile(_ url: String, dest: String?=nil, force: Bool=false){
    let dest_name = (dest ?? (Path.cwd/url.split(separator: "/").last!).string)
    let url_dest = URL(fileURLWithPath: (dest ?? (Path.cwd/url.split(separator: "/").last!).string))
    if (force || !Path(dest_name)!.exists){
        print("Downloading \(url)...")
        if let cts = Just.get(url).content{
            do    {try cts.write(to: URL(fileURLWithPath:dest_name))}
            catch {print("Can't write to \(url_dest).\n\(error)")}
        } else {print("Can't reach \(url)")}
    }
}

import TensorFlow

protocol ConvertableFromByte {
    init(_ d:UInt8)
}

extension Float : ConvertableFromByte{}
extension Int : ConvertableFromByte{}
extension Int32 : ConvertableFromByte{}

func loadMNIST<T:ConvertableFromByte & TensorFlowScalar>(training: Bool, labels: Bool, path: Path, flat: Bool) -> Tensor<T> {
    let split = training ? "train" : "t10k"
    let kind = labels ? "labels" : "images"
    let batch = training ? 60000 : 10000
    let shape: TensorShape = labels ? [batch] : (flat ? [batch, 784] : [batch, 28, 28])
    let dropK = labels ? 8 : 16
    let baseUrl = "https://storage.googleapis.com/cvdf-datasets/mnist/"
    let fname = split + "-" + kind + "-idx\(labels ? 1 : 3)-ubyte"
    let file = path/fname
    if !file.exists {
        downloadFile("\(baseUrl)\(fname).gz", dest:(path/"\(fname).gz").string)
        shellCommand("/bin/gunzip", ["-fq", (path/"\(fname).gz").string])
    }
    let data = try! Data(contentsOf: URL(fileURLWithPath: file.string)).dropFirst(dropK)
    if labels { return Tensor(data.map(T.init)) }
    else      { return Tensor(data.map(T.init)).reshaped(to: shape)}
}

public func loadMNIST(path:Path, flat:Bool = false) -> (Tensor<Float>, Tensor<Int32>, Tensor<Float>, Tensor<Int32>) {
    try! path.mkdir(.p)
    return (
        loadMNIST(training: true,  labels: false, path: path, flat: flat) / 255.0,
        loadMNIST(training: true,  labels: true,  path: path, flat: flat),
        loadMNIST(training: false, labels: false, path: path, flat: flat) / 255.0,
        loadMNIST(training: false, labels: true,  path: path, flat: flat)
    )
}

public let mnistPath = Path.home/".fastai"/"data"/"mnist_tst"

import Dispatch
public func time(repeating: Int=1, _ function: () -> ()) {
    if repeating > 1 { function() }
    var times = [Double]()
    for _ in 1...repeating{
        let start = DispatchTime.now()
        function()
        let end = DispatchTime.now()
        let nanoseconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
        let milliseconds = nanoseconds / 1e6
        times.append(milliseconds)
    }
    print("\(times.reduce(0.0, +)/Double(times.count)) ms")
}

public extension String {
    func findFirst(pat:String) -> Range<String.Index>? {
        return range(of: pat, options: .regularExpression)
    }
    func matches(pat: String) -> Bool {
        return findFirst(pat:pat) != nil
    }
}

public func notebookToScript(fname: String){
    let url_fname = URL(fileURLWithPath: fname)
    let last = fname.lastPathComponent
    let out_fname = (url_fname.deletingLastPathComponent().appendingPathComponent("FastaiNotebooks", isDirectory: true)
                     .appendingPathComponent("Sources", isDirectory: true)
                     .appendingPathComponent("FastaiNotebooks", isDirectory: true).appendingPathComponent(last)
                     .deletingPathExtension().appendingPathExtension("swift"))
    do{
        let data = try Data(contentsOf: url_fname)
        let jsonData = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: Any]
        let cells = jsonData["cells"] as! [[String:Any]]
        var module = """
/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: \(fname.lastPathComponent)

*/
        
"""
        for cell in cells{
            if let source = cell["source"] as? [String], !source.isEmpty, 
            source[0].matches(pat: #"^\s*//\s*export\s*$"#) {
                module.append("\n" + source[1...].joined() + "\n")
            }
        }
        try? module.write(to: out_fname, atomically: false, encoding: .utf8)
    } catch {print("Can't read the content of \(fname)")}
}

public func exportNotebooks(_ path: Path){
    for entry in try! path.ls() where entry.kind == Entry.Kind.file && 
        entry.path.basename().matches(pat: #"^\d*_.*ipynb$"#) {
        print("Converting \(entry.path.basename())")
        notebookToScript(fname: entry.path.basename())
    }
}
