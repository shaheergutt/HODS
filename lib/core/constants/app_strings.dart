class AppStrings {
  // App
  static const String appName = 'HODS';
  static const String appFullName = 'Hostel Online Distribution System';
  static const String appTagline = 'Find Your Perfect Hostel';

  // Auth
  static const String login = 'Login';
  static const String register = 'Register';
  static const String email = 'Email Address';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String fullName = 'Full Name';
  static const String phoneNumber = 'Phone Number';
  static const String forgotPassword = 'Forgot Password?';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String signUp = 'Sign Up';
  static const String signIn = 'Sign In';
  static const String logout = 'Logout';

  // Roles
  static const String student = 'Student';
  static const String hostelOwner = 'Hostel Owner';
  static const String admin = 'Super Admin';
  static const String iAmStudent = 'I am a Student';
  static const String iAmOwner = 'I am a Hostel Owner';

  // Hostel
  static const String searchHint = 'Search by city or hostel name...';
  static const String allHostels = 'All Hostels';
  static const String recommended = 'Recommended For You';
  static const String perMonth = '/month';
  static const String facilities = 'Facilities';
  static const String bookNow = 'Book Now';
  static const String viewDetails = 'View Details';
  static const String availableRooms = 'Available Rooms';
  static const String totalRooms = 'Total Rooms';

  // Facilities
  static const List<String> facilityList = [
    'WiFi',
    'AC',
    'Meals',
    'Laundry',
    'Parking',
    'Gym',
    '24/7 Security',
    'Hot Water',
    'Study Room',
    'CCTV',
    'Generator',
  ];

  // Cities
  static const List<String> cities = [
    'Karachi',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Peshawar',
    'Quetta',
    'Multan',
    'Hyderabad',
    'Sialkot',
  ];

  // Status
  static const String pending = 'Pending';
  static const String confirmed = 'Confirmed';
  static const String cancelled = 'Cancelled';
  static const String completed = 'Completed';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';

  // Errors
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email';
  static const String passwordTooShort =
      'Password must be at least 6 characters';
  static const String passwordMismatch = 'Passwords do not match';
  static const String somethingWentWrong = 'Something went wrong. Try again.';

  // AI
  static const String aiAgentName = 'HODS Assistant';
  static const String aiSystemPrompt =
      '''You are HODS AI Assistant, a helpful customer service agent for the HODS (Hostel Online Distribution System) app. 
You help students find hostels, answer questions about hostel bookings, explain app features, and provide support.
Be friendly, concise, and professional. If asked about specific hostel availability or pricing, explain that the student should use the search feature in the app.
Keep responses under 150 words unless a detailed explanation is needed.''';

  // Admin
  static const String adminEmail = 'admin@hods.com';
  static const String adminPassword = 'Admin@HODS2024';

  // About
  static const String aboutDescription =
      'HODS (Hostel Online Distribution System) is a smart hostel booking platform designed to connect students with verified hostel owners across Pakistan. '
      'Our AI-powered recommendation engine helps students find the perfect hostel based on their preferences, location, and budget. '
      'All hostel owners are verified and licensed by HODS to ensure safety and quality for every student.';

  static const String contactEmail = 'support@hods.com';
  static const String contactPhone = '+92-300-HODS-APP';
  static const String contactAddress = 'HODS Head Office, Karachi, Pakistan';
}
