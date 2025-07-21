# 🧾 Azure Function – Gestion des utilisateurs inactifs via Microsoft Graph

Ce script PowerShell est conçu pour être exécuté dans une **Azure Function (PowerShell 7.4)** afin de détecter, suivre et signaler les utilisateurs **inactifs** dans **Microsoft Entra ID (Azure AD)**. Il s’appuie sur **Microsoft Graph** pour collecter les données d’activité, notifier les managers (via Microsoft Teams), et taguer les utilisateurs traités.

---

## 🚀 Fonctionnalités principales

- 🔍 Détection des utilisateurs n’ayant pas signé depuis un certain nombre de jours (`90`, `180`, personnalisable).
- 👥 Exclusion possible de certains utilisateurs via un groupe Entra ID spécifié.
- 🧾 Génération d’un **rapport de synthèse Markdown** prêt à être posté dans un canal Microsoft Teams.
- 📌 Tag des utilisateurs inactifs via une **attribut personnalisé (extension)**.
- ✅ Prise en charge des utilisateurs qui se reconnectent (réactivation).

---

## 🔑 Points Clés

- ⚙️ **Exécution** : Ce script s’exécute dans une **Azure Function** avec une **identité managée**.
- 🔐 **Autorisations requises** sur Microsoft Graph :
  - `User.Read.All`
  - `Directory.Read.All`
  - `User.ReadWrite.All`
  - `Group.Read.All`
  - `Chat.ReadWrite`
  - `ChannelMessage.Send`
- 🧪 **Placeholders à implémenter** :
  - Notification Teams aux managers
  - Mise à jour de l'attribut utilisateur (tagging/detagging)
- 💬 **Rapport Markdown** : Généré automatiquement, prêt à être posté dans un canal Teams.

> 🛑 Ce script **ne supprime aucun utilisateur**. Il est uniquement destiné à la détection et au suivi.

---

## ⚙️ Prérequis

### Modules PowerShell requis

- `Microsoft.Graph.Authentication`
- `Microsoft.Graph.Users`
- `Microsoft.Graph.Groups`

> Ces modules doivent être référencés dans votre `requirements.psd1` pour Azure Functions.

### Autorisations Graph API (identité managée)

Votre Azure Function doit avoir les **permissions d’application suivantes** (dans Entra ID > Identité managée > API Microsoft Graph) :

- `User.Read.All`
- `Directory.Read.All`
- `User.ReadWrite.All`
- `Group.Read.All`
- `Chat.ReadWrite`
- `ChannelMessage.Send`

---

## ⚙️ Paramètres du script

| Paramètre                      | Description                                                                                  |
|-------------------------------|----------------------------------------------------------------------------------------------|
| `InactivityThresholds`        | Liste des seuils d’inactivité en jours. Par défaut : `90`, `180`                            |
| `ExcludeGroupDisplayName`     | Nom du groupe Entra ID dont les membres sont exclus du traitement                           |
| `TeamsSummaryTeamId`          | ID de l’équipe Teams dans laquelle publier le rapport                                       |
| `TeamsSummaryChannelId`       | ID du canal Teams pour poster le résumé                                                     |
| `InactiveUserTagExtensionName`| Nom de l’attribut personnalisé pour taguer les utilisateurs inactifs                        |

---

## 🔧 Déploiement (Azure Function)

1. **Créer une Azure Function** avec runtime PowerShell 7.
2. Ajouter les modules nécessaires dans `requirements.psd1`.
3. Coller le script dans un fichier `.ps1` dans `run.ps1`.
4. Configurer l'identité managée et attribuer les permissions Graph.
5. Définir les paramètres d’application (`APP SETTINGS`) si utilisés.
6. Tester et surveiller via Azure Function logs.

---

## 📌 Exemple de tag utilisateur

Le tag personnalisé utilisé est stocké dans un **open extension**. Exemple de structure JSON :

```json
{
  "isInactive": true,
  "inactiveThresholdDays": 90,
  "lastTaggedUTC": "2025-07-21T12:00:00Z"
}
