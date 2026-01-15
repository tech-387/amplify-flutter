enum LogMode {
  /// Default/info logs which will not have any additional suffix.
  info,

  /// Log type for loading/waiting for some operation. It will add clock icon with three dots as suffix.
  wait,

  /// Log type for success. It will add green checkmark icon as suffix.
  success,

  /// Log type for error. Use this whenever unexpected errors occur. It will add red x icon as suffix.
  error,
}
