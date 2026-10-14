# Graph Report - BuyTheWay - Mobile  (2026-10-14)

## Corpus Check
- 127 files · ~177,334 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 53 file(s) not represented in the graph (top: .xcconfig 8, (none) 7, .xml 7)

## Summary
- 3889 nodes · 5253 edges · 144 communities (105 shown, 39 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a79cb014`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- auth_screen.dart
- driver_work_screen.dart
- buyer_models.dart
- driver_models.dart
- courier_dashboard.dart
- buyer_widgets.dart
- settings_widgets.dart
- buyer_store.dart
- driver_shared_widgets.dart
- common.dart
- api_service.dart
- solid_ui.dart
- buyer_api_service.dart
- driver_chat_controller.dart
- driver_profile_info_screen.dart
- checkout_screen.dart
- chat_models.dart
- assigned_delivery_detail_screen.dart
- buyer_theme.dart
- driver_shell.dart
- orders_screen.dart
- StatelessWidget
- driver_deliveries_screen.dart
- order_detail_screen.dart
- product_detail_screen.dart
- chat_thread_screen.dart
- logistics_models.dart
- home_screen.dart
- driver_history_screen.dart
- settings_screens.dart
- address_form_screen.dart
- GeneratedPluginRegistrant.swift
- driver_register_screen.dart
- chat_list_screen.dart
- image_crop_sheet.dart
- State
- brand_logo.dart
- driver_home_screen.dart
- driver_chat_conversation_screen.dart
- my_application.cc
- profile_screen.dart
- driver_chat_list_screen.dart
- driver_login_screen.dart
- driver_theme.dart
- driver_settings_screen.dart
- qr_scan_screen.dart
- driver_payslip_screen.dart
- inventory_detail_screen.dart
- return_request_screen.dart
- reviews_screen.dart
- logistics_inventory_screen.dart
- product_pager.dart
- logistics_shell.dart
- categories_screen.dart
- account_screen.dart
- MaterialPageRoute
- ../widgets/buyer_widgets.dart
- cart_screen.dart
- driver_earnings_screen.dart
- List
- review_sheet.dart
- driver_otp_screen.dart
- order_actions.dart
- SingleTickerProviderStateMixin
- ../buyer_theme.dart
- password_strength_meter.dart
- Win32Window
- logistics_dashboard_screen.dart
- deliver_order_screen.dart
- addresses_screen.dart
- driver_archived_conversations_screen.dart
- win32_window.cpp
- pickup_order_screen.dart
- buyer_shell.dart
- delivery_request_details_screen.dart
- driver_delivery_message_screen.dart
- document_viewer_screen.dart
- variant_sheet.dart
- driver_nav_bar.dart
- courier_navbar.dart
- ../../../services/api_service.dart
- payments_util.dart
- driver_splash_screen.dart
- package:flutter/material.dart
- package:flutter/services.dart
- driver_forgot_password_screen.dart
- utils.cpp
- IconData?
- Development Instructions
- ../driver_theme.dart
- brand_splash_screen.dart
- flutter_window.h
- MessageHandler
- manifest.json
- ../../widgets/driver_shared_widgets.dart
- main.dart
- DriverWorkScreen
- MessageHandler
- VoidCallback?
- Point
- windows/flutter/generated_plugin_registrant.cc
- _CategoriesScreenState
- WorkApplicationStatusCard
- DriverChatController
- MainActivity.kt
- c_users_russel_onedrive_documents_buytheway_folders_buytheway_mobile_ios_runner_generatedpluginregistrant_h
- ApiException
- LaunchImage.imageset/README.md
- AuthScreen
- AddressFormScreen
- _PlacePicker
- CheckoutScreen
- SolidField
- logistics_settings_screen.dart
- CustomPainter
- _AssignedDeliveryDetailScreenState
- _NetworkImageLoader
- EmploymentBanner
- DriverDeliveriesScreen
- _MissionCard
- DriverHistoryScreen
- _HistoryCard
- DriverProfileInfoScreen
- ApplicationStatus
- _ApplyPage
- ResignationRequestSheet
- WorkCompanyCard
- WorkLicensePickerTile
- CourierDashboard
- PickupPriority
- PickupsScreen
- SalaryScreen
- LabeledField
- PressableScale
- @abclogistics
- @email
- @example
- bool?
- String?
- WorkResumePickerTile

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 24 edges
2. `ApiService` - 12 edges
3. `MessageHandler` - 12 edges
4. `Development Instructions` - 11 edges
5. `FlutterWindow` - 10 edges
6. `Create` - 10 edges
7. `WndProc` - 10 edges
8. `DriverChatController` - 9 edges
9. `MessageHandler` - 9 edges
10. `_MyApplication` - 7 edges

## Surprising Connections (you probably didn't know these)
- `OnCreate` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.h → windows/flutter/generated_plugin_registrant.cc
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/runner/my_application.cc → linux/flutter/generated_plugin_registrant.cc
- `main()` --calls--> `my_application_new()`  [INFERRED]
  linux/runner/main.cc → linux/runner/my_application.cc

## Import Cycles
- None detected.

## Communities (144 total, 39 thin omitted)

### Community 0 - "auth_screen.dart"
Cohesion: 0.01
Nodes (240): _addressError, _addressFields, _allControllers, _allRoles, _api, _appBarTitle, AuthPortal, _authToken (+232 more)

### Community 1 - "driver_work_screen.dart"
Cohesion: 0.01
Nodes (211): document_viewer_screen.dart, accent, accessToken, _allRegions, alreadyApplied, _apiService, application, _applicationFormColumn (+203 more)

### Community 2 - "buyer_models.dart"
Cohesion: 0.01
Nodes (168): archived, at, attachments, author, available, avatarUrl, average, awaitingReceipt (+160 more)

### Community 3 - "driver_models.dart"
Cohesion: 0.02
Nodes (115): accountStatus, actualMinutes, amount, applyFrom, assignedAt, AssignedDeliveryItem, AssignedDeliveryStatus, avatarInitial (+107 more)

### Community 4 - "courier_dashboard.dart"
Cohesion: 0.02
Nodes (97): acceptanceRate, actionLabel, address, amount, _bar, _breakdownByPeriod, _breakdownCard, _clock (+89 more)

### Community 5 - "buyer_widgets.dart"
Cohesion: 0.02
Nodes (96): BoxFit, Completer, dart:collection, ImageProvider, ImageStream?, ImageStreamListener?, acquire, action (+88 more)

### Community 6 - "settings_widgets.dart"
Cohesion: 0.03
Nodes (74): ageFor, avatarUrl, background, build, busy, capitalize, children, controller (+66 more)

### Community 7 - "buyer_store.dart"
Cohesion: 0.03
Nodes (78): Address? get, BuyerProfile, addressError, addresses, _addressesLoaded, addToCart, allSelected, api (+70 more)

### Community 8 - "driver_shared_widgets.dart"
Cohesion: 0.03
Nodes (70): ../chat/chat_models.dart, DeliveryStage, accent, actionLabel, attachment, _AttachmentCard, avatarUrl, _bubbles (+62 more)

### Community 9 - "common.dart"
Cohesion: 0.03
Nodes (73): EdgeInsetsGeometry, AppColors, _blob, blur, borderOpacity, borderRadius, build, _c (+65 more)

### Community 10 - "api_service.dart"
Cohesion: 0.03
Nodes (67): bytes, cancelResignationRequest, _configuredBaseUrl, confirmParcelTransfer, deactivateDriverAccount, _deliveryAttemptAction, errors, field (+59 more)

### Community 11 - "solid_ui.dart"
Cohesion: 0.03
Nodes (64): brand_logo.dart, Iterable, autofillHints, build, child, controller, createState, currentIndex (+56 more)

### Community 12 - "buyer_api_service.dart"
Cohesion: 0.03
Nodes (64): api_service.dart, dart:io, addPaymentMethod, addresses, addToWishlist, BuyerApiService, cancelOrder, checkout (+56 more)

### Community 13 - "driver_chat_controller.dart"
Cohesion: 0.03
Nodes (61): _accessToken, _activeConversationId, _api, _appVisible, _attachmentUrlCache, closeConversation, conversationById, _conversations (+53 more)

### Community 14 - "driver_profile_info_screen.dart"
Cohesion: 0.03
Nodes (60): GlobalKey, accessToken, account, _addressCard, _addressLoadError, _addressSectionKey, _api, autoEdit (+52 more)

### Community 15 - "checkout_screen.dart"
Cohesion: 0.03
Nodes (57): ../account/addresses_screen.dart, address, _AddressPanel, _applied, build, cardCvc, cardExpiry, _cardForm (+49 more)

### Community 16 - "chat_models.dart"
Cohesion: 0.03
Nodes (57): allowedTypes, applyFrom, archived, AttachmentPolicy, attachments, bytes, ChatAttachment, ChatConversation (+49 more)

### Community 17 - "assigned_delivery_detail_screen.dart"
Cohesion: 0.04
Nodes (52): ../chat/driver_delivery_message_screen.dart, failed_attempt_sheet.dart, accessToken, _actionTag, _api, _applyScannedProof, _attachPicture, build (+44 more)

### Community 18 - "buyer_theme.dart"
Cohesion: 0.04
Nodes (55): background, base, BButtons, BColors, body, border, BRadius, brand (+47 more)

### Community 19 - "driver_shell.dart"
Cohesion: 0.04
Nodes (51): chat/driver_chat_controller.dart, chat/driver_chat_list_screen.dart, deliveries/driver_deliveries_screen.dart, earnings/driver_earnings_screen.dart, history/driver_history_screen.dart, home/deliver_order_screen.dart, home/delivery_request_details_screen.dart, home/driver_home_screen.dart (+43 more)

### Community 20 - "orders_screen.dart"
Cohesion: 0.04
Nodes (52): build, _busy, _CartButton, controller, createState, dispose, formatDate, _headline (+44 more)

### Community 21 - "StatelessWidget"
Cohesion: 0.04
Nodes (51): Panel, PriceText, ProductCard, QtyStepper, SkeletonBox, _WishHeart, SettingsAvatar, SettingsDateField (+43 more)

### Community 22 - "driver_deliveries_screen.dart"
Cohesion: 0.04
Nodes (51): assigned_delivery_detail_screen.dart, accessToken, _actionsWidth, active, _alertExpanded, atRisk, _atRiskAfter, build (+43 more)

### Community 23 - "order_detail_screen.dart"
Cohesion: 0.04
Nodes (49): EdgeInsets, StatusEvent, _BarButton, _BottomBar, _busy, _buttons, _canReturn, child (+41 more)

### Community 24 - "product_detail_screen.dart"
Cohesion: 0.04
Nodes (48): ../chat/chat_thread_screen.dart, _addToCart, badge, _BottomBar, child, _CircleAction, _claim, claimed (+40 more)

### Community 25 - "chat_thread_screen.dart"
Cohesion: 0.04
Nodes (47): chat_list_screen.dart, ChatAttachment, ChatMessage, api, at, _attach, attachment, _AttachmentView (+39 more)

### Community 26 - "logistics_models.dart"
Cohesion: 0.04
Nodes (45): double?, address, buyer, companyName, confirmationToken, contactNo, courier, dimensions (+37 more)

### Community 27 - "home_screen.dart"
Cohesion: 0.05
Nodes (41): ../account/wishlist_screen.dart, categories_screen.dart, actionLabel, _ActiveOrderCard, alpha, badge, _CategoryRail, _Circle (+33 more)

### Community 28 - "driver_history_screen.dart"
Cohesion: 0.05
Nodes (42): DateTimeRange?, AssignedDelivery, accessToken, _api, avgMinutes, _body, build, _call (+34 more)

### Community 29 - "settings_screens.dart"
Cohesion: 0.05
Nodes (45): ../catalog/product_list_screen.dart, build, busy, busyId, _buyer, BuyerBlockedShopsScreen, _BuyerBlockedShopsScreenState, BuyerFollowingScreen (+37 more)

### Community 30 - "address_form_screen.dart"
Cohesion: 0.05
Nodes (40): _api, barangay, build, city, code, createState, _dec, dispose (+32 more)

### Community 31 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.06
Nodes (28): Any, Cocoa, file_picker, file_selector_macos, Flutter, FlutterAppDelegate, FlutterMacOS, FlutterPluginRegistry (+20 more)

### Community 32 - "driver_register_screen.dart"
Cohesion: 0.09
Nodes (22): driver_otp_screen.dart, build, _confirmController, createState, dispose, DriverRegisterScreen, _DriverRegisterScreenState, _emailController (+14 more)

### Community 33 - "chat_list_screen.dart"
Cohesion: 0.06
Nodes (36): chat_thread_screen.dart, _actions, archived, build, ChatAvatar, ChatListScreen, _ChatListScreenState, chatTimeLabel (+28 more)

### Community 34 - "image_crop_sheet.dart"
Cohesion: 0.06
Nodes (36): dart:ui, Image?, _askImageSource, _baseScale, build, bytes, _clamp, context (+28 more)

### Community 35 - "State"
Cohesion: 0.06
Nodes (52): MyReviewsScreen, _MyReviewsScreenState, PaymentMethodsScreen, _PaymentMethodsScreenState, _ProfileScreenState, VouchersScreen, _VouchersScreenState, WishlistScreen (+44 more)

### Community 36 - "brand_logo.dart"
Cohesion: 0.06
Nodes (33): animations, _bag, BagLogo, _bagPaint, blue, blueDark, blueTint, BrandColors (+25 more)

### Community 37 - "driver_home_screen.dart"
Cohesion: 0.06
Nodes (30): Duration, account, activeDelivery, _activeDeliveryCard, availableRequests, build, _clock, completedToday (+22 more)

### Community 38 - "driver_chat_conversation_screen.dart"
Cohesion: 0.06
Nodes (32): _archivedNotice, _AttachmentSourceSheet, _AttachSource, _body, build, _composer, controller, conversation (+24 more)

### Community 39 - "my_application.cc"
Cohesion: 0.08
Nodes (27): file_selector_plugin, FlPluginRegistry, flutter_linux, FlView, GApplication, gboolean, gchar, gdkx (+19 more)

### Community 40 - "profile_screen.dart"
Cohesion: 0.06
Nodes (31): birthday, build, _changeAvatar, contact, createState, _deactivate, _DeactivateDialog, _DeactivateDialogState (+23 more)

### Community 41 - "driver_chat_list_screen.dart"
Cohesion: 0.07
Nodes (29): driver_archived_conversations_screen.dart, _ArchiveShortcut, build, ChatConversationRow, _content, controller, conversation, createState (+21 more)

### Community 42 - "driver_login_screen.dart"
Cohesion: 0.07
Nodes (29): driver_forgot_password_screen.dart, driver_register_screen.dart, FocusNode, _api, _biometricStub, controller, createState, dispose (+21 more)

### Community 43 - "driver_theme.dart"
Cohesion: 0.07
Nodes (29): background, body, border, caption, DriverButtonStyle, DriverColors, DriverText, error (+21 more)

### Community 44 - "driver_settings_screen.dart"
Cohesion: 0.07
Nodes (27): ../auth/driver_login_screen.dart, driver_change_password_sheet.dart, driver_deactivate_account_dialog.dart, driver_profile_info_screen.dart, driver_vehicle_documents_screen.dart, ../earnings/driver_payslip_screen.dart, accessToken, account (+19 more)

### Community 45 - "qr_scan_screen.dart"
Cohesion: 0.07
Nodes (28): build, _controller, createState, dispose, expectedToken, _feedback, _feedbackTimer, _flashFeedback (+20 more)

### Community 46 - "driver_payslip_screen.dart"
Cohesion: 0.07
Nodes (27): dart:convert, accessToken, build, _busy, _cashout, _client, createState, _date (+19 more)

### Community 47 - "inventory_detail_screen.dart"
Cohesion: 0.08
Nodes (25): ../../driver/deliveries/qr_scan_screen.dart, QrScanResult, accessToken, _api, build, _buildBody, _buildScanBar, createState (+17 more)

### Community 48 - "return_request_screen.dart"
Cohesion: 0.08
Nodes (24): dart:typed_data, ImageSource, OrderItem, _addPhoto, build, createState, details, dispose (+16 more)

### Community 49 - "reviews_screen.dart"
Cohesion: 0.09
Nodes (22): int?, Review, ReviewSummary, build, _chip, createState, error, initialSummary (+14 more)

### Community 50 - "logistics_inventory_screen.dart"
Cohesion: 0.08
Nodes (24): inventory_detail_screen.dart, accessToken, build, createState, dispose, emptyIcon, emptySubtitle, emptyTitle (+16 more)

### Community 51 - "product_pager.dart"
Cohesion: 0.08
Nodes (23): buyer_widgets.dart, category, dispose, _disposed, error, false, handleNearEnd, hasMore (+15 more)

### Community 52 - "logistics_shell.dart"
Cohesion: 0.09
Nodes (23): dashboard/logistics_dashboard_screen.dart, inventory/logistics_inventory_screen.dart, _accessToken, _account, _accountLoadError, _api, build, createState (+15 more)

### Community 53 - "categories_screen.dart"
Cohesion: 0.09
Nodes (22): home_screen.dart, build, createState, dispose, _pagerFor, _pagers, _selected, wantKeepAlive (+14 more)

### Community 54 - "account_screen.dart"
Cohesion: 0.09
Nodes (22): addresses_screen.dart, AccountScreen, build, count, icon, label, onOpen, onTap (+14 more)

### Community 55 - "MaterialPageRoute"
Cohesion: 0.09
Nodes (22): build, _checkout, build, _open, build, openCourierChat, build, build (+14 more)

### Community 56 - "../widgets/buyer_widgets.dart"
Cohesion: 0.08
Nodes (23): build, createState, _delete, _edit, error, initState, _load, reviews (+15 more)

### Community 57 - "cart_screen.dart"
Cohesion: 0.09
Nodes (23): ../checkout/checkout_screen.dart, DateTime?, CartItem, _CartLine, CartScreen, _CartScreenState, _CheckoutBar, createState (+15 more)

### Community 58 - "driver_earnings_screen.dart"
Cohesion: 0.10
Nodes (21): double get, EarningsPeriod, availableBalance, _balanceCard, _breakdown, _breakdownCard, build, createState (+13 more)

### Community 59 - "List"
Cohesion: 0.11
Nodes (18): ../buyer_models.dart, ../buyer_shell.dart, build, createState, error, initState, _load, loading (+10 more)

### Community 60 - "review_sheet.dart"
Cohesion: 0.10
Nodes (21): build, comment, createState, dispose, false, initialComment, initialRating, orderItemId (+13 more)

### Community 61 - "driver_otp_screen.dart"
Cohesion: 0.10
Nodes (21): build, _code, _controllers, createState, _demoCode, dispose, DriverOtpScreen, _DriverOtpScreenState (+13 more)

### Community 62 - "order_actions.dart"
Cohesion: 0.10
Nodes (20): Order, added, build, busy, _cancel, _cancelReasons, _CancelSheet, _CancelSheetState (+12 more)

### Community 63 - "SingleTickerProviderStateMixin"
Cohesion: 0.10
Nodes (21): DriverSplashScreen, _DriverSplashScreenState, _PulsingDot, _PulsingDotState, DriverShimmerBox, _DriverShimmerBoxState, _DriverTopNotificationCard, _DriverTopNotificationCardState (+13 more)

### Community 64 - "../buyer_theme.dart"
Cohesion: 0.11
Nodes (18): ../buyer_store.dart, ../buyer_theme.dart, build, createState, _delete, error, initState, _load (+10 more)

### Community 65 - "password_strength_meter.dart"
Cohesion: 0.11
Nodes (18): bool get, build, label, meetsMinimum, of, password, PasswordRule, PasswordStrength (+10 more)

### Community 66 - "Win32Window"
Cohesion: 0.15
Nodes (19): FlutterViewController, RECT, unique_ptr, FlutterWindow, flutter_controller_, OnCreate, OnDestroy, project_ (+11 more)

### Community 67 - "logistics_dashboard_screen.dart"
Cohesion: 0.11
Nodes (18): int get, account, build, color, error, _fromPickup, _fromTransferDeparture, _fromTransferReceipt (+10 more)

### Community 68 - "deliver_order_screen.dart"
Cohesion: 0.12
Nodes (16): _arrived, _attachPhoto, build, _contactStub, createState, delivery, dispose, _handleArrived (+8 more)

### Community 69 - "addresses_screen.dart"
Cohesion: 0.12
Nodes (17): address_form_screen.dart, Color, AddressesScreen, _AddressesScreenState, build, color, createState, _delete (+9 more)

### Community 70 - "driver_archived_conversations_screen.dart"
Cohesion: 0.11
Nodes (18): dart:async, driver_chat_conversation_screen.dart, driver_chat_list_screen.dart, build, controller, _conversations, createState, _debounce (+10 more)

### Community 71 - "win32_window.cpp"
Cohesion: 0.17
Nodes (14): dwmapi, wchar_t, Scale(), Create, Destroy, GetHandle, SetQuitOnClose, Win32Window::Win32Window() (+6 more)

### Community 72 - "pickup_order_screen.dart"
Cohesion: 0.12
Nodes (15): ActiveDelivery, _arrived, _attachPhoto, build, _contactStub, createState, delivery, _handleArrived (+7 more)

### Community 73 - "buyer_shell.dart"
Cohesion: 0.12
Nodes (16): account/account_screen.dart, ../cart/cart_screen.dart, catalog/home_screen.dart, chat/chat_list_screen.dart, _backToSignIn, build, BuyerShell, _BuyerShellState (+8 more)

### Community 74 - "delivery_request_details_screen.dart"
Cohesion: 0.13
Nodes (14): DeliveryRequest, _accept, _addressRow, build, createState, _decline, dispose, initState (+6 more)

### Community 75 - "driver_delivery_message_screen.dart"
Cohesion: 0.14
Nodes (14): chat_models.dart, ChatConversation?, driver_chat_controller.dart, build, contact, controller, _conversation, createState (+6 more)

### Community 76 - "document_viewer_screen.dart"
Cohesion: 0.13
Nodes (15): driver_work_screen.dart, build, _controller, createState, DocumentViewerScreen, _DocumentViewerScreenState, _failed, initState (+7 more)

### Community 77 - "variant_sheet.dart"
Cohesion: 0.13
Nodes (14): ProductVariant, build, createState, initState, mode, product, quantity, selected (+6 more)

### Community 78 - "driver_nav_bar.dart"
Cohesion: 0.12
Nodes (15): badgeCount, build, currentIndex, DriverNavBar, _DriverNavItem, _handleTap, icon, _inactive (+7 more)

### Community 79 - "courier_navbar.dart"
Cohesion: 0.12
Nodes (15): badgeCount, build, createState, currentIndex, dispose, _handleTap, icon, _inactive (+7 more)

### Community 80 - "../../../services/api_service.dart"
Cohesion: 0.08
Nodes (23): codeDigits, codeInputs, confirmPassword, context, error, newPassword, obscure1, sending (+15 more)

### Community 81 - "payments_util.dart"
Cohesion: 0.13
Nodes (14): alt, d, detectCardBrand, digits, digitsOnly, expiryPassed, luhnValid, m (+6 more)

### Community 82 - "driver_splash_screen.dart"
Cohesion: 0.13
Nodes (14): Animation, driver_login_screen.dart, ../driver_shell.dart, _api, build, _controller, createState, dispose (+6 more)

### Community 83 - "package:flutter/material.dart"
Cohesion: 0.15
Nodes (11): ElevatedButton, build, _buildFeatureItem, SidePanel, package:buytheway/screens/driver/deliveries/failed_attempt_sheet.dart, package:ecommerce/main.dart, package:flutter/material.dart, package:flutter_test/flutter_test.dart (+3 more)

### Community 84 - "package:flutter/services.dart"
Cohesion: 0.14
Nodes (13): badgeCount, build, BuyerNavBar, currentIndex, _handleTap, icon, _inactive, label (+5 more)

### Community 85 - "driver_forgot_password_screen.dart"
Cohesion: 0.15
Nodes (13): build, createState, dispose, DriverForgotPasswordScreen, _DriverForgotPasswordScreenState, _emailController, _error, _formState (+5 more)

### Community 86 - "utils.cpp"
Cohesion: 0.19
Nodes (12): flutter_windows, _In_, _In_opt_, io, iostream, stdio, wWinMain(), string (+4 more)

### Community 87 - "IconData?"
Cohesion: 0.15
Nodes (12): IconData?, build, currentIndex, _handleTap, icon, _items, label, LogisticsNavBar (+4 more)

### Community 88 - "Development Instructions"
Cohesion: 0.17
Nodes (11): Code Changes, Code Quality & Performance, Communication, Development Instructions, Existing Functionality, Perceived Performance, Project Location, Redesign Permission (+3 more)

### Community 89 - "../driver_theme.dart"
Cohesion: 0.18
Nodes (11): ../driver_theme.dart, FormState, build, createState, _description, dispose, FailedAttemptSheet, _FailedAttemptSheetState (+3 more)

### Community 90 - "brand_splash_screen.dart"
Cohesion: 0.18
Nodes (10): AnimationController, ../auth/auth_screen.dart, dart:math, build, _controller, createState, dispose, initState (+2 more)

### Community 91 - "flutter_window.h"
Cohesion: 0.27
Nodes (7): dart_project, flutter_view_controller, functional, memory, string, vector, windows

### Community 92 - "MessageHandler"
Cohesion: 0.18
Nodes (10): generated_plugin_registrant, optional, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM (+2 more)

### Community 93 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 94 - "../../widgets/driver_shared_widgets.dart"
Cohesion: 0.25
Nodes (7): ../driver_models.dart, DriverAccount, account, build, createState, _refresh, ../../widgets/driver_shared_widgets.dart

### Community 95 - "main.dart"
Cohesion: 0.20
Nodes (9): build, main, MyApp, screens/buyer/buyer_shell.dart, screens/driver/auth/driver_splash_screen.dart, screens/driver/driver_shell.dart, screens/logistics/logistics_shell.dart, screens/pickup_courier/courier_dashboard.dart (+1 more)

### Community 97 - "MessageHandler"
Cohesion: 0.38
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetThisFromHandle, MessageHandler (+2 more)

### Community 98 - "VoidCallback?"
Cohesion: 0.25
Nodes (7): common.dart, build, isFullWidth, label, onPressed, OutlineActionButton, VoidCallback?

### Community 99 - "Point"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

### Community 100 - "windows/flutter/generated_plugin_registrant.cc"
Cohesion: 0.29
Nodes (5): file_selector_windows, plugin_registry, PluginRegistry, url_launcher_windows, RegisterPlugins()

### Community 101 - "_CategoriesScreenState"
Cohesion: 0.33
Nodes (6): AutomaticKeepAliveClientMixin, HomeScreen, CategoriesScreen, _CategoriesScreenState, _HomeScreenState, _HomeScreenState

### Community 103 - "DriverChatController"
Cohesion: 0.50
Nodes (4): ChangeNotifier, BuyerStore, ProductPager, DriverChatController

### Community 113 - "logistics_settings_screen.dart"
Cohesion: 0.15
Nodes (12): ../../driver/driver_theme.dart, ../../driver/settings/driver_change_password_sheet.dart, ../../driver/settings/widgets/settings_widgets.dart, ../../driver/widgets/driver_shared_widgets.dart, LogisticsAccount, accessToken, account, build (+4 more)

### Community 114 - "CustomPainter"
Cohesion: 0.33
Nodes (6): CustomPainter, _StripePainter, _RouteGridPainter, _RoutePathPainter, _BagLogoPainter, _GoogleMarkPainter

### Community 115 - "_AssignedDeliveryDetailScreenState"
Cohesion: 0.67
Nodes (3): AssignedDeliveryDetailScreen, _AssignedDeliveryDetailScreenState, WidgetsBindingObserver

## Knowledge Gaps
- **2951 isolated node(s):** `main`, `build`, `AuthPortal`, `kRegionOptions`, `kIdTypeOptions` (+2946 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 3127 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **39 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ApiService` connect `driver_splash_screen.dart` to `auth_screen.dart`, `driver_work_screen.dart`, `api_service.dart`, `driver_settings_screen.dart`, `driver_chat_controller.dart`, `driver_profile_info_screen.dart`, `inventory_detail_screen.dart`, `assigned_delivery_detail_screen.dart`, `driver_shell.dart`, `logistics_shell.dart`, `driver_history_screen.dart`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `Win32Window` connect `Win32Window` to `MessageHandler`, `Point`, `win32_window.cpp`, `flutter_window.h`, `MessageHandler`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **What connects `main`, `build`, `AuthPortal` to the rest of the system?**
  _2951 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `auth_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.008298755186721992 - nodes in this community are weakly interconnected._
- **Should `driver_work_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.009433962264150943 - nodes in this community are weakly interconnected._
- **Should `buyer_models.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.011834319526627219 - nodes in this community are weakly interconnected._
- **Should `driver_models.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.017241379310344827 - nodes in this community are weakly interconnected._