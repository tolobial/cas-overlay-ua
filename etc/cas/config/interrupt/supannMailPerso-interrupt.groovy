/*
 * Authentication Interrupt — contrôle de supannMailPerso
 * (spec « Activation automatique de la méthode mail MFA » du 26/09/2026, §5.1-5.2).
 *
 * Activé par : cas.interrupt.groovy.location=file:/etc/cas/config/interrupt/supannMailPerso-interrupt.groovy
 * Documentation : docs/interrupt-supannMailPerso.md
 *
 * Deux branches :
 *   - supannMailPerso absent ou vide  -> blocage total (block=true, ssoEnabled=false),
 *                                        renvoi vers un canal fiable, JAMAIS de lien (§5.2)
 *   - supannMailPerso présent          -> aucune interruption
 *
 * Arguments passés par GroovyScriptInterruptInquirer (CAS 7.3.8), dans cet ordre :
 *   principal, attributes (principal + authentification fusionnés), service,
 *   registeredService, requestContext, logger
 */
import org.apereo.cas.interrupt.InterruptResponse

def run(final Object... args) {
    def (principal, attributes, service, registeredService, requestContext, logger) = args

    def values = attributes?.get("supannMailPerso")
    def present = values instanceof Collection
        ? values.any { it != null && it.toString().trim() }
        : (values != null && values.toString().trim())

    if (present) {
        logger.debug("supannMailPerso présent pour [{}] : pas d'interruption", principal.id)
        return InterruptResponse.none()
    }

    logger.info("supannMailPerso absent ou vide pour [{}] : accès bloqué", principal.id)
    return new InterruptResponse(
        "Votre compte ne comporte pas d'adresse de messagerie personnelle, " +
            "nécessaire à la sécurisation de votre accès. " +
            "Pour la faire enregistrer, présentez-vous auprès d'un agent de la DSIN " +
            "ou appelez le numéro officiel du support publié par l'université.",
        [:],      // liens : toujours vide, aucun lien cliquable (spec §5.2)
        true,     // block : l'utilisateur ne peut pas poursuivre
        false     // ssoEnabled : aucune session SSO n'est établie
    )
}
