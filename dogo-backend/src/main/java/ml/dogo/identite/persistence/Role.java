package ml.dogo.identite.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.Table;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "role")
public class Role {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String nom;

    private String description;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(name = "role_permission",
            joinColumns = @JoinColumn(name = "role_id"),
            inverseJoinColumns = @JoinColumn(name = "permission_id"))
    private Set<Permission> permissions = new HashSet<>();

    protected Role() {
    }

    /** RG-06 : vérifie l'accès à une fonction par son code de permission. */
    public boolean verifierAcces(String codePermission) {
        return permissions.stream().anyMatch(p -> p.getCode().equals(codePermission));
    }

    public Long getId() { return id; }
    public String getNom() { return nom; }
    public String getDescription() { return description; }
    public Set<Permission> getPermissions() { return permissions; }
}
