/// What onboarding asks for, in the order it offers it. The values are the
/// server's own, so they travel to the API unchanged.
const kGenderOptions = ['Male', 'Female', 'Other'];

/// The label for a stored value. Accounts created before onboarding asked can
/// carry "Prefer not to say", which is no longer offered but still shown.
String genderLabelKey(String value) => switch (value) {
  'Male' => 'profile.gender.male',
  'Female' => 'profile.gender.female',
  'Other' => 'profile.gender.other',
  _ => 'profile.gender.prefer_not_to_say',
};
