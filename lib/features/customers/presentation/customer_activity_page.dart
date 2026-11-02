import 'package:flutter/material.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import 'customer_strings.dart';
import 'customer_error.dart';

class CustomerActivityPage extends StatefulWidget {
  const CustomerActivityPage({
    super.key,
    required this.repository,
    required this.customerId,
  });
  final CustomerRepository repository;
  final String customerId;
  @override
  State<CustomerActivityPage> createState() => _CustomerActivityPageState();
}

class _CustomerActivityPageState extends State<CustomerActivityPage> {
  Future<void> _add(Customer customer) async {
    final s = CustomerStrings(context);
    final text = TextEditingController();
    var type = ActivityType.note;
    var date = DateTime.now();
    var saving = false;
    String? errorMessage;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(s.t('تسجيل نشاط', 'Record activity')),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if(errorMessage!=null) Text(errorMessage!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
                  DropdownButtonFormField<ActivityType>(
                    initialValue: type,
                    isExpanded: true,
                    items: ActivityType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(s.activity(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (t) => setDialog(() => type = t!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: text,
                    maxLength: 10000,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: s.t(
                        'وصف النشاط (مطلوب)',
                        'Activity description (required)',
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialog(() => date = picked);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      MaterialLocalizations.of(context).formatMediumDate(date),
                    ),
                  ),
                  Text(
                    s.t(
                      'الأنشطة التجارية هنا مجرد سجل وصفي؛ لا تنشئ معاملات بيع أو عروض أسعار.',
                      'Business activity types are descriptive logs only; they do not create sales or quotations.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: saving ? null : () async {
                setDialog(() { saving=true;errorMessage=null; });
                try {
                  await widget.repository.addActivity(customer.id,customer.revision,type,text.text,date);
                  if(context.mounted) Navigator.pop(context,true);
                } catch(error) { if(context.mounted) setDialog(()=>errorMessage=customerError(error,s)); }
                finally { if(context.mounted) setDialog(()=>saving=false); }
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
    text.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = CustomerStrings(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('سجل أنشطة العميل', 'Customer activity history')),
      ),
      body: StreamBuilder<List<Customer>>(
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          final customer = snapshot.data
              ?.where((c) => c.id == widget.customerId)
              .firstOrNull;
          if (snapshot.hasError) return Center(child: Text(s.error));
          if (customer == null)
            return const Center(child: CircularProgressIndicator());
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => _add(customer),
                  icon: const Icon(Icons.add),
                  label: Text(s.t('تسجيل نشاط', 'Record activity')),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CustomerActivity>>(
                  future: widget.repository.activities(customer.id),
                  builder: (context, activities) {
                    if (activities.hasError)
                      return Center(child: Text(s.error));
                    if (!activities.hasData)
                      return const Center(child: CircularProgressIndicator());
                    if (activities.data!.isEmpty)
                      return Center(
                        child: Text(
                          s.t('لا توجد أنشطة مسجلة', 'No recorded activities'),
                        ),
                      );
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: activities.data!.length,
                      itemBuilder: (context, index) {
                        final a = activities.data![index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(s.activity(a.type)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).formatFullDate(a.occurredAt.toLocal()),
                                ),
                                Text(a.text),
                                if (a.sourceReference != null)
                                  Text(a.sourceReference!),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
