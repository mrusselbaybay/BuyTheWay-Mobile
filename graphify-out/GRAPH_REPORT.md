# Graph Report - BuyTheWay - Mobile  (2026-10-14)

## Corpus Check
- 138 files · ~203,727 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 53 file(s) not represented in the graph (top: .xcconfig 8, (none) 7, .xml 7)

## Summary
- 4565 nodes · 6197 edges · 159 communities (119 shown, 40 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `641e7322`
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
- ../buyer_theme.dart
- account_screen.dart
- MaterialPageRoute
- vouchers_screen.dart
- cart_screen.dart
- driver_earnings_screen.dart
- wishlist_screen.dart
- review_sheet.dart
- driver_otp_screen.dart
- order_actions.dart
- StatefulWidget
- search_screen.dart
- password_strength_meter.dart
- Win32Window
- logistics_dashboard_screen.dart
- deliver_order_screen.dart
- addresses_screen.dart
- driver_archived_conversations_screen.dart
- win32_window.cpp
- pickup_order_screen.dart
- ../widgets/buyer_widgets.dart
- delivery_request_details_screen.dart
- driver_delivery_message_screen.dart
- document_viewer_screen.dart
- variant_sheet.dart
- ValueChanged
- IconData?
- ../driver_theme.dart
- payments_util.dart
- driver_splash_screen.dart
- package:flutter/material.dart
- package:flutter/services.dart
- SolidField
- utils.cpp
- ../../driver/driver_theme.dart
- Development Instructions
- brand_splash_screen.dart
- flutter_window.h
- MessageHandler
- manifest.json
- ../../widgets/driver_shared_widgets.dart
- main.dart
- store_screen.dart
- MessageHandler
- VoidCallback?
- Point
- windows/flutter/generated_plugin_registrant.cc
- my_reviews_screen.dart
- my_reports_screen.dart
- DriverChatController
- MainActivity.kt
- c_users_russel_onedrive_documents_buytheway_folders_buytheway_mobile_ios_runner_generatedpluginregistrant_h
- ApiException
- LaunchImage.imageset/README.md
- AuthScreen
- AddressFormScreen
- _PlacePicker
- CheckoutScreen
- address_pin_picker.dart
- logistics_settings_screen.dart
- CustomPainter
- _AssignedDeliveryDetailScreenState
- voucher_quote.dart
- DriverDeliveriesScreen
- _MissionCard
- settings_kit.dart
- voucher_sheet.dart
- search_filter_sheet.dart
- ApplicationStatus
- product_list_screen.dart
- ../buyer_store.dart
- order_placed_screen.dart
- List
- dart:async
- PickupPriority
- ../buyer_models.dart
- SliverPersistentHeaderDelegate
- LabeledField
- PressableScale
- @abclogistics
- @email
- @example
- bool?
- String?
- _TicketClipper
- SingleTickerProviderStateMixin
- BuyerReportDetailScreen
- BuyerReportsScreen
- _DeactivateDialog
- _LocalMobileFormatter
- BuyerBlockedShopsScreen
- BuyerFollowingScreen
- BuyerNotificationsScreen
- BuyerPrivacyScreen
- BuyerSecurityScreen
- _AllTab
- _VoucherHistoryScreen
- _ReportSheet
- StoreScreen
- ProductDetailScreen
- _PulsingDotState
- _AuroraBackgroundState

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

## Communities (159 total, 40 thin omitted)

### Community 0 - "auth_screen.dart"
Cohesion: 0.01
Nodes (239): _addressError, _addressFields, _allControllers, _allRoles, _api, _appBarTitle, AuthPortal, _authToken (+231 more)

### Community 1 - "driver_work_screen.dart"
Cohesion: 0.01
Nodes (211): document_viewer_screen.dart, accent, accessToken, _allRegions, alreadyApplied, _apiService, application, _applicationFormColumn (+203 more)

### Community 2 - "buyer_models.dart"
Cohesion: 0.01
Nodes (187): anonymous, archived, at, attachments, author, autoApplied, available, avatarUrl (+179 more)

### Community 3 - "driver_models.dart"
Cohesion: 0.02
Nodes (115): accountStatus, actualMinutes, amount, applyFrom, assignedAt, AssignedDeliveryItem, AssignedDeliveryStatus, avatarInitial (+107 more)

### Community 4 - "courier_dashboard.dart"
Cohesion: 0.02
Nodes (98): acceptanceRate, actionLabel, address, amount, _bar, _breakdownByPeriod, _breakdownCard, _clock (+90 more)

### Community 5 - "buyer_widgets.dart"
Cohesion: 0.02
Nodes (89): BoxFit, Completer, dart:collection, ImageProvider, ImageStream?, ImageStreamListener?, acquire, action (+81 more)

### Community 6 - "settings_widgets.dart"
Cohesion: 0.03
Nodes (78): ageFor, avatarUrl, background, build, busy, capitalize, children, controller (+70 more)

### Community 7 - "buyer_store.dart"
Cohesion: 0.02
Nodes (94): Address? get, BuyerProfile, addressError, addresses, _addressesLoaded, addToCart, allSelected, api (+86 more)

### Community 8 - "driver_shared_widgets.dart"
Cohesion: 0.03
Nodes (78): ../chat/chat_models.dart, DeliveryStage, accent, actionLabel, attachment, _AttachmentCard, avatarUrl, _bubbles (+70 more)

### Community 9 - "common.dart"
Cohesion: 0.03
Nodes (73): EdgeInsetsGeometry, AppColors, _blob, blur, borderOpacity, borderRadius, build, _c (+65 more)

### Community 10 - "api_service.dart"
Cohesion: 0.03
Nodes (68): dart:io, bytes, cancelResignationRequest, _configuredBaseUrl, confirmParcelTransfer, deactivateDriverAccount, _deliveryAttemptAction, errors (+60 more)

### Community 11 - "solid_ui.dart"
Cohesion: 0.03
Nodes (64): brand_logo.dart, Iterable, autofillHints, build, child, controller, createState, currentIndex (+56 more)

### Community 12 - "buyer_api_service.dart"
Cohesion: 0.03
Nodes (72): api_service.dart, addPaymentMethod, addresses, addToWishlist, blockShop, BuyerApiService, cancelOrder, checkout (+64 more)

### Community 13 - "driver_chat_controller.dart"
Cohesion: 0.03
Nodes (61): _accessToken, _activeConversationId, _api, _appVisible, _attachmentUrlCache, closeConversation, conversationById, _conversations (+53 more)

### Community 14 - "driver_profile_info_screen.dart"
Cohesion: 0.03
Nodes (62): GlobalKey, accessToken, account, _addressCard, _addressLoadError, _addressSectionKey, _api, autoEdit (+54 more)

### Community 15 - "checkout_screen.dart"
Cohesion: 0.03
Nodes (67): ../account/addresses_screen.dart, address, _AddressPanel, build, _card, _clearShopVouchers, _collapsed, createState (+59 more)

### Community 16 - "chat_models.dart"
Cohesion: 0.03
Nodes (57): allowedTypes, applyFrom, archived, AttachmentPolicy, attachments, bytes, ChatAttachment, ChatConversation (+49 more)

### Community 17 - "assigned_delivery_detail_screen.dart"
Cohesion: 0.04
Nodes (52): ../chat/driver_delivery_message_screen.dart, failed_attempt_sheet.dart, accessToken, _actionTag, _api, _applyScannedProof, _attachPicture, build (+44 more)

### Community 18 - "buyer_theme.dart"
Cohesion: 0.03
Nodes (57): background, base, BButtons, BColors, body, border, BRadius, brand (+49 more)

### Community 19 - "driver_shell.dart"
Cohesion: 0.04
Nodes (53): chat/driver_chat_controller.dart, chat/driver_chat_list_screen.dart, deliveries/driver_deliveries_screen.dart, earnings/driver_earnings_screen.dart, history/driver_history_screen.dart, home/deliver_order_screen.dart, home/delivery_request_details_screen.dart, home/driver_home_screen.dart (+45 more)

### Community 20 - "orders_screen.dart"
Cohesion: 0.04
Nodes (57): build, _busy, _CartButton, controller, createState, dispose, formatDate, _headline (+49 more)

### Community 21 - "StatelessWidget"
Cohesion: 0.04
Nodes (55): BCheck, CategoryThumb, DiscountBadge, DiscountRibbon, EmptyState, ErrorState, _ImageFallback, NetImage (+47 more)

### Community 22 - "driver_deliveries_screen.dart"
Cohesion: 0.04
Nodes (51): assigned_delivery_detail_screen.dart, accessToken, _actionsWidth, active, _alertExpanded, atRisk, _atRiskAfter, build (+43 more)

### Community 23 - "order_detail_screen.dart"
Cohesion: 0.04
Nodes (57): ../catalog/product_list_screen.dart, ../chat/chat_thread_screen.dart, EdgeInsets, StatusEvent, _AddressRow, _AddressRowState, _BarButton, _BottomBar (+49 more)

### Community 24 - "product_detail_screen.dart"
Cohesion: 0.03
Nodes (76): ../catalog/search_screen.dart, _addToCart, _BottomBar, _card, child, _claim, claimedCoupons, claimingCoupons (+68 more)

### Community 25 - "chat_thread_screen.dart"
Cohesion: 0.04
Nodes (47): chat_list_screen.dart, ChatAttachment, ChatMessage, api, at, _attach, attachment, _AttachmentView (+39 more)

### Community 26 - "logistics_models.dart"
Cohesion: 0.04
Nodes (44): address, buyer, companyName, confirmationToken, contactNo, courier, dimensions, email (+36 more)

### Community 27 - "home_screen.dart"
Cohesion: 0.05
Nodes (36): ../account/wishlist_screen.dart, categories_screen.dart, actionLabel, _ActiveOrderCard, alpha, badge, _CategoryRail, _Circle (+28 more)

### Community 28 - "driver_history_screen.dart"
Cohesion: 0.04
Nodes (46): DateTimeRange?, AssignedDelivery, accessToken, _api, avgMinutes, _body, build, _call (+38 more)

### Community 29 - "settings_screens.dart"
Cohesion: 0.04
Nodes (49): actionLabel, audience, blocked, blockedLabel, build, busy, busyId, _buyer (+41 more)

### Community 30 - "address_form_screen.dart"
Cohesion: 0.04
Nodes (47): address_pin_picker.dart, _api, barangay, build, city, _clearPin, code, createState (+39 more)

### Community 31 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.06
Nodes (29): Any, Cocoa, file_picker, file_selector_macos, Flutter, FlutterAppDelegate, FlutterMacOS, FlutterPluginRegistry (+21 more)

### Community 32 - "driver_register_screen.dart"
Cohesion: 0.06
Nodes (36): driver_otp_screen.dart, ../driver_shell.dart, build, createState, dispose, DriverForgotPasswordScreen, _DriverForgotPasswordScreenState, _emailController (+28 more)

### Community 33 - "chat_list_screen.dart"
Cohesion: 0.06
Nodes (36): chat_thread_screen.dart, _actions, archived, build, ChatAvatar, ChatListScreen, _ChatListScreenState, chatTimeLabel (+28 more)

### Community 34 - "image_crop_sheet.dart"
Cohesion: 0.06
Nodes (36): dart:ui, Image?, _askImageSource, _baseScale, build, bytes, _clamp, context (+28 more)

### Community 35 - "State"
Cohesion: 0.10
Nodes (22): _ProfileScreenState, _ApplyPage, __ApplyPageState, DriverWorkScreen, _DriverWorkScreenState, EmploymentBanner, _EmploymentBannerState, ResignationRequestSheet (+14 more)

### Community 36 - "brand_logo.dart"
Cohesion: 0.04
Nodes (44): FormState, build, createState, _description, dispose, FailedAttemptSheet, _FailedAttemptSheetState, _formKey (+36 more)

### Community 37 - "driver_home_screen.dart"
Cohesion: 0.06
Nodes (33): DateTime?, Duration, account, activeDelivery, _activeDeliveryCard, availableRequests, build, _clock (+25 more)

### Community 38 - "driver_chat_conversation_screen.dart"
Cohesion: 0.06
Nodes (33): _archivedNotice, _AttachmentSourceSheet, _AttachSource, _body, build, _composer, controller, conversation (+25 more)

### Community 39 - "my_application.cc"
Cohesion: 0.08
Nodes (27): file_selector_plugin, FlPluginRegistry, flutter_linux, FlView, GApplication, gboolean, gchar, gdkx (+19 more)

### Community 40 - "profile_screen.dart"
Cohesion: 0.04
Nodes (56): _avatar, birthday, _changeAvatar, color, _Consequence, contact, controller, _controllers (+48 more)

### Community 41 - "driver_chat_list_screen.dart"
Cohesion: 0.07
Nodes (30): driver_archived_conversations_screen.dart, _ArchiveShortcut, build, ChatConversationRow, _content, controller, conversation, createState (+22 more)

### Community 42 - "driver_login_screen.dart"
Cohesion: 0.07
Nodes (30): driver_forgot_password_screen.dart, driver_register_screen.dart, FocusNode, _api, _biometricStub, build, controller, createState (+22 more)

### Community 43 - "driver_theme.dart"
Cohesion: 0.07
Nodes (29): background, body, border, caption, DriverButtonStyle, DriverColors, DriverText, error (+21 more)

### Community 44 - "driver_settings_screen.dart"
Cohesion: 0.06
Nodes (31): ../auth/driver_login_screen.dart, driver_change_password_sheet.dart, driver_deactivate_account_dialog.dart, driver_profile_info_screen.dart, driver_vehicle_documents_screen.dart, ../earnings/driver_payslip_screen.dart, accessToken, account (+23 more)

### Community 45 - "qr_scan_screen.dart"
Cohesion: 0.07
Nodes (28): build, _controller, createState, dispose, expectedToken, _feedback, _feedbackTimer, _flashFeedback (+20 more)

### Community 46 - "driver_payslip_screen.dart"
Cohesion: 0.07
Nodes (27): dart:convert, accessToken, build, _busy, _cashout, _client, createState, _date (+19 more)

### Community 47 - "inventory_detail_screen.dart"
Cohesion: 0.08
Nodes (26): ../../driver/deliveries/qr_scan_screen.dart, QrScanResult, accessToken, _api, build, _buildBody, _buildScanBar, createState (+18 more)

### Community 48 - "return_request_screen.dart"
Cohesion: 0.08
Nodes (24): dart:typed_data, ImageSource, Order, OrderItem, _addPhoto, build, createState, details (+16 more)

### Community 49 - "reviews_screen.dart"
Cohesion: 0.06
Nodes (38): Review, ReviewSummary, _avatar, busy, _chip, createState, error, _ExpandableText (+30 more)

### Community 50 - "logistics_inventory_screen.dart"
Cohesion: 0.08
Nodes (25): inventory_detail_screen.dart, accessToken, build, createState, dispose, emptyIcon, emptySubtitle, emptyTitle (+17 more)

### Community 51 - "product_pager.dart"
Cohesion: 0.06
Nodes (30): buyer_widgets.dart, activeFilters, applyFilters, category, dispose, _disposed, error, false (+22 more)

### Community 52 - "logistics_shell.dart"
Cohesion: 0.09
Nodes (23): dashboard/logistics_dashboard_screen.dart, inventory/logistics_inventory_screen.dart, _accessToken, _account, _accountLoadError, _api, build, createState (+15 more)

### Community 53 - "../buyer_theme.dart"
Cohesion: 0.12
Nodes (17): AutomaticKeepAliveClientMixin, bool get, ../buyer_theme.dart, HomeScreen, build, CategoriesScreen, _CategoriesScreenState, createState (+9 more)

### Community 54 - "account_screen.dart"
Cohesion: 0.06
Nodes (34): addresses_screen.dart, _AccountHero, AccountScreen, _AccountScreenState, avatarUrl, build, completeness, count (+26 more)

### Community 55 - "MaterialPageRoute"
Cohesion: 0.08
Nodes (26): build, build, build, _push, _use, build, _checkout, build (+18 more)

### Community 56 - "vouchers_screen.dart"
Cohesion: 0.03
Nodes (57): active, background, body, borderColor, build, _canUse, _cartButton, color (+49 more)

### Community 57 - "cart_screen.dart"
Cohesion: 0.06
Nodes (35): address_sheet.dart, ../catalog/store_screen.dart, ../checkout/checkout_screen.dart, CartItem, _AddressLine, _CartLine, CartScreen, _CartScreenState (+27 more)

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
Nodes (20): ../buyer_shell.dart, added, build, busy, _cancel, _cancelReasons, _CancelSheet, _CancelSheetState (+12 more)

### Community 63 - "StatefulWidget"
Cohesion: 0.17
Nodes (12): ProfileScreen, CourierDashboard, _CourierDashboardState, HomeScreen, PickupsScreen, _PickupsScreenState, ProfileScreen, SalaryScreen (+4 more)

### Community 64 - "search_screen.dart"
Cohesion: 0.07
Nodes (29): build, controller, createState, _debounce, _discover, dispose, _fetch, initial (+21 more)

### Community 65 - "password_strength_meter.dart"
Cohesion: 0.12
Nodes (17): build, label, meetsMinimum, of, password, PasswordRule, PasswordStrength, PasswordStrengthMeter (+9 more)

### Community 66 - "Win32Window"
Cohesion: 0.15
Nodes (19): FlutterViewController, RECT, unique_ptr, FlutterWindow, flutter_controller_, OnCreate, OnDestroy, project_ (+11 more)

### Community 67 - "logistics_dashboard_screen.dart"
Cohesion: 0.11
Nodes (18): int get, account, build, color, error, _fromPickup, _fromTransferDeparture, _fromTransferReceipt (+10 more)

### Community 68 - "deliver_order_screen.dart"
Cohesion: 0.11
Nodes (18): _arrived, _attachPhoto, build, _contactStub, createState, DeliverOrderScreen, _DeliverOrderScreenState, delivery (+10 more)

### Community 69 - "addresses_screen.dart"
Cohesion: 0.08
Nodes (26): address_form_screen.dart, _Action, address, _AddressCard, AddressesScreen, _AddressesScreenState, build, color (+18 more)

### Community 70 - "driver_archived_conversations_screen.dart"
Cohesion: 0.12
Nodes (17): driver_chat_controller.dart, driver_chat_list_screen.dart, build, controller, _conversations, createState, _debounce, dispose (+9 more)

### Community 71 - "win32_window.cpp"
Cohesion: 0.17
Nodes (14): dwmapi, wchar_t, Scale(), Create, Destroy, GetHandle, SetQuitOnClose, Win32Window::Win32Window() (+6 more)

### Community 72 - "pickup_order_screen.dart"
Cohesion: 0.12
Nodes (17): ActiveDelivery, _arrived, _attachPhoto, build, _contactStub, createState, delivery, _handleArrived (+9 more)

### Community 73 - "../widgets/buyer_widgets.dart"
Cohesion: 0.11
Nodes (18): account/account_screen.dart, catalog/home_screen.dart, chat/chat_list_screen.dart, _backToSignIn, build, BuyerShell, _BuyerShellState, createState (+10 more)

### Community 74 - "delivery_request_details_screen.dart"
Cohesion: 0.12
Nodes (16): DeliveryRequest, _accept, _addressRow, build, createState, _decline, DeliveryRequestDetailsScreen, _DeliveryRequestDetailsScreenState (+8 more)

### Community 75 - "driver_delivery_message_screen.dart"
Cohesion: 0.14
Nodes (14): chat_models.dart, ChatConversation?, driver_chat_conversation_screen.dart, build, contact, controller, _conversation, createState (+6 more)

### Community 76 - "document_viewer_screen.dart"
Cohesion: 0.13
Nodes (15): driver_work_screen.dart, build, _controller, createState, DocumentViewerScreen, _DocumentViewerScreenState, _failed, initState (+7 more)

### Community 77 - "variant_sheet.dart"
Cohesion: 0.11
Nodes (18): Product, ProductVariant, build, createState, initState, mode, product, quantity (+10 more)

### Community 78 - "ValueChanged"
Cohesion: 0.12
Nodes (16): badgeCount, build, currentIndex, DriverNavBar, _DriverNavItem, _handleTap, icon, _inactive (+8 more)

### Community 79 - "IconData?"
Cohesion: 0.11
Nodes (18): IconData?, badgeCount, build, CourierNavBar, _CourierNavBarState, createState, currentIndex, dispose (+10 more)

### Community 80 - "../driver_theme.dart"
Cohesion: 0.09
Nodes (23): ../driver_theme.dart, codeDigits, codeInputs, confirmPassword, context, error, newPassword, obscure1 (+15 more)

### Community 81 - "payments_util.dart"
Cohesion: 0.13
Nodes (14): alt, d, detectCardBrand, digits, digitsOnly, expiryPassed, luhnValid, m (+6 more)

### Community 82 - "driver_splash_screen.dart"
Cohesion: 0.13
Nodes (15): Animation, driver_login_screen.dart, _api, build, _controller, createState, dispose, DriverSplashScreen (+7 more)

### Community 83 - "package:flutter/material.dart"
Cohesion: 0.13
Nodes (13): ElevatedButton, build, _buildFeatureItem, SidePanel, package:buytheway/screens/buyer/catalog/home_screen.dart, package:buytheway/screens/driver/deliveries/failed_attempt_sheet.dart, package:ecommerce/main.dart, package:flutter/material.dart (+5 more)

### Community 84 - "package:flutter/services.dart"
Cohesion: 0.12
Nodes (15): activeIcon, badgeCount, _barHeight, build, BuyerNavBar, currentIndex, _handleTap, icon (+7 more)

### Community 86 - "utils.cpp"
Cohesion: 0.19
Nodes (12): flutter_windows, _In_, _In_opt_, io, iostream, stdio, wWinMain(), string (+4 more)

### Community 87 - "../../driver/driver_theme.dart"
Cohesion: 0.17
Nodes (11): ../../driver/driver_theme.dart, build, currentIndex, _handleTap, icon, _items, label, LogisticsNavBar (+3 more)

### Community 88 - "Development Instructions"
Cohesion: 0.17
Nodes (11): Code Changes, Code Quality & Performance, Communication, Development Instructions, Existing Functionality, Perceived Performance, Project Location, Redesign Permission (+3 more)

### Community 90 - "brand_splash_screen.dart"
Cohesion: 0.17
Nodes (12): AnimationController, ../auth/auth_screen.dart, dart:math, BrandSplashScreen, _BrandSplashScreenState, build, _controller, createState (+4 more)

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
Cohesion: 0.22
Nodes (9): ../driver_models.dart, DriverAccount, account, build, createState, DriverVehicleDocumentsScreen, _DriverVehicleDocumentsScreenState, _refresh (+1 more)

### Community 95 - "main.dart"
Cohesion: 0.15
Nodes (12): build, buildScrollbar, main, MyApp, _NoScrollbarBehavior, MaterialScrollBehavior, screens/buyer/buyer_shell.dart, screens/driver/auth/driver_splash_screen.dart (+4 more)

### Community 96 - "store_screen.dart"
Cohesion: 0.03
Nodes (69): _aboutRow, _ActionTile, anonymous, _block, build, busy, _claim, claimed (+61 more)

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

### Community 101 - "my_reviews_screen.dart"
Cohesion: 0.05
Nodes (43): _amber, _amberDark, _amberSoft, child, _clearFilters, color, _controls, count (+35 more)

### Community 102 - "my_reports_screen.dart"
Cohesion: 0.05
Nodes (37): _buyer, _card, closedCount, _copyReference, createState, _date, error, _fact (+29 more)

### Community 103 - "DriverChatController"
Cohesion: 0.50
Nodes (4): ChangeNotifier, BuyerStore, ProductPager, DriverChatController

### Community 112 - "address_pin_picker.dart"
Cohesion: 0.06
Nodes (36): LatLng?, AddressPinPreview, barangay, build, center, _confirm, controller, createState (+28 more)

### Community 113 - "logistics_settings_screen.dart"
Cohesion: 0.18
Nodes (10): ../../driver/settings/driver_change_password_sheet.dart, ../../driver/widgets/driver_shared_widgets.dart, LogisticsAccount, accessToken, account, build, _confirmSignOut, LogisticsSettingsScreen (+2 more)

### Community 114 - "CustomPainter"
Cohesion: 0.25
Nodes (8): CustomPainter, _TicketPainter, DealDashPainter, _CheckPainter, _RouteGridPainter, _RoutePathPainter, _BagLogoPainter, _GoogleMarkPainter

### Community 115 - "_AssignedDeliveryDetailScreenState"
Cohesion: 0.67
Nodes (3): AssignedDeliveryDetailScreen, _AssignedDeliveryDetailScreenState, WidgetsBindingObserver

### Community 117 - "voucher_quote.dart"
Cohesion: 0.06
Nodes (33): double?, int?, amount, applicable, bestDiscountId, bestShippingId, categories, conditions (+25 more)

### Community 120 - "settings_kit.dart"
Cohesion: 0.06
Nodes (30): actionLabel, actions, bottomBar, build, children, color, count, EmptyCard (+22 more)

### Community 121 - "voucher_sheet.dart"
Cohesion: 0.07
Nodes (30): VoucherOffer, VoucherOption, background, build, _choose, color, createState, discount (+22 more)

### Community 122 - "search_filter_sheet.dart"
Cohesion: 0.07
Nodes (28): Future, _apply, _availability, build, _categories, _category, createState, dispose (+20 more)

### Community 124 - "product_list_screen.dart"
Cohesion: 0.11
Nodes (19): home_screen.dart, build, category, createState, dispose, initState, _loadStores, pager (+11 more)

### Community 125 - "../buyer_store.dart"
Cohesion: 0.12
Nodes (17): ../account/address_form_screen.dart, ../account/settings_kit.dart, ../buyer_store.dart, _AddressSheet, _AddressSheetState, build, busyId, chosen (+9 more)

### Community 126 - "order_placed_screen.dart"
Cohesion: 0.13
Nodes (15): ../cart/cart_screen.dart, build, createState, dispose, _header, OrderPlacedScreen, _OrderPlacedScreenState, pager (+7 more)

### Community 127 - "List"
Cohesion: 0.15
Nodes (13): ../../driver/settings/widgets/settings_widgets.dart, build, createState, _delete, error, initState, _load, methods (+5 more)

### Community 128 - "dart:async"
Cohesion: 0.14
Nodes (13): dart:async, build, _CheckBadge, duration, message, paint, progress, shouldRepaint (+5 more)

### Community 130 - "../buyer_models.dart"
Cohesion: 0.14
Nodes (13): ../buyer_models.dart, Color, Coupon, build, claimed, claiming, color, coupon (+5 more)

### Community 131 - "SliverPersistentHeaderDelegate"
Cohesion: 0.50
Nodes (4): _PinnedHeader, _PinnedHeader, _TabsDelegate, SliverPersistentHeaderDelegate

### Community 143 - "_TicketClipper"
Cohesion: 0.67
Nodes (3): CustomClipper, _TicketClipper, Path

### Community 144 - "SingleTickerProviderStateMixin"
Cohesion: 0.67
Nodes (3): VouchersScreen, _VouchersScreenState, SingleTickerProviderStateMixin

## Knowledge Gaps
- **3503 isolated node(s):** `main`, `build`, `buildScrollbar`, `AuthPortal`, `kRegionOptions` (+3498 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 3694 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **40 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `MessageHandler`, `Point`, `win32_window.cpp`, `flutter_window.h`, `MessageHandler`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `FlutterWindow` connect `Win32Window` to `flutter_window.h`, `MessageHandler`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **What connects `main`, `build`, `buildScrollbar` to the rest of the system?**
  _3503 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `auth_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.008333333333333333 - nodes in this community are weakly interconnected._
- **Should `driver_work_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.009433962264150943 - nodes in this community are weakly interconnected._
- **Should `buyer_models.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.010638297872340425 - nodes in this community are weakly interconnected._
- **Should `driver_models.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.017241379310344827 - nodes in this community are weakly interconnected._