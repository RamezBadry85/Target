import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import '../domain/customer_validation.dart';
import 'customer_strings.dart';
import 'customer_error.dart';

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key,required this.repository,this.customer});
  final CustomerRepository repository;
  final Customer? customer;
  @override
  State<CustomerFormPage> createState()=>_CustomerFormPageState();
}
class _ContactFields {
  _ContactFields(CustomerContact? contact):id=contact?.id ?? const Uuid().v4(),name=TextEditingController(text:contact?.name),phone=TextEditingController(text:contact?.phone),alternative=TextEditingController(text:contact?.alternativePhone),email=TextEditingController(text:contact?.email);
  final String id;
  final TextEditingController name,phone,alternative,email;
  CustomerContact value()=>CustomerContact(id:id,name:name.text,phone:phone.text,alternativePhone:alternative.text,email:email.text);
  void dispose(){ for(final c in [name,phone,alternative,email]) { c.dispose(); } }
}
class _CustomerFormPageState extends State<CustomerFormPage> {
  final _form=GlobalKey<FormState>();
  final _fields=<String,TextEditingController>{};
  final _contacts=<_ContactFields>[];
  late CustomerType _type;
  late CustomerStatus _status;
  bool _saving=false, _allowPop=false;
  String? _error;
  @override
  void initState(){
    super.initState(); final d=widget.customer?.data;
    final values={'name':d?.name,'address':d?.address,'governorate':d?.governorate,'city':d?.city,'area':d?.area,
      'classification':d?.classification,'businessSector':d?.businessSector,'representative':d?.assignedRepresentativeId,
      'notes':d?.notes,'currency':d?.currency ?? 'EGP','potential':CustomerValidation.money(d?.potentialMinor ?? 0),
      'credit':d?.creditLimitMinor==null ? '' : CustomerValidation.money(d!.creditLimitMinor!)};
    for(final entry in values.entries) { _fields[entry.key]=TextEditingController(text:entry.value); }
    _type=d?.type ?? CustomerType.other; _status=d?.status ?? CustomerStatus.prospect;
    _contacts.addAll(d?.contacts.map(_ContactFields.new) ?? [_ContactFields(null)]);
  }
  @override
  void dispose(){ for(final c in _fields.values) { c.dispose(); } for(final c in _contacts){ c.dispose(); } super.dispose(); }
  String v(String key)=>_fields[key]!.text;
  Future<void> _save() async {
    if(!_form.currentState!.validate()) return;
    setState(() { _saving=true; _error=null; });
    try {
      await widget.repository.save(CustomerDraft(name:v('name'),type:_type,contacts:_contacts.map((c)=>c.value()).toList(),
        address:v('address'),governorate:v('governorate'),city:v('city'),area:v('area'),classification:v('classification'),
        businessSector:v('businessSector'),assignedRepresentativeId:v('representative'),status:_status,
        currency:v('currency').trim().toUpperCase(),potentialMinor:CustomerValidation.parseMoney(v('potential'))!,
        creditLimitMinor:v('credit').trim().isEmpty ? null : CustomerValidation.parseMoney(v('credit')),notes:v('notes')),
        id:widget.customer?.id,expectedRevision:widget.customer?.revision);
      if(mounted) { setState(()=>_allowPop=true); WidgetsBinding.instance.addPostFrameCallback((_){if(mounted) Navigator.of(context).pop(true);}); }
    } catch(error){ if(mounted) setState(()=>_error=customerError(error,CustomerStrings(context))); }
    finally { if(mounted) setState(()=>_saving=false); }
  }
  @override
  Widget build(BuildContext context){
    final s=CustomerStrings(context);
    Widget field(String key,{int lines=1})=>TextFormField(key:ValueKey('customer-$key'),controller:_fields[key],decoration:InputDecoration(labelText:s.label(key)),maxLines:lines,maxLength:key=='notes' ? 10000 : key=='name' ? 200 : 500,
      keyboardType:['potential','credit'].contains(key) ? const TextInputType.numberWithOptions(decimal:true) : TextInputType.text,
      validator:(value){ final text=value?.trim() ?? '';
        if(key=='name' && text.length<2) return s.t('أدخل اسماً من حرفين على الأقل','Enter at least two characters');
        if(key=='currency' && !RegExp(r'^[A-Za-z]{3}$').hasMatch(text)) return s.t('رمز عملة من ثلاثة أحرف مثل EGP','Three-letter currency code, e.g. EGP');
        if((key=='potential' || (key=='credit' && text.isNotEmpty)) && CustomerValidation.parseMoney(text)==null) return s.t('أدخل رقماً موجباً بحد أقصى منزلتين عشريتين','Enter a non-negative amount with at most two decimal places');
        return null;
      });
    return PopScope<bool>(canPop:_allowPop && !_saving,onPopInvokedWithResult:(didPop,result) async {
      if(didPop || _saving) return;
      final discard=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text(s.t('تجاهل التعديلات غير المحفوظة؟','Discard unsaved changes?')),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:Text(s.cancel)),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(s.t('تجاهل','Discard')))]));
      if(discard==true && mounted){setState(()=>_allowPop=true);WidgetsBinding.instance.addPostFrameCallback((_){if(mounted) Navigator.of(context).pop(false);});}
    },child:Scaffold(appBar:AppBar(title:Text(widget.customer==null ? s.t('إضافة عميل','Add customer') : s.t('تعديل العميل','Edit customer'))),body:AbsorbPointer(absorbing:_saving,child:Form(key:_form,child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1000),child:LayoutBuilder(builder:(context,box){
      final width=box.maxWidth>=700 ? (box.maxWidth-16)/2 : box.maxWidth;
      return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        if(_error!=null) Padding(padding:const EdgeInsets.only(bottom:16),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
        Wrap(spacing:16,runSpacing:16,children:[
          SizedBox(width:width,child:field('name')),
          SizedBox(width:width,child:DropdownButtonFormField<CustomerType>(initialValue:_type,isExpanded:true,decoration:InputDecoration(labelText:s.label('type')),items:CustomerType.values.map((t)=>DropdownMenuItem(value:t,child:Text(s.type(t)))).toList(),onChanged:(t)=>setState(()=>_type=t!))),
          for(final key in ['governorate','city','area','address','classification','businessSector','representative','currency','potential','credit']) SizedBox(width:width,child:field(key)),
          SizedBox(width:width,child:DropdownButtonFormField<CustomerStatus>(initialValue:_status,decoration:InputDecoration(labelText:s.label('status')),items:CustomerStatus.values.map((t)=>DropdownMenuItem(value:t,child:Text(s.status(t)))).toList(),onChanged:(t)=>setState(()=>_status=t!))),
        ]),
        const SizedBox(height:24),Text(s.t('جهات الاتصال (الهاتف مطلوب لكل جهة)','Contacts (phone required for each)'),style:Theme.of(context).textTheme.titleLarge),
        for(var i=0;i<_contacts.length;i++) Card(margin:const EdgeInsets.symmetric(vertical:8),child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
          Row(children:[Expanded(child:Text('${s.t('جهة اتصال','Contact')} ${i+1}')),if(_contacts.length>1) IconButton(tooltip:s.t('إزالة جهة الاتصال','Remove contact'),onPressed:(){final removed=_contacts.removeAt(i);setState((){}); WidgetsBinding.instance.addPostFrameCallback((_){removed.dispose();});},icon:const Icon(Icons.close))]),
          Wrap(spacing:16,runSpacing:16,children:[
            for(final entry in {'contactName':_contacts[i].name,'phone':_contacts[i].phone,'alternativePhone':_contacts[i].alternative,'email':_contacts[i].email}.entries)
              SizedBox(width:(width-32).clamp(180,1000).toDouble(),child:TextFormField(key:ValueKey('contact-$i-${entry.key}'),controller:entry.value,decoration:InputDecoration(labelText:s.label(entry.key)),maxLength:entry.key=='email' ? 254 : 200,
                keyboardType:entry.key=='email' ? TextInputType.emailAddress : ['phone','alternativePhone'].contains(entry.key) ? TextInputType.phone : TextInputType.text,
                validator:(value){ if(entry.key=='phone' && !CustomerValidation.phone(value ?? '')) return s.t('هاتف صالح من 7 إلى 15 رقماً','Valid phone with 7–15 digits required');
                  if(entry.key=='alternativePhone' && !CustomerValidation.phone(value ?? '',optional:true)) return s.t('صيغة الهاتف غير صالحة','Invalid phone format');
                  if(entry.key=='email' && !CustomerValidation.email(value ?? '')) return s.t('صيغة البريد غير صالحة','Invalid email format');return null; })),
          ]),
        ]))),
        if(_contacts.length<50) Align(alignment:AlignmentDirectional.centerStart,child:TextButton.icon(onPressed:()=>setState(()=>_contacts.add(_ContactFields(null))),icon:const Icon(Icons.person_add_alt),label:Text(s.t('إضافة جهة اتصال','Add contact')))),
        const SizedBox(height:16),field('notes',lines:4),const SizedBox(height:16),
        FilledButton.icon(key:const ValueKey('save-customer'),onPressed:_saving ? null : _save,icon:_saving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.save_outlined),label:Text(s.save)),
      ]);
    }))))))));
  }
}
