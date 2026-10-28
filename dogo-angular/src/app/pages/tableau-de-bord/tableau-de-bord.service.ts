import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { API_URL } from '../../core/api';

export interface PaysVue {
  codeIso: string;
  codeIso3: string;
  nomFr: string;
  latitude: number;
  longitude: number;
}

export interface RepartitionPaysVue {
  codeIso: string;
  nomFr: string;
  nombreGroupes: number;
  pourcentage: number;
  latitude: number;
  longitude: number;
}

export interface UtilisateursResume {
  clients: number;
  grossistes: number;
  courtiers: number;
  total: number;
}

export interface ResumeTableauDeBord {
  utilisateurs: UtilisateursResume;
  totalGroupes: number;
  groupesParStatut: Record<string, number>;
  repartitionPays: RepartitionPaysVue[];
  groupesSansPays: number;
  groupesLancesMois: number;
  progressionMoyenne: number;
  groupesComplets: number;
  retardsSuivi: number;
}

export interface ActeurVue {
  id: number;
  nom: string;
}

export interface GroupeCadranVue {
  id: number;
  titre: string;
  statut: string;
  paysOrigine?: PaysVue | null;
  quantiteCible: number;
  quantiteConfirmee: number;
  quantiteReservee: number;
  progressionPourcentage: number;
  prixUnitaire: number;
  dateLancement: string;
  dateLimite: string;
  grossiste: ActeurVue;
  courtier: ActeurVue;
  etapeSuivi?: string | null;
  categorieNom?: string | null;
}

export interface EtapeVue {
  id: number;
  etape: string;
  commentaire?: string | null;
  date?: string | null;
}

export interface GroupeDetailVue {
  id: number;
  titre: string;
  statut: string;
  paysOrigine?: PaysVue | null;
  quantiteCible: number;
  quantiteConfirmee: number;
  quantiteReservee: number;
  quantiteRestante: number;
  progressionPourcentage: number;
  prixUnitaire: number;
  dateLancement: string;
  dateLimite: string;
  disponibiliteValidee: boolean;
  porteParGrossiste: boolean;
  grossiste: ActeurVue;
  courtier: ActeurVue;
  produitNom: string;
  produitDescription?: string | null;
  produitPhotoUrl?: string | null;
  categorieNom?: string | null;
  prixMarchandise: number;
  transport: number;
  fraisPlateforme: number;
  douane: number;
  autres: number;
  devise: string;
  delaiLivraisonJours: number;
  politiqueAnnulation?: string | null;
  quantiteMinParCommercant: number;
  etapesAcheminement: EtapeVue[];
}

export interface PaysReference {
  codeIso: string;
  nomFr: string;
  latitude: number;
  longitude: number;
  actif: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class TableauDeBordService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${API_URL}/admin/tableau-de-bord`;

  getResume(): Observable<ResumeTableauDeBord> {
    return this.http.get<ResumeTableauDeBord>(`${this.baseUrl}/resume`);
  }

  getGroupes(params?: {
    statut?: string;
    pays?: string;
    q?: string;
    page?: number;
    taille?: number;
  }): Observable<GroupeCadranVue[]> {
    let httpParams = new HttpParams();
    if (params?.statut) httpParams = httpParams.set('statut', params.statut);
    if (params?.pays) httpParams = httpParams.set('pays', params.pays);
    if (params?.q) httpParams = httpParams.set('q', params.q);
    if (params?.page !== undefined) httpParams = httpParams.set('page', params.page.toString());
    if (params?.taille !== undefined) httpParams = httpParams.set('taille', params.taille.toString());

    return this.http.get<GroupeCadranVue[]>(`${this.baseUrl}/groupes`, { params: httpParams });
  }

  getDetailGroupe(id: number): Observable<GroupeDetailVue> {
    return this.http.get<GroupeDetailVue>(`${this.baseUrl}/groupes/${id}`);
  }

  assignerPays(id: number, paysOrigineCode: string): Observable<any> {
    return this.http.put(`${this.baseUrl}/groupes/${id}/pays`, { paysOrigineCode });
  }

  getPaysActifs(): Observable<PaysReference[]> {
    return this.http.get<PaysReference[]>(`${API_URL}/pays`);
  }
}

