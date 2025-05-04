import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pet_watch/map_logic/services/custom-notification.dart';

class NotificationService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  final bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  //initialize
  Future<void> initNotification() async{
    if(_isInitialized)//preventing reinitialization
    {
      return;
    }
    //for andrioid
    const initSettingsAndroid = AndroidInitializationSettings('pet_watch_logo');

    //for ios
    const initSettingsiOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
   // macOS settings
  const macosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsiOS,
    );
    
    await notificationsPlugin.initialize(initSettings);
  }

  //notifications detailed setup
NotificationDetails notificationDetails(){
  return const NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_channel_id', 
      'Daily Notifications',
      channelDescription: 'Daily Notifications Channel',
      importance: Importance.max
      ),
      iOS: DarwinNotificationDetails(

      )
  );
}
  //show notifications
Future<void> showCustomNotification(CustomNotification customNotif) async {
  await notificationsPlugin.show(
    0,
    customNotif.title,
    customNotif.body,
    notificationDetails(),
    payload: '${customNotif.title}|${customNotif.body}|${customNotif.imageUrl}|${customNotif.time}',
  );
}


  //on noti tap
}
