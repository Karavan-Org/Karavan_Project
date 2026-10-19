package ml.dogo.architecture;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.library.freeze.FreezingArchRule;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.stream.Stream;
import org.junit.jupiter.api.DynamicTest;
import org.junit.jupiter.api.TestFactory;

/**
 * Garde-fous de l'architecture « monolithe modulaire » : chaque module (identite, catalogue, campagne, participation,
 * finance, logistique, notification, audit) n'est utilisable par les autres que par son paquet {@code api}.
 *
 * <p>Les règles sont vérifiées par JUnit Jupiter : avec Surefire, le moteur {@code @ArchTest} n'était jamais découvert
 * (0 test exécuté, une règle violée passait au vert). Les violations déjà présentes à la réactivation sont gelées
 * dans {@code src/test/resources/archunit_store} : seules les nouvelles font échouer le build.
 */
class ArchitectureTest {

    private static final JavaClasses CLASSES = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("ml.dogo");

    /** Une vérification par champ {@link ArchRule} de cette classe. */
    @TestFactory
    Stream<DynamicTest> regles() {
        return Stream.of(ArchitectureTest.class.getDeclaredFields())
                .filter(champ -> Modifier.isStatic(champ.getModifiers()) && ArchRule.class.isAssignableFrom(champ.getType()))
                .map(champ -> DynamicTest.dynamicTest(champ.getName(), () -> FreezingArchRule.freeze(regle(champ)).check(CLASSES)));
    }

    private static ArchRule regle(Field champ) throws IllegalAccessException {
        return (ArchRule) champ.get(null);
    }

    private static final String[] MODULES = {"identite", "catalogue", "groupeachat", "participation", "finance",
            "logistique", "notification", "audit", "litige"};

    /** Le domaine (règles de gestion pures) ne dépend ni de Spring, ni de JPA, ni des couches techniques. */
    static final ArchRule domaine_pur = noClasses().that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAnyPackage("org.springframework..", "jakarta..",
                    "..persistence..", "..application..", "..web..", "..api..");

    /** Les couches respectent leur sens : web → application → persistence → domain, jamais l'inverse. */
    static final ArchRule persistance_independante_des_services = noClasses().that().resideInAPackage("..persistence..")
            .should().dependOnClassesThat().resideInAnyPackage("..application..", "..web..");

    static final ArchRule application_independante_du_web = noClasses().that().resideInAPackage("..application..")
            .should().dependOnClassesThat().resideInAPackage("..web..");

    static final ArchRule web_sans_acces_direct_aux_entites = noClasses().that().resideInAPackage("..web..")
            .and().resideOutsideOfPackage("..shared..")
            .should().dependOnClassesThat().resideInAPackage("..persistence..");

    /** Aucun module ne va chercher les entités, dépôts ou services d'un autre module : seul {@code api} est public. */
    static final ArchRule modules_communiquent_par_api = classes()
            .that().resideOutsideOfPackages("..shared..", "..demo..")
            .should(new com.tngtech.archunit.lang.ArchCondition<com.tngtech.archunit.core.domain.JavaClass>(
                    "n'utiliser d'un autre module que son paquet api") {
                @Override
                public void check(com.tngtech.archunit.core.domain.JavaClass classe,
                                  com.tngtech.archunit.lang.ConditionEvents evenements) {
                    String monModule = module(classe.getPackageName());
                    classe.getDirectDependenciesFromSelf().forEach(dependance -> {
                        String paquetCible = dependance.getTargetClass().getPackageName();
                        String moduleCible = module(paquetCible);
                        if (monModule != null && moduleCible != null && !monModule.equals(moduleCible)
                                && !paquetCible.contains(".api")) {
                            evenements.add(com.tngtech.archunit.lang.SimpleConditionEvent.violated(dependance,
                                    classe.getName() + " utilise " + dependance.getTargetClass().getName()));
                        }
                    });
                }
            });

    /** Pas de dépendance circulaire entre modules. */
    static final ArchRule pas_de_cycle_entre_modules = slices()
            .matching("ml.dogo.(identite|catalogue|groupeachat|participation|finance|logistique|notification|audit|litige)..")
            .should().beFreeOfCycles();

    /** Le chargeur de démo est un outil d'amorçage : rien ne dépend de lui. */
    static final ArchRule personne_ne_depend_de_la_demo = noClasses().that().resideOutsideOfPackage("..demo..")
            .should().dependOnClassesThat().resideInAPackage("..demo..");

    /** Les contrôleurs n'appellent pas les dépôts : ils passent par les services. */
    static final ArchRule controleurs_sans_depots = noClasses().that().haveSimpleNameEndingWith("Controller")
            .should().dependOnClassesThat().haveSimpleNameEndingWith("Repository");

    private static String module(String paquet) {
        for (String m : MODULES) {
            if (paquet.startsWith("ml.dogo." + m + ".") || paquet.equals("ml.dogo." + m)) {
                return m;
            }
        }
        return null;
    }
}

