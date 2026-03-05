import 'package:get/get.dart';
import '../services/firestore_services/admin_access_service.dart';
import '../services/app_update_service.dart';
import '../services/firestore_services/companydata_service.dart';
import '../services/firestore_services/shipdata_service.dart';
import '../services/firestore_services/transactiondata_service.dart';
import '../services/firestore_services/tripdata_service.dart';
import '../services/firestore_services/user_access_service.dart';
import '../services/firestore_services/userdata_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/local_otp_service.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<AppUpdateService>(AppUpdateService(), permanent: true);
    Get.put<AuthService>(AuthService(), permanent: true);
    Get.put<AdminAccessService>(AdminAccessService(), permanent: true);
    Get.put<UserAccessService>(UserAccessService(), permanent: true);
    Get.put<FirestoreUserService>(FirestoreUserService(), permanent: true);
    Get.put<FirestoreCompanyService>(
      FirestoreCompanyService(),
      permanent: true,
    );
    Get.put<FirestoreShipService>(FirestoreShipService(), permanent: true);
    Get.put<FirestoreTripService>(FirestoreTripService(), permanent: true);
    Get.put<FirestoreTransactionService>(
      FirestoreTransactionService(),
      permanent: true,
    );
    Get.put<LocalOtpService>(LocalOtpService(), permanent: true);
  }
}
