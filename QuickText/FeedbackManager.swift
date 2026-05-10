//
//  FeedbackManager.swift
//  QuickText
//
//  Created by Paul Fortin on 5/6/26.
//
import AppKit

struct FeedbackManager {
    static func sendFeedback() {
        let email = "gocodecloud@cp-soft.com"
        let subject = "QuickText Feedback"
        let body = "\n\nQuickText 1.0 on \(ProcessInfo.processInfo.operatingSystemVersionString)"
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
}
