import Foundation

// Minimal, dependency-free .tar.gz read/write for exactly one file entry.
// Real USTAR tar framing + real gzip framing (via system zlib, linked with
// `-lz`, called with windowBits = 15 + 16 — the standard trick that makes
// zlib emit/consume RFC-1952 gzip streams instead of raw zlib streams) so
// the result is openable by Finder/Archive Utility/`tar`, not just by this
// app. No subprocess, so this works inside the App Sandbox.

enum TarGzError: Error, LocalizedError {
    case entryNameTooLong
    case invalidArchive(String)
    case compressionFailed
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .entryNameTooLong:
            return "Internal error: archive entry name too long."
        case .invalidArchive(let reason):
            return "This file isn't a valid QuickText backup (\(reason))."
        case .compressionFailed:
            return "Failed to compress the backup data."
        case .decompressionFailed:
            return "Failed to decompress the backup file — it may be corrupt."
        }
    }
}

private let tarBlockSize = 512

/// Wraps `content` as a single-entry tar archive named `entryName`, then
/// gzip-compresses it.
func makeTarGz(jsonData content: Data, entryName: String) throws -> Data {
    let tarData = try makeTar(entryName: entryName, content: content)
    return try gzipCompress(tarData)
}

/// Reverses `makeTarGz`: gzip-decompresses, then reads the single tar
/// entry's content back out, validating the USTAR header along the way.
func extractJSON(fromTarGz data: Data) throws -> Data {
    let tarData = try gzipDecompress(data)
    return try readTarEntryContent(tarData)
}

// MARK: - Tar (single entry, USTAR)

private func makeTar(entryName: String, content: Data) throws -> Data {
    guard entryName.utf8.count < 100 else { throw TarGzError.entryNameTooLong }

    var header = [UInt8](repeating: 0, count: tarBlockSize)

    func write(_ bytes: [UInt8], at offset: Int) {
        header.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
    }
    func writeString(_ string: String, at offset: Int, length: Int) {
        write(Array(string.utf8.prefix(length)), at: offset)
    }
    func octalField(_ value: Int, length: Int) -> [UInt8] {
        let digits = length - 1
        let octal = String(value, radix: 8)
        let padded = String(repeating: "0", count: max(0, digits - octal.count)) + octal
        var bytes = Array(padded.utf8.suffix(digits))
        bytes.append(0)
        return bytes
    }

    writeString(entryName, at: 0, length: 100)                 // name
    write(octalField(0o644, length: 8), at: 100)                // mode
    write(octalField(0, length: 8), at: 108)                    // uid
    write(octalField(0, length: 8), at: 116)                    // gid
    write(octalField(content.count, length: 12), at: 124)       // size
    write(octalField(Int(Date().timeIntervalSince1970), length: 12), at: 136) // mtime
    for i in 148..<156 { header[i] = UInt8(ascii: " ") }         // checksum placeholder
    header[156] = UInt8(ascii: "0")                              // typeflag: regular file
    writeString("ustar", at: 257, length: 6)                     // magic ("ustar\0")
    writeString("00", at: 263, length: 2)                        // ustar version
    writeString("staff", at: 265, length: 32)                    // uname
    writeString("staff", at: 297, length: 32)                    // gname

    let checksum = header.reduce(0) { $0 + Int($1) }
    let checksumOctal = String(checksum, radix: 8)
    let checksumPadded = String(repeating: "0", count: max(0, 6 - checksumOctal.count)) + checksumOctal
    var checksumBytes = Array(checksumPadded.utf8.suffix(6))
    checksumBytes.append(0)
    checksumBytes.append(UInt8(ascii: " "))
    write(checksumBytes, at: 148)

    var result = Data(header)
    result.append(content)
    let padding = (tarBlockSize - (content.count % tarBlockSize)) % tarBlockSize
    result.append(Data(count: padding))
    result.append(Data(count: tarBlockSize * 2)) // end-of-archive marker
    return result
}

private func readTarEntryContent(_ tar: Data) throws -> Data {
    guard tar.count >= tarBlockSize else {
        throw TarGzError.invalidArchive("archive too short")
    }
    let header = [UInt8](tar.prefix(tarBlockSize))

    let magic = String(decoding: header[257..<262], as: UTF8.self)
    guard magic == "ustar" else {
        throw TarGzError.invalidArchive("missing ustar header")
    }

    let sizeField = String(decoding: header[124..<136], as: UTF8.self)
        .trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
    guard let size = Int(sizeField, radix: 8), size >= 0 else {
        throw TarGzError.invalidArchive("unreadable size field")
    }
    guard tar.count >= tarBlockSize + size else {
        throw TarGzError.invalidArchive("truncated content")
    }

    return tar.subdata(in: tarBlockSize..<(tarBlockSize + size))
}

// MARK: - Gzip (via system zlib, windowBits = 15 + 16)

private func gzipCompress(_ data: Data) throws -> Data {
    var stream = z_stream()
    let windowBits: Int32 = 15 + 16
    let initStatus = deflateInit2_(
        &stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, windowBits, 8, Z_DEFAULT_STRATEGY,
        zlibVersion(), Int32(MemoryLayout<z_stream>.size)
    )
    guard initStatus == Z_OK else { throw TarGzError.compressionFailed }
    defer { deflateEnd(&stream) }

    let bound = deflateBound(&stream, UInt(data.count))
    var output = Data(count: Int(bound))
    var input = data

    let deflateStatus: Int32 = output.withUnsafeMutableBytes { outRaw in
        input.withUnsafeMutableBytes { inRaw in
            stream.next_in = inRaw.bindMemory(to: UInt8.self).baseAddress
            stream.avail_in = UInt32(inRaw.count)
            stream.next_out = outRaw.bindMemory(to: UInt8.self).baseAddress
            stream.avail_out = UInt32(outRaw.count)
            return deflate(&stream, Z_FINISH)
        }
    }
    guard deflateStatus == Z_STREAM_END else { throw TarGzError.compressionFailed }

    output.removeSubrange(Int(stream.total_out)..<output.count)
    return output
}

private func gzipDecompress(_ data: Data) throws -> Data {
    guard !data.isEmpty else { throw TarGzError.invalidArchive("empty file") }

    var stream = z_stream()
    let windowBits: Int32 = 15 + 16
    let initStatus = inflateInit2_(&stream, windowBits, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
    guard initStatus == Z_OK else { throw TarGzError.decompressionFailed }
    defer { inflateEnd(&stream) }

    var input = data
    var output = Data()
    let bufferSize = 64 * 1024
    var outputBuffer = [UInt8](repeating: 0, count: bufferSize)
    var status: Int32 = Z_OK

    try input.withUnsafeMutableBytes { (inRaw: UnsafeMutableRawBufferPointer) in
        stream.next_in = inRaw.bindMemory(to: UInt8.self).baseAddress
        stream.avail_in = UInt32(inRaw.count)

        repeat {
            status = try outputBuffer.withUnsafeMutableBufferPointer { outBuf -> Int32 in
                stream.next_out = outBuf.baseAddress
                stream.avail_out = UInt32(bufferSize)
                let result = inflate(&stream, Z_NO_FLUSH)
                guard result == Z_OK || result == Z_STREAM_END else {
                    throw TarGzError.decompressionFailed
                }
                let bytesWritten = bufferSize - Int(stream.avail_out)
                if bytesWritten > 0 {
                    output.append(outBuf.baseAddress!, count: bytesWritten)
                }
                return result
            }
        } while status != Z_STREAM_END && stream.avail_in > 0
    }

    guard status == Z_STREAM_END else { throw TarGzError.decompressionFailed }
    return output
}
