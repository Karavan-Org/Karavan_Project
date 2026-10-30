package ml.dogo.shared.stockage;

/** Port de stockage de fichiers (documents KYC, preuves). Local pour la démo ; S3 ou autre plus tard. */
public interface StockageFichiers {

    /** Enregistre le contenu et renvoie la clé de stockage (jamais le nom fourni par l'utilisateur). */
    String enregistrer(String nomOriginal, byte[] contenu);

    /** Relit un fichier à partir de sa clé de stockage. */
    byte[] lire(String cle);
}
