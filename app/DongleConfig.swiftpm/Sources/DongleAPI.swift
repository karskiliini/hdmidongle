import Foundation

/// Kommunikoi donglen config-palvelimen kanssa (http://10.42.0.1:8080)
class DongleAPI {
    static let shared = DongleAPI()
    private let baseURL = "http://10.42.0.1:8080/api"

    struct DongleStatus: Codable {
        let config: DongleConfig
        let system: SystemInfo
    }

    struct DongleConfig: Codable {
        var dongleName: String
        var wifiSsid: String
        var wifiPassword: String
        var wifiCountry: String
        var mode: String
        var resolution: String

        enum CodingKeys: String, CodingKey {
            case dongleName = "dongle_name"
            case wifiSsid = "wifi_ssid"
            case wifiPassword = "wifi_password"
            case wifiCountry = "wifi_country"
            case mode, resolution
        }
    }

    struct SystemInfo: Codable {
        let model: String?
        let ipAddresses: [String]?
        let wifiConnected: Bool?
        let wifiSsid: String?
        let dongleService: String?
        let temperatureC: Double?

        enum CodingKeys: String, CodingKey {
            case model
            case ipAddresses = "ip_addresses"
            case wifiConnected = "wifi_connected"
            case wifiSsid = "wifi_ssid"
            case dongleService = "dongle_service"
            case temperatureC = "temperature_c"
        }
    }

    struct WiFiNetwork: Codable, Identifiable {
        let ssid: String
        let signal: Int
        let security: String
        var id: String { ssid }
    }

    struct ConfigResponse: Codable {
        let success: Bool
        let errors: [String]?
        let config: DongleConfig?
    }

    // MARK: - API-kutsut

    func getStatus() async throws -> DongleStatus {
        let data = try await fetch("GET", path: "/status")
        return try JSONDecoder().decode(DongleStatus.self, from: data)
    }

    func updateConfig(_ config: [String: String]) async throws -> ConfigResponse {
        let body = try JSONSerialization.data(withJSONObject: config)
        let data = try await fetch("POST", path: "/config", body: body)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }

    func scanWiFi() async throws -> [WiFiNetwork] {
        let data = try await fetch("GET", path: "/wifi/scan")
        struct Response: Codable { let networks: [WiFiNetwork] }
        return try JSONDecoder().decode(Response.self, from: data).networks
    }

    func restart() async throws {
        _ = try await fetch("POST", path: "/restart")
    }

    func reboot() async throws {
        _ = try await fetch("POST", path: "/reboot")
    }

    // MARK: - HTTP

    private func fetch(_ method: String, path: String, body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method
        request.timeoutInterval = 10
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}
