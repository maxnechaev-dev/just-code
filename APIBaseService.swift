//
//  APIBaseService.swift
//  eduva
//
//  Created by Max Nechaev on 28.08.2024.
//

import Foundation
import FirebaseFunctions
import FirebaseFirestore
import FirebaseStorage
import Combine

final class APIBaseService {
    // MARK: - Private variables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Fetching methods

    func fetchAllDocuments<T: Codable & Identifiable>(
        from collectionName: String,
        filters: [String: Any] = [:],
        orderBy: [(field: String, descending: Bool)] = []
    ) async throws -> [T] {
        let db = Firestore.firestore()
        var collectionRef: Query = db.collection(collectionName)

        // Применение фильтров
        for (field, value) in filters {
            collectionRef = collectionRef.whereField(field, isEqualTo: value)
        }

        // Применение сортировки
        for order in orderBy {
            collectionRef = collectionRef.order(by: order.field, descending: order.descending)
        }

        do {
            let snapshot = try await collectionRef.getDocuments()
            let documents = try snapshot.documents.compactMap { document in
                try document.data(as: T.self)
            }
            return documents
        } catch {
            throw error
        }
    }

    func fetchDocument<T: Codable & Identifiable>(
        collectionName: String,
        documentID: String
    ) async throws -> T {
        let db = Firestore.firestore()
        let docRef = db.collection(collectionName).document(documentID)

        do {
            let document = try await docRef.getDocument()
            if let data = try? document.data(as: T.self) {
                return data
            } else {
                throw NSError(domain: "Document does not exist", code: -1, userInfo: nil)
            }
        } catch {
            throw error
        }
    }

    func fetchDataFromStorage<T: Decodable>(
        for gsURL: String,
        ofType type: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let storageRef = Storage.storage().reference(forURL: gsURL)

        storageRef.downloadURL { [weak self] url, error in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching download URL: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let url = url else {
                completion(.failure(NSError(domain: "URL is nil", code: -1, userInfo: nil)))
                return
            }

            URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .decode(type: T.self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completionStatus in
                    switch completionStatus {
                    case .failure(let error):
                        print("Error fetching data from storage: \(error.localizedDescription)")
                        completion(.failure(error))
                    case .finished:
                        break
                    }
                }, receiveValue: { data in
                    completion(.success(data))
                })
                .store(in: &self.cancellables)
        }
    }

    func fetch<Input: Codable, Output: Codable>(method: APIMethods, input: Input? = nil) async throws -> Output {
        let function = Functions.functions().httpsCallable(method.rawValue)

        do {
            let jsonObject: [String: Any]
            if let input = input {
                let inputData = try JSONEncoder().encode(input)
                jsonObject = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any] ?? [:]
            } else {
                jsonObject = [:]
            }

            let result = try await function.call(jsonObject)

            if let data = result.data as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
                let output = try JSONDecoder().decode(Output.self, from: jsonData)
                return output
            } else {
                throw APIError.decodingError("Decoding error, we will fix it soon.")
            }
        } catch {
            throw APIError.functionError(error)
        }
    }
}
