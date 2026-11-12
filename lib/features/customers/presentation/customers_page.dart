import 'package:flutter/material.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import 'customer_strings.dart';
import 'customer_error.dart';
import 'customer_form_page.dart';
import 'customer_details_page.dart';
import 'customer_export_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key, required this.openModule});
  final Future<CustomerModule> Function() openModule;
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late Future<CustomerModule> _module;
  Stream<List<Customer>>? _stream;
  final _search = TextEditingController(),
      _governorate = TextEditingController(),
      _city = TextEditingController(),
      _classification = TextEditingController();
  CustomerType? _type;
  CustomerSort _sort = CustomerSort.name;
  bool _archived = false, _descending = false;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _module = widget.openModule();
  }

  @override
  void dispose() {
    for (final c in [_search, _governorate, _city, _classification]) {
      c.dispose();
    }
    super.dispose();
  }

  CustomerQuery get query => CustomerQuery(
    search: _search.text,
    governorate: _governorate.text,
    city: _city.text,
    classification: _classification.text,
    type: _type,
    archived: _archived,
    sort: _sort,
    descending: _descending,
  );
  void _refresh() {
    setState(() => _page = 0);
  }

  String _description(CustomerStrings s) => [
    _archived ? s.t('الأرشيف', 'Archived') : s.t('غير المؤرشف', 'Not archived'),
    if (_search.text.isNotEmpty) '${s.t('بحث', 'Search')}: ${_search.text}',
    if (_governorate.text.isNotEmpty)
      '${s.label('governorate')}: ${_governorate.text}',
    if (_city.text.isNotEmpty) '${s.label('city')}: ${_city.text}',
    if (_classification.text.isNotEmpty)
      '${s.label('classification')}: ${_classification.text}',
    if (_type != null) s.type(_type!),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final s = CustomerStrings(context);
    return FutureBuilder<CustomerModule>(
      future: _module,
      builder: (context, initialized) {
        if (initialized.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    s.t(
                      'تعذر فتح قاعدة البيانات المحلية. لا تمسح بيانات التطبيق.',
                      'Cannot open the local database. Do not clear app data.',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _stream = null;
                      _module = widget.openModule();
                    }),
                    child: Text(s.t('إعادة المحاولة', 'Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        if (!initialized.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final module = initialized.data!;
        _stream ??= module.repository.watchAll();
        return StreamBuilder<List<Customer>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                children: [
                  Text(s.error),
                  TextButton(
                    onPressed: () =>
                        setState(() => _stream = module.repository.watchAll()),
                    child: Text(s.t('إعادة المحاولة', 'Retry')),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final records = snapshot.data!;
            final filtered = query.apply(records);
            final pages = (filtered.length / 25)
                .ceil()
                .clamp(1, 1000000)
                .toInt();
            final page = _page.clamp(0, pages - 1).toInt();
            final shown = filtered.skip(page * 25).take(25).toList();
            void details(Customer c) => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerDetailsPage(
                  repository: module.repository,
                  customerId: c.id,
                ),
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      s.t('قائمة العملاء', 'Customer list'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    FilledButton.icon(
                      key: const ValueKey('add-customer'),
                      onPressed: () => Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerFormPage(
                            repository: module.repository,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(s.t('إضافة عميل', 'Add customer')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerExportPage(
                            module: module,
                            records: List.unmodifiable(records),
                            query: query,
                            filterDescription: _description(s),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(s.t('تصدير', 'Export')),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(s.cloudNotice),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, box) {
                    final width = box.maxWidth < 600
                        ? box.maxWidth
                        : (box.maxWidth - 16) / 2;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: TextField(
                            key: const ValueKey('customer-search'),
                            controller: _search,
                            onChanged: (_) => _refresh(),
                            decoration: InputDecoration(
                              labelText: s.t(
                                'بحث بالاسم أو الهاتف أو البريد أو المعرف',
                                'Search name, phone, email or ID',
                              ),
                              prefixIcon: const Icon(Icons.search),
                            ),
                          ),
                        ),
                        for (final entry in {
                          'governorate': _governorate,
                          'city': _city,
                          'classification': _classification,
                        }.entries)
                          SizedBox(
                            width: width,
                            child: TextField(
                              controller: entry.value,
                              onChanged: (_) => _refresh(),
                              decoration: InputDecoration(
                                labelText: s.label(entry.key),
                                helperText: s.t(
                                  'مطابقة كاملة؛ اتركه فارغاً لعرض الكل',
                                  'Exact match; leave blank for all',
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<CustomerType>(
                            initialValue: _type,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: s.label('type'),
                            ),
                            items: [
                              DropdownMenuItem<CustomerType>(
                                value: null,
                                child: Text(s.t('كل الأنواع', 'All types')),
                              ),
                              ...CustomerType.values.map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(s.type(t)),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              _type = v;
                              _refresh();
                            },
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<CustomerSort>(
                            initialValue: _sort,
                            decoration: InputDecoration(
                              labelText: s.t('ترتيب حسب', 'Sort by'),
                            ),
                            items: CustomerSort.values
                                .map(
                                  (sort) => DropdownMenuItem(
                                    value: sort,
                                    child: Text(
                                      s.t(
                                        [
                                          'الاسم',
                                          'الأحدث إنشاءً',
                                          'آخر تحديث',
                                          'القيمة المحتملة',
                                        ][sort.index],
                                        [
                                          'Name',
                                          'Newest created',
                                          'Last updated',
                                          'Potential value',
                                        ][sort.index],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              _sort = v!;
                              _refresh();
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Wrap(
                  spacing: 16,
                  children: [
                    FilterChip(
                      label: Text(s.t('عرض الأرشيف', 'Show archived')),
                      selected: _archived,
                      onSelected: (v) {
                        _archived = v;
                        _refresh();
                      },
                    ),
                    FilterChip(
                      label: Text(s.t('عكس الترتيب', 'Reverse order')),
                      selected: _descending,
                      onSelected: (v) {
                        _descending = v;
                        _refresh();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('${s.t('النتائج', 'Results')}: ${filtered.length}'),
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        s.t(
                          'لا يوجد عملاء مطابقون. أضف عميلاً أو عدّل عوامل التصفية.',
                          'No matching customers. Add a customer or adjust the filters.',
                        ),
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, box) {
                      if (box.maxWidth < 800) {
                        return Column(
                          children: [
                            for (final c in shown)
                              Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  onTap: () => details(c),
                                  title: Text(c.data.name),
                                  subtitle: Text(
                                    '${s.type(c.data.type)} · ${c.data.city}\n${c.data.contacts.firstOrNull?.phone ?? ''}\n${s.sync(c.syncStatus)}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                ),
                              ),
                          ],
                        );
                      }
                      return Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            showCheckboxColumn: false,
                            columns: [
                              DataColumn(label: Text(s.label('name'))),
                              DataColumn(label: Text(s.label('type'))),
                              DataColumn(label: Text(s.label('phone'))),
                              DataColumn(label: Text(s.label('city'))),
                              DataColumn(
                                label: Text(s.t('المزامنة', 'Synchronization')),
                              ),
                            ],
                            rows: [
                              for (final c in shown)
                                DataRow(
                                  onSelectChanged: (_) => details(c),
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 220,
                                        child: Text(
                                          c.data.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(s.type(c.data.type))),
                                    DataCell(
                                      Text(
                                        c.data.contacts.firstOrNull?.phone ??
                                            '',
                                      ),
                                    ),
                                    DataCell(Text(c.data.city)),
                                    DataCell(Text(s.sync(c.syncStatus))),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: s.t('السابق', 'Previous'),
                      onPressed: page == 0
                          ? null
                          : () => setState(() => _page = page - 1),
                      icon: const Icon(Icons.navigate_before),
                    ),
                    Text('${page + 1} / $pages'),
                    IconButton(
                      tooltip: s.t('التالي', 'Next'),
                      onPressed: page + 1 >= pages
                          ? null
                          : () => setState(() => _page = page + 1),
                      icon: const Icon(Icons.navigate_next),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
