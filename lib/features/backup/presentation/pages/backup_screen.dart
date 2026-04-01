import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/app_back_scope.dart';
import '../../../../core/error/failures.dart';
import '../../../../global/widgets/widgets.dart';
import '../../domain/entities/backup_import_result.dart';
import '../../domain/entities/cloud_backup_file.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../domain/repositories/cloud_backup_repository.dart';
import '../../domain/usecases/export_data_usecase.dart';
import '../../domain/usecases/import_data_usecase.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sao lưu & Khôi phục'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.file_upload), text: 'Export'),
              Tab(icon: Icon(Icons.file_download), text: 'Import'),
            ],
          ),
        ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportTab(),
          _buildImportTab(),
        ],
      ),
    ));
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Range Selection
          AppCard(
            child: AppListTile(
              leading: const Icon(Icons.date_range, color: Colors.blue),
              title: AppText.label('Khung thời gian'),
              subtitle: AppText.caption(
                _selectedDateRange == null
                    ? 'Tất cả dữ liệu'
                    : '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}',
              ),
              trailing: _selectedDateRange != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _selectedDateRange = null),
                    )
                  : null,
              onTap: _selectDateRange,
            ),
          ),
          const SizedBox(height: 24),

          // Export Options
          AppText.heading4('Chọn phương thức Export'),
          const SizedBox(height: 16),

          // Export to JSON
          AppCard(
            child: AppListTile.navigation(
              icon: Icons.save_alt,
              iconColor: Colors.green,
              title: 'Export ra file JSON',
              subtitle: 'Lưu dữ liệu vào bộ nhớ thiết bị',
              onTap: () => _handleExportLocal(context),
            ),
          ),
          // Google Drive features disabled - cần config OAuth consent screen
          const SizedBox(height: 12),
          // AppCard(
          //   child: AppListTile.navigation(
          //     icon: Icons.cloud_upload,
          //     iconColor: Colors.blue,
          //     title: 'Backup lên Google Drive',
          //     subtitle: 'Lưu dữ liệu vào tài khoản Google',
          //     onTap: () => _handleExportDrive(context),
          //   ),
          // ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          AppCard.padded(
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: AppText.caption(
                    'Export sẽ bao gồm: Giao dịch, Danh mục, Ngân sách, Giao dịch định kỳ',
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning
          AppCard.padded(
            color: Colors.orange.shade50,
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: AppText.caption(
                    'Import dữ liệu sẽ thay thế hoặc gộp với dữ liệu hiện tại. Hãy cẩn thận!',
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          AppText.heading4('Chọn nguồn Import'),
          const SizedBox(height: 16),

          AppCard(
            child: AppListTile.navigation(
              icon: Icons.folder_open,
              iconColor: Colors.teal,
              title: 'Import từ file JSON',
              subtitle: 'Chọn file từ bộ nhớ thiết bị',
              onTap: () => _handleImportLocal(context),
            ),
          ),
          // Google Drive features disabled - cần config OAuth consent screen
          // const SizedBox(height: 12),
          // AppCard(
          //   child: AppListTile.navigation(
          //     icon: Icons.cloud_download,
          //     iconColor: Colors.orange,
          //     title: 'Khôi phục từ Google Drive',
          //     subtitle: 'Chọn file backup từ tài khoản Google',
          //     onTap: () => _handleImportDrive(context),
          //   ),
          // ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  Future<void> _handleExportLocal(BuildContext context) async {
    try {
      if (!context.mounted) return;
      _showLoadingDialog(context, 'Đang tạo file backup...');

      // Tạo tên file
      final fileName = 'moni_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      
      // Lấy thư mục Downloads (Android) hoặc Documents (iOS)
      Directory? directory;
      if (Platform.isAndroid) {
        // Trên Android, lưu vào Downloads
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Fallback nếu không tìm thấy Downloads
          directory = await getExternalStorageDirectory();
        }
      } else {
        // Trên iOS, lưu vào Documents
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Không tìm thấy thư mục lưu file');
      }

      final outputPath = path.join(directory.path, fileName);
      print('📁 Output path: $outputPath');

      // Tạo file backup với path đã chọn
      final result = await sl<ExportDataUseCase>()(ExportDataParams(outputPath: outputPath));
      
      if (context.mounted) Navigator.of(context).pop();
      if (!context.mounted) return;

      result.fold(
        (failure) {
          print('❌ Export data failed: ${_failureMessage(failure)}');
          _showSnackBar(
            context,
            'Lỗi export: ${_failureMessage(failure)}',
            isError: true,
          );
        },
        (file) {
          print('✅ Export success: ${file.path}');
          _showSnackBar(
            context, 
            Platform.isAndroid 
              ? 'Đã lưu vào thư mục Download:\n$fileName'
              : 'Export thành công!\n$fileName'
          );
        },
      );
    } catch (e, stackTrace) {
      print('❌ ERROR in _handleExportLocal:');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showSnackBar(context, 'Lỗi: $e', isError: true);
      }
    }
  }

  // ignore: unused_element
  Future<void> _handleExportDrive(BuildContext context) async {
    try {
      print('🔵 Starting Google Drive backup...');
      _showLoadingDialog(context, 'Đang backup lên Google Drive...');

      print('📦 Creating backup file...');
      final exportResult = await sl<ExportDataUseCase>()(const ExportDataParams(outputPath: ''));
      final cloudRepo = sl<CloudBackupRepository>();

      if (context.mounted) Navigator.of(context).pop();

      await exportResult.fold(
        (failure) async {
          print('❌ Export failed: ${_failureMessage(failure)}');
          _showSnackBar(
            context,
            'Backup thất bại: ${_failureMessage(failure)}',
            isError: true,
          );
        },
        (file) async {
          print('✅ Backup file created: ${file.path}');
          print('☁️ Uploading to Google Drive...');
          _showLoadingDialog(context, 'Đang upload lên Google Drive...');
          
          final uploadResult = await cloudRepo.uploadBackup(file);
          
          if (context.mounted) Navigator.of(context).pop();

          uploadResult.fold(
            (failure) {
              print('❌ Upload failed: ${_failureMessage(failure)}');
              _showSnackBar(
                context,
                'Upload thất bại: ${_failureMessage(failure)}',
                isError: true,
              );
            },
            (_) {
              print('✅ Upload to Drive successful!');
              _showSnackBar(context, 'Backup lên Drive thành công!');
            },
          );
        },
      );
    } catch (e, stackTrace) {
      print('❌ ERROR in _handleExportDrive:');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showSnackBar(context, 'Lỗi: $e', isError: true);
      }
    }
  }

  Future<void> _handleImportLocal(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (picked == null || picked.files.single.path == null) return;
    
    // Kiểm tra extension .json
    final filePath = picked.files.single.path!;
    if (!filePath.toLowerCase().endsWith('.json')) {
      _showSnackBar(context, 'Vui lòng chọn file .json', isError: true);
      return;
    }

    final mode = await _showImportModeDialog(context);
    if (mode == null) return;

    _showLoadingDialog(context, 'Đang import dữ liệu...');

    final file = File(picked.files.single.path!);
    final result = await sl<ImportDataUseCase>()(
      ImportDataParams(file: file, mode: mode),
    );

    if (context.mounted) Navigator.of(context).pop();

    result.fold(
      (failure) => _showSnackBar(
        context,
        'Lỗi import: ${_failureMessage(failure)}',
        isError: true,
      ),
      (result) {
        if (result.success) {
          _showSnackBar(context, 'Import thành công');
        } else {
          final message = result.error == BackupImportError.incompatibleVersion
              ? 'File không tương thích phiên bản'
              : 'File backup không hợp lệ';
          _showSnackBar(context, message, isError: true);
        }
      },
    );
  }

  // ignore: unused_element
  Future<void> _handleImportDrive(BuildContext context) async {
    _showLoadingDialog(context, 'Đang lấy danh sách backup...');

    final cloudRepo = sl<CloudBackupRepository>();
    final listResult = await cloudRepo.listBackups();

    if (context.mounted) Navigator.of(context).pop();

    await listResult.fold(
      (failure) async => _showSnackBar(
        context,
        'Lỗi: ${_failureMessage(failure)}',
        isError: true,
      ),
      (backups) async {
        if (backups.isEmpty) {
          _showSnackBar(context, 'Không tìm thấy backup nào trên Drive');
          return;
        }

        final selectedBackup = await _showBackupSelectionDialog(context, backups);
        if (selectedBackup == null) return;

        final mode = await _showImportModeDialog(context);
        if (mode == null) return;

        _showLoadingDialog(context, 'Đang tải backup...');
        final downloadResult = await cloudRepo.downloadBackup(selectedBackup.id);

        if (context.mounted) Navigator.of(context).pop();

        await downloadResult.fold(
          (failure) async => _showSnackBar(
            context,
            'Tải thất bại: ${_failureMessage(failure)}',
            isError: true,
          ),
          (file) async {
            _showLoadingDialog(context, 'Đang khôi phục dữ liệu...');
            final importResult = await sl<ImportDataUseCase>()(
              ImportDataParams(file: file, mode: mode),
            );

            if (context.mounted) Navigator.of(context).pop();

            importResult.fold(
              (failure) => _showSnackBar(
                context,
                'Khôi phục thất bại: ${_failureMessage(failure)}',
                isError: true,
              ),
              (result) {
                if (result.success) {
                  _showSnackBar(context, 'Khôi phục thành công');
                } else {
                  _showSnackBar(context, 'File backup không hợp lệ', isError: true);
                }
              },
            );
          },
        );
      },
    );
  }

  Future<BackupImportMode?> _showImportModeDialog(BuildContext context) async {
    return AppDialog.showOptions<BackupImportMode>(
      context: context,
      title: 'Chế độ Import',
      options: [
        const AppDialogOption(
          value: BackupImportMode.replaceAll,
          icon: Icons.refresh,
          iconColor: Colors.red,
          label: 'Thay thế tất cả',
          subtitle: 'Xóa dữ liệu hiện tại và thay thế',
        ),
        const AppDialogOption(
          value: BackupImportMode.merge,
          icon: Icons.merge_type,
          iconColor: Colors.blue,
          label: 'Gộp dữ liệu',
          subtitle: 'Giữ dữ liệu cũ, thêm dữ liệu mới',
        ),
      ],
    );
  }

  Future<CloudBackupFile?> _showBackupSelectionDialog(
    BuildContext context,
    List<CloudBackupFile> backups,
  ) async {
    return showDialog<CloudBackupFile>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText.heading3('Chọn file backup'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: backups.length,
            itemBuilder: (context, index) {
              final backup = backups[index];
              return AppListTile(
                leading: const Icon(Icons.cloud),
                title: AppText.body(backup.name),
                subtitle: AppText.caption(
                  'Ngày: ${backup.createdTime != null ? DateFormat('dd/MM/yyyy HH:mm').format(backup.createdTime!) : 'Không rõ'}\n'
                  'Kích thước: ${(backup.size ?? 0) / 1024} KB',
                ),
                onTap: () => Navigator.pop(context, backup),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showLoadingDialog(BuildContext context, String message) {
    AppDialog.showLoading(context: context, message: message);
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (isError) {
      AppSnackBar.showError(context, message);
    } else {
      AppSnackBar.showSuccess(context, message);
    }
  }

  String _failureMessage(Failure failure) {
    if (failure is CacheFailure) {
      return failure.message ?? 'Lỗi cache';
    } else if (failure is ServerFailure) {
      return failure.message ?? 'Lỗi server';
    }
    return 'Lỗi không xác định';
  }
}
