import Foundation


struct HuggingFaceSibling: Decodable, Sendable {
    let rfilename: String
    let blobId: String?
    let size: Int64?
    let lfs: HuggingFaceLFSInfo?
}
