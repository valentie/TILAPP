import Vapor
import FluentMySQL

final class Category: Codable {
    var id: Int?
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

extension Category: MySQLModel {}
extension Category: Migration {}
extension Category: Content {}
extension Category: Parameter {}

extension Category {
    var acronyms: Siblings<Category, Acronym, AcronymCategoryPivot> {
        return siblings()
    }
}
