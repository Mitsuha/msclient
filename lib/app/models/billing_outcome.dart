/// The result of applying a billing method, which re-allocates an account from
/// the pool. Distinguishes the "pool is empty" case so the UI can surface a
/// dedicated prompt instead of the generic error banner.
enum BillingOutcome {
  /// Credentials were rewritten successfully.
  success,

  /// The backend had no assignable account left in the pool
  /// (`api.error.no_available_account`, HTTP 503).
  noAvailableAccount,

  /// Any other failure; the generic error banner carries the details.
  failed,
}
