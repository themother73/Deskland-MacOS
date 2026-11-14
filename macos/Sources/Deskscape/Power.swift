import Foundation
import IOKit
import IOKit.ps
import Darwin

/// Surveille batterie / mode économie d'énergie et prévient quand l'un des deux change.
final class PowerMonitor {
    var onChange: (() -> Void)?
    private var source: CFRunLoopSource?

    init() {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        if let s = IOPSNotificationCreateRunLoopSource({ c in
            guard let c = c else { return }
            Unmanaged<PowerMonitor>.fromOpaque(c).takeUnretainedValue().onChange?()
        }, ctx)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), s, .commonModes)
            source = s
        }
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.onChange?()
        }
    }

    var onBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeRetainedValue() as String? else { return false }
        return type == kIOPSBatteryPowerValue
    }

    var lowPowerMode: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
}

/// Mesure la consommation de Deskscape : CPU et mémoire (app + processus WebKit de la page), GPU global du système.
final class Metrics {
    struct Sample { var cpu: Double?; var memory: UInt64; var gpu: Int?; var perPid: [pid_t: Double] = [:] }

    private var lastCPU: [pid_t: UInt64] = [:]
    private var lastTime: UInt64 = 0
    private let timebase: mach_timebase_info_data_t = {
        var t = mach_timebase_info_data_t(); mach_timebase_info(&t); return t
    }()

    func reset() { lastCPU = [:]; lastTime = 0 }

    private func info(_ pid: pid_t) -> proc_taskinfo? {
        var ti = proc_taskinfo()
        let n = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &ti, Int32(MemoryLayout<proc_taskinfo>.size))
        return n > 0 ? ti : nil
    }

    /// `pids` : l'app elle-même + le processus WebContent de la page de fond d'écran.
    func sample(pids: [pid_t]) -> Sample {
        let now = mach_absolute_time()
        var total: UInt64 = 0, mem: UInt64 = 0, current: [pid_t: UInt64] = [:], deltas: [pid_t: UInt64] = [:]
        for pid in pids {
            guard let ti = info(pid) else { continue }
            let ticks = ti.pti_total_user + ti.pti_total_system
            let ns = ticks &* UInt64(timebase.numer) / UInt64(timebase.denom)
            current[pid] = ns
            mem += ti.pti_resident_size
            if let prev = lastCPU[pid], ns >= prev { total += ns - prev; deltas[pid] = ns - prev }
        }
        var cpu: Double?
        var per: [pid_t: Double] = [:]
        if lastTime != 0, now > lastTime {
            let wall = Double(now - lastTime) * Double(timebase.numer) / Double(timebase.denom)
            cpu = Double(total) / wall * 100        // 100 % = un cœur complet
            for (pid, d) in deltas { per[pid] = Double(d) / wall * 100 }
        }
        lastCPU = current; lastTime = now
        return Sample(cpu: cpu, memory: mem, gpu: Self.gpuUtilization(), perPid: per)
    }

    /// Utilisation du GPU (tout le système, pas seulement Deskscape) — « Device Utilization % ».
    static func gpuUtilization() -> Int? {
        var it: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &it) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(it) }
        var best: Int?
        while case let s = IOIteratorNext(it), s != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(s, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let d = props?.takeRetainedValue() as? [String: Any],
               let perf = d["PerformanceStatistics"] as? [String: Any],
               let u = (perf["Device Utilization %"] as? NSNumber)?.intValue {
                best = max(best ?? 0, u)
            }
            IOObjectRelease(s)
        }
        return best
    }
}
