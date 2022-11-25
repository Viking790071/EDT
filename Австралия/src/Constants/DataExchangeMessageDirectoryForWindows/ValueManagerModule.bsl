#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	DataExchangeServer.ExternalResourcesDataExchangeMessageDirectoryQuery(PermissionRequests, ThisObject);
	
EndProcedure

#EndRegion

#EndIf