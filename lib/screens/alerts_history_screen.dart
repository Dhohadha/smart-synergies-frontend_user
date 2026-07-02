import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/device_provider.dart';
import '../providers/user_provider.dart';
import '../core/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class AlertsHistoryScreen extends ConsumerStatefulWidget {
  const AlertsHistoryScreen({super.key});

  @override
  ConsumerState<AlertsHistoryScreen> createState() => _AlertsHistoryScreenState();
}

class _AlertsHistoryScreenState extends ConsumerState<AlertsHistoryScreen> {
  final Set<String> _pendingDeletes = {};
  final Set<String> _selectedItems = {};
  bool _isDeletingBatch = false;

  void _toggleSelection(String key) {
    setState(() {
      if (_selectedItems.contains(key)) {
        _selectedItems.remove(key);
      } else {
        _selectedItems.add(key);
      }
    });
  }

  void _selectAll(List<Map<String, dynamic>> allHistory) {
    setState(() {
      if (_selectedItems.length == allHistory.length) {
        _selectedItems.clear(); // Deselect all if all are already selected
      } else {
        _selectedItems.addAll(allHistory.map((e) => e['uniqueKey'] as String));
      }
    });
  }

  Future<void> _deleteSelected(List<Map<String, dynamic>> allHistory) async {
    setState(() => _isDeletingBatch = true);
    
    final itemsToDelete = allHistory.where((e) => _selectedItems.contains(e['uniqueKey'] as String)).toList();
    
    int successCount = 0;
    Set<String> devicesToInvalidate = {};

    for (var item in itemsToDelete) {
      final deviceId = item['deviceId'] as String;
      final historyId = item['_id'] as String;
      
      final success = await deleteDeviceHistoryItem(deviceId, historyId);
      if (success) {
        successCount++;
        devicesToInvalidate.add(deviceId);
      }
    }

    if (mounted) {
      setState(() {
        _isDeletingBatch = false;
        _selectedItems.clear();
      });
      
      for (var d in devicesToInvalidate) {
        ref.invalidate(historyProvider(d));
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $successCount notifications.', style: GoogleFonts.outfit()),
          backgroundColor: AppColors.cyan,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userState.value == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Text('Please log in.', style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark))),
        ),
      );
    }

    final devices = (userState.value!['assignedDevices'] as List<dynamic>? ?? [])
        .cast<String>()
        .toList();

    if (devices.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        ),
        body: Center(
          child: Text('No devices assigned.', style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark))),
        ),
      );
    }

    // Watch all history providers reactively
    final List<AsyncValue<List<dynamic>>> historyStates = devices.map((id) {
      return ref.watch(historyProvider(id));
    }).toList();

    // Check loading and error states across all watched devices
    final anyLoading = historyStates.any((state) => state.isLoading);
    final anyError = historyStates.any((state) => state.hasError);

    if (anyLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      );
    }

    if (anyError) {
      final errorState = historyStates.firstWhere((state) => state.hasError);
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        ),
        body: Center(
          child: Text('Error loading history: ${errorState.error}', 
            style: GoogleFonts.outfit(color: AppColors.red)),
        ),
      );
    }

    // Merge and attach device label context
    final List<Map<String, dynamic>> allHistory = [];
    for (int i = 0; i < devices.length; i++) {
      final deviceId = devices[i];
      final deviceHistory = historyStates[i].value ?? [];
      
      // Resolve device friendly name
      final deviceState = ref.watch(deviceProvider(deviceId)).value;
      final displayName = deviceState?.name != null && deviceState!.name!.isNotEmpty
          ? deviceState.name!
          : 'Device $deviceId';

      for (var item in deviceHistory) {
        final historyId = item['_id'] ?? '';
        final uniqueKey = '${item['timestamp']}_${deviceId}_$historyId';
        
        if (_pendingDeletes.contains(uniqueKey)) continue;

        final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
        itemMap['deviceId'] = deviceId;
        itemMap['deviceName'] = displayName;
        itemMap['uniqueKey'] = uniqueKey;
        allHistory.add(itemMap);
      }
    }

    if (allHistory.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: Text('Notifications History', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        ),
        body: Center(
          child: Text('No history found.', style: GoogleFonts.outfit(color: AppColors.getTextMuted(isDark))),
        ),
      );
    }

    // Sort descending by timestamp
    allHistory.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: _selectedItems.isNotEmpty
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                color: AppColors.getTextPrimary(isDark),
                onPressed: () => setState(() => _selectedItems.clear()),
              ),
              title: Text('${_selectedItems.length} Selected', 
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
              backgroundColor: AppColors.cyan.withValues(alpha: 0.1),
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select All',
                  color: AppColors.cyan,
                  onPressed: () => _selectAll(allHistory),
                ),
                if (_isDeletingBatch)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red))),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.red),
                    tooltip: 'Delete Selected',
                    onPressed: () => _deleteSelected(allHistory),
                  ),
              ],
            )
          : AppBar(
              title: Text('Notifications History', 
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.getTextPrimary(isDark))),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
            ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: allHistory.length,
        itemBuilder: (context, index) {
          final item = allHistory[index];
          final date = DateTime.parse(item['timestamp']).toLocal();
          final isAlert = item['type'] == 'Alert';
          final deviceLabel = item['deviceName'] ?? item['deviceId'] ?? '';
          
          final historyId = item['_id'] ?? '';
          final deviceId = item['deviceId'] ?? '';
          final uniqueKey = item['uniqueKey'] as String;
          final isSelected = _selectedItems.contains(uniqueKey);

          return Dismissible(
            key: ValueKey(uniqueKey),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: AppColors.red,
                size: 28,
              ),
            ),
            onDismissed: (direction) {
              setState(() {
                _pendingDeletes.add(uniqueKey);
                _selectedItems.remove(uniqueKey);
              });
              
              final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Notification log deleted.', style: GoogleFonts.outfit()),
                  backgroundColor: AppColors.cyan,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'UNDO',
                    textColor: Colors.white,
                    onPressed: () {
                      // Handled by closed reason
                    },
                  ),
                ),
              );

              snackBarController.closed.then((reason) async {
                if (reason == SnackBarClosedReason.action) {
                  if (mounted) {
                    setState(() {
                      _pendingDeletes.remove(uniqueKey);
                    });
                  }
                } else {
                  if (deviceId.isNotEmpty && historyId.isNotEmpty) {
                    final success = await deleteDeviceHistoryItem(deviceId, historyId);
                    if (success) {
                      ref.invalidate(historyProvider(deviceId));
                    } else {
                      if (context.mounted) {
                        setState(() {
                          _pendingDeletes.remove(uniqueKey);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete notification log.', style: GoogleFonts.outfit()),
                            backgroundColor: AppColors.red,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  }
                }
              });
            },
            child: Card(
              color: isSelected 
                  ? AppColors.cyan.withValues(alpha: 0.15) 
                  : AppColors.getSurface(isDark),
              elevation: isDark ? 0 : 2,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isSelected ? const BorderSide(color: AppColors.cyan, width: 1.5) : BorderSide.none,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onLongPress: () => _toggleSelection(uniqueKey),
                onTap: _selectedItems.isNotEmpty ? () => _toggleSelection(uniqueKey) : null,
                child: ListTile(
                  leading: isSelected
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.check_circle_rounded, color: AppColors.cyan, size: 24),
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isAlert ? AppColors.red : AppColors.cyan).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isAlert ? Icons.warning_rounded : Icons.info_rounded, 
                            color: isAlert ? AppColors.red : AppColors.cyan,
                            size: 20,
                          ),
                        ),
                  title: Text(item['message'] ?? 'Unknown event',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.getTextPrimary(isDark))),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${DateFormat('dd MMM, hh:mm a').format(date)} • $deviceLabel',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.getTextMuted(isDark)),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
