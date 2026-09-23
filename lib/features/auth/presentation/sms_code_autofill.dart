import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:smart_auth/smart_auth.dart';

/// Android only: asks to read the next SMS through the User Consent API and
/// hands back its 6-digit code. Our DLT template carries no app hash, so the
/// zero-tap Retriever API is not an option. On iOS the code field's
/// `oneTimeCode` autofill hint does the job instead.
void useSmsCodeAutofill({
  required Object? key,
  required ValueChanged<String> onCode,
}) {
  final latestOnCode = useRef(onCode)..value = onCode;
  useEffect(() {
    if (key == null ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    var active = true;
    SmartAuth.instance.getSmsWithUserConsentApi(matcher: r'\d{6}').then((res) {
      final code = res.data?.code;
      if (active && code != null) latestOnCode.value(code);
    });
    return () {
      active = false;
      SmartAuth.instance.removeUserConsentApiListener();
    };
  }, [key]);
}
