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
    
    init(apiService: MobileAPIService = MobileAPIService()) {
        self.apiService = apiService
    }
    
    func loadGivingPage() async {
        isLoading = true
        errorMessage = nil
        
        do {
            givingPage = try await apiService.fetchGiving()
        } catch {
            errorMessage = "Failed to load giving information. Please try again."
            print("Error loading giving page: \(error)")
        }
        
        isLoading = false
    }
    
    func openGivingURL() {
        guard let urlString = givingPage?.onlineGivingUrl,
              let url = URL(string: urlString) else {
            return
        }
        UIApplication.shared.open(url)
    }
    
    func openManageAccount() {
        // This would open the manage account URL or screen
        // For now, we'll use the same giving URL with a parameter
        guard let urlString = givingPage?.onlineGivingUrl,
              let url = URL(string: urlString) else {
            return
        }
        UIApplication.shared.open(url)
    }
}

