import 'package:flutter/material.dart';

class CloudTtsEngine {
  final String id;
  final String name;
  final String type; // system, local, cloud
  final String? apiKey;
  final String? apiUrl;
  final String? region;
  final bool enabled;
  final int? rate;
  final int? pitch;

  CloudTtsEngine({required this.id, required this.name, required this.type, this.apiKey, this.apiUrl, this.region, this.enabled = true, this.rate, this.pitch});

  factory CloudTtsEngine.fromJson(Map<String, dynamic> json) => CloudTtsEngine(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    type: json['type'] ?? 'system',
    apiKey: json['apiKey'],
    apiUrl: json['apiUrl'],
    region: json['region'],
    enabled: json['enabled'] ?? true,
    rate: json['rate'],
    pitch: json['pitch'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'type': type, 'apiKey': apiKey,
    'apiUrl': apiUrl, 'region': region, 'enabled': enabled, 'rate': rate, 'pitch': pitch,
  };
}

class CloudTtsScreen extends StatefulWidget {
  const CloudTtsScreen({super.key});

  @override
  State<CloudTtsScreen> createState() => _CloudTtsScreenState();
}

class _CloudTtsScreenState extends State<CloudTtsScreen> {
  final List<CloudTtsEngine> _engines = [
    CloudTtsEngine(id: 'system', name: '系统TTS', type: 'system', enabled: true),
    CloudTtsEngine(id: 'volcengine', name: '火山引擎TTS', type: 'cloud', region: 'cn-beijing', enabled: false),
    CloudTtsEngine(id: 'azure', name: 'Azure语音', type: 'cloud', region: 'eastus', enabled: false),
    CloudTtsEngine(id: 'openai', name: 'OpenAI TTS', type: 'cloud', apiUrl: 'https://api.openai.com/v1', enabled: false),
    CloudTtsEngine(id: 'gemini', name: 'Gemini TTS', type: 'cloud', enabled: false),
    CloudTtsEngine(id: 'aws', name: 'AWS Polly', type: 'cloud', region: 'us-east-1', enabled: false),
    CloudTtsEngine(id: 'alibaba', name: '阿里云TTS', type: 'cloud', region: 'cn-shanghai', enabled: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TTS引擎管理')),
      body: ListView.builder(
        itemCount: _engines.length,
        itemBuilder: (context, index) {
          final engine = _engines[index];
          return Card(
            child: ListTile(
              leading: Icon(engine.type == 'system' ? Icons.phone_android : Icons.cloud_outlined),
              title: Text(engine.name),
              subtitle: Text(engine.type == 'system' ? '系统内置' : '云端引擎${engine.region != null ? " (${engine.region})" : ""}'),
              trailing: Switch(
                value: engine.enabled,
                onChanged: (v) => setState(() => _engines[index] = CloudTtsEngine(
                  id: engine.id, name: engine.name, type: engine.type,
                  apiKey: engine.apiKey, apiUrl: engine.apiUrl, region: engine.region,
                  enabled: v, rate: engine.rate, pitch: engine.pitch,
                )),
              ),
              onTap: () => _showEngineConfig(engine, index),
            ),
          );
        },
      ),
    );
  }

  void _showEngineConfig(CloudTtsEngine engine, int index) {
    final apiKeyController = TextEditingController(text: engine.apiKey ?? '');
    final apiUrlController = TextEditingController(text: engine.apiUrl ?? '');
    final regionController = TextEditingController(text: engine.region ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(engine.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (engine.type == 'cloud') ...[
              TextField(controller: apiKeyController, decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder()), obscureText: true),
              const SizedBox(height: 12),
              TextField(controller: apiUrlController, decoration: const InputDecoration(labelText: 'API URL', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: regionController, decoration: const InputDecoration(labelText: '区域', border: OutlineInputBorder())),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  setState(() => _engines[index] = CloudTtsEngine(
                    id: engine.id, name: engine.name, type: engine.type,
                    apiKey: apiKeyController.text, apiUrl: apiUrlController.text,
                    region: regionController.text, enabled: engine.enabled,
                    rate: engine.rate, pitch: engine.pitch,
                  ));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已保存')));
                },
                child: const Text('保存'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
