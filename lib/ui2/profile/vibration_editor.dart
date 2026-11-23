// VibrationEditorScreen — visual creator and manager for custom haptic vibrations.
// Allows composing rhythms, testing live on the WHOOP strap, and copying
// ready-to-paste MacroDroid / Tasker configurations.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/vibration_pattern.dart';
import '../../state/app_state.dart';
import '../ui2.dart';

class VibrationEditorScreen extends StatefulWidget {
  const VibrationEditorScreen({super.key});

  @override
  State<VibrationEditorScreen> createState() => _VibrationEditorScreenState();
}

class _VibrationEditorScreenState extends State<VibrationEditorScreen> {
  bool _creating = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final List<VibrationStep> _draftSteps = [
    const VibrationStep(VibrationStepType.single),
    const VibrationStep(VibrationStepType.pause, 200),
    const VibrationStep(VibrationStepType.doubleTap),
  ];
  bool _playing = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    const ch = MethodChannel('openstrap/tasker');
    try {
      final t = await ch.invokeMethod<String>('get_auth_token');
      if (mounted) setState(() => _token = t);
    } catch (_) {}
  }

  Future<void> _play(AppState app, List<VibrationStep> steps) async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      await app.engine.playVibrationSequence(steps);
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  void _copyForMacroDroid(String name, {String? directAction}) {
    final tokenStr = _token ?? '<TUO_TOKEN>';
    final text = directAction != null
        ? '''Azione: $directAction
Pacchetto: wtf.openstrap.openstrap_custom
Extra Stringa 1: token=$tokenStr'''
        : '''Azione: wtf.openstrap.openstrap_custom.BUZZ_STRAP
Pacchetto: wtf.openstrap.openstrap_custom
Extra Stringa 1: token=$tokenStr
Extra Stringa 2: name=$name''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configurazione per MacroDroid ($name) copiata!'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _saveDraft(AppState app) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _draftSteps.isEmpty) return;
    final vibration = CustomVibration(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      steps: List.from(_draftSteps),
    );
    app.saveCustomVibration(vibration);
    setState(() {
      _creating = false;
      _nameCtrl.clear();
      _draftSteps
        ..clear()
        ..addAll([
          const VibrationStep(VibrationStepType.single),
          const VibrationStep(VibrationStepType.pause, 200),
          const VibrationStep(VibrationStepType.doubleTap),
        ]);
    });
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final app = c.watch<AppState>();
    final customList = app.customVibrations;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Vibrazioni Personalizzate'),
        backgroundColor: p.bg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, S.x16),
        children: [
          // ── Creator Card ──
          if (_creating) ...[
            Surface(
              pad: const EdgeInsets.all(S.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.sparkles, size: 18, color: C.crimson),
                      const SizedBox(width: S.x2),
                      Text(
                        'Componi nuova vibrazione',
                        style: F.head.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Pressable(
                        onTap: () => setState(() => _creating = false),
                        semanticLabel: 'Chiudi',
                        child: Icon(LucideIcons.x, size: 18, color: p.ink2),
                      ),
                    ],
                  ),
                  const SizedBox(height: S.x3),
                  TextField(
                    controller: _nameCtrl,
                    style: F.body.copyWith(color: p.ink),
                    decoration: InputDecoration(
                      labelText: 'Nome vibrazione (es. whatsapp, banca, mamma)',
                      labelStyle: F.cap.copyWith(color: p.ink2),
                      filled: true,
                      fillColor: p.card2,
                      border: OutlineInputBorder(
                        borderRadius: R.rSm,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: S.x4),
                  Text('Sequenza ritmica:', style: F.cap.copyWith(color: p.ink2)),
                  const SizedBox(height: S.x2),
                  Wrap(
                    spacing: S.x2,
                    runSpacing: S.x2,
                    children: _draftSteps.asMap().entries.map((e) {
                      final idx = e.key;
                      final s = e.value;
                      final isPause = s.type == VibrationStepType.pause;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x2),
                        decoration: BoxDecoration(
                          color: isPause ? p.card2 : p.wash(C.crimson),
                          borderRadius: R.rPill,
                          border: Border.all(
                            color: isPause ? p.line : C.crimson,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.label,
                              style: F.cap.copyWith(
                                color: isPause ? p.ink2 : C.crimson,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: S.x1),
                            Pressable(
                              onTap: () => setState(() => _draftSteps.removeAt(idx)),
                              semanticLabel: 'Elimina step',
                              child: Icon(LucideIcons.x, size: 14, color: isPause ? p.ink3 : C.crimson),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: S.x4),
                  Text('Aggiungi elemento:', style: F.cap.copyWith(color: p.ink2)),
                  const SizedBox(height: S.x2),
                  Wrap(
                    spacing: S.x2,
                    runSpacing: S.x2,
                    children: [
                      _stepAddChip(p, '+ Tocco Singolo', () {
                        setState(() => _draftSteps.add(const VibrationStep(VibrationStepType.single)));
                      }),
                      _stepAddChip(p, '+ Doppio Tocco', () {
                        setState(() => _draftSteps.add(const VibrationStep(VibrationStepType.doubleTap)));
                      }),
                      _stepAddChip(p, '+ Vibrazione Lunga', () {
                        setState(() => _draftSteps.add(const VibrationStep(VibrationStepType.alarm)));
                      }),
                      _stepAddChip(p, '+ Pausa 200ms', () {
                        setState(() => _draftSteps.add(const VibrationStep(VibrationStepType.pause, 200)));
                      }),
                      _stepAddChip(p, '+ Pausa 400ms', () {
                        setState(() => _draftSteps.add(const VibrationStep(VibrationStepType.pause, 400)));
                      }),
                    ],
                  ),
                  const SizedBox(height: S.x4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Pressable(
                        onTap: () => _play(app, _draftSteps),
                        semanticLabel: 'Prova al polso',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x2),
                          decoration: BoxDecoration(
                            color: p.card2,
                            borderRadius: R.rPill,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.play, size: 14, color: C.silverBright),
                              const SizedBox(width: S.x1),
                              Text('Prova al polso', style: F.cap.copyWith(color: C.silverBright)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: S.x2),
                      Pressable(
                        onTap: () => _saveDraft(app),
                        semanticLabel: 'Salva vibrazione',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x2),
                          decoration: BoxDecoration(
                            color: p.fill(C.crimson),
                            borderRadius: R.rPill,
                          ),
                          child: Text(
                            'Salva vibrazione',
                            style: F.cap.copyWith(color: p.inkOnFill, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: S.x4),
          ] else ...[
            Pressable(
              onTap: () => setState(() => _creating = true),
              semanticLabel: 'Crea nuova vibrazione',
              child: Surface(
                pad: const EdgeInsets.all(S.x4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(S.x2),
                      decoration: BoxDecoration(
                        color: p.wash(C.crimson),
                        borderRadius: R.rSm,
                      ),
                      child: const Icon(LucideIcons.plus, size: 18, color: C.crimson),
                    ),
                    const SizedBox(width: S.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crea nuova vibrazione',
                            style: F.head.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Componi un ritmo unico con tocchi e pause personalizzate',
                            style: F.cap.copyWith(color: p.ink2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: S.x4),
          ],

          // ── Le tue vibrazioni salvate ──
          if (customList.isNotEmpty) ...[
            Text('Le tue vibrazioni create', style: F.head.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: S.x2),
            ...customList.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: S.x3),
                  child: Surface(
                    pad: const EdgeInsets.all(S.x4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              v.name,
                              style: F.head.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Pressable(
                              onTap: () => _play(app, v.steps),
                              semanticLabel: 'Ascolta',
                              child: Container(
                                padding: const EdgeInsets.all(S.x2),
                                decoration: BoxDecoration(
                                  color: p.wash(C.crimson),
                                  borderRadius: R.rPill,
                                ),
                                child: const Icon(LucideIcons.play, size: 16, color: C.crimson),
                              ),
                            ),
                            const SizedBox(width: S.x2),
                            Pressable(
                              onTap: () => app.deleteCustomVibration(v.id),
                              semanticLabel: 'Elimina',
                              child: Container(
                                padding: const EdgeInsets.all(S.x2),
                                decoration: BoxDecoration(
                                  color: p.card2,
                                  borderRadius: R.rPill,
                                ),
                                child: Icon(LucideIcons.trash2, size: 16, color: p.ink3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: S.x2),
                        Wrap(
                          spacing: S.x1,
                          runSpacing: S.x1,
                          children: v.steps
                              .map((s) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x1),
                                    decoration: BoxDecoration(
                                      color: p.card2,
                                      borderRadius: R.rPill,
                                    ),
                                    child: Text(s.label, style: F.over.copyWith(color: p.ink2)),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: S.x3),
                        Pressable(
                          onTap: () => _copyForMacroDroid(v.name),
                          semanticLabel: 'Copia per MacroDroid',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x2),
                            decoration: BoxDecoration(
                              color: p.card2,
                              borderRadius: R.rSm,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.copy, size: 14, color: C.silverBright),
                                const SizedBox(width: S.x2),
                                Text(
                                  'Copia comando MacroDroid (name="${v.name}")',
                                  style: F.cap.copyWith(color: C.silverBright, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: S.x4),
          ],

          // ── Preset Pronti all'Uso ──
          Text('Preset pronti per MacroDroid', style: F.head.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: S.x2),
          _presetCard(
            p,
            app,
            title: 'Singola (1 tocco secco)',
            desc: 'Perfetta per notifiche ordinarie o silenziose.',
            action: 'wtf.openstrap.openstrap_custom.BUZZ_SINGLE',
            steps: CustomVibration.presetSingle,
          ),
          _presetCard(
            p,
            app,
            title: 'Doppia (2 tocchi rapidi)',
            desc: 'Ideale per messaggi WhatsApp, Telegram, SMS.',
            action: 'wtf.openstrap.openstrap_custom.BUZZ_DOUBLE',
            steps: CustomVibration.presetDouble,
          ),
          _presetCard(
            p,
            app,
            title: 'Tripla (3 tocchi con ritmo)',
            desc: 'Ideale per email, promemoria importanti o alert.',
            action: 'wtf.openstrap.openstrap_custom.BUZZ_TRIPLE',
            steps: CustomVibration.presetTriple,
          ),
          _presetCard(
            p,
            app,
            title: 'Allarme continuo',
            desc: 'Vibrazione sostenuta per chiamate in arrivo.',
            action: 'wtf.openstrap.openstrap_custom.BUZZ_ALARM',
            steps: CustomVibration.presetAlarm,
          ),
          _presetCard(
            p,
            app,
            title: 'SOS / Emergenza',
            desc: 'Sequenza ritmica distintiva per allarmi critici o contatti VIP.',
            action: 'wtf.openstrap.openstrap_custom.BUZZ_SOS',
            steps: CustomVibration.presetSos,
          ),
        ],
      ),
    );
  }

  Widget _stepAddChip(P p, String label, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x2),
        decoration: BoxDecoration(
          color: p.card2,
          borderRadius: R.rPill,
        ),
        child: Text(label, style: F.cap.copyWith(color: C.silverBright)),
      ),
    );
  }

  Widget _presetCard(
    P p,
    AppState app, {
    required String title,
    required String desc,
    required String action,
    required List<VibrationStep> steps,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x3),
      child: Surface(
        pad: const EdgeInsets.all(S.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: F.head.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
                      const SizedBox(height: S.x1),
                      Text(desc, style: F.cap.copyWith(color: p.ink2)),
                    ],
                  ),
                ),
                Pressable(
                  onTap: () => _play(app, steps),
                  semanticLabel: 'Ascolta $title',
                  child: Container(
                    padding: const EdgeInsets.all(S.x2),
                    decoration: BoxDecoration(
                      color: p.wash(C.crimson),
                      borderRadius: R.rPill,
                    ),
                    child: const Icon(LucideIcons.play, size: 16, color: C.crimson),
                  ),
                ),
              ],
            ),
            const SizedBox(height: S.x3),
            Pressable(
              onTap: () => _copyForMacroDroid(title, directAction: action),
              semanticLabel: 'Copia per MacroDroid',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: S.x3, vertical: S.x2),
                decoration: BoxDecoration(
                  color: p.card2,
                  borderRadius: R.rSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.copy, size: 14, color: C.silverBright),
                    const SizedBox(width: S.x2),
                    Text(
                      'Copia Azione per MacroDroid',
                      style: F.cap.copyWith(color: C.silverBright, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
