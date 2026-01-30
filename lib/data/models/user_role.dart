enum UserRole {
  customer('customer'),
  merchant('merchant'),
  superAdmin('super_admin');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.customer,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.merchant:
        return 'Merchant';
      case UserRole.superAdmin:
        return 'Super Admin';
    }
  }

  bool get isCustomer => this == UserRole.customer;
  bool get isMerchant => this == UserRole.merchant;
  bool get isSuperAdmin => this == UserRole.superAdmin;
}