/** Adresse du backend Spring Boot DoGo (même serveur que les applications Commerçant, Grossiste et Courtier). */
export const API_URL = 'http://localhost:8080/api';

/** Message lisible à partir d'une erreur HTTP du backend (ProblemDetail : detail, regle, erreurs). */
export function messageErreur(erreur: any, defaut = 'Une erreur est survenue.'): string {
  if (erreur?.status === 0) {
    return 'Impossible de joindre le serveur Karavan. Veuillez vérifier votre connexion internet.';
  }
  if (erreur?.status === 401) {
    return 'Session expirée. Reconnecte-toi.';
  }
  if (erreur?.status === 403) {
    return 'Accès refusé : ton rôle administratif ne permet pas cette action.';
  }
  const corps = erreur?.error;
  const details: string[] = Array.isArray(corps?.erreurs) ? corps.erreurs : [];
  const texte = corps?.detail || corps?.message || defaut;
  const regle = corps?.regle ? ` (${corps.regle})` : '';
  return details.length ? `${texte}${regle} : ${details.join(', ')}` : `${texte}${regle}`;
}

/** 1250000 → « 1 250 000 FCFA » */
export function fcfa(montant: number | string | null | undefined): string {
  const n = Number(montant ?? 0);
  return `${Math.round(Number.isFinite(n) ? n : 0).toLocaleString('fr-FR')} FCFA`;
}

/** Date courte à l'heure de Bamako (« 09/10/2026 18:02 ») */
export function dateCourte(date: string | null | undefined): string {
  if (!date) {
    return '—';
  }
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) {
    return '—';
  }
  return new Intl.DateTimeFormat('fr-FR', {
    timeZone: 'Africa/Bamako',
    dateStyle: 'short',
    timeStyle: 'short'
  }).format(d);
}

/** « Il y a 5 min », « Hier », « Il y a 3 jours » */
export function dateRelative(date: string | null | undefined): string {
  if (!date) {
    return 'Date inconnue';
  }
  const t = new Date(date).getTime();
  if (Number.isNaN(t)) {
    return 'Date inconnue';
  }
  const minutes = Math.max(0, Math.floor((Date.now() - t) / 60_000));
  if (minutes < 1) return 'À l’instant';
  if (minutes < 60) return `Il y a ${minutes} min`;
  const heures = Math.floor(minutes / 60);
  if (heures < 24) return `Il y a ${heures} h`;
  const jours = Math.floor(heures / 24);
  return jours === 1 ? 'Hier' : `Il y a ${jours} jours`;
}

/** Libellés des états de groupe (StatutGroupe du backend) */
export const LIBELLES_GROUPE: Record<string, string> = {
  BROUILLON: 'Brouillon',
  EN_VALIDATION: 'En validation',
  OUVERT: 'Ouvert',
  OBJECTIF_ATTEINT: 'Objectif atteint',
  EN_EXPEDITION: 'En expédition',
  LIVRE: 'Livré au dépôt',
  TERMINE: 'Terminé',
  ANNULE: 'Annulé',
  ECHOUE: 'Échoué'
};

/** Libellés des états de convoi (StatutExpedition du backend) */
export const LIBELLES_CONVOI: Record<string, string> = {
  ACHETE: 'Acheté',
  CHEZ_TRANSITAIRE: 'Chez le transitaire',
  EN_TRANSIT: 'En transit',
  BLOQUE_DOUANE: 'Bloqué en douane',
  ARRIVE: 'Arrivé'
};

/** Télécharge un fichier texte généré dans le navigateur (export CSV / JSON) */
export function telechargerTexte(nom: string, contenu: string, type = 'text/csv;charset=utf-8'): void {
  const url = URL.createObjectURL(new Blob(['﻿' + contenu], { type }));
  const lien = document.createElement('a');
  lien.href = url;
  lien.download = nom;
  lien.click();
  URL.revokeObjectURL(url);
}

/** Ligne CSV (séparateur « ; » pour Excel français) */
export function ligneCsv(valeurs: unknown[]): string {
  return valeurs.map(v => `"${String(v ?? '').replace(/"/g, '""')}"`).join(';');
}

/** Libellés des états de commande (StatutCommande du backend) */
export const LIBELLES_COMMANDE: Record<string, string> = {
  CREEE: 'Commande créée',
  PREPAREE: 'En préparation',
  EXPEDIEE: 'En transit',
  ARRIVEE: 'Au dépôt',
  EN_ATTENTE_RETRAIT: 'Prêt pour retrait',
  COLLECTEE: 'Retirée',
  ANNULEE: 'Annulée'
};

/** Libellés des états de séquestre (StatutSequestre du backend) */
export const LIBELLES_SEQUESTRE: Record<string, string> = {
  BLOQUE: 'Bloqué',
  LIBERE: 'Libéré',
  RESTITUE: 'Restitué'
};

/** Résout une URL d'image servie par le backend */
export function urlImage(chemin: string | null | undefined): string {
  if (!chemin) return '';
  if (chemin.startsWith('http://') || chemin.startsWith('https://')) return chemin;
  const racine = API_URL.replace(/\/api$/, '');
  return `${racine}${chemin.startsWith('/') ? '' : '/'}${chemin}`;
}
