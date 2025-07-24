import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FreeGameSettingsPage extends StatefulWidget {
  final int initialWordLength;
  final bool initialIsTimerEnabled;
  final int initialTimerDuration;

  const FreeGameSettingsPage({
    Key? key,
    required this.initialWordLength,
    required this.initialIsTimerEnabled,
    required this.initialTimerDuration,
  }) : super(key: key);

  @override
  State<FreeGameSettingsPage> createState() => _FreeGameSettingsPageState();
}

class _FreeGameSettingsPageState extends State<FreeGameSettingsPage> {
  late int _wordLength;
  late bool _isTimerEnabled;
  late int _timerDuration;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _wordLength = widget.initialWordLength;
    _isTimerEnabled = widget.initialIsTimerEnabled;
    _timerDuration = widget.initialTimerDuration;
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wordLength = prefs.getInt('free_word_length') ?? _wordLength;
      _isTimerEnabled = prefs.getBool('free_is_timer_enabled') ?? _isTimerEnabled;
      _timerDuration = prefs.getInt('free_timer_duration') ?? _timerDuration;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('free_word_length', _wordLength);
    await prefs.setBool('free_is_timer_enabled', _isTimerEnabled);
    await prefs.setInt('free_timer_duration', _timerDuration);
    setState(() => _isSaving = false);
    if (mounted) {
      Navigator.of(context).pop({
        'wordLength': _wordLength,
        'isTimerEnabled': _isTimerEnabled,
        'timerDuration': _timerDuration,
        'saved': true,
      });
    }
  }

  void _applyOnce() {
    Navigator.of(context).pop({
      'wordLength': _wordLength,
      'isTimerEnabled': _isTimerEnabled,
      'timerDuration': _timerDuration,
      'saved': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serbest Oyun Ayarları'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      backgroundColor: theme.colorScheme.background,
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelime Uzunluğu',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          value: _wordLength,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceVariant,
                          ),
                          style: theme.textTheme.bodyLarge,
                          items: [4, 5, 6, 7, 8]
                              .map((length) => DropdownMenuItem(
                                    value: length,
                                    child: Text('$length Harf'),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _wordLength = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Süre Sınırı',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Switch(
                              value: _isTimerEnabled,
                              onChanged: (value) => setState(() => _isTimerEnabled = value),
                              activeColor: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        if (_isTimerEnabled) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            value: (_timerDuration / 60).round(),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant,
                            ),
                            style: theme.textTheme.bodyLarge,
                            items: List.generate(15, (i) => i + 1)
                                .map((minute) => DropdownMenuItem(
                                      value: minute,
                                      child: Text('$minute dakika'),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _timerDuration = val * 60);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        child: const Text('Kaydet ve Kullan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _applyOnce,
                        child: const Text('Tek Seferlik Kullan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'Kaydet: Ayarlarınız kalıcı olur.\nTek Seferlik: Sadece bu oyun için geçerli.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600], height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
} 