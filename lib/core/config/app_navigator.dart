import 'package:flutter/material.dart';

/// Global navigator key attached to MaterialApp to allow top-level routing,
/// such as popping all pushed routes on logout or 401 unauthorized.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
