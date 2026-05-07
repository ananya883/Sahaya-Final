class ApiConfig {
  // IMPORTANT: Update this IP address based on your network configuration
  //
  // For USB Debugging with Physical Device:
  // - Use your computer's local IP address (e.g., 192.168.x.x)
  // - Make sure your phone and computer are on the same WiFi network
  // - Run 'ipconfig' (Windows) or 'ifconfig' (Mac/Linux) to find your IP
  //
  // For Android Emulator:
  // - Use: http://10.0.2.2:5000
  //
  // Current network IP: 10.6.2.93

  static const String baseUrl = 'http://192.168.174.38:5000'; // Updated to current local IP
  // static const String baseUrl = 'http://10.6.2.93:5000'; // For mobile testing
  
  // New Endpoints
  static const String camps = '$baseUrl/api/camps/camps';
  static const String campRequests = '$baseUrl/api/camps/requests';
  static const String publicNotices = '$baseUrl/api/public-notices';

  // API Endpoints
  static const String adminLogin = '$baseUrl/api/admin/login';
  static const String adminCamps = '$baseUrl/api/admin/camps';
  static const String adminUsers = '$baseUrl/api/admin/users';
  static const String adminCreateCamp = '$baseUrl/api/admin/create-camp';
  static const String adminRegisterDisaster = '$baseUrl/api/admin/register-disaster';
  static const String adminDisasters = '$baseUrl/api/admin/disasters';
  static const String adminInventoryReport = '$baseUrl/api/admin/reports/inventory-donations';
  static const String adminMoneyReport = '$baseUrl/api/admin/reports/money-donations';

  static const String campManagerLogin = '$baseUrl/api/campmanager/auth/login';
  static const String campManagerRegister = '$baseUrl/api/campmanager/auth/register';

  static const String inventory = '$baseUrl/api/inventory';
  static const String campRequest = '$baseUrl/api/campmanager';
  static const String inmates = '$baseUrl/api/inmates';

  static const String donorDonateDirect = '$baseUrl/api/donor/donate-money';
  static const String createRazorpayOrder = '$baseUrl/api/donor/create-razorpay-order';
  static const String verifyRazorpayPayment = '$baseUrl/api/donor/verify-razorpay-payment';

  // Helper method to get disaster endpoint with ID
  static String adminDisaster(String disasterId) => '$baseUrl/api/admin/disaster/$disasterId';

  // Helper method to get inmate endpoint with ID
  static String inmateById(String inmateId) => '$baseUrl/api/inmates/$inmateId';

  // Helper method to get donation not-receive endpoint
  static String donationNotReceive(String donationId) => '$baseUrl/api/campmanager/donations/$donationId/not-receive';
  // Volunteer Endpoints
  static const String volunteerUpgrade = '$baseUrl/api/volunteer/upgrade';
  static const String volunteerSos = '$baseUrl/api/volunteer/sos';
  static String volunteerAcceptSos(String id) => '$baseUrl/api/volunteer/sos/$id/accept';
  static String volunteerResolveSos(String id) => '$baseUrl/api/volunteer/sos/$id/resolve';

  static String adminExpireSos(String id) => '$baseUrl/api/admin/sos/$id/expire';
  static String adminUnexpireSos(String id) => '$baseUrl/api/admin/sos/$id/unexpire';

  // Helper method for donor history
  static String donorHistory(String donorId, String donorName) => '$baseUrl/api/donor/history/$donorId/${Uri.encodeComponent(donorName)}';

  // Helper methods for Admin detailed camp view
  static String inventoryByCamp(String campId) => '$baseUrl/api/inventory/$campId';
  static String inmatesByCamp(String campId) => '$baseUrl/api/inmates/$campId';
}
