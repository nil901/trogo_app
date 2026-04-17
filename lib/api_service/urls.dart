String apiRootUrl = 'https://api.togoodsdraft.com';
String baseUrl = '$apiRootUrl/api/';
String socketBaseUrl = apiRootUrl;

String loginEndPoint = '${baseUrl}auth/login';
String requestOtpEndPoint = '${baseUrl}auth/request-otp';
String verifyOtpEndPoint = '${baseUrl}auth/verify-otp';
String fcmTokan = '${baseUrl}passenger/save-token';
String vehicletypes = '${baseUrl}passenger/vehicle-types?';
String history = '${baseUrl}passenger/history';
String banarUrl = '${baseUrl}passenger/banners';
String fareEstimateUrl = '${baseUrl}passenger/fare-estimate';
String profileGet = '${baseUrl}auth/profile';
String profileUpdate = '${baseUrl}auth/profile';
String transportVehicleGet = '${baseUrl}passenger/suggestions';
String noticationGet = '${baseUrl}notification';
String noticationDelete = '${baseUrl}notification/delete';
String noticationCreate = '${baseUrl}notification';
String signup = '${baseUrl}auth/signup';
String recentDropUrl = '${baseUrl}recent-drop';

String bookingsBaseUrl = '${baseUrl}bookings';
String bookingCreateUrl = '$bookingsBaseUrl/bookings';
String bookingCancelUrl = '$bookingsBaseUrl/cancel';
String bookingCompleteAndRateUrl = '$bookingsBaseUrl/complete-and-rate';
String transporterGlobalStatusUrl = '${baseUrl}transporter/global-status';

const String notificationList = '/notification';        // GET request - Fetch all notifications
const String notificationDelete = '/notification-delete'; // POST request - Delete notification

const String recentDropList = '/recent-drop';  // GET request - Fetch recent drops
