import Vapor
import Fluent

struct AcronymsController: RouteCollection {
    func boot(router: Router) throws {
        let acronymsRoute = router.grouped("api", "acronyms")
        acronymsRoute.get(use: getAllHandler)
        acronymsRoute.get(Acronym.parameter, use: getHandler)
        acronymsRoute.get(Acronym.parameter, "user", use: getUserHandler)
        acronymsRoute.get(Acronym.parameter, "categories", use: getCategoriesHandles)
        acronymsRoute.get("search", use: searchHandler)
        
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = acronymsRoute.grouped(tokenAuthMiddleware, guardMiddleware)
        tokenAuthGroup.post(AcronymCreateData.self, use: createHandler)
        tokenAuthGroup.delete(Acronym.parameter, use: deleteHandler)
        tokenAuthGroup.put(Acronym.parameter, use: updateHandler)
        tokenAuthGroup.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandles)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).all()
    }
    
    func createHandler(_ req: Request, acronymData: AcronymCreateData) throws -> Future<Acronym> {
        let user = try req.requireAuthenticated(User.self)
        let acronym = try Acronym(short: acronymData.short, long: acronymData.long, userID: user.requireID())
        return acronym.save(on: req)
    }
    
    func getHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.parameters.next(Acronym.self)
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(Acronym.self).flatMap(to: HTTPStatus.self) { acronym in
            return acronym.delete(on: req).transform(to: .noContent)
        }
    }
    
    func updateHandler(_ req: Request) throws -> Future<Acronym> {
        return try flatMap(to: Acronym.self,
                           req.parameters.next(Acronym.self),
                           req.content.decode(AcronymCreateData.self)) { acronym, updateAcronym in
                            acronym.short = updateAcronym.short
                            acronym.long = updateAcronym.long
                            let user = try req.requireAuthenticated(User.self)
                            acronym.userID = try user.requireID()
                            return acronym.save(on: req)
                            
        }
    }
    
    func getUserHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(Acronym.self).flatMap(to: User.Public.self) {
            acronym in
            return acronym.user.get(on: req).convertToPublic()
        }
    }
    
    func getCategoriesHandles(_ req: Request) throws -> Future<[Category]> {
        return try req.parameters.next(Acronym.self).flatMap(to: [Category].self) { acronym in
            return try acronym.categories.query(on: req).all()
        }
    }
    
    func addCategoriesHandles(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(Acronym.self),
                           req.parameters.next(Category.self)) { acronym, category in
                            let pivot = try AcronymCategoryPivot(acronym.requireID(), category.requireID())
                            return pivot.save(on: req).transform(to: .ok)
                            
        }
    }
    
    func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
        guard let searchTerm = req.query[String.self, at: "term"] else { throw Abort(.badRequest)
        }
        return Acronym.query(on: req).group(.or) { or in
            or.filter(\.short == searchTerm)
            or.filter(\.long == searchTerm)
        }.all()
    }
}

struct AcronymCreateData: Content {
    let short: String
    let long: String
}
