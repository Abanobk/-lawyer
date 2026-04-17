/// تسمية عربية لدور المستخدم في المكتب (بند الصلاحيات/الأدوار في الواجهة).
String roleLabelAr(String role) {
  switch (role) {
    case 'office_owner':
      return 'مالك المكتب';
    case 'lawyer':
      return 'محامٍ';
    case 'secretary':
      return 'سكرتارية';
    case 'accountant':
      return 'محاسب';
    case 'employee':
      return 'موظف';
    default:
      return role;
  }
}
