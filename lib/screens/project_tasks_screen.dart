import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/check_item.dart';
import '../services/task_service.dart';
import '../widgets/check_item_card.dart';

class ProjectTasksScreen extends StatefulWidget {
  const ProjectTasksScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.initialTasks,
  });

  final String projectId;
  final String projectName;
  final List<TaskItem> initialTasks;

  @override
  State<ProjectTasksScreen> createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends State<ProjectTasksScreen> {
  final TaskService _taskService = TaskService();
  List<TaskItem> _tasks = const [];
  String _selectedFilter = 'all';
  bool _isLoading = false;
  String? _errorText;
  bool _isUploading = false;
  bool _isUploadingDoc = false;
  String _comment = '';
  final Map<String, int> _uploadedCounts = {};
  final Map<String, TaskDetail> _details = {};
  final Map<String, TaskTemplateExample?> _templateByType = {};
  TaskDetail? _pendingDetail;
  void _safeSetModalState(
    void Function(void Function())? setModalState, [
    void Function()? fn,
  ]) {
    if (setModalState == null || fn == null) return;
    try {
      setModalState(fn);
    } catch (_) {
      // ignore setState after dispose in closed bottom sheets
    }
  }

  @override
  void initState() {
    super.initState();
    _tasks = widget.initialTasks;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    _pendingDetail = null;
    try {
      final all = await _taskService.fetchInstallerInbox();
      if (!mounted) return;
      final projectTasks =
          all.where((t) => t.projectId == widget.projectId).toList();
      setState(() {
        _tasks = projectTasks;
      });
      // подтянем типы и эталоны для задач, где нет типа или нет кеша шаблона
      _prefetchTypes(
        projectTasks.where(
          (t) =>
              (t.taskTypeName ?? '').isEmpty ||
              !_templateByType.containsKey(_typeKey(t)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName.isEmpty ? 'Проект' : widget.projectName),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilters(),
              const SizedBox(height: 16),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterButton(
            label: 'Все',
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
          ),
        ].expand((w) sync* {
          yield w;
          yield const SizedBox(width: 10);
        }).toList()
          ..removeLast(),
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
            const SizedBox(height: 8),
            Text(_errorText!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton(onPressed: _refresh, child: const Text('Обновить')),
          ],
        ),
      );
    }

    final filtered = _tasks.where((item) {
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
      return const Center(child: Text('Задач нет'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: _buildGroupedList(filtered),
    );
  }

  Widget _buildGroupedList(List<TaskItem> items) {
    final grouped = <String, List<TaskItem>>{};
    for (final item in items) {
      final key = _typeKey(item);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final keys = grouped.keys.toList()..sort();

    return ListView.separated(
      itemCount: keys.length,
      separatorBuilder: (_, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final key = keys[index];
        final list = grouped[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    key,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  IconButton(
                    tooltip: 'Эталон шаблона',
                    icon: const Icon(Icons.info_outline, size: 18),
                    onPressed: () => _openTemplateForType(key),
                  ),
                ],
              ),
            ),
            ...list.expand((item) sync* {
              yield const SizedBox(height: 8);
              yield CheckItemCard(
                item: item,
                onStatusChanged: (value) => _submitTask(item, value),
                onTap: () => _showDetails(item),
              );
            }).skip(1), // skip leading spacer for first element
          ],
        );
      },
    );
  }

  void _changeFilter(String value) {
    setState(() => _selectedFilter = value);
  }

  String _typeKey(TaskItem task) =>
      task.taskTypeName?.isNotEmpty == true ? task.taskTypeName! : 'Без типа';

  Future<void> _prefetchTypes(Iterable<TaskItem> items) async {
    for (final item in items) {
      try {
        final detail = await _taskService.fetchTaskDetail(item.id);
        if (!mounted) return;
        final typeKey = detail.taskTypeName?.isNotEmpty == true
            ? detail.taskTypeName!
            : _typeKey(item);
        setState(() {
          _details[item.id] = detail;
          _tasks = _tasks
              .map(
                (t) => t.id == item.id
                    ? t.copyWith(
                        status: detail.status ?? t.status,
                        taskTypeName: typeKey,
                      )
                    : t,
              )
              .toList();
          if (detail.templateExample != null) {
            _templateByType[typeKey] = detail.templateExample;
          }
        });
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _submitTask(
    TaskItem item,
    bool value, {
    String? comment,
    BuildContext? sheetContext,
  }) async {
    if (!value) return;
    if (!(item.isPending || item.isRejected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Задача уже отправлена или завершена')),
      );
      if (sheetContext != null) {
        Navigator.of(sheetContext).maybePop();
      }
      return;
    }

    var currentStatus = item.status;
    setState(() {
      _tasks = _tasks
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
      if (currentStatus == 'ready_for_installer') {
        await _taskService.installerStart(item.id);
        currentStatus = 'in_progress';
      }

      if (currentStatus == 'in_progress' || currentStatus == 'qa_rejected') {
        await _taskService.installerSubmit(item.id, comment: comment ?? _comment);
      } else {
        await _taskService.submitTask(item.id, comment: comment ?? _comment);
      }

      if (sheetContext != null) {
        Navigator.of(sheetContext).maybePop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отправлено')),
        );
        await _refresh();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить: $error')),
      );
      await _refresh();
    }
  }

  void _showDetails(TaskItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        _loadTaskDetail(item, setModalState: null);
        return StatefulBuilder(
          builder: (context, setModalState) {
            final effectiveStatus = _details[item.id]?.status ?? item.status;
            final isPending = effectiveStatus == 'pending' ||
                effectiveStatus == 'draft' ||
                effectiveStatus == 'ready_for_installer' ||
                effectiveStatus == 'in_progress' ||
                effectiveStatus == 'qa_rejected';
            final isRejected = effectiveStatus == 'rejected' ||
                effectiveStatus == 'qa_rejected';
          final readOnly = !(isPending || isRejected);
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final detail = _details[item.id] ?? _pendingDetail;
            final photos = detail?.photos ?? const <TaskPhoto>[];
            final documents = detail?.documents ?? const <TaskDocument>[];
            final template = detail?.templateExample;
            final uploadedCount = detail?.photos.length ??
                _uploadedCounts[item.id] ??
                0;
            final required = detail?.requiredPhotos ?? item.requiredPhotos;
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.9,
              minChildSize: 0.5,
              builder: (_, controller) {
                return SingleChildScrollView(
                  controller: controller,
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (template != null &&
                              ((template.title ?? '').isNotEmpty ||
                                  (template.annotation ?? '').isNotEmpty ||
                                  (template.photoUrl ?? '').isNotEmpty ||
                                  (template.documentUrl ?? '').isNotEmpty))
                            IconButton(
                              onPressed: () => _showTemplate(template),
                              tooltip: 'Эталон',
                              icon: const Icon(Icons.info_outline),
                            ),
                        ],
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
                      if (required > 0 || photos.isNotEmpty) ...[
                        Text(
                          'Требуемые фото: $required',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Загружено: $uploadedCount/$required',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        _PhotosGrid(
                          photos: photos,
                          onDelete: readOnly
                              ? null
                              : (photoId) => _deletePhoto(item, photoId, setModalState),
                        ),
                        if (photos.isEmpty && readOnly) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Вложения пока не подгрузились. Обновите, чтобы увидеть отправленные фото.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _loadTaskDetail(item, setModalState: setModalState),
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('Обновить вложения'),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      if (documents.isNotEmpty) ...[
                        Text(
                          'PDF / документы',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: documents
                              .map(
                                (d) => ActionChip(
                                  label: Text(d.name?.isNotEmpty == true ? d.name! : 'Документ'),
                                  avatar: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                  onPressed: () => _openUrl(d.url),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (detail?.submissionComment?.isNotEmpty == true) ...[
                        _CommentTile(
                          label: 'Комментарий к отправке',
                          text: detail!.submissionComment!,
                          icon: Icons.send_outlined,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (detail?.qaComment?.isNotEmpty == true) ...[
                        _CommentTile(
                          label: 'Комментарий QA',
                          text: detail!.qaComment!,
                          icon: Icons.verified_outlined,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (!readOnly && !_isUploading)
                                  ? () => _captureAndUpload(item, setModalState)
                                  : null,
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
                      OutlinedButton.icon(
                        onPressed: (!readOnly && !_isUploadingDoc)
                            ? () => _pickDocument(item, setModalState)
                            : null,
                        icon: _isUploadingDoc
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Прикрепить PDF'),
                      ),
                      const SizedBox(height: 12),
                      if (!readOnly) ...[
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
                          onPressed: () =>
                              _submitTask(item, true, comment: _comment, sheetContext: context),
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Отправить'),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'Отправлено. Доступен просмотр вложений.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _loadTaskDetail(item, setModalState: setModalState),
                              tooltip: 'Обновить вложения',
                              icon: const Icon(Icons.refresh_outlined),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
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

      final urls = await _taskService.uploadPhoto(
        item.id,
        watermarked,
        filename: filename,
      );
      setState(() {
        final current = _uploadedCounts[item.id] ?? 0;
        _uploadedCounts[item.id] = current + (urls.length);
      });
      await _loadTaskDetail(item, setModalState: setModalState);
      _safeSetModalState(setModalState, () {});
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
      _safeSetModalState(setModalState, () => _isUploading = false);
    }
  }

  Future<void> _pickDocument(
    TaskItem item,
    void Function(void Function()) setModalState,
  ) async {
    setModalState(() => _isUploadingDoc = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
        setModalState(() => _isUploadingDoc = false);
        return;
      }
      final file = result.files.first;
      final urls = await _taskService.uploadDocument(
        item.id,
        file.bytes!,
        filename: file.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF загружен (${urls.length})')),
        );
      }
      await _loadTaskDetail(item, setModalState: setModalState);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить PDF: $error')),
        );
      }
    } finally {
      _safeSetModalState(setModalState, () => _isUploadingDoc = false);
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
        : 'lat: ${position.latitude.toStringAsFixed(5)}, lon: ${position.longitude.toStringAsFixed(5)}';
    final ts = DateTime.now().toIso8601String().split('.').first;
    final stamp = '$coords  •  $ts';

    final font = img.arial24;
    final white = img.ColorUint8.rgb(255, 255, 255);
    final bg = img.ColorUint8.rgba(0, 0, 0, 170);

    const bandHeight = 52;
    final bandTop = image.height - bandHeight;

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

  Future<void> _loadTaskDetail(
    TaskItem item, {
    void Function(void Function())? setModalState,
  }) async {
    _pendingDetail = null;
    try {
      final detail = await _taskService.fetchTaskDetail(item.id);
      if (!mounted) return;
      setState(() {
        _details[item.id] = detail;
        if (detail.requiredPhotos != null) {
          _uploadedCounts[item.id] = detail.photos.length;
        }
        if (detail.templateExample != null) {
          final typeKey = detail.taskTypeName?.isNotEmpty == true
              ? detail.taskTypeName!
              : _typeKey(item);
          _templateByType[typeKey] = detail.templateExample;
        }
        if (detail.status != null) {
          _tasks = _tasks
              .map(
                (t) => t.id == item.id
                    ? t.copyWith(
                        status: detail.status!,
                        updatedAt: DateTime.now(),
                      )
                    : t,
              )
              .toList();
        }
      });
      _safeSetModalState(setModalState, () {});
    } catch (_) {
      // ignore load errors in sheet
    }
  }

  Future<void> _openTemplateForType(String typeName) async {
    TaskTemplateExample? template = _templateByType[typeName];

    bool hasContent(TaskTemplateExample? t) =>
        t != null &&
        ((t.title ?? '').isNotEmpty ||
            (t.annotation ?? '').isNotEmpty ||
            (t.photoUrl ?? '').isNotEmpty ||
            (t.documentUrl ?? '').isNotEmpty);

    if (!hasContent(template)) {
      // попробуем среди уже загруженных деталей
      template = _details.values.map((d) => d.templateExample).firstWhere(
            hasContent,
            orElse: () => null,
          );
    }

    if (!hasContent(template)) {
      // перебираем задачи нужного типа и подтягиваем детали, пока не найдём эталон
      final candidates =
          _tasks.where((t) => _typeKey(t) == typeName).toList(growable: false);
      final scanList = candidates.isNotEmpty ? candidates : _tasks;

      for (final task in scanList) {
        try {
          final detail = await _taskService.fetchTaskDetail(task.id);
          if (!mounted) return;
          setState(() => _details[task.id] = detail);
          if (hasContent(detail.templateExample)) {
            template = detail.templateExample;
            _templateByType[typeName] = template;
            break;
          }
        } catch (_) {
          // ignore and try next
        }
      }
    }

    if (!hasContent(template)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Эталон пока не загружен')),
        );
      }
      return;
    }
    _templateByType[typeName] = template;
    _showTemplate(template!);
  }
  Future<void> _deletePhoto(
    TaskItem item,
    String photoId,
    void Function(void Function()) setModalState,
  ) async {
    try {
      await _taskService.deletePhoto(item.id, photoId);
      await _loadTaskDetail(item, setModalState: setModalState);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото удалено')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить фото: $error')),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка скопирована')),
      );
    }
  }

  void _showTemplate(TaskTemplateExample example) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _TemplateScreen(example: example),
      ),
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({required this.photos, required this.onDelete});
  final List<TaskPhoto> photos;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: photos
          .map(
            (p) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    p.url,
                    width: 120,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Container(
                      width: 120,
                      height: 80,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                if (onDelete != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => onDelete?.call(p.id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.label,
    required this.text,
    required this.icon,
  });

  final String label;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplateScreen extends StatelessWidget {
  const _TemplateScreen({required this.example});

  final TaskTemplateExample example;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Эталонное выполнение'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((example.title ?? '').isNotEmpty) ...[
              Text(
                example.title!,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
            ],
            if ((example.annotation ?? '').isNotEmpty) ...[
              Text(
                example.annotation!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],
            if ((example.photoUrl ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  example.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => Container(
                    height: 220,
                    color: colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Text('Не удалось загрузить фото'),
                  ),
                ),
              ),
            if ((example.photoUrl ?? '').isEmpty)
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text('Фото примера отсутствует'),
              ),
            const SizedBox(height: 16),
            if ((example.documentUrl ?? '').isNotEmpty)
              FilledButton.icon(
                onPressed: () => _openUrlStatic(context, example.documentUrl!),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Открыть инструкцию PDF'),
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openUrlStatic(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = filled || selected
        ? colorScheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;
    final borderColor =
        selected ? colorScheme.primary : colorScheme.outlineVariant;
    final textColor =
        selected ? colorScheme.primary : colorScheme.onSurface;

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
// ignore_for_file: use_build_context_synchronously
