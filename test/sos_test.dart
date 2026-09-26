import 'package:flutter_test/flutter_test.dart';
import 'package:rovlo/services/sos_service.dart';

void main() {
  const place = SosSnapshot(
    lat: 22.572646,
    lng: 88.363895,
    address: 'Park Street, Kolkata, West Bengal',
    countryCode: 'IN',
  );

  test('emergency number follows the country (112 by default)', () {
    expect(SosService.emergencyNumber('IN'), '112');
    expect(SosService.emergencyNumber(null), '112');
    expect(SosService.emergencyNumber('us'), '911');
    expect(SosService.emergencyNumber('GB'), '999');
    expect(SosService.emergencyNumber('AU'), '000');
    expect(SosService.emergencyNumber('DE'), '112');
  });

  test('the SOS message carries name, map link and address', () {
    final m = SosService.buildMessage(name: 'Asha', location: place);
    expect(m, contains('EMERGENCY'));
    expect(m, contains('Asha'));
    expect(m, contains('https://www.google.com/maps?q=22.572646,88.363895'));
    expect(m, contains('Park Street, Kolkata'));
  });

  test('without a location the message asks to be called', () {
    final m = SosService.buildMessage(name: '', location: null);
    expect(m, contains('A Rovlo traveler'));
    expect(m, contains('call me'));
    expect(m, isNot(contains('maps')));
  });

  test('phone numbers are cleaned, deduplicated and junk is dropped', () {
    final n = SosService.cleanNumbers([
      {'name': 'A', 'phone': '+91 98765-43210'},
      {'name': 'B', 'phone': '(+91) 98765 43210'}, // same number
      {'name': 'C', 'phone': ''},
      {'name': 'D', 'phone': '12'},
      {'name': 'E', 'phone': '033 2222 1111'},
    ]);
    expect(n, ['+919876543210', '03322221111']);
  });

  test('sms link is pre-filled, %20 not +, and recipient list joined', () {
    final body = SosService.buildMessage(name: 'Asha', location: place);
    final android = SosService.smsUri(['+919876543210', '100'], body, ios: false);
    expect(android.scheme, 'sms');
    expect(android.toString(), startsWith('sms:+919876543210,100?body='));
    expect(android.toString(), isNot(contains('+Asha')));
    expect(android.toString(), contains('%20'));
    final ios = SosService.smsUri(['100'], 'hi', ios: true);
    expect(ios.toString(), 'sms:100&body=hi');
  });
}
