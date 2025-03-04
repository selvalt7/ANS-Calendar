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

enum VerbisAPIError: Error {
    case BadPassword
    case NoUser
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
    var ValidLogin: Bool = false
    @Published var IsLoggedIn: Bool = false
    
    init() {
        self.JSessionID = UserDefaults.standard.string(forKey: "JSessionID") ?? ""
        self.StudentID = UserDefaults.standard.integer(forKey: "StudentID")
        self.TourID = UserDefaults.standard.integer(forKey: "TourID")
        self.SemesterID = UserDefaults.standard.integer(forKey: "SemesterID")
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
            guard !user.isEmpty else {
                throw VerbisAPIError.NoUser
            }
            let apiurl = URL(string: BaseUrl+LoginUrl)
            let loginData = "login=\(user)&password=\(pass)"
            
            let request = InitRequest(EndUrl: LoginUrl, UrlData: loginData)
            
            let session = URLSession.shared
            
            HTTPCookieStorage.shared.cookies(for: apiurl!)?.forEach({ HTTPCookie in
                HTTPCookieStorage.shared.deleteCookie(HTTPCookie)
            })
            
            let (data, response) = try await session.data(for: request)
            let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
            let doc: Document = try SwiftSoup.parse(html)
            if ( try doc.getElementsByClass("bad-pasword-wiki").indices.contains(0) )
            {
                print("Wrong password")
                throw VerbisAPIError.BadPassword
            }
            else{
                print("Login succesful")
                let links: Elements = try doc.select("a")
                let studentsidregex = /(idosoby=)(\d+)/
                let tourRegex = /(nrtury=)(\d+)/
                
                for link: Element in links.array() {
                    let linkHref: String = try link.attr("href")
                    if let match = linkHref.firstMatch(of: studentsidregex) {
                        StudentID = NumberFormatter().number(from: String(match.2))!.intValue
                    }
                    if let match = linkHref.firstMatch(of: tourRegex) {
                        TourID = NumberFormatter().number(from: String(match.2))!.intValue
                    }
                }
                
                let HTTPResponse = response as! HTTPURLResponse
                let fields = HTTPResponse.allHeaderFields as? [String: String]
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields!, for: response.url!)
                
                fields?.forEach({ (key: String, value: String) in
                    print(key, value)
                })
                
                for cookie in cookies {
                    print(cookie.name)
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
                    kSecValueData as String: pass.data(using: .utf8)!
                ]
                
                if SecItemAdd(attributes as CFDictionary, nil) == noErr {
                    print("Added keychain")
                } else {
                    print("Something went wrong")
                }
                
                try await GetSemesterID()
            }
        } catch {
            print("Error occured")
        }
    }
    
    func InitRequest(EndUrl: String, UrlData: String = "") -> URLRequest {
        let url = URL(string: BaseUrl+EndUrl)
        var request = URLRequest(url: url!)
        
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
            let doc: Document = try! SwiftSoup.parse(html)
            
            let scripts: Elements = try! doc.select("script")
            
            let semesterIDRegex = /(idSemestru:)\s(\d+)/
            for script in scripts {
                if let match = try script.data().firstMatch(of: semesterIDRegex) {
                    SemesterID = NumberFormatter().number(from: String(match.2))!.intValue
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
