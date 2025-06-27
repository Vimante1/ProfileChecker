# ProfileChecker
This PowerShell script analyzes Windows user profile entries in the system registry to identify duplicate profile paths and orphaned (ghost) SIDs — registry profiles that do not correspond to any existing user account.

Key features include:
  
  • Scans the registry under HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList to find all user profiles and their associated SIDs.
 
  • Detects duplicate profile paths that reference multiple SIDs.

  • Identifies orphaned profile SIDs that exist in the registry but are not linked to any local user account.
 
  • Provides a detailed console report listing duplicates and ghost profiles.
 
  • Prompts the user for confirmation before automatically removing duplicate registry entries, or can be set to auto-remove duplicates without prompts.
 
  • Before deletion, exports each duplicate SID registry key to a .reg file in a specified folder for backup and potential restoration.

  • Maintains a log file summarizing all exported and deleted duplicate profiles.


This tool is useful for system administrators and IT professionals to clean up stale or conflicting user profile registry entries on Windows machines, helping to resolve profile corruption or login issues related to duplicated profiles.
