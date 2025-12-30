import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/check_item.dart';
import '../services/task_service.dart';
import '../widgets/check_item_card.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.userName,
    required this.companyName,
  });

  final String userName;
  final String companyName;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TaskService _taskService = TaskService();
  List<TaskItem> _items = const <TaskItem>[];
  String _selectedFilter = 'all';
  bool _isLoading = true;
  String? _errorText;
  bool _isUploading = false;
  String _comment = '';
  final Map<String, int> _uploadedCounts = {};

  String get _initial {
    final trimmed = widget.userName.trim();
    if (trimmed.isEmpty) return 'C';
    return trimmed[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final tasks = await _taskService.fetchInstallerInbox();
      if (!mounted) return;
      setState(() => _items = tasks);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolved = _items.where((item) => item.isApproved).length;
    final inProgress = _items.length - resolved;
    final completion =
        _items.isEmpty ? 0 : (resolved / _items.length * 100).round();

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Привет, ${widget.userName}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.companyName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Уведомления',
          ),
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Выйти'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primary,
                child: Text(
                  _initial,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSnack,
        backgroundColor: colorScheme.primary.withValues(alpha: 0.9),
        icon: const Icon(Icons.playlist_add_check_outlined),
        label: const Text('Новая проверка'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopStats(
                active: inProgress,
                done: resolved,
                progress: completion,
              ),
              const SizedBox(height: 24),
              Text(
                'Журнал проверок',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    _FilterButton(
                      label: 'Все задачи',
                      selected: _selectedFilter == 'all',
                      onTap: () => _changeFilter('all'),
                      filled: true,
                    ),
                    _FilterButton(
                      label: 'В работе',
                      selected: _selectedFilter == 'open',
                      onTap: () => _changeFilter('open'),
                    ),
                    _FilterButton(
                      label: 'На проверке',
                      selected: _selectedFilter == 'submitted',
                      onTap: () => _changeFilter('submitted'),
                    ),
                    _FilterButton(
                      label: 'Готово',
                      selected: _selectedFilter == 'approved',
                      onTap: () => _changeFilter('approved'),
                    ),
                    _FilterButton(
                      label: 'Возврат',
                      selected: _selectedFilter == 'rejected',
                      onTap: () => _changeFilter('rejected'),
                      outlinedColor: Colors.red,
                    ),
                  ].expand((w) sync* {
                    yield w;
                    yield const SizedBox(width: 10);
                  }).toList()
                    ..removeLast(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorText != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _errorText!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadTasks,
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
    }

    final filtered = _items.where((item) {
      switch (_selectedFilter) {
        case 'open':
          return !item.isApproved && !item.isSubmitted;
        case 'submitted':
          return item.isSubmitted;
        case 'approved':
          return item.isApproved;
        case 'rejected':
          return item.isRejected;
        default:
          return true;
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Нет задач под выбранный фильтр'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = filtered[index];
          return CheckItemCard(
            item: item,
            onStatusChanged: (value) => _submitTask(item, value),
            onTap: () => _showDetails(item),
          );
        },
      ),
    );
  }

  void _changeFilter(String value) {
    setState(() => _selectedFilter = value);
  }

  Future<void> _submitTask(TaskItem item, bool value, {String? comment}) async {
    // разрешаем переключение только в сторону "отправить"
    if (!value) {
      return;
    }
    if (!(item.isPending || item.isRejected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Задача уже отправлена или завершена')),
      );
      return;
    }

    var currentStatus = item.status;

    // Оптимистично меняем статус
    setState(() {
      _items = _items
          .map(
            (current) => current.id == item.id
                ? current.copyWith(
                    status: 'submitted',
                    updatedAt: DateTime.now(),
                  )
                : current,
          )
          .toList();
    });

    try {
      // Если задача только готова к инсталлеру — сначала стартуем её
      if (currentStatus == 'ready_for_installer') {
        await _taskService.installerStart(item.id);
        currentStatus = 'in_progress';
      }

      if (currentStatus == 'in_progress' || currentStatus == 'qa_rejected') {
        await _taskService.installerSubmit(item.id, comment: comment);
      } else {
        await _taskService.submitTask(item.id, comment: comment);
      }

      await _loadTasks();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить: $error')),
      );
      await _loadTasks();
    }
  }

  void _showDetails(TaskItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (item.projectName.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.business_outlined),
                        const SizedBox(width: 6),
                        Text(item.projectName),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.flag_outlined),
                      const SizedBox(width: 6),
                      Text(item.statusLabel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (item.instructions != null &&
                      item.instructions!.trim().isNotEmpty) ...[
                    Text(
                      'Описание',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(item.instructions!),
                    const SizedBox(height: 12),
                  ],
                  if (item.requiredPhotos > 0) ...[
                    Text(
                      'Требуемые фото: ${item.requiredPhotos}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Загружено (сессия): ${_uploadedCounts[item.id] ?? 0}/${item.requiredPhotos}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUploading
                              ? null
                              : () => _captureAndUpload(item, setModalState),
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_camera_outlined),
                          label: const Text('Сделать фото'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий (опционально)',
                      prefixIcon: Icon(Icons.comment_outlined),
                    ),
                    onChanged: (value) => _comment = value,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _submitTask(item, true, comment: _comment),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      'Отправить',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _captureAndUpload(
    TaskItem item,
    void Function(void Function()) setModalState,
  ) async {
    final picker = ImagePicker();

    setModalState(() => _isUploading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }

      Position? position;
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (enabled) {
          position = await Geolocator.getCurrentPosition();
        }
      }

      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) {
        setModalState(() => _isUploading = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      final watermarked = await _addWatermark(bytes, position);
      final filename = _buildFilename(position);

      final urls = await _taskService.uploadPhoto(item.id, watermarked, filename: filename);
      setState(() {
        final current = _uploadedCounts[item.id] ?? 0;
        _uploadedCounts[item.id] = current + (urls.length);
      });
      setModalState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото загружено')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить фото: $error')),
        );
      }
    } finally {
      setModalState(() => _isUploading = false);
    }
  }

  Future<Uint8List> _addWatermark(
    Uint8List original,
    Position? position,
  ) async {
    final image = img.decodeImage(original);
    if (image == null) return original;

    final coords = position == null
        ? 'GPS недоступен'
        : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    final ts = DateTime.now().toIso8601String().split('.').first;
    final stamp = '$coords  •  $ts';

    final font = img.arial24;
    final white = img.ColorUint8.rgb(255, 255, 255);
    final bg = img.ColorUint8.rgba(0, 0, 0, 170);

    const bandHeight = 48;
    final bandTop = image.height - bandHeight;

    // полупрозрачный фон под текст
    img.fillRect(
      image,
      x1: 0,
      y1: bandTop,
      x2: image.width,
      y2: image.height,
      color: bg,
    );

    img.drawString(
      image,
      stamp,
      font: font,
      x: 16,
      y: bandTop + 12,
      color: white,
    );

    final encoded = img.encodeJpg(image, quality: 85);
    return Uint8List.fromList(encoded);
  }

  String _buildFilename(Position? pos) {
    if (pos == null) return 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final lat = pos.latitude.toStringAsFixed(5);
    final lon = pos.longitude.toStringAsFixed(5);
    return 'photo_${lat}_${lon}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  void _showAddSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция создания задачи будет доступна позже'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _TopStats extends StatelessWidget {
  const _TopStats({
    required this.active,
    required this.done,
    required this.progress,
  });

  final int active;
  final int done;
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          label: 'Активных',
          value: '$active',
          icon: Icons.warning_amber,
          color: const Color(0xFFFFB47D),
        ),
        _StatCard(
          label: 'Завершено',
          value: '$done',
          icon: Icons.verified_outlined,
          color: const Color(0xFF9AD8AE),
        ),
        _StatCard(
          label: 'Прогресс',
          value: '$progress%',
          icon: Icons.speed,
          color: const Color(0xFF9CA6DD),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.filled = false,
    this.outlinedColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool filled;
  final Color? outlinedColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = filled || selected
        ? (outlinedColor ?? colorScheme.primary).withValues(alpha: 0.12)
        : Colors.transparent;
    final borderColor = outlinedColor ??
        (selected ? colorScheme.primary : colorScheme.outlineVariant);
    final textColor = outlinedColor ??
        (selected ? colorScheme.primary : colorScheme.onSurface);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 16, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
