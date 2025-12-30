class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.projectName,
    required this.projectId,
    required this.status,
    this.taskTypeName,
    this.instructions,
    this.requiredPhotos = 0,
    this.qaId,
    this.orderIndex,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String projectName;
  final String projectId;
  final String status;
  final String? taskTypeName;
  final String? instructions;
  final int requiredPhotos;
  final String? qaId;
  final int? orderIndex;
  final DateTime? updatedAt;

  bool get isApproved =>
      status == 'approved' ||
      status == 'qa_approved' ||
      status == 'final_approved';
  bool get isSubmitted => status == 'submitted';
  bool get isRejected => status == 'rejected' || status == 'qa_rejected';
  bool get isPending =>
      status == 'pending' ||
      status == 'draft' ||
      status == 'ready_for_installer' ||
      status == 'in_progress' ||
      status == 'qa_rejected' ||
      status == 'sent_to_qa';

  String get statusLabel {
    switch (status) {
      case 'approved':
      case 'qa_approved':
      case 'final_approved':
        return 'Готово';
      case 'submitted':
        return 'На проверке';
      case 'rejected':
        return 'Возврат';
      case 'ready_for_installer':
        return 'Готов к работе';
      case 'in_progress':
        return 'В работе';
      case 'qa_rejected':
        return 'Возврат QA';
      case 'sent_to_qa':
        return 'На проверке QA';
      case 'draft':
        return 'Черновик';
      default:
        return 'В работе';
    }
  }

  TaskItem copyWith({
    String? status,
    DateTime? updatedAt,
    String? taskTypeName,
  }) {
    return TaskItem(
      id: id,
      title: title,
      projectName: projectName,
      projectId: projectId,
      status: status ?? this.status,
      taskTypeName: taskTypeName ?? this.taskTypeName,
      instructions: instructions,
      requiredPhotos: requiredPhotos,
      qaId: qaId,
      orderIndex: orderIndex,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      projectName: json['project_name'] as String? ?? 'Проект',
      projectId: json['project_id']?.toString() ?? '',
      status: json['status'] as String? ?? 'pending',
      taskTypeName: json['task_type_name'] as String? ??
          json['task_type'] as String? ??
          json['type'] as String?,
      instructions: json['instructions'] as String?,
      requiredPhotos: (json['required_photos'] as num?)?.toInt() ?? 0,
      qaId: json['qa_id']?.toString(),
      orderIndex: json['order_index'] as int?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

class TaskPhoto {
  TaskPhoto({required this.id, required this.url});
  final String id;
  final String url;

  factory TaskPhoto.fromJson(Map<String, dynamic> json) {
    return TaskPhoto(
      id: json['id']?.toString() ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

class TaskDocument {
  TaskDocument({required this.id, required this.url, this.name});

  final String id;
  final String url;
  final String? name;

  factory TaskDocument.fromJson(Map<String, dynamic> json) {
    return TaskDocument(
      id: json['id']?.toString() ?? '',
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? json['filename'] as String?,
    );
  }
}

class TaskTemplateExample {
  const TaskTemplateExample({
    this.title,
    this.annotation,
    this.photoUrl,
    this.documentUrl,
  });

  final String? title;
  final String? annotation;
  final String? photoUrl;
  final String? documentUrl;
}

class TaskDetail {
  TaskDetail({
    required this.photos,
    required this.documents,
    this.submissionComment,
    this.qaComment,
    this.status,
    this.requiredPhotos,
    this.templateExample,
    this.taskTypeName,
  });

  final List<TaskPhoto> photos;
  final List<TaskDocument> documents;
  final String? submissionComment;
  final String? qaComment;
  final String? status;
  final int? requiredPhotos;
  final TaskTemplateExample? templateExample;
  final String? taskTypeName;
}
