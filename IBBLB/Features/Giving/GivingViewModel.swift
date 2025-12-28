//
//  GivingViewModel.swift
//  IBBLB
//
//  View model for managing giving page state and data
//

import Foundation
import Combine
import UIKit

@MainActor
class GivingViewModel: ObservableObject {
    @Published var givingPage: GivingPage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalGiven: Double = 0.0 // This would come from user account data
    
    private let apiService: MobileAPIService
    private var fetchTask: Task<Void, Never>?
    
    init(apiService: MobileAPIService = MobileAPIService()) {
        self.apiService = apiService
    }
    
    func loadGivingPage() async {
        // Cancel previous task to prevent race conditions
        fetchTask?.cancel()
        
        fetchTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            isLoading = true
            errorMessage = nil
            
            do {
                givingPage = try await apiService.fetchGiving()
                guard !Task.isCancelled else { return }
            } catch {
                // Handle cancellation silently
                if error is CancellationError {
                    return
                }
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    return
                }
                
                errorMessage = "Failed to load giving information. Please try again."
                print("Error loading giving page: \(error)")
            }
            
            // Only update loading state if task wasn't cancelled
            if !Task.isCancelled {
                isLoading = false
            }
        }
        
        await fetchTask?.value
    }
    
    func openGivingURL() {
        guard let urlString = givingPage?.onlineGivingUrl else {
            errorMessage = "Giving URL not available"
            return
        }

        // SECURITY: Validate URL before opening
        let success = SecureURLHandler.openURL(
            urlString,
            trustedDomains: ["give.ibblb.org", "giving.ibblb.org", "donate.ibblb.org", "ibblb.org"]
        ) { untrustedURL in
            // Handle untrusted URL - in a real app, show an alert to user
            #if DEBUG
            print("⚠️ Giving URL is untrusted: \(untrustedURL)")
            #endif
            self.errorMessage = "The giving link appears to be external. Please contact support."
        }

        if !success {
            errorMessage = "Unable to open giving link. Please check the URL."
        }
    }

    func openManageAccount() {
        // This would open the manage account URL or screen
        // For now, we'll use the same giving URL with a parameter
        guard let urlString = givingPage?.onlineGivingUrl else {
            errorMessage = "Account management URL not available"
            return
        }

        // SECURITY: Validate URL before opening
        let success = SecureURLHandler.openURL(
            urlString,
            trustedDomains: ["give.ibblb.org", "giving.ibblb.org", "ibblb.org"]
        ) { untrustedURL in
            #if DEBUG
            print("⚠️ Account management URL is untrusted: \(untrustedURL)")
            #endif
            self.errorMessage = "The account link appears to be external. Please contact support."
        }

        if !success {
            errorMessage = "Unable to open account management link."
        }
    }
}

