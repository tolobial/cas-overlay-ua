# Authentication Interrupt : contrôle de `supannMailPerso`

Référence : spec « Activation automatique de la méthode mail MFA » du 26/09/2026
(`gestid/docs/superpowers/specs/2026-09-26-mfa-mail-auto-enrollment-design.pdf`),
§5.1-5.2. Le §6 de cette spec traite de la relance proactive échelonnée, qui
conditionne la date d'activation (voir §4, point 6 ci-dessous).

Objectif : juste après l'authentification LDAP, avant la MFA,

| `supannMailPerso`                         | Comportement                                   |
|-------------------------------------------|------------------------------------------------|
| absent, `null`, liste vide, valeurs vides | **blocage total** : message de renvoi vers un canal fiable (présentiel ou numéro officiel), **jamais de lien cliquable**, pas de poursuite, pas de SSO |
| au moins une valeur non vide              | **rien** : le flux continue normalement        |

Tout ce qui suit a été vérifié sur les jars CAS 7.3.8 (bytecode de
`cas-server-support-interrupt-core` et du modèle de configuration), sans
serveur ni build.

## 1. Dépendances (`build.gradle`, `gradle.properties`)

- `cas.version=7.3.8.3` (release de sécurité publiée sur Maven Central ; la
  BOM 7.3.8.3 garde Spring Boot 3.5.6, donc `springBootVersion` est inchangé).
- `cas-server-support-interrupt-webflow` : tire `-interrupt-api` et
  `-interrupt-core`, où sont les déclencheurs JSON, Groovy, REST et Regex.
- `cas-server-core-scripting` : **indispensable pour le déclencheur Groovy**.
  `GroovyScriptInterruptInquirer` passe par `ExecutableCompiledScriptFactory`,
  dont l'implémentation Groovy (`GroovyExecutableCompiledScriptFactory`, plus
  `org.apache.groovy:groovy*`) se trouve dans ce module. Le `build/libs/cas.war`
  actuel ne contient aucun jar Groovy : sans cette ligne, le script ne serait
  pas exécutable.

Les versions ne sont pas fixées dans les lignes de dépendance : elles viennent
de `enforcedPlatform(cas-server-support-bom:${cas.version})`, comme pour les
autres modules de l'overlay.

## 2. Déclencheurs disponibles

