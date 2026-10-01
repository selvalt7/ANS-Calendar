//
//  Profile.swift
//  ANS Calendar
//

import SwiftUI
import SwiftSoup

let ProfilePageURL = "stud.daneosobowe.MojProfilView"
let ProfileDetailsURL = "stud.daneosobowe.DaneOsoboweTabView"

struct ProfileField: Equatable {
    var label: String
    var value: String
    var isSensitive = false
}

struct StudentProfile: Equatable {
    var name: String
    var photoPath: String?
    var personal: [ProfileField]
    var studies: [ProfileField]
    var addresses: [ProfileField]

    var isEmpty: Bool {
        name.isEmpty && personal.isEmpty && studies.isEmpty && addresses.isEmpty
    }

    var hasSensitiveFields: Bool {
        (personal + studies + addresses).contains(where: \.isSensitive)
    }
}

func absolutePortalURL(from src: String) -> URL? {
    let trimmed = src.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed), url.scheme != nil {
        return url
    }
    if trimmed.hasPrefix("/") {
        return URL(string: "https://wu.ans-nt.edu.pl" + trimmed)
    }
    return URL(string: BaseUrl + trimmed)
}

func parseStudentProfile(html: String) throws -> StudentProfile {
    let document = try SwiftSoup.parse(html)
    let name = (try document.select("#moj-profil-container .vdo-title, .vdo-title.big").array().first?.text() ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let photo = try document.select("#moj-profil-container .photo img, .photo img").array().first?.attr("src")
    return StudentProfile(
        name: name,
        photoPath: (photo?.isEmpty == false) ? photo : nil,
        personal: try profileFields(in: document, selector: ".person-info"),
        studies: try profileFields(in: document, selector: ".jednostka-info"),
        addresses: try profileFields(in: document, selector: ".addresses")
    )
}

private func profileFields(in document: SwiftSoup.Document, selector: String) throws -> [ProfileField] {
    guard let container = try document.select(selector).array().first else { return [] }
    let rows = container.children().array().filter { $0.tagName().lowercased() == "div" }
    var fields: [ProfileField] = []
    var index = 0
    while index + 1 < rows.count {
        let labelText = try rows[index].text()
        let label = normalizedProfileLabel(labelText)
        let value = normalizedProfileValue(try profileValueText(rows[index + 1]))
        if !label.isEmpty, let value {
            fields.append(ProfileField(
                label: label,
                value: value,
                isSensitive: sensitiveProfileKeys.contains(foldedProfileLabel(labelText))
            ))
        }
        index += 2
    }
    return fields
}

private func profileValueText(_ element: Element) throws -> String {
    let html = try element.html()
    let marked = html.replacingOccurrences(
        of: "(?i)<br\\s*/?>|</p>",
        with: "\u{241E}",
        options: .regularExpression
    )
    let text = try SwiftSoup.parseBodyFragment(marked).text()
    return text
        .components(separatedBy: "\u{241E}")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
}

private func foldedProfileLabel(_ raw: String) -> String {
    var label = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if label.hasSuffix(":") {
        label.removeLast()
        label = label.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return foldedPortalKey(label)
}

private func normalizedProfileLabel(_ raw: String) -> String {
    var label = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if label.hasSuffix(":") {
        label.removeLast()
        label = label.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return profileLabels[foldedPortalKey(label)] ?? label
}

private func normalizedProfileValue(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    switch foldedPortalKey(trimmed) {
    case "brak danych":
        return "No data"
    case "mezczyzna":
        return "Male"
    case "kobieta":
        return "Female"
    default:
        return trimmed
    }
}

private func foldedPortalKey(_ text: String) -> String {
    text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pl_PL"))
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private let sensitiveProfileKeys: Set<String> = [
    "imie ojca",
    "imie matki",
    "data urodzenia",
    "miejsce urodzenia",
    "pesel",
    "adres e-mail prywatny",
    "telefon kontaktowy",
    "wku",
    "adres zamieszkania",
    "adres tymczasowy",
    "adres korespondencyjny"
]

private let profileLabels = [
    "imie ojca": "Father's name",
    "imie matki": "Mother's name",
    "data urodzenia": "Date of birth",
    "miejsce urodzenia": "Place of birth",
    "plec": "Gender",
    "pesel": "PESEL",
    "adres e-mail prywatny": "Private email",
    "adres e-mail uczelniany": "University email",
    "telefon kontaktowy": "Phone",
    "login": "Login",
    "grupa dziekanska": "Dean's group",
    "host uwierzytelnienia": "Authentication host",
    "wku": "WKU",
    "jednostka macierzysta": "Department",
    "uczelnia": "University",
    "adres zamieszkania": "Home address",
    "adres tymczasowy": "Temporary address",
    "adres korespondencyjny": "Correspondence address"
]

@MainActor
final class ProfileModel: ObservableObject {
    @Published var profile: StudentProfile?
    @Published var photo: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(api: VerbisAPI) async {
        if profile == nil {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let page = try await fetchHTML(api: api, endUrl: ProfilePageURL)
            var parsed = try parseStudentProfile(html: page)
            if parsed.personal.isEmpty && parsed.studies.isEmpty && parsed.addresses.isEmpty {
                let details = try await fetchHTML(api: api, endUrl: ProfileDetailsURL)
                let extra = try parseStudentProfile(html: details)
                parsed.personal = extra.personal
                parsed.studies = extra.studies
                parsed.addresses = extra.addresses
                if parsed.name.isEmpty { parsed.name = extra.name }
                if parsed.photoPath == nil { parsed.photoPath = extra.photoPath }
            }

            guard !parsed.isEmpty else {
                if profile == nil {
                    errorMessage = "Couldn't load the profile."
                }
                return
            }

            profile = parsed
            errorMessage = nil
            photo = await fetchPhoto(api: api, src: parsed.photoPath)
        } catch {
            if profile == nil {
                errorMessage = "Couldn't load the profile."
            }
            print("Failed to load profile: \(error.localizedDescription)")
        }
    }

    private func fetchHTML(api: VerbisAPI, endUrl: String) async throws -> String {
        let request = api.InitRequest(EndUrl: endUrl)
        let (data, _) = try await URLSession.shared.data(for: request)
        if let html = String(data: data, encoding: .utf8) {
            return html
        }
        return String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
    }

    private func fetchPhoto(api: VerbisAPI, src: String?) async -> UIImage? {
        guard let src, let url = absolutePortalURL(from: src) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("JSESSIONID=\(api.JSessionID)", forHTTPHeaderField: "Cookie")
        request.setValue("image/*,*/*", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
