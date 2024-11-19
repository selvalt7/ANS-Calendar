//
//  Auth.swift
//  ANS Calendar
//
//  Created by Stanisław on 16/11/2024.
//

import Foundation
import Security
import SwiftSoup

let LoginUrl = "https://wu.ans-nt.edu.pl/ppuz-stud-app/ledge/view/stud.StartPage?action=security.authentication.ImapLogin"

struct LoginResult {
    var Success: Bool
    let JSessionID: String
    let StudentID: Int
}

func Login(user: String, pass: String) async -> LoginResult {
    do {
        let apiurl = URL(string: LoginUrl)
        
        var request = URLRequest(url: apiurl!)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 13_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let loginData: Data = "login=\(user)&password=\(pass)".data(using: .utf8)!
        request.httpBody = loginData
        
        let session = URLSession.shared
        let (data, response) = try await session.data(for: request)
        let html: String = String(NSString(data: data, encoding: NSUTF8StringEncoding) ?? "")
        let doc: Document = try SwiftSoup.parse(html)
        if ( try doc.getElementsByClass("bad-pasword-wiki").indices.contains(0) )
        {
            print("Wrong password")
            return LoginResult(Success: false, JSessionID: "", StudentID: 0)
        }
        else{
            print("Login succesful")
            let links: Elements = try doc.select("a")
            var studentid = 0
            var tourNumber = 0
            let studentsidregex = /(idosoby=)(\d+)/
            let tourRegex = /(nrtury=)(\d+)/
            
            for link: Element in links.array() {
                let linkHref: String = try link.attr("href")
                if let match = linkHref.firstMatch(of: studentsidregex) {
                    studentid = NumberFormatter().number(from: String(match.2))!.intValue
                }
                if let match = linkHref.firstMatch(of: tourRegex) {
                    tourNumber = NumberFormatter().number(from: String(match.2))!.intValue
                }
            }
            
            let HTTPResponse = response as! HTTPURLResponse
            let fields = HTTPResponse.allHeaderFields as? [String: String]
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields!, for: response.url!)
            var JSessionID = ""
            
            for cookie in cookies {
                if (cookie.name == "JSESSIONID") {
                    JSessionID = cookie.value
                }
            }
            
            UserDefaults.standard.set(JSessionID, forKey: "JSessionID")
            UserDefaults.standard.set(studentid, forKey: "StudentID")
            UserDefaults.standard.set(tourNumber, forKey: "TourID")
            UserDefaults.standard.set(true, forKey: "LoginGood")
            UserDefaults.standard.set(user, forKey: "Login")
            
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

            return LoginResult(Success: true, JSessionID: JSessionID, StudentID: studentid)
        }
    } catch {
        print("Error occured")
        return LoginResult(Success: false, JSessionID: "", StudentID: 0)
    }
}

func LoginExistingUser() async {
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
                    _ = await Login(user: username, pass: password)
                }
            } else {
                print("Something went wrong trying to find the user in the keychain")
            }
        }
    } catch {
        
    }
}

func Logout() {
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
    
    UserDefaults.standard.set("", forKey: "JSessionID")
    UserDefaults.standard.set("", forKey: "Login")
    UserDefaults.standard.set(false, forKey: "LoginGood")
}

struct ExceptionResponse: Codable {
    let exceptionClass: String?
    let exceptionMessage: String?
}

func CheckAuthority(SessionID: String) async -> Bool {
    do {
        let url = URL(string: AJAXUrl)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 13_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.1 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("JSESSIONID=\(SessionID)", forHTTPHeaderField: "Cookie")
        
        request.httpBody = "{\"service\":\"Wiadomosc\",\"method\":\"getLiczbaNowychWiadomosci\",\"params\":{}}".data(using: .utf8)
        
        let session = URLSession.shared
        let (data, _) = try await session.data(for: request)
        let parsedJSON: ExceptionResponse = try! JSONDecoder().decode(ExceptionResponse.self, from: data)
        print(request.allHTTPHeaderFields)
        
        if (parsedJSON.exceptionClass == "org.objectledge.security.exception.AccessControlException") {        print(parsedJSON.exceptionClass)
            return false
        }
        return true
    } catch {
        return false
    }
}
