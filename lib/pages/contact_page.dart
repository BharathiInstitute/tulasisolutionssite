import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../sections/contact/contact_intro_section.dart';
import '../sections/contact/contact_form_section.dart';
import '../sections/contact/whatsapp_section.dart';
import '../sections/contact/phone_email_section.dart';
import '../sections/contact/india_reach_section.dart';
import '../sections/contact/booking_calendar_section.dart';
// Footer class is also exported from contact_form_section.dart

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final GlobalKey _formKey = GlobalKey();
  final GlobalKey _whatsappKey = GlobalKey();
  final GlobalKey _phoneKey = GlobalKey();
  String? _lastArg;

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut, alignment: 0.08);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null || args == _lastArg) return;
    _lastArg = args as String?;
    switch (_lastArg) {
      case 'form':
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_formKey));
        break;
      case 'whatsapp':
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_whatsappKey));
        break;
      case 'phone':
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_phoneKey));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ContactIntroSection(),
            ContactFormCardSection(anchorKey: _formKey),
            Container(key: _whatsappKey, child: const WhatsappChatSection()),
            Container(key: _phoneKey, child: const PhoneEmailSection()),
            const IndiaReachSection(),
            const BookingCalendarSection(),
            const ContactFooterSection(),
          ],
        ),
      ),
    );
  }
}
