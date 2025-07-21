<#
.SYNOPSIS
    Script pour détecter les utilisateurs inactifs dans Entra ID (anciennement Azure AD).

.DESCRIPTION
    Utilise Microsoft Graph pour :
    - Identifier les utilisateurs n'ayant pas eu de connexion depuis X jours
    - Exclure certains utilisateurs via un groupe
    - Notifier les managers (placeholder)
    - Taguer les utilisateurs traités (évite les doublons)
    - Poster un rapport de synthèse dans Teams (placeholder)

.PARAMETERS
    - InactivityThresholds : Nombre de jours d'inactivité (par défaut : 90 et 180)
    - ExcludeGroupDisplayName : Nom d’un groupe à exclure du traitement
    - TeamsSummaryTeamId/ChannelId : Identifiants de l’équipe/canal Teams pour le résumé
    - InactiveUserTagExtensionName : Nom du champ personnalisé pour taguer les utilisateurs
#>

# Import requis pour les modules Graph
#Requires -Modules @{ModuleName='Microsoft.Graph.Authentication'; ModuleVersion='2.0.0'}, @{ModuleName='Microsoft.Graph.Users'; ModuleVersion='2.0.0'}, @{ModuleName='Microsoft.Graph.Groups'; ModuleVersion='2.0.0'}

[CmdletBinding()]
param (
    [int[]]$InactivityThresholds = @(90, 180),
    [string]$ExcludeGroupDisplayName,
    [string]$TeamsSummaryTeamId,
    [string]$TeamsSummaryChannelId,
    [string]$InactiveUserTagExtensionName
)

# Fonction utilitaire pour les logs dans Azure Functions
function Write-AzFunctionLog {
    param (
        [string]$Message,
        [string]$Level = 'Information'
    )
    Write-Output "[$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))] [$Level] $Message"
}

Write-AzFunctionLog -Message "Script démarré."

# --- Authentification Graph ---
$cloud = "Global" # Environnement par défaut : Commercial (Microsoft 365 global)
$neededScopes = @(
    'User.Read.All', 'Directory.Read.All', 'User.ReadWrite.All',
    'Group.Read.All', 'Chat.ReadWrite', 'ChannelMessage.Send'
)

try {
    Write-AzFunctionLog -Message "Connexion à Microsoft Graph..."
    Connect-MgGraph -ContextScope CurrentUser -Environment $cloud -NoWelcome -Scopes $neededScopes
    Write-AzFunctionLog -Message "Connecté à Microsoft Graph."
} catch {
    Write-AzFunctionLog -Message "Erreur de connexion Graph : $($_.Exception.Message)" -Level "Error"
    exit 1
}

# --- Récupérer les utilisateurs à exclure (via groupe) ---
$excludedUserPrincipalNames = @()
if (-not [string]::IsNullOrEmpty($ExcludeGroupDisplayName)) {
    Write-AzFunctionLog -Message "Recherche du groupe d'exclusion '$ExcludeGroupDisplayName'"
    try {
        $excludeGroup = Get-MgGroup -Filter "displayName eq '$ExcludeGroupDisplayName'" -ErrorAction Stop
        if ($excludeGroup) {
            $excludeGroupMembers = Get-MgGroupMember -GroupId $excludeGroup.Id -All | Select-Object -ExpandProperty UserPrincipalName
            $excludedUserPrincipalNames = $excludeGroupMembers | Where-Object { $_ -ne $null }
            Write-AzFunctionLog -Message "Groupe trouvé : $($excludedUserPrincipalNames.Count) membres exclus."
        }
    } catch {
        Write-AzFunctionLog -Message "Erreur récupération du groupe : $($_.Exception.Message)" -Level "Error"
    }
}

# Résumés utilisateurs inactifs et réactivés
$inactiveUsersSummary = [System.Collections.ArrayList]::new()
$reactivatedUsersSummary = [System.Collections.ArrayList]::new()

