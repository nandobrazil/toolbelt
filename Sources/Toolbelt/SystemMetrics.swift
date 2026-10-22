import Foundation

struct SystemSnapshot: Equatable {
    var memoryTotal: UInt64 = 0
    var memoryApp: UInt64 = 0
    var memoryWired: UInt64 = 0
    var memoryCompressed: UInt64 = 0
    var memoryCached: UInt64 = 0
    var pressureLevel = 1
    var swapTotal: UInt64 = 0
    var swapUsed: UInt64 = 0
    var diskTotal: UInt64 = 0
    var diskFree: UInt64 = 0

    var memoryUsed: UInt64 { memoryApp + memoryWired + memoryCompressed }
    var memoryUsedRatio: Double { memoryTotal == 0 ? 0 : Double(memoryUsed) / Double(memoryTotal) }
    var diskFreeRatio: Double { diskTotal == 0 ? 1 : Double(diskFree) / Double(diskTotal) }

    var pressureTitle: String {
        switch pressureLevel {
        case 4: return String(localized: "crítica")
        case 2: return String(localized: "alta")
        default: return String(localized: "normal")
        }
    }
}

enum SystemMetrics {
    static func snapshot() -> SystemSnapshot {
        var snapshot = SystemSnapshot()
        readMemory(into: &snapshot)
        readSwap(into: &snapshot)
        readDisk(into: &snapshot)
        snapshot.pressureLevel = sysctlInt("kern.memorystatus_vm_pressure_level") ?? 1
        return snapshot
    }

    private static func readMemory(into snapshot: inout SystemSnapshot) {
        snapshot.memoryTotal = UInt64(sysctlInt("hw.memsize") ?? 0)
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let pageSize = UInt64(vm_kernel_page_size)
        let anonymous = UInt64(statistics.internal_page_count)
        let purgeable = UInt64(statistics.purgeable_count)
        snapshot.memoryApp = (anonymous > purgeable ? anonymous - purgeable : 0) * pageSize
        snapshot.memoryWired = UInt64(statistics.wire_count) * pageSize
        snapshot.memoryCompressed = UInt64(statistics.compressor_page_count) * pageSize
        snapshot.memoryCached = (UInt64(statistics.external_page_count) + purgeable) * pageSize
    }

    private static func readSwap(into snapshot: inout SystemSnapshot) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return }
        snapshot.swapTotal = usage.xsu_total
        snapshot.swapUsed = usage.xsu_used
    }

    private static func readDisk(into snapshot: inout SystemSnapshot) {
        var stats = statfs()
        let path = FileManager.default.fileExists(atPath: "/System/Volumes/Data") ? "/System/Volumes/Data" : "/"
        guard statfs(path, &stats) == 0 else { return }
        let blockSize = UInt64(stats.f_bsize)
        snapshot.diskTotal = UInt64(stats.f_blocks) * blockSize
        snapshot.diskFree = UInt64(stats.f_bavail) * blockSize
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
            var smallValue: Int32 = 0
            var smallSize = MemoryLayout<Int32>.size
            guard sysctlbyname(name, &smallValue, &smallSize, nil, 0) == 0 else { return nil }
            return Int(smallValue)
        }
        return size == MemoryLayout<Int32>.size ? Int(Int32(truncatingIfNeeded: value)) : Int(value)
    }
}

enum ByteFormat {
    private static let usesDecimalComma = Bundle.main.preferredLocalizations.first?.hasPrefix("pt") ?? true

    static func memory(_ bytes: UInt64) -> String {
        let gigabytes = Double(bytes) / 1_073_741_824
        if gigabytes >= 1 {
            return withDecimalSeparator(String(format: "%.1f GB", gigabytes))
        }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }

    static func storage(_ bytes: UInt64) -> String {
        let gigabytes = Double(bytes) / 1_000_000_000
        if gigabytes >= 100 {
            return String(format: "%.0f GB", gigabytes)
        }
        return withDecimalSeparator(String(format: "%.1f GB", gigabytes))
    }

    private static func withDecimalSeparator(_ text: String) -> String {
        usesDecimalComma ? text.replacingOccurrences(of: ".", with: ",") : text
    }
}
