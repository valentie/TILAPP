import Vapor
import Crypto

struct UserController: RouteCollection {
    func boot(router: Router) throws {
        let userRouter = router.grouped("api", "users")
        userRouter.post(User.self, use: createHandler)
        userRouter.get(use: getAllHandler)
        userRouter.get(User.parameter, use:getUserHandler)
        userRouter.get(User.parameter, "acronyms", use: getAcronymHandler)
        
        let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
        let basicAuthGroup = userRouter.grouped(basicAuthMiddleware)
        basicAuthGroup.post("login", use: loginHandler)
    }
    
    func createHandler(_ req: Request, user: User) throws -> Future<User.Public> {
        user.password = try BCrypt.hash(user.password)
        return user.save(on: req).convertToPublic()
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[User.Public]> {
        return User.query(on: req).decode(data: User.Public.self).all()
    }
    
    func getUserHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(User.self).convertToPublic()
    }
    
    func getAcronymHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req.parameters.next(User.self).flatMap(to: [Acronym].self) { user in
            return try user.acronyms.query(on: req).all()
        }
    }
    
    func loginHandler(_ req: Request) throws -> Future<Token> {
        let user = try req.requireAuthenticated(User.self)
        let token = try Token.generate(for: user)
        return token.save(on: req)
    }
}
