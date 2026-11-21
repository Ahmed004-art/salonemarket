/// Category model representing marketplace taxonomy.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.coverImageUrl,
    this.parentId,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Category',
      slug: (map['slug'] as String?) ?? '',
      description: map['description'] as String?,
      iconUrl: map['icon_url'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
      parentId: map['parent_id'] as String?,
      sortOrder: (map['sort_order'] is num)
          ? (map['sort_order'] as num).toInt()
          : (int.tryParse(map['sort_order']?.toString() ?? '0') ?? 0),
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final String? coverImageUrl;
  final String? parentId;
  final int sortOrder;
  final bool isActive;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon_url': iconUrl,
      'cover_image_url': coverImageUrl,
      'parent_id': parentId,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}
