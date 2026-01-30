class AppConstants {
  static const String appName = 'Savr';
  static const String appVersion = '1.0.0';
  
  static const String roleCustomer = 'customer';
  static const String roleMerchant = 'merchant';
  static const String roleAdmin = 'admin';
  static const String roleSuperAdmin = 'super_admin';
  
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  
  static const String orderPending = 'pending';
  static const String orderConfirmed = 'confirmed';
  static const String orderReady = 'ready';
  static const String orderCompleted = 'completed';
  static const String orderCancelled = 'cancelled';
  
  static const double defaultDiscountPercentage = 50.0;
  static const int defaultFoodQuantity = 5;
  static const double defaultSearchRadius = 10.0; // km
  
  static const String timeFormat = 'HH:mm';
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
}