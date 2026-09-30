import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/access/panel_access.dart';
import 'package:tulasisolutionssite/core/models/models.dart';

void main() {
  test('staff without explicit panels can access all personal sections', () {
    final staff = AppUser(
      uid: 'staff@example.com',
      email: 'staff@example.com',
      name: 'Staff Member',
      isAdmin: false,
      isStaff: true,
    );

    expect(hasGrantedAdminPanel(staff), isTrue);
    for (final route in [
      '/admin/my-dashboard',
      '/admin/my-performance',
      '/admin/my-tasks',
      '/admin/my-completed-tasks',
    ]) {
      expect(canAccessAdminPanel(staff, panelForAdminRoute(route)!), isTrue);
    }
    expect(firstGrantedAdminRoute(staff), '/admin/my-dashboard');
    for (final panel in ['users', 'tasks', 'performance', 'payments', 'chat']) {
      expect(canAccessAdminPanel(staff, panel), isFalse);
    }
  });

  test('ordinary authenticated accounts do not gain personal staff access', () {
    final user = AppUser(
      uid: 'ordinary-user',
      email: 'user@example.com',
      name: 'User',
      isAdmin: false,
    );
    for (final panel in defaultStaffPanels) {
      expect(canAccessAdminPanel(user, panel), isFalse);
      expect(canAccessAdminPanel(null, panel), isFalse);
    }
  });
}
