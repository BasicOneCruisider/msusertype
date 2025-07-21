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
  - `Direct
