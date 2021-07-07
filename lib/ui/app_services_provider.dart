import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../service/app_services.dart';
import '../service/auth/auth_manager.dart';
import '../util/extension/extension.dart';

class AppServicesProvider extends HookWidget {
  const AppServicesProvider({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final appServices = useListenable(useMemoized(() => AppServices()));
    useEffect(() => appServices.dispose, []);

    if (isLogin && !appServices.databaseInitialized) {
      return const SizedBox();
    }

    return ChangeNotifierProvider.value(
      value: appServices,
      child: child,
    );
  }
}