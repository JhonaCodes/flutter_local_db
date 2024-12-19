/// Enum that defines the HTTP methods allowed for the middleware
/// that handles requests and responses.
enum RequestMethod {
  /// Handles GET requests to retrieve resources
  /// Example: Get list of users
  get,

  /// Handles POST requests to create new resources
  /// Example: Create a new user
  post,

  /// Handles PUT requests to update existing resources
  /// Example: Update complete user data
  put,

  /// Handles DELETE requests to remove resources
  /// Example: Delete a user
  delete,

  /// Special case of GET to retrieve a resource by ID
  /// Example: Get specific user by ID
  geById
}