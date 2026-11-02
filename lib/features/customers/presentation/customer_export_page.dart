import 'package:flutter/material.dart';
import '../../../core/files/document_files.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import 'customer_strings.dart';

class CustomerExportPage extends StatefulWidget {
  const CustomerExportPage({
    super.key,
    required this.module,
    required this.records,
    required this.query,
    required this.filterDescription,
  });
  final CustomerModule module;
  final List<Customer> records;
  final CustomerQuery query;
  final String filterDescription;
  @override
  State<CustomerExportPage> createState() => _CustomerExportPageState();
}

class _CustomerExportPageState extends State<CustomerExportPage> {
  bool _all = false, _busy = false;
  String? _message;
  Future<void> _export(String format) async {
    final s = CustomerStrings(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    final records = _all
        ? (List<Customer>.from(widget.records)
            ..sort((a, b) => a.data.name.compareTo(b.data.name)))
        : widget.query.apply(widget.records);
    try {
      final now = DateTime.now().toUtc();
      final bytes = format == 'xlsx'
          ? await widget.module.reports.xlsx(records, arabic: s.arabic)
          : await widget.module.reports.pdf(
              records,
              arabic: s.arabic,
              filters: _all
                  ? s.t(
                      'كل السجلات، بما في ذلك الأرشيف',
                      'All records, including archived',
                    )
                  : widget.filterDescription,
              generatedAt: now,
            );
      final saved = await DocumentFiles.save(
        bytes,
        'Target-Customers-${now.millisecondsSinceEpoch}',
        format,
      );
      if (mounted) {
        setState(
          () => _message = saved
              ? s.t(
                  'تم تسليم الملف إلى نظام الحفظ / تنزيل المتصفح.',
                  'File handed to the save dialog / browser download.',
                )
              : s.t('تم إلغاء الحفظ', 'Save cancelled'),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _message = s.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = CustomerStrings(context);
    final count = _all
        ? widget.records.length
        : widget.query.apply(widget.records).length;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('خيارات التصدير', 'Export options'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.t('تصدير بيانات العملاء', 'Export customer data'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      value: _all,
                      onChanged: _busy ? null : (v) => setState(() => _all = v),
                      title: Text(
                        s.t(
                          'كل السجلات، بما في ذلك الأرشيف',
                          'All records, including archived',
                        ),
                      ),
                      subtitle: Text(
                        s.t(
                          'عند الإيقاف: كل النتائج المطابقة للتصفية، وليس الصفحة الحالية فقط.',
                          'When off: all filtered matches, not just the current page.',
                        ),
                      ),
                    ),
                    Text('${s.t('عدد العملاء', 'Customer count')}: $count'),
                    Text(widget.filterDescription),
                    const SizedBox(height: 16),
                    Text(
                      s.t(
                        'تحتوي الملفات على بيانات حساسة. احفظها في مكان آمن.',
                        'Exports contain sensitive information. Store them securely.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _export('xlsx'),
                      icon: const Icon(Icons.table_view_outlined),
                      label: const Text('Excel · XLSX'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _export('pdf'),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF · A4'),
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_message!),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
