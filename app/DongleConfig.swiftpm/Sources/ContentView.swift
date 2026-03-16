import SwiftUI

struct ContentView: View {
    @EnvironmentObject var detector: USBDetector

    var body: some View {
        Group {
            if detector.dongleConnected {
                ConfigView()
            } else {
                WaitingView()
            }
        }
        .frame(width: 480, height: 560)
    }
}

// MARK: - Odotussivu

struct WaitingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cable.connector.horizontal")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Kytke dongle USB:llä")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Yhdistä dongle Maciin USB-kaapelilla konfiguroidaksesi sen.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            ProgressView()
                .scaleEffect(0.8)
        }
        .padding(40)
    }
}

// MARK: - Konfiguraatiosivu

struct ConfigView: View {
    @State private var dongleName = ""
    @State private var wifiSSID = ""
    @State private var wifiPassword = ""
    @State private var wifiCountry = "FI"
    @State private var mode = "auto"
    @State private var resolution = "auto"
    @State private var renderMode = "pixel"
    @State private var crtScanlines = true
    @State private var crtBloom = 0.3
    @State private var crtCurvature = 0.0

    @State private var networks: [DongleAPI.WiFiNetwork] = []
    @State private var systemInfo: DongleAPI.SystemInfo?
    @State private var loading = true
    @State private var saving = false
    @State private var statusMessage = ""
    @State private var showPassword = false

    let modes = ["auto", "airplay", "ndi", "retro"]
    let resolutions = ["auto", "1080p", "720p"]
    let countries = ["FI", "SE", "NO", "DK", "DE", "US", "GB"]

