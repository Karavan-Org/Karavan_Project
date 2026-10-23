import 'package:flutter/material.dart';
import '../models/role_acteur.dart';
import '../widgets/mes_documents.dart';

/// Documents du grossiste : son dossier de vérification réel (/api/kyc/moi).
class DocumentsGrossisteScreen extends StatelessWidget {
  const DocumentsGrossisteScreen({super.key});

  @override
  Widget build(BuildContext context) => const MesDocumentsScreen(role: RoleActeur.grossiste);
}
