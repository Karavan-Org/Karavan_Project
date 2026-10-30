package ml.dogo.notification.web;

import java.util.List;
import ml.dogo.notification.application.NotificationService;
import ml.dogo.shared.security.UtilisateurCourant;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/moi/notifications")
public class NotificationController {

    private final NotificationService service;

    public NotificationController(NotificationService service) {
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('NOTIFICATION_LIRE')")
    public List<NotificationService.NotificationVue> lister(@AuthenticationPrincipal UtilisateurCourant moi,
                                                            @RequestParam(defaultValue = "30") int taille) {
        return service.mesNotifications(moi.id(), taille);
    }

    @PostMapping("/{id}/lue")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('NOTIFICATION_LIRE')")
    public void marquerLue(@AuthenticationPrincipal UtilisateurCourant moi, @PathVariable long id) {
        service.marquerLue(moi.id(), id);
    }
}