    var body: some View {
        VStack(spacing: 0) {
            // Otsikkopalkki
            HStack {
                Image(systemName: "display")
                    .foregroundStyle(.blue)
                Text("Dongle Configuration")
                    .font(.headline)
                Spacer()
                if let temp = systemInfo?.temperatureC {
                    Label("\(temp, specifier: "%.0f") C", systemImage: "thermometer")
                        .font(.caption)
                        .foregroundStyle(temp > 70 ? .red : .secondary)
                }
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Yhdistetty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.bar)

            Divider()

            if loading {
                Spacer()
                ProgressView("Ladataan asetuksia...")
                Spacer()
            } else {
                Form {
                    // Nimi
                    Section("Dongle") {
                        TextField("Nimi", text: $dongleName)
                            .textFieldStyle(.roundedBorder)

                        Picker("Tila", selection: $mode) {
                            Text("Automaattinen (NDI > RETRO > AirPlay)").tag("auto")
                            Text("Vain AirPlay (1080p)").tag("airplay")
                            Text("Vain NDI (4K)").tag("ndi")
                            Text("Vain RETRO (C64/Amiga/CPC)").tag("retro")
                        }

                        Picker("Resoluutio", selection: $resolution) {
                            Text("Automaattinen").tag("auto")
                            Text("1080p").tag("1080p")
                            Text("720p").tag("720p")
                        }
                    }

                    // Renderointi
                    Section("Renderointi (RETRO)") {
                        Picker("Skaalaustila", selection: $renderMode) {
                            Text("Pikselitarkka").tag("pixel")
                            Text("Pehmentava (bilinear)").tag("smooth")
                            Text("CRT-simulaatio").tag("crt")
                        }

                        if renderMode == "crt" {
                            Toggle("Scanline-raidat", isOn: $crtScanlines)

                            HStack {
                                Text("Bloom")
                                Slider(value: $crtBloom, in: 0...1)
                                Text("\(Int(crtBloom * 100))%")
                                    .frame(width: 35)
                            }

                            HStack {
                                Text("Kaarevuus")
                                Slider(value: $crtCurvature, in: 0...1)
                                Text("\(Int(crtCurvature * 100))%")
                                    .frame(width: 35)
                            }
                        }
                    }

                    // Wi-Fi
                    Section("Wi-Fi") {
                        HStack {
                            Picker("Verkko", selection: $wifiSSID) {
                                Text("Valitse...").tag("")
                                ForEach(networks) { net in
                                    HStack {
                                        Text(net.ssid)
                                        Spacer()
                                        wifiSignalIcon(net.signal)
                                    }.tag(net.ssid)
                                }
                            }
                            Button("Skannaa") {
                                Task { await scanNetworks() }
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack {
                            if showPassword {
                                TextField("Salasana", text: $wifiPassword)
                            } else {
                                SecureField("Salasana", text: $wifiPassword)
                            }
                            Button(showPassword ? "Piilota" : "Nayta") {
                                showPassword.toggle()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                        }
                        .textFieldStyle(.roundedBorder)

                        Picker("Maakoodi", selection: $wifiCountry) {
                            ForEach(countries, id: \.self) { Text($0) }
                        }
                    }

                    // Tila
                    if let info = systemInfo {
                        Section("Jarjestelma") {
                            LabeledContent("Malli", value: info.model ?? "-")
                            LabeledContent("Wi-Fi", value: info.wifiConnected == true
                                ? (info.wifiSsid ?? "Yhdistetty") : "Ei yhdistetty")
                            LabeledContent("Palvelu", value: info.dongleService ?? "-")
                            if let ips = info.ipAddresses, !ips.isEmpty {
                                LabeledContent("IP", value: ips.joined(separator: ", "))
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }

            Divider()

            // Alapalkki
            HStack {
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(statusMessage.contains("Virhe") ? .red : .green)
                }
                Spacer()
                Button("Kaynnista uudelleen") {
                    Task { await rebootDongle() }
                }
                .buttonStyle(.bordered)

                Button("Tallenna") {
                    Task { await saveConfig() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving)
            }
            .padding()
            .background(.bar)
        }
        .task {
            await loadStatus()
            await scanNetworks()
        }
    }

    // MARK: - Toiminnot

    func loadStatus() async {
        loading = true
        do {
            let status = try await DongleAPI.shared.getStatus()
            dongleName = status.config.dongleName
            wifiSSID = status.config.wifiSsid
            wifiPassword = status.config.wifiPassword
            wifiCountry = status.config.wifiCountry
            mode = status.config.mode
            resolution = status.config.resolution
            systemInfo = status.system
        } catch {
            statusMessage = "Virhe: \(error.localizedDescription)"
        }
        loading = false
    }

    func scanNetworks() async {
        do {
            networks = try await DongleAPI.shared.scanWiFi()
        } catch {
            // Skannaus epäonnistui — ei kriittistä
        }
    }

    func saveConfig() async {
        saving = true
        statusMessage = ""
        do {
            let config: [String: String] = [
                "dongle_name": dongleName,
                "wifi_ssid": wifiSSID,
                "wifi_password": wifiPassword,
                "wifi_country": wifiCountry,
                "mode": mode,
                "resolution": resolution,
                "render_mode": renderMode,
                "crt_scanlines": crtScanlines ? "true" : "false",
                "crt_bloom": String(format: "%.2f", crtBloom),
                "crt_curvature": String(format: "%.2f", crtCurvature),
            ]
            let response = try await DongleAPI.shared.updateConfig(config)
            if response.success {
                statusMessage = "Tallennettu"
            } else {
                statusMessage = "Virhe: \(response.errors?.joined(separator: ", ") ?? "tuntematon")"
            }
        } catch {
            statusMessage = "Virhe: \(error.localizedDescription)"
        }
        saving = false
    }

    func rebootDongle() async {
        do {
            try await DongleAPI.shared.reboot()
            statusMessage = "Kaynnistyy uudelleen..."
        } catch {
            statusMessage = "Virhe: \(error.localizedDescription)"
        }
    }

    func wifiSignalIcon(_ signal: Int) -> some View {
        Image(systemName: signal > 70 ? "wifi" : signal > 40 ? "wifi.exclamationmark" : "wifi.slash")
            .foregroundStyle(signal > 70 ? .green : signal > 40 ? .orange : .red)
            .font(.caption)
    }
}
