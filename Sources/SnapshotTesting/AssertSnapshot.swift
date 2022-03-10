import XCTest

/// Enhances failure messages with a command line diff tool expression that can be copied and pasted into a terminal.
///
///     diffTool = "ksdiff"
public var diffTool: String? = nil

/// Whether or not to record all new references.
public var isRecording = false

/// Whether or not to record all new references.
/// Due to a name clash in Xcode 12, this has been renamed to `isRecording`.
@available(*, deprecated, renamed: "isRecording")
public var record: Bool {
  get { isRecording }
  set { isRecording = newValue }
}

/// Asserts that a given value matches a reference on disk.
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - snapshotting: A strategy for serializing, deserializing, and comparing values.
///   - name: An optional description of the snapshot.
///   - recording: Whether or not to record a new reference.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertSnapshot<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as snapshotting: Snapshotting<Value, Format>,
  named name: String? = nil,
  record recording: Bool = false,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  ) {

  let failure = verifySnapshot(
    matching: try value(),
    as: snapshotting,
    named: name,
    record: recording,
    timeout: timeout,
    file: file,
    testName: testName,
    line: line
  )
  guard let message = failure else { return }
  XCTFail(message, file: file, line: line)
}

/// Asserts that a given value matches references on disk.
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - strategies: A dictionary of names and strategies for serializing, deserializing, and comparing values.
///   - recording: Whether or not to record a new reference.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertSnapshots<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as strategies: [String: Snapshotting<Value, Format>],
  record recording: Bool = false,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  ) {

  try? strategies.forEach { name, strategy in
    assertSnapshot(
      matching: try value(),
      as: strategy,
      named: name,
      record: recording,
      timeout: timeout,
      file: file,
      testName: testName,
      line: line
    )
  }
}

/// Asserts that a given value matches references on disk.
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - strategies: An array of strategies for serializing, deserializing, and comparing values.
///   - recording: Whether or not to record a new reference.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertSnapshots<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as strategies: [Snapshotting<Value, Format>],
  record recording: Bool = false,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  ) {

  try? strategies.forEach { strategy in
    assertSnapshot(
      matching: try value(),
      as: strategy,
      record: recording,
      timeout: timeout,
      file: file,
      testName: testName,
      line: line
    )
  }
}