Chaque déclencheur est activé par la présence de sa propriété. Ils peuvent
coexister (plan d'exécution ordonné).

### JSON — `cas.interrupt.json.location`

`JsonResourceInterruptInquirer` charge une map **indexée par identifiant de
principal** (`uid` → `InterruptResponse`) et recharge le fichier s'il change.

- Pour : aucun code, rechargement à chaud.
- Contre : c'est une liste nominative statique. Il faudrait générer et tenir à
  jour une entrée par compte sans `supannMailPerso`, en dehors de CAS.
- **Inadapté** à une règle sur la valeur d'un attribut.

### Groovy — `cas.interrupt.groovy.location`

`GroovyScriptInterruptInquirer` exécute `run(Object... args)` avec, dans cet
ordre : `principal`, `attributes` (attributs du principal et de
l'authentification fusionnés), `service`, `registeredService`,
`requestContext`, `logger`. Le script renvoie un `InterruptResponse`. Il est
surveillé et rechargé quand le fichier change.

- Pour : exprime directement « absent ou vide », sans composant externe, et la
  logique est versionnée dans ce dépôt.
- Contre : il faut `cas-server-core-scripting` (runtime Groovy dans le war) ;
  c'est du code, à tester comme tel.

### REST — `cas.interrupt.rest.url`

`RestEndpointInterruptInquirer` appelle un service HTTP externe (avec
principal et service en paramètres) qui renvoie un `InterruptResponse` en JSON.

- Pour : la décision peut vivre dans un autre SI et interroger d'autres sources.
- Contre : un service de plus à développer, héberger, sécuriser et superviser,
  plus un appel réseau à chaque connexion. Il faut aussi décider de l'effet
  d'une panne. Surdimensionné pour tester un attribut que CAS possède déjà.

### Regex — `cas.interrupt.regex.attribute-name` / `attribute-value`

Ce déclencheur n'était pas demandé, mais il est l'alternative « sans code » la
plus proche. `RegexAttributeInterruptInquirer` interrompt si un attribut
**présent** a une valeur qui correspond à l'expression.

- **Inadapté** : un attribut absent ne correspond à rien, donc le cas principal
  (absence) ne déclencherait jamais. En outre, la réponse est un
  `InterruptResponse.interrupt()` générique, non bloquant.

## 3. Recommandation : Groovy

C'est le seul déclencheur qui teste l'absence d'un attribut sans composant
externe. Le script est `etc/cas/config/interrupt/supannMailPerso-interrupt.groovy`.
Les cas absent / `null` / `[]` / `['  ']` / `''` → blocage et `['x@y.fr']` /
`'x@y.fr'` / `['', 'x@y.fr']` → rien ont été vérifiés hors CAS avec un bouchon
de `InterruptResponse`.

Branche « absent » : `new InterruptResponse(message, [:], block=true, ssoEnabled=false)`.
La map `links` reste vide par exigence de la spec (§5.2 : jamais de lien
cliquable dans le message d'interruption).
Branche « présent » : `InterruptResponse.none()`.

### Propriétés à ajouter (`cas.properties`, non versionné)

```properties
# Authentication Interrupt — contrôle supannMailPerso
cas.interrupt.groovy.location=file:/etc/cas/config/interrupt/supannMailPerso-interrupt.groovy
# Défaut explicité : déclenché juste après l'authentification primaire
cas.interrupt.core.trigger-mode=AFTER_AUTHENTICATION
```

`supannMailPerso` figure déjà dans `cas.authn.ldap[0].principal-attribute-list`,
et c'est ce qui le rend visible du script.

## 4. Points à valider en recette

1. **Politique par service** : un service dont le JSON déclare
   `webflowInterruptPolicy.enabled=false` n'est pas interrompu
   (`BaseInterruptInquirer.shouldSkipInterruptForRegisteredService`). Pour un
   blocage « total », aucun service ne doit le désactiver. Une connexion sans
   service (`/cas/login` direct) est bien contrôlée.
2. **Ordre avec la MFA esup-otp** : la spec (§5.1) exige l'interruption
   « avant la MFA ». Il faut vérifier que le blocage survient avant la
   proposition du second facteur. L'ordre effectif du webflow n'a pas été testé.
3. **`cas.interrupt.core.force-execution`** (défaut `false`) : le contrôle
   s'appuie sur un cookie de suivi. Avec `ssoEnabled=false` aucun SSO n'est
   établi, donc le contrôle rejoue à chaque tentative. C'est le résultat
   attendu, à confirmer.
4. **Message** : texte en dur dans le script. Il ne contient aucune URL ni aucun
   numéro. Le numéro officiel du support pourra y être ajouté en clair
   (texte, pas de lien). Pour l'i18n, utiliser `setMessageCode("…")` avec une
   clé dans `messages*.properties`. Il faut aussi vérifier que le template
   `casInterruptView` n'ajoute pas de lien de lui-même.
5. **Déploiement** : copier le script dans `/etc/cas/config/interrupt/` sur la
   cible (le répertoire `etc/cas/config` du dépôt n'est pas embarqué dans le war).
6. **Activation par vagues (spec §6.3)** : le blocage ne doit s'appliquer qu'aux
   retardataires d'une vague, une fois sa relance terminée (personnel d'abord,
   puis les étudiants par composante). Le script livré bloque **toute** la
   population sans `supannMailPerso` dès que `cas.interrupt.groovy.location` est
   défini. Tant que la première vague n'est pas échue, il ne faut pas activer la
   propriété. Pour activer par vague, il faudra ajouter un filtre au script (par
   exemple `eduPersonAffiliation` ou `supannEntiteAffectation`, déjà présents
   dans `principal-attribute-list`). Ce filtre est à définir.
7. **Aucun contournement (spec §7)** : un usager bloqué le reste jusqu'à son
   passage en agence. Cela renforce le point 1 : aucune politique de service ne
   doit désactiver l'interruption.
