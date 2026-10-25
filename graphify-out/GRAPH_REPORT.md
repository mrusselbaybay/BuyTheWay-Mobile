# Graph Report - BuyTheWay - Mobile  (2026-10-25)

## Corpus Check
- 169 files · ~244,630 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 54 file(s) not represented in the graph (top: .xcconfig 8, (none) 7, .xml 7)

## Summary
- 5663 nodes · 7720 edges · 182 communities (145 shown, 37 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9a750ea2`
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
- courier_home_screen.dart
- account_screen.dart
- MaterialPageRoute
- vouchers_screen.dart
- cart_screen.dart
- driver_earnings_screen.dart
- wishlist_screen.dart
- review_sheet.dart
- driver_otp_screen.dart
- order_actions.dart
- poller.dart
- search_screen.dart
- bool get
- Win32Window
- logistics_dashboard_screen.dart
- deliver_order_screen.dart
- addresses_screen.dart
- driver_archived_conversations_screen.dart
- win32_window.cpp
- pickup_order_screen.dart
- buyer_shell.dart
- ../driver_theme.dart
- ../widgets/buyer_widgets.dart
- document_viewer_screen.dart
- variant_sheet.dart
- logistics_settings_screen.dart
- courier_navbar.dart
- ../services/api_service.dart
- payments_util.dart
- driver_splash_screen.dart
- package:flutter/material.dart
- notification_inbox.dart
- chat_assistant.dart
- utils.cpp
- DriverChatController
- Development Instructions
- report_delivered_sheet.dart
- payment_qr_screen.dart
- Map
- MessageHandler
- manifest.json
- buyer_payment_qr_card.dart
- main.dart
- store_screen.dart
- driver_forgot_password_screen.dart
- VoidCallback?
- string
- windows/flutter/generated_plugin_registrant.cc
- my_reviews_screen.dart
- my_reports_screen.dart
- logistics_notifications_screen.dart
- MainActivity.kt
- c_users_russel_onedrive_documents_buytheway_folders_buytheway_mobile_ios_runner_generatedpluginregistrant_h
- remittances_test.dart
- LaunchImage.imageset/README.md
- AuthScreen
- remittances_screen.dart
- parcel_tracking.dart
- driver_chat_settle_test.dart
- address_pin_picker.dart
- remittance_action_screen.dart
- MessageHandler
- remittance_api_service.dart
- remittance_detail_screen.dart
- voucher_quote.dart
- ApiException
- Point
- settings_kit.dart
- voucher_sheet.dart
- search_filter_sheet.dart
- ApplicationStatus
- ../buyer_theme.dart
- address_sheet.dart
- List
- SliverPersistentHeaderDelegate
- success_popup.dart
- sign_in_methods_sheets.dart
- Color?
- StatefulWidget
- SingleTickerProviderStateMixin
- PressableScale
- @abclogistics
- @email
- @example
- bool?
- String?
- _TicketClipper
- payment_methods_screen.dart
- notifications_screen.dart
- sign_in_methods_section.dart
- static const
- brand_splash_screen.dart
- push_service.dart
- chat_notification.dart
- google_auth_service.dart
- package:flutter/services.dart
- BuyerReportDetailScreen
- _AllTab
- _VoucherHistoryScreen
- _ReportSheet
- StoreScreen
- ProductDetailScreen
- BuyerReportsScreen
- driver_delivery_message_screen.dart
- remittance_format.dart
- dart:async
- dart:typed_data
- driver_notifications_screen.dart
- BuyerBlockedShopsScreen
- ChatThreadScreen
- _AuroraBackgroundState
- LabeledField
- BuyerFollowingScreen
- BuyerNotificationsScreen
- TextInputFormatter
- Size
- BuyerPrivacyScreen
- AssignedDeliveryDetailScreen
- PickupPriority
- _PasswordConfirmSheet
- BuyerSecurityScreen
- _SetPasswordSheet
- _NetworkImageLoader
- DriverShell
- CourierHomeScreen

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 24 edges
2. `Poller` - 15 edges
3. `ApiService` - 14 edges
4. `MessageHandler` - 12 edges
5. `DriverChatController` - 11 edges
6. `Development Instructions` - 11 edges
7. `FlutterWindow` - 10 edges
8. `Create` - 10 edges
9. `WndProc` - 10 edges
10. `MessageHandler` - 9 edges

## Surprising Connections (you probably didn't know these)
- `_FakeApi` --inherits--> `RemittanceApiService`  [EXTRACTED]
  test/remittances_test.dart → lib/services/remittance_api_service.dart
- `OnCreate` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.h → windows/flutter/generated_plugin_registrant.cc
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/runner/my_application.cc → linux/flutter/generated_plugin_registrant.cc

## Import Cycles
- None detected.

## Communities (182 total, 37 thin omitted)

### Community 0 - "auth_screen.dart"
Cohesion: 0.01
Nodes (241): _addressError, _addressFields, _allControllers, _allRoles, _api, _appBarTitle, AuthPortal, _authToken (+233 more)

### Community 1 - "driver_work_screen.dart"
Cohesion: 0.01
Nodes (218): document_viewer_screen.dart, accent, accessToken, _allRegions, alreadyApplied, _apiService, application, _applicationFormColumn (+210 more)

### Community 2 - "buyer_models.dart"
Cohesion: 0.01
Nodes (230): active, anonymous, archived, at, attachments, author, autoApplied, available (+222 more)

### Community 3 - "driver_models.dart"
Cohesion: 0.02
Nodes (122): accountStatus, actualMinutes, amount, applyFrom, assignedAt, AssignedDeliveryItem, AssignedDeliveryStatus, avatarInitial (+114 more)

### Community 4 - "courier_dashboard.dart"
Cohesion: 0.02
Nodes (98): acceptanceRate, actionLabel, address, amount, _bar, _breakdownByPeriod, _breakdownCard, _clock (+90 more)

### Community 5 - "buyer_widgets.dart"
Cohesion: 0.02
Nodes (104): BoxFit, Completer, dart:collection, ImageProvider, ImageStream?, ImageStreamListener?, acquire, action (+96 more)

### Community 6 - "settings_widgets.dart"
Cohesion: 0.03
Nodes (72): ageFor, avatarUrl, background, build, busy, capitalize, children, controller (+64 more)

### Community 7 - "buyer_store.dart"
Cohesion: 0.02
Nodes (121): Address? get, BuyerProfile, addressError, addresses, _addressesLoaded, addToCart, allSelected, api (+113 more)

### Community 8 - "driver_shared_widgets.dart"
Cohesion: 0.03
Nodes (70): ../chat/chat_models.dart, accent, actionLabel, attachment, _AttachmentCard, _AttachmentImageViewer, avatarUrl, _bubbles (+62 more)

### Community 9 - "common.dart"
Cohesion: 0.03
Nodes (73): EdgeInsetsGeometry, AppColors, _blob, blur, borderOpacity, borderRadius, build, _c (+65 more)

### Community 10 - "api_service.dart"
Cohesion: 0.02
Nodes (83): _accountRequest, _authHeaders, bytes, cancelResignationRequest, code, _configuredBaseUrl, confirmParcelTransfer, deactivateDriverAccount (+75 more)

### Community 11 - "solid_ui.dart"
Cohesion: 0.03
Nodes (67): brand_logo.dart, Iterable, autofillHints, build, child, controller, createState, currentIndex (+59 more)

### Community 12 - "buyer_api_service.dart"
Cohesion: 0.02
Nodes (81): addPaymentMethod, addresses, addToWishlist, blockShop, BuyerApiService, cancelOrder, checkout, claimCoupon (+73 more)

### Community 13 - "driver_chat_controller.dart"
Cohesion: 0.03
Nodes (61): _accessToken, _activeConversationId, _api, _attachmentUrlCache, closeConversation, conversationById, _conversations, conversationsError (+53 more)

### Community 14 - "driver_profile_info_screen.dart"
Cohesion: 0.03
Nodes (61): GlobalKey, accessToken, account, _addressCard, _addressLoadError, _addressSectionKey, _api, autoEdit (+53 more)

### Community 15 - "checkout_screen.dart"
Cohesion: 0.03
Nodes (78): ../account/addresses_screen.dart, CheckoutPaymentMethod, address, _AddressPanel, build, _card, CheckoutScreen, _CheckoutScreenState (+70 more)

### Community 16 - "chat_models.dart"
Cohesion: 0.03
Nodes (57): allowedTypes, applyFrom, archived, AttachmentPolicy, attachments, bytes, ChatAttachment, ChatConversation (+49 more)

### Community 17 - "assigned_delivery_detail_screen.dart"
Cohesion: 0.03
Nodes (70): ../chat/driver_delivery_message_screen.dart, failed_attempt_sheet.dart, accessToken, _actionTag, _api, _applyScannedProof, _attachPicture, _attachPictureFlow (+62 more)

### Community 18 - "buyer_theme.dart"
Cohesion: 0.03
Nodes (57): background, base, BButtons, BColors, body, border, BRadius, brand (+49 more)

### Community 19 - "driver_shell.dart"
Cohesion: 0.03
Nodes (74): chat/driver_chat_list_screen.dart, deliveries/driver_deliveries_screen.dart, earnings/driver_earnings_screen.dart, history/driver_history_screen.dart, home/courier_home_screen.dart, home/deliver_order_screen.dart, home/delivery_request_details_screen.dart, home/driver_home_screen.dart (+66 more)

### Community 20 - "orders_screen.dart"
Cohesion: 0.03
Nodes (69): ../chat/chat_thread_screen.dart, _applyPending, build, _busy, _CartButton, controller, createState, didChangeDependencies (+61 more)

### Community 21 - "StatelessWidget"
Cohesion: 0.05
Nodes (43): SettingsAvatar, SettingsDateField, SettingsDropdownField, SettingsErrorBanner, SettingsFieldError, SettingsFieldLabel, SettingsGroupCard, SettingsInfoNote (+35 more)

### Community 22 - "driver_deliveries_screen.dart"
Cohesion: 0.04
Nodes (57): assigned_delivery_detail_screen.dart, accessToken, _actionsWidth, active, _alertExpanded, atRisk, _atRiskAfter, _call (+49 more)

### Community 23 - "order_detail_screen.dart"
Cohesion: 0.03
Nodes (69): EdgeInsets, ReturnRequestInfo, StatusEvent, _AddressRow, _AddressRowState, _BarButton, _BottomBar, _busy (+61 more)

### Community 24 - "product_detail_screen.dart"
Cohesion: 0.02
Nodes (84): _addToCart, _BottomBar, build, _card, child, _circle, _claim, claimedCoupons (+76 more)

### Community 25 - "chat_thread_screen.dart"
Cohesion: 0.02
Nodes (103): chat_assistant.dart, chat_list_screen.dart, ChatAttachment, ChatMessage, action, api, _Asking, _AskingChip (+95 more)

### Community 26 - "logistics_models.dart"
Cohesion: 0.03
Nodes (58): address, body, buyer, companyName, confirmationToken, contactNo, copyWith, courier (+50 more)

### Community 27 - "home_screen.dart"
Cohesion: 0.05
Nodes (36): ../account/wishlist_screen.dart, categories_screen.dart, actionLabel, _ActiveOrderCard, alpha, badge, build, _CategoryRail (+28 more)

### Community 28 - "driver_history_screen.dart"
Cohesion: 0.04
Nodes (46): DateTimeRange?, AssignedDelivery, accessToken, _api, avgMinutes, _body, build, _call (+38 more)

### Community 29 - "settings_screens.dart"
Cohesion: 0.04
Nodes (48): actionLabel, audience, blocked, blockedLabel, build, busy, busyId, _buyer (+40 more)

### Community 30 - "address_form_screen.dart"
Cohesion: 0.04
Nodes (51): address_pin_picker.dart, AddressFormScreen, _AddressFormScreenState, _api, barangay, build, city, _clearPin (+43 more)

### Community 31 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.05
Nodes (33): Any, Cocoa, file_picker, file_selector_macos, firebase_core, firebase_messaging, Flutter, flutter_local_notifications (+25 more)

### Community 32 - "driver_register_screen.dart"
Cohesion: 0.09
Nodes (23): driver_otp_screen.dart, ../driver_shell.dart, build, _confirmController, createState, dispose, DriverRegisterScreen, _DriverRegisterScreenState (+15 more)

### Community 33 - "chat_list_screen.dart"
Cohesion: 0.05
Nodes (37): chat_thread_screen.dart, _actions, archived, build, ChatAvatar, ChatListScreen, _ChatListScreenState, chatTimeLabel (+29 more)

### Community 34 - "image_crop_sheet.dart"
Cohesion: 0.05
Nodes (38): Image?, _askImageSource, _baseScale, build, bytes, _clamp, context, createState (+30 more)

### Community 35 - "State"
Cohesion: 0.13
Nodes (18): AutomaticKeepAliveClientMixin, HomeScreen, _ProfileScreenState, CategoriesScreen, _CategoriesScreenState, _HomeScreenState, CourierDashboard, _CourierDashboardState (+10 more)

### Community 36 - "brand_logo.dart"
Cohesion: 0.06
Nodes (32): animations, _bag, BagLogo, _bagPaint, blue, blueDark, blueTint, BrandColors (+24 more)

### Community 37 - "driver_home_screen.dart"
Cohesion: 0.06
Nodes (33): account, activeDelivery, _activeDeliveryCard, availableRequests, build, _clock, completedToday, createState (+25 more)

### Community 38 - "driver_chat_conversation_screen.dart"
Cohesion: 0.06
Nodes (32): _archivedNotice, _AttachmentSourceSheet, _AttachSource, _body, build, _composer, controller, conversation (+24 more)

### Community 39 - "my_application.cc"
Cohesion: 0.08
Nodes (27): file_selector_plugin, FlPluginRegistry, flutter_linux, FlView, GApplication, gboolean, gchar, gdkx (+19 more)

### Community 40 - "profile_screen.dart"
Cohesion: 0.03
Nodes (58): _avatar, birthday, _changeAvatar, color, _Consequence, contact, controller, _controllers (+50 more)

### Community 41 - "driver_chat_list_screen.dart"
Cohesion: 0.07
Nodes (29): driver_archived_conversations_screen.dart, _ArchiveShortcut, build, ChatConversationRow, _content, controller, conversation, createState (+21 more)

### Community 42 - "driver_login_screen.dart"
Cohesion: 0.07
Nodes (29): driver_forgot_password_screen.dart, FocusNode, _api, _biometricStub, build, controller, createState, dispose (+21 more)

### Community 43 - "driver_theme.dart"
Cohesion: 0.07
Nodes (29): background, body, border, caption, DriverButtonStyle, DriverColors, DriverText, error (+21 more)

### Community 44 - "driver_settings_screen.dart"
Cohesion: 0.07
Nodes (28): driver_deactivate_account_dialog.dart, driver_profile_info_screen.dart, driver_vehicle_documents_screen.dart, accessToken, account, _api, build, _comingSoon (+20 more)

### Community 45 - "qr_scan_screen.dart"
Cohesion: 0.07
Nodes (30): build, _controller, createState, dispose, expectedToken, _feedback, _feedbackTimer, _flashFeedback (+22 more)

### Community 46 - "driver_payslip_screen.dart"
Cohesion: 0.08
Nodes (25): accessToken, build, _busy, _cashout, _client, createState, _date, dispose (+17 more)

### Community 47 - "inventory_detail_screen.dart"
Cohesion: 0.06
Nodes (36): ../../driver/deliveries/qr_scan_screen.dart, accessToken, _api, build, _buildBody, _buildScanBar, createState, didChangeDependencies (+28 more)

### Community 48 - "return_request_screen.dart"
Cohesion: 0.09
Nodes (23): ImageSource, _addPhoto, build, createState, details, dispose, hasQr, initState (+15 more)

### Community 49 - "reviews_screen.dart"
Cohesion: 0.05
Nodes (39): Review, ReviewSummary, _avatar, build, busy, _chip, createState, error (+31 more)

### Community 50 - "logistics_inventory_screen.dart"
Cohesion: 0.06
Nodes (34): inventory_detail_screen.dart, accessToken, _applyHeld, build, createState, dispose, emptyIcon, emptySubtitle (+26 more)

### Community 51 - "product_pager.dart"
Cohesion: 0.07
Nodes (29): int get, activeFilters, applyFilters, category, dispose, _disposed, error, false (+21 more)

### Community 52 - "logistics_shell.dart"
Cohesion: 0.04
Nodes (46): dashboard/logistics_dashboard_screen.dart, inventory/logistics_inventory_screen.dart, _accessToken, _account, _accountLoadError, _api, _applyLists, build (+38 more)

### Community 53 - "courier_home_screen.dart"
Cohesion: 0.03
Nodes (79): BoxDecoration get, DateTime? get, accessToken, account, _activity, _activityRow, _amber, _areaRow (+71 more)

### Community 54 - "account_screen.dart"
Cohesion: 0.06
Nodes (33): addresses_screen.dart, _AccountHero, AccountScreen, _AccountScreenState, avatarUrl, build, completeness, count (+25 more)

### Community 55 - "MaterialPageRoute"
Cohesion: 0.07
Nodes (28): build, build, build, _push, _use, _reviewsTab, _addStockReplyToCart, build (+20 more)

### Community 56 - "vouchers_screen.dart"
Cohesion: 0.03
Nodes (58): ../catalog/product_list_screen.dart, active, background, body, borderColor, build, _canUse, _cartButton (+50 more)

### Community 57 - "cart_screen.dart"
Cohesion: 0.05
Nodes (38): address_sheet.dart, ../catalog/store_screen.dart, ../checkout/checkout_screen.dart, CartItem, _AddressLine, build, _CartLine, CartScreen (+30 more)

### Community 58 - "driver_earnings_screen.dart"
Cohesion: 0.10
Nodes (21): double get, EarningsPeriod, availableBalance, _balanceCard, _breakdown, _breakdownCard, build, createState (+13 more)

### Community 59 - "wishlist_screen.dart"
Cohesion: 0.05
Nodes (38): _addToCart, build, _categoryHeader, child, _controls, createState, dispose, error (+30 more)

### Community 60 - "review_sheet.dart"
Cohesion: 0.10
Nodes (20): anonymous, build, comment, createState, dispose, false, initialRating, orderItemId (+12 more)

### Community 61 - "driver_otp_screen.dart"
Cohesion: 0.10
Nodes (21): build, _code, _controllers, createState, _demoCode, dispose, DriverOtpScreen, _DriverOtpScreenState (+13 more)

### Community 62 - "order_actions.dart"
Cohesion: 0.10
Nodes (21): ../buyer_shell.dart, Order, added, build, busy, _cancel, _cancelReasons, _CancelSheet (+13 more)

### Community 63 - "poller.dart"
Cohesion: 0.08
Nodes (25): DateTime?, Duration, didChangeAppLifecycleState, _failures, _foreground, _generation, _halted, _inFlight (+17 more)

### Community 64 - "search_screen.dart"
Cohesion: 0.07
Nodes (29): build, controller, createState, _debounce, _discover, dispose, _fetch, initial (+21 more)

### Community 65 - "bool get"
Cohesion: 0.11
Nodes (18): bool get, build, label, meetsMinimum, of, password, PasswordRule, PasswordStrength (+10 more)

### Community 66 - "Win32Window"
Cohesion: 0.16
Nodes (18): FlutterViewController, RECT, unique_ptr, FlutterWindow, flutter_controller_, OnCreate, OnDestroy, project_ (+10 more)

### Community 67 - "logistics_dashboard_screen.dart"
Cohesion: 0.10
Nodes (20): int?, account, build, count, error, _forest, icon, _ink (+12 more)

### Community 68 - "deliver_order_screen.dart"
Cohesion: 0.11
Nodes (18): _arrived, _attachPhoto, build, _contactStub, createState, DeliverOrderScreen, _DeliverOrderScreenState, delivery (+10 more)

### Community 69 - "addresses_screen.dart"
Cohesion: 0.08
Nodes (24): address_form_screen.dart, _Action, address, _AddressCard, AddressesScreen, _AddressesScreenState, build, color (+16 more)

### Community 70 - "driver_archived_conversations_screen.dart"
Cohesion: 0.11
Nodes (18): driver_chat_conversation_screen.dart, driver_chat_list_screen.dart, build, controller, _conversations, createState, _debounce, dispose (+10 more)

### Community 71 - "win32_window.cpp"
Cohesion: 0.16
Nodes (15): dwmapi, wchar_t, Scale(), Create, Destroy, SetQuitOnClose, Show, UpdateTheme (+7 more)

### Community 72 - "pickup_order_screen.dart"
Cohesion: 0.12
Nodes (17): ActiveDelivery, _arrived, _attachPhoto, build, _contactStub, createState, delivery, _handleArrived (+9 more)

### Community 73 - "buyer_shell.dart"
Cohesion: 0.10
Nodes (21): account/account_screen.dart, ../account/notifications_screen.dart, ../cart/cart_screen.dart, catalog/home_screen.dart, chat/chat_list_screen.dart, _backToSignIn, build, BuyerShell (+13 more)

### Community 74 - "../driver_theme.dart"
Cohesion: 0.08
Nodes (26): ../driver_models.dart, ../driver_theme.dart, DeliveryRequest, DriverAccount, _accept, _addressRow, build, capacity (+18 more)

### Community 75 - "../widgets/buyer_widgets.dart"
Cohesion: 0.15
Nodes (12): ../buyer_models.dart, OrderItem, build, item, _openPhoto, _reasonLabel, _reasons, returnBadge (+4 more)

### Community 76 - "document_viewer_screen.dart"
Cohesion: 0.13
Nodes (15): driver_work_screen.dart, build, _controller, createState, DocumentViewerScreen, _DocumentViewerScreenState, _failed, initState (+7 more)

### Community 77 - "variant_sheet.dart"
Cohesion: 0.12
Nodes (17): Product, ProductVariant, build, createState, initState, mode, product, quantity (+9 more)

### Community 78 - "logistics_settings_screen.dart"
Cohesion: 0.17
Nodes (11): ../driver/widgets/driver_shared_widgets.dart, LogisticsAccount, accessToken, account, build, _confirmSignOut, LogisticsSettingsScreen, onSignOut (+3 more)

### Community 79 - "courier_navbar.dart"
Cohesion: 0.11
Nodes (18): badgeCount, build, CourierNavBar, _CourierNavBarState, createState, currentIndex, dispose, _handleTap (+10 more)

### Community 80 - "../services/api_service.dart"
Cohesion: 0.09
Nodes (22): codeDigits, codeInputs, confirmPassword, context, error, newPassword, obscure1, sending (+14 more)

### Community 81 - "payments_util.dart"
Cohesion: 0.13
Nodes (14): alt, d, detectCardBrand, digits, digitsOnly, expiryPassed, luhnValid, m (+6 more)

### Community 82 - "driver_splash_screen.dart"
Cohesion: 0.14
Nodes (14): Animation, _api, build, _controller, createState, dispose, DriverSplashScreen, _DriverSplashScreenState (+6 more)

### Community 83 - "package:flutter/material.dart"
Cohesion: 0.08
Nodes (22): ElevatedButton, build, _buildFeatureItem, SidePanel, package:buytheway/screens/buyer/buyer_models.dart, package:buytheway/screens/buyer/catalog/home_screen.dart, package:buytheway/screens/buyer/orders/return_tracking_sheet.dart, package:buytheway/screens/driver/deliveries/failed_attempt_sheet.dart (+14 more)

### Community 84 - "notification_inbox.dart"
Cohesion: 0.05
Nodes (37): build, createState, didChangeDependencies, diff, dispose, emptySubtitle, _error, _ErrorState (+29 more)

### Community 85 - "chat_assistant.dart"
Cohesion: 0.04
Nodes (48): active, AssistantActions, _body, build, ChatPick, conversationId, createState, dispose (+40 more)

### Community 86 - "utils.cpp"
Cohesion: 0.19
Nodes (12): flutter_windows, _In_, _In_opt_, io, iostream, stdio, wWinMain(), string (+4 more)

### Community 87 - "DriverChatController"
Cohesion: 0.40
Nodes (5): ChangeNotifier, BuyerStore, ParcelJourneyController, ProductPager, DriverChatController

### Community 88 - "Development Instructions"
Cohesion: 0.17
Nodes (11): Code Changes, Code Quality & Performance, Communication, Development Instructions, Existing Functionality, Perceived Performance, Project Location, Redesign Permission (+3 more)

### Community 89 - "report_delivered_sheet.dart"
Cohesion: 0.05
Nodes (37): _add, _addPackage, build, busy, contents, createState, _damaged, details (+29 more)

### Community 90 - "payment_qr_screen.dart"
Cohesion: 0.10
Nodes (21): accessToken, _api, build, _busy, _change, createState, dispose, _error (+13 more)

### Community 91 - "Map"
Cohesion: 0.13
Nodes (14): ../driver/driver_theme.dart, IconData get, build, _detail, _link, onSelect, RemittanceRecordCard, row (+6 more)

### Community 92 - "MessageHandler"
Cohesion: 0.18
Nodes (10): generated_plugin_registrant, optional, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM (+2 more)

### Community 93 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 94 - "buyer_payment_qr_card.dart"
Cohesion: 0.12
Nodes (17): buyer_widgets.dart, build, _busy, BuyerPaymentQrCard, _BuyerPaymentQrCardState, _change, createState, _error (+9 more)

### Community 95 - "main.dart"
Cohesion: 0.14
Nodes (13): build, buildScrollbar, main, MyApp, _NoScrollbarBehavior, MaterialScrollBehavior, screens/buyer/buyer_shell.dart, screens/driver/auth/driver_splash_screen.dart (+5 more)

### Community 96 - "store_screen.dart"
Cohesion: 0.03
Nodes (72): _aboutRow, _ActionTile, anonymous, _block, build, busy, _claim, claimed (+64 more)

### Community 97 - "driver_forgot_password_screen.dart"
Cohesion: 0.15
Nodes (13): build, createState, dispose, DriverForgotPasswordScreen, _DriverForgotPasswordScreenState, _emailController, _error, _formState (+5 more)

### Community 98 - "VoidCallback?"
Cohesion: 0.15
Nodes (11): common.dart, build, DriverNotificationBell, onTap, unread, build, isFullWidth, label (+3 more)

### Community 99 - "string"
Cohesion: 0.27
Nodes (7): dart_project, flutter_view_controller, functional, memory, string, vector, windows

### Community 100 - "windows/flutter/generated_plugin_registrant.cc"
Cohesion: 0.25
Nodes (6): file_selector_windows, firebase_core_plugin_c_api, plugin_registry, PluginRegistry, url_launcher_windows, RegisterPlugins()

### Community 101 - "my_reviews_screen.dart"
Cohesion: 0.05
Nodes (43): _amber, _amberDark, _amberSoft, child, _clearFilters, color, _controls, count (+35 more)

### Community 102 - "my_reports_screen.dart"
Cohesion: 0.04
Nodes (46): _buyer, _card, closedCount, _copyReference, createState, _date, didChangeDependencies, dispose (+38 more)

### Community 103 - "logistics_notifications_screen.dart"
Cohesion: 0.13
Nodes (14): ../../driver/notifications/notification_inbox.dart, ../inventory/inventory_detail_screen.dart, accessToken, _api, build, LogisticsNotificationsScreen, onOpenInventory, onScanActive (+6 more)

### Community 106 - "remittances_test.dart"
Cohesion: 0.14
Nodes (13): dart:convert, package:buytheway/screens/remittances/remittance_format.dart, package:buytheway/screens/remittances/remittances_screen.dart, package:buytheway/services/api_service.dart, package:buytheway/services/remittance_api_service.dart, package:http/http.dart, package:http/testing.dart, main (+5 more)

### Community 109 - "remittances_screen.dart"
Cohesion: 0.04
Nodes (52): accessToken, _action, _actionOpen, active, api, _applyHeld, _batchPayment, build (+44 more)

### Community 110 - "parcel_tracking.dart"
Cohesion: 0.06
Nodes (35): ParcelJourney, build, controller, createState, _ctrl, dispose, _disposed, events (+27 more)

### Community 111 - "driver_chat_settle_test.dart"
Cohesion: 0.40
Nodes (4): package:buytheway/screens/driver/chat/chat_models.dart, package:buytheway/screens/driver/chat/driver_chat_controller.dart, main, _msg

### Community 112 - "address_pin_picker.dart"
Cohesion: 0.06
Nodes (35): LatLng?, AddressPinPreview, barangay, build, center, _confirm, controller, createState (+27 more)

### Community 113 - "remittance_action_screen.dart"
Cohesion: 0.06
Nodes (32): action, _amount, api, build, _busy, _bytes, _changed, _confirmed (+24 more)

### Community 114 - "MessageHandler"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 115 - "remittance_api_service.dart"
Cohesion: 0.07
Nodes (29): api_service.dart, Client, accessToken, _base, _client, close, _decode, dispute (+21 more)

### Community 116 - "remittance_detail_screen.dart"
Cohesion: 0.09
Nodes (23): api, build, createState, didChangeDependencies, dispose, _error, _fetch, id (+15 more)

### Community 117 - "voucher_quote.dart"
Cohesion: 0.06
Nodes (32): double?, amount, applicable, bestDiscountId, bestShippingId, categories, conditions, count (+24 more)

### Community 118 - "ApiException"
Cohesion: 0.67
Nodes (3): Exception, ApiException, GoogleAuthException

### Community 119 - "Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 120 - "settings_kit.dart"
Cohesion: 0.06
Nodes (30): actionLabel, actions, bottomBar, build, children, color, count, EmptyCard (+22 more)

### Community 121 - "voucher_sheet.dart"
Cohesion: 0.07
Nodes (30): VoucherOffer, VoucherOption, background, build, _choose, color, createState, discount (+22 more)

### Community 122 - "search_filter_sheet.dart"
Cohesion: 0.07
Nodes (27): _apply, _availability, build, _categories, _category, createState, dispose, _facets (+19 more)

### Community 124 - "../buyer_theme.dart"
Cohesion: 0.07
Nodes (31): ../buyer_theme.dart, home_screen.dart, build, createState, dispose, _pagerFor, _pagers, _selected (+23 more)

### Community 125 - "address_sheet.dart"
Cohesion: 0.12
Nodes (17): ../account/address_form_screen.dart, ../account/settings_kit.dart, Address, _AddressSheet, _AddressSheetState, build, busyId, chosen (+9 more)

### Community 126 - "List"
Cohesion: 0.14
Nodes (14): ../buyer_store.dart, build, createState, dispose, _header, OrderPlacedScreen, _OrderPlacedScreenState, pager (+6 more)

### Community 127 - "SliverPersistentHeaderDelegate"
Cohesion: 0.50
Nodes (4): _PinnedHeader, _PinnedHeader, _TabsDelegate, SliverPersistentHeaderDelegate

### Community 128 - "success_popup.dart"
Cohesion: 0.10
Nodes (20): CustomPainter, _TicketPainter, DealDashPainter, build, _CheckBadge, _CheckPainter, duration, message (+12 more)

### Community 129 - "sign_in_methods_sheets.dart"
Cohesion: 0.04
Nodes (45): actionLabel, api, autofillHint, autofocus, build, _busy, child, _code (+37 more)

### Community 130 - "Color?"
Cohesion: 0.15
Nodes (12): Color?, Coupon, build, claimed, claiming, color, coupon, DealTicket (+4 more)

### Community 131 - "StatefulWidget"
Cohesion: 0.09
Nodes (22): ProfileScreen, _ApplyPage, __ApplyPageState, DriverWorkScreen, _DriverWorkScreenState, EmploymentBanner, _EmploymentBannerState, ResignationRequestSheet (+14 more)

### Community 132 - "SingleTickerProviderStateMixin"
Cohesion: 0.40
Nodes (5): VouchersScreen, _VouchersScreenState, LogisticsInventoryScreen, _LogisticsInventoryScreenState, SingleTickerProviderStateMixin

### Community 143 - "_TicketClipper"
Cohesion: 0.67
Nodes (3): CustomClipper, _TicketClipper, Path

### Community 144 - "payment_methods_screen.dart"
Cohesion: 0.14
Nodes (14): ../../driver/settings/widgets/settings_widgets.dart, build, createState, _delete, error, initState, _load, methods (+6 more)

### Community 145 - "notifications_screen.dart"
Cohesion: 0.06
Nodes (31): build, createState, dispose, error, hasMore, _iconFor, initState, items (+23 more)

### Community 146 - "sign_in_methods_section.dart"
Cohesion: 0.05
Nodes (41): actionLabel, _api, _apply, _bar, build, _connectGoogle, createState, destructive (+33 more)

### Community 147 - "static const"
Cohesion: 0.18
Nodes (11): FormState, build, createState, _description, dispose, FailedAttemptSheet, _FailedAttemptSheetState, _formKey (+3 more)

### Community 148 - "brand_splash_screen.dart"
Cohesion: 0.17
Nodes (12): AnimationController, ../auth/auth_screen.dart, dart:math, BrandSplashScreen, _BrandSplashScreenState, build, _controller, createState (+4 more)

### Community 149 - "push_service.dart"
Cohesion: 0.05
Nodes (38): @pragma, chat_notification.dart, dart:io, FlutterLocalNotificationsPlugin, _channelMessages, _channelNotifications, clearTap, conversationId (+30 more)

### Community 150 - "chat_notification.dart"
Cohesion: 0.12
Nodes (19): @visibleForTesting, settleSentMessage, avatar, _avatarBudget, _avatarPx, _brand, channelId, ChatNotification (+11 more)

### Community 151 - "google_auth_service.dart"
Cohesion: 0.12
Nodes (15): Future, GoogleSignIn, _ensureInitialized, _google, GoogleAuthService, _initialized, instance, pickAccount (+7 more)

### Community 152 - "package:flutter/services.dart"
Cohesion: 0.06
Nodes (37): IconData?, activeIcon, badgeCount, _barHeight, build, BuyerNavBar, currentIndex, _handleTap (+29 more)

### Community 160 - "driver_delivery_message_screen.dart"
Cohesion: 0.14
Nodes (14): chat_models.dart, ChatConversation?, driver_chat_controller.dart, build, contact, controller, _conversation, createState (+6 more)

### Community 161 - "remittance_format.dart"
Cohesion: 0.11
Nodes (17): isNotEmpty
      ?, amount, business, cents, digits, formatEditUpdate, parse, parseRemittancePesos (+9 more)

### Community 162 - "dart:async"
Cohesion: 0.17
Nodes (12): dart:async, build, buyerToken, createState, _error, initState, _loading, _open (+4 more)

### Community 163 - "dart:typed_data"
Cohesion: 0.22
Nodes (8): dart:typed_data, dart:ui, package:buytheway/services/chat_notification.dart, image, _isPng, main, recorder, _solidPng

### Community 164 - "driver_notifications_screen.dart"
Cohesion: 0.12
Nodes (15): ../chat/driver_chat_controller.dart, ../deliveries/assigned_delivery_detail_screen.dart, accessToken, _api, build, controller, DriverNotificationsScreen, onBusy (+7 more)

### Community 171 - "TextInputFormatter"
Cohesion: 0.40
Nodes (5): _PlateNumberFormatter, _UppercaseLetterFormatter, _LocalMobileFormatter, TransactionNumberFormatter, TextInputFormatter

### Community 172 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

## Knowledge Gaps
- **4407 isolated node(s):** `UserNotifications`, `main`, `build`, `buildScrollbar`, `AuthPortal` (+4402 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 4630 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **37 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `string`, `win32_window.cpp`, `Size`, `MessageHandler`, `Point`, `MessageHandler`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `ApiService` connect `driver_splash_screen.dart` to `auth_screen.dart`, `driver_work_screen.dart`, `sign_in_methods_sheets.dart`, `api_service.dart`, `driver_settings_screen.dart`, `driver_chat_controller.dart`, `driver_profile_info_screen.dart`, `inventory_detail_screen.dart`, `assigned_delivery_detail_screen.dart`, `sign_in_methods_section.dart`, `driver_shell.dart`, `logistics_shell.dart`, `driver_history_screen.dart`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `Poller` connect `remittance_detail_screen.dart` to `my_reports_screen.dart`, `buyer_store.dart`, `driver_chat_controller.dart`, `remittances_screen.dart`, `checkout_screen.dart`, `inventory_detail_screen.dart`, `notifications_screen.dart`, `assigned_delivery_detail_screen.dart`, `driver_shell.dart`, `notification_inbox.dart`, `logistics_shell.dart`, `order_detail_screen.dart`, `poller.dart`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **What connects `UserNotifications`, `main`, `build` to the rest of the system?**
  _4407 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `auth_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.008264462809917356 - nodes in this community are weakly interconnected._
- **Should `driver_work_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0091324200913242 - nodes in this community are weakly interconnected._
- **Should `buyer_models.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.008658008658008658 - nodes in this community are weakly interconnected._