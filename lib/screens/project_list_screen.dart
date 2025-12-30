import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/check_item.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';
import 'login_screen.dart';
import 'project_tasks_screen.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final TaskService _taskService = TaskService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _loading = true;
  String? _error;
  List<TaskItem> _tasks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _taskService.fetchInstallerInbox();
      if (!mounted) return;
      setState(() => _tasks = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои проекты'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorState(
                      message: _error!,
                      onRetry: _load,
                      onLogout: _logoutAndExit,
                    )
                  : _buildList(colorScheme),
        ),
      ),
    );
  }

  Future<void> _logoutAndExit() async {
    try {
      await _secureStorage.delete(key: 'quick_email');
      await _secureStorage.delete(key: 'quick_password');
      await _secureStorage.delete(key: 'quick_pin');
    } catch (_) {
      // ignore storage errors
    }
    authService = AuthService();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildList(ColorScheme colorScheme) {
    if (_tasks.isEmpty) {
      return const Center(
        child: Text('Нет назначенных проектов'),
      );
    }

    final projects = <String, _ProjectGroup>{};
    for (final t in _tasks) {
      final group = projects.putIfAbsent(
        t.projectId,
        () => _ProjectGroup(name: t.projectName),
      );
      group.tasks.add(t);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = projects.entries.elementAt(index);
        final group = entry.value;
        final counts = _counts(group.tasks);
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              group.name.isEmpty ? 'Проект' : group.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Всего: ${group.tasks.length} • В работе: ${counts.inWork} • На проверке: ${counts.onCheck} • Готово: ${counts.done}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProjectTasksScreen(
                  projectId: entry.key,
                  projectName: group.name,
                  initialTasks: group.tasks,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _Counts _counts(List<TaskItem> tasks) {
    var inWork = 0, onCheck = 0, done = 0;
    for (final t in tasks) {
      if (t.isApproved) {
        done++;
      } else if (t.isSubmitted) {
        onCheck++;
      } else {
        inWork++;
      }
    }
    return _Counts(inWork: inWork, onCheck: onCheck, done: done);
  }
}

class _Counts {
  _Counts({required this.inWork, required this.onCheck, required this.done});
  final int inWork;
  final int onCheck;
  final int done;
}

class _ProjectGroup {
  _ProjectGroup({required this.name});
  final String name;
  final List<TaskItem> tasks = [];
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.onLogout,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Обновить'),
          ),
          if (onLogout != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onLogout,
              child: const Text('Выйти и войти заново'),
            ),
          ],
        ],
      ),
    );
  }
}
