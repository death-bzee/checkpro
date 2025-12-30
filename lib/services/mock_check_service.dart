import '../models/check_item.dart';

class MockCheckService {
  const MockCheckService();

  List<TaskItem> fetchChecks() {
    final now = DateTime.now();
    return [
      TaskItem(
        id: 'sprinklers',
        title: 'Проверка давления в спринклерах',
        projectId: 'project-1',
        projectName: 'Технический этаж',
        status: 'pending',
        updatedAt: now.subtract(const Duration(hours: 2)),
        instructions:
            'Давление упало ниже нормы после ночного теста. Необходимо повторить замер и вызвать подрядчика, если значение не восстановится.',
      ),
      TaskItem(
        id: 'evacuation',
        title: 'Актуальность плана эвакуации',
        projectId: 'project-2',
        projectName: 'Ресепшн',
        status: 'approved',
        updatedAt: now.subtract(const Duration(days: 1, hours: 3)),
        instructions:
            'Все этажи подписаны, схемы обновлены неделю назад. Доступна печать PDF при необходимости.',
      ),
      TaskItem(
        id: 'sensors',
        title: 'Калибровка датчиков дыма',
        projectId: 'project-3',
        projectName: 'Склад №3',
        status: 'submitted',
        updatedAt: now.subtract(const Duration(hours: 6)),
        instructions:
            'После последнего ТО два датчика показывают завышенные значения. Инженер выедет в течение дня.',
      ),
      TaskItem(
        id: 'training',
        title: 'Тренировка по эвакуации',
        projectId: 'project-1',
        projectName: 'Корпус B',
        status: 'approved',
        updatedAt: now.subtract(const Duration(days: 3)),
        instructions:
            'Участие 96% сотрудников. Итоги занесены в отчет, повторное упражнение назначено через месяц.',
      ),
      TaskItem(
        id: 'extinguishers',
        title: 'Инвентаризация огнетушителей',
        projectId: 'project-4',
        projectName: 'Подземный паркинг',
        status: 'rejected',
        updatedAt: now.subtract(const Duration(hours: 12)),
        instructions:
            'Три баллона требуют перезарядки, заказ согласован. Следить за сроком поставки.',
      ),
    ];
  }
}
