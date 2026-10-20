# Graph Report - BuyTheWay - Mobile  (2026-10-20)

## Corpus Check
- 155 files · ~234,726 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 53 file(s) not represented in the graph (top: .xcconfig 8, (none) 7, .xml 7)

## Summary
- 5382 nodes · 7329 edges · 177 communities (135 shown, 42 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `400769f9`
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
- delivery_request_details_screen.dart
- driver_delivery_message_screen.dart
- document_viewer_screen.dart
- ../widgets/buyer_widgets.dart
- driver_nav_bar.dart
- courier_navbar.dart
- ../../services/api_service.dart
- payments_util.dart
- driver_splash_screen.dart
- package:flutter/material.dart
- buyer_nav_bar.dart
- chat_assistant.dart
- utils.cpp
- IconData?
- Development Instructions
- report_delivered_sheet.dart
- payment_qr_screen.dart
- ValueChanged
- MessageHandler
- manifest.json
- ../buyer_store.dart
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
- CheckoutScreen
- address_pin_picker.dart
- remittance_action_screen.dart
- MessageHandler
- remittance_api_service.dart
- remittance_detail_screen.dart
- voucher_quote.dart
- ../../widgets/driver_shared_widgets.dart
- Point
- settings_kit.dart
- voucher_sheet.dart
- search_filter_sheet.dart
- ApplicationStatus
- ../buyer_theme.dart
- address_sheet.dart
- List
- SliverPersistentHeaderDelegate
- package:flutter/services.dart
- _NetworkImageLoader
- ../buyer_models.dart
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
- _PlacePicker
- static const
- brand_splash_screen.dart
- BuyerBlockedShopsScreen
- BuyerFollowingScreen
- BuyerNotificationsScreen
- BuyerPrivacyScreen
- BuyerReportDetailScreen
- _AllTab
- _VoucherHistoryScreen
- _ReportSheet
- StoreScreen
- ProductDetailScreen
- BuyerReportsScreen
- BuyerSecurityScreen
- remittance_format.dart
- dart:async
- CourierHomeScreen
- AssignedDeliveryDetailScreen
- PickupPriority
- ChatThreadScreen
- _AuroraBackgroundState
- LabeledField
- ../driver/driver_theme.dart
- CustomPainter
- AddressFormScreen
- DriverDeliveriesScreen
- _MissionCard
- _PulsingDotState
- DriverProfileInfoScreen
- RemittancesScreen

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 24 edges
2. `Poller` - 15 edges
3. `ApiService` - 13 edges
4. `MessageHandler` - 12 edges
5. `Development Instructions` - 11 edges
6. `DriverChatController` - 10 edges
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

## Communities (177 total, 42 thin omitted)

### Community 0 - "auth_screen.dart"
Cohesion: 0.01
Nodes (239): _addressError, _addressFields, _allControllers, _allRoles, _api, _appBarTitle, AuthPortal, _authToken (+231 more)

### Community 1 - "driver_work_screen.dart"
Cohesion: 0.01
Nodes (216): document_viewer_screen.dart, accent, accessToken, _allRegions, alreadyApplied, _apiService, application, _applicationFormColumn (+208 more)

### Community 2 - "buyer_models.dart"
Cohesion: 0.01
Nodes (219): active, anonymous, archived, at, attachments, author, autoApplied, available (+211 more)

### Community 3 - "driver_models.dart"
Cohesion: 0.02
Nodes (120): accountStatus, actualMinutes, amount, applyFrom, assignedAt, AssignedDeliveryItem, AssignedDeliveryStatus, avatarInitial (+112 more)

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
Nodes (69): ../chat/chat_models.dart, accent, actionLabel, attachment, avatarUrl, _bubbles, build, cancelLabel (+61 more)

### Community 9 - "common.dart"
Cohesion: 0.03
Nodes (73): EdgeInsetsGeometry, AppColors, _blob, blur, borderOpacity, borderRadius, build, _c (+65 more)

### Community 10 - "api_service.dart"
Cohesion: 0.03
Nodes (73): dart:io, _authHeaders, bytes, cancelResignationRequest, _configuredBaseUrl, confirmParcelTransfer, deactivateDriverAccount, _deliveryAttemptAction (+65 more)

### Community 11 - "solid_ui.dart"
Cohesion: 0.03
Nodes (66): brand_logo.dart, Iterable, autofillHints, build, child, controller, createState, currentIndex (+58 more)

### Community 12 - "buyer_api_service.dart"
Cohesion: 0.02
Nodes (81): addPaymentMethod, addresses, addToWishlist, blockShop, BuyerApiService, cancelOrder, checkout, claimCoupon (+73 more)

### Community 13 - "driver_chat_controller.dart"
Cohesion: 0.03
Nodes (59): _accessToken, _activeConversationId, _api, _attachmentUrlCache, closeConversation, conversationById, _conversations, conversationsError (+51 more)

### Community 14 - "driver_profile_info_screen.dart"
Cohesion: 0.03
Nodes (59): GlobalKey, accessToken, account, _addressCard, _addressLoadError, _addressSectionKey, _api, autoEdit (+51 more)

### Community 15 - "checkout_screen.dart"
Cohesion: 0.03
Nodes (77): ../account/addresses_screen.dart, CheckoutPaymentMethod, address, _AddressPanel, build, _card, _clearShopVouchers, codMethod (+69 more)

### Community 16 - "chat_models.dart"
Cohesion: 0.03
Nodes (57): allowedTypes, applyFrom, archived, AttachmentPolicy, attachments, bytes, ChatAttachment, ChatConversation (+49 more)

### Community 17 - "assigned_delivery_detail_screen.dart"
Cohesion: 0.03
Nodes (65): ../chat/driver_delivery_message_screen.dart, failed_attempt_sheet.dart, accessToken, _actionTag, _api, _applyScannedProof, _attachPicture, _attachPictureFlow (+57 more)

### Community 18 - "buyer_theme.dart"
Cohesion: 0.03
Nodes (57): background, base, BButtons, BColors, body, border, BRadius, brand (+49 more)

### Community 19 - "driver_shell.dart"
Cohesion: 0.03
Nodes (64): chat/driver_chat_list_screen.dart, deliveries/driver_deliveries_screen.dart, earnings/driver_earnings_screen.dart, history/driver_history_screen.dart, home/courier_home_screen.dart, home/deliver_order_screen.dart, home/delivery_request_details_screen.dart, home/driver_home_screen.dart (+56 more)

### Community 20 - "orders_screen.dart"
Cohesion: 0.03
Nodes (67): _applyPending, build, _busy, _CartButton, controller, createState, didChangeDependencies, dispose (+59 more)

### Community 21 - "StatelessWidget"
Cohesion: 0.04
Nodes (46): SettingsChoiceField, SettingsDateField, SettingsDropdownField, SettingsErrorBanner, SettingsFieldError, SettingsGroupCard, SettingsInfoNote, SettingsInfoRow (+38 more)

### Community 22 - "driver_deliveries_screen.dart"
Cohesion: 0.04
Nodes (51): assigned_delivery_detail_screen.dart, ../chat/driver_chat_controller.dart, accessToken, _actionsWidth, active, _alertExpanded, atRisk, _atRiskAfter (+43 more)

### Community 23 - "order_detail_screen.dart"
Cohesion: 0.03
Nodes (67): ../chat/chat_thread_screen.dart, EdgeInsets, StatusEvent, _AddressRow, _AddressRowState, _BarButton, _BottomBar, _busy (+59 more)

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
Nodes (36): ../account/notifications_screen.dart, ../account/wishlist_screen.dart, categories_screen.dart, actionLabel, _ActiveOrderCard, alpha, badge, _CategoryRail (+28 more)

### Community 28 - "driver_history_screen.dart"
Cohesion: 0.04
Nodes (46): DateTimeRange?, AssignedDelivery, accessToken, _api, avgMinutes, _body, build, _call (+38 more)

### Community 29 - "settings_screens.dart"
Cohesion: 0.04
Nodes (48): actionLabel, audience, blocked, blockedLabel, build, busy, busyId, _buyer (+40 more)

### Community 30 - "address_form_screen.dart"
Cohesion: 0.04
Nodes (47): address_pin_picker.dart, _api, barangay, build, city, _clearPin, code, createState (+39 more)

### Community 31 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.06
Nodes (29): Any, Cocoa, file_picker, file_selector_macos, Flutter, FlutterAppDelegate, FlutterMacOS, FlutterPluginRegistry (+21 more)

### Community 32 - "driver_register_screen.dart"
Cohesion: 0.09
Nodes (23): driver_otp_screen.dart, ../driver_shell.dart, build, _confirmController, createState, dispose, DriverRegisterScreen, _DriverRegisterScreenState (+15 more)

### Community 33 - "chat_list_screen.dart"
Cohesion: 0.05
Nodes (37): chat_thread_screen.dart, _actions, archived, build, ChatAvatar, ChatListScreen, _ChatListScreenState, chatTimeLabel (+29 more)

### Community 34 - "image_crop_sheet.dart"
Cohesion: 0.05
Nodes (39): dart:ui, Image?, _askImageSource, _baseScale, build, bytes, _clamp, context (+31 more)

### Community 35 - "State"
Cohesion: 0.13
Nodes (18): AutomaticKeepAliveClientMixin, HomeScreen, _ProfileScreenState, CategoriesScreen, _CategoriesScreenState, _HomeScreenState, CourierDashboard, _CourierDashboardState (+10 more)

### Community 36 - "brand_logo.dart"
Cohesion: 0.06
Nodes (32): animations, _bag, BagLogo, _bagPaint, blue, blueDark, blueTint, BrandColors (+24 more)

### Community 37 - "driver_home_screen.dart"
Cohesion: 0.07
Nodes (30): account, activeDelivery, _activeDeliveryCard, availableRequests, build, _clock, completedToday, createState (+22 more)

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
Nodes (30): driver_forgot_password_screen.dart, driver_register_screen.dart, FocusNode, _api, _biometricStub, build, controller, createState (+22 more)

### Community 43 - "driver_theme.dart"
Cohesion: 0.07
Nodes (29): background, body, border, caption, DriverButtonStyle, DriverColors, DriverText, error (+21 more)

### Community 44 - "driver_settings_screen.dart"
Cohesion: 0.07
Nodes (30): driver_change_password_sheet.dart, driver_deactivate_account_dialog.dart, driver_profile_info_screen.dart, driver_vehicle_documents_screen.dart, accessToken, account, _api, build (+22 more)

### Community 45 - "qr_scan_screen.dart"
Cohesion: 0.07
Nodes (29): build, _controller, createState, dispose, expectedToken, _feedback, _feedbackTimer, _flashFeedback (+21 more)

### Community 46 - "driver_payslip_screen.dart"
Cohesion: 0.08
Nodes (25): accessToken, build, _busy, _cashout, _client, createState, _date, dispose (+17 more)

### Community 47 - "inventory_detail_screen.dart"
Cohesion: 0.06
Nodes (36): ../../driver/deliveries/qr_scan_screen.dart, accessToken, _api, build, _buildBody, _buildScanBar, createState, didChangeDependencies (+28 more)

### Community 48 - "return_request_screen.dart"
Cohesion: 0.08
Nodes (24): ImageSource, OrderItem, _addPhoto, build, createState, details, dispose, hasQr (+16 more)

### Community 49 - "reviews_screen.dart"
Cohesion: 0.05
Nodes (39): Review, ReviewSummary, _avatar, build, busy, _chip, createState, error (+31 more)

### Community 50 - "logistics_inventory_screen.dart"
Cohesion: 0.06
Nodes (35): inventory_detail_screen.dart, accessToken, _applyHeld, build, createState, dispose, emptyIcon, emptySubtitle (+27 more)

### Community 51 - "product_pager.dart"
Cohesion: 0.07
Nodes (29): activeFilters, applyFilters, category, dispose, _disposed, error, false, _gen (+21 more)

### Community 52 - "logistics_shell.dart"
Cohesion: 0.05
Nodes (44): dashboard/logistics_dashboard_screen.dart, inventory/logistics_inventory_screen.dart, _accessToken, _account, _accountLoadError, _api, _applyLists, build (+36 more)

### Community 53 - "courier_home_screen.dart"
Cohesion: 0.03
Nodes (78): BoxDecoration get, DateTime? get, ../deliveries/assigned_delivery_detail_screen.dart, accessToken, account, _activity, _activityRow, _amber (+70 more)

### Community 54 - "account_screen.dart"
Cohesion: 0.06
Nodes (33): addresses_screen.dart, _AccountHero, AccountScreen, _AccountScreenState, avatarUrl, build, completeness, count (+25 more)

### Community 55 - "MaterialPageRoute"
Cohesion: 0.07
Nodes (28): build, build, build, _push, _use, build, _reviewsTab, _addStockReplyToCart (+20 more)

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
Cohesion: 0.15
Nodes (19): FlutterViewController, RECT, unique_ptr, FlutterWindow, flutter_controller_, OnCreate, OnDestroy, project_ (+11 more)

### Community 67 - "logistics_dashboard_screen.dart"
Cohesion: 0.08
Nodes (23): int get, account, build, color, error, _fromPickup, _fromTransferDeparture, _fromTransferReceipt (+15 more)

### Community 68 - "deliver_order_screen.dart"
Cohesion: 0.11
Nodes (18): _arrived, _attachPhoto, build, _contactStub, createState, DeliverOrderScreen, _DeliverOrderScreenState, delivery (+10 more)

### Community 69 - "addresses_screen.dart"
Cohesion: 0.08
Nodes (24): address_form_screen.dart, _Action, address, _AddressCard, AddressesScreen, _AddressesScreenState, build, color (+16 more)

### Community 70 - "driver_archived_conversations_screen.dart"
Cohesion: 0.12
Nodes (17): driver_chat_controller.dart, driver_chat_list_screen.dart, build, controller, _conversations, createState, _debounce, dispose (+9 more)

### Community 71 - "win32_window.cpp"
Cohesion: 0.17
Nodes (14): dwmapi, wchar_t, Scale(), Create, Destroy, GetHandle, SetQuitOnClose, Win32Window::Win32Window() (+6 more)

### Community 72 - "pickup_order_screen.dart"
Cohesion: 0.12
Nodes (17): ActiveDelivery, _arrived, _attachPhoto, build, _contactStub, createState, delivery, _handleArrived (+9 more)

### Community 73 - "buyer_shell.dart"
Cohesion: 0.11
Nodes (18): account/account_screen.dart, ../cart/cart_screen.dart, catalog/home_screen.dart, chat/chat_list_screen.dart, _backToSignIn, build, BuyerShell, _BuyerShellState (+10 more)

### Community 74 - "delivery_request_details_screen.dart"
Cohesion: 0.12
Nodes (16): DeliveryRequest, _accept, _addressRow, build, createState, _decline, DeliveryRequestDetailsScreen, _DeliveryRequestDetailsScreenState (+8 more)

### Community 75 - "driver_delivery_message_screen.dart"
Cohesion: 0.11
Nodes (19): ChangeNotifier, chat_models.dart, ChatConversation?, driver_chat_conversation_screen.dart, BuyerStore, ParcelJourneyController, ProductPager, DriverChatController (+11 more)

### Community 76 - "document_viewer_screen.dart"
Cohesion: 0.13
Nodes (15): driver_work_screen.dart, build, _controller, createState, DocumentViewerScreen, _DocumentViewerScreenState, _failed, initState (+7 more)

### Community 77 - "../widgets/buyer_widgets.dart"
Cohesion: 0.11
Nodes (18): Product, ProductVariant, build, createState, initState, mode, product, quantity (+10 more)

### Community 78 - "driver_nav_bar.dart"
Cohesion: 0.12
Nodes (15): badgeCount, _barHeight, build, currentIndex, DriverNavBar, _DriverNavItem, _handleTap, icon (+7 more)

### Community 79 - "courier_navbar.dart"
Cohesion: 0.12
Nodes (17): badgeCount, build, CourierNavBar, _CourierNavBarState, createState, currentIndex, dispose, _handleTap (+9 more)

### Community 80 - "../../services/api_service.dart"
Cohesion: 0.09
Nodes (23): ../driver_theme.dart, codeDigits, codeInputs, confirmPassword, context, error, newPassword, obscure1 (+15 more)

### Community 81 - "payments_util.dart"
Cohesion: 0.13
Nodes (14): alt, d, detectCardBrand, digits, digitsOnly, expiryPassed, luhnValid, m (+6 more)

### Community 82 - "driver_splash_screen.dart"
Cohesion: 0.14
Nodes (14): Animation, _api, build, _controller, createState, dispose, DriverSplashScreen, _DriverSplashScreenState (+6 more)

### Community 83 - "package:flutter/material.dart"
Cohesion: 0.13
Nodes (13): ElevatedButton, build, _buildFeatureItem, SidePanel, package:buytheway/screens/buyer/catalog/home_screen.dart, package:buytheway/screens/driver/deliveries/failed_attempt_sheet.dart, package:ecommerce/main.dart, package:flutter/material.dart (+5 more)

### Community 84 - "buyer_nav_bar.dart"
Cohesion: 0.13
Nodes (14): activeIcon, badgeCount, _barHeight, build, BuyerNavBar, currentIndex, _handleTap, icon (+6 more)

### Community 85 - "chat_assistant.dart"
Cohesion: 0.04
Nodes (48): active, AssistantActions, _body, build, ChatPick, conversationId, createState, dispose (+40 more)

### Community 86 - "utils.cpp"
Cohesion: 0.19
Nodes (12): flutter_windows, _In_, _In_opt_, io, iostream, stdio, wWinMain(), string (+4 more)

### Community 87 - "IconData?"
Cohesion: 0.14
Nodes (13): IconData?, badge, badges, build, currentIndex, _handleTap, icon, _items (+5 more)

### Community 88 - "Development Instructions"
Cohesion: 0.17
Nodes (11): Code Changes, Code Quality & Performance, Communication, Development Instructions, Existing Functionality, Perceived Performance, Project Location, Redesign Permission (+3 more)

### Community 89 - "report_delivered_sheet.dart"
Cohesion: 0.05
Nodes (37): _add, _addPackage, build, busy, contents, createState, _damaged, details (+29 more)

### Community 90 - "payment_qr_screen.dart"
Cohesion: 0.10
Nodes (21): accessToken, _api, build, _busy, _change, createState, dispose, _error (+13 more)

### Community 91 - "ValueChanged"
Cohesion: 0.13
Nodes (14): IconData get, build, _detail, _link, onSelect, RemittanceRecordCard, row, selected (+6 more)

### Community 92 - "MessageHandler"
Cohesion: 0.18
Nodes (10): generated_plugin_registrant, optional, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM (+2 more)

### Community 93 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 94 - "../buyer_store.dart"
Cohesion: 0.12
Nodes (17): ../buyer_store.dart, buyer_widgets.dart, build, _busy, BuyerPaymentQrCard, _BuyerPaymentQrCardState, _change, createState (+9 more)

### Community 95 - "main.dart"
Cohesion: 0.15
Nodes (12): build, buildScrollbar, main, MyApp, _NoScrollbarBehavior, MaterialScrollBehavior, screens/buyer/buyer_shell.dart, screens/driver/auth/driver_splash_screen.dart (+4 more)

### Community 96 - "store_screen.dart"
Cohesion: 0.03
Nodes (72): _aboutRow, _ActionTile, anonymous, _block, build, busy, _claim, claimed (+64 more)

### Community 97 - "driver_forgot_password_screen.dart"
Cohesion: 0.15
Nodes (13): build, createState, dispose, DriverForgotPasswordScreen, _DriverForgotPasswordScreenState, _emailController, _error, _formState (+5 more)

### Community 98 - "VoidCallback?"
Cohesion: 0.25
Nodes (7): common.dart, build, isFullWidth, label, onPressed, OutlineActionButton, VoidCallback?

### Community 99 - "string"
Cohesion: 0.27
Nodes (7): dart_project, flutter_view_controller, functional, memory, string, vector, windows

### Community 100 - "windows/flutter/generated_plugin_registrant.cc"
Cohesion: 0.29
Nodes (5): file_selector_windows, plugin_registry, PluginRegistry, url_launcher_windows, RegisterPlugins()

### Community 101 - "my_reviews_screen.dart"
Cohesion: 0.05
Nodes (43): _amber, _amberDark, _amberSoft, child, _clearFilters, color, _controls, count (+35 more)

### Community 102 - "my_reports_screen.dart"
Cohesion: 0.04
Nodes (46): _buyer, _card, closedCount, _copyReference, createState, _date, didChangeDependencies, dispose (+38 more)

### Community 103 - "logistics_notifications_screen.dart"
Cohesion: 0.05
Nodes (43): ../inventory/inventory_detail_screen.dart, LogisticsNotification, accessToken, _api, build, createState, didChangeDependencies, diff (+35 more)

### Community 106 - "remittances_test.dart"
Cohesion: 0.11
Nodes (18): dart:convert, dart:typed_data, Exception, ApiException, RemittanceApiService, package:buytheway/screens/remittances/remittance_format.dart, package:buytheway/screens/remittances/remittances_screen.dart, package:buytheway/services/api_service.dart (+10 more)

### Community 109 - "remittances_screen.dart"
Cohesion: 0.04
Nodes (51): accessToken, _action, _actionOpen, active, api, _applyHeld, _batchPayment, build (+43 more)

### Community 110 - "parcel_tracking.dart"
Cohesion: 0.06
Nodes (35): ParcelJourney, build, controller, createState, _ctrl, dispose, _disposed, events (+27 more)

### Community 112 - "address_pin_picker.dart"
Cohesion: 0.06
Nodes (35): LatLng?, AddressPinPreview, barangay, build, center, _confirm, controller, createState (+27 more)

### Community 113 - "remittance_action_screen.dart"
Cohesion: 0.06
Nodes (33): int?, action, _amount, api, build, _busy, _bytes, _changed (+25 more)

### Community 114 - "MessageHandler"
Cohesion: 0.38
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetThisFromHandle, MessageHandler (+2 more)

### Community 115 - "remittance_api_service.dart"
Cohesion: 0.07
Nodes (29): api_service.dart, Client, accessToken, _base, _client, close, _decode, dispute (+21 more)

### Community 116 - "remittance_detail_screen.dart"
Cohesion: 0.09
Nodes (23): api, build, createState, didChangeDependencies, dispose, _error, _fetch, id (+15 more)

### Community 117 - "voucher_quote.dart"
Cohesion: 0.06
Nodes (32): double?, amount, applicable, bestDiscountId, bestShippingId, categories, conditions, count (+24 more)

### Community 118 - "../../widgets/driver_shared_widgets.dart"
Cohesion: 0.22
Nodes (9): ../driver_models.dart, DriverAccount, account, build, createState, DriverVehicleDocumentsScreen, _DriverVehicleDocumentsScreenState, _refresh (+1 more)

### Community 119 - "Point"
Cohesion: 0.21
Nodes (6): Point, x, y, Size, height, width

### Community 120 - "settings_kit.dart"
Cohesion: 0.06
Nodes (30): actionLabel, actions, bottomBar, build, children, color, count, EmptyCard (+22 more)

### Community 121 - "voucher_sheet.dart"
Cohesion: 0.07
Nodes (30): VoucherOffer, VoucherOption, background, build, _choose, color, createState, discount (+22 more)

### Community 122 - "search_filter_sheet.dart"
Cohesion: 0.07
Nodes (28): Future, _apply, _availability, build, _categories, _category, createState, dispose (+20 more)

### Community 124 - "../buyer_theme.dart"
Cohesion: 0.07
Nodes (30): ../buyer_theme.dart, home_screen.dart, build, createState, dispose, _pagerFor, _pagers, _selected (+22 more)

### Community 125 - "address_sheet.dart"
Cohesion: 0.12
Nodes (17): ../account/address_form_screen.dart, ../account/settings_kit.dart, Address, _AddressSheet, _AddressSheetState, build, busyId, chosen (+9 more)

### Community 126 - "List"
Cohesion: 0.14
Nodes (14): build, createState, dispose, _header, OrderPlacedScreen, _OrderPlacedScreenState, pager, paymentMethod (+6 more)

### Community 127 - "SliverPersistentHeaderDelegate"
Cohesion: 0.50
Nodes (4): _PinnedHeader, _PinnedHeader, _TabsDelegate, SliverPersistentHeaderDelegate

### Community 128 - "package:flutter/services.dart"
Cohesion: 0.14
Nodes (13): build, _CheckBadge, duration, message, paint, progress, shouldRepaint, showSuccessPopup (+5 more)

### Community 130 - "../buyer_models.dart"
Cohesion: 0.14
Nodes (13): ../buyer_models.dart, Color, Coupon, build, claimed, claiming, color, coupon (+5 more)

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

### Community 147 - "static const"
Cohesion: 0.18
Nodes (11): FormState, build, createState, _description, dispose, FailedAttemptSheet, _FailedAttemptSheetState, _formKey (+3 more)

### Community 148 - "brand_splash_screen.dart"
Cohesion: 0.17
Nodes (12): AnimationController, ../auth/auth_screen.dart, dart:math, BrandSplashScreen, _BrandSplashScreenState, build, _controller, createState (+4 more)

### Community 161 - "remittance_format.dart"
Cohesion: 0.10
Nodes (20): isNotEmpty
      ?, _LocalMobileFormatter, amount, business, cents, digits, formatEditUpdate, parse (+12 more)

### Community 162 - "dart:async"
Cohesion: 0.17
Nodes (12): dart:async, build, buyerToken, createState, _error, initState, _loading, _open (+4 more)

### Community 169 - "../driver/driver_theme.dart"
Cohesion: 0.15
Nodes (12): ../driver/driver_theme.dart, ../../driver/settings/driver_change_password_sheet.dart, ../driver/widgets/driver_shared_widgets.dart, LogisticsAccount, accessToken, account, build, _confirmSignOut (+4 more)

### Community 170 - "CustomPainter"
Cohesion: 0.25
Nodes (8): CustomPainter, _TicketPainter, DealDashPainter, _CheckPainter, _RouteGridPainter, _RoutePathPainter, _BagLogoPainter, _GoogleMarkPainter

## Knowledge Gaps
- **4199 isolated node(s):** `main`, `build`, `buildScrollbar`, `AuthPortal`, `kRegionOptions` (+4194 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 4406 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **42 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `string`, `win32_window.cpp`, `MessageHandler`, `Point`, `MessageHandler`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `Point` connect `Point` to `Win32Window`, `win32_window.cpp`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **What connects `main`, `build`, `buildScrollbar` to the rest of the system?**
  _4199 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `auth_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.008333333333333333 - nodes in this community are weakly interconnected._
- **Should `driver_work_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.009216589861751152 - nodes in this community are weakly interconnected._
- **Should `buyer_models.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.00909090909090909 - nodes in this community are weakly interconnected._
- **Should `driver_models.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.01652892561983471 - nodes in this community are weakly interconnected._