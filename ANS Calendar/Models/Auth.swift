//
//  Auth.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import Foundation
import Security
import SwiftSoup

let BaseUrl = "https://wu.ans-nt.edu.pl/ppuz-stud-app/ledge/view/"
let LoginUrl = "stud.StartPage?action=security.authentication.ImapLogin"
let LogoutUrl = "stud.StartPage?action=security.authentication.Logout"

enum VerbisAPIError: Error, LocalizedError, Equatable {
    case BadPassword
    case NoUser
    case ExpiredPassword
    case SignInFailed
    case PasswordsDoNotMatch
    case WeakPassword
    case ChangeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .BadPassword: return "The album number or password is incorrect."
        case .NoUser: return "Enter your album number."
        case .ExpiredPassword: return "Your password has expired."
        case .SignInFailed: return "Couldn't sign in. Check your connection and try again."
        case .PasswordsDoNotMatch: return "Passwords do not match."
        case .WeakPassword: return "Password must be at least 8 characters long, contain one uppercase letter, one lowercase letter, and one number."
        case .ChangeFailed(let message): return message
        }
    }
}

struct ExceptionResponse: Codable {
    let exceptionClass: String?
    let exceptionMessage: String?
}

@MainActor
class VerbisAPI: ObservableObject {
    @Published var JSessionID: String = ""
    @Published var StudentID: Int = 0
    @Published var TourID: Int = 0
    @Published var SemesterID: Int = 0
    @Published var MailboxID: Int = 0
    var ValidLogin: Bool = false
    @Published var IsLoggedIn: Bool = false
    @Published var AuthError: VerbisAPIError? = nil
    @Published var IsBusy: Bool = false
    
    init() {
        self.JSessionID = UserDefaults.standard.string(forKey: "JSessionID") ?? ""
        self.StudentID = UserDefaults.standard.integer(forKey: "StudentID")
        self.TourID = UserDefaults.standard.integer(forKey: "TourID")
        self.SemesterID = UserDefaults.standard.integer(forKey: "SemesterID")
        self.MailboxID = UserDefaults.standard.integer(forKey: "MailboxID")
        self.ValidLogin = UserDefaults.standard.bool(forKey: "LoginGood")
        
        URLSession.shared.configuration.httpShouldSetCookies = false
        URLSession.shared.configuration.httpCookieAcceptPolicy = .never
        
        Task {
            if (JSessionID.isEmpty) {
                try await LoginExistingUser()
            } else {
                if await !CheckAuthority() {
                    try await LoginExistingUser()
                } else {
                    self.IsLoggedIn = true
                }
            }
        }
    }
    
    func Login(user: String, pass: String) async throws {
        do {
            IsBusy = true
            AuthError = nil
            guard !user.isEmpty else {
                throw VerbisAPIError.NoUser
            }
            guard let apiurl = URL(string: BaseUrl + LoginUrl) else {
                IsBusy = false
                return
            }
            let loginData = "login=\(user)&password=\(pass)"
            
            let request = InitRequest(EndUrl: LoginUrl, UrlData: loginData)
            
            let session = URLSession.shared
            
            HTTPCookieStorage.shared.cookies(for: apiurl)?.forEach({ HTTPCookie in
                HTTPCookieStorage.shared.deleteCookie(HTTPCookie)
            })
            
            let (data, response) = try await session.data(for: request)
            
            let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
            
            let doc: Document = try SwiftSoup.parse(html)
            
            if ( try doc.getElementsByClass("bad-pasword-wiki").indices.contains(0) )
            {
                IsBusy = false
                throw VerbisAPIError.BadPassword
            } else {
                print("Login succesful")
                let links: Elements = try doc.select("a")
                let studentsidregex = /(idosoby=)(\d+)/
                let tourRegex = /(nrtury=)(\d+)/
                
                for link: Element in links.array() {
                    let linkHref: String = try link.attr("href")
                    if let match = linkHref.firstMatch(of: studentsidregex), let student = Int(match.2) {
                        StudentID = student
                    }
                    if let match = linkHref.firstMatch(of: tourRegex), let tour = Int(match.2) {
                        TourID = tour
                    }
                }
                
                guard let httpResponse = response as? HTTPURLResponse, let responseURL = response.url else {
                    IsBusy = false
                    return
                }
                let fields = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
                    if let key = pair.key as? String, let value = pair.value as? String {
                        result[key] = value
                    }
                }
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: responseURL)
                
                for cookie in cookies {
                    if (cookie.name == "JSESSIONID") {
                        JSessionID = cookie.value
                    }
                }
                
                UserDefaults.standard.set(JSessionID, forKey: "JSessionID")
                UserDefaults.standard.set(StudentID, forKey: "StudentID")
                UserDefaults.standard.set(TourID, forKey: "TourID")
                UserDefaults.standard.set(true, forKey: "LoginGood")
                UserDefaults.standard.set(user, forKey: "Login")
                
                self.IsLoggedIn = true
                
                let attributes: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: user,
                    kSecValueData as String: Data(pass.utf8)
                ]
                
