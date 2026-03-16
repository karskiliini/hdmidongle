import Foundation
import IOKit
import IOKit.usb
import Combine

/// Tarkkailee USB-laitteita ja tunnistaa donglen (ECM gadget).
class USBDetector: ObservableObject {
    @Published var dongleConnected = false
    @Published var checking = false

    private var timer: Timer?

    // Donglen USB gadget -tunnisteet (Linux Foundation Composite Gadget)
    private let vendorID: Int = 0x1d6b
    private let productID: Int = 0x0104
    private let dongleIP = "10.42.0.1"

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        // Tarkista 2 sekunnin välein onko dongle kytketty
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
        checkConnection()
    }

    func checkConnection() {
        guard !checking else { return }
        checking = true

        // Tarkista onko USB-laite kytketty IOKitin kautta
        let usbConnected = checkUSBDevice()

        if usbConnected {
            // Tarkista onko verkkoliitäntä aktiivinen (ping)
            checkNetworkReachability { [weak self] reachable in
                DispatchQueue.main.async {
                    self?.dongleConnected = reachable
                    self?.checking = false
                }
            }
        } else {
            DispatchQueue.main.async {
                self.dongleConnected = false
                self.checking = false
            }
        }
    }

    private func checkUSBDevice() -> Bool {
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        matchingDict[kUSBVendorID] = vendorID
        matchingDict[kUSBProductID] = productID

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        guard result == KERN_SUCCESS else { return false }

        let service = IOIteratorNext(iterator)
        IOObjectRelease(iterator)

        if service != 0 {
            IOObjectRelease(service)
            return true
        }
        return false
    }

    private func checkNetworkReachability(completion: @escaping (Bool) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        task.arguments = ["-c", "1", "-t", "1", dongleIP]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        DispatchQueue.global().async {
            do {
                try task.run()
                task.waitUntilExit()
                completion(task.terminationStatus == 0)
            } catch {
                completion(false)
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}
