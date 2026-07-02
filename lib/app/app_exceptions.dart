/// Thrown when an operation requires a session but none is stored (or the
/// stored one has been rejected by the server).
class UnauthenticatedException implements Exception {
  const UnauthenticatedException();
}