# --- Parcourir les seuils d’inactivité ---
foreach ($days in $InactivityThresholds | Sort-Object -Descending) {
    Write-AzFunctionLog -Message "Traitement des utilisateurs inactifs depuis $days jours..."
    $targetDate = (Get-Date).ToUniversalTime().AddDays(-$days).ToString("o")
    $siFilter = 'signInActivity/lastSuccessfulSignInDateTime'

    # Construction de l'URL Graph (avec filtre et attributs personnalisés)
    $apiUrl = "/v1.0/users?`$filter=$siFilter lt $($targetDate)&`$select=userPrincipalName,signInActivity,accountEnabled,id,userType,$($InactiveUserTagExtensionName)"

    $pagedResults = [System.Collections.ArrayList]::new()
    $nextLink = $apiUrl
    do {
        try {
            $response = Invoke-MgGraphRequest -Method GET $nextLink -OutputType PSObject -ErrorAction Stop
            $pagedResults.AddRange($response.value) | Out-Null
            $nextLink = $response."@odata.nextLink"
        } catch {
            Write-AzFunctionLog -Message "Erreur récupération utilisateurs : $($_.Exception.Message)" -Level "Error"
            $nextLink = $null
        }
    } until ([string]::IsNullOrEmpty($nextLink))

    foreach ($user in $pagedResults) {
        if (-not $user.accountEnabled -or [string]::IsNullOrEmpty($user.userPrincipalName)) {
            continue # Ignorer les comptes désactivés ou sans UPN
        }

        if ($excludedUserPrincipalNames -contains $user.userPrincipalName) {
            continue # Ignorer les utilisateurs exclus
        }

        $lastSignInDate = $user.signInActivity.lastSuccessfulSignInDateTime
        $isCurrentlyInactive = ($lastSignInDate -lt (Get-Date).ToUniversalTime().AddDays(-$days))
        $userTaggedStatus = $user.$($InactiveUserTagExtensionName)
        $needsAction = $true

        # Vérifie si l'utilisateur est déjà tagué comme inactif
        if ($userTaggedStatus) {
            try {
                $tagData = $userTaggedStatus | ConvertFrom-Json
                if ($tagData.isInactive -eq $true -and $tagData.inactiveThresholdDays -ge $days) {
                    if (-not $isCurrentlyInactive) {
                        # L'utilisateur s'est reconnecté ⇒ on le dé-tague
                        $reactivatedUsersSummary.Add([PSCustomObject]@{
                            UserPrincipalName = $user.userPrincipalName
                            LastSuccessfulSignIn = $lastSignInDate
                            PreviousInactiveThreshold = $tagData.inactiveThresholdDays
                        }) | Out-Null
                        $needsAction = $false
                    } else {
                        $needsAction = $false
                    }
                }
            } catch {
                Write-AzFunctionLog -Message "Erreur analyse tag utilisateur $($user.userPrincipalName)." -Level "Warning"
            }
        }

        if ($needsAction -and $isCurrentlyInactive) {
            # Récupère le manager (si défini)
            try {
                $manager = Get-MgUserManager -UserId $user.Id -ErrorAction SilentlyContinue
            } catch {
                $manager = $null
            }

            # (Placeholder) Envoi du message Teams au manager
            Write-AzFunctionLog -Message "Action: Notifier manager $($manager.UserPrincipalName) (utilisateur: $($user.userPrincipalName))" -Level "Information"

            # (Placeholder) Marquage de l'utilisateur comme inactif
            Write-AzFunctionLog -Message "Action: Tag utilisateur $($user.userPrincipalName) comme inactif ($days jours)." -Level "Information"

            # Ajout au résumé
            $inactiveUsersSummary.Add([PSCustomObject]@{
                UserPrincipalName = $user.userPrincipalName
                LastSuccessfulSignIn = $lastSignInDate
                UserType = $user.userType
                Manager = $manager.UserPrincipalName
                InactivityDaysThreshold = $days
            }) | Out-Null
        }
    }
}

# --- Construction et affichage du résumé Teams ---
if ($inactiveUsersSummary.Count -gt 0 -or $reactivatedUsersSummary.Count -gt 0) {
    $summaryMessage = "## Rapport d'inactivité - $((Get-Date).ToString('yyyy-MM-dd'))`n`n"

    if ($inactiveUsersSummary.Count -gt 0) {
        $summaryMessage += "### Nouveaux utilisateurs inactifs:`n"
        $summaryMessage += "| UPN | Dernière connexion | Type | Manager | Seuil (jours) |`n|---|---|---|---|---|`n"
        foreach ($user in $inactiveUsersSummary) {
            $summaryMessage += "| $($user.UserPrincipalName) | $($user.LastSuccessfulSignIn) | $($user.UserType) | $($user.Manager) | $($user.InactivityDaysThreshold) |`n"
        }
    }

    if ($reactivatedUsersSummary.Count -gt 0) {
        $summaryMessage += "`n### Utilisateurs réactivés:`n"
        $summaryMessage += "| UPN | Dernière connexion | Ancien seuil |`n|---|---|---|`n"
        foreach ($user in $reactivatedUsersSummary) {
            $summaryMessage += "| $($user.UserPrincipalName) | $($user.LastSuccessfulSignIn) | $($user.PreviousInactiveThreshold) |`n"
        }
    }

    # (Placeholder) Poster le message dans un canal Teams
    Write-AzFunctionLog -Message "Action: Poster résumé dans Teams (TeamId: $TeamsSummaryTeamId / ChannelId: $TeamsSummaryChannelId)." -Level "Information"
} else {
    Write-AzFunctionLog -Message "Aucun utilisateur inactif ou réactivé trouvé."
}

Write-AzFunctionLog -Message "Script terminé."
