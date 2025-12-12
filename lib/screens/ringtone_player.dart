import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

void playRingtone() {
  FlutterRingtonePlayer().playRingtone(
    looping: true,                      // lặp liên tục đến khi stop
    volume: 1.0,
    asAlarm: false,
  );
}

void stopRingtone() {
  FlutterRingtonePlayer().stop();
}
