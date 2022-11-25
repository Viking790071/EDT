
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisObject, ExternalUsers.ExternalUserAuthorizationData());
	CommonClientServer.SetDynamicListFilterItem(List, "Owner", AuthorizedCounterparty, DataCompositionComparisonType.Equal);
	CommonClientServer.SetDynamicListFilterItem(List, "DeletionMark", False, DataCompositionComparisonType.Equal);
	
	If GetFunctionalOption("UseContractRestrictionsForExternalUsers") Then
		CommonClientServer.SetDynamicListFilterItem(List, "VisibleToExternalUsers", True, DataCompositionComparisonType.Equal);
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
