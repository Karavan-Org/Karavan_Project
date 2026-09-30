package ml.dogo.identite.domain;

import java.util.EnumSet;
import java.util.Set;

/** RG-04 : documents exigés selon le type d'acteur. */
public enum TypeDocument {
    NIF, REGISTRE_COMMERCE, LICENCE_TRANSIT, PIECE_IDENTITE;

    public static Set<TypeDocument> obligatoiresPour(TypeActeur type) {
        return switch (type) {
            case GROSSISTE -> EnumSet.of(PIECE_IDENTITE, NIF, REGISTRE_COMMERCE);
            case COURTIER -> EnumSet.of(PIECE_IDENTITE, LICENCE_TRANSIT);
            default -> EnumSet.noneOf(TypeDocument.class);
        };
    }
}
