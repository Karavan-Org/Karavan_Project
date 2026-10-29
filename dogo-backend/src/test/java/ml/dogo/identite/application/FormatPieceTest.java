package ml.dogo.identite.application;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.jupiter.api.Test;

class FormatPieceTest {

    private static final byte[] PDF = "%PDF-1.4\n%%EOF".getBytes(StandardCharsets.US_ASCII);
    private static final byte[] OLE2 = {(byte) 0xD0, (byte) 0xCF, 0x11, (byte) 0xE0, (byte) 0xA1, (byte) 0xB1, 0x1A,
            (byte) 0xE1, 0, 0};

    private static byte[] zip(String... entrees) throws IOException {
        ByteArrayOutputStream sortie = new ByteArrayOutputStream();
        try (ZipOutputStream z = new ZipOutputStream(sortie)) {
            for (String e : entrees) {
                z.putNextEntry(new ZipEntry(e));
                z.write("x".getBytes(StandardCharsets.US_ASCII));
                z.closeEntry();
            }
        }
        return sortie.toByteArray();
    }

    @Test
    void imagesEtPdfReconnusParLeurSignatureQuelQueSoitLeNom() {
        assertThat(FormatPiece.extensionValidee("scan.bin", PDF)).isEqualTo(".pdf");
        assertThat(FormatPiece.extensionValidee("x.png", new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0}))
                .isEqualTo(".jpg");
    }

    @Test
    void documentsBureautiquesAcceptes() throws IOException {
        byte[] docx = zip("[Content_Types].xml", "word/document.xml");
        assertThat(FormatPiece.extensionValidee("Registre.DOCX", docx)).isEqualTo(".docx");
        assertThat(FormatPiece.extensionValidee("releve.xlsx", zip("[Content_Types].xml", "xl/workbook.xml")))
                .isEqualTo(".xlsx");
        assertThat(FormatPiece.extensionValidee("nif.odt", zip("mimetype", "content.xml"))).isEqualTo(".odt");
        assertThat(FormatPiece.extensionValidee("ancien.doc", OLE2)).isEqualTo(".doc");
        assertThat(FormatPiece.extensionValidee("note.rtf", "{\\rtf1 bonjour}".getBytes(StandardCharsets.US_ASCII)))
                .isEqualTo(".rtf");
        assertThat(FormatPiece.extensionValidee("note.txt", "Société Kéïta\r\nNIF 123\t".getBytes(StandardCharsets.UTF_8)))
                .isEqualTo(".txt");
    }

    @Test
    void contenuIncoherentOuDangereuxRefuse() throws IOException {
        // Archive quelconque déguisée, macros, binaire déguisé en texte, extension inconnue
        assertThat(FormatPiece.extensionValidee("piece.docx", zip("payload.exe"))).isNull();
        assertThat(FormatPiece.extensionValidee("piece.docx", zip("[Content_Types].xml", "word/vbaProject.bin")))
                .isNull();
        assertThat(FormatPiece.extensionValidee("piece.doc", zip("[Content_Types].xml"))).isNull();
        assertThat(FormatPiece.extensionValidee("piece.txt", new byte[]{'M', 'Z', 0, 0, 1})).isNull();
        assertThat(FormatPiece.extensionValidee("piece.html", "<script>".getBytes(StandardCharsets.US_ASCII))).isNull();
        assertThat(FormatPiece.extensionValidee("piece.txt", new byte[]{'a'})).isNull();
    }
}
