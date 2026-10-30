import { Injectable } from '@angular/core';
import { PAYS_ISO, PaysIso } from '../data/pays-iso';

export interface PaysInfo extends PaysIso {
  /** false si la saisie ne correspond à aucun pays ISO : on l'affiche telle quelle, sans deviner. */
  reconnu: boolean;
}

/**
 * Résolution d'un pays à partir d'un code ISO (2 ou 3 lettres), d'un nom français ou anglais,
 * avec ou sans accents, ou d'une ville d'approvisionnement courante (« Guangzhou », « Dubaï »…).
 * La correspondance est exacte après normalisation : « Niger » ne devient jamais « Nigeria ».
 */
@Injectable({ providedIn: 'root' })
export class PaysResolverService {
  private readonly index = PaysResolverService.construireIndex();

  private static construireIndex(): Map<string, PaysIso> {
    const index = new Map<string, PaysIso>();
    const ajouter = (cle: string, p: PaysIso) => {
      if (cle && !index.has(cle)) index.set(cle, p);
    };
    // Codes d'abord, puis noms officiels, puis alias : une clé déjà prise n'est jamais écrasée.
    for (const p of PAYS_ISO) {
      index.set(p.codeIso.toLowerCase(), p);
      index.set(p.codeIso3.toLowerCase(), p);
    }
    for (const p of PAYS_ISO) {
      ajouter(PaysResolverService.cle(p.nomFr), p);
      ajouter(PaysResolverService.cle(p.nomEn), p);
    }
    for (const p of PAYS_ISO) {
      for (const a of p.alias) ajouter(PaysResolverService.cle(a), p);
    }
    return index;
  }

  /** Minuscules, sans accents, espaces ni ponctuation : « Côte d’Ivoire » → « cotedivoire ». */
  static cle(texte: string): string {
    return texte
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/œ/g, 'oe')
      .replace(/[^a-z0-9]/g, '');
  }

  resoudre(saisie?: string | null): PaysInfo {
    const texte = (saisie ?? '').trim();
    if (!texte) {
      return { codeIso: '', codeIso3: '', nomFr: '', nomEn: '', alias: [], reconnu: false };
    }
    let p = this.index.get(PaysResolverService.cle(texte));
    if (!p && texte.includes('?')) {
      // Tolérance aux caractères accentués altérés (ex: "Br?sil" -> "Brésil", "C?te d'Ivoire" -> "Côte d'Ivoire")
      const cleAvecWildcards = texte
        .normalize('NFD')
        .replace(/[̀-ͯ]/g, '')
        .toLowerCase()
        .replace(/œ/g, 'oe')
        .replace(/[^a-z0-9?]/g, '');
      const motif = new RegExp('^' + cleAvecWildcards.replace(/\?/g, '.') + '$');
      p = PAYS_ISO.find(item =>
        motif.test(PaysResolverService.cle(item.nomFr)) ||
        motif.test(PaysResolverService.cle(item.nomEn))
      );
    }
    return p
      ? { ...p, reconnu: true }
      : { codeIso: '', codeIso3: '', nomFr: texte, nomEn: texte, alias: [], reconnu: false };
  }

  get tousLesPays(): readonly PaysIso[] {
    return PAYS_ISO;
  }
}
