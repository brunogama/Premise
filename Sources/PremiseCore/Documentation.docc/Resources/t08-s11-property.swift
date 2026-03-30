import Testing
import PremiseTesting
import PremiseStrategies

@Test func requestRouterHandlesAllMethods() async throws {
  try await forAll(requestStrategy) { request in
    // Verify the router doesn't crash for any generated request.
    let response = MyRouter.route(request)
    #expect(response.statusCode >= 100)
    #expect(response.statusCode < 600)
    // GET requests with no body should never produce 400 Bad Request.
    if request.method == "GET" && request.body == nil {
      #expect(response.statusCode != 400)
    }
  }
}