/// Verifies that a given value matches a reference on disk.
///
/// Third party snapshot assert helpers can be built on top of this function. Simply invoke `verifySnapshot` with your own arguments, and then invoke `XCTFail` with the string returned if it is non-`nil`. For example, if you want the snapshot directory to be determined by an environment variable, you can create your own assert helper like so:
///
///     public func myAssertSnapshot<Value, Format>(
///       matching value: @autoclosure () throws -> Value,
///       as snapshotting: Snapshotting<Value, Format>,
///       named name: String? = nil,
///       record recording: Bool = false,
///       timeout: TimeInterval = 5,
///       file: StaticString = #file,
///       testName: String = #function,
///       line: UInt = #line
///       ) {
///
///         let snapshotDirectory = ProcessInfo.processInfo.environment["SNAPSHOT_REFERENCE_DIR"]! + "/" + #file
///         let failure = verifySnapshot(
///           matching: value,
///           as: snapshotting,
///           named: name,
///           record: recording,
///           snapshotDirectory: snapshotDirectory,
///           timeout: timeout,
///           file: file,
///           testName: testName
///         )
///         guard let message = failure else { return }
///         XCTFail(message, file: file, line: line)
///     }
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - snapshotting: A strategy for serializing, deserializing, and comparing values.
///   - name: An optional description of the snapshot.
///   - recording: Whether or not to record a new reference.
///   - snapshotDirectory: Optional directory to save snapshots. By default snapshots will be saved in a directory with the same name as the test file, and that directory will sit inside a directory `__Snapshots__` that sits next to your test file.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
/// - Returns: A failure message or, if the value matches, nil.
public func verifySnapshot<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as snapshotting: Snapshotting<Value, Format>,
  named name: String? = nil,
  record recording: Bool = false,
  snapshotDirectory: String? = nil,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  )
  -> String? {

    CleanCounterBetweenTestCases.registerIfNeeded()
    let recording = recording || isRecording

    do {
      var fileUrl = URL(fileURLWithPath: "\(file)", isDirectory: false)
      let fileName = fileUrl.deletingPathExtension().lastPathComponent
      let sanitizedFileName = sanitizePathComponent(fileName)
      let fileNamePrefix = sanitizedFileName.prefix(1).lowercased() + sanitizedFileName.dropFirst()

      while(fileUrl.lastPathComponent != "PACEDriveSnapshotTests") {
        fileUrl = fileUrl.deletingLastPathComponent()
      }

      let projectDirectoryUrl = snapshotDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? fileUrl

      let snapshotReferencesUrl = projectDirectoryUrl.appendingPathComponent("SnapshotReferences")
      let snapshotTargetsUrl = projectDirectoryUrl.appendingPathComponent("SnapshotTargets")
      let snapshotAdditionsUrl = projectDirectoryUrl.appendingPathComponent("SnapshotAdditions")
      let snapshotChangesUrl = projectDirectoryUrl.appendingPathComponent("SnapshotChanges")
      let snapshotDifferencesUrl = projectDirectoryUrl.appendingPathComponent("SnapshotDifferences")

      let identifier: String
      if let name = name {
        identifier = sanitizePathComponent(name)
      } else {
        let counter = counterQueue.sync { () -> Int in
          let key = snapshotReferencesUrl.appendingPathComponent(testName)
          counterMap[key, default: 0] += 1
          return counterMap[key]!
        }
        identifier = String(counter)
      }

      let testName = sanitizePathComponent(testName)
      let snapshotFileName = "\(fileNamePrefix).\(testName).\(identifier)"

      let fileManager = FileManager.default
      try fileManager.createDirectory(at: snapshotReferencesUrl, withIntermediateDirectories: true)

      let tookSnapshot = XCTestExpectation(description: "Took snapshot")
      var optionalDiffable: Format?
      snapshotting.snapshot(try value()).run { b in
        optionalDiffable = b
        tookSnapshot.fulfill()
      }
      let result = XCTWaiter.wait(for: [tookSnapshot], timeout: timeout)
      switch result {
      case .completed:
        break
      case .timedOut:
        return """
          Exceeded timeout of \(timeout) seconds waiting for snapshot.

          This can happen when an asynchronously rendered view (like a web view) has not loaded. \
          Ensure that every subview of the view hierarchy has loaded to avoid timeouts, or, if a \
          timeout is unavoidable, consider setting the "timeout" parameter of "assertSnapshot" to \
          a higher value.
          """
      case .incorrectOrder, .invertedFulfillment, .interrupted:
        return "Couldn't snapshot value"
      @unknown default:
        return "Couldn't snapshot value"
      }

      guard var diffable = optionalDiffable else {
        return "Couldn't snapshot value"
      }

      // MARK: - Target snapshots
      try writeToDirectory(snapshotting: snapshotting, format: diffable, directoryUrl: snapshotTargetsUrl, snapshotFileName: snapshotFileName)

      let snapshotReferenceFileUrl = snapshotReferencesUrl.appendingPathComponent(snapshotFileName).appendingPathExtension(snapshotting.pathExtension ?? "")
      
      guard !recording, fileManager.fileExists(atPath: snapshotReferenceFileUrl.path) else {
        try writeToDirectory(snapshotting: snapshotting, format: diffable, directoryUrl: snapshotAdditionsUrl, snapshotFileName: snapshotFileName)
        return
            """
            No reference was found on disk. A new snapshot has been created to the "SnapshotAdditions" folder.

            open "SnapshotAdditions" folder and add the content to the "SnapshotReferences" folder

            Then Re-run "\(testName)" to test against the newly-recorded snapshot.
            """
      }

      let data = try Data(contentsOf: snapshotReferenceFileUrl)
      let reference = snapshotting.diffing.fromData(data)

      #if os(iOS) || os(tvOS)
      // If the image generation fails for the diffable part and the reference was empty, use the reference
      if let localDiff = diffable as? UIImage,
         let refImage = reference as? UIImage,
         localDiff.size == .zero && refImage.size == .zero {
        diffable = reference
      }
      #endif

      guard let (_, attachments) = snapshotting.diffing.diff(reference, diffable) else {
        return nil
      }

      // MARK: - Changed snapshots
      try writeToDirectory(snapshotting: snapshotting, format: diffable, directoryUrl: snapshotChangesUrl, snapshotFileName: snapshotFileName)

      // MARK: - Diff snapshots
      if let difference = snapshotting.diffing.difference?(reference, diffable) {
        try writeToDirectory(snapshotting: snapshotting, format: difference, directoryUrl: snapshotDifferencesUrl, snapshotFileName: snapshotFileName)
      }

      if !attachments.isEmpty {
        #if !os(Linux) && !os(Windows)
        if ProcessInfo.processInfo.environment.keys.contains("__XCODE_BUILT_PRODUCTS_DIR_PATHS") {
          XCTContext.runActivity(named: "Attached Failure Diff") { activity in
            attachments.forEach {
              activity.add($0)
            }
          }
        }
        #endif
      }

      return nil
    } catch {
      return error.localizedDescription
    }
}

private func writeToDirectory<Value, Format>(snapshotting: Snapshotting<Value, Format>, format: Format, directoryUrl: URL, snapshotFileName: String) throws {
  try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true)
  let snapshotFileUrl = directoryUrl.appendingPathComponent(snapshotFileName).appendingPathExtension(snapshotting.pathExtension ?? "")
  try snapshotting.diffing.toData(format).write(to: snapshotFileUrl)
}

// MARK: - Private

private let counterQueue = DispatchQueue(label: "co.pointfree.SnapshotTesting.counter")
private var counterMap: [URL: Int] = [:]

func sanitizePathComponent(_ string: String) -> String {
  return string
    .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
    .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
}

// We need to clean counter between tests executions in order to support test-iterations.
private class CleanCounterBetweenTestCases: NSObject, XCTestObservation {
    private static var registered = false
    private static var registerQueue = DispatchQueue(label: "co.pointfree.SnapshotTesting.testObserver")

    static func registerIfNeeded() {
      registerQueue.sync {
        if !registered {
          registered = true
          XCTestObservationCenter.shared.addTestObserver(CleanCounterBetweenTestCases())
        }
      }
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
      counterQueue.sync {
        counterMap = [:]
      }
    }
}
