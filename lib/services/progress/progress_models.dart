enum ProgressStage {
  understandingRequest,
  loadingPreferences,
  searchingHostels,
  checkingPolicies,
  processingBookings,
  processingComplaints,
  runningAnalytics,
  rankingRecommendations,
  reflectionVerification,
  generatingAnswer,
  completed,
  error,
}

enum ProgressStatus {
  started,
  running,
  completed,
  failed,
}

enum ProgressSeverity {
  info,
  success,
  warning,
  error,
}
