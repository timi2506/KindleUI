import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import CKindleGTK

// MARK: - Main-Thread Dispatcher for GTK+-2.0

private final class MainThreadBox: @unchecked Sendable {
    let block: () -> Void
    init(_ block: @escaping () -> Void) {
        self.block = block
    }
}

private func kindleMainThreadIdleTrampoline(userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { return }
    let box = Unmanaged<MainThreadBox>.fromOpaque(userData).takeRetainedValue()
    box.block()
}

/// Dispatches work onto the active GTK+-2.0 main event loop thread so `@State` updates
/// safely trigger a declarative UI rebuild and E-Ink display refresh.
public enum KindleMainThread {
    public static func async(_ block: @escaping @Sendable () -> Void) {
        let box = MainThreadBox(block)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        kgtk_schedule_idle(kindleMainThreadIdleTrampoline, ptr)
    }
}

// MARK: - KindleHTTP Native URLSession Client

public enum KindleHTTPError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case transportError(String)
    case emptyResponse(String)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .transportError(let detail):
            return "Network error: \(detail)"
        case .emptyResponse(let url):
            return "Empty response from \(url)."
        case .decodingFailed(let detail):
            return "JSON decode error: \(detail)"
        }
    }
}

private final class HttpCompletionBox: @unchecked Sendable {
    let urlString: String
    let completion: @Sendable (Result<Data, KindleHTTPError>) -> Void

    init(urlString: String, completion: @escaping @Sendable (Result<Data, KindleHTTPError>) -> Void) {
        self.urlString = urlString
        self.completion = completion
    }
}

private func kindleHttpCallbackTrampoline(
    statusCode: Int32,
    dataPtr: UnsafePointer<UInt8>?,
    dataLen: Int32,
    errorPtr: UnsafePointer<CChar>?,
    userData: UnsafeMutableRawPointer?
) {
    guard let userData = userData else { return }
    let box = Unmanaged<HttpCompletionBox>.fromOpaque(userData).takeRetainedValue()
    if let errorPtr = errorPtr {
        let msg = String(cString: errorPtr)
        box.completion(.failure(.transportError(msg)))
        return
    }
    if statusCode >= 400 {
        box.completion(.failure(.transportError("HTTP \(statusCode)")))
        return
    }
    if let dataPtr = dataPtr, dataLen > 0 {
        let data = Data(bytes: dataPtr, count: Int(dataLen))
        box.completion(.success(data))
    } else {
        box.completion(.failure(.emptyResponse(box.urlString)))
    }
}

/// Asynchronous HTTP/HTTPS & JSON helper built on fast IPv4 `libcurl` (`khttp_get_async`) with
/// `URLSession` fallback, automatically marshaling completion callbacks onto the GTK+-2.0 main UI thread.
public enum KindleHTTP {
    /// Performs an asynchronous HTTP/HTTPS GET and invokes `completion` on the GTK main thread.
    public static func getData(
        from urlString: String,
        timeoutSeconds: TimeInterval = 8,
        completion: @escaping @Sendable (Result<Data, KindleHTTPError>) -> Void
    ) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else {
            KindleMainThread.async {
                completion(.failure(.invalidURL(urlString)))
            }
            return
        }

        let box = HttpCompletionBox(urlString: trimmed, completion: completion)
        let boxPtr = Unmanaged.passRetained(box).toOpaque()
        let started = trimmed.withCString { cUrl in
            khttp_get_async(
                cUrl,
                Int32(max(2, Int(timeoutSeconds.rounded()))),
                kindleHttpCallbackTrampoline,
                boxPtr
            )
        }
        if started {
            return
        }
        // Release retained box if falling back to URLSession
        _ = Unmanaged<HttpCompletionBox>.fromOpaque(boxPtr).takeRetainedValue()

        var request = URLRequest(url: url, timeoutInterval: timeoutSeconds)
        request.setValue("KindleUI/1.0 (https://github.com/kindlemodding/KindleUI; contact@kindlemodding.org; Kindle E-Ink)", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            let result: Result<Data, KindleHTTPError>
            if let error = error {
                result = .failure(.transportError(error.localizedDescription))
            } else if let data = data, !data.isEmpty {
                result = .success(data)
            } else {
                result = .failure(.emptyResponse(trimmed))
            }
            KindleMainThread.async {
                completion(result)
            }
        }
        task.resume()
    }

    /// Performs an asynchronous HTTP/HTTPS GET, decodes a `Decodable` JSON payload,
    /// and delivers the result on the GTK main thread.
    ///
    /// Decoding happens on a background queue so large payloads never block the UI thread.
    public static func getJSON<T: Decodable & Sendable>(
        _ type: T.Type,
        from urlString: String,
        timeoutSeconds: TimeInterval = 8,
        completion: @escaping @Sendable (Result<T, KindleHTTPError>) -> Void
    ) {
        getJSON(type, from: urlString, timeoutSeconds: timeoutSeconds, transform: { $0 }, completion: completion)
    }

    /// Like `getJSON(_:from:timeoutSeconds:completion:)`, but additionally runs `transform` on the decoded value
    /// on the background queue, so expensive post-processing (HTML scraping, layout, ...) stays off the UI thread.
    /// Use a lower `qos` for non-essential work so it doesn't compete with what the user is waiting for.
    /// Only `completion` runs on the GTK main thread.
    public static func getJSON<T: Decodable & Sendable, U: Sendable>(
        _ type: T.Type,
        from urlString: String,
        timeoutSeconds: TimeInterval = 8,
        qos: DispatchQoS.QoSClass = .userInitiated,
        transform: @escaping @Sendable (T) -> U,
        completion: @escaping @Sendable (Result<U, KindleHTTPError>) -> Void
    ) {
        getData(from: urlString, timeoutSeconds: timeoutSeconds) { dataResult in
            switch dataResult {
            case .failure(let err):
                completion(.failure(err))
            case .success(let data):
                DispatchQueue.global(qos: qos).async {
                    let result: Result<U, KindleHTTPError>
                    do {
                        let decoded = try JSONDecoder().decode(T.self, from: data)
                        result = .success(transform(decoded))
                    } catch {
                        result = .failure(.decodingFailed(error.localizedDescription))
                    }
                    KindleMainThread.async {
                        completion(result)
                    }
                }
            }
        }
    }

    /// Performs an asynchronous HTTP/HTTPS GET using Swift `async/await`.
    public static func getData(
        from urlString: String,
        timeoutSeconds: TimeInterval = 8
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            getData(from: urlString, timeoutSeconds: timeoutSeconds) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Performs an asynchronous HTTP/HTTPS GET and decodes a `Decodable` JSON payload using Swift `async/await`.
    public static func getJSON<T: Decodable & Sendable>(
        _ type: T.Type,
        from urlString: String,
        timeoutSeconds: TimeInterval = 8
    ) async throws -> T {
        let data = try await getData(from: urlString, timeoutSeconds: timeoutSeconds)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw KindleHTTPError.decodingFailed(error.localizedDescription)
        }
    }
}