                if SecItemAdd(attributes as CFDictionary, nil) == noErr {
                    print("Added keychain")
                } else {
                    print("Something went wrong")
                }
                
                if let ErrorMessageContainer = try doc.getElementById("error-message") {
                    let Nodes = try ErrorMessageContainer.getAllElements()
                    
                    for element in Nodes {
                        for node in element.getChildNodes() {
                            if let CommentNode = node as? Comment {
                                if CommentNode.getData().contains(/password expired/) {
                                    AuthError = VerbisAPIError.ExpiredPassword
                                }
                            }
                        }
                    }
                }
                
                IsBusy = false
                
                await GetSemesterID()
            }
        } catch {
            IsBusy = false
            if let error = error as? VerbisAPIError {
                AuthError = error
            } else {
                AuthError = .SignInFailed
            }
        }
    }
    
    func ChangePassword(Old: String, New: String, Confirm: String) async throws {
        // 1. Validate that the passwords match locally
        guard New == Confirm else {
            throw VerbisAPIError.PasswordsDoNotMatch
        }
        
        // 2. Validate password complexity locally (8+ chars, 1 uppercase, 1 lowercase, 1 number)
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
        guard New.range(of: passwordRegex, options: .regularExpression) != nil else {
            throw VerbisAPIError.WeakPassword
        }
        
        IsBusy = true
        defer { IsBusy = false }
        
        // 3. Prepare the network request
        let changeUrl = "stud.StartPage?action=student.ChangePassword"
        
        let safeOld = Old.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? Old
        let safeNew = New.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? New
        let payload = "oldpassword=\(safeOld)&newpassword=\(safeNew)"
        
        var request = InitRequest(EndUrl: changeUrl, UrlData: payload)
        // Sometimes servers expect form-urlencoded content type for POST payloads like this
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw VerbisAPIError.ChangeFailed("Failed to connect to the server.")
        }
        
        // 4. Parse the response HTML to check for the 'action-error-message' div
        let html = String(data: data, encoding: .utf8) ?? ""
        let doc: Document = try SwiftSoup.parse(html)
        
        let errorContainers = try doc.getElementsByClass("action-error-message")
        
        if !errorContainers.isEmpty() {
            let container = errorContainers.first()!
            
            // Grab the main text ("Nie można zmienić hasła") and clean up the quotes/spaces
            var fullErrorMessage = try container.ownText()
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Grab all the specific reasons ("Hasło jest zbyt krótkie", etc.)
            let errorDetails = try container.getElementsByClass("action-error-data")
            var detailsText: [String] = []
            
            for detail in errorDetails.array() {
                detailsText.append(try detail.text())
            }
            
            // Combine them into a readable multi-line string for the SwiftUI Alert
            if !detailsText.isEmpty {
                let bulletPoints = detailsText.map { "• \($0)" }.joined(separator: "\n")
                fullErrorMessage += "\n\n" + bulletPoints
            }
            
            throw VerbisAPIError.ChangeFailed(fullErrorMessage.isEmpty ? "Wystąpił nieznany błąd." : fullErrorMessage)
        }
        
        AuthError = nil;
        // 5. If no error is found on the page, the change was successful. Update Keychain.
        if let username = UserDefaults.standard.string(forKey: "Login") {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: username
            ]
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: Data(New.utf8)
            ]
            
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            if status != noErr {
                print("Failed to update password in keychain.")
            } else {
                print("Keychain password updated successfully.")
            }
        }
    }
    
    func InitRequest(EndUrl: String, UrlData: String = "") -> URLRequest {
        let url = URL(string: BaseUrl + EndUrl) ?? URL(string: "about:blank")!
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 13_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("JSESSIONID=\(JSessionID)", forHTTPHeaderField: "Cookie")
        
        request.httpBody = UrlData.data(using: .utf8)
        
        return request
    }
    
    func InitAJAXRequest(Service: String, Method: String, Params: String = "") -> URLRequest {
        var request = InitRequest(EndUrl: "AJAX")
        request.httpBody = "{\"service\":\"\(Service)\",\"method\":\"\(Method)\",\"params\":{\(Params)}}".data(using: .utf8)
        
        return request
    }
    
    func GetSemesterID() async {
        do {
            let loginData = "idosoby=\(StudentID)&nrtury=\(TourID)"
            var request = InitRequest(EndUrl: SchedulePageURL, UrlData: loginData)
            
            let session = URLSession.shared
            let (data, response) = try await session.data(for: request)
            let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
            let doc: Document = try SwiftSoup.parse(html)
            
            let scripts: Elements = try doc.select("script")
            
            let semesterIDRegex = /(idSemestru:)\s(\d+)/
            for script in scripts {
                if let match = try script.data().firstMatch(of: semesterIDRegex),
                   let semester = Int(match.2) {
                    SemesterID = semester
                    UserDefaults.standard.set(SemesterID, forKey: "SemesterID")
                    break
                }
            }
        } catch {
            
        }
    }
    
    func LoginExistingUser() async throws {
        do {
            if (UserDefaults.standard.bool(forKey: "LoginGood")) {
                let User = UserDefaults.standard.string(forKey: "Login")
                // Set query
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: User ?? "",
                    kSecMatchLimit as String: kSecMatchLimitOne,
                    kSecReturnAttributes as String: true,
                    kSecReturnData as String: true,
                ]
                var item: CFTypeRef?
                // Check if user exists in the keychain
                if SecItemCopyMatching(query as CFDictionary, &item) == noErr {
                    // Extract result
                    if let existingItem = item as? [String: Any],
                       let username = existingItem[kSecAttrAccount as String] as? String,
                       let passwordData = existingItem[kSecValueData as String] as? Data,
                       let password = String(data: passwordData, encoding: .utf8)
                    {
                        try await Login(user: username, pass: password)
                    }
                } else {
                    print("Something went wrong trying to find the user in the keychain")
                }
            }
        } catch {
            
        }
    }
    
    func CheckAuthority() async -> Bool {
        do {
            var request = InitAJAXRequest(Service: "Planowanie", Method: "getWykladowcy", Params: "\"itemIdList\":[\"r0\"]")
            
            let session = URLSession.shared
            let (data, _) = try await session.data(for: request)
            let parsedJSON: ExceptionResponse = try JSONDecoder().decode(ExceptionResponse.self, from: data)
            
            if (parsedJSON.exceptionClass == "org.objectledge.web.mvc.security.LoginRequiredException") {
                return false
            }
            return true
        } catch {
            return false
        }
    }
    
    func Logout() async {
        do {
            let Username = UserDefaults.standard.string(forKey: "Login")
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: Username,
            ]
            
            if SecItemDelete(query as CFDictionary) == noErr {
                print("User deleted")
            } else {
                print("Failed to delele user")
            }
            
            var request = InitRequest(EndUrl: LogoutUrl)
            
            let session = URLSession.shared
            let (_, _) = try await session.data(for: request)
            
            JSessionID = ""
            TourID = 0
            StudentID = 0
            IsLoggedIn = false
            ValidLogin = false
            
            UserDefaults.standard.set("", forKey: "JSessionID")
            UserDefaults.standard.set("", forKey: "Login")
            UserDefaults.standard.set(false, forKey: "LoginGood")
        } catch {
            
        }
    }
}
