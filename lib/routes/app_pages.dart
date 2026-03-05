import 'package:get/get.dart';
import 'app_routes.dart';
import '../modules/auth/auth.dart';
import '../modules/company/add_company/add_company_controller.dart';
import '../modules/company/add_company/add_company_view.dart';
import '../modules/company/company_details/company_details_controller.dart';
import '../modules/company/company_details/company_details_view.dart';
import '../modules/company/company_list/company_list_controller.dart';
import '../modules/company/company_list/company_list_view.dart';
import '../modules/Transactions/expenses/add_transaction/add_expenses_transaction_controller.dart';
import '../modules/Transactions/expenses/add_transaction/add_expenses_transaction_view.dart';
import '../modules/Transactions/payments/add_transaction/add_payment_transaction_controller.dart';
import '../modules/Transactions/payments/add_transaction/add_payment_transaction_view.dart';
import '../modules/Transactions/payments/transaction_details/transaction_details_controller.dart';
import '../modules/Transactions/payments/transaction_details/transaction_details_view.dart';
import '../modules/Transactions/transactions_history/transaction_history_controller.dart';
import '../modules/Transactions/transactions_history/transaction_history_view.dart';
import '../modules/home/home.dart';
import '../modules/ship/add_ship/add_ship_controller.dart';
import '../modules/ship/add_ship/add_ship_view.dart';
import '../modules/ship/ship_details/ship_details_view.dart';
import '../modules/ship/ship_details/ship_detials_controller.dart';
import '../modules/ship/ship_list/ship_list_controller.dart';
import '../modules/ship/ship_list/ship_list_view.dart';
import '../modules/trip/add_trips/add_trip_controller.dart';
import '../modules/trip/add_trips/add_trip_view.dart';
import '../modules/trip/trip_details/trip_details_controller.dart';
import '../modules/trip/trip_details/trip_detials_view.dart';
import '../modules/trip/trip_history/trip_hisotry_controller.dart';
import '../modules/trip/trip_history/trip_history_view.dart';
import '../core/bootstrap/bootstrap_controller.dart';
import '../core/bootstrap/bootstrap_view.dart';
import '../modules/auth/firebase_verification/firebase_verification_view.dart';
import '../modules/auth/firebase_verification/firebase_verification_controller.dart';
import '../modules/admin/admin_users/admin_users_controller.dart';
import '../modules/admin/admin_users/admin_users_view.dart';
import '../modules/home/blocked/blocked_controller.dart';
import '../modules/home/blocked/blocked_view.dart';
import '../modules/update/force_update/force_update_controller.dart';
import '../modules/update/force_update/force_update_view.dart';
import '../core/services/firestore_services/users_export_service.dart';

class AppPages {
  AppPages._(); // private constructor to prevent instantiation

  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.bootstrap,
      page: () => const BootstrapView(),
      binding: BindingsBuilder(() {
        Get.put(BootstrapController());
      }),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => LoginController());
      }),
    ),
    GetPage(
      name: AppRoutes.signup,
      page: () => const SignupView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => SignupController());
      }),
    ),
    GetPage(
      name: AppRoutes.otpVerification,
      page: () => const OtpVerificationView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => OtpVerificationController());
      }),
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ForgotPasswordController());
      }),
    ),
    GetPage(
      name: AppRoutes.resetPassword,
      page: () => const ResetPasswordView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ResetPasswordController());
      }),
    ),
    GetPage(
      name: AppRoutes.lockedAccount,
      page: () => const BlockedView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => BlockedController());
      }),
    ),
    GetPage(
      name: AppRoutes.forceUpdate,
      page: () => const ForceUpdateView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ForceUpdateController());
      }),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => HomeController());
      }),
    ),
    GetPage(
      name: AppRoutes.shipList,
      page: () => const ShipListView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ShipListController());
      }),
    ),
    GetPage(
      name: AppRoutes.shipDetails,
      page: () => const ShipDetailsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ShipDetailsController());
      }),
    ),
    GetPage(
      name: AppRoutes.companyList,
      page: () => const CompanyListView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => CompanyListController());
      }),
    ),
    GetPage(
      name: AppRoutes.companyDetails,
      page: () => const CompanyDetailsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => CompanyDetailsController());
      }),
    ),
    GetPage(
      name: AppRoutes.addShip,
      page: () => const AddShipView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AddShipController());
      }),
    ),
    GetPage(
      name: AppRoutes.addTrip,
      page: () => const AddTripView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AddTripController());
      }),
    ),
    GetPage(
      name: AppRoutes.addTransaction,
      page: () => const AddTransactionView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AddTransactionController());
      }),
    ),
    GetPage(
      name: AppRoutes.addExpensesTransaction,
      page: () => const AddExpensesTransactionView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AddExpensesTransactionController());
      }),
    ),
    GetPage(
      name: AppRoutes.transactionHistory,
      page: () => const TransactionHistoryView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => TransactionHistoryController());
      }),
    ),
    GetPage(
      name: AppRoutes.transactionDetails,
      page: () => const TransactionDetailsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => TransactionDetailsController());
      }),
    ),
    GetPage(
      name: AppRoutes.tripHistory,
      page: () => const TripHistoryView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => TripHistoryController());
      }),
    ),
    GetPage(
      name: AppRoutes.tripDetails,
      page: () => const TripDetailsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => TripDetailsController());
      }),
    ),
    GetPage(
      name: AppRoutes.addCompany,
      page: () => const AddCompanyView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AddCompanyController());
      }),
    ),
    GetPage(
      name: AppRoutes.adminUsers,
      page: () => const AdminUsersView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AdminUsersController());
        Get.lazyPut<UsersExportService>(() => UsersExportService());
      }),
    ),
    GetPage(
      name: AppRoutes.firebaseEmailVerification,
      page: () => const FirebaseVerificationView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => FirebaseVerificationController());
      }),
    ),
    GetPage(
      name: AppRoutes.postVerificationDetails,
      page: () => const PostVerificationDetailsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => PostVerificationDetailsController());
      }),
    ),
  ];
}
