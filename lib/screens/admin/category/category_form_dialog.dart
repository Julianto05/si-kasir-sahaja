import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/category_model.dart';
import '../../../providers/category_provider.dart';

/// Modal dialog for adding or editing a product category.
class CategoryFormDialog extends StatefulWidget {
  final CategoryModel? category;

  const CategoryFormDialog({super.key, this.category});

  static Future<bool?> show(BuildContext context, {CategoryModel? category}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CategoryFormDialog(category: category),
    );
  }

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late bool _isActive;
  bool _isSubmitting = false;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descController =
        TextEditingController(text: widget.category?.description ?? '');
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<CategoryProvider>();
    bool success;

    if (_isEdit) {
      final updated = widget.category!.copyWith(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        isActive: _isActive,
      );
      success = await provider.updateCategory(updated);
    } else {
      success = await provider.addCategory(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        isActive: _isActive,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Kategori "${_nameController.text}" berhasil diperbarui'
                : 'Kategori "${_nameController.text}" berhasil ditambahkan',
          ),
          backgroundColor: AppTheme.secondary,
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                      ),
                      child: Icon(
                        _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit Kategori' : 'Tambah Kategori',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Name Input
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kategori *',
                    hintText: 'e.g. Makanan, Minuman, Sembako',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama kategori wajib diisi';
                    }
                    if (value.trim().length < 2) {
                      return 'Nama kategori minimal 2 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Description Input
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi (Opsional)',
                    hintText: 'Keterangan kategori...',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Active Switch
                SwitchListTile(
                  title: const Text('Status Aktif'),
                  subtitle: Text(
                    _isActive
                        ? 'Kategori akan tampil pada kasir & produk'
                        : 'Kategori disembunyikan sementara',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: _isActive,
                  activeThumbColor: AppTheme.secondary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
                const SizedBox(height: AppTheme.spacingLg),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSubmitting ? null : () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isEdit ? 'Simpan' : 'Tambah'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
